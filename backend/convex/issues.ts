// House problems.
//
// Everything in a shared home that is broken, and what the household is doing
// about it. This is deliberately not a second task list. A chore is a thing to
// *do* and it is finished the moment somebody does it; a problem is a thing that
// is *wrong*. It can outlive three attempts to fix it, it costs money, it needs
// parts, somebody has to be called, and — the part no task list can express —
// the same one comes back next winter. So it keeps its own state machine, its
// own history, and links out to the modules that already own the work rather
// than copying any of it:
//
//   the chore     -> tasks.issue_id
//   the visit     -> issues.event_id
//   the parts     -> shopping_items.issue_id
//   what it cost  -> expenses.issue_id
//
// Two reads serve the whole module and both are bounded by something a person
// has to act on to grow — what is still open, plus a window of what was fixed —
// rather than by the household's history. `byHome` is one query and not three
// on purpose: the counters, the charts and the rows under them are computed from
// the same read, so a badge saying "2 urgent" can never sit above three urgent
// rows. It is the same bargain `events:detail` and `finance:summary` make.

import {
  query,
  mutation,
  internalQuery,
  internalMutation,
  internalAction,
} from "./_generated/server";
import { v } from "convex/values";
import { Doc, Id } from "./_generated/dataModel";
import { MutationCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { requireMembers } from "./lib/relations";
import { outstandingNames } from "./lib/pending";

// ---------------------------------------------------------------------------
// Vocabulary
//
// Repeated from the schema rather than imported, exactly as `finance.ts` repeats
// its category union: these are argument validators, and a schema field
// validator is not one.

const issueStatus = v.union(
  v.literal("reported"),
  v.literal("acknowledged"),
  v.literal("scheduled"),
  v.literal("inProgress"),
  v.literal("blocked"),
  v.literal("fixed"),
  v.literal("wontFix"),
);

const issueSeverity = v.union(
  v.literal("cosmetic"),
  v.literal("minor"),
  v.literal("major"),
  v.literal("urgent"),
);

const issueArea = v.union(
  v.literal("kitchen"),
  v.literal("bathroom"),
  v.literal("bedroom"),
  v.literal("living"),
  v.literal("hallway"),
  v.literal("laundry"),
  v.literal("garage"),
  v.literal("garden"),
  v.literal("balcony"),
  v.literal("basement"),
  v.literal("roof"),
  v.literal("exterior"),
  v.literal("whole"),
  v.literal("other"),
);

const issueCategory = v.union(
  v.literal("plumbing"),
  v.literal("electrical"),
  v.literal("heating"),
  v.literal("appliance"),
  v.literal("furniture"),
  v.literal("structural"),
  v.literal("internet"),
  v.literal("pest"),
  v.literal("damp"),
  v.literal("safety"),
  v.literal("cosmetic"),
  v.literal("other"),
);

const shoppingCategory = v.union(
  v.literal("groceries"),
  v.literal("household"),
  v.literal("cleaning"),
  v.literal("other"),
);

type Status =
  | "reported"
  | "acknowledged"
  | "scheduled"
  | "inProgress"
  | "blocked"
  | "fixed"
  | "wontFix";
type Severity = "cosmetic" | "minor" | "major" | "urgent";
type Issue = Doc<"issues">;

// ---------------------------------------------------------------------------
// Constants

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * How many settled problems the module carries back with it.
 *
 * Same bargain as `tasks:listByHome` and `shopping:listByHome`, and for the same
 * reason: fixing something does not remove the row, it flips a flag, so a
 * household that uses this accumulates fixed problems forever. Two hundred is
 * well past where anybody scrolls their own repair history, and it is also
 * exactly the window every figure on the History face is computed over — so the
 * list and the statistics above it agree by construction.
 */
const CLOSED_WINDOW = 200;

/** Pictures per problem. Past this the detail sheet stops being readable. */
const MAX_PHOTOS = 6;

/** Parts that can be sent to the shopping list in one go. */
const MAX_PARTS = 40;

/** A comment, not an essay. Long enough for what actually happened. */
const MAX_COMMENT = 2000;

/** Longest a text field on a problem may be. */
const MAX_TEXT = 4000;

/**
 * The largest estimate this will hold, in minor units — the same ceiling
 * `finance.ts` puts on the ledger, for the same reason: `v.number()` is float64
 * and integer arithmetic over it stops being exact past 2^53.
 */
const MAX_MINOR_UNITS = 1_000_000_000_000;

/** Months of repair spend the History face totals. */
const SPEND_LOOKBACK_MONTHS = 12;

/**
 * How long a problem may sit untouched before the sweep says something.
 *
 * Long enough that a weekend counts as nothing happening rather than as
 * neglect, short enough that a leak nobody chased does not quietly become
 * furniture.
 */
const STALE_DAYS = 7;

/**
 * How far back the sweep still looks for a problem nobody has been told about.
 *
 * The nudge is recorded against `<last_activity_at>:stale`, so a problem that
 * has been announced once is never announced again until somebody touches it —
 * which means looking further back than this only ever re-reads problems that
 * have already had their nudge. The window exists for the other case: a stretch
 * where the cron did not run.
 */
const STALE_SWEEP_DAYS = 90;

/** How many problems one sweep will announce, so a bad day cannot fan out. */
const MAX_NUDGES = 60;

// ---------------------------------------------------------------------------
// Status

/** Whether a problem in this state is still outstanding. */
function isOpenStatus(status: Status): boolean {
  return status !== "fixed" && status !== "wontFix";
}

/**
 * How far along a status is, for sorting and for the stepper the client draws.
 *
 * `blocked` deliberately shares a rank with `inProgress`: being stuck on a part
 * is not progress, but it is not a step backwards either, and a household that
 * sees "blocked" sort below "reported" reads it as the problem having been
 * forgotten.
 */
function statusRank(status: Status): number {
  switch (status) {
    case "reported":
      return 0;
    case "acknowledged":
      return 1;
    case "scheduled":
      return 2;
    case "inProgress":
      return 3;
    case "blocked":
      return 3;
    case "fixed":
      return 4;
    case "wontFix":
      return 4;
  }
}

function severityRank(severity: Severity): number {
  switch (severity) {
    case "cosmetic":
      return 0;
    case "minor":
      return 1;
    case "major":
      return 2;
    case "urgent":
      return 3;
  }
}

// ---------------------------------------------------------------------------
// Text and numbers

function clean(value: string | undefined, limit = MAX_TEXT): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed.slice(0, limit) : undefined;
}

