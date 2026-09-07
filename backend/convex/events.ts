import { query, mutation, internalQuery, internalMutation, internalAction } from "./_generated/server";
import { v } from "convex/values";
import { Doc, Id } from "./_generated/dataModel";
import { MutationCtx } from "./_generated/server";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { requireMembers, requireRef, requireSameHome, unlinkEvent } from "./lib/relations";
import { internal } from "./_generated/api";

// The household calendar.
//
// One row in `events` is a *series*. A one-off is a series of one; "every other
// Tuesday" is one row. Nothing stores an occurrence — they are derived here,
// for exactly the window the client is looking at, and thrown away again.
//
// That is the whole performance story of this module. The alternative, writing
// a row per occurrence, means a recurring event is unbounded storage, editing
// the series is a fan-out write, and "what is on in March" is a scan. The
// alternative on the *client* — ship the series and expand on device — means
// every phone downloads every event the household has ever held in order to
// draw thirty days, which is the mistake `stats:forHome` and `finance:summary`
// were written to stop making.
//
// The other half of this module is the *plan*. An event links out to the three
// things a household actually has to organise around a date — what it costs,
// what has to be bought, and what is being cooked — and each link points at the
// module that already owns that data:
//
//   expenses.event_id       money spent on it, still living in the ledger
//   shopping_items.event_id things to buy for it, still on the shopping list
//   events.recipe_ids       the menu, read through from `recipes`
//
// `detail` below rolls all three into one subscription, so the event screen is
// a single query rather than four, and `stockUp` turns a menu into a shopping
// list in one write instead of one per ingredient.

const DAY = 86_400_000;
const MINUTE = 60_000;

/** Year 9999. Stands in for "this series never ends". */
const FOREVER = 253_402_300_799_000;

/**
 * Ceilings on one expansion.
 *
 * A daily series read across a year is 365 occurrences, which is a fine
 * payload; a *minute*ly one would not be, and nothing stops a client asking for
 * a ten-year window. These bound the answer rather than the question, so a
 * pathological range degrades into "the first 800 things" instead of a
 * timeout.
 */
const MAX_PER_SERIES = 400;
const MAX_TOTAL = 800;

/** The widest window a single read may ask for. Two years covers any UI here. */
const MAX_WINDOW = 731 * DAY;

const eventKind = v.union(
  v.literal("general"),
  v.literal("houseParty"),
  v.literal("dinnerParty"),
  v.literal("movieNight"),
  v.literal("gameNight"),
  v.literal("visit"),
  v.literal("chore"),
  v.literal("dining"),
  v.literal("concert"),
  v.literal("cinema"),
  v.literal("theatre"),
  v.literal("sports"),
  v.literal("picnic"),
  v.literal("trip"),
  v.literal("birthday"),
  v.literal("anniversary"),
  v.literal("holiday"),
  v.literal("appointment"),
  v.literal("deadline"),
);

const shoppingCategory = v.union(
  v.literal("groceries"),
  v.literal("household"),
  v.literal("cleaning"),
  v.literal("other"),
);

const rsvpStatus = v.union(
  v.literal("going"),
  v.literal("maybe"),
  v.literal("declined"),
);

const recurrenceArg = v.object({
  freq: v.union(
    v.literal("daily"),
    v.literal("weekly"),
    v.literal("monthly"),
    v.literal("yearly"),
  ),
  interval: v.number(),
  weekdays: v.optional(v.array(v.number())),
  until: v.optional(v.number()),
});

type Recurrence = {
  freq: "daily" | "weekly" | "monthly" | "yearly";
  interval: number;
  weekdays?: number[];
  until?: number;
};

type EventDoc = Doc<"events">;

// MARK: - Calendar arithmetic
//
// All of it in the *event's* zone, not the server's and not the reader's.
// Convex runs in UTC, so a monthly series written at 09:00 in Istanbul would
// expand from its UTC instant (06:00) and land on the wrong side of midnight
// for any event in the late evening — a 23:30 Monday would repeat on Tuesdays.
// Shifting by the stored offset and reading UTC components is the same as
// reading local components, without needing a timezone database.

type Parts = { y: number; m: number; d: number; ms: number };

/** Local calendar parts, plus the time of day as milliseconds past midnight. */
function partsOf(at: number, tzOffset: number): Parts {
  const shifted = new Date(at + tzOffset * MINUTE);
  return {
    y: shifted.getUTCFullYear(),
    m: shifted.getUTCMonth(),
    d: shifted.getUTCDate(),
    ms:
      shifted.getUTCHours() * 3_600_000 +
      shifted.getUTCMinutes() * 60_000 +
      shifted.getUTCSeconds() * 1_000 +
      shifted.getUTCMilliseconds(),
  };
}

/**
 * The instant for these parts, or `null` if the day does not exist in that
 * month.
 *
 * Not clamped on purpose. `Date.UTC(2026, 1, 31)` silently rolls to 3 March,
 * and clamping it to the 28th is no better: a household that set "rent, the
 * 31st" means the 31st, and a February that quietly pays on the 28th is a
 * wrong answer delivered confidently. A month without a 31st simply has no
 * occurrence, which is what every calendar app does.
 */
