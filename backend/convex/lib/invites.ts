// House invites by link or QR code: the parts shared by convex/invites.ts,
// the removal paths that revoke them, and the HTTP page in convex/http.ts.
//
// Default runtime only (Web Crypto, no Node), so http.ts can import it.

import { Doc, Id } from "../_generated/dataModel";
import { MutationCtx } from "../_generated/server";

/** A link lasts a week. */
export const LINK_TTL_MS = 7 * 24 * 60 * 60 * 1000;
/** A QR code lasts ten minutes; the sheet asks for a new one before then. */
export const QR_TTL_MS = 10 * 60 * 1000;
/** `maxUses`, when given, is 1 to this. */
export const MAX_USES_LIMIT = 20;
/** Live invites a home keeps; creating one past this revokes the oldest. */
export const LIVE_INVITES_PER_HOME = 20;
/** Rows read off a home's live range for the cap and the revokes. Bounded. */
export const LIVE_SCAN = 200;

/**
 * A token as it travels: 16 random bytes in unpadded base64url, 22
 * characters. Anything else is refused before it is hashed or drawn. A
 * little slack on the length, so a future longer token is not a breaking
 * change for the page.
 */
export const TOKEN_RE = /^[A-Za-z0-9_-]{16,64}$/;

/** Where an invite link points: `<base>/<token>`. */
export function inviteLinkBase(): string {
  const base =
    process.env.INVITE_LINK_BASE ?? "https://nestzone-convex-api.walhallaa.com/.well-known/join";
  return base.replace(/\/+$/, "");
}

export function inviteUrl(token: string): string {
  return `${inviteLinkBase()}/${token}`;
}

/** 128 random bits, base64url without padding. */
export function newToken(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** What is stored for a token: its SHA-256, in hex. */
export async function hashToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export type InviteState = "ok" | "expired" | "full" | "revoked";

/** Why an invite can or cannot be used now. Revoked beats full beats expired. */
export function inviteState(invite: Doc<"home_invites">, now: number): InviteState {
  if (invite.revoked_at !== undefined) return "revoked";
  if (invite.max_uses !== undefined && invite.uses >= invite.max_uses) return "full";
  if (invite.expires_at <= now) return "expired";
  return "ok";
}

/**
 * Revokes one invite. `expires_at` comes down to now as well, so the row
 * leaves its home's live range at once (and the sweep takes it a day later).
 */
export async function revokeInvite(
  ctx: MutationCtx,
  invite: Doc<"home_invites">,
  now: number,
): Promise<void> {
  if (invite.revoked_at !== undefined) return;
  await ctx.db.patch(invite._id, {
    revoked_at: now,
    expires_at: Math.min(invite.expires_at, now),
  });
}

/** A home's invites that have not expired yet, newest expiry first. Bounded. */
export async function liveInvites(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  now: number,
): Promise<Doc<"home_invites">[]> {
  return await ctx.db
    .query("home_invites")
    .withIndex("by_home", (q) =>
      // Nothing is made to last longer than a link; the ceiling says so.
      q.eq("home_id", homeId).gt("expires_at", now).lte("expires_at", now + LINK_TTL_MS),
    )
    .order("desc")
    .take(LIVE_SCAN);
}

/**
 * Revokes every live invite of a home: for a removal, beside the new invite
 * code, so the person removed cannot walk back in with a link they kept.
 */
export async function revokeHomeInvites(ctx: MutationCtx, homeId: Id<"homes">): Promise<number> {
  const now = Date.now();
  const live = await liveInvites(ctx, homeId, now);
  for (const invite of live) await revokeInvite(ctx, invite, now);
  return live.length;
}
