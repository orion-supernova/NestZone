// Reporting, blocking and the moderation queue (App Store guideline 1.2).
//
// Anybody who can see a message, a problem photo, a face or a housemate's
// shared calendar item can report it; the
// report hides it from them at once and goes to the moderators named in
// `MODERATOR_USER_IDS` (lib/moderation.ts). A moderator can dismiss it, delete
// the content, take the person out of the home, or stop them writing in chat.
// That is the only power in this backend that reaches across homes, and it
// lives in these functions and nowhere else.
//
// Blocking is one person's, and quiet: the blocker stops seeing the other's
// messages and hearing their pushes, and a 1:1 between them cannot be opened.

import { ConvexError, v } from "convex/values";
import { paginationOptsValidator } from "convex/server";
import { internalMutation, mutation, query } from "./_generated/server";
import { MutationCtx, QueryCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import { Doc, Id } from "./_generated/dataModel";
import { requireHomeMember, requireUser, currentUserId } from "./lib/auth";
import { departHome } from "./lib/membership";
import { publicUser } from "./lib/users";
import {
  BLOCK_READ_CAP,
  discardFile,
  holdFile,
  isModerator,
  moderatorIds,
  releaseHolds,
  requireModerator,
} from "./lib/moderation";
import { fingerprintEndsAt, itemFingerprint } from "./lib/calendarShare";
import { refreshPreview } from "./messages";
import { detachPhoto } from "./issues";

// ---------------------------------------------------------------------------
// Shapes

const reportKind = v.union(
  v.literal("message"),
  v.literal("issuePhoto"),
  v.literal("avatar"),
  v.literal("calendarItem"),
);
const reportReason = v.union(
  v.literal("abuse"),
  v.literal("harassment"),
  v.literal("sexual"),
  v.literal("spam"),
  v.literal("other"),
);
const reportStatus = v.union(v.literal("open"), v.literal("dismissed"), v.literal("actioned"));
const reportAction = v.union(
  v.literal("deleted"),
  v.literal("removedFromHome"),
  v.literal("suspended"),
  v.literal("none"),
);

type ReportKind = "message" | "issuePhoto" | "avatar" | "calendarItem";
type ReportReason = "abuse" | "harassment" | "sexual" | "spam" | "other";

/** Reports one person may file in a rolling day. */
const DAILY_REPORT_LIMIT = 20;
const DAY_MS = 24 * 60 * 60 * 1000;
/** Longest note kept with a report. */
const MAX_NOTE = 1000;
/** How long a report waits before the moderators are reminded, once. */
const STALE_AFTER_MS = 12 * 60 * 60 * 1000;
/** Reports settled together when a thing is deleted. */
const SIBLING_CAP = 50;

const queueRow = v.object({
  _id: v.id("reports"),
  kind: reportKind,
  reason: reportReason,
  status: reportStatus,
  action: v.union(reportAction, v.null()),
  created: v.number(),
  note: v.union(v.string(), v.null()),
  home_id: v.id("homes"),
  home_name: v.union(v.string(), v.null()),
  reporter_id: v.id("users"),
  reporter_name: v.union(v.string(), v.null()),
  target_id: v.string(),
  target_user_id: v.union(v.id("users"), v.null()),
  target_user_name: v.union(v.string(), v.null()),
  /** The reported text, cut to 200 characters; the photo's title otherwise. */
  preview: v.union(v.string(), v.null()),
});

const snapshotValidator = v.object({
  text: v.optional(v.string()),
  conversation_id: v.optional(v.id("conversations")),
  message_type: v.optional(v.string()),
  sent_at: v.optional(v.number()),
  storage_id: v.optional(v.id("_storage")),
  thumb_id: v.optional(v.id("_storage")),
  issue_id: v.optional(v.id("issues")),
  issue_title: v.optional(v.string()),
  user_name: v.optional(v.string()),
  location: v.optional(v.string()),
  calendar_key: v.optional(v.string()),
  calendar_name: v.optional(v.string()),
  starts_at: v.optional(v.number()),
  ends_at: v.optional(v.number()),
});

async function nameOf(
  ctx: QueryCtx | MutationCtx,
  id: Id<"users"> | undefined,
): Promise<string | null> {
  if (!id) return null;
  const user = await ctx.db.get(id);
  return user?.name ?? null;
}

async function toRow(ctx: QueryCtx, report: Doc<"reports">) {
  const [home, reporterName, targetName] = await Promise.all([
    ctx.db.get(report.home_id),
    nameOf(ctx, report.reporter_id),
    nameOf(ctx, report.target_user_id),
  ]);
  const preview =
    report.snapshot.text?.slice(0, 200) ??
    report.snapshot.issue_title ??
    report.snapshot.location?.slice(0, 200) ??
    null;
  return {
    _id: report._id,
    kind: report.kind,
    reason: report.reason,
    status: report.status,
    action: report.action ?? null,
    created: report.created,
    note: report.note ?? null,
    home_id: report.home_id,
    home_name: home?.name ?? null,
    reporter_id: report.reporter_id,
    reporter_name: reporterName,
    target_id: report.target_id,
    target_user_id: report.target_user_id ?? null,
    target_user_name: targetName,
    preview,
  };
}

function invalid(message: string): ConvexError<{ code: string; message: string }> {
  return new ConvexError({ code: "INVALID", message });
}

function notFound(): ConvexError<{ code: string }> {
  return new ConvexError({ code: "NOT_FOUND" });
}

// ---------------------------------------------------------------------------
// Reporting

type Resolved = {
  homeId: Id<"homes">;
  /** What the report is keyed on: dedupe and the sibling sweep. */
  targetId: string;
  /** What the reporter's hide is keyed on, which is what the phone holds. */
  hideId: string;
  targetUserId?: Id<"users">;
  conversationId?: Id<"conversations">;
  snapshot: Doc<"reports">["snapshot"];
  files: (Id<"_storage"> | undefined)[];
};

/**
 * The home, if the caller is a member; otherwise the same `NOT_FOUND` a
 * missing thing answers, so a report cannot be used to learn what exists in a
 * house the caller is not in.
 */
async function memberOrNotFound(ctx: MutationCtx, homeId: Id<"homes">) {
  try {
    return await requireHomeMember(ctx, homeId);
  } catch {
    throw notFound();
  }
}

/**
 * What a report is about, checked: it exists, the caller can see it, and it
 * is not their own. The same checks the screens that draw it make.
 */
async function resolveTarget(
  ctx: MutationCtx,
  caller: Doc<"users">,
  args: {
    kind: ReportKind;
    targetId: string;
    issueId?: Id<"issues">;
    homeId?: Id<"homes">;
  },
): Promise<Resolved> {
  if (args.kind === "message") {
    const id = ctx.db.normalizeId("messages", args.targetId);
    if (!id) throw invalid("Not a message id");
    const message = await ctx.db.get(id);
    if (!message) throw notFound();
    const convo = await ctx.db.get(message.conversation_id);
    if (!convo) throw notFound();
    // In the thread, and still in its home.
    if (!(convo.participants ?? []).includes(caller._id)) throw notFound();
    await memberOrNotFound(ctx, convo.home_id);
    if (message.sender_id === caller._id) throw invalid("That is your own message");
    return {
      homeId: convo.home_id,
      targetId: id,
      hideId: id,
      targetUserId: message.sender_id,
      conversationId: convo._id,
      snapshot: {
        text: message.content,
        conversation_id: convo._id,
        message_type: message.message_type,
        sent_at: message.created ?? message._creationTime,
        storage_id: message.file,
      },
      files: [message.file],
    };
  }

  if (args.kind === "issuePhoto") {
    if (!args.issueId) throw invalid("issueId is required for a problem photo");
    const storageId = ctx.db.system.normalizeId("_storage", args.targetId);
    if (!storageId) throw invalid("Not a storage id");
    const issue = await ctx.db.get(args.issueId);
    if (!issue) throw notFound();
    await memberOrNotFound(ctx, issue.home_id);
    // The phone may hold either half of the pair; the report is about the
    // picture, so it is filed under the full-size id.
    const photos = issue.photos ?? [];
    const thumbs = issue.photo_thumbs ?? [];
    let index = photos.indexOf(storageId);
    if (index === -1) index = thumbs.indexOf(storageId);
    if (index === -1 || !photos[index]) throw notFound();
    const photo = photos[index];
    const thumb = thumbs[index] && thumbs[index] !== photo ? thumbs[index] : undefined;
    // Who attached it (`photo_uploaders`). A photo from before that was
    // recorded names nobody, so removing or suspending refuses rather than
    // landing on the problem's reporter, who may not have taken it.
    const uploader = issue.photo_uploaders?.[index] ?? undefined;
    if (uploader === caller._id) throw invalid("That is your own photo");
    return {
      homeId: issue.home_id,
      targetId: photo,
      hideId: photo,
      targetUserId: uploader,
      snapshot: {
        storage_id: photo,
        thumb_id: thumb,
        issue_id: issue._id,
        issue_title: issue.title,
      },
      files: [photo, thumb],
    };
  }

  if (args.kind === "calendarItem") {
    // A housemate's shared calendar item (calendarShare.ts), by the row id
    // the phone holds. Filed and hidden under its fingerprint (the person,
    // the calendar, the times), because every sync replaces the rows: the
    // hide and a moderator's deletion have to outlive the row id.
    const id = ctx.db.normalizeId("shared_busy", args.targetId);
    if (!id) throw invalid("Not a shared calendar item id");
    const row = await ctx.db.get(id);
    if (!row) throw notFound();
    const home = await memberOrNotFound(ctx, row.home_id);
    if (row.user_id === caller._id) throw invalid("That is your own calendar");
    // Only what the caller could see: an owner still in the home, a calendar
    // still shared, and its title and location only at `details`.
    if (!(home.members ?? []).includes(row.user_id)) throw notFound();
    const share = await ctx.db
      .query("calendar_shares")
      .withIndex("by_home_user", (q) => q.eq("home_id", row.home_id).eq("user_id", row.user_id))
      .first();
    const calendar = share?.calendars.find((c) => c.key === row.calendar_key);
    if (!calendar) throw notFound();
    const details = calendar.level === "details";
    const fingerprint = itemFingerprint(row);
    return {
      homeId: row.home_id,
      targetId: fingerprint,
      hideId: fingerprint,
      targetUserId: row.user_id,
      snapshot: {
        text: details ? row.title : undefined,
        location: details ? row.location : undefined,
        calendar_key: row.calendar_key,
        calendar_name: calendar.name,
        starts_at: row.starts_at,
        ends_at: row.ends_at,
      },
      files: [],
    };
  }

  // A face: the person must share the named home with the caller.
  if (!args.homeId) throw invalid("homeId is required for a profile photo");
  const userId = ctx.db.normalizeId("users", args.targetId);
  if (!userId) throw invalid("Not a user id");
  if (userId === caller._id) throw invalid("That is your own photo");
  const home = await memberOrNotFound(ctx, args.homeId);
  if (!(home.members ?? []).includes(userId)) throw notFound();
  const target = await ctx.db.get(userId);
  if (!target?.avatar) throw notFound();
  return {
    homeId: home._id,
    // The report is about this face, not the person: a new photo is a new
    // thing to report, and deleting this one settles only reports of it.
    targetId: target.avatar,
    // Hidden by person, because that is what the phone draws a face from.
    hideId: userId,
    targetUserId: userId,
    snapshot: { storage_id: target.avatar, user_name: target.name },
    files: [target.avatar],
  };
}

/**
 * Reports a message, a problem photo or a profile photo.
 *
 * `targetId` is the message id, the photo's storage id (with `issueId`), or
 * the user id of the face (with `homeId`, a home the two share). The thing is
 * hidden from the caller at once. Reporting the same thing again while the
 * first report is open returns that report (`already`), and does not count
 * against the daily limit of twenty. Past the limit the thing is still hidden
 * and the answer is `limited` with no report filed.
 */
export const report = mutation({
  args: {
    kind: reportKind,
    targetId: v.string(),
    reason: reportReason,
    note: v.optional(v.string()),
    issueId: v.optional(v.id("issues")),
    homeId: v.optional(v.id("homes")),
  },
  returns: v.object({
    /** `null` only with `limited`. */
    reportId: v.union(v.id("reports"), v.null()),
    status: v.union(v.literal("filed"), v.literal("already"), v.literal("limited")),
  }),
  handler: async (ctx, args) => {
    const caller = await requireUser(ctx);
    const target = await resolveTarget(ctx, caller, args);

    // Hidden first, and kept whatever happens next: the person who reported
    // it should not have to look at it again, cap or no cap.
    await hideFor(ctx, caller._id, args.kind, target.hideId, target.conversationId);

    const existing = await ctx.db
      .query("reports")
      .withIndex("by_reporter_kind_target", (q) =>
        q.eq("reporter_id", caller._id).eq("kind", args.kind).eq("target_id", target.targetId),
      )
      .order("desc")
      .first();
    if (existing && existing.status === "open") {
      return { reportId: existing._id, status: "already" as const };
    }

    const now = Date.now();
    const recent = await ctx.db
      .query("reports")
      .withIndex("by_reporter_created", (q) =>
        q.eq("reporter_id", caller._id).gte("created", now - DAY_MS).lte("created", now),
      )
      .take(DAILY_REPORT_LIMIT);
    if (recent.length >= DAILY_REPORT_LIMIT) {
      // Answered, not thrown, so the hide above is kept.
      return { reportId: null, status: "limited" as const };
    }

    const note = args.note?.trim().slice(0, MAX_NOTE);
    const reportId = await ctx.db.insert("reports", {
      reporter_id: caller._id,
      home_id: target.homeId,
      kind: args.kind,
      target_id: target.targetId,
      target_user_id: target.targetUserId,
      reason: args.reason,
      note: note ? note : undefined,
      snapshot: target.snapshot,
      status: "open",
      created: now,
    });
    for (const file of target.files) await holdFile(ctx, reportId, file);

    // To the moderators only. No `homeId`, so `notifyUsers` files nothing in
    // any household's feed; and nothing of the content itself rides in the
    // push — it is read in the queue, behind the moderator check.
    const moderators = moderatorIds(ctx);
    if (moderators.length > 0) {
      await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
        userIds: moderators,
        title: "New report",
        body: `${REASON_LABEL[args.reason]} · ${KIND_LABEL[args.kind]}`,
        category: "moderation",
        threadId: "moderation",
      });
    }
    return { reportId, status: "filed" as const };
  },
});

