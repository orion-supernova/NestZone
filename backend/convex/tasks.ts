import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";

const priority = v.union(v.literal("low"), v.literal("medium"), v.literal("high"));
const taskType = v.union(
  v.literal("cleaning"),
  v.literal("shopping"),
  v.literal("maintenance"),
  v.literal("general"),
);

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("tasks")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
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
    await requireHomeMember(ctx, args.homeId);
    const now = Date.now();
    return await ctx.db.insert("tasks", {
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
    await requireDocHome(ctx, task, "Task");
    await ctx.db.patch(id, { ...fields, updated_by: user._id, updated: Date.now() });
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
