// A person's own calendars, shared with one home.
//
// The phone reads the calendars the person picked (EventKit: iCloud, Gmail,
// Exchange...) and sends a window of each one ahead, replaced whole on every
// sync. Housemates see those rows beside the house's events, as "Murat ·
// busy" or, for a calendar shared at `details`, with its title and location.
// Never notes, attendees or links: the server has no field for them.
//
// Nothing here is a household event. Nothing links to a shared row, nothing
// counts it, and it cannot be edited from anywhere but the owner's own
// calendar.
//
// Plus: sharing is the `calendar` feature, the same gate as adding events.
// `setCalendars` with calendars and `replace` refuse for a free house; `mine`,
// `inRange`, `stop` and `setCalendars([])` never do (Pro never gates reads or
// removals). A house that loses Plus needs no code of its own here: `replace`
// starts refusing, so nothing is refreshed, and the daily `sweep` clears rows
// as they end and every share not synced for 30 days.
//
// Privacy: a calendar at `busy` never stores a title or location (the server
// drops them whatever the phone sent), and `inRange` reads the level off the
// owner's current share row, so moving a calendar to `busy` hides its titles
// at once, before the strip of its existing rows has finished.

import { ConvexError, v } from "convex/values";
import { internalMutation, mutation, query } from "./_generated/server";
import { MutationCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import { Doc, Id } from "./_generated/dataModel";
import { requireHomeMember, requireUser } from "./lib/auth";
import { requirePro } from "./lib/pro";
import { blockedBy } from "./lib/moderation";
import {
  MAX_ITEM_SPAN_MS,
  SHARE_DELETE_BATCH,
  calendarFingerprintPrefix,
  deleteSharedRows,
  endShare,
  itemFingerprint,
  shareOf,
} from "./lib/calendarShare";

// ---------------------------------------------------------------------------
// Limits

const DAY_MS = 24 * 60 * 60 * 1000;
/** Calendars one person may share with one home. */
const MAX_CALENDARS = 20;
/** Items one `replace` keeps, soonest first. */
const MAX_ITEMS = 500;
const MAX_NAME = 80;
const MAX_KEY = 128;
const MAX_TEXT = 200;
const MIN_WINDOW_DAYS = 7;
const MAX_WINDOW_DAYS = 120;
const DEFAULT_WINDOW_DAYS = 56;
/** Existing rows one `replace` looks at to find the ones it replaces. */
const REPLACE_READ_CAP = 2000;
/** The widest window `inRange` answers for. */
const MAX_RANGE_MS = 200 * DAY_MS;
/** Rows `inRange` returns at most. */
const IN_RANGE_CAP = 1000;
/** Share rows of one home `inRange` looks at. A household, not a city. */
const SHARES_PER_HOME = 50;
/** Hides of shared items one person's read looks at. */
const HIDDEN_READ_CAP = 500;
/** A share not synced for this long is emptied by the sweep. */
const STALE_SHARE_MS = 30 * DAY_MS;
/** Rows the sweep deletes per run, and share rows it looks at. */
const SWEEP_BATCH = 400;
const SWEEP_SHARES = 25;
/** Runs one day's sweep may chain before it stops and says so. */
const SWEEP_MAX_ROUNDS = 50;

const HEX_COLOR = /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/;

// ---------------------------------------------------------------------------
// Shapes

const level = v.union(v.literal("busy"), v.literal("details"));

const calendarIn = v.object({
  key: v.string(),
  name: v.string(),
  color: v.optional(v.string()),
  level,
});

const shareDoc = v.object({
  _id: v.id("calendar_shares"),
  _creationTime: v.number(),
  home_id: v.id("homes"),
  user_id: v.id("users"),
  calendars: v.array(calendarIn),
  window_days: v.number(),
  allow_copy: v.optional(v.boolean()),
  synced_at: v.optional(v.number()),
  updated: v.number(),
});

const sharedRow = v.object({
  _id: v.id("shared_busy"),
  user_id: v.id("users"),
  calendar_key: v.string(),
  calendar_name: v.string(),
  color: v.union(v.string(), v.null()),
  level,
  starts_at: v.number(),
  ends_at: v.number(),
  is_all_day: v.boolean(),
  /** The owner's consent to housemates copying this calendar to their phone. */
  allow_copy: v.boolean(),
  title: v.optional(v.string()),
  location: v.optional(v.string()),
});

const housemateShare = v.object({
  user_id: v.id("users"),
  allow_copy: v.boolean(),
  calendars: v.number(),
});

type Calendar = Doc<"calendar_shares">["calendars"][number];

function invalid(message: string): ConvexError<{ code: string; message: string }> {
  return new ConvexError({ code: "INVALID", message });
}

function clean(text: string | undefined, max: number): string | undefined {
  const t = text?.trim().slice(0, max);
  return t ? t : undefined;
}

function clampWindowDays(days: number): number {
  if (!Number.isFinite(days)) return DEFAULT_WINDOW_DAYS;
  return Math.min(MAX_WINDOW_DAYS, Math.max(MIN_WINDOW_DAYS, Math.round(days)));
}

/** Trimmed, capped and one entry per key (the last one sent wins). */
function cleanCalendars(input: Calendar[]): Calendar[] {
  const byKey = new Map<string, Calendar>();
  for (const c of input) {
    const key = c.key.trim();
    if (!key || key.length > MAX_KEY) throw invalid("A calendar key is empty or too long");
    const color = c.color && HEX_COLOR.test(c.color) ? c.color : undefined;
    byKey.set(key, {
      key,
      name: clean(c.name, MAX_NAME) ?? "",
      ...(color ? { color } : {}),
      level: c.level,
    });
  }
  return [...byKey.values()].slice(0, MAX_CALENDARS);
}

// ---------------------------------------------------------------------------
// The owner's side

/** The caller's share with this home, as stored, or null. Never refuses. */
export const mine = query({
  args: { homeId: v.id("homes") },
  returns: v.union(shareDoc, v.null()),
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);
    return await ctx.db
      .query("calendar_shares")
      .withIndex("by_home_user", (q) => q.eq("home_id", homeId).eq("user_id", user._id))
      .first();
  },
});

