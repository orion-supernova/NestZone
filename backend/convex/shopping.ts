import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { outstandingItems, outstandingNames } from "./lib/pending";
import { noteGrowth } from "./lib/companion";

// Shown as the notification title; the body carries what actually changed.
const NOTIFY_TITLE = "Added to the list";

const category = v.union(
  v.literal("groceries"),
  v.literal("household"),
  v.literal("cleaning"),
  v.literal("other"),
);

/**
 * How many bought items the list carries back with it.
 *
 * A shopping list is the things you still need plus a short tail of what you
 * just got, and the screen shows exactly that: an outstanding section and a
 * "purchased" one under it. Bought rows are never deleted by ticking them —
 * they keep their flag and stay — so collecting the whole table meant the list
 * screen downloaded every item the household had ever bought, growing with its
 * history and shrinking for no reason but a manual "clear purchased".
 *
 * Five hundred is far past the end of anything anyone scrolls, so nothing
 * visible changes today; it just stops being unbounded tomorrow. And because
 * clearing works on what the screen is holding, the window is also exactly what
 * a person can act on — the list and the button agree.
 */
const DONE_WINDOW = 500;

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    const [outstanding, bought] = await Promise.all([
      outstandingItems(ctx, homeId),
      // `true` is never the missing value — nothing writes a bought item
      // without saying so — so unlike the outstanding half this is one bucket.
      // `.order("desc")` runs down the index's implicit `_creationTime`, newest
      // first, which is the end of the list a person is still interested in.
      ctx.db
        .query("shopping_items")
        .withIndex("by_home_purchased", (q) =>
          q.eq("home_id", homeId).eq("is_purchased", true),
        )
        .order("desc")
        .take(DONE_WINDOW),
    ]);
    return [...outstanding, ...bought];
  },
});

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    name: v.string(),
    description: v.optional(v.string()),
    quantity: v.optional(v.number()),
    category: v.optional(category),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const now = Date.now();
    const createdId = await ctx.db.insert("shopping_items", {
      home_id: args.homeId,
      name: args.name,
      description: args.description,
      quantity: args.quantity,
      category: args.category,
      is_purchased: false,
      created_by: user._id,
      updated_by: user._id,
      created: now,
      updated: now,
    });

    // Tell the rest of the household. Scheduled rather than awaited: a mutation
    // must not block on APNs, and a failed push must never roll back the write.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: user.name ? `${user.name} added` : NOTIFY_TITLE,
      body: args.name,
      category: "shopping",
    });

    return createdId;
  },
});

/// The most a single typed list may add. Far past anything a person types in
/// one go — "süt, yumurta, ekmek" is three — and low enough that one mutation
/// stays well inside its one-second budget. Add anything caps its preview at
/// the same number, so what a person is shown is what is sent; this only ever
/// refuses a caller that skipped that.
const MANY_LIMIT = 50;

/// A bound on the names read before any of them is checked, so the loop below
/// stays short whatever a caller sends. Generous, because duplicates and names
/// already on the list are dropped after it and only what is left counts
/// against `MANY_LIMIT`.
const MANY_INPUT_LIMIT = 500;

/// Several things typed at once — "süt, yumurta, ekmek" from Add anything — in
/// one round trip.
///
/// Beside `create` rather than instead of it: every build already in people's
/// hands calls `create`, and keeps doing so. Same per-item fields, same
/// membership check, but one write, one live push and one notification for the
/// batch, for the reasons `createFromRecipe` below gives.
///
/// Names already on the list and not yet bought are skipped, as they are for a
/// recipe, and so is a name typed twice in the same breath — "milk" said twice
/// is still one carton. Returns the ids actually inserted, so the caller can
/// say how many it added rather than how many it sent.
export const createMany = mutation({
  args: {
    homeId: v.id("homes"),
    names: v.array(v.string()),
    category: v.optional(category),
  },
  returns: v.array(v.id("shopping_items")),
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);

    if (args.names.length > MANY_INPUT_LIMIT) {
      throw new Error(`At most ${MANY_LIMIT} items at once`);
    }
    const cleaned = args.names.map((n) => n.trim()).filter((n) => n.length > 0);

    const outstanding = await outstandingNames(ctx, args.homeId);
    const seen = new Set<string>();
    const wanted: string[] = [];
    for (const name of cleaned) {
      const key = name.toLowerCase();
      if (outstanding.has(key) || seen.has(key)) continue;
      seen.add(key);
      wanted.push(name);
    }
    // Counted after the duplicates are gone: sixty names that are ten things
    // is ten things. Refused whole rather than truncated — dropping the tail
    // of somebody's list without a word is the one outcome they could not
    // notice.
    if (wanted.length > MANY_LIMIT) {
      throw new Error(`At most ${MANY_LIMIT} items at once`);
    }

    const now = Date.now();
    // One round of inserts, not one at a time — see `createFromRecipe`.
    const ids = await Promise.all(
      wanted.map((name) =>
        ctx.db.insert("shopping_items", {
          home_id: args.homeId,
          name,
          // What the list screen adds under when nobody picks an aisle.
          category: args.category ?? "groceries",
          is_purchased: false,
          created_by: user._id,
          updated_by: user._id,
          created: now,
          updated: now,
        }),
      ),
    );

    if (wanted.length > 0) {
      // One notification for the batch. The names themselves rather than a
      // count: "Milk, eggs, bread" is what the rest of the house wants to read,
      // and it needs no translating on a server that cannot know the language.
      const shown = wanted.slice(0, 3).join(", ");
      const more = wanted.length > 3 ? ` +${wanted.length - 3}` : "";
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: args.homeId,
        actor: user._id,
        title: user.name ? `${user.name} added` : NOTIFY_TITLE,
        body: `${shown}${more}`,
        category: "shopping",
      });
    }

    return ids;
  },
});

