import { query, mutation, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { Doc } from "./_generated/dataModel";
import { requireUser, requireHomeMember } from "./lib/auth";
import { departHome } from "./lib/membership";
import { purgeHomeBatch } from "./lib/relations";
import { publicUsers } from "./lib/users";
import { internal } from "./_generated/api";

/**
 * Homes the current user belongs to.
 *
 * Read through the user's own `home_id` mirror rather than by collecting every
 * home in the deployment and filtering in JavaScript. That scan was not scoped
 * to the household or even to the account — it grew with the number of homes
 * *every user of the app* had ever made, and it sits on the launch path: this
 * is the query the launch screen waits for. One household's cold start got
 * slower every time a stranger signed up.
 *
 * The mirror is safe to navigate by because it cannot drift. Membership is
 * written in exactly three places — create, join and leave — and each of them
 * patches `homes.members` and the user's `home_id` in the same mutation, which
 * in Convex is one transaction. `cascadeDeleteHome` scrubs it the same way.
 *
 * Membership is still decided by `homes.members`, which is what
 * `requireHomeMember` enforces, so the mirror only ever narrows what is looked
 * at — it never grants a home the members list does not agree with.
 */
export const listMine = query({
  args: {},
  handler: async (ctx) => {
    const user = await requireUser(ctx);
    const docs = await Promise.all((user.home_id ?? []).map((id) => ctx.db.get(id)));
    return docs.filter(
      (home): home is Doc<"homes"> =>
        home !== null && (home.members ?? []).some((m) => m === user._id),
    );
  },
});

export const get = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    return await requireHomeMember(ctx, homeId);
  },
});

/**
 * Member user docs for a home, each carrying a loadable avatar URL.
 *
 * This is the subscription seven features already hold — Home, Tasks, Messages,
 * Calendar, Finance, Issues and Settings all read the household off it — so it
 * is also the cheapest place in the app to learn what everybody looks like.
 * Resolving the photo here is what lets `AvatarDirectory` fill itself from a
 * read every screen was doing anyway, instead of an avatar having to be
 * threaded through eight features' member models.
 */
export const members = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    const home = await requireHomeMember(ctx, homeId);
    const docs = await Promise.all((home.members ?? []).map((id) => ctx.db.get(id)));
    return await publicUsers(
      ctx,
      docs.filter((doc): doc is NonNullable<typeof doc> => doc !== null),
    );
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
    await Promise.all(
      PRESET_LISTS.map((preset) =>
        ctx.db.insert("movie_lists", {
          home_id: homeId,
          name: preset.name,
          type: preset.type,
          is_preset: true,
          created: now,
          updated: now,
        }),
      ),
    );

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
    const missing = PRESET_LISTS.filter((preset) => !present.has(preset.type));
    await Promise.all(
      missing.map((preset) =>
        ctx.db.insert("movie_lists", {
          home_id: homeId,
          name: preset.name,
          type: preset.type,
          is_preset: true,
          created: now,
          updated: now,
        }),
      ),
    );
    const added = missing.length;
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
    // Last member out takes the home with them (lib/membership.ts).
    const departure = await departHome(ctx, home, user._id);
    return { ok: true, ...departure };
  },
});

/** Batches after which a purge still running is logged as an error. */
const PURGE_WARN_ROUNDS = 200;

/**
 * Drains a deleted home's rows, one bounded batch per transaction, scheduling
 * the next until nothing is left (lib/relations.ts, `purgeHomeBatch`). The
 * home document is already gone, so nobody can reach these rows meanwhile.
 *
 * Every batch is logged with what it removed, and a purge that keeps going
 * past 200 batches is logged as an error each time, so one that is stuck or
 * failing is loud in `npx convex logs` rather than quietly half-done. A batch
 * that throws is retried by nothing — the error is in the logs with the home
 * id, and running this again with that id resumes where it stopped.
 */
export const purgeHomeData = internalMutation({
  args: { homeId: v.id("homes"), round: v.optional(v.number()) },
  returns: v.object({ removed: v.number(), more: v.boolean() }),
  handler: async (ctx, { homeId, round }) => {
    const n = round ?? 0;
    if (await ctx.db.get(homeId)) {
      console.error(`homes:purgeHomeData refused: home ${homeId} still exists`);
      return { removed: 0, more: false };
    }
    const { removed, more } = await purgeHomeBatch(ctx, homeId);
    if (n >= PURGE_WARN_ROUNDS) {
      console.error(`homes:purgeHomeData ${homeId} still running at batch ${n} (removed ${removed})`);
    } else {
      console.log(`homes:purgeHomeData ${homeId} batch ${n}: removed ${removed}${more ? ", more to go" : ", done"}`);
    }
    if (more) {
      await ctx.scheduler.runAfter(0, internal.homes.purgeHomeData, { homeId, round: n + 1 });
    }
    return { removed, more };
  },
});

/**
 * Takes another member out of a home.
 *
 * Houses are invite-only, so this is the house's answer to somebody who
 * should no longer be in it (App Review asks for one where people share
 * messages and photos). Any member may do it — there is no owner — and never
 * to themselves: that is `leave`, which may delete the home, and this never
 * can, because the caller stays.
 *
 * Idempotent: somebody already gone is `removed: false`, not an error, so a
 * retry or two phones doing it at once land the same. What they wrote stays
 * with the household, exactly as when somebody leaves.
 */
export const removeMember = mutation({
  args: { homeId: v.id("homes"), userId: v.id("users") },
  returns: v.object({ ok: v.boolean(), removed: v.boolean() }),
  handler: async (ctx, { homeId, userId }) => {
    const caller = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    if (userId === caller._id) throw new Error("To leave a home yourself, use leave");
    if (!(home.members ?? []).includes(userId)) return { ok: true, removed: false };

    const removedUser = await ctx.db.get(userId);
    await departHome(ctx, home, userId);
    // A new invite code, or the person just removed could walk straight back
    // in with the one they already have. Old codes simply stop matching.
    await ctx.db.patch(homeId, { invite_code: crypto.randomUUID().toUpperCase() });

    const homeName = home.name ?? "Your home";
    // The person removed hears it as a push only: the home's feed is no
    // longer theirs to read, so no row is filed for them (no `homeId`).
    await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
      userIds: [userId],
      actor: caller._id,
      title: homeName,
      body: caller.name
        ? `${caller.name} removed you from the home`
        : "You were removed from the home",
      category: "home",
    });
    // And the house is told, so a removal is never silent to the people
    // still living there.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId,
      actor: caller._id,
      title: homeName,
      body:
        (caller.name && removedUser?.name
          ? `${caller.name} removed ${removedUser.name} from the home`
          : "Someone was removed from the home") +
        ". The invite code has changed.",
      category: "home",
    });
    return { ok: true, removed: true };
  },
});
