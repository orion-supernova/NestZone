import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";

const difficulty = v.union(v.literal("easy"), v.literal("medium"), v.literal("hard"));

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("recipes")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
  },
});

export const get = query({
  args: { id: v.id("recipes") },
  handler: async (ctx, { id }) => {
    const recipe = await ctx.db.get(id);
    if (!recipe) throw new Error("Recipe not found");
    await requireDocHome(ctx, recipe, "Recipe");
    return recipe;
  },
});

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    title: v.string(),
    description: v.optional(v.string()),
    ingredients: v.optional(v.any()),
    steps: v.optional(v.any()),
    prep_time: v.optional(v.number()),
    cook_time: v.optional(v.number()),
    servings: v.optional(v.number()),
    difficulty: v.optional(difficulty),
    image: v.optional(v.id("_storage")),
    tags: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const now = Date.now();
    const { homeId, ...rest } = args;
    const id = await ctx.db.insert("recipes", {
      ...rest,
      home_id: homeId,
      created_by: user._id,
      created: now,
      updated: now,
    });
    return await ctx.db.get(id);
  },
});

export const remove = mutation({
  args: { id: v.id("recipes") },
  handler: async (ctx, { id }) => {
    const recipe = await ctx.db.get(id);
    if (!recipe) return { ok: true };
    await requireDocHome(ctx, recipe, "Recipe");
    await ctx.db.delete(id);
    return { ok: true };
  },
});
