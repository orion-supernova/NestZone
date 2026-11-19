// One shape for "a user, on the wire".
import { Doc, Id } from "../_generated/dataModel";
import { QueryCtx, MutationCtx } from "../_generated/server";
import { discardFile } from "./moderation";

/**
 * The caller's own user document, plus the one field the phone cannot work out
 * for itself. Only ever for the person themselves (`users:me` and the writes
 * that answer with the caller's own profile): it carries their email, phone and
 * every bookkeeping field.
 */
export type OwnUser = Omit<Doc<"users">, "chat_suspended_at"> & { avatar_url: string | null };

/**
 * Another person, as a housemate (or anyone else who is not them) may see them.
 *
 * An allow-list, never a deny-list: a field added to `users` tomorrow stays on
 * the server until somebody decides it belongs here. Email and phone go to the
 * person themselves and nobody else (`ownUser`). Every app build decodes
 * `email`, `home_id`, `created` and `updated` with `decodeIfPresent`, so
 * leaving them out degrades to "absent", never to a blank screen; a person
 * with no `name` is drawn as "Someone" rather than their email's local part.
 */
export type PublicUser = {
  _id: Id<"users">;
  _creationTime: number;
  name?: string;
  /** The photo's storage id: its identity, what a report names. */
  avatar?: Id<"_storage">;
  avatar_url: string | null;
};

async function avatarUrl(ctx: QueryCtx | MutationCtx, doc: Doc<"users">) {
  return doc.avatar ? await ctx.storage.getUrl(doc.avatar) : null;
}

/** The caller's own document. Never pass anybody else's through this. */
export async function ownUser(
  ctx: QueryCtx | MutationCtx,
  doc: Doc<"users">,
): Promise<OwnUser> {
  // A suspension is between the person and the moderators, never on the
  // wire, not even to them.
  const { chat_suspended_at: _suspended, ...rest } = doc;
  return { ...rest, avatar_url: await avatarUrl(ctx, doc) };
}

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
  const out: PublicUser = {
    _id: doc._id,
    _creationTime: doc._creationTime,
    avatar_url: await avatarUrl(ctx, doc),
  };
  if (doc.name !== undefined) out.name = doc.name;
  if (doc.avatar !== undefined) out.avatar = doc.avatar;
  return out;
}

/**
 * The email for a row naming `doc`, when the row goes to `caller`: theirs if
 * it is them, `null` for anybody else. For the screens whose rows carry a name
 * and an email rather than a whole user (contributions, the ledger, the
 * archive), which old builds decode with the key present.
 */
export function emailFor(
  caller: Doc<"users">,
  doc: Doc<"users"> | null | undefined,
): string | null {
  return doc && doc._id === caller._id ? (doc.email ?? null) : null;
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
  // Through `discardFile`, which also keeps a face that is under report until
  // a moderator has looked at it.
  await discardFile(ctx, storageId);
}
