// Household Pro, read from RevenueCat and judged here.
//
// RevenueCat runs the purchase, the receipts and the renewals; this
// deployment stays the only judge of what a house may do, because every old
// build and every modified client talks to the same server. So the phone
// never says "I'm Pro" — it asks the server to look (`refresh`, after a
// purchase or a restore and once per launch), and the server asks RevenueCat
// with the secret key and writes the answer (`pro_entitlements`).
//
// Pull before push: a RevenueCat webhook would need the tunnel to forward a
// new path to the HTTP-actions origin, and pulling needs nothing new. The
// sweep below re-asks about rows near their end, so a cancelled subscription
// ends on time even if nobody opens the app, and about every other row once a
// day, so a purchase moved to another account by a restore, or a refunded
// lifetime, stops carrying houses within a day.
//
// The HTTP calls, and the key they need, are in lib/revenuecat.ts.

import { v } from "convex/values";
import {
  action,
  internalAction,
  internalMutation,
  internalQuery,
  query,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { requireUser, requireHomeMember } from "./lib/auth";
import { entitlementActive, homeProStatus, proAllows, proEnforced } from "./lib/pro";
import { fetchEntitlement, revenueCatConfigured } from "./lib/revenuecat";

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

/** The sweep's window: about to expire, or expired within billing grace. */
const SWEEP_AHEAD_MS = DAY;
const SWEEP_BEHIND_MS = 3 * DAY;
/** Every row, lifetime included, is re-asked at least this often. */
const RECHECK_MS = DAY;
/** Rows asked about per sweep round. */
const SWEEP_BATCH = 100;
/** Rounds one sweep may chain before waiting for the next cron. */
const SWEEP_MAX_ROUNDS = 20;
/** A row in the expiry window checked this recently is not asked again. */
const SWEEP_MIN_AGE_MS = HOUR;
/** `refresh` answers from the row instead of RevenueCat this soon after. */
const REFRESH_REUSE_MS = 10_000;
/** A row this long past its end grants nothing and is dropped. */
const FORGET_AFTER_MS = 30 * DAY;

// MARK: - Reading

const statusShape = v.object({
  pro: v.boolean(),
  /** Whether the server refuses Pro writes right now (`PRO_ENFORCE`). */
  enforced: v.boolean(),
  carriedBy: v.union(v.object({ id: v.id("users"), name: v.union(v.string(), v.null()) }), v.null()),
  /** When the carrier's access ends; null for lifetime, comped, or not Pro. */
  expiresAt: v.union(v.number(), v.null()),
  willRenew: v.union(v.boolean(), v.null()),
  /** The caller's own entitlement is what carries it. */
  mine: v.boolean(),
});

/**
 * Whether this house is Pro, live.
 *
 * A subscription, so a purchase on one phone unlocks every phone in the house
 * the moment `refresh` writes the row. Members only. `pro` is the truth
 * whatever `enforced` says: the new app gates itself from it regardless, and
 * `enforced` only tells it whether the server would refuse too.
 */
export const status = query({
  args: { homeId: v.id("homes") },
  returns: statusShape,
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    const s = await homeProStatus(ctx, home, user._id);
    let carriedBy: { id: Id<"users">; name: string | null } | null = null;
    if (s.carriedBy) {
      const carrier = await ctx.db.get(s.carriedBy);
      carriedBy = { id: s.carriedBy, name: carrier?.name ?? null };
    }
    return {
      pro: s.pro,
      enforced: proEnforced(),
      carriedBy,
      expiresAt: s.expiresAt ?? null,
      willRenew: s.willRenew ?? null,
      mine: s.carriedBy === user._id,
    };
  },
});

/** For `push.notifyHome`: may this house hear about a Pro domain? */
export const homeAllows = internalQuery({
  args: { homeId: v.id("homes") },
  returns: v.boolean(),
  handler: async (ctx, { homeId }) => {
    return await proAllows(ctx, homeId);
  },
});