/** Rejects anything that is not a whole, positive, representable amount. */
function requireEstimate(amount: number): number {
  if (!Number.isFinite(amount) || Math.round(amount) !== amount) {
    throw new Error("An estimate has to be a whole number of cents");
  }
  if (amount <= 0) throw new Error("An estimate has to be more than zero");
  if (amount > MAX_MINOR_UNITS) throw new Error("That estimate is too large");
  return amount;
}

/**
 * Turns `_storage` ids into something the client can load *and* delete.
 *
 * Both halves, deliberately. Resolved URLs alone would mean the phone had to
 * work an id back out of a URL in order to remove a picture — and a signed
 * storage URL is not required to contain one, so that guess would delete the
 * wrong photo or none at all. A file that has gone is dropped instead of
 * becoming a broken image.
 */
async function photoRefs(
  ctx: { storage: { getUrl: (id: Id<"_storage">) => Promise<string | null> } },
  ids: Id<"_storage">[] | undefined,
): Promise<{ id: Id<"_storage">; url: string }[]> {
  if (!ids?.length) return [];
  const urls = await Promise.all(ids.map((id) => ctx.storage.getUrl(id)));
  return ids.flatMap((id, index) =>
    urls[index] === null ? [] : [{ id, url: urls[index] as string }],
  );
}

// ---------------------------------------------------------------------------
// The timeline
//
// Every entry is written through here, so a problem's history is a complete
// account of it rather than whatever each mutation remembered to log. The
// insert also stamps `last_activity_at`, which is what makes "nobody has touched
// this in a week" answerable — and what retires the stale nudge, since the key
// carries the activity time it was sent for.

type EntryKind = "comment" | "status" | "link" | "system";

async function record(
  ctx: MutationCtx,
  issue: Issue,
  entry: {
    kind: EntryKind;
    author?: Id<"users">;
    body?: string;
    from?: Status;
    to?: Status;
  },
  patch: Record<string, unknown> = {},
): Promise<void> {
  const now = Date.now();
  await ctx.db.insert("issue_comments", {
    issue_id: issue._id,
    home_id: issue.home_id,
    author_id: entry.author,
    kind: entry.kind,
    body: entry.body,
    from_status: entry.from,
    to_status: entry.to,
    created: now,
  });
  // Re-read rather than trust the caller's copy. `update` patches `due_by` and
  // `reminded` before calling this, so pruning against the document it loaded
  // would put back the very key that patch had just retired — a stale nudge key
  // that can never match anything again, resurrected on every edit.
  const fresh = (await ctx.db.get(issue._id)) ?? issue;
  await ctx.db.patch(issue._id, {
    ...patch,
    last_activity_at: now,
    // Any activity opens a new quiet stretch, so the nudge sent for the last
    // one stops counting and the next one is free to fire on its own account.
    // Exactly how paying a bill retires its reminders.
    reminded: prunedReminded(fresh.reminded, fresh.due_by),
    updated: now,
  });
}

/**
 * Drops the nudge keys that no longer apply.
 *
 * The overdue key is keyed by the due date, so moving the date retires it; the
 * stale key is keyed by the activity time, so any activity retires it — and
 * since this is called from `record`, which is what *causes* activity, the
 * stale key never survives a write. What is kept is the overdue key for the
 * date still standing.
 */
function prunedReminded(
  reminded: string[] | undefined,
  dueBy: number | undefined,
): string[] {
  if (!reminded?.length) return [];
  const keep = dueBy === undefined ? null : `${dueBy}:overdue`;
  return keep === null ? [] : reminded.filter((key) => key === keep);
}

// ---------------------------------------------------------------------------
// Reads

/**
 * The whole module, in one subscription.
 *
 * Rows and aggregates together, and deliberately so: the board's counters, the
 * room grid, the severity split and the list under them are all derived from
 * this one read, so none of them can contradict another. Three queries would be
 * three websocket subscriptions per open screen, three pushes on every comment,
 * and three chances for a badge to disagree with the list it sits over.
 *
 * Bounded by `by_home_open`: every outstanding problem, plus the `CLOSED_WINDOW`
 * most recently *reported* of the settled ones — every Convex index ends in
 * `_creationTime`, so that is the cheap bound, and the History face sorts what
 * comes back by when it was fixed. A fixed problem is a row that never goes
 * away on its own, so collecting them all would make this query slower every
 * month a household used it — the mistake `stats:forHome` and `events:detail`
 * were both rebuilt to stop making.
 */