/**
 * Sets which calendars the caller shares with this home and how much of each.
 *
 * The list is the whole list: a calendar left out stops being shared and its
 * rows go; one moved from `details` to `busy` has its titles and locations
 * stripped. Up to 20 calendars (more are dropped), `windowDays` clamped to
 * 7–120. Plus when the list has anything in it; an empty list is stopping and
 * always allowed. Returns the row.
 */
export const setCalendars = mutation({
  args: {
    homeId: v.id("homes"),
    calendars: v.array(calendarIn),
    windowDays: v.number(),
    // Absent keeps what is stored (off for a new share); never required, so
    // builds from before it existed keep working.
    allowCopy: v.optional(v.boolean()),
  },
  returns: shareDoc,
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    const calendars = cleanCalendars(args.calendars);
    if (calendars.length > 0) await requirePro(ctx, home, "calendar");

    const now = Date.now();
    const windowDays = clampWindowDays(args.windowDays);
    const existing = await shareOf(ctx, home._id, user._id);
    let shareId: Id<"calendar_shares">;
    if (existing) {
      shareId = existing._id;
      await ctx.db.patch(shareId, {
        calendars,
        window_days: windowDays,
        updated: now,
        ...(args.allowCopy !== undefined ? { allow_copy: args.allowCopy } : {}),
      });
      // Scheduled, not inline: twenty calendars of rows would not fit one
      // transaction, and nothing waits on it — `inRange` joins on this row,
      // so a dropped calendar and a dropped title are gone from every screen
      // the moment the patch above lands.
      const next = new Map(calendars.map((c) => [c.key, c]));
      for (const before of existing.calendars) {
        const after = next.get(before.key);
        const target = { homeId: home._id, userId: user._id, calendarKey: before.key };
        if (!after) {
          await ctx.scheduler.runAfter(0, internal.calendarShare.purgeCalendar, target);
        } else if (before.level === "details" && after.level === "busy") {
          await ctx.scheduler.runAfter(0, internal.calendarShare.stripDetails, target);
        }
      }
    } else {
      shareId = await ctx.db.insert("calendar_shares", {
        home_id: home._id,
        user_id: user._id,
        calendars,
        window_days: windowDays,
        updated: now,
        ...(args.allowCopy !== undefined ? { allow_copy: args.allowCopy } : {}),
      });
    }
    const row = await ctx.db.get(shareId);
    if (!row) throw new Error("Share row vanished");
    return row;
  },
});

