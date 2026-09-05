import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember } from "./lib/auth";
import { cascadeDeleteHome } from "./lib/relations";
import { internal } from "./_generated/api";

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
    // Every home starts with the two lists the Movies screen is built around.
    //
    // The pre-refactor client created these itself, from its own localized
    // strings, so the names froze in whatever language the app happened to be
    // in at signup — which is why older homes have English rows that never
    // translate. Creating them here fixes both halves: a home made since the
    // refactor got no lists at all, and the name below is only a label for
    // anyone reading the table. The app renders these two from `type`, so what
    // a person sees follows their language rather than the row.
    for (const preset of PRESET_LISTS) {
      await ctx.db.insert("movie_lists", {
        home_id: homeId,
        name: preset.name,
        type: preset.type,
        is_preset: true,
        created: now,
        updated: now,
      });
    }

    // Mirror PB behaviour: track the user's home membership on the user too.
    const homes = new Set([...(user.home_id ?? []), homeId]);
    await ctx.db.patch(user._id, { home_id: [...homes] });
    return await ctx.db.get(homeId);
  },
});

/** The built-in movie lists, in the order the Movies screen shows them. */
const PRESET_LISTS = [
  { type: "wishlist", name: "Wishlist" },
  { type: "watched", name: "Watched" },
] as const;

/**
 * Gives a home its built-in lists if it has none.
 *
 * For the homes made in the window where nothing created them — the refactor
 * dropped the client-side seeding before the server picked it up — so those
 * households are not left with a Movies screen that cannot save anything.
 * Idempotent: it adds only what is missing, so calling it repeatedly is safe.
 */
export const ensurePresetLists = mutation({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    const existing = await ctx.db
      .query("movie_lists")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
    const present = new Set(existing.map((l) => l.type));

    const now = Date.now();
    let added = 0;
    for (const preset of PRESET_LISTS) {
      if (present.has(preset.type)) continue;
      await ctx.db.insert("movie_lists", {
        home_id: homeId,
        name: preset.name,
        type: preset.type,
        is_preset: true,
        created: now,
        updated: now,
      });
      added++;
    }
    return { added };
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

    const wasAlreadyMember = (home.members ?? []).some((m) => m === user._id);

    const members = new Set([...(home.members ?? []), user._id]);
    await ctx.db.patch(home._id, { members: [...members], updated: Date.now() });

    const homes = new Set([...(user.home_id ?? []), home._id]);
    await ctx.db.patch(user._id, { home_id: [...homes] });

    // Re-entering a code you are already a member of is a no-op, not an
    // arrival, and must not announce one.
    if (!wasAlreadyMember) {
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: home._id,
        actor: user._id,
        title: home.name ?? "NestZone",
        body: user.name
          ? `${user.name} joined the home`
          : "Someone joined the home",
        category: "home",
      });
    }

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
