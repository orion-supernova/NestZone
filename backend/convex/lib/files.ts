// Who a stored file belongs to.
//
// A storage id is not a secret: it travels inside every signed URL the app
// draws. Before claims, any function that took a client-supplied
// `Id<"_storage">` stored it unchecked, so a member who learned another
// house's id could attach it to a row of their own and then delete that row
// (`issues:removePhoto`, `messages:remove`, emptying a house) — deleting
// somebody else's photo, or somebody's face.
//
// A claim is written the first time a file is attached to anything, and names
// the house it was attached in (or, for an avatar, the person). Every later
// attach must be in the same house (same person for an avatar), or it is
// refused as `NOT_FOUND`, the same answer a file that does not exist gets, so
// a refusal says nothing about whether the id is real. An honest client
// attaches only what it just uploaded, so it never sees the refusal.
//
// A claim is not a use: `storage:reapReport` does not count it as a
// reference, and the claim goes when its file is actually deleted
// (`discardFile`, `releaseHolds`, the reaper).

import { ConvexError } from "convex/values";
import { Id } from "../_generated/dataModel";
import { MutationCtx } from "../_generated/server";

export type FileKind =
  | "issue_photo"
  | "issue_thumb"
  | "message"
  | "avatar"
  | "task_image"
  | "note_image"
  | "recipe_image";

export type FileOwner = {
  /** The house the row lives in. Absent for an avatar, which is a person's. */
  homeId?: Id<"homes">;
  /** Who attached it. For an avatar, whose face it is. */
  userId: Id<"users">;
  kind: FileKind;
};

function notFound(): ConvexError<{ code: string }> {
  return new ConvexError({ code: "NOT_FOUND" });
}

/**
 * Lets `owner` attach `storageId`, claiming it on first attach.
 *
 * Refuses (`NOT_FOUND`) a file that does not exist, and a file already
 * claimed by another house — or, for an avatar, by another person or by any
 * house. Idempotent: attaching the same file again in the same house is a
 * no-op.
 */
export async function claimFile(
  ctx: MutationCtx,
  storageId: Id<"_storage">,
  owner: FileOwner,
): Promise<void> {
  const claim = await ctx.db
    .query("file_claims")
    .withIndex("by_storage", (q) => q.eq("storage_id", storageId))
    .first();
  if (claim) {
    const same = owner.homeId !== undefined
      ? claim.home_id === owner.homeId
      : claim.home_id === undefined && claim.user_id === owner.userId;
    if (!same) throw notFound();
    return;
  }
  const file = await ctx.db.system.get("_storage", storageId);
  if (!file) throw notFound();
  await ctx.db.insert("file_claims", {
    storage_id: storageId,
    ...(owner.homeId !== undefined ? { home_id: owner.homeId } : {}),
    user_id: owner.userId,
    kind: owner.kind,
    created: Date.now(),
  });
}

/** `claimFile` for each id, skipping repeats. */
export async function claimFiles(
  ctx: MutationCtx,
  storageIds: readonly (Id<"_storage"> | undefined)[],
  owner: FileOwner,
): Promise<void> {
  const seen = new Set<Id<"_storage">>();
  for (const id of storageIds) {
    if (!id || seen.has(id)) continue;
    seen.add(id);
    await claimFile(ctx, id, owner);
  }
}

/**
 * Whether `storageId` is claimed by `homeId`. A file nobody has claimed is
 * not the house's to delete: it predates claims and the backfill has not
 * reached it, or it was never attached through a checked path.
 */
export async function claimedByHome(
  ctx: MutationCtx,
  storageId: Id<"_storage">,
  homeId: Id<"homes">,
): Promise<boolean> {
  const claim = await ctx.db
    .query("file_claims")
    .withIndex("by_storage", (q) => q.eq("storage_id", storageId))
    .first();
  return claim !== null && claim.home_id === homeId;
}

/** Forgets every claim on a file that has just been deleted. */
export async function dropClaims(
  ctx: MutationCtx,
  storageId: Id<"_storage">,
): Promise<void> {
  const claims = await ctx.db
    .query("file_claims")
    .withIndex("by_storage", (q) => q.eq("storage_id", storageId))
    .take(10);
  await Promise.all(claims.map((c) => ctx.db.delete(c._id)));
}