/** Deletes a batch of one calendar's rows now and schedules the rest. */
async function dropCalendarRows(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  userId: Id<"users">,
  calendarKey: string,
): Promise<void> {
  const { more } = await deleteSharedRows(ctx, homeId, userId, calendarKey);
  if (more) {
    await ctx.scheduler.runAfter(0, internal.calendarShare.purgeCalendar, {
      homeId,
      userId,
      calendarKey,
    });
  }
}

/**
 * Strips one batch of a calendar's titles and locations, and schedules the
 * rest (`stripDetails`). Reads are already safe without it (`inRange` checks the level); this
 * is so nothing private is kept that the person asked not to share.
 */
async function stripCalendarDetails(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  userId: Id<"users">,
  calendarKey: string,
  cursor: string | null = null,
): Promise<void> {
  const page = await ctx.db
    .query("shared_busy")
    .withIndex("by_user_home_calendar_ends", (q) =>
      q.eq("user_id", userId).eq("home_id", homeId).eq("calendar_key", calendarKey),
    )
    .paginate({ numItems: SHARE_DELETE_BATCH, cursor });
  await Promise.all(
    page.page
      .filter((r) => r.title !== undefined || r.location !== undefined)
      .map((r) => ctx.db.patch(r._id, { title: undefined, location: undefined })),
  );
  if (!page.isDone) {
    await ctx.scheduler.runAfter(0, internal.calendarShare.stripDetails, {
      homeId,
      userId,
      calendarKey,
      cursor: page.continueCursor,
    });
  }
}

/**
 * Replaces one shared calendar's items in [from, to) with `items`.
 *
 * The phone sends the whole window for one calendar on each sync; the rows
 * of that calendar overlapping the window are deleted and the new ones
 * written in one transaction, so a retry after a dropped connection lands
 * the same. Items that do not overlap the window, end at or before they
 * start, or have already ended are dropped; at most 500 are kept, soonest
 * first; titles and locations are cut to 200 characters, and dropped
 * entirely for a calendar shared at `busy`. An item longer than 62 days is
 * kept as its first 62. An item a moderator deleted stays deleted.
 *
 * `NOT_FOUND` when `calendarKey` is not in the caller's share list (call
 * `setCalendars` first). Plus. Returns how many rows were written.
 */