export const byHome = query({
  args: { homeId: v.id("homes"), tzOffsetMinutes: v.optional(v.number()) },
  handler: async (ctx, { homeId, tzOffsetMinutes }) => {
    await requireHomeMember(ctx, homeId);
    const now = Date.now();
    const offset = tzOffsetMinutes ?? 0;

    const [open, closed, outstandingParts, recentSpend] = await Promise.all([
      ctx.db
        .query("issues")
        .withIndex("by_home_open", (q) => q.eq("home_id", homeId).eq("is_open", true))
        .collect(),
      ctx.db
        .query("issues")
        .withIndex("by_home_open", (q) => q.eq("home_id", homeId).eq("is_open", false))
        .order("desc")
        .take(CLOSED_WINDOW),
      // Parts still to buy, per problem.
      //
      // Free, in the sense that matters: this is the *outstanding* half of the
      // shopping list, which `lib/pending.ts` already reads for the Home tab
      // and which is bounded by what somebody has to buy rather than by what
      // the household has ever bought. Counting it here is what lets a row say
      // "2 parts still to get" without one indexed read per problem on screen.
      ctx.db
        .query("shopping_items")
        .withIndex("by_home_purchased", (q) =>
          q.eq("home_id", homeId).eq("is_purchased", false),
        )
        .collect(),
      // A year of repairs, and only a year. Bounded on the date rather than
      // collected whole, for the reason above — and a year is the window the
      // question is actually asked over ("what has this house cost us").
      ctx.db
        .query("expenses")
        .withIndex("by_home_spent", (q) =>
          q
            .eq("home_id", homeId)
            .gte("spent_at", now - SPEND_LOOKBACK_MONTHS * 30 * DAY_MS),
        )
        .collect(),
    ]);

    const rows = [...open, ...closed];

    // --- Per-problem rollups ------------------------------------------------
    const partsOpen = new Map<string, number>();
    for (const item of outstandingParts) {
      if (!item.issue_id) continue;
      partsOpen.set(item.issue_id, (partsOpen.get(item.issue_id) ?? 0) + 1);
    }

    const spentByIssue = new Map<string, { amount: number; currency: string }>();
    let repairYear = 0;
    let repairMonth = 0;
    let repairCurrency: string | null = null;
    const monthStart = startOfMonth(now, offset);
    for (const expense of recentSpend) {
      if (!expense.issue_id) continue;
      const previous = spentByIssue.get(expense.issue_id);
      // Per-problem sums are scoped to one currency, like every other sum in
      // this app: adding 500 lira to 20 euros is not a number, and no rate is
      // ever invented on a household's behalf. The first receipt sets it.
      if (!previous) {
        spentByIssue.set(expense.issue_id, {
          amount: expense.amount,
          currency: expense.currency,
        });
      } else if (previous.currency === expense.currency) {
        previous.amount += expense.amount;
      }
      // The year and month totals are scoped to one currency for the same
      // reason the per-problem ones are, and to the same currency the first
      // receipt was written in: adding 500 lira to 20 euros is not a number,
      // and no rate is ever invented on a household's behalf. A household that
      // pays for repairs in two currencies sees the figure for its main one.
      if (repairCurrency === null) repairCurrency = expense.currency;
      if (expense.currency !== repairCurrency) continue;
      repairYear += expense.amount;
      if (expense.spent_at >= monthStart) repairMonth += expense.amount;
    }

    // First photo only. The list draws one thumbnail per row, and resolving
    // every picture on every problem would be a storage read per photo on every
    // push — for pictures nothing on this screen is going to draw.
    const thumbnails = await Promise.all(
      rows.map((issue) =>
        issue.photos?.length ? ctx.storage.getUrl(issue.photos[0]) : null,
      ),
    );

    const issues = rows.map((issue, index) => ({
      ...issue,
      thumbnail_url: thumbnails[index],
      photo_count: issue.photos?.length ?? 0,
      /** Parts on the shopping list for this that nobody has bought yet. */
      parts_open: partsOpen.get(issue._id) ?? 0,
      /** What it has cost so far, in the currency its first receipt was in. */
      spent: spentByIssue.get(issue._id)?.amount ?? 0,
      spent_currency: spentByIssue.get(issue._id)?.currency ?? null,
      // Sent rather than left to the client so every screen ages a problem
      // against the same clock — the server's — instead of against a phone
      // whose own clock may be minutes out.
      age_days: Math.floor((now - (issue.created ?? issue._creationTime)) / DAY_MS),
    }));

    // --- Aggregates ---------------------------------------------------------
    const byStatus = new Map<string, number>();
    const bySeverity = new Map<string, number>();
    const byArea = new Map<string, number>();
    const byCategory = new Map<string, number>();
    const bump = (map: Map<string, number>, key: string) =>
      map.set(key, (map.get(key) ?? 0) + 1);

    let urgent = 0;
    let overdue = 0;
    let unassigned = 0;
    let oldestOpenAt: number | null = null;

    for (const issue of open) {
      bump(byStatus, issue.status);
      bump(bySeverity, issue.severity);
      bump(byArea, issue.area);
      bump(byCategory, issue.category);
      if (issue.severity === "urgent") urgent++;
      if (issue.due_by !== undefined && issue.due_by < now) overdue++;
      if (!issue.assigned_to) unassigned++;
      const reported = issue.created ?? issue._creationTime;
      if (oldestOpenAt === null || reported < oldestOpenAt) oldestOpenAt = reported;
    }

    // How long the household actually takes, over the settled window.
    //
    // Only problems that were *fixed* count. A `wontFix` was closed by a
    // decision rather than by work, and folding those in would make a household
    // that gave up on three things look fast.
    const fixed = closed.filter((i) => i.status === "fixed" && i.resolved_at !== undefined);
    const durations = fixed
      .map((i) => (i.resolved_at ?? 0) - (i.created ?? i._creationTime))
      .filter((ms) => ms >= 0)
      .sort((a, b) => a - b);
    const medianFixMs = durations.length
      ? durations[Math.floor(durations.length / 2)]
      : null;
    const fixedThisMonth = fixed.filter((i) => (i.resolved_at ?? 0) >= monthStart).length;

    // Where this house keeps going wrong.
    //
    // The one thing a list of problems cannot tell you by being read: that the
    // kitchen plumbing has now been fixed three times. Counted over everything
    // in the window, open and settled alike, because a fault that came back is
    // a fault that came back whatever state the latest report is in.
    const repeats = new Map<string, { area: string; category: string; count: number }>();
    for (const issue of rows) {
      const key = `${issue.area}|${issue.category}`;
      const entry = repeats.get(key);
      if (entry) entry.count++;
      else repeats.set(key, { area: issue.area, category: issue.category, count: 1 });
    }

    return {
      issues,
      summary: {
        open: open.length,
        closed: closed.length,
        urgent,
        overdue,
        unassigned,
        oldestOpenAt,
        fixedThisMonth,
        medianFixMs,
        repairSpentYear: repairYear,
        repairSpentMonth: repairMonth,
        repairCurrency,
        byStatus: [...byStatus.entries()].map(([status, count]) => ({ status, count })),
        bySeverity: [...bySeverity.entries()].map(([severity, count]) => ({
          severity,
          count,
        })),
        byArea: [...byArea.entries()]
          .map(([area, count]) => ({ area, count }))
          .sort((a, b) => b.count - a.count),
        byCategory: [...byCategory.entries()]
          .map(([category, count]) => ({ category, count }))
          .sort((a, b) => b.count - a.count),
        repeats: [...repeats.values()]
          .filter((r) => r.count > 1)
          .sort((a, b) => b.count - a.count)
          .slice(0, 6),
      },
    };
  },
});

/** Epoch-ms of local midnight on the 1st of the month `at` falls in. */
function startOfMonth(at: number, offsetMinutes: number): number {
  const local = new Date(at + offsetMinutes * 60_000);
  return (
    Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), 1) - offsetMinutes * 60_000
  );
}

/**
 * Everything hanging off one problem, in one subscription.
 *
 * The same argument `events:detail` makes: the timeline, the parts, the
 * receipts, the chore and the visit are five queries otherwise, five pushes on
 * every change, and five chances for the spend total to disagree with the list
 * under it. Rolled up here they are computed from one read.
 *
 * Every outward link is resolved *through* rather than trusted. A chore somebody
 * deleted, a visit that was cancelled, a receipt from a home this problem does
 * not belong to — each simply stops being shown, because the link was never an
 * owner. That is the same promise `expenses.event_id` makes, and it is why
 * closing a problem never has to reach into four other tables.
 */
