import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";

// Shown as the notification title; the body carries what actually changed.
const NOTIFY_TITLE = "Added to the list";

const category = v.union(
  v.literal("groceries"),
  v.literal("household"),
  v.literal("cleaning"),
  v.literal("other"),
);

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("shopping_items")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
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

    const existing = await ctx.db
      .query("shopping_items")
      .withIndex("by_home", (q) => q.eq("home_id", args.homeId))
      .collect();
    const outstanding = new Set(
      existing
        .filter((it) => !it.is_purchased)
        .map((it) => (it.name ?? "").trim().toLowerCase()),
    );

    const now = Date.now();
    const wanted = args.names
      .map((n) => n.trim())
      .filter((n) => n.length > 0)
      .filter((n) => !outstanding.has(n.toLowerCase()));

    for (const name of wanted) {
      await ctx.db.insert("shopping_items", {
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
      });
    }

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
