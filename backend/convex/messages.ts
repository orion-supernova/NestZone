// Chat messages. NOTE: in Convex these queries are *live subscriptions* — a
// client that subscribes to `listByConversation` is pushed new messages
// automatically. This replaces the PocketBase SSE realtime manager entirely.

import { query, mutation } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { requireUser } from "./lib/auth";
import { requirePro } from "./lib/pro";
import { blockedBy, blockedEitherWay, discardFile, requireChatAllowed } from "./lib/moderation";
import { claimFile } from "./lib/files";
import { internal } from "./_generated/api";
import { Doc, Id } from "./_generated/dataModel";
import { QueryCtx, MutationCtx } from "./_generated/server";
import {
  MAX_MENTIONS,
  Reaction,
  normalizeReaction,
  reactionValidator,
  snippetOf,
} from "./lib/chat";

const messageType = v.union(v.literal("text"), v.literal("image"), v.literal("system"));

// Shown as the notification title when the sender has no name on their profile.
const NOTIFY_TITLE = "New message";

/**
 * How far back opening a conversation marks it read.
 *
 * Exported because `stats:forHome` must count unread over exactly this window.
 * A badge counted over a wider one is a badge that opening the chat cannot
 * clear, which is how it gets permanently stuck.
 */
export const READ_WINDOW = 200;

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
    const { user } = await assertParticipant(ctx, conversationId);
    const count = limit ?? 100;

    // What this caller has blocked or reported is left out for them alone
    // (lib/moderation.ts). Two indexed ranges, both nearly always empty; when
    // they are, the read is exactly what it always was.
    const [blocked, hiddenRows] = await Promise.all([
      blockedBy(ctx, user._id),
      ctx.db
        .query("hidden_content")
        .withIndex("by_user_conversation", (q) =>
          q.eq("user_id", user._id).eq("conversation_id", conversationId),
        )
        .take(HIDDEN_READ_CAP),
    ]);
    if (blocked.size === 0 && hiddenRows.length === 0) {
      const msgs = await ctx.db
        .query("messages")
        .withIndex("by_conversation", (q) => q.eq("conversation_id", conversationId))
        .order("desc")
        .take(count);
      return msgs.reverse();
    }

    // Read a little further back so a thread with a blocked talker still
    // fills the page, then trim to what was asked for.
    const hidden = new Set(hiddenRows.map((h) => h.target_id));
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_conversation", (q) => q.eq("conversation_id", conversationId))
      .order("desc")
      .take(count + Math.min(Math.max(count, 0), 200));
    return msgs
      .filter((m) => !blocked.has(m.sender_id) && !hidden.has(m._id))
      .slice(0, count)
      .reverse()
      .map((m) => {
        // Somebody blocked does not show up in the reaction row either. No
        // read: the reactions are on the message.
        if (blocked.size === 0 || !m.reactions?.some((r) => blocked.has(r.user_id))) return m;
        return { ...m, reactions: m.reactions.filter((r) => !blocked.has(r.user_id)) };
      });
  },
});

/** The most per-thread hides one read looks at. */
const HIDDEN_READ_CAP = 500;