export const detail = query({
  args: { id: v.id("issues") },
  handler: async (ctx, { id }) => {
    const issue = await ctx.db.get(id);
    if (!issue) return null;
    await requireDocHome(ctx, issue, "Problem");

    const [entries, parts, expenses, photos] = await Promise.all([
      ctx.db
        .query("issue_comments")
        .withIndex("by_issue", (q) => q.eq("issue_id", id))
        .collect(),
      ctx.db
        .query("shopping_items")
        .withIndex("by_issue", (q) => q.eq("issue_id", id))
        .collect(),
      ctx.db
        .query("expenses")
        .withIndex("by_issue", (q) => q.eq("issue_id", id))
        .collect(),
      photoRefs(ctx, issue.photos),
    ]);

    const [task, event, history] = await Promise.all([
      issue.task_id ? ctx.db.get(issue.task_id) : Promise.resolve(null),
      issue.event_id ? ctx.db.get(issue.event_id) : Promise.resolve(null),
      // What has gone wrong here before.
      //
      // Read from the settled bucket only: the point is "this has been fixed
      // twice already", and the other open problems are on the same screen
      // anyway. Bounded by the same window the module's list uses, so the
      // history a problem claims is history the household can actually go and
      // look at.
      ctx.db
        .query("issues")
        .withIndex("by_home_open", (q) =>
          q.eq("home_id", issue.home_id).eq("is_open", false),
        )
        .order("desc")
        .take(CLOSED_WINDOW),
    ]);

    const currency = issue.currency ?? expenses[0]?.currency ?? null;
    const spent = expenses
      .filter((e) => currency === null || e.currency === currency)
      .reduce((total, e) => total + e.amount, 0);

    return {
      issue: {
        ...issue,
        photo_refs: photos,
        photo_count: photos.length,
      },
      timeline: entries
        .map((entry) => ({
          _id: entry._id,
          kind: entry.kind,
          author_id: entry.author_id ?? null,
          body: entry.body ?? null,
          from_status: entry.from_status ?? null,
          to_status: entry.to_status ?? null,
          created: entry.created,
        }))
        .sort((a, b) => a.created - b.created),
      parts: parts
        .map((item) => ({
          _id: item._id,
          name: item.name ?? "",
          is_purchased: item.is_purchased ?? false,
          category: item.category ?? "other",
        }))
        .sort(
          (a, b) =>
            Number(a.is_purchased) - Number(b.is_purchased) ||
            a.name.localeCompare(b.name),
        ),
      parts_total: parts.length,
      parts_purchased: parts.filter((p) => p.is_purchased).length,
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
      currency,
      spent,
      /** The chore, if there is one and it still exists. */
      task:
        task && task.home_id === issue.home_id
          ? {
              _id: task._id,
              title: task.title ?? "",
              is_completed: task.is_completed ?? false,
              assigned_to: task.assigned_to ?? null,
              due_date: task.due_date ?? null,
            }
          : null,
      /** The visit, if there is one and it still exists. */
      event:
        event && event.home_id === issue.home_id
          ? {
              _id: event._id,
              title: event.title ?? "",
              starts_at: event.starts_at,
              ends_at: event.ends_at,
              location: event.location ?? null,
            }
          : null,
      /** Times this exact fault has been settled before, newest first. */
      previously: history
        .filter(
          (h) =>
            h._id !== issue._id &&
            h.area === issue.area &&
            h.category === issue.category,
        )
        .slice(0, 5)
        .map((h) => ({
          _id: h._id,
          title: h.title ?? "",
          status: h.status,
          resolved_at: h.resolved_at ?? null,
          resolution: h.resolution ?? null,
        })),
    };
  },
});

// ---------------------------------------------------------------------------
// Writing a problem

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    title: v.string(),
    details: v.optional(v.string()),
    area: issueArea,
    category: issueCategory,
    severity: issueSeverity,
    assignedTo: v.optional(v.id("users")),
    dueBy: v.optional(v.number()),
    costEstimate: v.optional(v.number()),
    currency: v.optional(v.string()),
    vendorName: v.optional(v.string()),
    vendorPhone: v.optional(v.string()),
    vendorUrl: v.optional(v.string()),
    warrantyUntil: v.optional(v.number()),
    photos: v.optional(v.array(v.id("_storage"))),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);

    const title = clean(args.title, 200);
    if (!title) throw new Error("Say what is wrong");
    if (args.assignedTo) {
      await requireMembers(ctx, home, [args.assignedTo], "Problem");
    }

    const now = Date.now();
    const id = await ctx.db.insert("issues", {
      home_id: args.homeId,
      title,
      details: clean(args.details),
      area: args.area,
      category: args.category,
      severity: args.severity,
      status: "reported",
      is_open: true,
      reported_by: user._id,
      assigned_to: args.assignedTo,
      photos: args.photos?.slice(0, MAX_PHOTOS),
      due_by: args.dueBy,
      cost_estimate:
        args.costEstimate === undefined ? undefined : requireEstimate(args.costEstimate),
      currency: args.currency,
      vendor_name: clean(args.vendorName, 120),
      vendor_phone: clean(args.vendorPhone, 40),
      vendor_url: clean(args.vendorUrl, 500),
      warranty_until: args.warrantyUntil,
      // Whoever reports it is by definition affected by it, so the count starts
      // at one rather than at nought. A "+1" control that reads 0 next to the
      // person who just filed the report is a control that has to be explained.
      me_too: [user._id],
      last_activity_at: now,
      reminded: [],
      created: now,
      updated: now,
    });

    // Scheduled, never awaited: a mutation must not block on APNs, and a push
    // that fails must not roll the report back.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title:
        args.severity === "urgent"
          ? "Something urgent needs fixing"
          : user.name
            ? `${user.name} reported a problem`
            : "New house problem",
      body: title,
      category: "issues",
    });

    // Deliberately no second push for the assignee.
    //
    // `notifyHome` excludes only the actor, so a report filed *and* handed to
    // somebody would reach that person twice for one event — which is how an
    // app gets muted. The household-wide fact is the one that matters when
    // something breaks; `issues:assign` carries the personal nudge for every
    // handoff after this one.

    return id;
  },
});

