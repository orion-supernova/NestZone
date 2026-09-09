// Home dashboard counters.
//
// The iOS Home tab used to compute these on-device: it subscribed to
// `shopping:listByHome`, `notes:listByHome` and `tasks:listByHome`, pulled every
// document in all three collections down to the phone, and filtered them by
// `created` in Swift — on every appearance of the tab, plus again whenever the
// selected home changed. For a household with a year of history that is
// megabytes of JSON to render six integers, and it also fetched
// `tasks:listByHome` twice per pass because the task list and the stats block
// each asked for it separately.
//
// This does the counting where the data already is and returns ~100 bytes.

import { query } from "./_generated/server";
import { v } from "convex/values";
import { Doc, Id } from "./_generated/dataModel";
import { requireUser, requireHomeMember } from "./lib/auth";
import { openTasks, outstandingItems } from "./lib/pending";
import { READ_WINDOW } from "./messages";

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/** Documents created inside [start, end). */
function countBetween(docs: { _creationTime: number }[], start: number, end: number): number {
  let n = 0;
  for (const doc of docs) if (doc._creationTime >= start && doc._creationTime < end) n++;
  return n;
}

/**
 * The Home tab's counters.
 *
 * Every read here is bounded by something that cannot grow without a person
 * doing something about it — what is open, what is outstanding, what happened in
 * the last fortnight — rather than by the household's whole history. This query
 * runs on the launch path, and a dashboard that gets slower every month a
 * household uses the app is a dashboard that eventually takes the Home tab down
 * with it. That is not hypothetical: it already happened once here, when the
 * unread count walked every conversation and collected every message ever sent
 * in it, and it happened again in `events:detail`.
 *
 * The two counters that could not be bounded are gone rather than paid for.
 * "Tasks done" was an all-time total that only ever grew and the old "Issues"
 * tile was a high-priority *task* count that read 0 in any household that never
 * sets priority; the Home tab dropped both some time ago, and the server went on
 * collecting the entire tasks table to compute them for a while afterwards.
 *
 * `openIssues` below is not that number coming back. It is a different table
 * with a boolean the server maintains, so "what is still broken" is an index
 * range rather than a scan — which is the only reason it is allowed on this
 * query at all.
 */
export const forHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);

    const now = Date.now();
    const weekAgo = now - WEEK_MS;
    const twoWeeksAgo = now - 2 * WEEK_MS;

    const [open, outstanding, notes, recentShopping, conversations, problems] = await Promise.all([
      openTasks(ctx, homeId),
      outstandingItems(ctx, homeId),
      // Not bounded, and deliberately so. Notes are authored one at a time by a
      // person who can also delete them, unlike a completed task or a bought
      // item, which accumulate on their own as a by-product of using the app.
      // The Notes screen collects the same rows to draw the board, so a count
      // taken here costs the household nothing it was not already paying.
      ctx.db.query("notes").withIndex("by_home", (q) => q.eq("home_id", homeId)).collect(),
      // Only the fortnight the trend chip compares. Every Convex index ends in
      // `_creationTime` implicitly, so `by_home` already sorts by it and this
      // needs no index of its own.
      ctx.db
        .query("shopping_items")
        .withIndex("by_home", (q) => q.eq("home_id", homeId).gte("_creationTime", twoWeeksAgo))
        .collect(),
      ctx.db.query("conversations").withIndex("by_home", (q) => q.eq("home_id", homeId)).collect(),
      // What is still broken.
      //
      // The tile this replaces was removed once already, and the reason is
      // worth repeating: the old "Issues" counter was a high-priority *task*
      // count computed by collecting the household's entire tasks table, and it
      // read 0 in any home that never set a priority. This is a different
      // number from a different table, and it is bounded by the one thing that
      // cannot grow on its own — `issues.is_open` goes false the moment
      // somebody fixes something, so the read is the household's outstanding
      // repairs and never its repair history.
      ctx.db
        .query("issues")
        .withIndex("by_home_open", (q) => q.eq("home_id", homeId).eq("is_open", true))
        .collect(),
    ]);

    // Unread messages actually mean something now. The client previously
    // reported `messageCount = noteCount` — the note count relabelled — so the
    // "Messages" tile on the Home tab has never shown a message count.
    //
    // Two things were wrong with counting this, and both of them were fatal on
    // a household that actually talks. It walked the conversations one at a
    // time, and for each it `.collect()`ed *every message ever sent* in it — to
    // derive a single integer. A query gets one second of execution, so a few
    // thousand messages spent it all here and `stats:forHome` failed outright,
    // taking the entire Home tab's dashboard down with it.
    //
    // Now: all conversations in one round, and the newest `READ_WINDOW` of
    // each. That bound is not an approximation of the right answer, it *is* the
    // right answer — `messages:markRead` marks exactly this window, so a message
    // older than it can never be cleared by opening the chat. Counting over a
    // wider window than can be marked read is how a badge gets stuck at
    // "3 unread" forever.
    const recent = await Promise.all(
      conversations.map((conversation) =>
        ctx.db
          .query("messages")
          .withIndex("by_conversation", (q) => q.eq("conversation_id", conversation._id))
          .order("desc")
          .take(READ_WINDOW),
      ),
    );
    const unreadMessages = recent
      .flat()
      .filter((m) => m.sender_id !== user._id && !(m.read_by ?? []).includes(user._id))
      .length;

    return {
      openTasks: open.length,
      shoppingItems: outstanding.length,
      notes: notes.length,
      unreadMessages,
      openIssues: problems.length,
      // The half of the number that decides whether the tile shouts. Counted
      // here rather than derived on the phone because the phone does not hold
      // the problems — that is the whole point of this query.
      urgentIssues: problems.filter(
        (issue) => issue.severity === "urgent" || (issue.due_by ?? Infinity) < now,
      ).length,

      shoppingChange:
        countBetween(recentShopping, weekAgo, now) -
        countBetween(recentShopping, twoWeeksAgo, weekAgo),
      notesChange:
        countBetween(notes, weekAgo, now) - countBetween(notes, twoWeeksAgo, weekAgo),
      // Reported this week against last. Read off the open set, so it is
      // "what has come up lately" rather than a rate over everything the house
      // has ever broken — and it goes down when things are fixed, which is the
      // direction a household wants to see it move.
      issuesChange:
        countBetween(problems, weekAgo, now) - countBetween(problems, twoWeeksAgo, weekAgo),
      // No historical read-state to compare against, so this stays flat rather
      // than inventing a trend.
      messagesChange: 0,
    };
  },
});

