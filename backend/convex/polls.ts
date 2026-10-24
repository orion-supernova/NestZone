import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { cascadeDeletePoll } from "./lib/relations";
import { noteGrowth } from "./lib/companion";
import { companionVoteFor } from "./lib/companionVote";
import { internal } from "./_generated/api";
import { Doc } from "./_generated/dataModel";
import { MutationCtx, QueryCtx } from "./_generated/server";

const pollType = v.union(v.literal("movie"), v.literal("recipe"), v.literal("generic"));
const pollStatus = v.union(v.literal("draft"), v.literal("active"), v.literal("closed"));

/**
 * Nestie's vote for the next one is a `generic` poll the server opened
 * (`companion_votes`): its options, its end and its deletion are the
 * server's, never a member's by hand. Ballots go through `vote` as on any
 * poll.
 */
async function refuseCompanionVote(ctx: MutationCtx, poll: Doc<"polls">) {
  if (await companionVoteFor(ctx, poll)) {
    throw new Error("The vote for the next one runs itself");
  }
}

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

    // Nestie's vote takes ballots only while it is open, and only on its own
    // options; once every member has answered every one, it closes itself
    // (`companion:voteChanged`). A ballot on it grows nothing.
    const companionVote = await companionVoteFor(ctx, poll);
    if (companionVote) {
      if (companionVote.status !== "open") throw new Error("That vote is over");
      if (!companionVote.options.includes(args.target_external_id)) {
        throw new Error("That isn't one of the options");
      }
    }

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
    // A movie round the house agrees on grows Nestie (convex/companion.ts).
    // Only a vote that can move the answer is worth a reconcile: a new yes,
    // or a yes turned to no. Re-sending the same vote, or a first no, can't.
    const moves = existing ? existing.vote !== args.vote : args.vote;
    // Any new answer can be the last one Nestie's vote was waiting for, a
    // first no included; the same answer sent again can't.
    if (companionVote && (!existing || existing.vote !== args.vote)) {
      await ctx.scheduler.runAfter(0, internal.companion.voteChanged, {
        pollId: args.pollId,
        userId: user._id,
      });
    }
    if (poll.type === "movie" && moves) {
      await noteGrowth(ctx, poll.home_id, { kind: "poll", id: args.pollId });
    }
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

    // A ballot on Nestie's vote stands once the vote is over: what it chose
    // was chosen with it. Not an error, for the same reason as below.
    const companionVote = await companionVoteFor(ctx, poll);
    if (companionVote && companionVote.status !== "open") return;

    // Undoing a swipe the server never recorded is not a failure: the vote is
    // gone either way, which is all the caller asked for. The optimistic client
    // can outrun its own write, and that must not surface as an error.
    if (existing) {
      await ctx.db.delete(existing._id);
      // Taking back a yes can undo the house agreeing on a film (convex/companion.ts).
      if (existing.vote && poll.type === "movie") {
        await noteGrowth(ctx, poll.home_id, { kind: "poll", id: args.pollId });
      }
    }
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
    await refuseCompanionVote(ctx, poll);
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
    await refuseCompanionVote(ctx, poll);
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
    // Closing Nestie's vote early is `companion:decide`, which counts it.
    await refuseCompanionVote(ctx, poll);
    await ctx.db.patch(pollId, { status, updated: Date.now() });
    return await ctx.db.get(pollId);
  },
});