function instantFor(p: Parts, tzOffset: number): number | null {
  const at = Date.UTC(p.y, p.m, p.d) + p.ms;
  // `p.ms` is always inside one day, so a rolled-over day is the only way the
  // date can come back different — and it means the day asked for is not in
  // that month.
  if (new Date(at).getUTCDate() !== p.d) return null;
  return at - tzOffset * MINUTE;
}

/** 0=Sunday … 6=Saturday, in the event's own zone. */
function weekdayOf(at: number, tzOffset: number): number {
  return new Date(at + tzOffset * MINUTE).getUTCDay();
}

/** Local midnight of the day containing `at`. */
function startOfDay(at: number, tzOffset: number): number {
  const p = partsOf(at, tzOffset);
  return Date.UTC(p.y, p.m, p.d) - tzOffset * MINUTE;
}

// MARK: - Expansion

/**
 * Every occurrence of `event` that overlaps `[from, to]`, soonest first.
 *
 * Jumps to the first occurrence in the window rather than walking to it. That
 * is what dropping `COUNT` from the recurrence model buys: with no "the 30th
 * time" to count, the nth occurrence is closed-form for daily, weekly and
 * weekly-on-weekdays, and a cheap month walk for the rest.
 *
 * An occurrence counts as overlapping if any part of it does — an event that
 * started yesterday and runs through today belongs on today.
 */
function expand(event: EventDoc, from: number, to: number): number[] {
  const tz = event.tz_offset ?? 0;
  const duration = Math.max(0, event.ends_at - event.starts_at);
  const skipped = new Set(event.exdates ?? []);
  const first = event.starts_at;

  // An occurrence starting this early still reaches into the window.
  const earliest = from - duration;

  const rec = event.recurrence as Recurrence | undefined;
  if (!rec) {
    return first <= to && first >= earliest && !skipped.has(first) ? [first] : [];
  }

  const interval = Math.max(1, Math.floor(rec.interval || 1));
  const last = Math.min(to, rec.until ?? FOREVER);
  if (last < first) return [];

  const out: number[] = [];
  const take = (start: number) => {
    if (start < earliest || start > last) return;
    if (skipped.has(start)) return;
    out.push(start);
  };

  switch (rec.freq) {
    case "daily":
    case "weekly": {
      const weekdays = rec.freq === "weekly" ? cleanWeekdays(rec.weekdays) : [];

      if (weekdays.length === 0) {
        // A fixed stride, so the first occurrence in the window is arithmetic.
        const step = (rec.freq === "daily" ? 1 : 7) * interval * DAY;
        const skip = Math.max(0, Math.ceil((earliest - first) / step));
        for (let i = skip; out.length < MAX_PER_SERIES; i++) {
          const start = first + i * step;
          if (start > last) break;
          take(start);
        }
        break;
      }

      // "Every other Tuesday and Thursday": the *week* has the stride, and each
      // qualifying week contributes one occurrence per named weekday. Anchor on
      // the Sunday of the first week so week indices are stable, and keep the
      // time of day from the series start.
      const stride = interval * 7 * DAY;
      const anchor = first - weekdayOf(first, tz) * DAY;
      const skipWeeks = Math.max(0, Math.floor((earliest - anchor - 6 * DAY) / stride));

      for (let w = skipWeeks; out.length < MAX_PER_SERIES; w++) {
        const weekStart = anchor + w * stride;
        if (weekStart > last) break;
        for (const day of weekdays) {
          const start = weekStart + day * DAY;
          // The rule cannot reach back before the series began — a Monday
          // series added on a Wednesday does not retroactively acquire that
          // week's Monday.
          if (start < first) continue;
          take(start);
        }
      }
      break;
    }

    case "monthly":
    case "yearly": {
      const step = rec.freq === "monthly" ? interval : interval * 12;
      const base = partsOf(first, tz);
      const target = partsOf(Math.max(earliest, first), tz);
      // Months between the series start and the window, floored to a whole
      // number of strides so nothing before it is missed.
      const monthsAhead = (target.y - base.y) * 12 + (target.m - base.m);
      const skip = Math.max(0, Math.floor(monthsAhead / step));

      for (let i = skip; out.length < MAX_PER_SERIES; i++) {
        const month = base.m + i * step;
        const y = base.y + Math.floor(month / 12);
        const m = ((month % 12) + 12) % 12;
        // The walk ends on the month, not on the occurrence: a February that
        // has no 31st produces nothing, and testing `start > last` on a
        // non-existent occurrence would never end the loop.
        if (Date.UTC(y, m, 1) - tz * MINUTE > last) break;
        const start = instantFor({ y, m, d: base.d, ms: base.ms }, tz);
        if (start !== null) take(start);
      }
      break;
    }
  }

  return out;
}

/** At most three distinct weekdays… of the seven there are. Order is meaningless. */
function cleanWeekdays(days: number[] | undefined): number[] {
  if (!days?.length) return [];
  const seen = new Set<number>();
  for (const d of days) {
    const day = Math.floor(d);
    if (Number.isFinite(day) && day >= 0 && day <= 6) seen.add(day);
  }
  return [...seen].sort((a, b) => a - b);
}

