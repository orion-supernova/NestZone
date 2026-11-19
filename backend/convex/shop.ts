// Buying from the house jar.
//
// The same checkout as the phone's purchase card (`CompanionHouse.checkout`):
// a thing has one price in one currency; a house short of Leaves makes up the
// rest with its own Sparkles, one for one; Sparkles are never made up with
// Leaves. Debiting the jar, writing the ledger row and putting the thing in
// the house are one transaction, so a purchase is either all there or not at
// all.

import { mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember } from "./lib/auth";
import {
  boughtItem,
  checkout,
  ensureHouse,
  itemPrice,
  knownItem,
  moveJar,
  PACKS,
  shopContext,
  standingOf,
  standingPrice,
} from "./lib/companion";

const itemArg = v.object({
  kind: v.union(v.literal("decor"), v.literal("species"), v.literal("pack")),
  id: v.string(),
});

const priceValue = v.object({
  currency: v.union(v.literal("leaves"), v.literal("sparkles")),
  amount: v.number(),
});

const coinsValue = v.object({ leaves: v.number(), sparkles: v.number() });

/**
 * Buys one thing for the house.
 *
 * - `requestId` is the phone's id for this tap, made when the card's buy
 *   button is pressed. A retry with the same id and the same thing returns the
 *   first answer and never debits twice; the same id for a different thing is
 *   refused. A second phone buying the same thing at the same moment finds it
 *   already in the house and pays nothing.
 * - `expectedPrice` is the price the card showed, and is required. If the
 *   catalog says otherwise, nothing is bought and the real price comes back:
 *   the house only ever pays what it was asked.
 * - The house's day (for holidays and seasons) is the house's own offset, set
 *   by `companion:setPlace`, never the buying phone's.
 * - A species from a pack buys its pack (`ShopItem.bought`).
 *
 * The answer is a status, not an error, for every outcome the card has a
 * screen for: bought, already the house's, short (with how many Sparkles more
 * would do it), not to be had today, or a changed price.
 */
export const buy = mutation({
  args: {
    homeId: v.id("homes"),
    item: itemArg,
    requestId: v.string(),
    expectedPrice: priceValue,
  },
  returns: v.union(
    v.object({
      status: v.literal("bought"),
      item: itemArg,
      paid: coinsValue,
      /** The Leaves the Sparkles made up, when they did. */
      madeUp: v.union(v.number(), v.null()),
      jar: coinsValue,
      /** True when this answers a retry of a purchase already made. */
      replay: v.boolean(),
    }),
    v.object({ status: v.literal("owned"), item: itemArg }),
    v.object({ status: v.literal("short"), item: itemArg, sparkles: v.number(), price: priceValue }),
    v.object({ status: v.literal("unavailable"), item: itemArg }),
    v.object({ status: v.literal("priceChanged"), item: itemArg, price: priceValue }),
  ),
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const requestId = args.requestId.trim();
    if (requestId.length < 8 || requestId.length > 64) throw new Error("A bad request id");

    if (!knownItem(args.item)) return { status: "unavailable" as const, item: args.item };
    const item = boughtItem(args.item);
    const itemKey = `${item.kind}:${item.id}`;

    const key = `buy:${requestId}`;
    const house = await ensureHouse(ctx, args.homeId);

    // A retry: the same answer as the first time, for the same thing only.
    const done = await ctx.db
      .query("jar_ledger")
      .withIndex("by_home_key", (q) => q.eq("home_id", args.homeId).eq("key", key))
      .first();
    if (done) {
      if (done.kind !== "buy" || done.item !== itemKey) return { status: "unavailable" as const, item };
      return {
        status: "bought" as const,
        item,
        paid: { leaves: -done.leaves, sparkles: -done.sparkles },
        madeUp: done.made_up ?? null,
        jar: { leaves: house.leaves, sparkles: house.sparkles },
        replay: true,
      };
    }

    const shop = shopContext(house, Date.now());
    const standing = standingOf(item, shop);
    if (standing.type === "have" || standing.type === "free") return { status: "owned" as const, item };
    const onSale = standingPrice(standing);
    const price = itemPrice(item);
    if (!onSale || !price) return { status: "unavailable" as const, item };

    if (args.expectedPrice.currency !== price.currency || args.expectedPrice.amount !== price.amount) {
      return { status: "priceChanged" as const, item, price };
    }

    const result = checkout({ leaves: house.leaves, sparkles: house.sparkles }, price);
    if (result.type === "short") return { status: "short" as const, item, sparkles: result.sparkles, price };

    const coins = result.coins;
    await moveJar(ctx, house._id, {
      key,
      kind: "buy",
      leaves: -coins.leaves,
      sparkles: -coins.sparkles,
      userId: user._id,
      item: itemKey,
      madeUp: result.type === "makeUp" ? result.short : undefined,
    });

    // Into the house (`CompanionHouse.receive`).
    const now = Date.now();
    if (item.kind === "decor") {
      await ctx.db.patch(house._id, { owned_decor: [...new Set([...house.owned_decor, item.id])], updated: now });
    } else {
      const adding = item.kind === "pack" ? (PACKS.get(item.id)?.species ?? []) : [item.id];
      await ctx.db.patch(house._id, {
        owned_species: [...new Set([...house.owned_species, ...adding])],
        updated: now,
      });
    }

    return {
      status: "bought" as const,
      item,
      paid: coins,
      madeUp: result.type === "makeUp" ? result.short : null,
      jar: { leaves: house.leaves - coins.leaves, sparkles: house.sparkles - coins.sparkles },
      replay: false,
    };
  },
});
