// Reports, blocks and who may read them.
//
// Moderators are not admins, on purpose. An admin writes the changelog, which
// is public by nature; a moderator reads what was reported out of somebody's
// private chat. Two lists, so being trusted with one is never being trusted
// with the other:
//
//   npx convex env set MODERATOR_USER_IDS "jh7abc...,jh7def..."
//
// By id only. Unset is nobody — reports are still filed and kept, nobody is
// told and nobody can read them until a moderator is named.

import { ConvexError } from "convex/values";
import { Doc, Id } from "../_generated/dataModel";
import { QueryCtx, MutationCtx } from "../_generated/server";
import { requireUser } from "./auth";

/** The ids in `MODERATOR_USER_IDS`, as strings. */
function configuredModeratorIds(): Set<string> {
  const ids = new Set<string>();
  for (const raw of (process.env.MODERATOR_USER_IDS ?? "").split(",")) {
    const id = raw.trim();
    if (id) ids.add(id);
  }
  return ids;
}

/** Whether this user id is a moderator. */
export function isModerator(userId: Id<"users"> | string): boolean {
  return configuredModeratorIds().has(userId);
}

/** The moderators that exist as users on this deployment. */
export function moderatorIds(ctx: QueryCtx | MutationCtx): Id<"users">[] {
  const out: Id<"users">[] = [];
  for (const raw of configuredModeratorIds()) {
    const id = ctx.db.normalizeId("users", raw);
    if (id) out.push(id);
  }
  return out;
}

/** The calling moderator, or `FORBIDDEN` — never data. */
export async function requireModerator(
  ctx: QueryCtx | MutationCtx,
): Promise<Doc<"users">> {
  const user = await requireUser(ctx);
  if (!isModerator(user._id)) throw new ConvexError({ code: "FORBIDDEN" });
  return user;
}

/** Refuses chat writing for a person a moderator has suspended. */
export function requireChatAllowed(user: Doc<"users">): void {
  if (user.chat_suspended_at !== undefined) {
    throw new ConvexError({ code: "CHAT_SUSPENDED" });
  }
}

// ---------------------------------------------------------------------------
// Blocks

/**
 * The most blocks one person's reads look at. A household app; anyone near
 * this has bigger problems than a list that stops growing.
 */
export const BLOCK_READ_CAP = 200;

/** Everybody `userId` has blocked. One indexed range. */
export async function blockedBy(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<Set<Id<"users">>> {
  const rows = await ctx.db
    .query("blocks")
    .withIndex("by_blocker_blocked", (q) => q.eq("blocker_id", userId))
    .take(BLOCK_READ_CAP);
  return new Set(rows.map((r) => r.blocked_id));
}

/** Everybody who has blocked `userId`. One indexed range. */
export async function blockersOf(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<Set<Id<"users">>> {
  const rows = await ctx.db
    .query("blocks")
    .withIndex("by_blocked", (q) => q.eq("blocked_id", userId))
    .take(BLOCK_READ_CAP);
  return new Set(rows.map((r) => r.blocker_id));
}

/** Whether either of the two has blocked the other. Two point reads. */
export async function blockedEitherWay(
  ctx: QueryCtx | MutationCtx,
  a: Id<"users">,
  b: Id<"users">,
): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q) => q.eq("blocker_id", a).eq("blocked_id", b))
      .first(),
    ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q) => q.eq("blocker_id", b).eq("blocked_id", a))
      .first(),
  ]);
  return ab !== null || ba !== null;
}

// ---------------------------------------------------------------------------
// Files a report still needs

/**
 * Deletes a stored file unless a report holds it, tolerating one that is
 * already gone.
 *
 * Every path that deletes a stored file goes through here (`issues.removePhoto`,
 * `discardAvatar`), so removing a reported photo — by its owner, by a
 * moderator, by deleting an account — never destroys the evidence while the
 * report is open. A held file is marked instead, and `releaseHolds` deletes it
 * once nothing holds it any more.
 */
export async function discardFile(
  ctx: MutationCtx,
  storageId: Id<"_storage"> | undefined | null,
): Promise<void> {
  if (!storageId) return;
  const holds = await ctx.db
    .query("report_holds")
    .withIndex("by_storage", (q) => q.eq("storage_id", storageId))
    .take(50);
  if (holds.length > 0) {
    await Promise.all(
      holds
        .filter((h) => !h.deferred_delete)
        .map((h) => ctx.db.patch(h._id, { deferred_delete: true })),
    );
    return;
  }
  try {
    await ctx.storage.delete(storageId);
  } catch {
    // Already gone. Nothing to reclaim and nothing to report.
  }
}

/** Holds a file for a report. Idempotent per report and file. */
export async function holdFile(
  ctx: MutationCtx,
  reportId: Id<"reports">,
  storageId: Id<"_storage"> | undefined,
): Promise<void> {
  if (!storageId) return;
  const existing = await ctx.db
    .query("report_holds")
    .withIndex("by_report", (q) => q.eq("report_id", reportId))
    .take(10);
  if (existing.some((h) => h.storage_id === storageId)) return;
  await ctx.db.insert("report_holds", { report_id: reportId, storage_id: storageId });
}

/**
 * Lets go of a resolved report's files. A file whose deletion was deferred,
 * and that no other report still holds, is deleted now.
 */
export async function releaseHolds(
  ctx: MutationCtx,
  reportId: Id<"reports">,
): Promise<void> {
  const holds = await ctx.db
    .query("report_holds")
    .withIndex("by_report", (q) => q.eq("report_id", reportId))
    .take(10);
  for (const hold of holds) {
    await ctx.db.delete(hold._id);
    const others = await ctx.db
      .query("report_holds")
      .withIndex("by_storage", (q) => q.eq("storage_id", hold.storage_id))
      .take(50);
    if (others.length > 0) {
      // Still evidence for somebody else; carry the pending delete over.
      if (hold.deferred_delete) {
        await Promise.all(
          others
            .filter((o) => !o.deferred_delete)
            .map((o) => ctx.db.patch(o._id, { deferred_delete: true })),
        );
      }
      continue;
    }
    if (hold.deferred_delete) {
      try {
        await ctx.storage.delete(hold.storage_id);
      } catch {
        // Already gone.
      }
    }
  }
}
