import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";

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
    return await ctx.db.insert("shopping_items", {
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