export const callerId = internalQuery({
  args: {},
  returns: v.id("users"),
  handler: async (ctx) => (await requireUser(ctx))._id,
});

// MARK: - RevenueCat's answer, recorded

const entitlementShape = v.object({
  expiresAt: v.union(v.number(), v.null()),
  productId: v.optional(v.string()),
  store: v.optional(v.string()),
  isSandbox: v.boolean(),
  willRenew: v.boolean(),
});

/**
 * Writes RevenueCat's answer for one person.
 *
 * `null` (no entitlement: never had one, refunded, or moved to another user
 * by a restore) writes the row as ended now rather than deleting it, so a
 * house the person carried loses Pro at once. A row more than 30 days past
 * its end grants nothing and is dropped.
 */
export const store = internalMutation({
  args: { userId: v.id("users"), entitlement: v.union(entitlementShape, v.null()) },
  returns: v.null(),
  handler: async (ctx, { userId, entitlement }) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("pro_entitlements")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .take(10);
    const [first, ...extra] = rows;
    // One row per person; two concurrent refreshes may have made a second.
    await Promise.all(extra.map((r) => ctx.db.delete(r._id)));

    const forgotten = (expiresAt: number | null) =>
      expiresAt !== null && expiresAt < now - FORGET_AFTER_MS;

    if (entitlement === null) {
      if (!first) return null;
      if (forgotten(first.expires_at)) {
        await ctx.db.delete(first._id);
        return null;
      }
      await ctx.db.patch(first._id, {
        expires_at: first.expires_at === null ? now : Math.min(first.expires_at, now),
        will_renew: false,
        checked_at: now,
      });
      return null;
    }
    if (forgotten(entitlement.expiresAt)) {
      if (first) await ctx.db.delete(first._id);
      return null;
    }
    // A user deleted while the lookup was out: write nothing for nobody.
    if (!(await ctx.db.get(userId))) return null;
    const fields = {
      user_id: userId,
      expires_at: entitlement.expiresAt,
      product_id: entitlement.productId,
      store: entitlement.store,
      is_sandbox: entitlement.isSandbox,
      will_renew: entitlement.willRenew,
      checked_at: now,
    };
    if (first) await ctx.db.replace(first._id, fields);
    else await ctx.db.insert("pro_entitlements", fields);
    return null;
  },
});

/** The caller's own row, for `refresh`'s short-circuit. */
export const ownRow = internalQuery({
  args: { userId: v.id("users") },
  returns: v.union(
    v.object({
      checkedAt: v.number(),
      active: v.boolean(),
      expiresAt: v.union(v.number(), v.null()),
    }),
    v.null(),
  ),
  handler: async (ctx, { userId }) => {
    const row = await ctx.db
      .query("pro_entitlements")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .first();
    if (!row) return null;
    return {
      checkedAt: row.checked_at,
      active: entitlementActive(row, Date.now()),
      expiresAt: row.expires_at,
    };
  },
});

/**
 * Asks RevenueCat about the caller and records the answer.
 *
 * Called by the app after a purchase or a restore, and once per launch. The
 * house's `status` subscription moves on its own once the row is written.
 * `active` is the caller's own entitlement, judged as `status` judges it
 * (a sandbox purchase is active only while `PRO_SANDBOX` is on). Within 10
 * seconds of the last check it answers from the row without asking again,
 * so a double tap or a launch racing a restore costs one lookup.
 */
export const refresh = action({
  args: {},
  returns: v.object({ active: v.boolean(), expiresAt: v.union(v.number(), v.null()) }),
  handler: async (ctx): Promise<{ active: boolean; expiresAt: number | null }> => {
    const userId: Id<"users"> = await ctx.runQuery(internal.pro.callerId, {});
    const recent: { checkedAt: number; active: boolean; expiresAt: number | null } | null =
      await ctx.runQuery(internal.pro.ownRow, { userId });
    if (recent && recent.checkedAt > Date.now() - REFRESH_REUSE_MS) {
      return { active: recent.active, expiresAt: recent.expiresAt };
    }
    const entitlement = await fetchEntitlement(userId);
    await ctx.runMutation(internal.pro.store, { userId, entitlement });
    if (!entitlement) return { active: false, expiresAt: null };
    const sandboxOk = !entitlement.isSandbox || process.env.PRO_SANDBOX === "on";
    const active =
      sandboxOk && (entitlement.expiresAt === null || entitlement.expiresAt > Date.now());
    return { active, expiresAt: entitlement.expiresAt };
  },
});

