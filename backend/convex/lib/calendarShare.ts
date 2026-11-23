// Shared calendars: what more than one module needs to know about them.
//
// `calendarShare.ts` owns the functions; this holds the pieces that leaving a
// home (`departHome`), deleting an account, moderation and the sweep also
// call, so "stop sharing" means the same thing on every path out.

import { Doc, Id } from "../_generated/dataModel";
import { MutationCtx } from "../_generated/server";
import { internal } from "../_generated/api";

/** Rows deleted per transaction by any of the deletes here. */
export const SHARE_DELETE_BATCH = 400;

/** One shared item is never drawn as longer than this (a trip, a holiday). */
export const MAX_ITEM_SPAN_MS = 62 * 24 * 60 * 60 * 1000;

/**
 * What a reported shared item is known by, and what the reporter's hide is
 * keyed on: the person, their calendar and the item's times. Not the row id,
 * because every sync replaces the rows, and a hide or a moderator's deletion
 * has to survive the next sync.
 */
export function itemFingerprint(row: {
  user_id: Id<"users">;
  calendar_key: string;
  starts_at: number;
  ends_at: number;
}): string {
  return `${row.user_id}:${row.calendar_key}:${row.starts_at}:${row.ends_at}`;
}

/** The common start of every fingerprint of one person's one calendar. */
export function calendarFingerprintPrefix(userId: Id<"users">, calendarKey: string): string {
  return `${userId}:${calendarKey}:`;
}

/** The `ends_at` a fingerprint names, or null for one that is not one. */
export function fingerprintEndsAt(fingerprint: string): number | null {
  const last = fingerprint.slice(fingerprint.lastIndexOf(":") + 1);
  const n = Number(last);
  return Number.isFinite(n) ? n : null;
}

/**
 * Deletes up to a batch of one person's rows in one home, all calendars or
 * one. Returns whether more are left.
 */
export async function deleteSharedRows(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  userId: Id<"users">,
  calendarKey?: string,
): Promise<{ deleted: number; more: boolean }> {
  const rows = await ctx.db
    .query("shared_busy")
    .withIndex("by_user_home_calendar_ends", (q) => {
      const byHome = q.eq("user_id", userId).eq("home_id", homeId);
      return calendarKey === undefined ? byHome : byHome.eq("calendar_key", calendarKey);
    })
    .take(SHARE_DELETE_BATCH);
  await Promise.all(rows.map((r) => ctx.db.delete(r._id)));
  return { deleted: rows.length, more: rows.length === SHARE_DELETE_BATCH };
}

/** The caller's share row in a home, if any. `.first()` tolerates a race. */
export async function shareOf(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  userId: Id<"users">,
): Promise<Doc<"calendar_shares"> | null> {
  return await ctx.db
    .query("calendar_shares")
    .withIndex("by_home_user", (q) => q.eq("home_id", homeId).eq("user_id", userId))
    .first();
}

/**
 * Ends one person's sharing with one home, now: the share row goes in this
 * transaction, so `inRange` (which joins on it) stops showing their rows at
 * once, and the rows themselves drain in batches behind it
 * (`calendarShare:purgeUserHome`). Leaving, being removed, deleting the
 * account and `calendarShare:stop` all come through here.
 */
export async function endShare(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  userId: Id<"users">,
): Promise<void> {
  const shares = await ctx.db
    .query("calendar_shares")
    .withIndex("by_home_user", (q) => q.eq("home_id", homeId).eq("user_id", userId))
    .take(10);
  await Promise.all(shares.map((s) => ctx.db.delete(s._id)));
  const { more } = await deleteSharedRows(ctx, homeId, userId);
  if (more) {
    await ctx.scheduler.runAfter(0, internal.calendarShare.purgeUserHome, { homeId, userId });
  }
}
