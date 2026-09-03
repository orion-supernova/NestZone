// Shared auth/permission helpers used by the domain functions.
import { getAuthUserId } from "@convex-dev/auth/server";
import { Doc, Id } from "../_generated/dataModel";
import { QueryCtx, MutationCtx } from "../_generated/server";

/** Returns the current authenticated user doc, or throws. */
export async function requireUser(
  ctx: QueryCtx | MutationCtx,
): Promise<Doc<"users">> {
  const uid = await getAuthUserId(ctx);
  if (!uid) throw new Error("Not authenticated");
  const user = await ctx.db.get(uid);
  if (!user) throw new Error("Authenticated user not found");
  return user;
}

/** Returns current user id or null (for optional-auth queries). */
export async function currentUserId(
  ctx: QueryCtx | MutationCtx,
): Promise<Id<"users"> | null> {
  return await getAuthUserId(ctx);
}

/** Assert the user is a member of `homeId` (via homes.members). Throws otherwise. */
export async function requireHomeMember(
  ctx: QueryCtx | MutationCtx,
  homeId: Id<"homes">,
): Promise<Doc<"homes">> {
  const user = await requireUser(ctx);
  const home = await ctx.db.get(homeId);
  if (!home) throw new Error("Home not found");
  const members = home.members ?? [];
  if (!members.some((m) => m === user._id)) {
    throw new Error("Not a member of this home");
  }
  return home;
}

/**
 * Assert the caller is a member of the home a document belongs to.
 *
 * Prefer this over `if (doc.home_id) await requireHomeMember(...)`: every
 * `home_id` is `v.optional` in the schema (PocketBase allowed empty relations),
 * so the conditional form silently skips BOTH the membership check and
 * authentication for any document that has no home. A document that isn't
 * attached to a home must be unreachable, not unprotected.
 */
export async function requireDocHome(
  ctx: QueryCtx | MutationCtx,
  doc: { home_id?: Id<"homes"> },
  label: string,
): Promise<Doc<"homes">> {
  if (!doc.home_id) throw new Error(`${label} is not attached to a home`);
  return await requireHomeMember(ctx, doc.home_id);
}
