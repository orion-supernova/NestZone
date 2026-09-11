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
 * Sent to the client (see `listByHome`) rather than duplicated there, because
 * the Tasks screen states the rule to the person reading it — and a screen that
 * says "30 days" while the server means 14 is worse than one that says nothing.
 */
export const DONE_WINDOW_DAYS = 30;

/**
 * A hard ceiling on the Done list, under the date window.
 *
 * The window is what actually bounds this in any normal household; this is for
 * the one that ticks four hundred boxes a month. It keeps the list read — which
 * is on the Tasks screen's launch path — from being unbounded in how *busy* a
 * home is, now that it is no longer unbounded in how *long* it has been used.
 */
const DONE_LIMIT = 500;

/** How many completions the History screen carries back in one read. */
const HISTORY_LIMIT = 200;
const HISTORY_MAX = 500;

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
    const [open, done] = await Promise.all([
      openTasks(ctx, homeId),
      ctx.db
        .query("tasks")
        .withIndex("by_home_completed", (q) =>
          q
            .eq("home_id", homeId)
            .eq("is_completed", true)
            // Not put away by hand. `undefined` is its own key in a Convex
            // index, so "never archived" is an equality rather than a filter.
            .eq("archived_at", undefined)
            .gte("completed_at", Date.now() - DONE_WINDOW_DAYS * DAY_MS),
        )
        .order("desc")
        .take(DONE_LIMIT),
    ]);
    return { tasks: [...open, ...done], doneWindowDays: DONE_WINDOW_DAYS };
  },
});

/**
 * Everything this household has ever finished, newest first.
 *
 * Read from `task_completions` rather than from the tasks themselves, which is
 * the whole reason that table exists: this is the record, and it does not
 * change when somebody tidies their task list. It is also exactly what the
 * contribution split is counted from, so the two screens cannot disagree.
 *
 * The task behind each row is fetched for one reason — to say whether there is
 * still something there to put back on the Done list. Bounded by `limit`, and
 * off every launch path.
 */
export const history = query({
  args: {
    homeId: v.id("homes"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { homeId, limit }) => {
    await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);

    const take = Math.min(Math.max(Math.floor(limit ?? HISTORY_LIMIT), 1), HISTORY_MAX);
    const rows = await ctx.db
      .query("task_completions")
      .withIndex("by_home_at", (q) => q.eq("home_id", homeId))
      .order("desc")
      .take(take);

    const [tasks, profiles] = await Promise.all([
      Promise.all(rows.map((row) => ctx.db.get(row.task_id))),
      memberProfiles(ctx, home.members ?? []),
    ]);

    // A chore put back on the Done list has to actually land on it, and the
    // list only carries the last `DONE_WINDOW_DAYS`. Offering "put back" on
    // something finished six months ago would be a button that appears to do
    // nothing, so the server decides here rather than letting the screen guess.
    const restorableFrom = Date.now() - DONE_WINDOW_DAYS * DAY_MS;

    return {
      limit: take,
      // True when the read hit its ceiling, so the screen can say so rather
      // than implying this is everything the household has ever done.
      isTruncated: rows.length === take,
      entries: rows.map((row, index) => {
        const task = tasks[index];
        const credited = row.user_id && profiles.has(row.user_id as string)
          ? row.user_id
          : null;
        const profile = credited ? profiles.get(credited as string) : undefined;
        const isArchived = task != null && task.archived_at != null;
        return {
          id: row._id,
          taskId: row.task_id,
          // The chore as it was called when it was done. Falls back to the live
          // task for rows written before the snapshot, and to nothing at all
          // once the task itself is gone.
          title: row.title ?? task?.title ?? null,
          type: row.type ?? task?.type ?? null,
          completedAt: row.completed_at,
          userId: credited,
          name: profile?.name ?? null,
          email: profile?.email ?? null,
          isArchived,
          canRestore: isArchived && row.completed_at >= restorableFrom,
        };
      }),
    };
  },
});

/**
 * The archive, as a list you can open rather than a badge on rows elsewhere.
 *
 * This was the hole in the first version of the archive: putting a chore away
 * hid it from the Done list, and the only way back to it was to spot its badge
 * among every completion the household had ever recorded. Archive the wrong
 * thing — a test row, a chore somebody made twice — and it was gone somewhere
 * you could not go, with no way to restore it and no way to delete it.
 *
 * Read from `tasks` rather than from the ledger, because an archived chore is a
 * *task* that has been put away, and everything needed to draw it is already on
 * the row: `archived_at` orders the list, and `completed_at` / `completed_by`
 * are denormalised there for the Done list's index. No join, one index range.
 *
 * Shaped to match `history` exactly, so the screen draws both with one row.
 */