export const replace = mutation({
  args: {
    homeId: v.id("homes"),
    calendarKey: v.string(),
    from: v.number(),
    to: v.number(),
    items: v.array(
      v.object({
        startsAt: v.number(),
        endsAt: v.number(),
        isAllDay: v.optional(v.boolean()),
        title: v.optional(v.string()),
        location: v.optional(v.string()),
      }),
    ),
  },
  returns: v.object({ written: v.number() }),
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    await requirePro(ctx, home, "calendar");

    const share = await shareOf(ctx, home._id, user._id);
    const calendar = share?.calendars.find((c) => c.key === args.calendarKey);
    if (!share || !calendar) throw new ConvexError({ code: "NOT_FOUND" });

    if (!Number.isFinite(args.from) || !Number.isFinite(args.to) || args.from >= args.to) {
      throw invalid("The window is empty");
    }
    const now = Date.now();
    // A window as wide as the widest the person can pick, and a day of grace.
    const from = args.from;
    const to = Math.min(args.to, Math.max(from, now) + (MAX_WINDOW_DAYS + 1) * DAY_MS);
    if (from >= to) throw invalid("The window is empty");

    // What this calendar had in the window. An item overlaps [from, to) when
    // it ends after `from` and starts before `to`; it cannot end later than
    // `to + MAX_ITEM_SPAN_MS`, because nothing is stored longer than that.
    const existing = await ctx.db
      .query("shared_busy")
      .withIndex("by_user_home_calendar_ends", (q) =>
        q
          .eq("user_id", user._id)
          .eq("home_id", home._id)
          .eq("calendar_key", calendar.key)
          .gt("ends_at", from)
          .lt("ends_at", to + MAX_ITEM_SPAN_MS),
      )
      .take(REPLACE_READ_CAP);
    if (existing.length === REPLACE_READ_CAP) {
      console.warn(`calendarShare:replace read cap hit for ${user._id} in ${home._id}`);
    }
    await Promise.all(
      existing.filter((r) => r.starts_at < to).map((r) => ctx.db.delete(r._id)),
    );

    // Items a moderator deleted, by fingerprint, so the next sync cannot
    // bring them back.
    const prefix = calendarFingerprintPrefix(user._id, calendar.key);
    const removedReports = await ctx.db
      .query("reports")
      .withIndex("by_kind_target_status", (q) =>
        q
          .eq("kind", "calendarItem")
          .gte("target_id", prefix)
          .lt("target_id", prefix + "￿"),
      )
      .take(200);
    const removed = new Set(
      removedReports
        .filter((r) => r.status === "actioned" && r.action === "deleted")
        .map((r) => r.target_id),
    );

    const details = calendar.level === "details";
    const items = args.items
      .filter(
        (i) =>
          Number.isFinite(i.startsAt) &&
          Number.isFinite(i.endsAt) &&
          i.endsAt > i.startsAt &&
          i.endsAt > now &&
          i.endsAt > from &&
          i.startsAt < to,
      )
      .map((i) => ({
        starts_at: i.startsAt,
        ends_at: Math.min(i.endsAt, i.startsAt + MAX_ITEM_SPAN_MS),
        is_all_day: i.isAllDay === true ? true : undefined,
        title: details ? clean(i.title, MAX_TEXT) : undefined,
        location: details ? clean(i.location, MAX_TEXT) : undefined,
      }))
      .filter(
        (i) =>
          !removed.has(
            itemFingerprint({ user_id: user._id, calendar_key: calendar.key, ...i }),
          ),
      )
      .sort((a, b) => a.starts_at - b.starts_at)
      .slice(0, MAX_ITEMS);

    await Promise.all(
      items.map((i) =>
        ctx.db.insert("shared_busy", {
          home_id: home._id,
          user_id: user._id,
          calendar_key: calendar.key,
          ...i,
        }),
      ),
    );
    await ctx.db.patch(share._id, { synced_at: now });
    return { written: items.length };
  },
});

/**
 * Stops sharing: one calendar (`calendarKey`), or everything the caller
 * shares with this home. Never Plus, and idempotent. The rows go in batches;
 * a share with more than one batch finishes in scheduled steps, and is gone
 * from housemates' screens at once either way.
 */
export const stop = mutation({
  args: { homeId: v.id("homes"), calendarKey: v.optional(v.string()) },
  returns: v.object({ ok: v.boolean() }),
  handler: async (ctx, { homeId, calendarKey }) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    if (calendarKey === undefined) {
      await endShare(ctx, home._id, user._id);
      return { ok: true };
    }
    const share = await shareOf(ctx, home._id, user._id);
    if (share && share.calendars.some((c) => c.key === calendarKey)) {
      await ctx.db.patch(share._id, {
        calendars: share.calendars.filter((c) => c.key !== calendarKey),
        updated: Date.now(),
      });
    }
    await dropCalendarRows(ctx, home._id, user._id, calendarKey);
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// The house's side

/**
 * Housemates' shared items overlapping [from, to), for the calendar's
 * screen: everyone's but the caller's, only current members', only calendars
 * still in their owner's list, nothing of a person the caller blocked and
 * nothing the caller reported. Title and location only for a calendar its
 * owner shares at `details`. Up to 1000 rows and a 200-day window. Never
 * refuses for a free house.
 */
export const inRange = query({
  args: { homeId: v.id("homes"), from: v.number(), to: v.number() },
  returns: v.array(sharedRow),
  handler: async (ctx, args) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, args.homeId);
    if (!Number.isFinite(args.from) || !Number.isFinite(args.to) || args.from >= args.to) {
      return [];
    }
    const from = args.from;
    const to = Math.min(args.to, from + MAX_RANGE_MS);

    const members = new Set((home.members ?? []).filter((m) => m !== user._id));
    if (members.size === 0) return [];

    const [shares, blocked, hiddenRows] = await Promise.all([
      ctx.db
        .query("calendar_shares")
        .withIndex("by_home", (q) => q.eq("home_id", home._id))
        .take(SHARES_PER_HOME),
      blockedBy(ctx, user._id),
      ctx.db
        .query("hidden_content")
        .withIndex("by_user_kind_target", (q) =>
          q.eq("user_id", user._id).eq("kind", "calendarItem"),
        )
        .take(HIDDEN_READ_CAP),
    ]);
    const hidden = new Set(hiddenRows.map((h) => h.target_id));

    const out: (typeof sharedRow.type)[] = [];
    for (const share of shares) {
      if (!members.has(share.user_id) || blocked.has(share.user_id)) continue;
      for (const calendar of share.calendars) {
        const room = IN_RANGE_CAP - out.length;
        if (room <= 0) return out;
        const rows = await ctx.db
          .query("shared_busy")
          .withIndex("by_user_home_calendar_ends", (q) =>
            q
              .eq("user_id", share.user_id)
              .eq("home_id", home._id)
              .eq("calendar_key", calendar.key)
              .gt("ends_at", from)
              .lt("ends_at", to + MAX_ITEM_SPAN_MS),
          )
          .take(room);
        const details = calendar.level === "details";
        for (const r of rows) {
          if (r.starts_at >= to) continue;
          if (hidden.size > 0 && hidden.has(itemFingerprint(r))) continue;
          out.push({
            _id: r._id,
            user_id: r.user_id,
            calendar_key: r.calendar_key,
            calendar_name: calendar.name,
            color: calendar.color ?? null,
            level: calendar.level,
            starts_at: r.starts_at,
            ends_at: r.ends_at,
            is_all_day: r.is_all_day === true,
            allow_copy: share.allow_copy === true,
            ...(details && r.title !== undefined ? { title: r.title } : {}),
            ...(details && r.location !== undefined ? { location: r.location } : {}),
          });
        }
      }
    }
    return out.sort((a, b) => a.starts_at - b.starts_at);
  },
});