const REASON_LABEL: Record<ReportReason, string> = {
  abuse: "Abuse",
  harassment: "Harassment",
  sexual: "Sexual content",
  spam: "Spam",
  other: "Other",
};
const KIND_LABEL: Record<ReportKind, string> = {
  message: "a message",
  issuePhoto: "a problem photo",
  avatar: "a profile photo",
  calendarItem: "a shared calendar item",
};

async function hideFor(
  ctx: MutationCtx,
  userId: Id<"users">,
  kind: ReportKind,
  targetId: string,
  conversationId: Id<"conversations"> | undefined,
) {
  const already = await ctx.db
    .query("hidden_content")
    .withIndex("by_user_kind_target", (q) =>
      q.eq("user_id", userId).eq("kind", kind).eq("target_id", targetId),
    )
    .first();
  if (already) return;
  await ctx.db.insert("hidden_content", {
    user_id: userId,
    kind,
    target_id: targetId,
    conversation_id: conversationId,
    created: Date.now(),
  });
}

/**
 * What the caller has reported and so no longer sees, for the screens that
 * hide it on the phone: problem photos (`target_id` is the photo's storage
 * id) and faces (`target_id` is the user id). Messages are left out of
 * `messages:listByConversation` by the server and are not listed here. Up to
 * 500 of each kind.
 */
