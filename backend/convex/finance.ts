// Bills & Finance.
//
// Three things live here and they are deliberately different shapes:
//
//   expenses    — money that was spent, and who it was spent on behalf of
//   settlements — money moved between members to square up; never a spend
//   bills       — a *schedule*, not a spend. Paying one writes an expense.
//
// Everything is in **minor units** (cents) as integers. The split maths is the
// reason: a three-way division of 10.00 has to come out as 334 + 333 + 333, and
// in floating-point euros it does not. `v.number()` is float64, so these are
// integer-valued doubles and every helper below rounds explicitly.
//
// The client draws charts, rings and a leaderboard from `summary`, which is one
// pass over the home's ledger returning about a kilobyte. It does not download
// the ledger to derive them — the same reasoning as `stats:forHome`.

import {
  query,
  mutation,
  internalQuery,
  internalMutation,
  internalAction,
} from "./_generated/server";
import { v } from "convex/values";
import { Doc, Id } from "./_generated/dataModel";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { requireMembers, requireRef, requireSameHome } from "./lib/relations";

const financeCategory = v.union(
  v.literal("groceries"),
  v.literal("utilities"),
  v.literal("rent"),
  v.literal("household"),
  v.literal("dining"),
  v.literal("transport"),
  v.literal("health"),
  v.literal("entertainment"),
  v.literal("subscriptions"),
  v.literal("other"),
);

const billCycle = v.union(
  v.literal("once"),
  v.literal("weekly"),
  v.literal("biweekly"),
  v.literal("monthly"),
  v.literal("quarterly"),
  v.literal("yearly"),
);

const splitMode = v.union(
  v.literal("equal"),
  v.literal("shares"),
  v.literal("exact"),
);

type Cycle = "once" | "weekly" | "biweekly" | "monthly" | "quarterly" | "yearly";
type Split = { user_id: Id<"users">; amount: number };

const DAY_MS = 24 * 60 * 60 * 1000;
/** How many nudges one bill may carry. Four is how a bill gets muted. */
const MAX_REMINDERS = 3;
/** The furthest ahead a reminder may be set. */
const MAX_REMINDER_DAYS = 30;
/** Months of history the spend chart shows, including the selected one. */
const SERIES_MONTHS = 6;
/**
 * How many events the Finance screen rolls up.
 *
 * A household plans a handful of things at a time; a list of every party it
 * has ever held is a different screen (the calendar) pretending to be this one.
 */
const MAX_EVENT_ROLLUP = 12;
/**
 * How far back an event with a budget but no spend yet is still worth showing.
 *
 * Bounded on purpose: without it, "which events have a budget" is a scan of
 * every event the household has ever held, and `summary` is on the hot path of
 * a screen that re-runs on every ledger push.
 */
const EVENT_LOOKBACK_MONTHS = 6;

// ---------------------------------------------------------------------------
// Money

/**
 * The largest amount this ledger will hold, in minor units.
 *
 * `v.number()` is float64, exact only to 2^53, and everything here is integer
 * arithmetic over these values — splitting, summing balances, totalling a
 * month. Past that limit the sums stop adding up silently, which is the worst
 * way for a ledger to fail. Three orders of magnitude of headroom, and still
 * ten billion in any major unit.
 */
const MAX_MINOR_UNITS = 1_000_000_000_000;

/** Rejects anything that is not a positive whole number of minor units. */
function requireAmount(amount: number, label = "Amount"): number {
  if (!Number.isFinite(amount) || Math.round(amount) !== amount) {
    throw new Error(`${label} must be a whole number of cents`);
  }
  if (amount <= 0) throw new Error(`${label} must be more than zero`);
  // Enforced here as well as in the field, because the field is a courtesy and
  // this is the invariant: no client version may write an amount the arithmetic
  // above cannot carry.
  if (amount > MAX_MINOR_UNITS) throw new Error(`${label} is too large`);
  return amount;
}

/**
 * Divides `total` as evenly as it goes, handing the remainder out one minor
 * unit at a time.
 *
 * The parts always sum to `total` exactly. Rounding each share independently
 * does not: three ways of 10.00 rounds to 3.33 each and loses a cent, which is
 * how a ledger ends up disagreeing with the expenses that built it.
 */
function splitEvenly(total: number, people: Id<"users">[]): Split[] {
  const n = people.length;
  const base = Math.floor(total / n);
  const remainder = total - base * n;
  return people.map((id, i) => ({ user_id: id, amount: base + (i < remainder ? 1 : 0) }));
}

/**
 * Divides `total` in proportion to weights, by largest remainder.
 *
 * Each share is floored, then the minor units that fall out of the flooring go
 * to the shares that lost the most to it — so the parts sum to `total` and the
 * person rounded down hardest is the one rounded back up.
 */
function splitByWeight(
  total: number,
  weights: { user_id: Id<"users">; weight: number }[],
): Split[] {
  const sum = weights.reduce((acc, w) => acc + w.weight, 0);
  if (!(sum > 0)) throw new Error("Shares have to add up to more than zero");

  const parts = weights.map((w, index) => {
    const exact = (total * w.weight) / sum;
    const floor = Math.floor(exact);
    return { index, user_id: w.user_id, amount: floor, fraction: exact - floor };
  });

  let remainder = total - parts.reduce((acc, p) => acc + p.amount, 0);
  // Biggest loser to the flooring first; ties by original order so the same
  // input always produces the same split.
  const order = [...parts].sort(
    (a, b) => b.fraction - a.fraction || a.index - b.index,
  );
  for (const part of order) {
    if (remainder <= 0) break;
    part.amount += 1;
    remainder -= 1;
  }

  return parts.map((p) => ({ user_id: p.user_id, amount: p.amount }));
}

