// Who is allowed to write the app's changelog.
//
// One person, and an escape hatch. The changelog is the only thing in this
// backend that is not owned by a household — a release note is written once and
// read by everybody — so it is the only thing that needs an authority above
// home membership.
//
// Enforced here, on the server, and nowhere else that matters. The client also
// asks whether it is an admin, but only so it knows whether to *draw* the
// button: every mutation below the panel calls `requireAdmin` itself, because a
// hidden button is a UI decision and a permission is not.

import { Doc } from "../_generated/dataModel";
import { QueryCtx, MutationCtx } from "../_generated/server";
import { requireUser, currentUserId } from "./auth";

/**
 * The built-in administrator.
 *
 * Hardcoded rather than left to configuration alone so a fresh deployment has
 * an owner without anybody having to remember a step. `ADMIN_EMAILS` and
 * `ADMIN_USER_IDS` below add to this; nothing removes it.
 */
const BUILT_IN_ADMIN_EMAIL = "muratcankoc@gmail.com";

/**
 * Extra administrators, as a comma-separated environment variable:
 *
 *   npx convex env set ADMIN_EMAILS "someone@example.com,other@example.com"
 *
 * This exists because of how this app signs people in. Accounts are keyed on
 * Apple's `sub`, and Apple sends an email address **only on the very first
 * authorization** — and sends a `@privaterelay.appleid.com` alias instead of
 * the real address whenever "Hide My Email" was used. So the email on a `users`
 * row is not guaranteed to be the one its owner would tell you, which would
 * otherwise make an email allowlist a coin flip. When the address does not
 * match, `ADMIN_USER_IDS` settles it for good — see `whoAmI` in convex/inbox.ts
 * for how to find the id.
 */
function configuredEmails(): Set<string> {
  const emails = new Set<string>([BUILT_IN_ADMIN_EMAIL]);
  for (const raw of (process.env.ADMIN_EMAILS ?? "").split(",")) {
    const email = raw.trim().toLowerCase();
    if (email) emails.add(email);
  }
  return emails;
}

/**
 * Administrators named by user id:
 *
 *   npx convex env set ADMIN_USER_IDS "jh7abc...,jh7def..."
 *
 * The answer that cannot be wrong. An id is what the account *is*, where the
 * email is only what it once claimed.
 */
function configuredUserIds(): Set<string> {
  const ids = new Set<string>();
  for (const raw of (process.env.ADMIN_USER_IDS ?? "").split(",")) {
    const id = raw.trim();
    if (id) ids.add(id);
  }
  return ids;
}

/** Whether a loaded user doc may write the changelog. */
export function isAdminUser(user: Doc<"users">): boolean {
  if (configuredUserIds().has(user._id)) return true;
  const email = user.email?.trim().toLowerCase();
  return Boolean(email) && configuredEmails().has(email!);
}

/**
 * Whether the caller is an administrator, without throwing.
 *
 * For the one query that has to answer "should this person see an Admin
 * button": not being an admin is the ordinary case there, not a failure.
 * Returns false for a signed-out caller rather than throwing, so the badge
 * query stays usable the moment before a session is restored.
 */
export async function callerIsAdmin(ctx: QueryCtx | MutationCtx): Promise<boolean> {
  const uid = await currentUserId(ctx);
  if (!uid) return false;
  const user = await ctx.db.get(uid);
  return user ? isAdminUser(user) : false;
}

/** Returns the calling administrator, or throws. Guards every changelog write. */
export async function requireAdmin(
  ctx: QueryCtx | MutationCtx,
): Promise<Doc<"users">> {
  const user = await requireUser(ctx);
  if (!isAdminUser(user)) throw new Error("Not an administrator");
  return user;
}
