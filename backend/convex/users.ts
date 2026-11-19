import { query, mutation, action, internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { requireUser, currentUserId } from "./lib/auth";
import { publicUser, publicUsers, discardAvatar } from "./lib/users";
import { revokeAppleAuthorization } from "./lib/apple";
import { departHome } from "./lib/membership";

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

// ---------------------------------------------------------------------------
// Deleting the account (App Store Guideline 5.1.1(v))
//
// The person goes; the household's record of what they did stays. Every home
// they are in is left exactly as `homes:leave` leaves it — the last one out
// takes the home and its data — and then everything that is theirs alone goes:
// sign-in rows, devices, read marks, the Pro row, the photo, the user. What
// they wrote into a shared home (messages, chores, expenses, comments) stays
// for the people still living there, pointing at an id that no longer
// resolves: `users:byIds` and `homes:members` drop it, and the app draws an
// author it cannot find as nobody in particular.
//
// Bounded: one phase per transaction, each phase capped, rescheduling itself
// until nothing is left. A person in three homes with years of history is
// several short transactions, never one that runs out of reads.

/** Rows of one kind removed per transaction. */
const DELETE_BATCH = 100;
/** Sign-in sessions handled per transaction (each with its refresh tokens). */
const SESSION_BATCH = 20;
/** Longest authorization code accepted. Apple's are well under this. */
const MAX_AUTH_CODE = 4096;

export const callerId = internalQuery({
  args: {},
  returns: v.id("users"),
  handler: async (ctx) => (await requireUser(ctx))._id,
});

/**
 * Deletes the signed-in person's account.
 *
 * `authorizationCode` is a fresh one from Sign in with Apple, asked for on
 * the confirm step; with it (and SIWA_* set) the app's access is revoked at
 * Apple too. That half is best effort — logged, never blocking — because the
 * person asked for their account to be gone, not for Apple to be reachable.
 *
 * The sign-in rows go before this returns, so the session ends at once; the
 * homes and the rest follow in scheduled steps within seconds.
 */
export const deleteAccount = action({
  args: { authorizationCode: v.optional(v.string()) },
  returns: v.object({ ok: v.boolean(), appleRevoked: v.boolean() }),
  handler: async (ctx, { authorizationCode }): Promise<{ ok: boolean; appleRevoked: boolean }> => {
    const userId: Id<"users"> = await ctx.runQuery(internal.users.callerId, {});

    let appleRevoked = false;
    if (authorizationCode && authorizationCode.length <= MAX_AUTH_CODE) {
      try {
        appleRevoked = await revokeAppleAuthorization(authorizationCode);
      } catch (error) {
        console.error(`Sign in with Apple revocation failed: ${String(error)}`);
      }
    }

    await ctx.runMutation(internal.users.deleteAccountStep, { userId });
    return { ok: true, appleRevoked };
  },
});

/**
 * One bounded step of deleting `userId`. Idempotent: it works out what is
 * left from the data and schedules itself again until the user row is gone.
 */
export const deleteAccountStep = internalMutation({
  args: { userId: v.id("users") },
  returns: v.object({ done: v.boolean() }),
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user) return { done: true };
    const continueLater = async () => {
      await ctx.scheduler.runAfter(0, internal.users.deleteAccountStep, { userId });
      return { done: false };
    };

    // 1. Every way back in, and every device: sessions with their refresh
    //    tokens, linked sign-in accounts with their codes, push tokens. First,
    //    so the account is unusable and silent before anything else moves.
    let more = false;
    const sessions = await ctx.db
      .query("authSessions")
      .withIndex("userId", (q) => q.eq("userId", userId))
      .take(SESSION_BATCH);
    for (const session of sessions) {
      const tokens = await ctx.db
        .query("authRefreshTokens")
        .withIndex("sessionId", (q) => q.eq("sessionId", session._id))
        .take(DELETE_BATCH);
      await Promise.all(tokens.map((t) => ctx.db.delete(t._id)));
      if (tokens.length < DELETE_BATCH) await ctx.db.delete(session._id);
      else more = true;
    }
    if (sessions.length === SESSION_BATCH) more = true;

    const accounts = await ctx.db
      .query("authAccounts")
      .withIndex("userIdAndProvider", (q) => q.eq("userId", userId))
      .take(SESSION_BATCH);
    for (const account of accounts) {
      const codes = await ctx.db
        .query("authVerificationCodes")
        .withIndex("accountId", (q) => q.eq("accountId", account._id))
        .take(DELETE_BATCH);
      await Promise.all(codes.map((c) => ctx.db.delete(c._id)));
      if (codes.length < DELETE_BATCH) await ctx.db.delete(account._id);
      else more = true;
    }
    if (accounts.length === SESSION_BATCH) more = true;

    const devices = await ctx.db
      .query("push_tokens")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .take(DELETE_BATCH);
    await Promise.all(devices.map((d) => ctx.db.delete(d._id)));
    if (devices.length === DELETE_BATCH) more = true;

    if (more || sessions.length + accounts.length + devices.length > 0) {
      return await continueLater();
    }

    // 2. Homes, one per step: leaving one may delete a whole household.
    const homeId = (user.home_id ?? [])[0];
    if (homeId) {
      const home = await ctx.db.get(homeId);
      if (home && (home.members ?? []).includes(userId)) {
        await departHome(ctx, home, userId);
      } else {
        // A mirror entry with no membership behind it: just drop it.
        await ctx.db.patch(userId, {
          home_id: (user.home_id ?? []).filter((h) => h !== homeId),
        });
      }
      return await continueLater();
    }

    // 3. What was only theirs: read marks, the Pro row.
    const [reads, updateReads, pro] = await Promise.all([
      ctx.db
        .query("activity_reads")
        .withIndex("by_user_home", (q) => q.eq("user_id", userId))
        .take(DELETE_BATCH),
      ctx.db
        .query("update_reads")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .take(DELETE_BATCH),
      ctx.db
        .query("pro_entitlements")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .take(DELETE_BATCH),
    ]);
    const own = [...reads, ...updateReads, ...pro];
    await Promise.all(own.map((r) => ctx.db.delete(r._id)));
    if (own.length > 0) return await continueLater();

    // 4. The photo and the person.
    await discardAvatar(ctx, user.avatar);
    await ctx.db.delete(userId);
    return { done: true };
  },
});