/**
 * Turns what the composer was showing into the shares that get stored.
 *
 * The invariant — splits sum to the total, exactly — is enforced here rather
 * than trusted from the client, so no client version can write a ledger that
 * does not balance.
 */
function resolveSplits(
  amount: number,
  mode: "equal" | "shares" | "exact",
  participants: Id<"users">[],
  weights: { userId: Id<"users">; weight: number }[] | undefined,
  exact: { userId: Id<"users">; amount: number }[] | undefined,
): Split[] {
  switch (mode) {
    case "equal": {
      if (participants.length === 0) throw new Error("Choose who this is split between");
      return splitEvenly(amount, participants);
    }
    case "shares": {
      const rows = (weights ?? []).filter((w) => w.weight > 0);
      if (rows.length === 0) throw new Error("Give at least one person a share");
      return splitByWeight(
        amount,
        rows.map((w) => ({ user_id: w.userId, weight: w.weight })),
      );
    }
    case "exact": {
      const rows = (exact ?? []).filter((e) => e.amount !== 0);
      if (rows.length === 0) throw new Error("Enter what each person owes");
      const sum = rows.reduce((acc, e) => acc + e.amount, 0);
      if (sum !== amount) {
        // Said in minor units on purpose: the client formats the difference,
        // and it is the only message here a person is expected to act on.
        throw new Error(`The amounts add up to ${sum}, not ${amount}`);
      }
      for (const row of rows) requireAmount(row.amount, "Each share");
      return rows.map((e) => ({ user_id: e.userId, amount: e.amount }));
    }
  }
}

// ---------------------------------------------------------------------------
// Calendar
//
// Every date question here is a *wall clock* question — which month an expense
// landed in, what day a bill is due — so each one is answered by shifting the
// instant by the viewer's offset and then reading UTC parts. The server has no
// timezone of its own; without the offset a household in UTC+13 would see half
// its January in December.

function shifted(at: number, offset: number): Date {
  return new Date(at + offset * 60_000);
}

/** Epoch-ms of local midnight on the 1st. `month` is 1-12 and may overflow. */
function monthStart(year: number, month: number, offset: number): number {
  return Date.UTC(year, month - 1, 1) - offset * 60_000;
}

function monthKey(at: number, offset: number): string {
  const d = shifted(at, offset);
  return `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}`;
}

/**
 * The next occurrence of a recurring bill.
 *
 * Month arithmetic clamps rather than rolling over: the 31st of January
 * advances to the 28th of February, not to the 3rd of March, which is what
 * `setUTCMonth` alone would do and what makes a monthly bill wander forward a
 * few days a year.
 */
function nextDue(due: number, cycle: Cycle): number {
  const d = new Date(due);
  switch (cycle) {
    case "once":
      return due;
    case "weekly":
      return due + 7 * DAY_MS;
    case "biweekly":
      return due + 14 * DAY_MS;
    case "monthly":
      return addMonths(d, 1);
    case "quarterly":
      return addMonths(d, 3);
    case "yearly":
      return addMonths(d, 12);
  }
}

function addMonths(from: Date, months: number): number {
  const day = from.getUTCDate();
  const target = new Date(from.getTime());
  target.setUTCDate(1);
  target.setUTCMonth(target.getUTCMonth() + months);
  const lastDay = new Date(
    Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0),
  ).getUTCDate();
  target.setUTCDate(Math.min(day, lastDay));
  return target.getTime();
}

// ---------------------------------------------------------------------------
// Reminders

/** Whole days, deduplicated, soonest-to-due last, and never more than three. */
function cleanReminders(days: number[] | undefined): number[] {
  if (!days) return [];
  const kept = new Set<number>();
  for (const raw of days) {
    if (!Number.isFinite(raw)) continue;
    const day = Math.round(raw);
    if (day < 0 || day > MAX_REMINDER_DAYS) continue;
    kept.add(day);
  }
  return [...kept].sort((a, b) => b - a).slice(0, MAX_REMINDERS);
}

/**
 * Drops the keys belonging to a cycle that has closed.
 *
 * Keys carry the due date they were sent for, so paying a bill — which moves
 * `due_date` — retires all of them at once, and the list cannot grow without
 * bound over a bill's life.
 */
function prunedReminded(reminded: string[] | undefined, dueDate: number): string[] {
  const prefix = `${dueDate}:`;
  return (reminded ?? []).filter((key) => key.startsWith(prefix));
}

/** Local midnight, in whole days since the epoch. */
function dayNumber(at: number): number {
  return Math.floor(at / DAY_MS);
}

// ---------------------------------------------------------------------------
// Reads

/**
 * One month of the ledger, newest first.
 *
 * Month-scoped rather than "everything": the screen is driven by a month
 * scrubber, and a household two years in would otherwise ship its whole history
 * to draw one page.
 */
