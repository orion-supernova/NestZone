// House invites by universal link or QR code.
//
// Beside the invite code (`homes.invite_code`, `homes:join`), never instead
// of it: every build that joins by code keeps doing so. A link lasts a week,
// a QR code ten minutes; either may be limited to a number of uses. Only the
// SHA-256 of a token is stored (lib/invites.ts), so the raw token exists on
// the phone that asked for it, in the link, and nowhere else.
//
// Joining goes through `joinHome` (lib/membership.ts), the same path as
// `homes:join`: the Plus rule for a second home and the arrival notice are
// one code whichever door was used.

import { ConvexError, v } from "convex/values";
import { internalMutation, mutation, query, MutationCtx, QueryCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import { Doc } from "./_generated/dataModel";
import { requireHomeMember, requireUser } from "./lib/auth";
import { joinHome } from "./lib/membership";
import { publicUser, publicUsers } from "./lib/users";
import {
  LINK_TTL_MS,
  LIVE_INVITES_PER_HOME,
  MAX_USES_LIMIT,
  QR_TTL_MS,
  TOKEN_RE,
  hashToken,
  inviteState,
  inviteUrl,
  liveInvites,
  newToken,
  revokeInvite,
} from "./lib/invites";

const publicUserValidator = v.object({
  _id: v.id("users"),
  _creationTime: v.number(),
  name: v.optional(v.string()),
  avatar: v.optional(v.id("_storage")),
  avatar_url: v.union(v.string(), v.null()),
});

/** Members shown on the invite card. */
const PREVIEW_MEMBERS = 5;

function invalid(message: string): ConvexError<{ code: string; message: string }> {
  return new ConvexError({ code: "INVALID", message });
}

/** The invite a token names, or null. Never throws for a malformed token. */
async function inviteFor(
  ctx: QueryCtx | MutationCtx,
  token: string,
): Promise<Doc<"home_invites"> | null> {
  if (!TOKEN_RE.test(token)) return null;
  const hash = await hashToken(token);
  return await ctx.db
    .query("home_invites")
    .withIndex("by_token", (q) => q.eq("token", hash))
    .unique();
}

/**
 * A new invite to `homeId`, by any member.
 *
 * `link` lasts 7 days, `qr` 10 minutes. A new `qr` revokes the caller's
 * earlier `qr` invites to the same home — the sheet asks for a fresh one
 * every few minutes while it is open, which is how the code "changes". A
 * home keeps at most 20 live invites; past that the oldest are revoked.
 * `maxUses` is an integer 1–20, absent for unlimited.
 *
 * The token is returned here and never again: only its hash is kept.
 */
export const create = mutation({
  args: {
    homeId: v.id("homes"),
    kind: v.union(v.literal("link"), v.literal("qr")),
    maxUses: v.optional(v.number()),
  },
  returns: v.object({
    token: v.string(),
    url: v.string(),
    expiresAt: v.number(),
    maxUses: v.union(v.number(), v.null()),
  }),
  handler: async (ctx, { homeId, kind, maxUses }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);
    if (
      maxUses !== undefined &&
      (!Number.isInteger(maxUses) || maxUses < 1 || maxUses > MAX_USES_LIMIT)
    ) {
      throw invalid(`maxUses must be a whole number from 1 to ${MAX_USES_LIMIT}`);
    }

    const now = Date.now();
    const live = await liveInvites(ctx, homeId, now);
    // Newest expiry first. Only invites that could still let somebody in
    // count against the cap; a used-up one is no door.
    const usable = live.filter((i) => inviteState(i, now) === "ok");
    for (const invite of usable) {
      if (kind === "qr" && invite.kind === "qr" && invite.created_by === user._id) {
        await revokeInvite(ctx, invite, now);
      }
    }
    const kept = usable.filter(
      (i) => !(kind === "qr" && i.kind === "qr" && i.created_by === user._id),
    );
    // Room for the one being made: keep the newest `LIMIT - 1`.
    for (const invite of kept.slice(LIVE_INVITES_PER_HOME - 1)) {
      await revokeInvite(ctx, invite, now);
    }

    const token = newToken();
    const expiresAt = now + (kind === "qr" ? QR_TTL_MS : LINK_TTL_MS);
    await ctx.db.insert("home_invites", {
      home_id: homeId,
      token: await hashToken(token),
      created_by: user._id,
      kind,
      created: now,
      expires_at: expiresAt,
      max_uses: maxUses,
      uses: 0,
    });
    return { token, url: inviteUrl(token), expiresAt, maxUses: maxUses ?? null };
  },
});

/**
 * How an invite of `homeId` stands, for the sheet that shows it: live, so
 * "1 of 3 used" moves as people join and a used-up QR code can be replaced.
 * `null` when the token is not an invite to this home. Members only.
 *
 * Expiry is a time, not an event: the answer does not change by itself when
 * `expiresAt` passes, so the phone compares it with its own clock. A revoked
 * invite's `expiresAt` is the moment it was revoked.
 */
export const status = query({
  args: { homeId: v.id("homes"), token: v.string() },
  returns: v.union(
    v.null(),
    v.object({
      uses: v.number(),
      maxUses: v.union(v.number(), v.null()),
      expiresAt: v.number(),
      revoked: v.boolean(),
    }),
  ),
  handler: async (ctx, { homeId, token }) => {
    await requireHomeMember(ctx, homeId);
    const invite = await inviteFor(ctx, token);
    if (!invite || invite.home_id !== homeId) return null;
    return {
      uses: invite.uses,
      maxUses: invite.max_uses ?? null,
      expiresAt: invite.expires_at,
      revoked: invite.revoked_at !== undefined,
    };
  },
});

