import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { internal } from "./_generated/api";

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
    // Set by the paths that adopt a bundled Explore recipe into the home. Three
    // of them exist — "add to my recipes", "plan it for tonight" and "send its
    // ingredients to the list" — and every one of them used to insert a fresh
    // copy, so a household that cooked the same dish twice ended up with the
    // same dish on the shelf three times. Hand-written recipes leave this off:
    // two of your own called "Soup" are two recipes, not a mistake.
    dedupeByTitle: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const { homeId, dedupeByTitle, ...rest } = args;

    if (dedupeByTitle) {
      const wanted = rest.title.trim().toLowerCase();
      const existing = await ctx.db
        .query("recipes")
        .withIndex("by_home", (q) => q.eq("home_id", homeId))
        .collect();
      const match = existing.find(
        (r) => (r.title ?? "").trim().toLowerCase() === wanted,
      );
      // The caller wanted a recipe in this home with this title, and there is
      // one. Handing it back is both the honest answer and the id the caller
      // needs to point a meal plan or a shopping batch at.
      if (match) return match;
    }

    // Only a recipe that is genuinely new to the shelf. The dedupe branch
    // above returns early, so adopting the same bundled recipe a second time
    // stays silent.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId,
      actor: user._id,
      title: user.name ? `${user.name} added a recipe` : "New recipe",
      body: rest.title,
      category: "recipes",
    });

    const now = Date.now();
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

/// Deletes a recipe and every duplicate copy of it in one write.
///
/// Same reasoning as `shopping:removeMany`: one delete per id meant one
/// subscription push per delete, and a shelf that had collapsed three copies
/// into one row watched two of them reappear before vanishing again.
export const removeMany = mutation({
  args: { ids: v.array(v.id("recipes")) },
  handler: async (ctx, { ids }) => {
    // Each phase in one round rather than one recipe at a time: a mutation gets
    // one second, and awaiting a get and a delete per id spends it on round
    // trips. The transaction is all-or-nothing either way.
    const found = await Promise.all(ids.map((id) => ctx.db.get(id)));
    const present = found.filter((r): r is NonNullable<typeof r> => r !== null);
    await Promise.all(present.map((recipe) => requireDocHome(ctx, recipe, "Recipe")));
    await Promise.all(present.map((recipe) => ctx.db.delete(recipe._id)));
    return { removed: present.length };
  },
});