export const hiddenByMe = query({
  args: {},
  returns: v.array(v.object({ kind: reportKind, target_id: v.string() })),
  handler: async (ctx) => {
    const user = await requireUser(ctx);
    const [photos, faces] = await Promise.all(
      (["issuePhoto", "avatar"] as const).map((kind) =>
        ctx.db
          .query("hidden_content")
          .withIndex("by_user_kind_target", (q) => q.eq("user_id", user._id).eq("kind", kind))
          .take(500),
      ),
    );
    return [...photos, ...faces].map((r) => ({ kind: r.kind, target_id: r.target_id }));
  },
});

// ---------------------------------------------------------------------------
// Blocking

/** Blocks a person. Idempotent; blocking yourself is `INVALID`. */
export const block = mutation({
  args: { userId: v.id("users") },
  returns: v.object({ ok: v.boolean() }),
  handler: async (ctx, { userId }) => {
    const user = await requireUser(ctx);
    if (userId === user._id) throw invalid("You cannot block yourself");
    // Only somebody the caller knows: a member of one of their homes now, or
    // somebody in a conversation with them in one. Anybody else answers
    // exactly as an id that does not exist.
    if (!(await knowEachOther(ctx, user, userId))) throw notFound();
    const existing = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q) => q.eq("blocker_id", user._id).eq("blocked_id", userId))
      .first();
    if (existing) return { ok: true };
    const count = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q) => q.eq("blocker_id", user._id))
      .take(BLOCK_READ_CAP);
    if (count.length >= BLOCK_READ_CAP) throw new ConvexError({ code: "BLOCK_LIMIT" });
    await ctx.db.insert("blocks", { blocker_id: user._id, blocked_id: userId, created: Date.now() });
    return { ok: true };
  },
});

