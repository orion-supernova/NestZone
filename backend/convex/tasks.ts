import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
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

/**
 * How many finished tasks the list carries back with it.
 *
 * Same bargain as `shopping:listByHome`, and for the same reason: finishing a
 * chore flips a flag, it does not remove the row, so a household that uses the
 * app accumulates completed tasks forever and the Tasks screen was downloading
 * all of them to draw an "open" list and a "done" tab. Five hundred is well past
 * where anybody stops scrolling their own history.
 */
const DONE_WINDOW = 500;

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    const [open, done] = await Promise.all([
      openTasks(ctx, homeId),
      ctx.db
        .query("tasks")
        .withIndex("by_home_completed", (q) =>
          q.eq("home_id", homeId).eq("is_completed", true),
        )
        .order("desc")
        .take(DONE_WINDOW),
    ]);
    return [...open, ...done];
  },
});

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

    // Credit the chore to whoever ticked the box, and take the credit back when
    // the box is unticked — otherwise a task completed, reopened and finished by
    // someone else would keep counting for the first person forever. `undefined`
    // in a patch removes the field, which is what "nobody has finished this"
    // should look like.
    const completed_by = justCompleted
      ? user._id // freshly ticked — credit whoever ticked it
      : fields.is_completed === false
        ? undefined // reopened — nobody has finished this
        : task.completed_by; // an unrelated edit leaves the credit alone

    await ctx.db.patch(id, {
      ...fields,
      completed_by,
      updated_by: user._id,
      updated: Date.now(),
    });

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

export const remove = mutation({
  args: { id: v.id("tasks") },
  handler: async (ctx, { id }) => {
    const task = await ctx.db.get(id);
    if (!task) return { ok: true };
    await requireDocHome(ctx, task, "Task");
    await ctx.db.delete(id);
    return { ok: true };
  },
});