// ---------------------------------------------------------------------------
// Who actually does the chores.
//
// The Home tab could say how many tasks were done but never by whom, which in a
// shared household is the more interesting half of the question. This returns
// one row per member plus a daily histogram, so the client can draw the split
// without downloading the task list to derive it.

const DAY_MS = 24 * 60 * 60 * 1000;
/** Days of histogram returned, whatever the window. Enough to read a rhythm. */
const MAX_CHART_DAYS = 30;
/** How far back a streak is allowed to run. Bounds the scan on old households. */
const MAX_STREAK_DAYS = 400;

type TaskDoc = Doc<"tasks">;

/**
 * Who a finished chore counts for.
 *
 * `completed_by` is the real answer, but it only exists on tasks completed after
 * that field shipped. Everything older falls back through the next-best signals:
 * `updated_by` is whoever last touched it, which for a completed task is almost
 * always the person who ticked it; then the assignee; then the author. A task
 * that answers none of these is counted as unattributed rather than guessed at.
 */
function creditFor(task: TaskDoc): Id<"users"> | null {
  return task.completed_by ?? task.updated_by ?? task.assigned_to ?? task.created_by ?? null;
}

/** When a chore was finished. Completion is an update, so `updated` is the time. */
function finishedAt(task: TaskDoc): number {
  return task.updated ?? task._creationTime;
}

/**
 * The day `at` falls on *for the viewer*, as a day number.
 *
 * The server has no timezone, so the client sends its offset. Without this a
 * household in UTC+13 sees chores land on the wrong bar, and "today" on the
 * streak counter is up to a day out.
 */
function dayIndex(at: number, offsetMinutes: number): number {
  return Math.floor((at + offsetMinutes * 60_000) / DAY_MS);
}

/** UTC instant that day number starts at, for the client to format. */
function dayStart(index: number, offsetMinutes: number): number {
  return index * DAY_MS - offsetMinutes * 60_000;
}

/** Consecutive days up to today with at least one completion. */
function streakLength(days: Set<number>, today: number): number {
  // Yesterday still counts: a streak should not break at midnight before the
  // person has had a chance to do anything today.
  let cursor = days.has(today) ? today : today - 1;
  if (!days.has(cursor)) return 0;
  let streak = 0;
  while (days.has(cursor) && streak < MAX_STREAK_DAYS) {
    streak++;
    cursor--;
  }
  return streak;
}

