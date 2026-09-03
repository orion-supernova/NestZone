import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireHomeMember, requireDocHome } from "./lib/auth";

const listType = v.union(v.literal("wishlist"), v.literal("watched"), v.literal("custom"));

export const listsByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("movie_lists")
      .filter((q) => q.eq(q.field("home_id"), homeId))
      .collect();
  },
});

export const moviesInList = query({
  args: { listId: v.id("movie_lists") },
  handler: async (ctx, { listId }) => {
    const list = await ctx.db.get(listId);
    if (!list) throw new Error("List not found");
    await requireDocHome(ctx, list, "List");
    return await ctx.db
      .query("movies")
      .filter((q) => q.eq(q.field("list_id"), listId))
      .collect();
  },
});

export const createList = mutation({
  args: {
    homeId: v.id("homes"),
    name: v.string(),
    description: v.optional(v.string()),
    type: v.optional(listType),
    is_preset: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    await requireHomeMember(ctx, args.homeId);
    const now = Date.now();
    const id = await ctx.db.insert("movie_lists", {
      home_id: args.homeId,
      name: args.name,
      description: args.description,
      type: args.type ?? "custom",
      is_preset: args.is_preset ?? false,
      created: now,
      updated: now,
    });
    return await ctx.db.get(id);
  },
});

export const addMovie = mutation({
  args: {
    homeId: v.id("homes"),
    listId: v.id("movie_lists"),
    imdb_id: v.optional(v.string()),
    title: v.string(),
    year: v.optional(v.number()),
    poster: v.optional(v.string()),
    genres: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    await requireHomeMember(ctx, args.homeId);
    // The list must belong to the same home, or a member of home A could file
    // movies into home B's list.
    const list = await ctx.db.get(args.listId);
    if (!list) throw new Error("List not found");
    if (list.home_id !== args.homeId) throw new Error("List belongs to another home");
    const now = Date.now();
    return await ctx.db.insert("movies", {
      home_id: args.homeId,
      list_id: args.listId,
      imdb_id: args.imdb_id,
      title: args.title,
      year: args.year,
      poster: args.poster,
      genres: args.genres,
      created: now,
      updated: now,
    });
  },
});

/** All movies across a home's lists. */
export const byHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("movies")
      .filter((q) => q.eq(q.field("home_id"), homeId))
      .collect();
  },
});

export const updateList = mutation({
  args: { id: v.id("movie_lists"), name: v.optional(v.string()), description: v.optional(v.string()) },
  handler: async (ctx, { id, ...fields }) => {
    const list = await ctx.db.get(id);
    if (!list) throw new Error("List not found");
    await requireDocHome(ctx, list, "List");
    await ctx.db.patch(id, { ...fields, updated: Date.now() });
    return await ctx.db.get(id);
  },
});

/** Delete a movie list and all movies in it. */
export const removeList = mutation({
  args: { id: v.id("movie_lists") },
  handler: async (ctx, { id }) => {
    const list = await ctx.db.get(id);
    if (!list) return { ok: true };
    await requireDocHome(ctx, list, "List");
    for (const m of await ctx.db.query("movies").filter((q) => q.eq(q.field("list_id"), id)).collect()) {
      await ctx.db.delete(m._id);
    }
    await ctx.db.delete(id);
    return { ok: true };
  },
});

export const removeMovie = mutation({
  args: { id: v.id("movies") },
  handler: async (ctx, { id }) => {
    const movie = await ctx.db.get(id);
    if (!movie) return { ok: true };
    await requireDocHome(ctx, movie, "Movie");
    await ctx.db.delete(id);
    return { ok: true };
  },
});
