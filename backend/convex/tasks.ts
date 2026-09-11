import { query, mutation, internalMutation } from "./_generated/server";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { openTasks } from "./lib/pending";
import { requireMembers } from "./lib/relations";

// Shown as the notification title; the body carries what actually changed.
const NOTIFY_TITLE = "New task";

const priority = v.union(v.literal("low"), v.literal("medium"), v.literal("high"));
const taskType = v.union(
  v.literal("cleaning"),
  v.literal("shopping"),
  v.literal("maintenance"),
  v.literal("general"),
);

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * How long a finished chore stays on the Done list before it moves to History.
 *
 * The Tasks screen is a working list, and the thing that ruins a working list
 * is a year of ticked boxes underneath it. Finishing a chore flips a flag, it
 * does not remove the row, so without a window the Done tab is every chore the
 * household has ever done, forever, in front of the ones it is doing now.
 *
 * Nothing is lost when a row rolls off: the completion is a document in
 * `task_completions`, the History screen reads it, and the contribution split
 * is tallied from it. This shortens the list, not the record.
 *
 * Sent to the client (see `listByHome` and `archive`) rather than duplicated
 * there, because both screens state the rule to the person reading them — and a
 * screen that says "30 days" while the server means 14 is worse than one that
 * says nothing.
 */
const DEFAULT_DONE_WINDOW_DAYS = 30;

/**
 * The window in force, which the deployment may override.
 *
 * How long a finished chore stays on the working list is a product decision,
 * not a constant of nature, and it is the kind that wants trying at a different
 * value before it wants a code change. `npx convex env set DONE_WINDOW_DAYS 7`
 * moves it; unset, or set to anything that is not a non-negative number, and it
 * is the default above.
 *
 * It is also the only way to see the Archive without waiting a month: set it to
 * `0` and every finished chore falls below the boundary at once. Nothing is
 * rewritten by that — the boundary moves, the rows do not, and putting the
 * value back puts them back.
 */
export function doneWindowDays(): number {
  const raw = Number(process.env.DONE_WINDOW_DAYS);
  return Number.isFinite(raw) && raw >= 0 ? raw : DEFAULT_DONE_WINDOW_DAYS;
}

/**
 * A hard ceiling on the Done list, under the date window.
 *
 * The window is what actually bounds this in any normal household; this is for
 * the one that ticks four hundred boxes a month. It keeps the list read — which
 * is on the Tasks screen's launch path — from being unbounded in how *busy* a
 * home is, now that it is no longer unbounded in how *long* it has been used.
 */
const DONE_LIMIT = 500;

/** How many completions the Archive screen carries back in one read. */
const ARCHIVE_LIMIT = 200;
const ARCHIVE_MAX = 500;

// ---------------------------------------------------------------------------
// The record of work done.

/**
 * Who a finished chore counts for, when nobody recorded it at the time.
 *
 * `completed_by` is the real answer and every completion written since the
 * ledger shipped has one. This is the fallback chain for the rows that predate
 * it: `updated_by` is whoever last touched the task, which for a completed one
 * is almost always the person who ticked it; then the assignee; then the
 * author. A task that answers none of these counts for nobody rather than being
 * guessed at.
 *
 * Applied once, by `backfillCompletions`, and then never again — which is the
 * point of moving it here from the stats query. It used to run on every read of
 * every screen that showed the split, so a guess made about a 2023 import was
 * re-derived forever instead of being written down once.
 */
function creditFor(task: Doc<"tasks">): Id<"users"> | undefined {
  return task.completed_by ?? task.updated_by ?? task.assigned_to ?? task.created_by ?? undefined;
}

/**
 * Record a finished chore.
 *
 * Half of the only pair of writes that can touch the household's record of who
 * does the housework. Ticking the box writes it; unticking the box — see
 * `retractCompletion` — is the only act in the app that can take it back, and
 * it is deliberately the one a person can watch happen.
 *
 * Deleting a task cannot reach either: `remove` refuses a completed row.
 */
async function recordCompletion(
  ctx: MutationCtx,
  task: Doc<"tasks">,
  userId: Id<"users">,
  at: number,
  snapshot: { title: string | undefined; type: Doc<"tasks">["type"] },
) {
  // At most one completion per task, by construction. The caller already guards
  // on the false-to-true transition; this is belt and braces against a
  // double-tick racing itself into two rows and crediting somebody twice.
  await retractCompletion(ctx, task._id);
  await ctx.db.insert("task_completions", {
    home_id: task.home_id,
    task_id: task._id,
    user_id: userId,
    title: snapshot.title,
    type: snapshot.type,
    completed_at: at,
  });
}

/** Take back the record of a chore having been finished. */
async function retractCompletion(ctx: MutationCtx, taskId: Id<"tasks">) {
  const rows = await ctx.db
    .query("task_completions")
    .withIndex("by_task", (q) => q.eq("task_id", taskId))
    .collect();
  await Promise.all(rows.map((row) => ctx.db.delete(row._id)));
}