/** At most three nudges, whole minutes, never negative. Same rule as a bill's. */
function cleanReminders(mins: number[] | undefined): number[] {
  if (!mins?.length) return [];
  const seen = new Set<number>();
  for (const m of mins) {
    const value = Math.floor(m);
    if (Number.isFinite(value) && value >= 0 && value <= 60 * 24 * 30) seen.add(value);
  }
  return [...seen].sort((a, b) => b - a).slice(0, 3);
}

/**
 * What `series_end` should be for a set of fields.
 *
 * The last occurrence may *start* on `until` and run past it, so the series is
 * still live for one duration beyond that — otherwise a three-hour party on the
 * final Saturday would drop out of "what is on today" while it was happening.
 */
function seriesEndFor(startsAt: number, endsAt: number, rec: Recurrence | undefined): number {
  if (!rec) return endsAt;
  if (rec.until === undefined) return FOREVER;
  return rec.until + Math.max(0, endsAt - startsAt);
}

// MARK: - Reading

/**
 * One occurrence, flattened.
 *
 * Carries its series with it rather than pointing at it. The alternative — ids
 * here and a second subscription for the documents — costs a round trip to open
 * a detail sheet, and a household's events are small: the whole of a busy month
 * is a few kilobytes.
 */
function occurrence(event: EventDoc, start: number) {
  const duration = Math.max(0, event.ends_at - event.starts_at);
  return {
    // Stable across pushes and unique across the series, so the client can key
    // a list on it without inventing an identity.
    id: `${event._id}:${start}`,
    event_id: event._id,
    home_id: event.home_id,
    title: event.title ?? "",
    notes: event.notes,
    location: event.location,
    kind: event.kind ?? "general",
    starts_at: start,
    ends_at: start + duration,
    is_all_day: event.is_all_day ?? false,
    tz_offset: event.tz_offset ?? 0,
    url: event.url ?? null,
    // The plan travels with the occurrence so the composer can reopen fully
    // populated without a second read. Only the *shape* of it — what it costs
    // and what has been bought are rolled up by `detail`, which is the query
    // the screen showing those numbers subscribes to.
    budget: event.budget ?? null,
    currency: event.currency ?? null,
    recipe_ids: event.recipe_ids ?? [],
    recurrence: event.recurrence ?? null,
    /** Where the series itself began — "since March", on the detail sheet. */
    series_start: event.starts_at,
    is_recurring: !!event.recurrence,
    attendees: event.attendees ?? [],
    rsvps: event.rsvps ?? [],
    reminders: event.reminders ?? [],
    created_by: event.created_by,
    created: event.created,
    updated: event.updated,
  };
}

type Occurrence = ReturnType<typeof occurrence>;

/**
 * Reads the series that could still produce something at or after `from`.
 *
 * One index range. `series_end` is the denormalised "last instant this row can
 * matter", so a household with three years of history reads only what is still
 * live rather than everything it has ever held. `starts_at <= to` is checked in
 * memory because it is the cheaper of the two bounds to apply second: what is
 * left after the index is tens of rows, not thousands.
 */
async function seriesFor(
  ctx: { db: any },
  homeId: Id<"homes">,
  from: number,
  to: number,
): Promise<EventDoc[]> {
  const rows: EventDoc[] = await ctx.db
    .query("events")
    .withIndex("by_home_series_end", (q: any) =>
      q.eq("home_id", homeId).gte("series_end", from),
    )
    .collect();
  return rows.filter((e) => e.starts_at <= to);
}

function collect(series: EventDoc[], from: number, to: number): Occurrence[] {
  const out: Occurrence[] = [];
  for (const event of series) {
    for (const start of expand(event, from, to)) {
      out.push(occurrence(event, start));
      if (out.length >= MAX_TOTAL) return sortOccurrences(out);
    }
  }
  return sortOccurrences(out);
}

/**
 * Soonest first, all-day events ahead of timed ones that start with them.
 *
 * An all-day event sorts to local midnight, so without the tie-break it lands
 * *after* anything else at midnight and reads as an appointment. Ties beyond
 * that go to the title, so a day's list is stable between pushes — an unstable
 * order makes SwiftUI animate rows that did not change.
 */
function sortOccurrences(items: Occurrence[]): Occurrence[] {
  return items.sort((a, b) => {
    if (a.starts_at !== b.starts_at) return a.starts_at - b.starts_at;
    if (a.is_all_day !== b.is_all_day) return a.is_all_day ? -1 : 1;
    return a.title.localeCompare(b.title) || a.id.localeCompare(b.id);
  });
}

/**
 * Everything on between two instants, already expanded.
 *
 * The client subscribes to one of these per visible range and holds nothing
 * else. Stepping a month replaces the subscription rather than filtering a
 * bigger one, which is what keeps a phone's copy of the calendar the size of
 * what is on screen.
 */
