// A person's notification preferences: which topics reach their phones, and
// their quiet hours. The rules and the topic list are in
// lib/notificationPrefs.ts; push.ts enforces them on the way out.

import { ConvexError, v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { Doc } from "./_generated/dataModel";
import { requireUser } from "./lib/auth";
import {
  MAX_KEY_LENGTH,
  MAX_OFF,
  MINUTES_PER_DAY,
  isValidTimeZone,
} from "./lib/notificationPrefs";

const quietShape = v.object({ start: v.number(), end: v.number(), timeZone: v.string() });

const prefsShape = v.object({
  off: v.array(v.string()),
  quiet: v.union(v.null(), quietShape),
});

function invalid(message: string): ConvexError<{ code: string; message: string }> {
  return new ConvexError({ code: "INVALID", message });
}

function shape(row: Pick<Doc<"notification_prefs">, "off" | "quiet"> | null) {
  return {
    off: row?.off ?? [],
    quiet: row?.quiet
      ? { start: row.quiet.start, end: row.quiet.end, timeZone: row.quiet.time_zone }
      : null,
  };
}

/** The caller's preferences. No row is the default: everything on, no quiet hours. */
export const mine = query({
  args: {},
  returns: prefsShape,
  handler: async (ctx) => {
    const user = await requireUser(ctx);
    const row = await ctx.db
      .query("notification_prefs")
      .withIndex("by_user", (q) => q.eq("user_id", user._id))
      .first();
    return shape(row);
  },
});

/**
 * Replaces the caller's preferences wholesale and answers with what was
 * stored. Idempotent: the same call twice stores the same thing.
 *
 * `off` keeps keys this backend does not know (a newer build's topics), but
 * no more than 100 of them, each at most 64 characters. `start == end` means no
 * quiet hours and stores none. A time zone the runtime can't compute in is not
 * an error: the topics are stored and the quiet hours stay as they were, which
 * is what the answer returns.
 */
export const set = mutation({
  args: prefsShape.fields,
  returns: prefsShape,
  handler: async (ctx, { off, quiet }) => {
    const user = await requireUser(ctx);

    const keys = Array.from(new Set(off.map((k) => k.trim()).filter((k) => k.length > 0)));
    if (keys.length > MAX_OFF) throw invalid(`At most ${MAX_OFF} topics`);
    if (keys.some((k) => k.length > MAX_KEY_LENGTH)) {
      throw invalid(`A topic is at most ${MAX_KEY_LENGTH} characters`);
    }

    const existing = await ctx.db
      .query("notification_prefs")
      .withIndex("by_user", (q) => q.eq("user_id", user._id))
      .first();

    let stored: Doc<"notification_prefs">["quiet"] = undefined;
    if (quiet) {
      for (const minute of [quiet.start, quiet.end]) {
        if (!Number.isInteger(minute) || minute < 0 || minute >= MINUTES_PER_DAY) {
          throw invalid("Quiet hours are minutes from 0 to 1439");
        }
      }
      // start == end is "no quiet hours", whatever the zone says.
      if (quiet.start !== quiet.end) {
        const timeZone = quiet.timeZone.trim();
        if (isValidTimeZone(timeZone)) {
          stored = { start: quiet.start, end: quiet.end, time_zone: timeZone };
        } else {
          // A zone this runtime can't compute in must not cost the person
          // their topic switches: those are stored, and the quiet hours stay
          // as they were. The answer says so, and the client sees it.
          console.warn(`notificationPrefs:set: unknown time zone "${timeZone}"; quiet hours unchanged`);
          stored = existing?.quiet;
        }
      }
    }

    const now = Date.now();
    if (existing) {
      // `replace`, so clearing quiet hours really removes the field.
      await ctx.db.replace(existing._id, {
        user_id: user._id,
        off: keys,
        ...(stored ? { quiet: stored } : {}),
        updated: now,
      });
    } else {
      await ctx.db.insert("notification_prefs", {
        user_id: user._id,
        off: keys,
        ...(stored ? { quiet: stored } : {}),
        updated: now,
      });
    }
    return shape({ off: keys, quiet: stored });
  },
});
