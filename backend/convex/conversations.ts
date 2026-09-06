import { query, mutation } from "./_generated/server";
import { QueryCtx, MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { requireUser, requireHomeMember } from "./lib/auth";
import { requireMembers } from "./lib/relations";

/** Conversations in a home that the current user participates in. */
export const listByHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    const user = await requireUser(ctx);
    const convos = await ctx.db
      .query("conversations")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
    return convos.filter((c) => (c.participants ?? []).some((p) => p === user._id));
  },
});

/** The current user, or a throw, plus the conversation they are a participant of. */
async function assertParticipant(
  ctx: QueryCtx | MutationCtx,
  conversationId: Id<"conversations">,
) {
  const user = await requireUser(ctx);
  const convo = await ctx.db.get(conversationId);
  if (!convo) throw new Error("Conversation not found");
  if (!(convo.participants ?? []).some((p) => p === user._id)) {
    throw new Error("Not a participant of this conversation");
  }
  return { user, convo };
}

/**
 * Rename a thread. An empty title clears it, which puts the conversation back on
 * its default name rather than leaving it called "".
 */
export const rename = mutation({
  args: {
    conversationId: v.id("conversations"),
    title: v.optional(v.string()),
  },
  handler: async (ctx, { conversationId, title }) => {
    await assertParticipant(ctx, conversationId);
    const trimmed = title?.trim();
    await ctx.db.patch(conversationId, {
      title: trimmed ? trimmed : undefined,
      updated: Date.now(),
    });
    return await ctx.db.get(conversationId);
  },
});

/** Same people, in any order. */
function sameParticipants(a: Id<"users">[], b: Id<"users">[]): boolean {
  if (a.length !== b.length) return false;
  const set = new Set(a);
  return b.every((id) => set.has(id));
}

export const create = mutation({
  args: {
    homeId: v.id("homes"),
    participants: v.array(v.id("users")),
    title: v.optional(v.string()),
    isGroupChat: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    const participants = Array.from(new Set([user._id, ...args.participants]));
    // Every participant must exist and be a member of this home. Without this a
    // caller could name any user id and hand them read access to the whole
    // conversation via messages:assertParticipant.
    await requireMembers(ctx, home, participants, "Conversation participants");
    if (participants.length < 2) {
      throw new Error("A conversation needs somebody else in it");
    }
    const isGroupChat = args.isGroupChat ?? participants.length > 2;

    // Messaging the same person twice reopens the thread you already have with
    // them instead of stacking a second empty one beside it — two 1:1 threads
    // with identical participants are indistinguishable in the list, and half
    // the history ends up in each. Groups are exempt: a household may well want
    // several named chats among the same people.
    if (!isGroupChat) {
      const existing = await ctx.db
        .query("conversations")
        .withIndex("by_home", (q) => q.eq("home_id", args.homeId))
        .collect();
      const already = existing.find(
        (c) => !c.is_group_chat && sameParticipants(c.participants ?? [], participants),
      );
      if (already) return already;
    }

    const now = Date.now();
    const id = await ctx.db.insert("conversations", {
      home_id: args.homeId,
      participants,
      title: args.title,
      is_group_chat: isGroupChat,
      created: now,
      updated: now,
    });
    return await ctx.db.get(id);
  },
});