export const inRange = query({
  args: { homeId: v.id("homes"), from: v.number(), to: v.number() },
  handler: async (ctx, { homeId, from, to }) => {
    await requireHomeMember(ctx, homeId);
    if (to < from) return [];
    // A window nobody could be looking at is a bug or a probe, not a request.
    const end = Math.min(to, from + MAX_WINDOW);
    const series = await seriesFor(ctx, homeId, from, end);
    return collect(series, from, end);
  },
});

/**
 * The next few things, whenever they are.
 *
 * For the Hub tile and anything else that wants "is there something coming"
 * without caring about a month. Capped at both ends: a horizon so an empty
 * calendar does not expand a daily series to the year 9999, and a count so the
 * answer stays small.
 */
export const upcoming = query({
  args: { homeId: v.id("homes"), limit: v.optional(v.number()) },
  handler: async (ctx, { homeId, limit }) => {
    await requireHomeMember(ctx, homeId);
    const now = Date.now();
    const horizon = now + 120 * DAY;
    const count = Math.min(Math.max(1, Math.floor(limit ?? 20)), 100);
    const series = await seriesFor(ctx, homeId, now, horizon);
    return collect(series, now, horizon).slice(0, count);
  },
});

// MARK: - Writing

const writableFields = {
  title: v.optional(v.string()),
  notes: v.optional(v.string()),
  location: v.optional(v.string()),
  kind: v.optional(eventKind),
  startsAt: v.optional(v.number()),
  endsAt: v.optional(v.number()),
  isAllDay: v.optional(v.boolean()),
  tzOffset: v.optional(v.number()),
  attendees: v.optional(v.array(v.id("users"))),
  reminders: v.optional(v.array(v.number())),
  url: v.optional(v.string()),
  /** `null` removes the budget; absent leaves it alone. */
  budget: v.optional(v.union(v.number(), v.null())),
  currency: v.optional(v.string()),
  recipeIds: v.optional(v.array(v.id("recipes"))),
};

// MARK: - The plan
//
// Three links, and the arithmetic that makes them worth having.

/**
 * A budget in whole minor units, or `undefined`.
 *
 * Money is integers here for the same reason it is integers in `finance.ts`: a
 * budget of 12.30 stored as a float and compared against a sum of integer
 * expenses drifts, and a party that reads "over budget by 1 cent" is a bug
 * people notice.
 */
function requireBudget(amount: number | undefined): number | undefined {
  if (amount === undefined) return undefined;
  if (!Number.isFinite(amount) || amount < 0) throw new Error("A budget cannot be negative");
  return Math.round(amount);
}

/**
 * The recipes this event may name.
 *
 * `v.id("recipes")` is a type, not a foreign key — it does not check the row
 * exists and it certainly does not check it belongs to this household. Without
 * this, an event could name a recipe from another home and read it straight
 * back out through `detail`.
 */
async function checkedRecipes(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  ids: Id<"recipes">[] | undefined,
): Promise<Id<"recipes">[]> {
  if (!ids?.length) return [];
  const unique = [...new Set(ids)].slice(0, MAX_MENU);
  for (const id of unique) {
    const recipe = await requireRef(ctx, id, "Recipe");
    requireSameHome(recipe, homeId, "Recipe");
  }
  return unique;
}

/** A menu, not a cookbook. Beyond this the detail sheet stops being readable. */
const MAX_MENU = 12;

/**
 * Everything hanging off one event, in one subscription.
 *
 * The detail screen is a single query on purpose. Four — the event, its
 * expenses, its shopping, its recipes — is four websocket queries per open
 * sheet, four pushes every time any of them changes, and four chances for the
 * screen to show a spend total that disagrees with the list under it. Rolled up
 * here, the numbers and the rows they summarise can never disagree, because
 * they are computed from the same read.
 */