/**
 * Keep the completion's snapshot in step with the task it describes.
 *
 * The snapshot exists so the two readers of that table never have to fetch a
 * task per row; it is a performance decision, not a second version of the
 * truth, so while the task is alive and finished an edit to it lands here too.
 */
async function syncCompletionSnapshot(
  ctx: MutationCtx,
  taskId: Id<"tasks">,
  fields: { title?: string; type?: Doc<"tasks">["type"] },
) {
  const row = await ctx.db
    .query("task_completions")
    .withIndex("by_task", (q) => q.eq("task_id", taskId))
    .first();
  if (!row) return;
  await ctx.db.patch(row._id, fields);
}

/** Display fields for a home's members, by id, for rows that credit somebody. */
async function memberProfiles(
  ctx: QueryCtx,
  memberIds: Id<"users">[],
): Promise<Map<string, { name: string | null; email: string | null }>> {
  const members = await Promise.all(memberIds.map((id) => ctx.db.get(id)));
  const profiles = new Map<string, { name: string | null; email: string | null }>();
  for (const member of members) {
    if (!member) continue;
    profiles.set(member._id as string, {
      name: member.name ?? null,
      email: member.email ?? null,
    });
  }
  return profiles;
}

// ---------------------------------------------------------------------------
// Reads.

/**
 * The household's working list: everything open, plus what was finished
 * recently and not put away.
 *
 * Both halves are index ranges. The open half always was; the finished half
 * used to be "the last 500 rows by creation date", which is a different set
 * from "the last 500 finished" on any home where chores sit on the list before
 * anybody gets to them — and it grew without limit in the dimension that
 * matters, the household's age.
 *
 * `doneWindowDays` travels with the rows because the screen tells the person
 * what the rule is. One source for the number, one sentence on the screen.
 */
export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    const windowDays = doneWindowDays();
    const [open, done] = await Promise.all([
      openTasks(ctx, homeId),
      ctx.db
        .query("tasks")
        .withIndex("by_home_completed", (q) =>
          q
            .eq("home_id", homeId)
            .eq("is_completed", true)
            .gte("completed_at", Date.now() - windowDays * DAY_MS),
        )
        .order("desc")
        .take(DONE_LIMIT),
    ]);
    return { tasks: [...open, ...done], doneWindowDays: windowDays };
  },
});

/**
 * The chores that have left the Done list: everything finished longer ago than
 * the window.
 *
 * The complement of the Done list, not a superset of it. That distinction is
 * the whole difference between an archive and a second copy of the same list,
 * and the first version of this screen got it wrong — it returned every
 * completion the household had ever recorded, so a chore finished yesterday
 * appeared here *and* on the Done tab at the same time. Nothing about that is
 * an archive.
 *
 * Both halves now read the same boundary off `completed_at`: Done is the range
 * above it, this is the range below. Disjoint by construction, with no flag to
 * keep in step and nothing to sweep.
 *
 * Read from `task_completions` and nothing else — no join at all. The title and
 * the kind were snapshotted when the box was ticked, which is what that table
 * is for, so the record needs no help from the tasks it describes.
 */
export const archive = query({
  args: {
    homeId: v.id("homes"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { homeId, limit }) => {
    await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);

    const windowDays = doneWindowDays();
    const take = Math.min(Math.max(Math.floor(limit ?? ARCHIVE_LIMIT), 1), ARCHIVE_MAX);
    const rows = await ctx.db
      .query("task_completions")
      .withIndex("by_home_at", (q) =>
        q.eq("home_id", homeId).lt("completed_at", Date.now() - windowDays * DAY_MS),
      )
      .order("desc")
      .take(take);

    const profiles = await memberProfiles(ctx, home.members ?? []);

    return {
      limit: take,
      windowDays,
      // True when the read hit its ceiling, so the screen can say it is showing
      // the most recent rather than implying it is showing everything.
      isTruncated: rows.length === take,
      entries: rows.map((row) => {
        const credited =
          row.user_id && profiles.has(row.user_id as string) ? row.user_id : null;
        const profile = credited ? profiles.get(credited as string) : undefined;
        return {
          id: row._id,
          taskId: row.task_id,
          // The chore as it was called when it was done.
          title: row.title ?? null,
          type: row.type ?? null,
          completedAt: row.completed_at,
          userId: credited,
          name: profile?.name ?? null,
          email: profile?.email ?? null,
        };
      }),
    };
  },
});

