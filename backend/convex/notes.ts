import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("notes")
      .filter((q) => q.eq(q.field("home_id"), homeId))
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
    return await ctx.db.insert("notes", {
      home_id: args.homeId,
      description: args.description,
      color: args.color,
      image: args.image,
      created_by: user._id,
      created: now,
      updated: now,
    });
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