// MARK: - The sweep

/**
 * Who the sweep should ask about next, most urgent first: rows ending within
 * a day, then rows that ended within billing grace (each oldest answer
 * first), then any row not asked about for a day — lifetime included —
 * oldest answer first. `more` says whether anything is left for another round.
 */
export const dueForCheck = internalQuery({
  args: {},
  returns: v.object({ users: v.array(v.id("users")), more: v.boolean() }),
  handler: async (ctx) => {
    const now = Date.now();
    const window = await ctx.db
      .query("pro_entitlements")
      .withIndex("by_expires", (q) =>
        q.gte("expires_at", now - SWEEP_BEHIND_MS).lte("expires_at", now + SWEEP_AHEAD_MS),
      )
      .take(SWEEP_BATCH * 10);
    const ended = (expiresAt: number | null) => (expiresAt !== null && expiresAt < now ? 1 : 0);
    const urgent = window
      .filter((r) => r.checked_at < now - SWEEP_MIN_AGE_MS)
      .sort((a, b) => ended(a.expires_at) - ended(b.expires_at) || a.checked_at - b.checked_at);
    const stale = await ctx.db
      .query("pro_entitlements")
      .withIndex("by_checked", (q) => q.lt("checked_at", now - RECHECK_MS))
      .take(SWEEP_BATCH);

    const seen = new Set<string>();
    const users: Id<"users">[] = [];
    for (const row of [...urgent, ...stale]) {
      if (seen.has(row.user_id)) continue;
      seen.add(row.user_id);
      users.push(row.user_id);
    }
    return {
      users: users.slice(0, SWEEP_BATCH),
      more: users.length > SWEEP_BATCH || stale.length === SWEEP_BATCH,
    };
  },
});

/**
 * Re-asks RevenueCat about everyone due (see `dueForCheck`), a hundred at a
 * time, chaining rounds while there is more and the last round made progress
 * — at most twenty — so a backlog drains in one run and a RevenueCat outage
 * ends the chain instead of spinning it. Every 6 hours (convex/crons.ts).
 * Quiet without a key.
 */
export const sweep = internalAction({
  args: { round: v.optional(v.number()) },
  returns: v.object({ checked: v.number(), failed: v.number() }),
  handler: async (ctx, { round }): Promise<{ checked: number; failed: number }> => {
    if (!revenueCatConfigured()) return { checked: 0, failed: 0 };
    const due: { users: Id<"users">[]; more: boolean } = await ctx.runQuery(
      internal.pro.dueForCheck,
      {},
    );
    let checked = 0;
    let failed = 0;
    // A few at a time: polite to RevenueCat, and one failure costs one row.
    for (let i = 0; i < due.users.length; i += 5) {
      await Promise.all(
        due.users.slice(i, i + 5).map(async (userId) => {
          try {
            const entitlement = await fetchEntitlement(userId);
            await ctx.runMutation(internal.pro.store, { userId, entitlement });
            checked += 1;
          } catch (error) {
            failed += 1;
            console.error(`pro:sweep could not check ${userId}: ${String(error)}`);
          }
        }),
      );
    }
    const next = (round ?? 0) + 1;
    if (due.more && checked > 0 && next < SWEEP_MAX_ROUNDS) {
      await ctx.scheduler.runAfter(0, internal.pro.sweep, { round: next });
    } else if (due.more) {
      console.error(
        `pro:sweep stopped at round ${next} with rows still due (checked ${checked}, failed ${failed})`,
      );
    }
    return { checked, failed };
  },
});