// ---------------------------------------------------------------------------
// Writes.

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    title: v.string(),
    description: v.optional(v.string()),
    assigned_to: v.optional(v.id("users")),
    priority: v.optional(priority),
    type: v.optional(taskType),
    due_date: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    if (args.assigned_to) {
      await requireMembers(ctx, home, [args.assigned_to], "Task assignee");
    }
    const now = Date.now();
    const createdId = await ctx.db.insert("tasks", {
      home_id: args.homeId,
      title: args.title,
      description: args.description,
      created_by: user._id,
      updated_by: user._id,
      assigned_to: args.assigned_to,
      is_completed: false,
      priority: args.priority,
      type: args.type,
      due_date: args.due_date,
      created: now,
      updated: now,
    });

    // Tell the rest of the household. Scheduled rather than awaited: a mutation
    // must not block on APNs, and a failed push must never roll back the write.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: user.name ? `${user.name} added a task` : NOTIFY_TITLE,
      body: args.title,
      category: "tasks",
    });

    return createdId;
  },
});

export const update = mutation({
  args: {
    id: v.id("tasks"),
    title: v.optional(v.string()),
    description: v.optional(v.string()),
    assigned_to: v.optional(v.id("users")),
    is_completed: v.optional(v.boolean()),
    priority: v.optional(priority),
    type: v.optional(taskType),
    due_date: v.optional(v.number()),
  },
  handler: async (ctx, { id, ...fields }) => {
    const user = await requireUser(ctx);
    const task = await ctx.db.get(id);
    if (!task) throw new Error("Task not found");
    const home = await requireDocHome(ctx, task, "Task");
    if (fields.assigned_to) {
      await requireMembers(ctx, home, [fields.assigned_to], "Task assignee");
    }
    // Only the transitions worth interrupting someone for. An edit to the
    // title, or unticking a box that was already unticked, is not news.
    const justCompleted = fields.is_completed === true && !task.is_completed;
    const reopened = fields.is_completed === false;
    const now = Date.now();

    const patch: Partial<Doc<"tasks">> = {
      ...fields,
      updated_by: user._id,
      updated: now,
    };

    if (justCompleted) {
      // Credit the chore to whoever ticked the box, and stamp when. That
      // stamp is also what decides which of the two lists it appears on, now
      // and for as long as it stands.
      patch.completed_by = user._id;
      patch.completed_at = now;
    } else if (reopened) {
      // Nobody has finished this. `undefined` in a patch removes the field,
      // which is what that should look like.
      patch.completed_by = undefined;
      patch.completed_at = undefined;
    }

    await ctx.db.patch(id, patch);

    if (justCompleted) {
      // Snapshotted from the task *as this edit leaves it*, not as it arrived:
      // one call can rename a chore and tick it at the same time, and the
      // record should say what was actually finished.
      await recordCompletion(ctx, task, user._id, now, {
        title: fields.title ?? task.title,
        type: fields.type ?? task.type,
      });
    } else if (reopened) {
      // The one act in the app that takes a completion back, and the person
      // doing it is looking at the tick disappear as it happens.
      await retractCompletion(ctx, id);
    } else if (task.is_completed && (fields.title !== undefined || fields.type !== undefined)) {
      const snapshot: { title?: string; type?: Doc<"tasks">["type"] } = {};
      if (fields.title !== undefined) snapshot.title = fields.title;
      if (fields.type !== undefined) snapshot.type = fields.type;
      await syncCompletionSnapshot(ctx, id, snapshot);
    }

    if (justCompleted && task.home_id) {
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: task.home_id,
        actor: user._id,
        title: user.name ? `${user.name} finished a task` : "Task done",
        body: task.title ?? "",
        category: "tasks",
      });

      // A chore that exists because something is broken owes the problem an
      // answer. Recorded on its timeline rather than closing it: "call the
      // plumber" is a chore somebody can finish while the tap goes on
      // dripping, so the app says what happened and the household says whether
      // it worked. Scheduled rather than awaited, like the push — ticking a box
      // must not wait on, or be rolled back by, a write to another module.
      if (task.issue_id) {
        await ctx.scheduler.runAfter(0, internal.issues.noteChoreDone, {
          issueId: task.issue_id,
          userId: user._id,
          title: task.title ?? "",
        });
      }
    }

    // Being handed a job is personal, so it goes to the assignee alone rather
    // than to the whole household.
    const justAssigned =
      fields.assigned_to !== undefined && fields.assigned_to !== task.assigned_to;
    if (justAssigned && fields.assigned_to) {
      await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
        userIds: [fields.assigned_to],
        actor: user._id,
        title: user.name ? `${user.name} assigned you a task` : "New task for you",
        body: fields.title ?? task.title ?? "",
        category: "tasks",
      });
    }

    return await ctx.db.get(id);
  },
});