export const detail = query({
  args: { id: v.id("events") },
  handler: async (ctx, { id }) => {
    const event = await ctx.db.get(id);
    if (!event) return null;
    await requireDocHome(ctx, event, "Event");

    const expenses = await ctx.db
      .query("expenses")
      .withIndex("by_event", (q) => q.eq("event_id", id))
      .collect();

    const items = await ctx.db
      .query("shopping_items")
      .withIndex("by_event", (q) => q.eq("event_id", id))
      .collect();

    // Read through, so nothing on the client subscribes to recipes to draw a
    // menu — and a recipe deleted since is simply dropped rather than leaving a
    // dangling row the sheet has to explain.
    const recipes = await Promise.all(
      (event.recipe_ids ?? []).map(async (recipeId) => {
        const recipe = await ctx.db.get(recipeId);
        if (!recipe || recipe.home_id !== event.home_id) return null;
        const ingredients = Array.isArray(recipe.ingredients) ? recipe.ingredients : [];
        return {
          _id: recipe._id,
          title: recipe.title ?? "",
          image: recipe.image ?? null,
          prep_time: recipe.prep_time ?? null,
          cook_time: recipe.cook_time ?? null,
          servings: recipe.servings ?? null,
          ingredient_count: ingredients.length,
        };
      }),
    );

    // Scoped to the budget's own currency, for exactly the reason
    // `finance:summary` is: adding 500 lira to 20 euros is not a number, and no
    // rate is ever invented on a household's behalf. With no budget set there
    // is nothing to compare against, so the sum is simply whatever currency the
    // expenses were written in — the client shows them per-row.
    const currency = event.currency ?? expenses[0]?.currency ?? null;
    const spent = expenses
      .filter((e) => currency === null || e.currency === currency)
      .reduce((total, e) => total + e.amount, 0);

    return {
      event_id: id,
      currency,
      budget: event.budget ?? null,
      spent,
      /** Every currency the linked expenses are written in, so a mixed plan can say so. */
      currencies: [...new Set(expenses.map((e) => e.currency))].sort(),
      expenses: expenses
        .map((e) => ({
          _id: e._id,
          title: e.title ?? "",
          amount: e.amount,
          currency: e.currency,
          category: e.category ?? "other",
          paid_by: e.paid_by,
          spent_at: e.spent_at,
        }))
        .sort((a, b) => b.spent_at - a.spent_at),
      shopping: items
        .map((it) => ({
          _id: it._id,
          name: it.name ?? "",
          is_purchased: it.is_purchased ?? false,
          category: it.category ?? "other",
          recipe_title: it.recipe_title ?? null,
        }))
        .sort((a, b) => Number(a.is_purchased) - Number(b.is_purchased) || a.name.localeCompare(b.name)),
      shopping_total: items.length,
      shopping_purchased: items.filter((it) => it.is_purchased).length,
      recipes: recipes.filter((r): r is NonNullable<typeof r> => r !== null),
    };
  },
});

/**
 * Turns the menu into a shopping list, in one write.
 *
 * One mutation rather than one per ingredient, for the reason
 * `shopping:createFromRecipe` gives: a four-recipe menu is forty writes, forty
 * subscription pushes and forty notifications otherwise. Names already on the
 * list and not yet bought are skipped, so pressing it twice does not double the
 * shop — and each line keeps its recipe as well as its event, so the shopping
 * screen can still group "everything for the lasagne" inside "everything for
 * Saturday".
 */
export const stockUp = mutation({
  args: { id: v.id("events"), category: v.optional(shoppingCategory) },
  handler: async (ctx, { id, category }) => {
    const user = await requireUser(ctx);
    const event = await ctx.db.get(id);
    if (!event) throw new Error("Event not found");
    await requireDocHome(ctx, event, "Event");

    const recipeIds = event.recipe_ids ?? [];
    if (!recipeIds.length) return { added: 0, skipped: 0 };

    const existing = await ctx.db
      .query("shopping_items")
      .withIndex("by_home", (q) => q.eq("home_id", event.home_id))
      .collect();
    // Matched on the outstanding list as a whole, not just this event's slice:
    // if the flour is already on the list for Tuesday's bread, buying it twice
    // for Saturday's cake is not help.
    const outstanding = new Set(
      existing.filter((it) => !it.is_purchased).map((it) => (it.name ?? "").trim().toLowerCase()),
    );

    const now = Date.now();
    let added = 0;
    let skipped = 0;

    for (const recipeId of recipeIds) {
      const recipe = await ctx.db.get(recipeId);
      if (!recipe || recipe.home_id !== event.home_id) continue;
      const ingredients: string[] = Array.isArray(recipe.ingredients) ? recipe.ingredients : [];

      for (const raw of ingredients) {
        const name = typeof raw === "string" ? raw.trim() : "";
        if (!name) continue;
        const key = name.toLowerCase();
        if (outstanding.has(key)) {
          skipped++;
          continue;
        }
        // Held in the same set, so two recipes both wanting butter add it once.
        outstanding.add(key);
        await ctx.db.insert("shopping_items", {
          home_id: event.home_id,
          name,
          category: category ?? "groceries",
          is_purchased: false,
          recipe_id: recipe._id,
          recipe_title: recipe.title ?? "",
          event_id: id,
          event_title: event.title ?? "",
          created_by: user._id,
          updated_by: user._id,
          created: now,
          updated: now,
        });
        added++;
      }
    }

    if (added > 0) {
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: event.home_id,
        actor: user._id,
        title: user.name ? `${user.name} added` : "Added to the list",
        body: `${added} ${added === 1 ? "item" : "items"} for ${event.title ?? "an event"}`,
        category: "shopping",
      });
    }

    return { added, skipped };
  },
});

/**
 * Things to buy for this event that are not in any recipe — the candles, the
 * ice, the extra chairs.
 */