export const update = mutation({
  args: {
    id: v.id("issues"),
    title: v.optional(v.string()),
    details: v.optional(v.string()),
    area: v.optional(issueArea),
    category: v.optional(issueCategory),
    severity: v.optional(issueSeverity),
    /** `null` clears the date; absent leaves it alone. */
    dueBy: v.optional(v.union(v.number(), v.null())),
    /** `null` clears the estimate; absent leaves it alone. */
    costEstimate: v.optional(v.union(v.number(), v.null())),
    currency: v.optional(v.string()),
    vendorName: v.optional(v.string()),
    vendorPhone: v.optional(v.string()),
    vendorUrl: v.optional(v.string()),
    warrantyUntil: v.optional(v.union(v.number(), v.null())),
  },
  handler: async (ctx, { id, ...fields }) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");

    const title = fields.title === undefined ? issue.title : clean(fields.title, 200);
    if (fields.title !== undefined && !title) throw new Error("Say what is wrong");

    const dueBy =
      fields.dueBy === undefined ? issue.due_by : (fields.dueBy ?? undefined);

    await ctx.db.patch(id, {
      title,
      details:
        fields.details === undefined ? issue.details : clean(fields.details),
      area: fields.area ?? issue.area,
      category: fields.category ?? issue.category,
      severity: fields.severity ?? issue.severity,
      due_by: dueBy,
      cost_estimate:
        fields.costEstimate === undefined
          ? issue.cost_estimate
          : fields.costEstimate === null
            ? undefined
            : requireEstimate(fields.costEstimate),
      currency: fields.currency ?? issue.currency,
      vendor_name:
        fields.vendorName === undefined
          ? issue.vendor_name
          : clean(fields.vendorName, 120),
      vendor_phone:
        fields.vendorPhone === undefined
          ? issue.vendor_phone
          : clean(fields.vendorPhone, 40),
      vendor_url:
        fields.vendorUrl === undefined ? issue.vendor_url : clean(fields.vendorUrl, 500),
      warranty_until:
        fields.warrantyUntil === undefined
          ? issue.warranty_until
          : (fields.warrantyUntil ?? undefined),
      // Moving the date opens a new deadline, so the nudge sent for the old one
      // stops counting and the new one is free to fire.
      reminded:
        dueBy === issue.due_by
          ? issue.reminded
          : prunedReminded(issue.reminded, dueBy),
      updated: Date.now(),
    });

    // Getting worse is news; every other edit is bookkeeping and stays quiet.
    if (
      fields.severity &&
      severityRank(fields.severity) > severityRank(issue.severity) &&
      fields.severity === "urgent"
    ) {
      await record(ctx, issue, {
        kind: "system",
        author: user._id,
        body: "Raised to urgent",
      });
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: issue.home_id,
        actor: user._id,
        title: "A problem just got urgent",
        body: title ?? "A house problem",
        category: "issues",
      });
    }

    return await ctx.db.get(id);
  },
});

/**
 * Moves a problem along, and writes the move into its history.
 *
 * The one mutation allowed to touch `status`, so `is_open` — which two indexes
 * and every count in the module depend on — cannot fall out of step with it.
 */
export const setStatus = mutation({
  args: {
    id: v.id("issues"),
    status: issueStatus,
    /** Why it is stuck, for `blocked`; what fixed it, for `fixed`. */
    note: v.optional(v.string()),
  },
  handler: async (ctx, { id, status, note }) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");
    if (issue.status === status) return await ctx.db.get(id);

    const now = Date.now();
    const settled = !isOpenStatus(status);
    const text = clean(note, MAX_COMMENT);

    await record(
      ctx,
      issue,
      {
        kind: "status",
        author: user._id,
        body: text,
        from: issue.status,
        to: status,
      },
      {
        status,
        is_open: !settled,
        blocked_reason: status === "blocked" ? text : undefined,
        // Reopening a problem takes the resolution back with it. A row that
        // says it is broken and also says who fixed it and when is a row nobody
        // can read, and it would go on counting toward the household's
        // time-to-fix figures for a repair that did not hold.
        resolution: status === "fixed" ? (text ?? issue.resolution) : undefined,
        resolved_at: settled ? now : undefined,
        resolved_by: settled ? user._id : undefined,
      },
    );

    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: issue.home_id,
      actor: user._id,
      title:
        status === "fixed"
          ? "Fixed"
          : status === "blocked"
            ? "A repair is stuck"
            : "A problem moved on",
      body:
        status === "fixed" && user.name
          ? `${user.name} fixed ${issue.title ?? "a house problem"}`
          : (issue.title ?? "A house problem"),
      category: "issues",
    });

    return await ctx.db.get(id);
  },
});

export const assign = mutation({
  args: {
    id: v.id("issues"),
    /**
     * `null` takes the name off it.
     *
     * A nullable union rather than `v.optional`, because the client always
     * sends the key: an absent argument would read as "leave it alone", and
     * unassigning has to be sayable. `events:rsvp` takes the same shape for the
     * same reason — and Convex rejects an explicit null against `v.optional`,
     * so the two have to agree.
     */
    userId: v.union(v.id("users"), v.null()),
  },
  handler: async (ctx, { id, userId: requested }) => {
    // `null` on the wire, `undefined` in the document: Convex removes a field
    // patched with `undefined`, and "nobody" is the absence of an assignee
    // rather than a null stored under one.
    const userId = requested ?? undefined;
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    const home = await requireDocHome(ctx, issue, "Problem");
    if (issue.assigned_to === userId) return await ctx.db.get(id);
    if (userId) await requireMembers(ctx, home, [userId], "Problem");

    const assignee = userId ? await ctx.db.get(userId) : null;
    await record(
      ctx,
      issue,
      {
        kind: "system",
        author: user._id,
        body: assignee
          ? `Assigned to ${assignee.name ?? "a member of the household"}`
          : "Unassigned",
      },
      { assigned_to: userId },
    );

    if (userId && userId !== user._id) {
      await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
        userIds: [userId],
        actor: user._id,
        title: user.name ? `${user.name} asked you to fix this` : "A repair for you",
        body: issue.title ?? "A house problem",
        category: "issues",
      });
    }

    return await ctx.db.get(id);
  },
});

/**
 * "This is happening to me too."
 *
 * The cheapest useful signal a shared house has: one person reporting a cold
 * radiator is a note, three people reporting it is the heating. It costs a tap,
 * it needs no words, and it is what sorts the list.
 */
export const toggleMeToo = mutation({
  args: { id: v.id("issues") },
  handler: async (ctx, { id }) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");

    const current = issue.me_too ?? [];
    const has = current.some((u) => u === user._id);
    // Not routed through `record`: agreeing with a report is not an event in
    // its history, and a timeline that fills up with "+1" is a timeline nobody
    // reads. It deliberately does not count as activity either — a problem
    // three people have agreed about and nobody has acted on is exactly the one
    // the stale sweep exists to find.
    await ctx.db.patch(id, {
      me_too: has ? current.filter((u) => u !== user._id) : [...current, user._id],
      updated: Date.now(),
    });
    return { affected: has ? current.length - 1 : current.length + 1 };
  },
});

