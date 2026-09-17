import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, currentUserId } from "./lib/auth";
import { publicUser, publicUsers, discardAvatar } from "./lib/users";

/** The signed-in user's profile (null when logged out). */
export const me = query({
  args: {},
  handler: async (ctx) => {
    const uid = await currentUserId(ctx);
    if (!uid) return null;
    const doc = await ctx.db.get(uid);
    return doc ? await publicUser(ctx, doc) : null;
  },
});

/** Update the current user's display name. */
export const updateProfile = mutation({
  args: {
    name: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const patch: Record<string, unknown> = {};
    if (args.name !== undefined) patch.name = args.name;
    patch.updated = Date.now();
    await ctx.db.patch(user._id, patch);
    const doc = await ctx.db.get(user._id);
    return doc ? await publicUser(ctx, doc) : null;
  },
});

/** Look up several users by id (e.g. to render chat participants). */
export const byIds = query({
  args: { ids: v.array(v.id("users")) },
  handler: async (ctx, { ids }) => {
    await requireUser(ctx);
    const docs = await Promise.all(ids.map((id) => ctx.db.get(id)));
    return await publicUsers(
      ctx,
      docs.filter((doc): doc is NonNullable<typeof doc> => doc !== null),
    );
  },
});

// ---------------------------------------------------------------------------
// The profile photo
//
// Two calls, and the split is the same one the photos on a house problem make:
// the bytes never pass through a mutation. A profile photo off a modern phone
// is several megabytes of HEIC, and a transaction is the wrong place to carry
// it — so Convex signs a one-shot URL, the phone posts straight to it, and only
// the storage id it answers with reaches `setAvatar`.

/** A one-shot URL the phone can POST an image to. */
export const avatarUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    await requireUser(ctx);
    return await ctx.storage.generateUploadUrl();
  },
});

/**
 * Points the signed-in user at an uploaded photo, or takes their photo off.
 *
 * The *only* thing that writes `users.avatar`, which is what makes the old file
 * impossible to leak by accident: every replacement and every removal passes
 * through the one place that knows to reclaim what it is replacing. It used to
 * be a field on `updateProfile` alongside the name, where a caller who set a
 * new avatar silently stranded the previous one in storage forever.
 *
 * `null` clears it rather than an omitted argument, because "not mentioned" and
 * "take it off" have to be different requests — an optional field can only say
 * the first.
 *
 * Nobody else's photo is reachable from here: the id being patched is the
 * caller's own, never an argument.
 */
export const setAvatar = mutation({
  args: { storageId: v.union(v.id("_storage"), v.null()) },
  handler: async (ctx, { storageId }) => {
    const user = await requireUser(ctx);
    const previous = user.avatar;

    await ctx.db.patch(user._id, {
      avatar: storageId ?? undefined,
      updated: Date.now(),
    });

    // Never the file we just pointed at: a client that re-submits the same id
    // would otherwise delete the photo it just set.
    if (previous && previous !== storageId) {
      await discardAvatar(ctx, previous);
    }

    const doc = await ctx.db.get(user._id);
    return doc ? await publicUser(ctx, doc) : null;
  },
});
