// Home dashboard counters.
//
// The iOS Home tab used to compute these on-device: it subscribed to
// `shopping:listByHome`, `notes:listByHome` and `tasks:listByHome`, pulled every
// document in all three collections down to the phone, and filtered them by
// `created` in Swift — on every appearance of the tab, plus again whenever the
// selected home changed. For a household with a year of history that is
// megabytes of JSON to render six integers, and it also fetched
// `tasks:listByHome` twice per pass because the task list and the stats block
// each asked for it separately.
//
// This does the counting where the data already is and returns ~100 bytes.

import { query } from "./_generated/server";
import { v } from "convex/values";
import { requireUser, requireHomeMember } from "./lib/auth";

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/** Documents created inside [start, end). */
function countBetween(
  docs: { created?: number; _creationTime: number }[],
  start: number,
  end: number,
): number {
  let n = 0;
  for (const doc of docs) {
    // Migrated PocketBase rows may have no `created`; `_creationTime` is always
    // stamped by Convex, so it is the reliable fallback.
    const at = doc.created ?? doc._creationTime;
    if (at >= start && at < end) n++;
  }
  return n;
}

export const forHome = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);

    const [tasks, shopping, notes, conversations] = await Promise.all([
      ctx.db
        .query("tasks")
        .withIndex("by_home", (q) => q.eq("home_id", homeId))
        .collect(),
      ctx.db
        .query("shopping_items")
        .withIndex("by_home", (q) => q.eq("home_id", homeId))
        .collect(),
      ctx.db
        .query("notes")
        .withIndex("by_home", (q) => q.eq("home_id", homeId))
        .collect(),
      ctx.db
        .query("conversations")
        .withIndex("by_home", (q) => q.eq("home_id", homeId))
        .collect(),
    ]);

    const now = Date.now();
    const weekAgo = now - WEEK_MS;
    const twoWeeksAgo = now - 2 * WEEK_MS;

    // Unread messages actually mean something now. The client previously
    // reported `messageCount = noteCount` — the note count relabelled — so the
    // "Messages" tile on the Home tab has never shown a message count.
    let unreadMessages = 0;
    for (const conversation of conversations) {
      const messages = await ctx.db
        .query("messages")
        .withIndex("by_conversation", (q) => q.eq("conversation_id", conversation._id))
        .collect();
      for (const message of messages) {
        if (message.sender_id === user._id) continue;
        if (!(message.read_by ?? []).includes(user._id)) unreadMessages++;
      }
    }

    const completedThisWeek = tasks.filter(
      (t) => t.is_completed && (t.updated ?? t._creationTime) >= weekAgo,
    ).length;
    const completedLastWeek = tasks.filter((t) => {
      const at = t.updated ?? t._creationTime;
      return t.is_completed && at >= twoWeeksAgo && at < weekAgo;
    }).length;

    const shoppingThisWeek = countBetween(shopping, weekAgo, now);
    const notesThisWeek = countBetween(notes, weekAgo, now);

    return {
      openTasks: tasks.filter((t) => !t.is_completed).length,
      completedTasks: tasks.filter((t) => t.is_completed).length,
      urgentTasks: tasks.filter((t) => !t.is_completed && t.priority === "high").length,
      shoppingItems: shopping.filter((s) => !s.is_purchased).length,
      notes: notes.length,
      unreadMessages,

      completedTasksChange: completedThisWeek - completedLastWeek,
      shoppingChange: shoppingThisWeek - countBetween(shopping, twoWeeksAgo, weekAgo),
      notesChange: notesThisWeek - countBetween(notes, twoWeeksAgo, weekAgo),
      // No historical read-state to compare against, so this stays flat rather
      // than inventing a trend.
      messagesChange: 0,
    };
  },
});