export const listExpenses = query({
  args: {
    homeId: v.id("homes"),
    year: v.number(),
    month: v.number(),
    tzOffsetMinutes: v.optional(v.number()),
  },
  handler: async (ctx, { homeId, year, month, tzOffsetMinutes }) => {
    await requireHomeMember(ctx, homeId);
    const offset = tzOffsetMinutes ?? 0;
    const start = monthStart(year, month, offset);
    const end = monthStart(year, month + 1, offset);

    const rows = await ctx.db
      .query("expenses")
      .withIndex("by_home_spent", (q) =>
        q.eq("home_id", homeId).gte("spent_at", start).lt("spent_at", end),
      )
      .order("desc")
      .collect();

    // Read through, not denormalised. `shopping_items` keeps a copy of the
    // event title because the shopping screen subscribes to items alone; the
    // ledger already reads its rows here, so one `get` per *distinct* event in
    // the month buys the same label without a copy that can go stale when the
    // party is renamed. A row whose event has since been deleted simply loses
    // its label — the money still moved, which is why the link was never an
    // owner.
    const titles = new Map<string, string | null>();
    const linked = [...new Set(rows.flatMap((e) => (e.event_id ? [e.event_id] : [])))];
    for (const [index, event] of (
      await Promise.all(linked.map((id) => ctx.db.get(id)))
    ).entries()) {
      titles.set(
        linked[index],
        event && event.home_id === homeId ? (event.title ?? "") : null,
      );
    }

    return rows.map((e) => ({
      ...e,
      event_title: e.event_id ? (titles.get(e.event_id) ?? null) : null,
    }));
  },
});

/** Every bill the household still keeps, soonest due first. */
export const listBills = query({
  args: { homeId: v.id("homes"), includeArchived: v.optional(v.boolean()) },
  handler: async (ctx, { homeId, includeArchived }) => {
    await requireHomeMember(ctx, homeId);
    const bills = await ctx.db
      .query("bills")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
    return bills
      .filter((b) => (includeArchived ? true : !b.is_archived))
      .sort((a, b) => a.due_date - b.due_date);
  },
});

export const listBudgets = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("budgets")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
  },
});

/** The most recent squarings-up, newest first. */
export const listSettlements = query({
  args: { homeId: v.id("homes"), limit: v.optional(v.number()) },
  handler: async (ctx, { homeId, limit }) => {
    await requireHomeMember(ctx, homeId);
    const rows = await ctx.db
      .query("settlements")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
    return rows
      .sort((a, b) => b.settled_at - a.settled_at)
      .slice(0, Math.max(1, Math.min(limit ?? 20, 100)));
  },
});

/**
 * Everything the Finance screen draws, computed in one pass.
 *
 * Balances are all-time and the spend figures are month-scoped, and that
 * asymmetry is the point: what you owe somebody does not reset in January, but
 * what the household spent very much does.
 */
