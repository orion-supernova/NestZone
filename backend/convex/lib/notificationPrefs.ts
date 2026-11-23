// Per-person notification preferences: which topics a person wants pushed, and
// when their phone should stay quiet.
//
// Enforced where pushes are sent (push.ts), never at the call sites. Two rules
// hold whatever is stored here:
//   - The household's feed (`inbox.record`) is never filtered. A topic switched
//     off stops the tap on the shoulder, not the record in the app.
//   - Some pushes are not the household's and are never filtered: the
//     moderators' and the test push (`UNFILTERED`).
//
// A person with no row hears everything, exactly as before preferences existed.

import { Id } from "../_generated/dataModel";
import { QueryCtx } from "../_generated/server";

/**
 * Every topic a push can carry. The contract with the app's Settings screen:
 * add, never rename. Each push in the backend names exactly one of these
 * (`topic` on `push.notifyHome` / `notifyUsers`), or one is derived from its
 * category (`topicFor`).
 */
export const TOPICS = [
  "tasks.assigned",
  "tasks.new",
  "tasks.done",
  "shopping.added",
  "shopping.bought",
  "notes",
  "calendar.events",
  "calendar.rsvp",
  "calendar.reminders",
  "meals",
  "movies",
  "finance.expenses",
  "finance.reminders",
  "issues.new",
  "issues.updates",
  "issues.reminders",
  "messages.direct",
  "messages.group",
  "messages.mentions",
  "polls",
  "companion.ready",
  "companion.vote",
  "companion.new",
  "home.members",
  // Never switchable (`UNFILTERED`); listed so every push's topic is here.
  "home.removed",
] as const;

export type Topic = (typeof TOPICS)[number];

/**
 * Never switchable: the moderators' pushes, the test push, being removed from
 * a home (a person has to hear that), and a push whose category no topic
 * covers (`other`), which must not be silenced by a switch it doesn't match.
 */
export const UNFILTERED = new Set(["moderation", "test", "home.removed", "other"]);

/**
 * The topic of a push that did not name one, from its category. Every caller
 * in this backend names one; this is what keeps a future caller that forgets
 * from being unclassified (and so unswitchable).
 */
const CATEGORY_TOPIC: Record<string, string> = {
  tasks: "tasks.new",
  shopping: "shopping.added",
  notes: "notes",
  calendar: "calendar.events",
  meals: "meals",
  recipes: "meals",
  movies: "movies",
  finance: "finance.expenses",
  issues: "issues.updates",
  messages: "messages.group",
  polls: "polls",
  companion: "companion.ready",
  home: "home.members",
  moderation: "moderation",
  test: "test",
};

export function topicFor(topic: string | undefined, category: string | undefined): string {
  if (topic) return topic;
  const derived = CATEGORY_TOPIC[category ?? ""];
  if (derived) return derived;
  console.warn(`push with no topic and an unmapped category: ${category ?? "(none)"}`);
  return "other";
}

export const MAX_OFF = 100;
export const MAX_KEY_LENGTH = 64;
export const MINUTES_PER_DAY = 24 * 60;

export type Quiet = { start: number; end: number; time_zone: string };

/**
 * Whether `timeZone` is an IANA zone this runtime can actually compute in.
 * Formats a fixed instant and checks the zone round-trips, so a runtime that
 * quietly falls back to UTC for a zone it doesn't know is caught too.
 */
export function isValidTimeZone(timeZone: string): boolean {
  if (!timeZone || timeZone.length > 64) return false;
  try {
    const format = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    });
    format.format(new Date(Date.UTC(2026, 0, 1, 12, 0)));
    const resolved = format.resolvedOptions().timeZone;
    if (!resolved) return false;
    const norm = (z: string) => z.toLowerCase();
    // The runtime's ICU reports some zones by their older canonical name
    // (checked on this deployment: Europe/Kyiv resolves as Europe/Kiev,
    // Asia/Kolkata as Asia/Calcutta), so the name need not round-trip. What
    // must not happen is a real zone quietly becoming UTC.
    const utc = new Set(["utc", "etc/utc", "etc/gmt", "gmt", "etc/universal", "universal", "zulu", "etc/zulu"]);
    return !utc.has(norm(resolved)) || utc.has(norm(timeZone));
  } catch {
    return false;
  }
}

/** Minutes after midnight at `now` in `timeZone`, or null if it cannot say. */
function localMinutes(now: number, timeZone: string): number | null {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date(now));
    const hour = Number(parts.find((p) => p.type === "hour")?.value);
    const minute = Number(parts.find((p) => p.type === "minute")?.value);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
    return (hour % 24) * 60 + minute;
  } catch {
    return null;
  }
}

/**
 * Whether `now` falls inside the quiet window, in the person's own time zone.
 * `start` inclusive, `end` exclusive; a window whose end is before its start
 * wraps midnight. A zone that cannot be read is never quiet: the push goes out
 * as it always did rather than being silenced by a broken setting.
 */
export function isQuietAt(quiet: Quiet | undefined, now: number): boolean {
  if (!quiet || quiet.start === quiet.end) return false;
  const minutes = localMinutes(now, quiet.time_zone);
  if (minutes === null) return false;
  return quiet.start < quiet.end
    ? minutes >= quiet.start && minutes < quiet.end
    : minutes >= quiet.start || minutes < quiet.end;
}

/** What the sender needs to know about one person for one push. */
export type Delivery = "normal" | "passive" | "off";

/**
 * The preferences of everybody in `userIds`, one indexed read each, in one
 * round. Bounded by the household (or the conversation), which is what the
 * sender is addressing anyway.
 */
export async function prefsOf(ctx: QueryCtx, userIds: Id<"users">[]) {
  const rows = await Promise.all(
    userIds.map((userId) =>
      ctx.db
        .query("notification_prefs")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .first(),
    ),
  );
  const byUser = new Map<Id<"users">, { off: Set<string>; quiet?: Quiet }>();
  rows.forEach((row, i) => {
    if (row) byUser.set(userIds[i], { off: new Set(row.off), quiet: row.quiet });
  });
  return byUser;
}

/** How one person should hear a push on `topic` at `now`. */
export function deliveryFor(
  prefs: { off: Set<string>; quiet?: Quiet } | undefined,
  topic: string,
  now: number,
): Delivery {
  if (UNFILTERED.has(topic) || !prefs) return "normal";
  if (prefs.off.has(topic)) return "off";
  return isQuietAt(prefs.quiet, now) ? "passive" : "normal";
}
