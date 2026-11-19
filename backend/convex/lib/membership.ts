// One person leaving one home: the single place that knows how.
//
// Three ways out share it — `homes:leave` (you go), `homes:removeMember`
// (somebody sends you) and account deletion (you go from every home) — so a
// fix to what leaving means is made once and holds for all three.

import { Doc, Id } from "../_generated/dataModel";
import { MutationCtx } from "../_generated/server";
import { internal } from "../_generated/api";
import { cascadeDeleteHome } from "./relations";

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
  // Nestie's vote may have been waiting only on the one who just left: ask
  // "has everyone answered?" again of who is left. Scheduled, so leaving
  // never waits on it or fails for it; a house with no open vote is a no-op.
  await ctx.scheduler.runAfter(0, internal.companion.membersChanged, { homeId: home._id });
  return { deletedHome: false };
}
