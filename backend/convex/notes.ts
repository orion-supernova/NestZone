import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { claimFile } from "./lib/files";
import { discardHomeFile } from "./lib/moderation";

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

// A few pinned notes, for Today. Bounded: Today must not read the whole board
// to draw two cards, and a house that pins more than a handful has stopped
// pinning. One extra row tells the card there are more.
const PINNED_LIMIT = 4;

export const pinned = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("notes")
      .withIndex("by_home_pinned", (q) => q.eq("home_id", homeId).eq("pinned", true))
      .order("desc")
      .take(PINNED_LIMIT);
  },
});

// Anybody in the house may pin or unpin: the board is shared, and a pin is
// about the house's reference, not about the author. `updated` is left alone
// so pinning never reads as an edit.
export const setPinned = mutation({
  args: { id: v.id("notes"), pinned: v.boolean() },
  handler: async (ctx, { id, pinned }) => {
    await requireUser(ctx);
    const note = await ctx.db.get(id);
    if (!note) throw new Error("Note not found");
    await requireDocHome(ctx, note, "Note");
    await ctx.db.patch(id, { pinned: pinned ? true : undefined });
    return { ok: true };
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
    // Only a file this house uploaded (lib/files.ts).
    if (args.image) {
      await claimFile(ctx, args.image, { homeId: args.homeId, userId: user._id, kind: "note_image" });
    }
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
      topic: "notes",
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
    const user = await requireUser(ctx);
    const note = await ctx.db.get(id);
    if (!note) throw new Error("Note not found");
    const home = await requireDocHome(ctx, note, "Note");
    // Only a file this house uploaded (lib/files.ts).
    if (fields.image) {
      await claimFile(ctx, fields.image, { homeId: home._id, userId: user._id, kind: "note_image" });
    }
    await ctx.db.patch(id, { ...fields, updated: Date.now() });
    // A replaced picture is reclaimed, if it was this house's.
    if (fields.image && note.image && note.image !== fields.image) {
      await discardHomeFile(ctx, note.image, home._id);
    }
    return await ctx.db.get(id);
  },
});

export const remove = mutation({
  args: { id: v.id("notes") },
  handler: async (ctx, { id }) => {
    const note = await ctx.db.get(id);
    if (!note) return { ok: true };
    const home = await requireDocHome(ctx, note, "Note");
    await ctx.db.delete(id);
    // Its picture goes with it, if it was this house's (lib/files.ts).
    await discardHomeFile(ctx, note.image, home._id);
    return { ok: true };
  },
});