export const remove = mutation({
  args: { id: v.id("issues") },
  handler: async (ctx, { id }) => {
    const issue = await ctx.db.get(id);
    // Already gone — another member got there first, which is not an error.
    if (!issue) return { ok: true };
    await requireDocHome(ctx, issue, "Problem");

    const [entries, parts, expenses] = await Promise.all([
      ctx.db
        .query("issue_comments")
        .withIndex("by_issue", (q) => q.eq("issue_id", id))
        .collect(),
      ctx.db
        .query("shopping_items")
        .withIndex("by_issue", (q) => q.eq("issue_id", id))
        .collect(),
      ctx.db
        .query("expenses")
        .withIndex("by_issue", (q) => q.eq("issue_id", id))
        .collect(),
    ]);

    // The history goes with the problem — it is *of* it, and means nothing on
    // its own. Everything else is detached rather than deleted, exactly as
    // `unlinkEvent` detaches a cancelled party's: the washer is still needed
    // and the plumber's invoice is still money that moved, and a household's
    // balances must not change because somebody tidied a list. The chore is
    // left entirely alone; its dangling `issue_id` is read through a `get` that
    // now finds nothing, which is the same way every other link in this module
    // handles its target going away.
    await Promise.all([
      ...entries.map((e) => ctx.db.delete(e._id)),
      ...parts.map((p) =>
        ctx.db.patch(p._id, { issue_id: undefined, issue_title: undefined }),
      ),
      ...expenses.map((e) => ctx.db.patch(e._id, { issue_id: undefined })),
    ]);
    await ctx.db.delete(id);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// The timeline

export const comment = mutation({
  args: { id: v.id("issues"), body: v.string() },
  handler: async (ctx, { id, body }) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");

    const text = clean(body, MAX_COMMENT);
    if (!text) throw new Error("Write something first");

    await record(ctx, issue, { kind: "comment", author: user._id, body: text });

    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: issue.home_id,
      actor: user._id,
      title: user.name
        ? `${user.name} on ${issue.title ?? "a house problem"}`
        : "New note on a house problem",
      body: text,
      category: "issues",
    });

    return { ok: true };
  },
});

export const removeComment = mutation({
  args: { id: v.id("issue_comments") },
  handler: async (ctx, { id }) => {
    const user = await requireUser(ctx);
    const entry = await ctx.db.get(id);
    if (!entry) return { ok: true };
    await requireDocHome(ctx, entry, "Note");
    // Only what somebody wrote, and only by the person who wrote it. The rest
    // of the timeline is the record of what happened, and a history anybody can
    // edit is not a history.
    if (entry.kind !== "comment" || entry.author_id !== user._id) {
      throw new Error("Only your own notes can be removed");
    }
    await ctx.db.delete(id);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// Photos

/**
 * A one-shot URL the phone can PUT an image to.
 *
 * The bytes never pass through a mutation: Convex hands out a signed upload URL,
 * the client posts straight to it, and what comes back is a storage id that
 * `attachPhotos` files against the problem. That keeps a five-megapixel photo
 * out of the transaction that records it.
 */
export const uploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    await requireUser(ctx);
    return await ctx.storage.generateUploadUrl();
  },
});

export const attachPhotos = mutation({
  args: { id: v.id("issues"), storageIds: v.array(v.id("_storage")) },
  handler: async (ctx, { id, storageIds }) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");
    if (storageIds.length === 0) return { photos: issue.photos?.length ?? 0 };

    const existing = issue.photos ?? [];
    const merged = [...existing];
    for (const storageId of storageIds) {
      if (merged.length >= MAX_PHOTOS) break;
      if (!merged.includes(storageId)) merged.push(storageId);
    }

    await record(
      ctx,
      issue,
      {
        kind: "system",
        author: user._id,
        body:
          merged.length - existing.length === 1
            ? "Added a photo"
            : `Added ${merged.length - existing.length} photos`,
      },
      { photos: merged },
    );
    return { photos: merged.length };
  },
});

export const removePhoto = mutation({
  args: { id: v.id("issues"), storageId: v.id("_storage") },
  handler: async (ctx, { id, storageId }) => {
    await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");

    const remaining = (issue.photos ?? []).filter((p) => p !== storageId);
    await ctx.db.patch(id, { photos: remaining, updated: Date.now() });
    // Deleted, not orphaned. A file nothing points at is a file nothing will
    // ever point at again, and storage that only grows is storage somebody
    // eventually pays for.
    await ctx.storage.delete(storageId);
    return { photos: remaining.length };
  },
});

// ---------------------------------------------------------------------------
// The plan
//
// Three mutations that reach into three other modules, and all three write the
// *other* table's row rather than a copy of it. A repair that needs a chore, a
// visit and two parts should leave the task list, the calendar and the shopping
// list each holding exactly one more real row — not a private shadow of one
// that the rest of the app cannot see.

/**
 * Turns a problem into a chore somebody can be handed.
 *
 * Deliberately one-way and deliberately not automatic: not every problem needs
 * a chore ("call the landlord" is not a chore anybody in this house can do), and
 * a task list that silently doubled as the problem list would be the second list
 * this module exists to avoid.
 */
export const makeChore = mutation({
  args: {
    id: v.id("issues"),
    assignedTo: v.optional(v.id("users")),
    dueDate: v.optional(v.number()),
  },
  handler: async (ctx, { id, assignedTo, dueDate }) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    const home = await requireDocHome(ctx, issue, "Problem");

    // Already has one that still exists. Two chores for one fault is how a
    // household ends up arguing about which of them was done.
    if (issue.task_id) {
      const existing = await ctx.db.get(issue.task_id);
      if (existing) return { taskId: existing._id, created: false };
    }

    const assignee = assignedTo ?? issue.assigned_to;
    if (assignee) await requireMembers(ctx, home, [assignee], "Chore");

    const now = Date.now();
    const taskId = await ctx.db.insert("tasks", {
      home_id: issue.home_id,
      title: issue.title ?? "Fix it",
      description: issue.details,
      created_by: user._id,
      updated_by: user._id,
      assigned_to: assignee,
      is_completed: false,
      // Severity is the same statement priority is, in a vocabulary the task
      // list already speaks. Cosmetic and minor both map to `low`: a task list
      // with four priorities would be a fourth thing to keep in step.
      priority:
        issue.severity === "urgent"
          ? "high"
          : issue.severity === "major"
            ? "medium"
            : "low",
      type: "maintenance",
      due_date: dueDate ?? issue.due_by,
      issue_id: issue._id,
      created: now,
      updated: now,
    });

    await record(
      ctx,
      issue,
      { kind: "link", author: user._id, body: "Made it a chore" },
      {
        task_id: taskId,
        // A problem somebody has taken on is no longer merely reported. Left at
        // `reported` it would go on being counted as untriaged and go on being
        // swept as neglected, which is exactly wrong for the one that just got
        // a name against it.
        ...(issue.status === "reported"
          ? { status: "acknowledged" as const, is_open: true }
          : {}),
      },
    );

    if (assignee && assignee !== user._id) {
      await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
        userIds: [assignee],
        actor: user._id,
        title: user.name ? `${user.name} assigned you a repair` : "A repair for you",
        body: issue.title ?? "A house problem",
        category: "tasks",
      });
    }

    return { taskId, created: true };
  },
});

