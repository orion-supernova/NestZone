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
// ends on time even if nobody opens the app.
//
// The RevenueCat app user id IS the Convex user id (`users._id`), set by the
// app at sign-in.
//
//   npx convex env set REVENUECAT_SECRET_KEY sk_...   (the v1 secret key)

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
import { homeProStatus, proAllows, proEnforced } from "./lib/pro";

const ENTITLEMENT = "pro";
const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

/** The sweep's window: about to expire, or expired within billing grace. */
const SWEEP_AHEAD_MS = DAY;
const SWEEP_BEHIND_MS = 3 * DAY;
/** Rows asked about per sweep. Every six hours, so 4 × this a day. */
const SWEEP_BATCH = 100;
/** A row checked this recently is not asked about again by the sweep. */
const SWEEP_MIN_AGE_MS = HOUR;

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

// MARK: - RevenueCat

const entitlementShape = v.object({
  expiresAt: v.union(v.number(), v.null()),
  productId: v.optional(v.string()),
  store: v.optional(v.string()),
  isSandbox: v.boolean(),
  willRenew: v.boolean(),
});

type Entitlement = {
  expiresAt: number | null;
  productId?: string;
  store?: string;
  isSandbox: boolean;
  willRenew: boolean;
};

function parseDate(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
}

/**
 * Asks RevenueCat about one person. `null`: no `pro` entitlement, ever.
 *
 * An expired entitlement comes back with its past date rather than as null,
 * so the row records when it ended. Billing grace counts as access: Apple
 * keeps the subscriber's access through it, and so does the house.
 */
async function fetchEntitlement(userId: string): Promise<Entitlement | null> {
  const key = process.env.REVENUECAT_SECRET_KEY;
  if (!key) {
    throw new Error(
      "REVENUECAT_SECRET_KEY is not set on this deployment, so Pro cannot be checked. " +
        "See the header of convex/pro.ts.",
    );
  }
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    {
      headers: {
        Authorization: `Bearer ${key}`,
        Accept: "application/json",
      },
    },
  );
  if (!response.ok) {
    // Never written as "not Pro": a RevenueCat outage must not lock a paying
    // house out. The row keeps what it said last.
    throw new Error(`RevenueCat answered ${response.status} for a subscriber lookup`);
  }
  const body = (await response.json()) as { subscriber?: any };
  const subscriber = body.subscriber ?? {};
  const ent = subscriber.entitlements?.[ENTITLEMENT];
  if (!ent || typeof ent !== "object") return null;

  const productId: string | undefined =
    typeof ent.product_identifier === "string" ? ent.product_identifier : undefined;

  // Lifetime: no expiry on the entitlement.
  const expires = parseDate(ent.expires_date);
  const grace = parseDate(ent.grace_period_expires_date);
  const lifetime = ent.expires_date === null || ent.expires_date === undefined;
  const expiresAt = lifetime ? null : Math.max(expires ?? 0, grace ?? 0);

  const sub = productId ? subscriber.subscriptions?.[productId] : undefined;
  // A non-renewing (lifetime) purchase lives under `non_subscriptions`, as a
  // list of purchases of that product.
  const nonSubs: any[] | undefined =
    productId && Array.isArray(subscriber.non_subscriptions?.[productId])
      ? subscriber.non_subscriptions[productId]
      : undefined;
  const purchase = sub ?? nonSubs?.[nonSubs.length - 1];

  const isSandbox = purchase?.is_sandbox === true;
  const store: string | undefined =
    typeof purchase?.store === "string" ? purchase.store : undefined;
  const willRenew = sub
    ? !sub.unsubscribe_detected_at && !sub.billing_issues_detected_at
    : false;

  return { expiresAt, productId, store, isSandbox, willRenew };
}

/** Writes RevenueCat's answer for one person. `null` removes their row. */
export const store = internalMutation({
  args: { userId: v.id("users"), entitlement: v.union(entitlementShape, v.null()) },
  returns: v.null(),
  handler: async (ctx, { userId, entitlement }) => {
    const rows = await ctx.db
      .query("pro_entitlements")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .take(10);
    if (entitlement === null) {
      await Promise.all(rows.map((r) => ctx.db.delete(r._id)));
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
      checked_at: Date.now(),
    };
    const [first, ...extra] = rows;
    if (first) await ctx.db.replace(first._id, fields);
    else await ctx.db.insert("pro_entitlements", fields);
    // One row per person; two concurrent refreshes may have made a second.
    await Promise.all(extra.map((r) => ctx.db.delete(r._id)));
    return null;
  },
});

/**
 * Asks RevenueCat about the caller and records the answer.
 *
 * Called by the app after a purchase or a restore, and once per launch. The
 * house's `status` subscription moves on its own once the row is written.
 * `active` is the caller's own entitlement, judged as `status` judges it
 * (a sandbox purchase is active only while `PRO_SANDBOX` is on).
 */
export const refresh = action({
  args: {},
  returns: v.object({ active: v.boolean(), expiresAt: v.union(v.number(), v.null()) }),
  handler: async (ctx): Promise<{ active: boolean; expiresAt: number | null }> => {
    const userId: Id<"users"> = await ctx.runQuery(internal.pro.callerId, {});
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

/** Rows whose end is near or just past, not checked within the last hour. */
export const dueForCheck = internalQuery({
  args: {},
  returns: v.array(v.id("users")),
  handler: async (ctx) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("pro_entitlements")
      .withIndex("by_expires", (q) =>
        q.gte("expires_at", now - SWEEP_BEHIND_MS).lte("expires_at", now + SWEEP_AHEAD_MS),
      )
      .take(SWEEP_BATCH * 3);
    return rows
      .filter((r) => r.checked_at < now - SWEEP_MIN_AGE_MS)
      .slice(0, SWEEP_BATCH)
      .map((r) => r.user_id);
  },
});

/**
 * Re-asks RevenueCat about everyone whose access ends within a day or ended
 * within the last three (Apple's billing grace). A renewal moves the row out
 * of the window; a cancellation lets it lapse on time. Every 6 hours
 * (convex/crons.ts). Quiet without a key, so a deployment that has not set
 * up RevenueCat yet logs nothing every six hours.
 */
export const sweep = internalAction({
  args: {},
  returns: v.object({ checked: v.number(), failed: v.number() }),
  handler: async (ctx): Promise<{ checked: number; failed: number }> => {
    if (!process.env.REVENUECAT_SECRET_KEY) return { checked: 0, failed: 0 };
    const due: Id<"users">[] = await ctx.runQuery(internal.pro.dueForCheck, {});
    let checked = 0;
    let failed = 0;
    // A few at a time: polite to RevenueCat, and one failure costs one row.
    for (let i = 0; i < due.length; i += 5) {
      await Promise.all(
        due.slice(i, i + 5).map(async (userId) => {
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
    return { checked, failed };
  },
});