export const send = mutation({
  args: {
    conversationId: v.id("conversations"),
    content: v.string(),
    messageType: v.optional(messageType),
    file: v.optional(v.id("_storage")),
    /** The message this one answers. Must be in the same conversation. */
    replyToId: v.optional(v.id("messages")),
    /** People named in it. Kept only if they are in this conversation. */
    mentions: v.optional(v.array(v.id("users"))),
  },
  handler: async (ctx, args) => {
    const { user, convo } = await assertParticipant(ctx, args.conversationId);
    requireChatAllowed(user);
    // A 1:1 with somebody either side has blocked is closed.
    if (!convo.is_group_chat) {
      const other = (convo.participants ?? []).find((p) => p !== user._id);
      if (other && (await blockedEitherWay(ctx, user._id, other))) {
        throw new ConvexError({ code: "BLOCKED" });
      }
    }
    // Messages is Plus. Reading, marking read and deleting stay open: a house
    // that stops paying keeps every word it wrote.
    await requirePro(ctx, convo.home_id, "messages");
    const kind = args.messageType ?? "text";
    // A blank bubble is not a message. The composer already refuses to send one;
    // this is so a retry, a paste of whitespace or a future client cannot.
    const content = args.content.trim();
    if (!content && kind === "text" && !args.file) {
      throw new Error("Message is empty");
    }
    // The quote is copied now, so drawing it never needs a read and a later
    // delete leaves it standing. A target deleted in the moment before this
    // send goes out without its quote rather than failing the send. Replying
    // to a message the sender hid or blocked is allowed: it is their call.
    let replyTo: Doc<"messages">["reply_to"];
    if (args.replyToId) {
      const target = await ctx.db.get(args.replyToId);
      if (target) {
        if (target.conversation_id !== args.conversationId) {
          throw new ConvexError({ code: "REPLY_ELSEWHERE" });
        }
        replyTo = {
          message_id: target._id,
          sender_id: target.sender_id,
          snippet: snippetOf(target),
          message_type: target.message_type,
          sent_at: target.created ?? target._creationTime,
        };
      }
    }

    // Only people in this thread, never the sender, at most ten. Anything else
    // is dropped, not refused: a mention is a nudge, not the message.
    const inThread = new Set(convo.participants ?? []);
    const mentions = Array.from(new Set(args.mentions ?? []))
      .filter((id) => id !== user._id && inThread.has(id))
      .slice(0, MAX_MENTIONS);

    // Only a file this house uploaded (lib/files.ts): an id read off another
    // house's signed URL is refused, or deleting this message would delete it.
    if (args.file) {
      await claimFile(ctx, args.file, { homeId: convo.home_id, userId: user._id, kind: "message" });
    }

    const now = Date.now();
    const id = await ctx.db.insert("messages", {
      conversation_id: args.conversationId,
      sender_id: user._id,
      content,
      message_type: kind,
      file: args.file,
      read_by: [user._id],
      ...(replyTo ? { reply_to: replyTo } : {}),
      ...(mentions.length ? { mentions } : {}),
      created: now,
      updated: now,
    });
    // Keep conversation preview in sync (drives the chat list ordering).
    await ctx.db.patch(args.conversationId, {
      last_message: content,
      last_message_at: now,
      updated: now,
    });

    // Only the people in this conversation, not the whole home — the rest of
    // the household has no business knowing the chat exists. Scheduled rather
    // than awaited: a mutation must not block on APNs, and a failed push must
    // never roll back the message.
    //
    // The people it mentions hear "mentioned you" instead of the plain alert,
    // never both (`variant`); blocks apply to both, and the feed keeps its one
    // row for the message as it always has.
    const body = kind === "image" ? "Sent a photo" : content.slice(0, 120);
    await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
      userIds: convo.participants ?? [],
      actor: user._id,
      homeId: convo.home_id,
      title: user.name ?? NOTIFY_TITLE,
      body,
      category: "messages",
      threadId: args.conversationId,
      ...(mentions.length
        ? {
            variant: {
              userIds: mentions,
              title: `${user.name ?? "Someone"} mentioned you`,
              body,
            },
          }
        : {}),
    });

    return id;
  },
});

/**
 * The author of a message, or a throw.
 *
 * Participation is not enough: anyone in the thread could otherwise rewrite or
 * delete anybody else's words.
 */
async function assertAuthor(ctx: MutationCtx, messageId: Id<"messages">) {
  const user = await requireUser(ctx);
  const message = await ctx.db.get(messageId);
  if (!message) throw new Error("Message not found");
  if (message.sender_id !== user._id) {
    throw new Error("You can only change your own messages");
  }
  // Still has to be a thread they belong to -- membership can have been lost
  // since the message was written.
  const { convo } = await assertParticipant(ctx, message.conversation_id);
  return { user, message, convo };
}

/**
 * Repoint a conversation's preview at whatever is newest now.
 *
 * The list is ordered by `last_message_at` and shows `last_message`, so editing
 * or deleting the newest message leaves the row quoting text that no longer
 * exists -- or text that was never the latest.
 */
export async function refreshPreview(
  ctx: MutationCtx,
  conversationId: Id<"conversations">,
  /**
   * The message just deleted, if that is why. A pin on it goes in the same
   * write, so a thread never shows a pin for a message that is gone. Every
   * delete passes it (`remove`, moderation's `deleteContent`).
   */
  removed?: Id<"messages">,
) {
  const [newest] = await ctx.db
    .query("messages")
    .withIndex("by_conversation", (q) => q.eq("conversation_id", conversationId))
    .order("desc")
    .take(1);
  const convo = removed ? await ctx.db.get(conversationId) : null;
  const unpin = convo?.pinned !== undefined && convo.pinned.message_id === removed;
  await ctx.db.patch(conversationId, {
    last_message: newest?.content,
    last_message_at: newest?.created,
    ...(unpin ? { pinned: undefined } : {}),
    updated: Date.now(),
  });
}

