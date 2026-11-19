import { query, mutation } from "./_generated/server";
import { QueryCtx, MutationCtx } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { requireUser, requireHomeMember } from "./lib/auth";
import { requireMembers } from "./lib/relations";
import { requirePro } from "./lib/pro";
import { blockedBy, blockedEitherWay, requireChatAllowed } from "./lib/moderation";
import { pinnedValidator, snippetOf } from "./lib/chat";

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
    const mine = convos.filter((c) => (c.participants ?? []).some((p) => p === user._id));

    // A preview quoting somebody the caller blocked, or a message they
    // reported, is left off for them alone: `last_message` is omitted, which
    // every build already reads as optional, and `last_message_at` stays so
    // the order does not move. Two indexed reads, both nearly always empty;
    // only then one newest-message read per thread.
    const [blocked, hiddenRows] = await Promise.all([
      blockedBy(ctx, user._id),
      ctx.db
        .query("hidden_content")
        .withIndex("by_user_kind_target", (q) => q.eq("user_id", user._id).eq("kind", "message"))
        .take(500),
    ]);
    if (blocked.size === 0 && hiddenRows.length === 0) return mine;
    const hidden = new Set(hiddenRows.map((h) => h.target_id));
    return await Promise.all(
      mine.map(async (raw) => {
        // A pin quoting somebody the caller blocked, or a message they
        // reported, is left off for them alone. The pin carries its sender,
        // so this costs no read.
        const pin = raw.pinned;
        const c =
          pin && ((pin.sender_id && blocked.has(pin.sender_id)) || hidden.has(pin.message_id))
            ? (({ pinned: _pin, ...rest }) => rest)(raw)
            : raw;
        if (c.last_message === undefined) return c;
        const newest = await ctx.db
          .query("messages")
          .withIndex("by_conversation", (q) => q.eq("conversation_id", c._id))
          .order("desc")
          .first();
        if (!newest || (!blocked.has(newest.sender_id) && !hidden.has(newest._id))) return c;
        const { last_message: _quoted, ...rest } = c;
        return rest;
      }),
    );
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
    const { user, convo } = await assertParticipant(ctx, conversationId);
    requireChatAllowed(user);
    // Messages is Plus (lib/pro.ts); renaming a thread is using it.
    await requirePro(ctx, convo.home_id, "messages");
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
    // Messages is Plus: starting a chat or a group refuses for a free house.
    // Reopening a 1:1 you already have refuses too; the only thing to do in
    // it is send, which refuses.
    await requirePro(ctx, home, "messages");
    const participants = Array.from(new Set([user._id, ...args.participants]));
    // Every participant must exist and be a member of this home. Without this a
    // caller could name any user id and hand them read access to the whole
    // conversation via messages:assertParticipant.
    await requireMembers(ctx, home, participants, "Conversation participants");
    if (participants.length < 2) {
      throw new Error("A conversation needs somebody else in it");
    }
    const isGroupChat = args.isGroupChat ?? participants.length > 2;
    requireChatAllowed(user);

    // A 1:1 between two people either of whom has blocked the other is
    // refused, reopening an old one included. Groups are not: in a group a
    // block only hides that person's messages from the one who blocked.
    if (!isGroupChat && participants.length === 2) {
      const other = participants.find((p) => p !== user._id)!;
      if (await blockedEitherWay(ctx, user._id, other)) {
        throw new ConvexError({ code: "BLOCKED" });
      }
    }

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

/**
 * Pins a message to the top of its conversation, replacing any pin it had.
 * One pin per conversation, stored as a snapshot (lib/chat.ts) so drawing it
 * needs no read; deleting the message clears it in the same write.
 *
 * Any participant may pin. Messages is Plus, so this refuses for a free house
 * (`PRO_REQUIRED`); unpinning never does. A suspended person may not pin
 * (`CHAT_SUSPENDED`): it puts words at the top of everybody's thread. A 1:1
 * either side has blocked is closed (`BLOCKED`).
 */
export const pin = mutation({
  args: { conversationId: v.id("conversations"), messageId: v.id("messages") },
  returns: pinnedValidator,
  handler: async (ctx, { conversationId, messageId }) => {
    const { user, convo } = await assertParticipant(ctx, conversationId);
    requireChatAllowed(user);
    if (!convo.is_group_chat) {
      const other = (convo.participants ?? []).find((p) => p !== user._id);
      if (other && (await blockedEitherWay(ctx, user._id, other))) {
        throw new ConvexError({ code: "BLOCKED" });
      }
    }
    await requirePro(ctx, convo.home_id, "messages");
    const message = await ctx.db.get(messageId);
    if (!message || message.conversation_id !== conversationId) {
      throw new ConvexError({ code: "NOT_FOUND" });
    }
    const pinned = {
      message_id: message._id,
      sender_id: message.sender_id,
      snippet: snippetOf(message),
      message_type: message.message_type,
      pinned_by: user._id,
      pinned_at: Date.now(),
    };
    // Re-pinning what is already pinned changes nothing; a retry is a no-op.
    if (convo.pinned?.message_id === message._id) return convo.pinned;
    await ctx.db.patch(conversationId, { pinned, updated: pinned.pinned_at });
    return pinned;
  },
});

/**
 * Takes the pin down. Any participant; open to a free house and to a
 * suspended person, like every other removal. A no-op when nothing is pinned.
 */
export const unpin = mutation({
  args: { conversationId: v.id("conversations") },
  returns: v.null(),
  handler: async (ctx, { conversationId }) => {
    const { convo } = await assertParticipant(ctx, conversationId);
    if (convo.pinned === undefined) return null;
    await ctx.db.patch(conversationId, { pinned: undefined, updated: Date.now() });
    return null;
  },
});