export const addItems = mutation({
  args: {
    id: v.id("events"),
    names: v.array(v.string()),
    category: v.optional(shoppingCategory),
  },
  handler: async (ctx, { id, names, category }) => {
    const user = await requireUser(ctx);
    const event = await ctx.db.get(id);
    if (!event) throw new Error("Event not found");
    await requireDocHome(ctx, event, "Event");

    const existing = await ctx.db
      .query("shopping_items")
      .withIndex("by_home", (q) => q.eq("home_id", event.home_id))
      .collect();
    const outstanding = new Set(
      existing.filter((it) => !it.is_purchased).map((it) => (it.name ?? "").trim().toLowerCase()),
    );

    const now = Date.now();
    let added = 0;
    for (const raw of names.slice(0, 50)) {
      const name = raw.trim();
      if (!name || outstanding.has(name.toLowerCase())) continue;
      outstanding.add(name.toLowerCase());
      await ctx.db.insert("shopping_items", {
        home_id: event.home_id,
        name,
        category: category ?? "other",
        is_purchased: false,
        event_id: id,
        event_title: event.title ?? "",
        created_by: user._id,
        updated_by: user._id,
        created: now,
        updated: now,
      });
      added++;
    }

    if (added > 0) {
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: event.home_id,
        actor: user._id,
        title: user.name ? `${user.name} added` : "Added to the list",
        body: `${added} ${added === 1 ? "item" : "items"} for ${event.title ?? "an event"}`,
        category: "shopping",
      });
    }

    return { added, skipped: names.length - added };
  },
});

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    title: v.string(),
    notes: v.optional(v.string()),
    location: v.optional(v.string()),
    kind: v.optional(eventKind),
    startsAt: v.number(),
    endsAt: v.number(),
    isAllDay: v.optional(v.boolean()),
    tzOffset: v.optional(v.number()),
    recurrence: v.optional(recurrenceArg),
    attendees: v.optional(v.array(v.id("users"))),
    reminders: v.optional(v.array(v.number())),
    url: v.optional(v.string()),
    budget: v.optional(v.number()),
    currency: v.optional(v.string()),
    recipeIds: v.optional(v.array(v.id("recipes"))),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);

    const title = args.title.trim();
    if (!title) throw new Error("An event needs a name");
    if (args.endsAt < args.startsAt) throw new Error("An event cannot end before it starts");

    const attendees = [...new Set(args.attendees ?? [])];
    await requireMembers(ctx, home, attendees, "Event attendee");
    const recipeIds = await checkedRecipes(ctx, args.homeId, args.recipeIds);

    const recurrence = normaliseRecurrence(args.recurrence, args.startsAt);
    const now = Date.now();

    const id = await ctx.db.insert("events", {
      home_id: args.homeId,
      title,
      notes: args.notes?.trim() || undefined,
      location: args.location?.trim() || undefined,
      kind: args.kind ?? "general",
      starts_at: args.startsAt,
      ends_at: args.endsAt,
      is_all_day: args.isAllDay ?? false,
      tz_offset: args.tzOffset ?? 0,
      recurrence,
      series_end: seriesEndFor(args.startsAt, args.endsAt, recurrence),
      url: args.url?.trim() || undefined,
      budget: requireBudget(args.budget),
      currency: args.budget !== undefined ? (args.currency ?? "EUR") : undefined,
      recipe_ids: recipeIds.length ? recipeIds : undefined,
      attendees,
      // Whoever wrote it is coming, unless they say otherwise. Anything else
      // makes the organiser's own event show "nobody has answered".
      rsvps: [{ user_id: user._id, status: "going" as const }],
      reminders: cleanReminders(args.reminders),
      created_by: user._id,
      created: now,
      updated: now,
    });

    // Scheduled rather than awaited: a mutation must not block on APNs, and a
    // push that fails must never roll back the event.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: user.name ? `${user.name} added an event` : "New event",
      body: title,
      category: "calendar",
      collapseId: `event-${id}`,
    });

    return id;
  },
});

/**
 * Edits a series, or lifts one occurrence out of it.
 *
 * `scope: "occurrence"` does not patch anything: it marks that date skipped on
 * the series and writes the edited version as its own one-off event. That is
 * the only honest way to move one Tuesday without a per-occurrence override
 * table, and it leaves the rest of the series untouched.
 */