/**
 * Books the visit — the plumber, the engineer, the landlord's inspection.
 *
 * An ordinary calendar event that happens to know what it is for, rather than a
 * private appointment only this screen can see: the household's Saturday should
 * show the boiler engineer alongside everything else it is doing.
 */
export const scheduleVisit = mutation({
  args: {
    id: v.id("issues"),
    startsAt: v.number(),
    endsAt: v.number(),
    /** Whose visit it is. Defaults to the problem's vendor. */
    title: v.optional(v.string()),
    location: v.optional(v.string()),
    /** Whole minutes before to nudge the household. */
    reminders: v.optional(v.array(v.number())),
    /**
     * Minutes east of UTC where the visit was booked.
     *
     * A one-off cannot drift the way a series can, so nothing here reads it —
     * but every other row in `events` carries one, and an appointment written
     * without it is the row that trips up whatever reads them next.
     */
    tzOffset: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(args.id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");
    if (args.endsAt < args.startsAt) throw new Error("The visit ends before it starts");

    const title =
      clean(args.title, 200) ??
      (issue.vendor_name
        ? `${issue.vendor_name} — ${issue.title ?? "repair"}`
        : `Repair: ${issue.title ?? "house problem"}`);

    const reminders = [...new Set(args.reminders ?? [])]
      .filter((m) => Number.isFinite(m) && m >= 0)
      .map((m) => Math.round(m))
      .sort((a, b) => b - a)
      .slice(0, 3);

    const now = Date.now();

    // One problem, one visit ahead of it.
    //
    // A second tap on "book a visit" used to insert a second event and point
    // the problem at it, leaving the first standing in the household's calendar
    // with nothing referring to it — an appointment nobody could find their way
    // back to and nobody would think to cancel. So an upcoming visit is *moved*
    // rather than duplicated. One that has already happened is left alone: a
    // second callout is a real thing, and rewriting the record of the first
    // would lose what actually took place.
    const booked = issue.event_id ? await ctx.db.get(issue.event_id) : null;
    const rebooking =
      booked && booked.home_id === issue.home_id && booked.ends_at >= now
        ? booked
        : null;

    let eventId: Id<"events">;
    if (rebooking) {
      eventId = rebooking._id;
      await ctx.db.patch(eventId, {
        title,
        location: clean(args.location, 200),
        starts_at: args.startsAt,
        ends_at: args.endsAt,
        tz_offset: args.tzOffset ?? rebooking.tz_offset,
        series_end: args.endsAt,
        reminders,
        // A new time opens a new set of nudges; the ones sent for the old one
        // are about an appointment that is no longer happening.
        reminded: [],
        updated: now,
      });
    } else {
      eventId = await ctx.db.insert("events", {
        home_id: issue.home_id,
        title,
        notes: issue.details,
        location: clean(args.location, 200),
        kind: "appointment",
        starts_at: args.startsAt,
        ends_at: args.endsAt,
        is_all_day: false,
        tz_offset: args.tzOffset ?? 0,
        // A one-off, so the series ends when the appointment does — the
        // denormalised bound `events.by_home_series_end` ranges over.
        series_end: args.endsAt,
        reminders,
        reminded: [],
        created_by: user._id,
        created: now,
        updated: now,
      });
    }

    await record(
      ctx,
      issue,
      {
        kind: "link",
        author: user._id,
        body: rebooking ? "Moved the visit" : "Booked a visit",
      },
      {
        event_id: eventId,
        // A date in the diary is what "scheduled" means. Anything already
        // further along — being worked on, stuck, fixed — is left where it is.
        ...(statusRank(issue.status) < statusRank("scheduled")
          ? { status: "scheduled" as const, is_open: true }
          : {}),
      },
    );

    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: issue.home_id,
      actor: user._id,
      title: rebooking ? "A repair visit moved" : "A repair visit is booked",
      body: title,
      category: "calendar",
    });

    return { eventId };
  },
});

/**
 * Sends the parts to the shopping list, in one write.
 *
 * One mutation rather than one per part, for the reason
 * `shopping:createFromRecipe` gives: five parts is otherwise five writes, five
 * subscription pushes and five notifications. Anything already outstanding is
 * skipped — matched against the household's *whole* list rather than this
 * problem's slice, because a washer already on the list for the bathroom tap is
 * a washer you have.
 */
export const addParts = mutation({
  args: {
    id: v.id("issues"),
    names: v.array(v.string()),
    category: v.optional(shoppingCategory),
  },
  handler: async (ctx, { id, names, category }) => {
    const user = await requireUser(ctx);
    const issue = await ctx.db.get(id);
    if (!issue) throw new Error("Problem not found");
    await requireDocHome(ctx, issue, "Problem");

    const outstanding = await outstandingNames(ctx, issue.home_id);
    const seen = new Set<string>();
    const wanted: string[] = [];
    for (const raw of names.slice(0, MAX_PARTS)) {
      const name = raw.trim();
      if (!name) continue;
      const key = name.toLowerCase();
      if (outstanding.has(key) || seen.has(key)) continue;
      seen.add(key);
      wanted.push(name);
    }
    if (wanted.length === 0) {
      return { added: 0, skipped: names.filter((n) => n.trim()).length };
    }

    const now = Date.now();
    // Written in one round, not one part at a time: a mutation gets one second
    // of execution and awaiting each insert spends it on round trips.
    await Promise.all(
      wanted.map((name) =>
        ctx.db.insert("shopping_items", {
          home_id: issue.home_id,
          name,
          // Parts are hardware, not groceries. The list groups by aisle and
          // this is the aisle a washer is on.
          category: category ?? "household",
          is_purchased: false,
          issue_id: issue._id,
          issue_title: issue.title ?? "",
          created_by: user._id,
          updated_by: user._id,
          created: now,
          updated: now,
        }),
      ),
    );

    await record(ctx, issue, {
      kind: "link",
      author: user._id,
      body:
        wanted.length === 1
          ? `Added ${wanted[0]} to the shopping list`
          : `Added ${wanted.length} parts to the shopping list`,
    });

    // One notification for the batch, not one per part.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: issue.home_id,
      actor: user._id,
      title: user.name ? `${user.name} added parts` : "Parts added to the list",
      body: `${wanted.length} for ${issue.title ?? "a repair"}`,
      category: "shopping",
    });

    return { added: wanted.length, skipped: names.length - wanted.length };
  },
});