/**
 * Who in this house shares calendars, and whether they let housemates copy
 * them: one row per current member other than the caller, nothing of a person
 * the caller blocked. Never refuses for a free house. Feeds Settings'
 * "Housemates' calendars".
 */
export const housemates = query({
  args: { homeId: v.id("homes") },
  returns: v.array(housemateShare),
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    const members = new Set((home.members ?? []).filter((m) => m !== user._id));
    if (members.size === 0) return [];
    const [shares, blocked] = await Promise.all([
      ctx.db
        .query("calendar_shares")
        .withIndex("by_home", (q) => q.eq("home_id", home._id))
        .take(SHARES_PER_HOME),
      blockedBy(ctx, user._id),
    ]);
    return shares
      .filter((s) => members.has(s.user_id) && !blocked.has(s.user_id) && s.calendars.length > 0)
      .map((s) => ({
        user_id: s.user_id,
        allow_copy: s.allow_copy === true,
        calendars: s.calendars.length,
      }));
  },
});

// ---------------------------------------------------------------------------
// Continuations and the sweep

/**
 * The rest of one person's rows in one home, after their share ended
 * (`endShare`). Stops if they have started sharing with that home again: the
 * rows there now are the new share's.
 */
export const purgeUserHome = internalMutation({
  args: { homeId: v.id("homes"), userId: v.id("users") },
  returns: v.object({ deleted: v.number(), more: v.boolean() }),
  handler: async (ctx, { homeId, userId }) => {
    if (await shareOf(ctx, homeId, userId)) return { deleted: 0, more: false };
    const result = await deleteSharedRows(ctx, homeId, userId);
    if (result.more) {
      await ctx.scheduler.runAfter(0, internal.calendarShare.purgeUserHome, { homeId, userId });
    }
    return result;
  },
});

/**
 * The rest of one calendar's rows after it stopped being shared. Stops if
 * the calendar is back in the list.
 */
export const purgeCalendar = internalMutation({
  args: { homeId: v.id("homes"), userId: v.id("users"), calendarKey: v.string() },
  returns: v.object({ deleted: v.number(), more: v.boolean() }),
  handler: async (ctx, { homeId, userId, calendarKey }) => {
    const share = await shareOf(ctx, homeId, userId);
    if (share?.calendars.some((c) => c.key === calendarKey)) return { deleted: 0, more: false };
    const result = await deleteSharedRows(ctx, homeId, userId, calendarKey);
    if (result.more) {
      await ctx.scheduler.runAfter(0, internal.calendarShare.purgeCalendar, {
        homeId,
        userId,
        calendarKey,
      });
    }
    return result;
  },
});

