// The chat MVP's fields: reactions, replies, pins and mentions.
//
// Every one is an optional field on a document that already exists (messages,
// conversations), never a table of its own: each is read with the document it
// belongs to, so drawing a thread costs exactly the reads it always did. Every
// build decodes messages and conversations with explicit coding keys, so a
// field it does not know is ignored, not a crash.

import { v, Infer } from "convex/values";
import type { Doc } from "../_generated/dataModel";

/**
 * The six reactions. A house app, not a chat app: a short fixed row, so the
 * array on a message is bounded by six times the people in the thread.
 */
export const REACTION_EMOJI = ["👍", "❤️", "😂", "😮", "😢", "🙏"] as const;

/**
 * The emoji as the allow-list spells it, or null. A heart typed without its
 * variation selector (U+2764 alone, as some keyboards send it) is the same
 * heart.
 */
export function normalizeReaction(raw: string): string | null {
  const trimmed = raw.trim();
  const emoji = trimmed === "❤" ? "❤️" : trimmed;
  return (REACTION_EMOJI as readonly string[]).includes(emoji) ? emoji : null;
}

/** One person's one reaction. One row per person per emoji. */
export const reactionValidator = v.object({
  emoji: v.string(),
  user_id: v.id("users"),
});
export type Reaction = Infer<typeof reactionValidator>;

/** How much of a message a reply or a pin quotes. */
export const SNIPPET_LENGTH = 140;

/** The most people one message may mention. */
export const MAX_MENTIONS = 10;

/**
 * What a reply quotes, copied when it is sent so drawing it needs no read.
 * If the original is deleted later the quote stays; the client just cannot
 * jump to it. `message_type` lets a client say "Photo" in its own language
 * when the quoted message is a picture (its snippet is then the caption, or
 * empty).
 */
export const replyToValidator = v.object({
  message_id: v.id("messages"),
  sender_id: v.id("users"),
  snippet: v.string(),
  message_type: v.optional(
    v.union(v.literal("text"), v.literal("image"), v.literal("system")),
  ),
  sent_at: v.optional(v.number()),
});

/**
 * A conversation's one pinned message, as a snapshot. Cleared in the same
 * mutation that deletes the message; refreshed when its author edits it.
 */
export const pinnedValidator = v.object({
  message_id: v.id("messages"),
  sender_id: v.optional(v.id("users")),
  snippet: v.string(),
  message_type: v.optional(
    v.union(v.literal("text"), v.literal("image"), v.literal("system")),
  ),
  pinned_by: v.id("users"),
  pinned_at: v.number(),
});
export type Pinned = Infer<typeof pinnedValidator>;

/** The quoted part of a message. */
export function snippetOf(message: Doc<"messages">): string {
  return (message.content ?? "").trim().slice(0, SNIPPET_LENGTH);
}