/// Everything a recipe needs, in one round trip.
///
/// One mutation rather than one per ingredient: a twelve-line recipe was
/// twelve writes, twelve subscription pushes and twelve notifications. Names
/// already on the list and not yet bought are skipped, so sending the same
/// recipe twice does not double it up.
export const createFromRecipe = mutation({
  args: {
    homeId: v.id("homes"),
    recipeId: v.id("recipes"),
    recipeTitle: v.string(),
    names: v.array(v.string()),
    category: v.optional(category),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);

    const outstanding = await outstandingNames(ctx, args.homeId);

    const now = Date.now();
    const wanted = args.names
      .map((n) => n.trim())
      .filter((n) => n.length > 0)
      .filter((n) => !outstanding.has(n.toLowerCase()));

    // Written in one round, not one ingredient at a time. A mutation gets one
    // second of execution and awaiting each insert spends it on round trips —
    // which is how the same loop in `events:stockUp` timed out on a real menu.
    // The transaction commits together either way.
    await Promise.all(
      wanted.map((name) =>
        ctx.db.insert("shopping_items", {
          home_id: args.homeId,
          name,
          category: args.category ?? "groceries",
          is_purchased: false,
          recipe_id: args.recipeId,
          recipe_title: args.recipeTitle,
          created_by: user._id,
          updated_by: user._id,
          created: now,
          updated: now,
        }),
      ),
    );

    if (wanted.length > 0) {
      // One notification for the batch, not one per ingredient.
      await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
        homeId: args.homeId,
        actor: user._id,
        title: user.name ? `${user.name} added` : NOTIFY_TITLE,
        body: `${wanted.length} ${wanted.length === 1 ? "item" : "items"} for ${args.recipeTitle}`,
        category: "shopping",
      });
    }

    return { added: wanted.length, skipped: args.names.length - wanted.length };
  },
});

export const setPurchased = mutation({
  args: { id: v.id("shopping_items"), is_purchased: v.boolean() },
  handler: async (ctx, { id, is_purchased }) => {
    const user = await requireUser(ctx);
    const item = await ctx.db.get(id);
    if (!item) throw new Error("Item not found");
    await requireDocHome(ctx, item, "Item");
    await ctx.db.patch(id, { is_purchased, updated_by: user._id, updated: Date.now() });
    // A trip to the shops grows Nestie (convex/companion.ts).
    await noteGrowth(ctx, item.home_id, { kind: "shopping", id });
    return await ctx.db.get(id);
  },
});

export const update = mutation({
  args: {
    id: v.id("shopping_items"),
    name: v.optional(v.string()),
    description: v.optional(v.string()),
    quantity: v.optional(v.number()),
    category: v.optional(category),
  },
  handler: async (ctx, { id, ...fields }) => {
    const user = await requireUser(ctx);
    const item = await ctx.db.get(id);
    if (!item) throw new Error("Item not found");
    await requireDocHome(ctx, item, "Item");
    await ctx.db.patch(id, { ...fields, updated_by: user._id, updated: Date.now() });
    return await ctx.db.get(id);
  },
});

export const remove = mutation({
  args: { id: v.id("shopping_items") },
  handler: async (ctx, { id }) => {
    const item = await ctx.db.get(id);
    if (!item) return { ok: true };
    await requireDocHome(ctx, item, "Item");
    await ctx.db.delete(id);
    return { ok: true };
  },
});

/// Clears a whole group — an aisle, a meal, everything already bought — in one
/// write.
///
/// One mutation rather than one `remove` per row. Fired individually, each
/// delete landed on its own and pushed its own `listByHome` update, so a client
/// that had optimistically dropped the whole group watched the survivors flicker
/// back in and then disappear one at a time. A single transaction means a single
/// push, and the group is gone in one frame.
export const removeMany = mutation({
  args: { ids: v.array(v.id("shopping_items")) },
  handler: async (ctx, { ids }) => {
    // Read, check, then delete — each phase in one round rather than one item
    // at a time, for the reason `createFromRecipe` above gives.
    const items = await Promise.all(ids.map((id) => ctx.db.get(id)));
    // Already gone — another member got there first, which is not an error.
    const present = items.filter((it): it is NonNullable<typeof it> => it !== null);
    await Promise.all(present.map((item) => requireDocHome(ctx, item, "Item")));
    await Promise.all(present.map((item) => ctx.db.delete(item._id)));
    return { removed: present.length };
  },
});