async function knowEachOther(
  ctx: MutationCtx,
  user: Doc<"users">,
  other: Id<"users">,
): Promise<boolean> {
  const target = await ctx.db.get(other);
  if (!target) return false;
  const mine = user.home_id ?? [];
  if ((target.home_id ?? []).some((h) => mine.includes(h))) return true;
  // Somebody who has left: a conversation in one of the caller's homes with
  // both of them in it. Household-sized reads, the ones the chat list makes.
  for (const homeId of mine) {
    const convos = await ctx.db
      .query("conversations")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .take(500);
    if (
      convos.some(
        (c) => (c.participants ?? []).includes(user._id) && (c.participants ?? []).includes(other),
      )
    ) {
      return true;
    }
  }
  return false;
}

/** Lifts a block. Idempotent. */
export const unblock = mutation({
  args: { userId: v.id("users") },
  returns: v.object({ ok: v.boolean() }),
  handler: async (ctx, { userId }) => {
    const user = await requireUser(ctx);
    const existing = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q) => q.eq("blocker_id", user._id).eq("blocked_id", userId))
      .first();
    if (existing) await ctx.db.delete(existing._id);
    return { ok: true };
  },
});

/** Everybody the caller has blocked, newest first. */
export const blockedByMe = query({
  args: {},
  returns: v.array(
    v.object({
      user_id: v.id("users"),
      name: v.union(v.string(), v.null()),
      avatar_url: v.union(v.string(), v.null()),
      created: v.number(),
    }),
  ),
  handler: async (ctx) => {
    const user = await requireUser(ctx);
    const rows = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q) => q.eq("blocker_id", user._id))
      .take(BLOCK_READ_CAP);
    const out = await Promise.all(
      rows.map(async (r) => {
        const doc = await ctx.db.get(r.blocked_id);
        const pub = doc ? await publicUser(ctx, doc) : null;
        return {
          user_id: r.blocked_id,
          name: pub?.name ?? null,
          avatar_url: pub?.avatar_url ?? null,
          created: r.created,
        };
      }),
    );
    return out.sort((a, b) => b.created - a.created);
  },
});

// ---------------------------------------------------------------------------
// The queue (moderators only)

