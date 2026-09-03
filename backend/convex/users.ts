import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, currentUserId } from "./lib/auth";

/** The signed-in user's profile (null when logged out). */
export const me = query({
  args: {},
  handler: async (ctx) => {
    const uid = await currentUserId(ctx);
    if (!uid) return null;
    return await ctx.db.get(uid);
  },
});

/** Update the current user's display name / avatar. */
export const updateProfile = mutation({
  args: {
    name: v.optional(v.string()),
    avatar: v.optional(v.id("_storage")),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const patch: Record<string, unknown> = {};
    if (args.name !== undefined) patch.name = args.name;
    if (args.avatar !== undefined) patch.avatar = args.avatar;
    patch.updated = Date.now();
    await ctx.db.patch(user._id, patch);
    return await ctx.db.get(user._id);
  },
});

/** Look up several users by id (e.g. to render chat participants). */
export const byIds = query({
  args: { ids: v.array(v.id("users")) },
  handler: async (ctx, { ids }) => {
    await requireUser(ctx);
    const docs = await Promise.all(ids.map((id) => ctx.db.get(id)));
    return docs.filter(Boolean);
  },
});