export const contributions = query({
  args: {
    homeId: v.id("homes"),
    /** Days to look back over. 0 means every task the household has ever done. */
    windowDays: v.number(),
    /** Viewer's offset from UTC in minutes, east positive. */
    tzOffsetMinutes: v.optional(v.number()),
  },
  handler: async (ctx, { homeId, windowDays, tzOffsetMinutes }) => {
    await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);

    const tasks = await ctx.db
      .query("tasks")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();

    const memberIds = home.members ?? [];
    const memberDocs = await Promise.all(memberIds.map((id) => ctx.db.get(id)));

    const offset = tzOffsetMinutes ?? 0;
    const now = Date.now();
    const since = windowDays > 0 ? now - windowDays * DAY_MS : 0;
    const today = dayIndex(now, offset);

    const chartDays = windowDays > 0 ? Math.min(windowDays, MAX_CHART_DAYS) : MAX_CHART_DAYS;
    const firstChartDay = today - chartDays + 1;

    // Everything below is tallied in one pass over the tasks.
    const completed = new Map<string, number>();
    const openAssigned = new Map<string, number>();
    const overdue = new Map<string, number>();
    const byKind = new Map<string, Map<string, number>>();
    const streakDays = new Map<string, Set<number>>();
    // day index -> (user id -> count), for the histogram.
    const histogram = new Map<number, Map<string, number>>();

    const isMember = new Set<string>(memberIds.map((id) => id as string));
    let unattributed = 0;

    const bump = (map: Map<string, number>, key: string) =>
      map.set(key, (map.get(key) ?? 0) + 1);

    for (const task of tasks) {
      if (!task.is_completed) {
        const assignee = task.assigned_to;
        if (assignee && isMember.has(assignee)) {
          bump(openAssigned, assignee);
          if (task.due_date !== undefined && task.due_date < now) bump(overdue, assignee);
        }
        continue;
      }

      const credit = creditFor(task);
      const at = finishedAt(task);
      const day = dayIndex(at, offset);

      // A streak is a property of the person, not of the selected window, so it
      // is tallied from every completion rather than only the ones in range.
      if (credit && isMember.has(credit)) {
        let days = streakDays.get(credit);
        if (!days) streakDays.set(credit, (days = new Set()));
        days.add(day);
      }

      if (day >= firstChartDay && day <= today && credit && isMember.has(credit)) {
        let row = histogram.get(day);
        if (!row) histogram.set(day, (row = new Map()));
        row.set(credit, (row.get(credit) ?? 0) + 1);
      }

      if (at < since) continue;

      if (!credit || !isMember.has(credit)) {
        // A chore finished by someone who has since left the home still happened;
        // dropping it would make the shares add up to less than the total.
        unattributed++;
        continue;
      }

      bump(completed, credit);
      let kinds = byKind.get(credit);
      if (!kinds) byKind.set(credit, (kinds = new Map()));
      const kind = task.type ?? "general";
      kinds.set(kind, (kinds.get(kind) ?? 0) + 1);
    }

    const members = memberDocs.flatMap((user) => {
      if (!user) return [];
      const id = user._id as string;
      const kinds = byKind.get(id);
      return [
        {
          userId: user._id,
          name: user.name ?? null,
          email: user.email ?? null,
          completed: completed.get(id) ?? 0,
          openAssigned: openAssigned.get(id) ?? 0,
          overdue: overdue.get(id) ?? 0,
          streak: streakLength(streakDays.get(id) ?? new Set(), today),
          cleaning: kinds?.get("cleaning") ?? 0,
          shopping: kinds?.get("shopping") ?? 0,
          maintenance: kinds?.get("maintenance") ?? 0,
          general: kinds?.get("general") ?? 0,
        },
      ];
    });

    // Dense: every day in range gets a bar, including the empty ones, so the
    // chart shows the gaps instead of silently closing them up.
    const days = [];
    for (let day = firstChartDay; day <= today; day++) {
      const row = histogram.get(day);
      // Sorted, not Map-insertion order: without this the same two people
      // stack in a different order from one bar to the next, and the chart
      // shimmers as you read across it.
      const counts = row
        ? [...row]
            .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
            .map(([userId, count]) => ({ userId: userId as Id<"users">, count }))
        : [];
      days.push({
        start: dayStart(day, offset),
        total: counts.reduce((sum, entry) => sum + entry.count, 0),
        counts,
      });
    }

    return {
      windowDays,
      totalCompleted: members.reduce((sum, m) => sum + m.completed, 0) + unattributed,
      unattributed,
      members,
      days,
    };
  },
});