/**
 * Delete a chore that should not exist.
 *
 * Open tasks only, and that restriction is the point rather than a limitation.
 * "Delete" used to mean two different things depending on which row it landed
 * on — throw away a mistake, or erase a completed chore *and* the household's
 * record of who did it — and one swipe did both without saying so. The
 * contribution split was editable by anybody with a finger.
 *
 * So this keeps the first meaning only, and it is the one that needs no
 * confirming: an open chore has never been done by anybody, so there is no
 * credit to take away and nothing to warn about. Erasing finished work goes
 * through `removeFinished`, which is a different function precisely so that no
 * call site can arrive at it by accident.
 */
export const remove = mutation({
  args: { id: v.id("tasks") },
  handler: async (ctx, { id }) => {
    const task = await ctx.db.get(id);
    if (!task) return { ok: true };
    await requireDocHome(ctx, task, "Task");
    if (task.is_completed) {
      throw new Error("A finished chore can't be deleted here. Use removeFinished.");
    }
    // An open task has no completion to retract. Called anyway, because this is
    // the last moment a stray row could be orphaned, and an index lookup that
    // finds nothing is the cheapest read in the database.
    await retractCompletion(ctx, id);
    await ctx.db.delete(id);
    return { ok: true };
  },
});

/**
 * Delete a finished chore and the record of it having been done.
 *
 * A separate mutation from `remove`, and the separation is the safety rather
 * than a formality. `remove` is what the working list calls and it refuses
 * anything completed, so no ordinary delete path can reach a completion however
 * the client is written; arriving here takes naming this function, which is a
 * thing you cannot do by accident.
 *
 * The other half of the safety is on the client, and it is the only part a
 * person sees: every call goes through a dialog that names the chore, names
 * whose credit goes with it, and says the contribution split will change. That
 * is the whole difference between this and the behaviour it replaces — not that
 * the record became unreachable, but that reaching it stopped being silent.
 *
 * Offered on both lists. Restricting it to the Archive was tempting and wrong:
 * a chore added by mistake is noticed the same day, and a rule that made you
 * wait a month to delete it would be a dead end wearing a safety jacket.
 */
export const removeFinished = mutation({
  args: { id: v.id("tasks") },
  handler: async (ctx, { id }) => {
    const task = await ctx.db.get(id);
    if (!task) return { ok: true };
    await requireDocHome(ctx, task, "Task");
    if (!task.is_completed) {
      throw new Error("That chore is not finished. Delete it from the task list instead.");
    }
    await retractCompletion(ctx, id);
    await ctx.db.delete(id);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// One-time migration.

/**
 * Write a `task_completions` row for every chore finished before the ledger
 * existed, and stamp the two fields the new reads depend on.
 *
 * Run once per deployment:
 *
 *     npx convex run tasks:backfillCompletions '{}'
 *
 * It walks the table a page at a time and schedules its own continuation, so
 * one invocation finishes the job whatever the size of the deployment, and no
 * single mutation goes near the one-second budget.
 *
 * Idempotent: a task that already has a completion is skipped, and the patches
 * only fill in fields that are missing. Re-running it after a partial failure
 * costs a scan and changes nothing else.
 *
 * Until it has run, tasks finished before the ledger shipped have no
 * `completed_at` — so they sit outside the Done list's date range and appear
 * only in History, and they are missing from the contribution tally entirely.
 * That is a visible enough difference that it should be run as part of the
 * deploy rather than left for later.
 */
export const backfillCompletions = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    batch: v.optional(v.number()),
    written: v.optional(v.number()),
    patched: v.optional(v.number()),
    scanned: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const numItems = Math.min(Math.max(Math.floor(args.batch ?? 100), 1), 500);
    const page = await ctx.db
      .query("tasks")
      .paginate({ cursor: args.cursor ?? null, numItems });

    let written = args.written ?? 0;
    let patched = args.patched ?? 0;
    const scanned = (args.scanned ?? 0) + page.page.length;

    for (const task of page.page) {
      if (!task.is_completed) continue;

      // The same answer `finishedAt` used to compute on every read: completion
      // is an update, so `updated` is when it happened, and a row the import
      // left without one falls back to when it was created.
      const at = task.completed_at ?? task.updated ?? task._creationTime;
      const credit = creditFor(task);

      if (task.completed_at === undefined || task.completed_by === undefined) {
        await ctx.db.patch(task._id, { completed_at: at, completed_by: credit });
        patched++;
      }

      const existing = await ctx.db
        .query("task_completions")
        .withIndex("by_task", (q) => q.eq("task_id", task._id))
        .first();
      if (existing) continue;

      await ctx.db.insert("task_completions", {
        home_id: task.home_id,
        task_id: task._id,
        user_id: credit,
        title: task.title,
        type: task.type,
        completed_at: at,
      });
      written++;
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.tasks.backfillCompletions, {
        cursor: page.continueCursor,
        batch: numItems,
        written,
        patched,
        scanned,
      });
    }

    return { isDone: page.isDone, scanned, written, patched };
  },
});