export const update = mutation({
  args: {
    id: v.id("events"),
    scope: v.optional(v.union(v.literal("series"), v.literal("occurrence"))),
    /** Which occurrence is being edited. Required for `occurrence` scope. */
    occurrenceStart: v.optional(v.number()),
    ...writableFields,
    /** `null` clears the repeat; absent leaves it as it was. */
    recurrence: v.optional(v.union(recurrenceArg, v.null())),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const event = await ctx.db.get(args.id);
    if (!event) throw new Error("Event not found");
    const home = await requireDocHome(ctx, event, "Event");

    if (args.title !== undefined && !args.title.trim()) {
      throw new Error("An event needs a name");
    }
    const attendees = args.attendees ? [...new Set(args.attendees)] : undefined;
    if (attendees) await requireMembers(ctx, home, attendees, "Event attendee");
    const recipeIds = args.recipeIds
      ? await checkedRecipes(ctx, event.home_id, args.recipeIds)
      : undefined;

    const startsAt = args.startsAt ?? event.starts_at;
    const endsAt = args.endsAt ?? event.ends_at;
    if (endsAt < startsAt) throw new Error("An event cannot end before it starts");

    const now = Date.now();
    const fields = {
      title: args.title?.trim() ?? event.title,
      notes: args.notes !== undefined ? args.notes.trim() || undefined : event.notes,
      location: args.location !== undefined ? args.location.trim() || undefined : event.location,
      kind: args.kind ?? event.kind,
      is_all_day: args.isAllDay ?? event.is_all_day,
      tz_offset: args.tzOffset ?? event.tz_offset,
      attendees: attendees ?? event.attendees,
      reminders: args.reminders ? cleanReminders(args.reminders) : event.reminders,
      url: args.url !== undefined ? args.url.trim() || undefined : event.url,
      // Three states, not two: absent leaves the budget alone, `null` removes
      // it, a number replaces it. A plain optional could not say "stop
      // budgeting this" without also being how you say "don't touch it".
      budget:
        args.budget === undefined
          ? event.budget
          : args.budget === null
            ? undefined
            : requireBudget(args.budget),
      currency:
        args.budget === null
          ? undefined
          : (args.currency ?? event.currency ?? (args.budget !== undefined ? "EUR" : undefined)),
      recipe_ids: recipeIds ? (recipeIds.length ? recipeIds : undefined) : event.recipe_ids,
    };

    if ((args.scope ?? "series") === "occurrence") {
      const from = args.occurrenceStart;
      if (from === undefined) throw new Error("Editing one occurrence needs its date");
      if (!event.recurrence) throw new Error("This event does not repeat");

      const exdates = [...new Set([...(event.exdates ?? []), from])];
      await ctx.db.patch(args.id, { exdates, updated: now });

      // The detached copy keeps the series' RSVPs: the people who said they
      // were coming to this Tuesday did not un-say it by it being moved.
      return await ctx.db.insert("events", {
        home_id: event.home_id,
        ...fields,
        starts_at: startsAt,
        ends_at: endsAt,
        recurrence: undefined,
        series_end: endsAt,
        rsvps: event.rsvps ?? [],
        created_by: event.created_by,
        created: now,
        updated: now,
      });
    }

    const recurrence =
      args.recurrence === undefined
        ? (event.recurrence as Recurrence | undefined)
        : normaliseRecurrence(args.recurrence ?? undefined, startsAt);

    // Moving the series invalidates the skip list: those instants no longer
    // name occurrences of anything, and keeping them would silently swallow a
    // date that now happens to line up.
    const moved = startsAt !== event.starts_at;

    await ctx.db.patch(args.id, {
      ...fields,
      starts_at: startsAt,
      ends_at: endsAt,
      recurrence,
      series_end: seriesEndFor(startsAt, endsAt, recurrence),
      exdates: moved ? [] : event.exdates,
      updated: now,
    });

    if (user._id !== event.created_by) {
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: event.home_id,
        actor: user._id,
        title: user.name ? `${user.name} changed an event` : "Event changed",
        body: fields.title ?? "An event was updated",
        category: "calendar",
        collapseId: `event-${args.id}`,
      });
    }

    return args.id;
  },
});

/** Deletes a whole series, or skips one date in it. */
export const remove = mutation({
  args: {
    id: v.id("events"),
    scope: v.optional(v.union(v.literal("series"), v.literal("occurrence"))),
    occurrenceStart: v.optional(v.number()),
  },
  handler: async (ctx, { id, scope, occurrenceStart }) => {
    const user = await requireUser(ctx);
    const event = await ctx.db.get(id);
    if (!event) return { ok: true };
    await requireDocHome(ctx, event, "Event");

    if ((scope ?? "series") === "occurrence") {
      if (occurrenceStart === undefined) {
        throw new Error("Skipping one occurrence needs its date");
      }
      const exdates = [...new Set([...(event.exdates ?? []), occurrenceStart])];
      await ctx.db.patch(id, { exdates, updated: Date.now() });
      return { ok: true };
    }

    // The links go before the row does: an expense pointing at a deleted event
    // is a dangling id that `detail` can never resolve and nothing will ever
    // clean up. The rows themselves survive — see `unlinkEvent`.
    await unlinkEvent(ctx, id);
    await ctx.db.delete(id);

    // Only for what has not happened yet. Announcing the deletion of last
    // month's dentist appointment is noise.
    if (event.series_end >= Date.now()) {
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: event.home_id,
        actor: user._id,
        title: user.name ? `${user.name} cancelled an event` : "Event cancelled",
        body: event.title ?? "An event was cancelled",
        category: "calendar",
      });
    }
    return { ok: true };
  },
});

/**
 * Says whether the caller is coming.
 *
 * Per series, not per occurrence: answering "every Tuesday" once is what people
 * mean, and an RSVP that had to be repeated weekly would simply be ignored.
 */
export const rsvp = mutation({
  args: { id: v.id("events"), status: v.union(rsvpStatus, v.null()) },
  handler: async (ctx, { id, status }) => {
    const user = await requireUser(ctx);
    const event = await ctx.db.get(id);
    if (!event) throw new Error("Event not found");
    await requireDocHome(ctx, event, "Event");

    const others = (event.rsvps ?? []).filter((r) => r.user_id !== user._id);
    const rsvps = status === null ? others : [...others, { user_id: user._id, status }];
    await ctx.db.patch(id, { rsvps, updated: Date.now() });
    return { ok: true };
  },
});

