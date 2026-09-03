import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember } from "./lib/auth";

/** Conversations in a home that the current user participates in. */
export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    const user = await requireUser(ctx);
    const convos = await ctx.db
      .query("conversations")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
    return convos.filter((c) => (c.participants ?? []).some((p) => p === user._id));
  },
});

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    participants: v.array(v.id("users")),
    title: v.optional(v.string()),
    is_group_chat: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const participants = Array.from(new Set([user._id, ...args.participants]));
    const now = Date.now();
    const id = await ctx.db.insert("conversations", {
      home_id: args.homeId,
      participants,
      title: args.title,
      is_group_chat: args.is_group_chat ?? participants.length > 2,
      created: now,
      updated: now,
    });
    return await ctx.db.get(id);
  },
});
