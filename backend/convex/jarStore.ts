// Crediting and debiting the house jar for App Store money.
//
// The Node action in convex/jar.ts proves a transaction is Apple's; these
// internal mutations decide what it does to a jar. They are separate files
// because a "use node" module can export only actions, and the decision has to
// be one transaction: the purchase row, the ledger row and the balance are
// written together or not at all, so a top-up is never half credited and two
// phones sending the same receipt at the same moment credit it once (Convex
// serialises them on the `jar_purchases` read).

import { v } from "convex/values";
import { internalMutation, internalQuery, MutationCtx } from "./_generated/server";
import { Doc, Id } from "./_generated/dataModel";
import { requireHomeMember, requireUser } from "./lib/auth";
import { ensureHouse, houseFor, moveJar } from "./lib/companion";
import {
  JarEnvironment,
  accountToken,
  environmentValue,
  jarEnvironments,
  ledgerKey,
  mayUseTestStore,
  sparklesFor,
  topUpResult,
} from "./lib/jar";

/**
 * Who is asking, before anything is verified: a member of the house, and
 * whether they may use the Xcode test store. Membership is checked first so a
 * stranger learns nothing about a transaction, not even whether it is valid.
 */
export const caller = internalQuery({
  args: { homeId: v.id("homes") },
  returns: v.object({ mayTest: v.boolean() }),
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    return { mayTest: mayUseTestStore(user) };
  },
});

async function purchaseFor(
  ctx: MutationCtx,
  transactionId: string,
  environment: JarEnvironment,
): Promise<Doc<"jar_purchases"> | null> {
  return await ctx.db
    .query("jar_purchases")
    .withIndex("by_transaction_environment", (q) =>
      q.eq("transaction_id", transactionId).eq("environment", environment),
    )
    .first();
}

async function jarOf(ctx: MutationCtx, homeId: Id<"homes">) {
  const house = await houseFor(ctx, homeId);
  return house ? { leaves: house.leaves, sparkles: house.sparkles } : null;
}

/**
 * Takes a credited transaction's Sparkles back out of the jar it went into,
 * once, and marks it revoked. The jar may go below zero; nothing it bought is
 * taken back (HANDOFF step 4): the house spent money it had at the time.
 */
async function revoke(ctx: MutationCtx, purchase: Doc<"jar_purchases">, revokedAt: number): Promise<void> {
  if (purchase.revoked_at !== undefined) return;
  if (purchase.credited_at !== undefined && purchase.home_id) {
    const house = await houseFor(ctx, purchase.home_id);
    // A deleted house has no jar left to debit; the row still records the refund.
    if (house) {
      await moveJar(ctx, house._id, {
        key: ledgerKey("refund", purchase.environment, purchase.transaction_id),
        kind: "refund",
        leaves: 0,
        sparkles: -purchase.sparkles,
      });
    }
  }
  await ctx.db.patch(purchase._id, { revoked_at: revokedAt });
}

/**
 * Credits one verified transaction to one house, once across the deployment.
 *
 * Called only by `jar:topUp`, after Apple's signature (or, for Xcode, the test
 * account) has been checked. It checks membership, the environment and the
 * product again rather than trusting its caller's arguments, because the
 * Sparkles are worked out here from the product, never passed in.
 */