/** Whether the caller is a moderator, so the phone knows to draw the queue. */
export const amModerator = query({
  args: {},
  returns: v.boolean(),
  handler: async (ctx) => {
    const uid = await currentUserId(ctx);
    return uid ? isModerator(uid) : false;
  },
});

/** Open reports, newest first, a page at a time. `FORBIDDEN` for anyone else. */
export const queue = query({
  args: { paginationOpts: paginationOptsValidator },
  returns: v.object({
    page: v.array(queueRow),
    isDone: v.boolean(),
    continueCursor: v.string(),
  }),
  handler: async (ctx, { paginationOpts }) => {
    await requireModerator(ctx);
    const result = await ctx.db
      .query("reports")
      .withIndex("by_status_created", (q) => q.eq("status", "open"))
      .order("desc")
      .paginate({ ...paginationOpts, numItems: Math.min(Math.max(paginationOpts.numItems, 1), 50) });
    return {
      page: await Promise.all(result.page.map((r) => toRow(ctx, r))),
      isDone: result.isDone,
      continueCursor: result.continueCursor,
    };
  },
});

/** One report in full: the snapshot, the files, and where things stand now. */
export const detail = query({
  args: { reportId: v.id("reports") },
  returns: v.union(
    v.null(),
    v.object({
      report: queueRow,
      snapshot: snapshotValidator,
      /** The reported file (photo, face, or a message's image), if any. */
      file_url: v.union(v.string(), v.null()),
      thumb_url: v.union(v.string(), v.null()),
      /** Whether the reported thing is still there to delete. */
      still_exists: v.boolean(),
      /** Whether the reported person is still in the home. */
      target_in_home: v.boolean(),
      target_chat_suspended: v.boolean(),
      resolved_by_name: v.union(v.string(), v.null()),
      resolved_at: v.union(v.number(), v.null()),
    }),
  ),
  handler: async (ctx, { reportId }) => {
    await requireModerator(ctx);
    const report = await ctx.db.get(reportId);
    if (!report) return null;
    const { snapshot } = report;
    const [row, fileUrl, thumbUrl, home, target, stillExists, resolvedByName] =
      await Promise.all([
        toRow(ctx, report),
        snapshot.storage_id ? ctx.storage.getUrl(snapshot.storage_id) : Promise.resolve(null),
        snapshot.thumb_id ? ctx.storage.getUrl(snapshot.thumb_id) : Promise.resolve(null),
        ctx.db.get(report.home_id),
        report.target_user_id ? ctx.db.get(report.target_user_id) : Promise.resolve(null),
        contentStillThere(ctx, report),
        nameOf(ctx, report.resolved_by),
      ]);
    return {
      report: row,
      snapshot,
      file_url: fileUrl,
      thumb_url: thumbUrl,
      still_exists: stillExists,
      target_in_home: Boolean(
        report.target_user_id && home && (home.members ?? []).includes(report.target_user_id),
      ),
      target_chat_suspended: target ? target.chat_suspended_at !== undefined : false,
      resolved_by_name: resolvedByName,
      resolved_at: report.resolved_at ?? null,
    };
  },
});

async function contentStillThere(
  ctx: QueryCtx | MutationCtx,
  report: Doc<"reports">,
): Promise<boolean> {
  if (report.kind === "message") {
    const id = ctx.db.normalizeId("messages", report.target_id);
    return Boolean(id && (await ctx.db.get(id)));
  }
  if (report.kind === "issuePhoto") {
    const issue = report.snapshot.issue_id ? await ctx.db.get(report.snapshot.issue_id) : null;
    return Boolean(issue && (issue.photos ?? []).some((p) => p === report.target_id));
  }
  if (report.kind === "calendarItem") {
    return (await sharedItemRows(ctx, report)).length > 0;
  }
  // A face's report is keyed on the photo; the person is `target_user_id`.
  const user = report.target_user_id ? await ctx.db.get(report.target_user_id) : null;
  return Boolean(user?.avatar && user.avatar === report.target_id);
}

/**
 * The shared rows a `calendarItem` report is about: the reported person's
 * rows in that calendar with the reported times. Normally one; a sync may
 * have written the same item again under a new id.
 */
async function sharedItemRows(
  ctx: QueryCtx | MutationCtx,
  report: Doc<"reports">,
): Promise<Doc<"shared_busy">[]> {
  const { calendar_key, starts_at, ends_at } = report.snapshot;
  const userId = report.target_user_id;
  if (!userId || calendar_key === undefined || starts_at === undefined || ends_at === undefined) {
    return [];
  }
  const rows = await ctx.db
    .query("shared_busy")
    .withIndex("by_user_home_calendar_ends", (q) =>
      q
        .eq("user_id", userId)
        .eq("home_id", report.home_id)
        .eq("calendar_key", calendar_key)
        .eq("ends_at", ends_at),
    )
    .take(20);
  return rows.filter((r) => r.starts_at === starts_at);
}

// ---------------------------------------------------------------------------
// Decisions (moderators only, each written on the report)