// ---------------------------------------------------------------------------
// Called from other modules

/**
 * Notes on a problem's timeline that its chore was finished.
 *
 * Called by `tasks:update`. Deliberately *not* a fix: "call the plumber" is a
 * chore somebody can finish while the tap goes on dripping, so the app says what
 * happened and leaves the household to say whether it worked. What it does do is
 * count as activity, which is right — somebody did the thing that was asked.
 */
export const noteChoreDone = internalMutation({
  args: { issueId: v.id("issues"), userId: v.id("users"), title: v.string() },
  handler: async (ctx, { issueId, userId, title }) => {
    const issue = await ctx.db.get(issueId);
    // The problem was deleted while its chore lived on. Nothing to say.
    if (!issue || !issue.is_open) return;
    await record(ctx, issue, {
      kind: "system",
      author: userId,
      body: `Finished the chore: ${title}`,
    });
  },
});

// ---------------------------------------------------------------------------
// The stale sweep
//
// A problem is only a problem while somebody remembers it. `crons.ts` runs this
// once a day and it says two things out loud: a repair with a date on it that
// has passed, and one nobody has touched in a week.
//
// Idempotence is the whole design, exactly as it is for the bill sweep. Every
// send is recorded before it goes out, keyed by the thing that caused it — the
// due date, or the moment activity last stopped — so a retry, a redeploy or a
// clock that runs it twice sends nothing twice, and any activity at all retires
// the key and lets the next quiet stretch nudge once on its own account.

type Nudge = {
  issueId: Id<"issues">;
  homeId: Id<"homes">;
  key: string;
  title: string;
  severity: Severity;
  reason: "overdue" | "stale";
  days: number;
};

export const pendingNudges = internalQuery({
  args: {},
  handler: async (ctx): Promise<Nudge[]> => {
    const now = Date.now();
    // Only the open problems that have been quiet long enough to have anything
    // to say. This is the one read in the module that serves every household at
    // once, so it is bounded on both ends — without the range it would be a
    // scan of every open problem in the deployment, growing with the number of
    // people using the app rather than with the work actually due.
    const rows = await ctx.db
      .query("issues")
      .withIndex("by_open_activity", (q) =>
        q
          .eq("is_open", true)
          .gte("last_activity_at", now - STALE_SWEEP_DAYS * DAY_MS)
          .lte("last_activity_at", now - STALE_DAYS * DAY_MS),
      )
      .collect();

    const due: Nudge[] = [];
    for (const issue of rows) {
      const sent = new Set(issue.reminded ?? []);

      // A date that has passed is the louder of the two, and it is the only one
      // a household explicitly asked for.
      if (issue.due_by !== undefined && issue.due_by < now) {
        const key = `${issue.due_by}:overdue`;
        if (!sent.has(key)) {
          due.push({
            issueId: issue._id,
            homeId: issue.home_id,
            key,
            title: issue.title ?? "A house problem",
            severity: issue.severity,
            reason: "overdue",
            days: Math.floor((now - issue.due_by) / DAY_MS),
          });
          continue;
        }
      }

      // Cosmetic problems are the ones a household has decided not to care
      // about yet. Nagging about the scuffed skirting board is how the useful
      // nudges get muted along with it.
      if (issue.severity === "cosmetic") continue;

      const key = `${issue.last_activity_at}:stale`;
      if (sent.has(key)) continue;
      due.push({
        issueId: issue._id,
        homeId: issue.home_id,
        key,
        title: issue.title ?? "A house problem",
        severity: issue.severity,
        reason: "stale",
        days: Math.floor((now - issue.last_activity_at) / DAY_MS),
      });
    }

    // Loudest first, so a capped sweep drops the least urgent rather than
    // whichever the index happened to yield last.
    return due
      .sort(
        (a, b) =>
          severityRank(b.severity) - severityRank(a.severity) || b.days - a.days,
      )
      .slice(0, MAX_NUDGES);
  },
});

export const markNudged = internalMutation({
  args: { issueId: v.id("issues"), key: v.string() },
  handler: async (ctx, { issueId, key }) => {
    const issue = await ctx.db.get(issueId);
    if (!issue) return;
    const reminded = issue.reminded ?? [];
    if (reminded.includes(key)) return;
    // Not through `record`: telling somebody about a problem is not something
    // that happened *to* the problem, and stamping `last_activity_at` here
    // would make the sweep reset the very clock it is reading.
    await ctx.db.patch(issueId, { reminded: [...reminded, key] });
  },
});

/**
 * Announces every problem that has gone quiet or gone past its date.
 *
 * Marked as sent *before* the push goes out. A duplicate nudge is a worse
 * failure than a missed one — people mute an app that repeats itself, and the
 * problem is on the screen either way.
 */
export const sweepStale = internalAction({
  args: {},
  handler: async (ctx): Promise<{ sent: number }> => {
    const due: Nudge[] = await ctx.runQuery(internal.issues.pendingNudges, {});
    let sent = 0;

    for (const nudge of due) {
      await ctx.runMutation(internal.issues.markNudged, {
        issueId: nudge.issueId,
        key: nudge.key,
      });
      await ctx.runAction(internal.push.notifyHome, {
        homeId: nudge.homeId,
        title: nudge.reason === "overdue" ? "A repair is overdue" : "Still not fixed",
        body: nudgeBody(nudge),
        category: "issues",
      });
      sent++;
    }

    return { sent };
  },
});

function nudgeBody(nudge: Nudge): string {
  const days = Math.max(nudge.days, 1);
  const unit = days === 1 ? "day" : "days";
  return nudge.reason === "overdue"
    ? `${nudge.title} was due ${days} ${unit} ago`
    : `Nobody has touched ${nudge.title} in ${days} ${unit}`;
}

// MARK: - Exported for tests / other modules

export const __internals = { isOpenStatus, statusRank, severityRank, prunedReminded };