/** Rewrite one of your own messages. */
export const edit = mutation({
  args: { messageId: v.id("messages"), content: v.string() },
  handler: async (ctx, { messageId, content }) => {
    const { user, message, convo } = await assertAuthor(ctx, messageId);
    requireChatAllowed(user);
    await requirePro(ctx, convo.home_id, "messages");
    const trimmed = content.trim();
    if (!trimmed) throw new Error("Message is empty");
    // Reactions, mentions and the quote stay as sent; nobody is notified again.
    await ctx.db.patch(messageId, { content: trimmed, updated: Date.now() });
    await refreshPreview(ctx, message.conversation_id);
    // A pinned message shows its new words at the top too.
    if (convo.pinned?.message_id === messageId) {
      await ctx.db.patch(convo._id, {
        pinned: { ...convo.pinned, snippet: snippetOf({ ...message, content: trimmed }) },
      });
    }
    return await ctx.db.get(messageId);
  },
});

/** Delete one of your own messages. `remove`, because `delete` is a keyword. */
export const remove = mutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const { message } = await assertAuthor(ctx, messageId);
    // Its reactions go with it (they are on the document), and its pin too.
    await ctx.db.delete(messageId);
    await refreshPreview(ctx, message.conversation_id, messageId);
    // The picture goes with the message, unless a report still holds it.
    await discardFile(ctx, message.file);
    return { ok: true };
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
      .take(READ_WINDOW);
    // Two hundred patches, in one round rather than end to end. Awaited one at
    // a time this is the worst instance of the pattern that timed out
    // `events:stockUp` — and it runs every time somebody opens a busy chat.
    await Promise.all(
      unread
        .filter((m) => !(m.read_by ?? []).some((u) => u === user._id))
        .map((m) => ctx.db.patch(m._id, { read_by: [...(m.read_by ?? []), user._id] })),
    );
    return { ok: true };
  },
});

/**
 * Adds or takes back the caller's reaction on a message, and answers with the
 * message's reactions after it.
 *
 * `on` says which: true adds, false takes back, so a retried request lands
 * where the first one did. Absent, it toggles. One reaction per person per
 * emoji, from the six in lib/chat.ts (`INVALID_REACTION` otherwise).
 *
 * Messages is Plus, and this is a write in it, so it refuses for a free house
 * (`PRO_REQUIRED`); every read and removal stays open, and a reaction already
 * there is still drawn. A suspended person may still react, as they may still
 * vote in a chat poll: a reaction writes no words. A 1:1 that either side has
 * blocked is closed (`BLOCKED`), as it is to sending.
 *
 * Touches nothing but `reactions`: not `updated` (which would read as an
 * edit), not `read_by`, not the conversation's preview or order. No push.
 */
export const react = mutation({
  args: {
    messageId: v.id("messages"),
    emoji: v.string(),
    on: v.optional(v.boolean()),
  },
  returns: v.array(reactionValidator),
  handler: async (ctx, { messageId, emoji, on }) => {
    const message = await ctx.db.get(messageId);
    if (!message) throw new Error("Message not found");
    const { user, convo } = await assertParticipant(ctx, message.conversation_id);
    const chosen = normalizeReaction(emoji);
    if (!chosen) throw new ConvexError({ code: "INVALID_REACTION" });
    if (!convo.is_group_chat) {
      const other = (convo.participants ?? []).find((p) => p !== user._id);
      if (other && (await blockedEitherWay(ctx, user._id, other))) {
        throw new ConvexError({ code: "BLOCKED" });
      }
    }
    await requirePro(ctx, convo.home_id, "messages");

    const current: Reaction[] = message.reactions ?? [];
    const mine = current.some((r) => r.user_id === user._id && r.emoji === chosen);
    const want = on ?? !mine;
    if (want === mine) return current;
    const next = want
      ? [...current, { emoji: chosen, user_id: user._id }]
      : current.filter((r) => !(r.user_id === user._id && r.emoji === chosen));
    await ctx.db.patch(messageId, { reactions: next.length ? next : undefined });
    return next;
  },
});