/**
 * What a token leads to, for the "Join this home?" card. Signed-in callers
 * only. Never throws for a bad token: it answers `invalid`.
 *
 * The house is named only when the answer is `ok` or `alreadyMember`; an
 * expired, used-up or revoked invite says only that.
 */
export const preview = query({
  args: { token: v.string() },
  returns: v.object({
    state: v.union(
      v.literal("ok"),
      v.literal("expired"),
      v.literal("full"),
      v.literal("revoked"),
      v.literal("invalid"),
      v.literal("alreadyMember"),
    ),
    homeId: v.optional(v.id("homes")),
    homeName: v.optional(v.string()),
    inviter: v.optional(publicUserValidator),
    memberCount: v.optional(v.number()),
    members: v.optional(v.array(publicUserValidator)),
    // When the invite stops working. A query is not re-run as time passes,
    // so the phone compares this with its own clock.
    expiresAt: v.optional(v.number()),
  }),
  handler: async (ctx, { token }) => {
    const user = await requireUser(ctx);
    const invite = await inviteFor(ctx, token);
    if (!invite) return { state: "invalid" as const };
    const home = await ctx.db.get(invite.home_id);
    if (!home) return { state: "invalid" as const };

    const isMember = (home.members ?? []).includes(user._id);
    const state = isMember ? ("alreadyMember" as const) : inviteState(invite, Date.now());
    if (state !== "ok" && state !== "alreadyMember") return { state };

    const memberIds = home.members ?? [];
    const [inviterDoc, ...memberDocs] = await Promise.all([
      ctx.db.get(invite.created_by),
      ...memberIds.slice(0, PREVIEW_MEMBERS).map((id) => ctx.db.get(id)),
    ]);
    const out: {
      state: "ok" | "alreadyMember";
      homeId: typeof home._id;
      homeName?: string;
      inviter?: Awaited<ReturnType<typeof publicUser>>;
      memberCount: number;
      members: Awaited<ReturnType<typeof publicUsers>>;
      expiresAt: number;
    } = {
      state,
      homeId: home._id,
      expiresAt: invite.expires_at,
      memberCount: memberIds.length,
      members: await publicUsers(
        ctx,
        memberDocs.filter((d): d is Doc<"users"> => d !== null),
      ),
    };
    if (home.name !== undefined) out.homeName = home.name;
    // An inviter who has since deleted their account is simply not named.
    if (inviterDoc) out.inviter = await publicUser(ctx, inviterDoc);
    return out;
  },
});

/**
 * Joins the home a token leads to.
 *
 * Somebody already in it hears `{ homeId, already: true }` and no use is
 * spent. Otherwise: `INVITE_INVALID` (no such invite, or its home is gone,
 * or it was revoked), `INVITE_FULL`, `INVITE_EXPIRED`, or `PRO_REQUIRED`
 * with `feature: "multipleHomes"` — the same rule `homes:join` applies,
 * through the same code (`joinHome`). A use is counted in the same
 * transaction as the join, so two people racing for the last use cannot
 * both get in.
 */
export const redeem = mutation({
  args: { token: v.string() },
  returns: v.object({ homeId: v.id("homes"), already: v.boolean() }),
  handler: async (ctx, { token }) => {
    const user = await requireUser(ctx);
    const invite = await inviteFor(ctx, token);
    if (!invite) throw new ConvexError({ code: "INVITE_INVALID" });
    const home = await ctx.db.get(invite.home_id);
    if (!home) throw new ConvexError({ code: "INVITE_INVALID" });

    if ((home.members ?? []).includes(user._id)) {
      return { homeId: home._id, already: true };
    }
    const state = inviteState(invite, Date.now());
    if (state === "revoked") throw new ConvexError({ code: "INVITE_INVALID" });
    if (state === "full") throw new ConvexError({ code: "INVITE_FULL" });
    if (state === "expired") throw new ConvexError({ code: "INVITE_EXPIRED" });

    await joinHome(ctx, user, home);
    await ctx.db.patch(invite._id, { uses: invite.uses + 1 });
    return { homeId: home._id, already: false };
  },
});

/**
 * Revokes one invite of `homeId`, by any member. Idempotent: an invite that
 * is already revoked, or a token that is not this home's, is `revoked:
 * false`, not an error.
 */
export const revoke = mutation({
  args: { homeId: v.id("homes"), token: v.string() },
  returns: v.object({ revoked: v.boolean() }),
  handler: async (ctx, { homeId, token }) => {
    await requireHomeMember(ctx, homeId);
    const invite = await inviteFor(ctx, token);
    if (!invite || invite.home_id !== homeId || invite.revoked_at !== undefined) {
      return { revoked: false };
    }
    await revokeInvite(ctx, invite, Date.now());
    return { revoked: true };
  },
});

/** Invites deleted per sweep batch. */
const SWEEP_BATCH = 200;
/** How long an ended invite is kept, so "expired" can still be told apart from "invalid". */
const KEEP_AFTER_EXPIRY_MS = 24 * 60 * 60 * 1000;

/**
 * Deletes invites that expired (or were revoked) more than a day ago, a
 * batch at a time, scheduling the next batch while there is more. Daily,
 * from crons.ts.
 */
export const sweep = internalMutation({
  args: {},
  returns: v.object({ removed: v.number(), more: v.boolean() }),
  handler: async (ctx) => {
    const cutoff = Date.now() - KEEP_AFTER_EXPIRY_MS;
    const rows = await ctx.db
      .query("home_invites")
      .withIndex("by_expires", (q) => q.lt("expires_at", cutoff))
      .take(SWEEP_BATCH);
    await Promise.all(rows.map((r) => ctx.db.delete(r._id)));
    const more = rows.length === SWEEP_BATCH;
    if (more) await ctx.scheduler.runAfter(0, internal.invites.sweep, {});
    return { removed: rows.length, more };
  },
});
