// One shape for "a user, on the wire".
import { Doc, Id } from "../_generated/dataModel";
import { QueryCtx, MutationCtx } from "../_generated/server";

/** A user document plus the one field the phone cannot work out for itself. */
export type PublicUser = Doc<"users"> & { avatar_url: string | null };

/**
 * Resolves `avatar` into a URL the client can actually load.
 *
 * A storage id is not an address — `ctx.storage.getUrl` is the only thing that
 * can turn one into a request — so a payload carrying the id alone means every
 * screen that draws a face has to go back to the server for the URL, once per
 * person per screen. Resolving it here costs the read that was happening
 * anyway and makes an avatar travel with the user it belongs to.
 *
 * Both halves are kept, deliberately, for the same reason `issues.photoRefs`
 * keeps both: the id is the identity — it is what a write names — and the URL
 * is only how the bytes are fetched. A signed storage URL is not required to
 * contain the id, so working one back out of the other is a guess.
 *
 * A file that has gone resolves to `null` rather than to a broken image, and
 * the initials take over on the client.
 */
export async function publicUser(
  ctx: QueryCtx | MutationCtx,
  doc: Doc<"users">,
): Promise<PublicUser> {
  return {
    ...doc,
    avatar_url: doc.avatar ? await ctx.storage.getUrl(doc.avatar) : null,
  };
}

/** `publicUser` over a list, resolving the URLs concurrently. */
export async function publicUsers(
  ctx: QueryCtx | MutationCtx,
  docs: Doc<"users">[],
): Promise<PublicUser[]> {
  return await Promise.all(docs.map((doc) => publicUser(ctx, doc)));
}

/**
 * Drops a stored avatar, tolerating one that is already gone.
 *
 * Deleted rather than orphaned, on the same terms as `issues.removePhoto`: a
 * file nothing points at is a file nothing will ever point at again, and
 * storage that only grows is storage somebody eventually pays for. Replacing a
 * photo is the common case and it is exactly the case that leaks.
 *
 * Swallowing the failure is the point of the wrapper. The user's new face is
 * already in the document by the time this runs, and refusing the whole
 * transaction because a file that was supposed to disappear had disappeared
 * already would roll that back over nothing.
 */
export async function discardAvatar(
  ctx: MutationCtx,
  storageId: Id<"_storage"> | undefined | null,
): Promise<void> {
  if (!storageId) return;
  try {
    await ctx.storage.delete(storageId);
  } catch {
    // Already gone. Nothing to reclaim and nothing to report.
  }
}