/**
 * The report, unless it names the moderator deciding it: nobody rules on a
 * report about themselves. `FORBIDDEN`; the other moderator decides it.
 */
async function loadReport(
  ctx: MutationCtx,
  reportId: Id<"reports">,
  moderator: Doc<"users">,
) {
  const report = await ctx.db.get(reportId);
  if (!report) throw notFound();
  if (report.target_user_id === moderator._id) throw new ConvexError({ code: "FORBIDDEN" });
  return report;
}

async function settle(
  ctx: MutationCtx,
  report: Doc<"reports">,
  moderator: Id<"users">,
  status: "dismissed" | "actioned",
  action: "deleted" | "removedFromHome" | "suspended" | "none",
) {
  await ctx.db.patch(report._id, {
    status,
    action,
    resolved_by: moderator,
    resolved_at: Date.now(),
  });
  await releaseHolds(ctx, report._id);
}

const decision = v.object({ ok: v.boolean(), status: reportStatus, action: reportAction });

/** Nothing to do. Only an open report can be dismissed; otherwise a no-op. */
export const dismiss = mutation({
  args: { reportId: v.id("reports") },
  returns: decision,
  handler: async (ctx, { reportId }) => {
    const moderator = await requireModerator(ctx);
    const report = await loadReport(ctx, reportId, moderator);
    if (report.status !== "open") {
      return { ok: true, status: report.status, action: report.action ?? "none" };
    }
    await settle(ctx, report, moderator._id, "dismissed", "none");
    return { ok: true, status: "dismissed" as const, action: "none" as const };
  },
});

/**
 * Deletes the reported thing through the same code a member's delete runs:
 * the message (and the thread's preview), the problem photo and its thumbnail,
 * or the face. Every open report about the same thing is settled with it.
 * `removed` is false when it had already gone.
 */
export const deleteContent = mutation({
  args: { reportId: v.id("reports") },
  returns: v.object({ ok: v.boolean(), removed: v.boolean() }),
  handler: async (ctx, { reportId }) => {
    const moderator = await requireModerator(ctx);
    const report = await loadReport(ctx, reportId, moderator);
    let removed = false;

    if (report.kind === "message") {
      const id = ctx.db.normalizeId("messages", report.target_id);
      const message = id ? await ctx.db.get(id) : null;
      if (message) {
        await ctx.db.delete(message._id);
        await refreshPreview(ctx, message.conversation_id, message._id);
        // Its picture too; held by this report, so it goes when it is settled.
        await discardFile(ctx, message.file);
        removed = true;
      }
    } else if (report.kind === "issuePhoto") {
      const issue = report.snapshot.issue_id ? await ctx.db.get(report.snapshot.issue_id) : null;
      const storageId = ctx.db.system.normalizeId("_storage", report.target_id);
      if (issue && storageId) {
        removed = (await detachPhoto(ctx, issue, storageId)).removed;
      }
    } else if (report.kind === "calendarItem") {
      // The row goes now; the owner's next sync cannot write it back, because
      // `calendarShare:replace` drops any item whose fingerprint has an
      // actioned `deleted` report (this one, once settled below).
      const rows = await sharedItemRows(ctx, report);
      await Promise.all(rows.map((r) => ctx.db.delete(r._id)));
      removed = rows.length > 0;
    } else {
      const user = report.target_user_id ? await ctx.db.get(report.target_user_id) : null;
      // Only the face that was reported (`target_id`). A newer one is not
      // this report's.
      if (user?.avatar && user.avatar === report.target_id) {
        await ctx.db.patch(user._id, { avatar: undefined, updated: Date.now() });
        await discardFile(ctx, user.avatar);
        removed = true;
      }
    }

    const siblings = await ctx.db
      .query("reports")
      .withIndex("by_kind_target_status", (q) =>
        q.eq("kind", report.kind).eq("target_id", report.target_id).eq("status", "open"),
      )
      .take(SIBLING_CAP);
    for (const r of siblings) {
      if (r._id !== report._id) await settle(ctx, r, moderator._id, "actioned", "deleted");
    }
    await settle(ctx, report, moderator._id, "actioned", "deleted");
    return { ok: true, removed };
  },
});

/**
 * Takes the reported person out of the report's home, exactly as
 * `homes:removeMember` does (`departHome`, then a new invite code). Refused
 * with `LAST_MEMBER` when they are the only one left, because that would
 * delete the home. `removed` is false when they had already gone.
 */
