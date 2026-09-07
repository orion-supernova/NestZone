import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { cascadeDeletePoll } from "./lib/relations";
import { internal } from "./_generated/api";
import { Doc } from "./_generated/dataModel";
import { MutationCtx, QueryCtx } from "./_generated/server";

const pollType = v.union(v.literal("movie"), v.literal("recipe"), v.literal("generic"));
const pollStatus = v.union(v.literal("draft"), v.literal("active"), v.literal("closed"));

/**
 * The PocketBase rule: "polls update/delete: owner-only and home member".
 *
 * `owner_id` is required in the schema — the legacy PocketBase polls that had
 * none were purged 2026-09-03 — so this is an unconditional owner check.
 */
async function requirePollOwner(ctx: QueryCtx | MutationCtx, poll: Doc<"polls">) {
  const user = await requireUser(ctx);
  await requireDocHome(ctx, poll, "Poll");
  if (poll.owner_id !== user._id) {
    throw new Error("Only the poll owner can modify this poll");
  }
  return user;
}

export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("polls")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
  },
});

/** A poll plus its items and the current user's votes — one reactive read. */
export const detail = query({
  args: { pollId: v.id("polls") },
  handler: async (ctx, { pollId }) => {
    const user = await requireUser(ctx);
    const poll = await ctx.db.get(pollId);
    if (!poll) throw new Error("Poll not found");
    await requireDocHome(ctx, poll, "Poll");

    const items = await ctx.db
      .query("poll_items")
      .withIndex("by_poll", (q) => q.eq("poll_id", pollId))
      .collect();
    const votes = await ctx.db
      .query("poll_votes")
      .withIndex("by_poll", (q) => q.eq("poll_id", pollId))
      .collect();

    return {
      poll,
      items: items.sort((a, b) => (a.order ?? 0) - (b.order ?? 0)),
      votes,
      myVotes: votes.filter((vote) => vote.user_id === user._id),
    };
  },
});

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    title: v.string(),
    type: pollType,
    genre: v.optional(v.string()),
    items: v.optional(
      v.array(
        v.object({
          external_id: v.string(),
          label: v.optional(v.string()),
          thumbnail_url: v.optional(v.string()),
          payload: v.optional(v.any()),
          order: v.optional(v.number()),
        }),
      ),
    ),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const now = Date.now();
    const pollId = await ctx.db.insert("polls", {
      home_id: args.homeId,
      owner_id: user._id,
      title: args.title,
      type: args.type,
      status: "active",
      genre: args.genre,
      created: now,
      updated: now,
    });
    // The whole ballot in one round. Awaiting a candidate at a time spends the
    // mutation's one second of execution on round trips, and a ballot is
    // exactly the thing somebody puts twenty options on.
    await Promise.all(
      (args.items ?? []).map((it, index) =>
        ctx.db.insert("poll_items", {
          poll_id: pollId,
          external_id: it.external_id,
          label: it.label,
          thumbnail_url: it.thumbnail_url,
          payload: it.payload,
          order: it.order ?? index,
          created: now,
          updated: now,
        }),
      ),
    );

    // Tell the rest of the household. Scheduled rather than awaited: a mutation
    // must not block on APNs, and a failed push must never roll back the poll.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: args.homeId,
      actor: user._id,
      title: user.name ? `${user.name} started a vote` : "New vote",
      body: args.title,
      category: "polls",
    });

    return await ctx.db.get(pollId);
  },
});

/** Cast / update the current user's vote on a target item. */
export const vote = mutation({
  args: {
    pollId: v.id("polls"),
    target_external_id: v.string(),
    vote: v.boolean(),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const poll = await ctx.db.get(args.pollId);
    if (!poll) throw new Error("Poll not found");
    await requireDocHome(ctx, poll, "Poll");

    const existing = await ctx.db
      .query("poll_votes")
      .withIndex("by_poll_user_target", (q) =>
        q
          .eq("poll_id", args.pollId)
          .eq("user_id", user._id)
          .eq("target_external_id", args.target_external_id),
      )
      .first();

    const now = Date.now();
    if (existing) {
      await ctx.db.patch(existing._id, { vote: args.vote, updated: now });
      return existing._id;
    }
    return await ctx.db.insert("poll_votes", {
      poll_id: args.pollId,
      user_id: user._id,
      target_external_id: args.target_external_id,
      vote: args.vote,
      created: now,
      updated: now,
    });
  },
});

/**
 * Take back one vote.
 *
 * The deck's single-step undo. A swipe is the whole interaction here and it is
 * one flick away from the wrong answer, so a card has to be recoverable —
 * without a retraction the vote stands, `unvotedItems` keeps excluding it, and
 * the card never comes back.
 */
export const unvote = mutation({
  args: {
    pollId: v.id("polls"),
    target_external_id: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const poll = await ctx.db.get(args.pollId);
    if (!poll) throw new Error("Poll not found");
    await requireDocHome(ctx, poll, "Poll");

    const existing = await ctx.db
      .query("poll_votes")
      .withIndex("by_poll_user_target", (q) =>
        q
          .eq("poll_id", args.pollId)
          .eq("user_id", user._id)
          .eq("target_external_id", args.target_external_id),
      )
      .first();

    // Undoing a swipe the server never recorded is not a failure: the vote is
    // gone either way, which is all the caller asked for. The optimistic client
    // can outrun its own write, and that must not surface as an error.
    if (existing) await ctx.db.delete(existing._id);
  },
});

/** Add a single item to an existing poll. */
export const addItem = mutation({
  args: {
    pollId: v.id("polls"),
    external_id: v.string(),
    label: v.optional(v.string()),
    thumbnail_url: v.optional(v.string()),
    order: v.optional(v.number()),
  },
  handler: async (ctx, { pollId, ...rest }) => {
    const poll = await ctx.db.get(pollId);
    if (!poll) throw new Error("Poll not found");
    await requireDocHome(ctx, poll, "Poll");
    // PocketBase rule: poll_items may only be added while the poll is active.
    if (poll.status && poll.status !== "active") {
      throw new Error("Cannot add items to a poll that is not active");
    }
    const now = Date.now();
    return await ctx.db.insert("poll_items", { poll_id: pollId, ...rest, created: now, updated: now });
  },
});

/** Delete a poll and all of its items and votes. */
export const remove = mutation({
  args: { pollId: v.id("polls") },
  handler: async (ctx, { pollId }) => {
    const poll = await ctx.db.get(pollId);
    if (!poll) return { ok: true };
    await requirePollOwner(ctx, poll);
    await cascadeDeletePoll(ctx, pollId);
    return { ok: true };
  },
});

export const setStatus = mutation({
  args: { pollId: v.id("polls"), status: pollStatus },
  handler: async (ctx, { pollId, status }) => {
    const poll = await ctx.db.get(pollId);
    if (!poll) throw new Error("Poll not found");
    await requirePollOwner(ctx, poll);
    await ctx.db.patch(pollId, { status, updated: Date.now() });
    return await ctx.db.get(pollId);
  },
});