export const archived = query({
  args: {
    homeId: v.id("homes"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { homeId, limit }) => {
    await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);

    const take = Math.min(Math.max(Math.floor(limit ?? HISTORY_LIMIT), 1), HISTORY_MAX);
    const rows = await ctx.db
      .query("tasks")
      .withIndex("by_home_archived", (q) =>
        // Zero rather than `undefined`: a Convex index sorts `undefined` before
        // every number, so a range from 0 selects exactly the rows that carry a
        // timestamp — the put-away ones — and excludes the rest by ordering
        // rather than by filtering.
        q.eq("home_id", homeId).gte("archived_at", 0),
      )
      .order("desc")
      .take(take);

    const profiles = await memberProfiles(ctx, home.members ?? []);
    const restorableFrom = Date.now() - DONE_WINDOW_DAYS * DAY_MS;

    return {
      limit: take,
      isTruncated: rows.length === take,
      entries: rows.map((task) => {
        const credited =
          task.completed_by && profiles.has(task.completed_by as string)
            ? task.completed_by
            : null;
        const profile = credited ? profiles.get(credited as string) : undefined;
        const at = task.completed_at ?? task.updated ?? task._creationTime;
        return {
          id: task._id,
          taskId: task._id,
          title: task.title ?? null,
          type: task.type ?? null,
          completedAt: at,
          userId: credited,
          name: profile?.name ?? null,
          email: profile?.email ?? null,
          isArchived: true,
          canRestore: at >= restorableFrom,
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
      // Credit the chore to whoever ticked the box, and stamp when. Archiving
      // is a finished-chore verb, so a task arriving at "done" cannot already
      // be put away — clearing it here means a reopened-then-refinished chore
      // comes back onto the list rather than straight into the archive.
      patch.completed_by = user._id;
      patch.completed_at = now;
      patch.archived_at = undefined;
    } else if (reopened) {
      // Nobody has finished this. `undefined` in a patch removes the field,
      // which is what that should look like — and an open chore is work still
      // outstanding, so it has no business being hidden from the list of work
      // still outstanding either.
      patch.completed_by = undefined;
      patch.completed_at = undefined;
      patch.archived_at = undefined;
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
 * Put a finished chore away, or bring it back.
 *
 * The swipe on a finished chore, and the whole of what that swipe does: the row
 * leaves the Done list and the `task_completions` entry is not touched. The
 * work still counts, the split does not move, and the History screen still
 * shows it — which is the sentence the UI says out loud, and this is the code
 * that has to keep it true.
 *
 * Refuses an open task. Archiving is what you do with work that is *finished*;
 * hiding something you still have to do is just losing it.
 */
export const setArchived = mutation({
  args: { id: v.id("tasks"), archived: v.boolean() },
  handler: async (ctx, { id, archived }) => {
    const user = await requireUser(ctx);
    const task = await ctx.db.get(id);
    if (!task) throw new Error("Task not found");
    await requireDocHome(ctx, task, "Task");
    if (archived && !task.is_completed) {
      throw new Error("Only a finished chore can be archived.");
    }
    const now = Date.now();
    await ctx.db.patch(id, {
      archived_at: archived ? now : undefined,
      updated_by: user._id,
      updated: now,
    });
    return { ok: true };
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
 * So delete keeps the first meaning only. A finished chore is put away with
 * `setArchived`, which leaves the record alone; and if somebody genuinely means
 * "this was never done", the way there is to untick it — which retracts the
 * credit visibly, in front of them — and then delete it as the open task it has
 * become.
 */
export const remove = mutation({
  args: { id: v.id("tasks") },
  handler: async (ctx, { id }) => {
    const task = await ctx.db.get(id);
    if (!task) return { ok: true };
    await requireDocHome(ctx, task, "Task");
    if (task.is_completed) {
      throw new Error(
        "A finished chore can't be deleted here. Archive it and delete it from the archive, or reopen it first.",
      );
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
 * A separate mutation from `remove`, and the separation is the safety. `remove`
 * is the one the task list calls and it refuses anything completed, so no swipe
 * on the working list can reach a completion however the client is written.
 * This is the deliberate path: reachable only from the archive, behind a dialog
 * that names the person whose credit goes with it, and named for what it does
 * so a future call site cannot arrive here thinking it meant the other one.
 *
 * Archived only, for the same reason. Putting a chore away is already a
 * statement that the row has served its purpose; deleting it from the archive
 * is a second, separate statement that it should never have existed. Two acts
 * rather than one is the whole difference between this and the behaviour it
 * replaces, where a single swipe on the Done list did both silently.
 *
 * This *does* change the contribution split — that is the point of it, and why
 * the only way here is through a dialog that says so.
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
    if (task.archived_at === undefined || task.archived_at === null) {
      throw new Error("Archive the chore first, then delete it from the archive.");
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