export const summary = query({
  args: {
    homeId: v.id("homes"),
    year: v.number(),
    month: v.number(),
    tzOffsetMinutes: v.optional(v.number()),
    /**
     * Which currency the aggregates are about. Omitted means "whichever this
     * household mostly uses", which is what the screen opens on.
     *
     * Everything below is scoped to one currency because adding 500 lira to 20
     * dollars is not a number. A household that pays rent in one currency and a
     * holiday in another gets two sets of figures, and no conversion is
     * invented on its behalf.
     */
    currency: v.optional(v.string()),
  },
  handler: async (ctx, { homeId, year, month, tzOffsetMinutes, currency: wanted }) => {
    await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    const offset = tzOffsetMinutes ?? 0;

    const [allExpenses, allSettlements, allBills, budgets] = await Promise.all([
      ctx.db.query("expenses").withIndex("by_home", (q) => q.eq("home_id", homeId)).collect(),
      ctx.db.query("settlements").withIndex("by_home", (q) => q.eq("home_id", homeId)).collect(),
      ctx.db.query("bills").withIndex("by_home", (q) => q.eq("home_id", homeId)).collect(),
      ctx.db.query("budgets").withIndex("by_home", (q) => q.eq("home_id", homeId)).collect(),
    ]);

    // Every currency the household actually writes in, most-used first. The
    // screen offers these and nothing else — an empty picker of 150 ISO codes
    // is a worse answer than the three a household really uses.
    const votes = new Map<string, number>();
    const bump = (map: Map<string, number>, key: string, by: number) =>
      map.set(key, (map.get(key) ?? 0) + by);
    for (const e of allExpenses) bump(votes, e.currency, 1);
    for (const b of allBills) if (!b.is_archived) bump(votes, b.currency, 1);
    for (const b of budgets) bump(votes, b.currency, 1);
    const currencies = [...votes.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map(([code]) => code);

    // The asked-for currency, if the household uses it; otherwise its main one.
    const currency =
      wanted && (votes.has(wanted) || currencies.length === 0)
        ? wanted
        : (currencies[0] ?? wanted ?? null);

    const expenses = allExpenses.filter((e) => e.currency === currency);
    const settlements = allSettlements.filter((s) => s.currency === currency);

    const memberIds = home.members ?? [];
    const start = monthStart(year, month, offset);
    const end = monthStart(year, month + 1, offset);

    // --- Balances, all time ------------------------------------------------
    //
    // Positive means the household owes them. An expense credits whoever paid
    // and debits everyone it was split across; a settlement moves the same
    // money the other way without anything being spent.
    const paidAll = new Map<string, number>();
    const owedAll = new Map<string, number>();
    const net = new Map<string, number>();

    for (const e of expenses) {
      bump(paidAll, e.paid_by, e.amount);
      bump(net, e.paid_by, e.amount);
      for (const s of e.splits) {
        bump(owedAll, s.user_id, s.amount);
        bump(net, s.user_id, -s.amount);
      }
    }
    for (const s of settlements) {
      bump(net, s.from_user, s.amount);
      bump(net, s.to_user, -s.amount);
    }

    // --- The selected month ------------------------------------------------
    const inMonth = expenses.filter((e) => e.spent_at >= start && e.spent_at < end);
    const byCategory = new Map<string, number>();
    const paidMonth = new Map<string, number>();
    const shareMonth = new Map<string, number>();
    let monthTotal = 0;

    for (const e of inMonth) {
      monthTotal += e.amount;
      bump(byCategory, e.category ?? "other", e.amount);
      bump(paidMonth, e.paid_by, e.amount);
      for (const s of e.splits) bump(shareMonth, s.user_id, s.amount);
    }

    const prevStart = monthStart(year, month - 1, offset);
    const prevTotal = expenses
      .filter((e) => e.spent_at >= prevStart && e.spent_at < start)
      .reduce((acc, e) => acc + e.amount, 0);

    // --- Six months of history --------------------------------------------
    const buckets = new Map<string, number>();
    for (const e of expenses) bump(buckets, monthKey(e.spent_at, offset), e.amount);

    const series: { year: number; month: number; total: number }[] = [];
    for (let back = SERIES_MONTHS - 1; back >= 0; back--) {
      const at = new Date(Date.UTC(year, month - 1 - back, 1));
      const y = at.getUTCFullYear();
      const m = at.getUTCMonth() + 1;
      series.push({ year: y, month: m, total: buckets.get(`${y}-${m}`) ?? 0 });
    }

    // --- People ------------------------------------------------------------
    //
    // Built from the membership *plus* anyone carrying a balance, so a person
    // who has left the household still shows what is owed to or by them rather
    // than quietly taking the money with them.
    const involved = new Set<string>(memberIds.map(String));
    for (const [id, value] of net) if (value !== 0) involved.add(id);

    const docs = await Promise.all(
      [...involved].map((id) => ctx.db.get(id as Id<"users">)),
    );
    const isMember = new Set(memberIds.map(String));
    const members = docs
      .filter((u): u is Doc<"users"> => u !== null)
      .map((u) => ({
        userId: u._id,
        name: u.name,
        email: u.email,
        isMember: isMember.has(u._id),
        paid: paidAll.get(u._id) ?? 0,
        owed: owedAll.get(u._id) ?? 0,
        net: net.get(u._id) ?? 0,
        paidThisMonth: paidMonth.get(u._id) ?? 0,
        shareThisMonth: shareMonth.get(u._id) ?? 0,
      }));

    // --- Settling up -------------------------------------------------------
    //
    // The fewest payments that clear every balance: repeatedly match whoever is
    // owed the most against whoever owes the most. A household of four with
    // tangled debts settles in three transfers rather than twelve.
    const creditors = members
      .filter((m) => m.net > 0)
      .map((m) => ({ id: m.userId, amount: m.net }))
      .sort((a, b) => b.amount - a.amount);
    const debtors = members
      .filter((m) => m.net < 0)
      .map((m) => ({ id: m.userId, amount: -m.net }))
      .sort((a, b) => b.amount - a.amount);

    const transfers: { from: Id<"users">; to: Id<"users">; amount: number }[] = [];
    let ci = 0;
    let di = 0;
    while (ci < creditors.length && di < debtors.length) {
      const take = Math.min(creditors[ci].amount, debtors[di].amount);
      if (take > 0) {
        transfers.push({ from: debtors[di].id, to: creditors[ci].id, amount: take });
      }
      creditors[ci].amount -= take;
      debtors[di].amount -= take;
      if (creditors[ci].amount === 0) ci++;
      if (debtors[di].amount === 0) di++;
    }

    // --- Budgets -----------------------------------------------------------
    //
    // Counted in the budget's *own* currency rather than the selected one. A
    // grocery budget set in lira is a statement about lira groceries, and it
    // must not fill up because somebody bought coffee in euros.
    const spentByCurrencyCategory = new Map<string, number>();
    for (const e of allExpenses) {
      if (e.spent_at < start || e.spent_at >= end) continue;
      bump(spentByCurrencyCategory, `${e.currency}|${e.category ?? "other"}`, e.amount);
    }
    const budgetRows = budgets.map((b) => ({
      category: b.category,
      limit: b.limit,
      currency: b.currency,
      spent: spentByCurrencyCategory.get(`${b.currency}|${b.category}`) ?? 0,
    }));

    // --- Events ------------------------------------------------------------
    //
    // The one place the calendar's money reaches Finance. Both halves of it
    // were already stored and neither was ever shown here: an event keeps its
    // own cap on its own document (`events.budget`, in the event's own
    // currency), and money spent on it is ordinary ledger rows carrying an
    // `event_id`. So a budget set for Saturday's party appeared nowhere in
    // Finance at all, and its expenses appeared as unexplained lines in the
    // ledger with nothing tying them to the party.
    //
    // Deliberately *not* month-scoped, unlike everything above. An expense for
    // an event is dated to the event — the composer does that on purpose — so
    // the deposit paid in March for an April party is in neither month you
    // would think to look in. An event is a thing with a beginning and an end,
    // and what it cost is a total over that, not over whichever month the
    // scrubber is parked on.
    const linkedByEvent = new Map<string, Doc<"expenses">[]>();
    for (const e of allExpenses) {
      if (!e.event_id) continue;
      const list = linkedByEvent.get(e.event_id);
      if (list) list.push(e);
      else linkedByEvent.set(e.event_id, [e]);
    }

    // Recent and upcoming events, so one that has been budgeted but not yet
    // spent on still shows — otherwise setting a budget and coming here to look
    // at it shows nothing until the first receipt lands.
    const recentEvents = await ctx.db
      .query("events")
      .withIndex("by_home_series_end", (q) =>
        q
          .eq("home_id", homeId)
          .gte("series_end", monthStart(year, month - EVENT_LOOKBACK_MONTHS, offset)),
      )
      .collect();

    const eventDocs = new Map<string, Doc<"events">>();
    for (const ev of recentEvents) eventDocs.set(ev._id, ev);
    // An event with spend on it always shows, however old — the money is in
    // the ledger either way, and a row nobody can explain is worse than an old
    // one. Only the ones the window missed cost a read.
    const missing = [...linkedByEvent.keys()].filter((id) => !eventDocs.has(id));
    for (const ev of await Promise.all(
      missing.map((id) => ctx.db.get(id as Id<"events">)),
    )) {
      if (ev) eventDocs.set(ev._id, ev);
    }

    const eventRows = [...eventDocs.values()]
      .filter((ev) => ev.home_id === homeId)
      .map((ev) => {
        const linked = linkedByEvent.get(ev._id) ?? [];
        // The event's own currency wins; with none set it is whatever its
        // receipts were written in. The same rule its own plan card follows.
        const evCurrency = ev.currency ?? linked[0]?.currency ?? null;
        return {
          eventId: ev._id,
          title: ev.title ?? "",
          startsAt: ev.starts_at,
          kind: ev.kind ?? null,
          currency: evCurrency,
          budget: ev.budget ?? null,
          // Scoped to the event's own currency, like every other sum here.
          spent: linked
            .filter((e) => evCurrency === null || e.currency === evCurrency)
            .reduce((total, e) => total + e.amount, 0),
          // A count, not a sum, so it is not scoped — the same asymmetry the
          // overdue-bills badge follows.
          expenseCount: linked.length,
        };
      })
      // An event denominated in a currency this screen is not showing belongs
      // to the other set of figures, not to this one.
      .filter((row) => row.currency === currency)
      .filter((row) => row.budget !== null || row.expenseCount > 0)
      .sort((a, b) => b.startsAt - a.startsAt)
      .slice(0, MAX_EVENT_ROLLUP);

    return {
      year,
      month,
      currency,
      currencies,
      monthTotal,
      previousMonthTotal: prevTotal,
      expenseCount: inMonth.length,
      members,
      transfers,
      series,
      categories: [...byCategory.entries()]
        .map(([category, total]) => ({ category, total }))
        .sort((a, b) => b.total - a.total),
      budgets: budgetRows,
      events: eventRows,
      // No bill digest: the client has the whole bill list live and counts it
      // there. A count computed here would be scoped to one currency while the
      // list on screen is not, so "2 overdue" would sit above three overdue
      // rows.
    };
  },
});

// ---------------------------------------------------------------------------
// Expenses

export const createExpense = mutation({
  args: {
    homeId: v.id("homes"),
    title: v.string(),
    amount: v.number(),
    currency: v.string(),
    category: v.optional(financeCategory),
    paidBy: v.id("users"),
    spentAt: v.number(),
    mode: splitMode,
    participants: v.array(v.id("users")),
    weights: v.optional(
      v.array(v.object({ userId: v.id("users"), weight: v.number() })),
    ),
    exact: v.optional(
      v.array(v.object({ userId: v.id("users"), amount: v.number() })),
    ),
    note: v.optional(v.string()),
    billId: v.optional(v.id("bills")),
    /** Set when this was spent on something in the calendar. */
    eventId: v.optional(v.id("events")),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    const amount = requireAmount(args.amount);

    const title = args.title.trim();
    if (!title) throw new Error("Give the expense a name");

    // An expense may only point at an event this household can see — otherwise
    // the event's plan would total money from a home it has no access to.
    if (args.eventId) {
      const event = await requireRef(ctx, args.eventId, "Event");
      requireSameHome(event, args.homeId, "Event");
    }

    const touched = new Set<Id<"users">>([args.paidBy, ...args.participants]);
    for (const w of args.weights ?? []) touched.add(w.userId);
    for (const e of args.exact ?? []) touched.add(e.userId);
    await requireMembers(ctx, home, [...touched], "Expense");

    const splits = resolveSplits(
      amount,
      args.mode,
      args.participants,
      args.weights,
      args.exact,
    );

    const now = Date.now();
    const id = await ctx.db.insert("expenses", {
      home_id: args.homeId,
      title,
      amount,
      currency: args.currency,
      category: args.category,
      paid_by: args.paidBy,
      splits,
      split_mode: args.mode,
      weights: args.weights?.map((w) => ({ user_id: w.userId, weight: w.weight })),
      note: args.note?.trim() || undefined,
      spent_at: args.spentAt,
      bill_id: args.billId,
      event_id: args.eventId,
      created_by: user._id,
      created: now,
      updated: now,
    });

    // Scheduled, never awaited: a mutation must not block on APNs, and a push
    // that fails must not roll the expense back.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: user.name ? `${user.name} added an expense` : "New expense",
      body: title,
      category: "finance",
    });

    return id;
  },
});