export const credit = internalMutation({
  args: {
    homeId: v.id("homes"),
    transactionId: v.string(),
    originalTransactionId: v.string(),
    productId: v.string(),
    quantity: v.number(),
    environment: environmentValue,
    purchasedAt: v.number(),
    /** Apple's `revocationDate`, when the JWS already says it was refunded. */
    revokedAt: v.union(v.number(), v.null()),
    /** The UUID the app signed into the purchase, as Apple returned it. */
    appAccountToken: v.union(v.string(), v.null()),
  },
  returns: topUpResult,
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const invalid = { status: "invalid" as const, sparkles: 0, jar: null };
    if (!jarEnvironments().has(args.environment)) return invalid;
    if (args.environment === "Xcode" && !mayUseTestStore(user)) return invalid;

    // The buyer, and only the buyer. A receipt is a bearer token otherwise:
    // whoever holds the JWS could spend it into their own house. `invalid`
    // here is safe for the real buyer, because the phone that sent it keeps
    // the transaction unfinished and the buyer's own device can still send it.
    // The app sets the token on every purchase it makes; only Xcode's test
    // store may arrive without one (older Debug builds, the Transaction
    // Manager).
    if (args.appAccountToken === null) {
      if (args.environment !== "Xcode") {
        console.error(`jar:topUp: ${args.environment} ${args.transactionId} has no appAccountToken; refused`);
        return invalid;
      }
    } else if (args.appAccountToken.toLowerCase() !== (await accountToken(user._id))) {
      console.error(
        `jar:topUp: ${args.environment} ${args.transactionId} was bought by another account (token ${args.appAccountToken}), sent by ${user._id}; refused`,
      );
      return invalid;
    }

    const sparkles = sparklesFor(args.productId, args.quantity);
    if (sparkles === null) {
      // Apple took real money for it, so it is ours to credit once a build or
      // the table knows the product: thrown, and the phone keeps it.
      if (args.environment === "Production") {
        throw new Error(`jar:topUp: Production product ${args.productId} x${args.quantity} is not in the table`);
      }
      return invalid;
    }

    const existing = await purchaseFor(ctx, args.transactionId, args.environment);
    if (existing) {
      if (args.revokedAt !== null) await revoke(ctx, existing, args.revokedAt);
      if (existing.revoked_at !== undefined || args.revokedAt !== null) {
        return { status: "revoked" as const, sparkles: 0, jar: await jarOf(ctx, args.homeId) };
      }
      // The same house asking again (a lost answer, a relaunch before
      // `finish()`) hears what it was credited. Another house hears that the
      // receipt is spent, and nothing about where.
      const mine = existing.home_id === args.homeId;
      return { status: "already" as const, sparkles: mine ? existing.sparkles : 0, jar: await jarOf(ctx, args.homeId) };
    }

    const now = Date.now();
    if (args.revokedAt !== null) {
      // Refunded before it ever reached us: a tombstone, so an older copy of
      // the same JWS, signed before the refund, can never credit it later.
      await ctx.db.insert("jar_purchases", {
        transaction_id: args.transactionId,
        original_transaction_id: args.originalTransactionId,
        product_id: args.productId,
        sparkles,
        home_id: args.homeId,
        user_id: user._id,
        environment: args.environment,
        purchased_at: args.purchasedAt,
        revoked_at: args.revokedAt,
        created: now,
      });
      return { status: "revoked" as const, sparkles: 0, jar: await jarOf(ctx, args.homeId) };
    }

    const house = await ensureHouse(ctx, args.homeId);
    await moveJar(ctx, house._id, {
      key: ledgerKey("topup", args.environment, args.transactionId),
      kind: "topUp",
      leaves: 0,
      sparkles,
      userId: user._id,
    });
    await ctx.db.insert("jar_purchases", {
      transaction_id: args.transactionId,
      original_transaction_id: args.originalTransactionId,
      product_id: args.productId,
      sparkles,
      home_id: args.homeId,
      user_id: user._id,
      environment: args.environment,
      purchased_at: args.purchasedAt,
      credited_at: now,
      created: now,
    });
    const after = await houseFor(ctx, args.homeId);
    return {
      status: "credited" as const,
      sparkles,
      jar: after ? { leaves: after.leaves, sparkles: after.sparkles } : null,
    };
  },
});

/**
 * A refund or revocation from App Store Server Notifications, already
 * verified. Debits the jar the transaction credited, once; a second
 * notification for the same transaction finds `revoked_at` and does nothing.
 *
 * A transaction we never credited still gets a row, a tombstone, so the phone
 * can't send its pre-refund JWS afterwards and be credited for money Apple
 * gave back. A product we don't sell is ignored: it was never ours to credit.
 */
export const refund = internalMutation({
  args: {
    transactionId: v.string(),
    originalTransactionId: v.string(),
    productId: v.string(),
    quantity: v.number(),
    environment: environmentValue,
    purchasedAt: v.number(),
    revokedAt: v.number(),
  },
  returns: v.union(v.literal("debited"), v.literal("recorded"), v.literal("already"), v.literal("ignored")),
  handler: async (ctx, args) => {
    const existing = await purchaseFor(ctx, args.transactionId, args.environment);
    if (existing) {
      if (existing.revoked_at !== undefined) return "already" as const;
      await revoke(ctx, existing, args.revokedAt);
      return existing.credited_at !== undefined ? ("debited" as const) : ("recorded" as const);
    }
    const sparkles = sparklesFor(args.productId, args.quantity);
    if (sparkles === null) return "ignored" as const;
    await ctx.db.insert("jar_purchases", {
      transaction_id: args.transactionId,
      original_transaction_id: args.originalTransactionId,
      product_id: args.productId,
      sparkles,
      environment: args.environment,
      purchased_at: args.purchasedAt,
      revoked_at: args.revokedAt,
      created: Date.now(),
    });
    return "recorded" as const;
  },
});

/**
 * The credits from one environment, newest first: after a TestFlight or App
 * Review round, what Sandbox put into which jars.
 *
 *   npx convex run jarStore:credited '{"environment":"Sandbox"}'
 *
 * Bounded to 500 a call; pass `before` (a `credited_at`) to page further back.
 */
export const credited = internalQuery({
  args: {
    environment: environmentValue,
    before: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  returns: v.array(
    v.object({
      transactionId: v.string(),
      productId: v.string(),
      sparkles: v.number(),
      homeId: v.union(v.id("homes"), v.null()),
      userId: v.union(v.id("users"), v.null()),
      creditedAt: v.number(),
      revokedAt: v.union(v.number(), v.null()),
    }),
  ),
  handler: async (ctx, args) => {
    const limit = Math.min(Math.max(Math.floor(Number.isFinite(args.limit) ? args.limit! : 100), 1), 500);
    const before = Number.isFinite(args.before) ? args.before! : Number.MAX_SAFE_INTEGER;
    const rows = await ctx.db
      .query("jar_purchases")
      .withIndex("by_environment_credited", (q) =>
        q.eq("environment", args.environment).gte("credited_at", 0).lt("credited_at", before),
      )
      .order("desc")
      .take(limit);
    return rows.map((row) => ({
      transactionId: row.transaction_id,
      productId: row.product_id,
      sparkles: row.sparkles,
      homeId: row.home_id ?? null,
      userId: row.user_id ?? null,
      creditedAt: row.credited_at!,
      revokedAt: row.revoked_at ?? null,
    }));
  },
});