export const removeFromHome = mutation({
  args: { reportId: v.id("reports") },
  returns: v.object({ ok: v.boolean(), removed: v.boolean() }),
  handler: async (ctx, { reportId }) => {
    const moderator = await requireModerator(ctx);
    const report = await loadReport(ctx, reportId, moderator);
    const userId = report.target_user_id;
    if (!userId) throw invalid("This report names nobody to remove");
    const home = await ctx.db.get(report.home_id);
    if (!home) throw notFound();

    // Every open report about this person in this home is answered by it.
    const settleAll = async () => {
      const others = await ctx.db
        .query("reports")
        .withIndex("by_target_user_home_status", (q) =>
          q.eq("target_user_id", userId).eq("home_id", home._id).eq("status", "open"),
        )
        .take(SIBLING_CAP);
      for (const r of others) {
        if (r._id !== report._id) await settle(ctx, r, moderator._id, "actioned", "removedFromHome");
      }
      await settle(ctx, report, moderator._id, "actioned", "removedFromHome");
    };

    if (!(home.members ?? []).includes(userId)) {
      await settleAll();
      return { ok: true, removed: false };
    }
    if ((home.members ?? []).length <= 1) throw new ConvexError({ code: "LAST_MEMBER" });

    await departHome(ctx, home, userId);
    // A new invite code, or they could walk straight back in.
    await ctx.db.patch(home._id, { invite_code: crypto.randomUUID().toUpperCase() });
    await settleAll();

    const homeName = home.name ?? "Your home";
    // The person removed hears it as a push only, never a feed row.
    await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
      userIds: [userId],
      title: homeName,
      body: "You were removed from the home",
      category: "home",
    });
    // And the house is told, so a removal is never silent. No actor: it was
    // not anybody living there.
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: home._id,
      title: homeName,
      body: "Someone was removed from the home. The invite code has changed.",
      category: "home",
    });
    return { ok: true, removed: true };
  },
});

/**
 * Stops the reported person writing in chat, in every home: `messages:send`
 * and `edit`, `conversations:create` and `rename`, and a chat poll's
 * `create` and `addItem` refuse with `CHAT_SUSPENDED`. Reading stays open.
 */
export const suspendChat = mutation({
  args: { reportId: v.id("reports") },
  returns: v.object({ ok: v.boolean(), suspendedAt: v.number() }),
  handler: async (ctx, { reportId }) => {
    const moderator = await requireModerator(ctx);
    const report = await loadReport(ctx, reportId, moderator);
    if (!report.target_user_id) throw invalid("This report names nobody to suspend");
    const user = await ctx.db.get(report.target_user_id);
    if (!user) throw notFound();
    const suspendedAt = user.chat_suspended_at ?? Date.now();
    if (user.chat_suspended_at === undefined) {
      await ctx.db.patch(user._id, { chat_suspended_at: suspendedAt });
    }
    await settle(ctx, report, moderator._id, "actioned", "suspended");
    return { ok: true, suspendedAt };
  },
});

/** Lets a suspended person write in chat again. Idempotent. */
export const unsuspendChat = mutation({
  args: { userId: v.id("users") },
  returns: v.object({ ok: v.boolean() }),
  handler: async (ctx, { userId }) => {
    const moderator = await requireModerator(ctx);
    // Nobody lifts their own suspension.
    if (userId === moderator._id) throw new ConvexError({ code: "FORBIDDEN" });
    const user = await ctx.db.get(userId);
    if (!user) throw notFound();
    if (user.chat_suspended_at !== undefined) {
      await ctx.db.patch(userId, { chat_suspended_at: undefined });
    }
    return { ok: true };
  },
});

// ---------------------------------------------------------------------------
// The reminder

/**
 * Reminds the moderators of reports open for more than twelve hours, once per
 * report: each is stamped `nudged_at` as it is counted, so a run never
 * repeats one. One push per run however many there are. With no moderators
 * configured nothing is stamped, so naming one later still hears of them.
 */
export const nudgeStale = internalMutation({
  args: {},
  returns: v.object({ nudged: v.number() }),
  handler: async (ctx) => {
    const moderators = moderatorIds(ctx);
    if (moderators.length === 0) return { nudged: 0 };
    const cutoff = Date.now() - STALE_AFTER_MS;
    const stale = await ctx.db
      .query("reports")
      .withIndex("by_status_nudged_created", (q) =>
        q.eq("status", "open").eq("nudged_at", undefined).lte("created", cutoff),
      )
      .take(100);
    if (stale.length === 0) return { nudged: 0 };
    const now = Date.now();
    await Promise.all(stale.map((r) => ctx.db.patch(r._id, { nudged_at: now })));
    await ctx.scheduler.runAfter(0, internal.push.notifyUsers, {
      userIds: moderators,
      title: "Reports waiting",
      body:
        stale.length === 1
          ? "A report has been waiting over 12 hours"
          : `${stale.length} reports have been waiting over 12 hours`,
      category: "moderation",
      threadId: "moderation",
    });
    return { nudged: stale.length };
  },
});

// ---------------------------------------------------------------------------
// Retention

/**
 * How long a settled report is kept: twelve months after `resolved_at`, as
 * the privacy policy says. An open report is never deleted, however old.
 */
const REPORT_RETENTION_MS = 365 * DAY_MS;
/** Reports deleted per run of `sweepReports`. */
const RETENTION_BATCH = 100;
/** Runs one day's sweep may chain before it stops and says so. */
const RETENTION_MAX_ROUNDS = 50;