/**
 * Strips a calendar's titles and locations after it moved from `details` to
 * `busy`, a batch per run. Stops if it went back to `details`.
 */
export const stripDetails = internalMutation({
  args: {
    homeId: v.id("homes"),
    userId: v.id("users"),
    calendarKey: v.string(),
    cursor: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, { homeId, userId, calendarKey, cursor }) => {
    const share = await shareOf(ctx, homeId, userId);
    const calendar = share?.calendars.find((c) => c.key === calendarKey);
    if (calendar?.level === "details") return null;
    await stripCalendarDetails(ctx, homeId, userId, calendarKey, cursor ?? null);
    return null;
  },
});

/**
 * The daily cleanup (crons.ts). Two halves, in order:
 *
 *  1. Rows that ended more than a day ago. A share is a window ahead, not a
 *     history.
 *  2. Shares not synced for 30 days (a phone that is gone should not keep
 *     saying "busy"): their rows are deleted and their calendar list emptied,
 *     `synced_at` cleared and `updated` set, so the person sees sharing as
 *     off. A share that then sits empty and untouched for another 30 days is
 *     deleted outright, so the range never fills with empty rows.
 *
 * Bounded per run, chaining itself while there is more, up to fifty runs a
 * day. Idempotent: a rerun only finds less. This is also what clears the
 * rows of a house that stopped paying for Plus: `replace` refuses, nothing
 * is synced, and both halves take it from there.
 */
export const sweep = internalMutation({
  args: { round: v.optional(v.number()) },
  returns: v.object({ deleted: v.number(), shares: v.number(), more: v.boolean() }),
  handler: async (ctx, { round }) => {
    const n = round ?? 0;
    const now = Date.now();
    let more = false;

    const past = await ctx.db
      .query("shared_busy")
      .withIndex("by_ends", (q) => q.lt("ends_at", now - DAY_MS))
      .take(SWEEP_BATCH);
    await Promise.all(past.map((r) => ctx.db.delete(r._id)));
    let deleted = past.length;
    if (past.length === SWEEP_BATCH) more = true;

    let shares = 0;
    if (!more) {
      const cutoff = now - STALE_SHARE_MS;
      // Synced, but not for 30 days. `gte(0)` keeps never-synced rows out.
      const stale = await ctx.db
        .query("calendar_shares")
        .withIndex("by_synced_updated", (q) => q.gte("synced_at", 0).lt("synced_at", cutoff))
        .take(SWEEP_SHARES);
      for (const share of stale) {
        const result = await deleteSharedRows(ctx, share.home_id, share.user_id);
        deleted += result.deleted;
        if (result.more) {
          more = true;
          break;
        }
        await ctx.db.patch(share._id, { calendars: [], synced_at: undefined, updated: now });
        shares += 1;
        if (deleted >= SWEEP_BATCH * 2) {
          more = true;
          break;
        }
      }
      if (stale.length === SWEEP_SHARES) more = true;

      // Never synced (or emptied above) and untouched for 30 days.
      const idle = await ctx.db
        .query("calendar_shares")
        .withIndex("by_synced_updated", (q) =>
          q.eq("synced_at", undefined).lt("updated", cutoff),
        )
        .take(SWEEP_SHARES);
      for (const share of idle) {
        if (share.calendars.length > 0) {
          // Shared, never sent anything: nothing to delete but the list.
          await ctx.db.patch(share._id, { calendars: [], updated: now });
        } else {
          await ctx.db.delete(share._id);
        }
        shares += 1;
      }
      if (idle.length === SWEEP_SHARES) more = true;
    }

    if (deleted > 0 || shares > 0) {
      console.log(
        `calendarShare:sweep round ${n}: deleted ${deleted} rows, ${shares} shares${more ? ", more to go" : ""}`,
      );
    }
    if (more) {
      if (n + 1 >= SWEEP_MAX_ROUNDS) {
        console.error(`calendarShare:sweep stopped after ${n + 1} rounds; tomorrow's run continues`);
      } else {
        await ctx.scheduler.runAfter(0, internal.calendarShare.sweep, { round: n + 1 });
      }
    }
    return { deleted, shares, more };
  },
});