export const updateExpense = mutation({
  args: {
    id: v.id("expenses"),
    title: v.optional(v.string()),
    amount: v.optional(v.number()),
    currency: v.optional(v.string()),
    category: v.optional(financeCategory),
    paidBy: v.optional(v.id("users")),
    spentAt: v.optional(v.number()),
    mode: v.optional(splitMode),
    participants: v.optional(v.array(v.id("users"))),
    weights: v.optional(
      v.array(v.object({ userId: v.id("users"), weight: v.number() })),
    ),
    exact: v.optional(
      v.array(v.object({ userId: v.id("users"), amount: v.number() })),
    ),
    note: v.optional(v.string()),
    /** `null` unlinks it from its event; absent leaves the link alone. */
    eventId: v.optional(v.union(v.id("events"), v.null())),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const expense = await ctx.db.get(args.id);
    if (!expense) throw new Error("Expense not found");
    const home = await requireDocHome(ctx, expense, "Expense");

    if (args.eventId) {
      const event = await requireRef(ctx, args.eventId, "Event");
      requireSameHome(event, home._id, "Event");
    }

    const amount = args.amount === undefined ? expense.amount : requireAmount(args.amount);
    const mode = args.mode ?? expense.split_mode;
    const paidBy = args.paidBy ?? expense.paid_by;

    // Re-resolving the split on every edit is the point: changing the total of
    // an equal split has to move everyone's share with it, and leaving the old
    // amounts in place is exactly how a ledger stops balancing.
    const participants =
      args.participants ?? expense.splits.map((s) => s.user_id);
    const weights =
      args.weights ??
      expense.weights?.map((w) => ({ userId: w.user_id, weight: w.weight }));
    const exact =
      args.exact ??
      (mode === "exact"
        ? expense.splits.map((s) => ({ userId: s.user_id, amount: s.amount }))
        : undefined);

    const touched = new Set<Id<"users">>([paidBy, ...participants]);
    for (const w of weights ?? []) touched.add(w.userId);
    for (const e of exact ?? []) touched.add(e.userId);
    await requireMembers(ctx, home, [...touched], "Expense");

    const splits =
      // An exact split whose total changed cannot be carried over untouched —
      // `resolveSplits` refuses it, which is the correct answer.
      resolveSplits(amount, mode, participants, weights, exact);

    await ctx.db.patch(args.id, {
      title: args.title?.trim() || expense.title,
      amount,
      currency: args.currency ?? expense.currency,
      category: args.category ?? expense.category,
      paid_by: paidBy,
      splits,
      split_mode: mode,
      weights: weights?.map((w) => ({ user_id: w.userId, weight: w.weight })),
      note: args.note === undefined ? expense.note : args.note.trim() || undefined,
      spent_at: args.spentAt ?? expense.spent_at,
      event_id:
        args.eventId === undefined
          ? expense.event_id
          : (args.eventId ?? undefined),
      updated: Date.now(),
    });
    void user;
    return await ctx.db.get(args.id);
  },
});

