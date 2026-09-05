// Chat messages. NOTE: in Convex these queries are *live subscriptions* — a
// client that subscribes to `listByConversation` is pushed new messages
// automatically. This replaces the PocketBase SSE realtime manager entirely.

import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { QueryCtx, MutationCtx } from "./_generated/server";

const messageType = v.union(v.literal("text"), v.literal("image"), v.literal("system"));

// Shown as the notification title when the sender has no name on their profile.
const NOTIFY_TITLE = "New message";

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

/** Live, reactive message list (oldest -> newest), capped to `limit`. */
export const listByConversation = query({
  args: { conversationId: v.id("conversations"), limit: v.optional(v.number()) },
  handler: async (ctx, { conversationId, limit }) => {
    await assertParticipant(ctx, conversationId);
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_conversation", (q) => q.eq("conversation_id", conversationId))
      .order("desc")
      .take(limit ?? 100);
    return msgs.reverse();
  },
});

export const send = mutation({
  args: {
    conversationId: v.id("conversations"),
    content: v.string(),
    message_type: v.optional(messageType),
    file: v.optional(v.id("_storage")),
  },
  handler: async (ctx, args) => {
    const { user, convo } = await assertParticipant(ctx, args.conversationId);
    const now = Date.now();
    const id = await ctx.db.insert("messages", {
      conversation_id: args.conversationId,
      sender_id: user._id,
      content: args.content,
      message_type: args.message_type ?? "text",
      file: args.file,
      read_by: [user._id],
      created: now,
      updated: now,
    });
    // Keep conversation preview in sync (drives the chat list ordering).
    await ctx.db.patch(args.conversationId, {
      last_message: args.content,
      last_message_at: now,
      updated: now,
    });

    // Only the people in this conversation, not the whole home — the rest of
    // the household has no business knowing the chat exists. Scheduled rather
    // than awaited: a mutation must not block on APNs, and a failed push must
    // never roll back the message.
    await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
      userIds: convo.participants ?? [],
      actor: user._id,
      title: user.name ?? NOTIFY_TITLE,
      body:
        args.message_type === "image"
          ? "Sent a photo"
          : args.content.slice(0, 120),
      category: "messages",
      threadId: args.conversationId,
    });

    return id;
  },
});

/** Mark messages as read by the current user. */
export const markRead = mutation({
  args: { conversationId: v.id("conversations") },
  handler: async (ctx, { conversationId }) => {
    const { user } = await assertParticipant(ctx, conversationId);
    const unread = await ctx.db
      .query("messages")
      .withIndex("by_conversation", (q) => q.eq("conversation_id", conversationId))
      .order("desc")
      .take(200);
    for (const m of unread) {
      const readBy = m.read_by ?? [];
      if (!readBy.some((u) => u === user._id)) {
        await ctx.db.patch(m._id, { read_by: [...readBy, user._id] });
      }
    }
    return { ok: true };
  },
});
