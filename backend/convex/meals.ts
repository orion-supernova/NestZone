import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { requireRef, requireSameHome } from "./lib/relations";
import { internal } from "./_generated/api";

// What is for dinner, by calendar day.
//
// Three shapes, one row: cook a recipe, order in, or go out. A cook plan is a
// pointer, and the recipe is read through on the way out so the Home tab can
// show and open it without subscribing to the whole recipe collection. A cook
// plan whose recipe has since been deleted is dropped rather than returned
// half-empty — there would be nothing to show or open.

const mealKind = v.union(v.literal("cook"), v.literal("order"), v.literal("out"));

export const forHome = query({
  args: { homeId: v.id("homes"), from: v.string() },
  handler: async (ctx, { homeId, from }) => {
    await requireHomeMember(ctx, homeId);
    const plans = await ctx.db
      .query("meal_plans")
      .withIndex("by_home_date", (q) => q.eq("home_id", homeId).gte("date", from))
      .collect();

    const resolved = await Promise.all(
      plans.map(async (plan) => {
        // The event this meal belongs to, read through for the same reason the
        // recipe is: the Home tab shows tonight without subscribing to the
        // calendar, and can open the event that owns the shopping and the
        // budget straight from the card. An event deleted since simply drops
        // off rather than leaving a dangling id.
        const event = plan.event_id ? await ctx.db.get(plan.event_id) : null;
        const withEvent = {
          ...plan,
          event: event
            ? { _id: event._id, title: event.title ?? "", kind: event.kind ?? "general" }
            : null,
        };
        if (plan.kind !== "cook") return { ...withEvent, recipe: null };
        // A cook plan with a name and no recipe stands on its own.
        if (!plan.recipe_id) return { ...withEvent, recipe: null };
        const recipe = await ctx.db.get(plan.recipe_id);
        return recipe ? { ...withEvent, recipe } : null;
      }),
    );
    return resolved
      .filter((p): p is NonNullable<typeof p> => p !== null)
      .sort((a, b) => a.date.localeCompare(b.date));
  },
});

export const set = mutation({
  args: {
    homeId: v.id("homes"),
    date: v.string(),
    kind: mealKind,
    recipeId: v.optional(v.id("recipes")),
    title: v.optional(v.string()),
    cuisine: v.optional(v.string()),
    place: v.optional(v.string()),
    /** The calendar event this meal belongs to, if it is part of one. */
    eventId: v.optional(v.id("events")),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);

    // A meal may only point at an event this household can see — otherwise the
    // Home tab would read a title out of another home.
    if (args.eventId) {
      const event = await requireRef(ctx, args.eventId, "Event");
      requireSameHome(event, args.homeId, "Event");
    }

    if (args.kind === "cook") {
      // Either a recipe or a name — "leftovers" is a perfectly good answer to
      // what is for dinner, and does not deserve a recipe row.
      if (!args.recipeId && !args.title?.trim()) {
        throw new Error("Cooking needs a recipe or a name");
      }
      if (args.recipeId) {
        const recipe = await ctx.db.get(args.recipeId);
        if (!recipe) throw new Error("Recipe not found");
        // A plan may only point at a recipe this home can actually see.
        await requireDocHome(ctx, recipe, "Recipe");
      }
    } else if (!args.cuisine && !args.place) {
      throw new Error("Ordering in or going out needs a cuisine or a place");
    }

    const fields = {
      kind: args.kind,
      // Cleared rather than left behind: switching from cooking to a takeaway
      // must not leave last night's recipe hanging off the row.
      recipe_id: args.kind === "cook" ? args.recipeId : undefined,
      // A typed name belongs to a recipe-less cook plan only; picking a recipe
      // later must not leave the old text behind it.
      title: args.kind === "cook" && !args.recipeId ? args.title?.trim() : undefined,
      cuisine: args.kind === "cook" ? undefined : args.cuisine,
      place: args.kind === "cook" ? undefined : args.place,
      // Absent means "leave the link alone", so re-deciding the same evening's
      // dinner does not silently detach it from the party it belongs to.
      ...(args.eventId ? { event_id: args.eventId } : {}),
      planned_by: user._id,
    };

    // What the notification says the household is eating. A cook plan names
    // the recipe it points at; the other two name where the food is coming
    // from.
    const recipeTitle = args.recipeId
      ? (await ctx.db.get(args.recipeId))?.title
      : undefined;
    const what =
      args.kind === "cook"
        ? (recipeTitle ?? args.title?.trim() ?? "dinner")
        : (args.place ?? args.cuisine ?? "dinner");

    // One dinner per day: deciding again replaces rather than stacks up.
    const existing = await ctx.db
      .query("meal_plans")
      .withIndex("by_home_date", (q) =>
        q.eq("home_id", args.homeId).eq("date", args.date),
      )
      .unique();

    // Tell the rest of the household. Scheduled rather than awaited: a
    // mutation must not block on APNs, and a failed push must never roll back
    // the plan. Collapsed on the day, because re-deciding tonight's dinner
    // should replace the earlier answer rather than stack a second one beside
    // it.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: user.name ? `${user.name} planned dinner` : "Dinner is planned",
      body:
        args.kind === "cook"
          ? `Cooking ${what}`
          : args.kind === "order"
            ? `Ordering ${what}`
            : `Going out: ${what}`,
      category: "meals",
      collapseId: `meal-${args.homeId}-${args.date}`,
    });

    const now = Date.now();
    if (existing) {
      await ctx.db.patch(existing._id, { ...fields, updated: now });
      return existing._id;
    }
    return await ctx.db.insert("meal_plans", {
      home_id: args.homeId,
      date: args.date,
      ...fields,
      created: now,
      updated: now,
    });
  },
});

export const clear = mutation({
  args: { homeId: v.id("homes"), date: v.string() },
  handler: async (ctx, { homeId, date }) => {
    await requireHomeMember(ctx, homeId);
    const existing = await ctx.db
      .query("meal_plans")
      .withIndex("by_home_date", (q) => q.eq("home_id", homeId).eq("date", date))
      .unique();
    if (existing) await ctx.db.delete(existing._id);
    return { ok: true };
  },
});