export const removeExpense = mutation({
  args: { id: v.id("expenses") },
  handler: async (ctx, { id }) => {
    const expense = await ctx.db.get(id);
    // Already gone — another member got there first, which is not an error.
    if (!expense) return { ok: true };
    await requireDocHome(ctx, expense, "Expense");
    await ctx.db.delete(id);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// Settling up

export const settle = mutation({
  args: {
    homeId: v.id("homes"),
    fromUser: v.id("users"),
    toUser: v.id("users"),
    amount: v.number(),
    currency: v.string(),
    note: v.optional(v.string()),
    settledAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    const amount = requireAmount(args.amount);
    if (args.fromUser === args.toUser) {
      throw new Error("A payment needs two different people");
    }
    await requireMembers(ctx, home, [args.fromUser, args.toUser], "Settlement");

    const now = Date.now();
    const id = await ctx.db.insert("settlements", {
      home_id: args.homeId,
      from_user: args.fromUser,
      to_user: args.toUser,
      amount,
      currency: args.currency,
      note: args.note?.trim() || undefined,
      settled_at: args.settledAt ?? now,
      created_by: user._id,
      created: now,
      updated: now,
    });

    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: "Settled up",
      body: user.name ? `${user.name} recorded a payment` : "A payment was recorded",
      category: "finance",
    });

    return id;
  },
});

export const removeSettlement = mutation({
  args: { id: v.id("settlements") },
  handler: async (ctx, { id }) => {
    const row = await ctx.db.get(id);
    if (!row) return { ok: true };
    await requireDocHome(ctx, row, "Settlement");
    await ctx.db.delete(id);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// Bills

export const createBill = mutation({
  args: {
    homeId: v.id("homes"),
    title: v.string(),
    amount: v.number(),
    currency: v.string(),
    category: v.optional(financeCategory),
    cycle: billCycle,
    dueDate: v.number(),
    responsible: v.optional(v.id("users")),
    autoSplit: v.optional(v.boolean()),
    reminders: v.optional(v.array(v.number())),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    const amount = requireAmount(args.amount);
    const title = args.title.trim();
    if (!title) throw new Error("Give the bill a name");
    if (args.responsible) {
      await requireMembers(ctx, home, [args.responsible], "Bill");
    }

    const now = Date.now();
    const id = await ctx.db.insert("bills", {
      home_id: args.homeId,
      title,
      amount,
      currency: args.currency,
      category: args.category,
      cycle: args.cycle,
      due_date: args.dueDate,
      responsible: args.responsible,
      auto_split: args.autoSplit ?? true,
      is_archived: false,
      reminders: cleanReminders(args.reminders),
      reminded: [],
      created_by: user._id,
      created: now,
      updated: now,
    });

    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: "New bill",
      body: title,
      category: "finance",
    });

    return id;
  },
});

export const updateBill = mutation({
  args: {
    id: v.id("bills"),
    title: v.optional(v.string()),
    amount: v.optional(v.number()),
    currency: v.optional(v.string()),
    category: v.optional(financeCategory),
    cycle: v.optional(billCycle),
    dueDate: v.optional(v.number()),
    responsible: v.optional(v.id("users")),
    autoSplit: v.optional(v.boolean()),
    isArchived: v.optional(v.boolean()),
    reminders: v.optional(v.array(v.number())),
  },
  handler: async (ctx, { id, ...fields }) => {
    await requireUser(ctx);
    const bill = await ctx.db.get(id);
    if (!bill) throw new Error("Bill not found");
    const home = await requireDocHome(ctx, bill, "Bill");
    if (fields.responsible) {
      await requireMembers(ctx, home, [fields.responsible], "Bill");
    }

    const dueDate = fields.dueDate ?? bill.due_date;
    await ctx.db.patch(id, {
      title: fields.title?.trim() || bill.title,
      amount: fields.amount === undefined ? bill.amount : requireAmount(fields.amount),
      currency: fields.currency ?? bill.currency,
      category: fields.category ?? bill.category,
      cycle: fields.cycle ?? bill.cycle,
      due_date: dueDate,
      responsible: fields.responsible ?? bill.responsible,
      auto_split: fields.autoSplit ?? bill.auto_split,
      is_archived: fields.isArchived ?? bill.is_archived,
      reminders:
        fields.reminders === undefined ? bill.reminders : cleanReminders(fields.reminders),
      // Moving the date opens a new cycle, so the nudges already sent for the
      // old one stop counting and the new ones are free to fire.
      reminded: prunedReminded(bill.reminded, dueDate),
      updated: Date.now(),
    });
    return await ctx.db.get(id);
  },
});

/**
 * Pays a bill: writes the expense it just became, and rolls the schedule on.
 *
 * One mutation rather than "add an expense, then edit the bill" by hand. A bill
 * that is paid but still says it is due is the single most confusing state this
 * screen can be in, and two round trips is exactly how a household gets there.
 */
export const payBill = mutation({
  args: {
    id: v.id("bills"),
    /** Who actually paid it. Defaults to whoever is tapping. */
    paidBy: v.optional(v.id("users")),
    /** Overrides the bill's own amount for a variable bill — power, water. */
    amount: v.optional(v.number()),
    paidAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const bill = await ctx.db.get(args.id);
    if (!bill) throw new Error("Bill not found");
    const home = await requireDocHome(ctx, bill, "Bill");

    const amount = requireAmount(args.amount ?? bill.amount);
    const paidBy = args.paidBy ?? user._id;
    await requireMembers(ctx, home, [paidBy], "Bill");
    const paidAt = args.paidAt ?? Date.now();

    // A shared bill splits across the household; one somebody carries alone
    // lands wholly on the person responsible for it, so the household's spend
    // still records it but nobody is quietly put in debt for it.
    const members = home.members ?? [];
    const shared = bill.auto_split !== false && members.length > 0;
    const splits = shared
      ? splitEvenly(amount, members)
      : [{ user_id: bill.responsible ?? paidBy, amount }];

    const now = Date.now();
    const expenseId = await ctx.db.insert("expenses", {
      home_id: bill.home_id,
      title: bill.title ?? "Bill",
      amount,
      currency: bill.currency,
      category: bill.category,
      paid_by: paidBy,
      splits,
      split_mode: shared ? "equal" : "exact",
      spent_at: paidAt,
      bill_id: bill._id,
      created_by: user._id,
      created: now,
      updated: now,
    });

    // A one-off is done rather than due again; anything recurring moves to its
    // next date so the timeline never shows a bill that has just been paid.
    if (bill.cycle === "once") {
      await ctx.db.patch(bill._id, {
        is_archived: true,
        last_paid_at: paidAt,
        updated: now,
      });
    } else {
      const moved = nextDue(bill.due_date, bill.cycle);
      await ctx.db.patch(bill._id, {
        due_date: moved,
        last_paid_at: paidAt,
        // A new cycle: every nudge sent for the one just paid is retired, so
        // the next round fires on its own schedule.
        reminded: prunedReminded(bill.reminded, moved),
        updated: now,
      });
    }

    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: bill.home_id,
      actor: user._id,
      title: "Bill paid",
      body: user.name ? `${user.name} paid ${bill.title ?? "a bill"}` : (bill.title ?? "A bill was paid"),
      category: "finance",
    });

    return { expenseId };
  },
});

