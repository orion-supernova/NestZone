// One person joining or leaving one home: the single place that knows how.
//
// Two ways in share `joinHome` — `homes:join` (the invite code) and
// `invites:redeem` (a link or QR code) — so the Plus rule and the arrival
// notice are the same whichever door was used. Three ways out share
// `departHome` — `homes:leave` (you go), `homes:removeMember`
// (somebody sends you) and account deletion (you go from every home) — so a
// fix to what leaving means is made once and holds for all three.

import { Doc, Id } from "../_generated/dataModel";
import { MutationCtx } from "../_generated/server";
import { internal } from "../_generated/api";
import { cascadeDeleteHome } from "./relations";
import { endShare } from "./calendarShare";
import { homeProStatus, proEnforced, proRequired, userHasPro } from "./pro";

export type Departure =
  | { deletedHome: true; removed: Record<string, number> }
  | { deletedHome: false };

/**
 * Takes `userId` out of `home`, in this transaction.
 *
 * Last member out takes the home and everything in it. Otherwise the rows
 * would survive with nobody able to satisfy requireHomeMember — permanently
 * unreadable data that no code path could ever reach or clean up again.
 *
 * What the person wrote while they lived there stays with the household
 * (messages, chores, expenses): it is the house's record, and every reader
 * already tolerates an author who is no longer a member.
 */
export async function departHome(
  ctx: MutationCtx,
  home: Doc<"homes">,
  userId: Id<"users">,
): Promise<Departure> {
  const remaining = (home.members ?? []).filter((m) => m !== userId);

  if (remaining.length === 0) {
    // Scrubs every member's `home_id` mirror, this person's included.
    const removed = await cascadeDeleteHome(ctx, home._id);
    return { deletedHome: true, removed };
  }

  await ctx.db.patch(home._id, { members: remaining, updated: Date.now() });
  const user = await ctx.db.get(userId);
  if (user) {
    await ctx.db.patch(userId, {
      home_id: (user.home_id ?? []).filter((h) => h !== home._id),
    });
  }
  // The calendars they shared with this house stop showing at once; their
  // rows drain behind it (lib/calendarShare.ts). The last-one-out case above
  // needs nothing: `homes:purgeHomeData` takes the whole house's.
  await endShare(ctx, home._id, userId);
  // Nestie's vote may have been waiting only on the one who just left: ask
  // "has everyone answered?" again of who is left. Scheduled, so leaving
  // never waits on it or fails for it; a house with no open vote is a no-op.
  await ctx.scheduler.runAfter(0, internal.companion.membersChanged, { homeId: home._id });
  return { deletedHome: false };
}

/**
 * Whether this person may take on one more home: always while `PRO_ENFORCE`
 * is off, when they belong to no other home, or when they carry Plus
 * themselves (`userHasPro`; a Plus house they are in does not count — Plus
 * for a second home is the person's). Never takes a home away: somebody
 * already in two keeps both, and leaving stays free. `joining` is the home
 * being joined, which does not count against them.
 */
export async function mayAddHome(
  ctx: MutationCtx,
  user: Doc<"users">,
  joining?: Id<"homes">,
): Promise<boolean> {
  if (!proEnforced()) return true;
  let count = 0;
  for (const id of user.home_id ?? []) {
    if (id === joining) continue;
    const home = await ctx.db.get(id);
    if (home && (home.members ?? []).includes(user._id)) count += 1;
  }
  if (count === 0) return true;
  return await userHasPro(ctx, user._id);
}

/**
 * Puts `user` into `home`, in this transaction: the Plus rule for a second
 * home, both sides of the membership (`homes.members` and the user's
 * `home_id` mirror), and the house's "joined" notice. Throws
 * `PRO_REQUIRED`/`multipleHomes` when the rule says no.
 *
 * Joining a home you are already in changes nothing that matters and
 * announces nothing (it still touches `updated`, as `homes:join` always has).
 */
export async function joinHome(
  ctx: MutationCtx,
  user: Doc<"users">,
  home: Doc<"homes">,
): Promise<{ wasAlreadyMember: boolean }> {
  const wasAlreadyMember = (home.members ?? []).some((m) => m === user._id);
  // A second home is Plus: the person's own, or the house being joined
  // already has it (the house pays). Re-entering a home you are in is not a
  // second home.
  if (
    !wasAlreadyMember &&
    !(await mayAddHome(ctx, user, home._id)) &&
    !(await homeProStatus(ctx, home)).pro
  ) {
    throw proRequired("multipleHomes");
  }

  const members = new Set([...(home.members ?? []), user._id]);
  await ctx.db.patch(home._id, { members: [...members], updated: Date.now() });

  const homes = new Set([...(user.home_id ?? []), home._id]);
  await ctx.db.patch(user._id, { home_id: [...homes] });

  // Re-entering a home you are already a member of is a no-op, not an
  // arrival, and must not announce one.
  if (!wasAlreadyMember) {
    await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
      homeId: home._id,
      actor: user._id,
      title: home.name ?? "NestZone",
      body: user.name
        ? `${user.name} joined the home`
        : "Someone joined the home",
      category: "home",
      topic: "home.members",
    });
  }
  return { wasAlreadyMember };
}
