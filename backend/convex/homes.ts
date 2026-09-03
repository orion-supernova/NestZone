import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember } from "./lib/auth";
import { cascadeDeleteHome } from "./lib/relations";

/** Homes the current user belongs to. */
export const listMine = query({
  args: {},
  handler: async (ctx) => {
    const user = await requireUser(ctx);
    // Small dataset: scan and filter membership. Add an index if homes grow large.
    const all = await ctx.db.query("homes").collect();
    return all.filter((h) => (h.members ?? []).some((m) => m === user._id));
  },
});

export const get = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    return await requireHomeMember(ctx, homeId);
  },
});

/** Member user docs for a home. */
export const members = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    const home = await requireHomeMember(ctx, homeId);
    const docs = await Promise.all((home.members ?? []).map((id) => ctx.db.get(id)));
    return docs.filter(Boolean);
  },
});

export const create = mutation({
  args: {
    name: v.string(),
    address: v.optional(v.object({ lat: v.number(), lng: v.number() })),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const now = Date.now();
    const inviteCode = crypto.randomUUID().toUpperCase();
    const homeId = await ctx.db.insert("homes", {
      name: args.name,
      address: args.address,
      members: [user._id],
      invite_code: inviteCode,
      created: now,
      updated: now,
    });
    // Mirror PB behaviour: track the user's home membership on the user too.
    const homes = new Set([...(user.home_id ?? []), homeId]);
    await ctx.db.patch(user._id, { home_id: [...homes] });
    return await ctx.db.get(homeId);
  },
});

/** Join a home using its invite code. */
export const join = mutation({
  args: { inviteCode: v.string() },
  handler: async (ctx, { inviteCode }) => {
    const user = await requireUser(ctx);
    const home = await ctx.db
      .query("homes")
      .withIndex("by_invite_code", (q) => q.eq("invite_code", inviteCode))
      .first();
    if (!home) throw new Error("Invalid invite code");

    const members = new Set([...(home.members ?? []), user._id]);
    await ctx.db.patch(home._id, { members: [...members], updated: Date.now() });

    const homes = new Set([...(user.home_id ?? []), home._id]);
    await ctx.db.patch(user._id, { home_id: [...homes] });
    return await ctx.db.get(home._id);
  },
});

export const leave = mutation({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    const remaining = (home.members ?? []).filter((m) => m !== user._id);

    // Last member out takes the home and everything in it. Otherwise the rows
    // survive with nobody able to satisfy requireHomeMember — permanently
    // unreadable data that no code path could ever reach or clean up again.
    if (remaining.length === 0) {
      const removed = await cascadeDeleteHome(ctx, homeId);
      return { ok: true, deletedHome: true, removed };
    }

    await ctx.db.patch(homeId, { members: remaining, updated: Date.now() });
    await ctx.db.patch(user._id, {
      home_id: (user.home_id ?? []).filter((h) => h !== homeId),
    });
    return { ok: true, deletedHome: false };
  },
});