function normaliseRecurrence(
  rec: Recurrence | undefined,
  startsAt: number,
): Recurrence | undefined {
  if (!rec) return undefined;
  const interval = Math.min(Math.max(1, Math.floor(rec.interval || 1)), 99);
  const weekdays = rec.freq === "weekly" ? cleanWeekdays(rec.weekdays) : undefined;
  // An `until` before the first occurrence would produce a series with nothing
  // in it, which reads as an event that vanished on save.
  const until = rec.until !== undefined && rec.until >= startsAt ? rec.until : undefined;
  return {
    freq: rec.freq,
    interval,
    ...(weekdays && weekdays.length ? { weekdays } : {}),
    ...(until !== undefined ? { until } : {}),
  };
}

// MARK: - Reminders
//
// Same shape as the bill sweep, and the same rule: a nudge is recorded before
// it is sent, because a duplicate reminder is worse than a missed one.
//
// The difference is the clock. A bill is due on a *day*, so a daily sweep is
// exact enough; an event is at 18:30, and "half an hour before" has to mean
// something. Hence a quarter-hourly sweep and a set of offsets coarse enough
// (10 minutes at the finest) that landing anywhere inside a 15-minute bucket
// still reads as early rather than late.

type EventNudge = {
  eventId: Id<"events">;
  homeId: Id<"homes">;
  key: string;
  title: string;
  startsAt: number;
  minutesBefore: number;
};

export const pendingReminders = internalQuery({
  args: {},
  handler: async (ctx): Promise<EventNudge[]> => {
    const now = Date.now();
    // Only series that can still produce something. A finished one has nothing
    // left to announce, whatever its reminder list says.
    const events = await ctx.db
      .query("events")
      .withIndex("by_series_end", (q) => q.gte("series_end", now))
      .collect();

    const due: EventNudge[] = [];

    for (const event of events) {
      const offsets = cleanReminders(event.reminders);
      if (!offsets.length) continue;

      const sent = new Set(event.reminded ?? []);
      // The widest offset decides how far ahead to look; nothing beyond it can
      // be due yet.
      const horizon = now + Math.max(...offsets) * MINUTE;
      const duration = Math.max(0, event.ends_at - event.starts_at);

      for (const start of expand(event, now - duration, horizon)) {
        for (const minutes of offsets) {
          const fireAt = start - minutes * MINUTE;
          if (fireAt > now) continue;
          // A nudge whose event has already finished is not a reminder.
          if (start + duration < now) continue;
          const key = `${start}:${minutes}`;
          if (sent.has(key)) continue;
          due.push({
            eventId: event._id,
            homeId: event.home_id,
            key,
            title: event.title ?? "An event",
            startsAt: start,
            minutesBefore: minutes,
          });
        }
      }
    }

    return due;
  },
});

export const markReminded = internalMutation({
  args: { eventId: v.id("events"), key: v.string() },
  handler: async (ctx, { eventId, key }) => {
    const event = await ctx.db.get(eventId);
    if (!event) return;
    const reminded = event.reminded ?? [];
    if (reminded.includes(key)) return;

    // Pruned as it grows. A standing Tuesday is one row forever, and without
    // this its `reminded` array is an append-only log of every week since it
    // was created — a document that gets slower to read for as long as the
    // household keeps the event. Keys name the occurrence they belong to, so
    // anything a month past is safe to forget: that occurrence can never come
    // round again.
    const cutoff = Date.now() - 30 * DAY;
    const kept = reminded.filter((k) => {
      const start = Number(k.split(":")[0]);
      return !Number.isFinite(start) || start >= cutoff;
    });

    await ctx.db.patch(eventId, { reminded: [...kept, key] });
  },
});

export const sweepReminders = internalAction({
  args: {},
  handler: async (ctx): Promise<{ sent: number }> => {
    const due: EventNudge[] = await ctx.runQuery(internal.events.pendingReminders, {});
    let sent = 0;

    for (const nudge of due) {
      await ctx.runMutation(internal.events.markReminded, {
        eventId: nudge.eventId,
        key: nudge.key,
      });
      await ctx.runAction(internal.push.notifyHome, {
        homeId: nudge.homeId,
        title: nudge.title,
        body: reminderBody(nudge),
        category: "calendar",
        // One nudge per occurrence on the lock screen, whatever the offset:
        // "in an hour" being replaced by "in ten minutes" is the point.
        collapseId: `event-${nudge.eventId}-${nudge.startsAt}`,
      });
      sent++;
    }

    return { sent };
  },
});

function reminderBody(nudge: EventNudge): string {
  // No locale on the server, so this stays in whole units rather than pretending
  // to format a time. The notification's job is to get the screen opened.
  const m = nudge.minutesBefore;
  if (m === 0) return "Starting now";
  if (m < 60) return `Starts in ${m} minutes`;
  if (m < 1440) {
    const hours = Math.round(m / 60);
    return `Starts in ${hours} ${hours === 1 ? "hour" : "hours"}`;
  }
  const days = Math.round(m / 1440);
  return `Starts in ${days} ${days === 1 ? "day" : "days"}`;
}

// MARK: - Exported for tests / other modules

export const __internals = { expand, cleanReminders, cleanWeekdays, startOfDay, FOREVER };