/**
 * Deletes settled reports (dismissed or actioned) resolved more than twelve
 * months ago, releasing whatever they still hold first (`releaseHolds`), so a
 * file whose deletion was deferred for the report goes with it. Settling
 * already releases a report's holds; this is the belt to that brace.
 *
 * A hundred per run, chaining itself while a full batch came back, up to
 * fifty runs a day. Idempotent: a rerun only finds less. The daily cron
 * (`crons.ts`) starts it at round 0.
 */
export const sweepReports = internalMutation({
  args: { round: v.optional(v.number()) },
  returns: v.object({ deleted: v.number(), more: v.boolean() }),
  handler: async (ctx, { round }) => {
    const n = round ?? 0;
    const cutoff = Date.now() - REPORT_RETENTION_MS;
    const settled: Doc<"reports">[] = [];
    for (const status of ["dismissed", "actioned"] as const) {
      const room = RETENTION_BATCH - settled.length;
      if (room <= 0) break;
      const rows = await ctx.db
        .query("reports")
        .withIndex("by_status_resolved", (q) =>
          // `gte(0)` keeps a settled report with no `resolved_at` (none
          // exists; settling always stamps it) out of the range, rather than
          // treating "never stamped" as "long ago".
          q.eq("status", status).gte("resolved_at", 0).lte("resolved_at", cutoff),
        )
        .take(room);
      settled.push(...rows);
    }

    for (const report of settled) {
      await releaseHolds(ctx, report._id);
      // `releaseHolds` reads ten at a time; a report holds at most two (the
      // file and its thumbnail), so one pass is all of them. Checked anyway,
      // so a report is never deleted from under a hold.
      const left = await ctx.db
        .query("report_holds")
        .withIndex("by_report", (q) => q.eq("report_id", report._id))
        .first();
      if (left) continue;
      await ctx.db.delete(report._id);
    }

    const more = settled.length === RETENTION_BATCH;
    if (settled.length > 0) {
      console.log(`moderation:sweepReports round ${n}: deleted ${settled.length}${more ? ", more to go" : ""}`);
    }
    if (more) {
      if (n + 1 >= RETENTION_MAX_ROUNDS) {
        console.error(`moderation:sweepReports stopped after ${n + 1} rounds; tomorrow's run continues`);
      } else {
        await ctx.scheduler.runAfter(0, internal.moderation.sweepReports, { round: n + 1 });
      }
    }
    return { deleted: settled.length, more };
  },
});

/** `hidden_content` rows looked at per run of `sweepHidden`. */
const HIDDEN_BATCH = 100;
/** Runs one week's sweep may chain: 20,000 rows. */
const HIDDEN_MAX_ROUNDS = 200;

/**
 * Drops `hidden_content` rows whose target no longer exists: a message that
 * was deleted, a problem photo or face whose file is gone. Nothing would ever
 * show them again, and the thread reads (`by_user_conversation`) would keep
 * paying for them.
 *
 * `target_id` is a string and has no index of its own, so this walks the
 * table a page at a time — a hundred rows and a hundred point reads per run,
 * chaining by cursor. The table is one row per thing one person reported, so
 * a weekly walk of all of it is cheap. A held file still exists, so the hide
 * for a reported photo stays while the report does.
 */
export const sweepHidden = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())), round: v.optional(v.number()) },
  returns: v.object({ checked: v.number(), deleted: v.number(), more: v.boolean() }),
  handler: async (ctx, { cursor, round }) => {
    const n = round ?? 0;
    const page = await ctx.db
      .query("hidden_content")
      .paginate({ numItems: HIDDEN_BATCH, cursor: cursor ?? null });
    let deleted = 0;
    for (const row of page.page) {
      let exists: boolean;
      if (row.kind === "message") {
        const id = ctx.db.normalizeId("messages", row.target_id);
        exists = id !== null && (await ctx.db.get(id)) !== null;
      } else if (row.kind === "calendarItem") {
        // Keyed on a fingerprint, not a row (lib/calendarShare.ts): it is
        // needed until the item has ended and the sweep has taken its rows.
        const endsAt = fingerprintEndsAt(row.target_id);
        exists = endsAt !== null && endsAt > Date.now() - 2 * DAY_MS;
      } else {
        const id = ctx.db.system.normalizeId("_storage", row.target_id);
        exists = id !== null && (await ctx.db.system.get(id)) !== null;
      }
      if (!exists) {
        await ctx.db.delete(row._id);
        deleted += 1;
      }
    }
    const more = !page.isDone;
    if (deleted > 0) console.log(`moderation:sweepHidden round ${n}: deleted ${deleted} of ${page.page.length}`);
    if (more) {
      if (n + 1 >= HIDDEN_MAX_ROUNDS) {
        console.error(`moderation:sweepHidden stopped after ${n + 1} rounds`);
      } else {
        await ctx.scheduler.runAfter(0, internal.moderation.sweepHidden, {
          cursor: page.continueCursor,
          round: n + 1,
        });
      }
    }
    return { checked: page.page.length, deleted, more };
  },
});
