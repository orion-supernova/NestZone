import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";

// Shown as the notification title; the body carries what actually changed.
const NOTIFY_TITLE = "New note";

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("notes")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
  },
});

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    description: v.string(),
    color: v.optional(v.string()),
    image: v.optional(v.id("_storage")),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const now = Date.now();
    const createdId = await ctx.db.insert("notes", {
      home_id: args.homeId,
      description: args.description,
      color: args.color,
      image: args.image,
      created_by: user._id,
      created: now,
      updated: now,
    });

    // Tell the rest of the household. Scheduled rather than awaited: a mutation
    // must not block on APNs, and a failed push must never roll back the write.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: user.name ? `${user.name} left a note` : NOTIFY_TITLE,
      body: args.description.slice(0, 120),
      category: "notes",
    });

    return createdId;
  },
});

export const update = mutation({
  args: {
    id: v.id("notes"),
    description: v.optional(v.string()),
    color: v.optional(v.string()),
    image: v.optional(v.id("_storage")),
  },
  handler: async (ctx, { id, ...fields }) => {
    await requireUser(ctx);
    const note = await ctx.db.get(id);
    if (!note) throw new Error("Note not found");
    await requireDocHome(ctx, note, "Note");
    await ctx.db.patch(id, { ...fields, updated: Date.now() });
    return await ctx.db.get(id);
  },
});

export const remove = mutation({
  args: { id: v.id("notes") },
  handler: async (ctx, { id }) => {
    const note = await ctx.db.get(id);
    if (!note) return { ok: true };
    await requireDocHome(ctx, note, "Note");
    await ctx.db.delete(id);
    return { ok: true };
  },
});