export const removeBill = mutation({
  args: { id: v.id("bills") },
  handler: async (ctx, { id }) => {
    const bill = await ctx.db.get(id);
    if (!bill) return { ok: true };
    await requireDocHome(ctx, bill, "Bill");
    // The expenses it produced keep their `bill_id`; they are history and stay.
    await ctx.db.delete(id);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// Budgets

/** Sets (or replaces) the monthly ceiling for one category. */
export const setBudget = mutation({
  args: {
    homeId: v.id("homes"),
    category: financeCategory,
    limit: v.number(),
    currency: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const limit = requireAmount(args.limit, "Budget");

    const existing = await ctx.db
      .query("budgets")
      .withIndex("by_home_category", (q) =>
        q.eq("home_id", args.homeId).eq("category", args.category),
      )
      .unique();

    const now = Date.now();
    if (existing) {
      await ctx.db.patch(existing._id, {
        limit,
        currency: args.currency,
        updated: now,
      });
      return existing._id;
    }
    return await ctx.db.insert("budgets", {
      home_id: args.homeId,
      category: args.category,
      limit,
      currency: args.currency,
      created_by: user._id,
      created: now,
      updated: now,
    });
  },
});

export const removeBudget = mutation({
  args: { id: v.id("budgets") },
  handler: async (ctx, { id }) => {
    const budget = await ctx.db.get(id);
    if (!budget) return { ok: true };
    await requireDocHome(ctx, budget, "Budget");
    await ctx.db.delete(id);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// The reminder sweep
//
// A bill is a date, and a date is only useful if something says it out loud
// before it passes. `crons.ts` runs this once a day; it looks for bills whose
// nudge falls today and pushes one notification per bill per nudge.
//
// Idempotence is the whole design. The sweep is naturally at-least-once — a
// retry, a redeploy, a clock that runs it twice — so every send is recorded
// against `<due_date>:<daysBefore>` and a key that is already there is skipped.
// Without that, a household with a rent reminder would be told about the rent
// every morning until they paid it.

/** One bill that is asking to be announced today. */
type DueNudge = {
  billId: Id<"bills">;
  homeId: Id<"homes">;
  key: string;
  title: string;
  amount: number;
  currency: string;
  /** Whole days until due; negative once it is late. */
  daysUntil: number;
};

/**
 * How far past its date the sweep still looks for a bill nobody has been told
 * about.
 *
 * The late nudge is recorded against `<due_date>:overdue`, so a bill that has
 * been announced once is never announced again however long it stays unpaid —
 * which means looking further back than this only ever re-reads bills that have
 * already had their nudge. The window exists for the other case: a stretch where
 * the cron did not run. Three months of it.
 */
const OVERDUE_SWEEP_DAYS = 90;

export const pendingReminders = internalQuery({
  args: {},
  handler: async (ctx): Promise<DueNudge[]> => {
    const now = Date.now();
    // Only the bills near enough their date to have anything to say. This
    // served every household in the deployment from one unindexed scan of the
    // whole `bills` table, so the daily sweep got slower with every account
    // that ever signed up — and a query gets one second, after which nobody's
    // reminders go out at all.
    const bills = await ctx.db
      .query("bills")
      .withIndex("by_due_date", (q) =>
        q
          .gte("due_date", now - OVERDUE_SWEEP_DAYS * DAY_MS)
          .lte("due_date", now + (MAX_REMINDER_DAYS + 1) * DAY_MS),
      )
      .collect();
    const today = dayNumber(now);
    const due: DueNudge[] = [];

    for (const bill of bills) {
      if (bill.is_archived) continue;
      const sent = new Set(bill.reminded ?? []);
      const daysUntil = dayNumber(bill.due_date) - today;

      const fire = (suffix: string) => {
        const key = `${bill.due_date}:${suffix}`;
        if (sent.has(key)) return;
        due.push({
          billId: bill._id,
          homeId: bill.home_id,
          key,
          title: bill.title ?? "A bill",
          amount: bill.amount,
          currency: bill.currency,
          daysUntil,
        });
      };

      // The nudges the household actually asked for.
      for (const day of cleanReminders(bill.reminders)) {
        if (daysUntil === day) fire(String(day));
      }

      // And one late nudge, whether or not any were configured: a bill that
      // has quietly gone past its date is the case a reminder exists for.
      if (daysUntil < 0) fire("overdue");
    }

    return due;
  },
});

export const markReminded = internalMutation({
  args: { billId: v.id("bills"), key: v.string() },
  handler: async (ctx, { billId, key }) => {
    const bill = await ctx.db.get(billId);
    if (!bill) return;
    const reminded = bill.reminded ?? [];
    if (reminded.includes(key)) return;
    await ctx.db.patch(billId, { reminded: [...reminded, key] });
  },
});

/**
 * Announces every bill that is due for a nudge today.
 *
 * Marked as sent *before* the push goes out. A duplicate reminder is a worse
 * failure than a missed one — people mute an app that repeats itself, and the
 * bill is still on the screen either way.
 */
export const sweepReminders = internalAction({
  args: {},
  handler: async (ctx): Promise<{ sent: number }> => {
    const due: DueNudge[] = await ctx.runQuery(internal.finance.pendingReminders, {});
    let sent = 0;

    for (const nudge of due) {
      await ctx.runMutation(internal.finance.markReminded, {
        billId: nudge.billId,
        key: nudge.key,
      });
      await ctx.runAction(internal.push.notifyHome, {
        homeId: nudge.homeId,
        title: nudge.daysUntil < 0 ? "Bill overdue" : "Bill due soon",
        body: reminderBody(nudge),
        category: "finance",
      });
      sent++;
    }

    return { sent };
  },
});

function reminderBody(nudge: DueNudge): string {
  // Minor units are not formatted here: the server has no locale, and the
  // notification is a nudge to open the screen rather than a statement of
  // account. The bill's name and its timing are what make it actionable.
  if (nudge.daysUntil < 0) {
    const late = -nudge.daysUntil;
    return `${nudge.title} was due ${late} ${late === 1 ? "day" : "days"} ago`;
  }
  if (nudge.daysUntil === 0) return `${nudge.title} is due today`;
  return `${nudge.title} is due in ${nudge.daysUntil} ${nudge.daysUntil === 1 ? "day" : "days"}`;
}
