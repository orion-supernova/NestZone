// Household Pro: who carries it, and the one check every Pro write makes.
//
// A house is Pro while any current member holds an unexpired `pro`
// entitlement (a `pro_entitlements` row, written from RevenueCat's answer by
// convex/pro.ts) — and the house is among the first `PLUS_HOMES_PER_PERSON`
// homes that member joined, so one subscription cannot carry every house its
// owner walks into. Read per member: a house is a handful of people, so this
// is a handful of indexed point reads, never a scan.
//
// Three switches, all deployment env vars:
//   PRO_ENFORCE        "on" makes `requirePro` refuse and the coercions
//                      apply. Unset, every gate is a no-op: one deployment
//                      serves builds that have no paywall, and they must keep
//                      working until the census says they are gone.
//   PRO_SANDBOX        "on" counts sandbox purchases (TestFlight, App Review).
//   PRO_COMP_USER_IDS  comma-separated user ids that are always Pro — the
//                      owner's own testing, never a sales channel.
//
// Reads never call any of this to refuse. Pro gates features, never the
// household's own data: a house that stops paying keeps reading everything it
// wrote.

import { ConvexError } from "convex/values";
import { Doc, Id } from "../_generated/dataModel";
import { QueryCtx, MutationCtx } from "../_generated/server";

/**
 * What a refusal names, so the app's paywall opens on what was reached for.
 * Mirrors the app's `ProFeature` registry. A hint, not a contract: an unknown
 * value must degrade to a generic paywall on the client.
 */
export type ProFeature =
  | "calendar"
  | "finance"
  | "shoppingCategories"
  | "customMovieLists"
  | "archiveNow"
  | "eventFromElsewhere"
  | "expenseFromElsewhere"
  | "issues"
  | "multipleHomes"
  | "matureContent"
  | "messages";

export type ProStatus = {
  pro: boolean;
  /** Whose entitlement makes the house Pro. Absent when it isn't. */
  carriedBy?: Id<"users">;
  /** When the carrier's access ends; `null` is lifetime (or comped). */
  expiresAt?: number | null;
  willRenew?: boolean;
};

export function proEnforced(): boolean {
  return process.env.PRO_ENFORCE === "on";
}

function sandboxCounts(): boolean {
  return process.env.PRO_SANDBOX === "on";
}

function compedUsers(): Set<string> {
  return new Set(
    (process.env.PRO_COMP_USER_IDS ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter((s) => s.length > 0),
  );
}

/** Whether one entitlement row grants Pro at `now`. */
export function entitlementActive(row: Doc<"pro_entitlements">, now: number): boolean {
  if (row.is_sandbox && !sandboxCounts()) return false;
  return row.expires_at === null || row.expires_at > now;
}

/** A person's own row, if any. One per person; `.first()` tolerates a race. */
export async function entitlementOf(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<Doc<"pro_entitlements"> | null> {
  return await ctx.db
    .query("pro_entitlements")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .first();
}

/**
 * How many homes one person's Plus covers. A house is Plus through a member,
 * so without a cap one subscription that joins five houses makes all five
 * Plus. With it, a person's Plus covers the first homes they joined, in join
 * order, and any further home they are in gets nothing from them (it is still
 * Plus if another member there carries Plus with room to spare). Nobody is
 * refused a home or taken out of one for it: a third home is simply not
 * covered. Comped people follow the same cap.
 */
export const PLUS_HOMES_PER_PERSON = 2;

/**
 * The homes a person's own Plus covers, in join order: the first
 * `PLUS_HOMES_PER_PERSON` homes in their `home_id` mirror that they are still
 * a member of.
 *
 * Join order is the order of `users.home_id`. Every writer appends on join
 * (`homes.create`, `homes.join`, `demo.seedHousehold`: a `Set` of the old
 * array plus the new id, which keeps the order and puts the new one last) and
 * every remover filters (`departHome`, `cascadeDeleteHome`), which keeps the
 * order of what is left; leaving and coming back is a new join, at the end.
 * There is no join timestamp to prefer. A mirror entry for a home that is
 * gone or no longer lists the person is skipped, so a stale entry can never
 * take a slot.
 *
 * Says nothing about whether the person carries Plus; ask `userHasPro`.
 */
export async function coveredHomes(
  ctx: QueryCtx | MutationCtx,
  user: Doc<"users">,
): Promise<Id<"homes">[]> {
  const covered: Id<"homes">[] = [];
  for (const id of user.home_id ?? []) {
    if (covered.length >= PLUS_HOMES_PER_PERSON) break;
    if (covered.includes(id)) continue;
    const home = await ctx.db.get(id);
    if (home && (home.members ?? []).includes(user._id)) covered.push(id);
  }
  return covered;
}

/**
 * Whether this member's Plus, if they carry it, reaches `home`: whether
 * `home` is among the first `PLUS_HOMES_PER_PERSON` homes they are a member
 * of. Walks their mirror only up to `home` or the cap, whichever comes
 * first, so a person in one or two homes costs one or two reads.
 *
 * A member whose mirror lacks `home` (it should never, but the two are
 * separate documents) is treated as having joined it last.
 */
async function coversHome(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
  home: Doc<"homes">,
): Promise<boolean> {
  if (!(home.members ?? []).includes(userId)) return false;
  const user = await ctx.db.get(userId);
  if (!user) return false;
  const seen = new Set<Id<"homes">>();
  let before = 0;
  for (const id of user.home_id ?? []) {
    if (id === home._id) return true; // reached it with a slot still free
    if (seen.has(id)) continue;
    seen.add(id);
    const other = await ctx.db.get(id);
    if (other && (other.members ?? []).includes(userId)) {
      before += 1;
      if (before >= PLUS_HOMES_PER_PERSON) return false;
    }
  }
  // Not in the mirror at all: it counts after every home that is.
  return before < PLUS_HOMES_PER_PERSON;
}

/**
 * Whether `home` is Pro, and who carries it.
 *
 * A member carries it for this home only when they hold Plus (an active
 * entitlement, or the comp list) *and* this home is one their Plus covers
 * (`PLUS_HOMES_PER_PERSON`, in join order). Coverage is checked only for
 * members who hold Plus, and only until one is found, so a house nobody pays
 * for costs what it always did: one indexed read per member.
 *
 * `prefer` names the member to credit when several carry it — the caller,
 * so "your Pro covers this house" is said to the person who pays rather than
 * to whoever sorts first. Otherwise lifetime beats a date, and the latest
 * date wins; a comped member comes after every paying one.
 */
export async function homeProStatus(
  ctx: QueryCtx | MutationCtx,
  home: Doc<"homes">,
  prefer?: Id<"users">,
): Promise<ProStatus> {
  const members = home.members ?? [];
  if (members.length === 0) return { pro: false };

  const comped = compedUsers();
  const compedStatus = (userId: Id<"users">): ProStatus => ({
    pro: true,
    carriedBy: userId,
    expiresAt: null,
    willRenew: true,
  });

  const now = Date.now();
  const rows = await Promise.all(members.map((m) => entitlementOf(ctx, m)));
  const active = rows.filter(
    (r): r is Doc<"pro_entitlements"> => r !== null && entitlementActive(r, now),
  );
  const compedMembers = members.filter((m) => comped.has(m));
  if (active.length === 0 && compedMembers.length === 0) return { pro: false };

  // The caller first, paid or comped, when their Plus reaches this home.
  const isMember = prefer !== undefined && members.includes(prefer);
  if (isMember) {
    const own = active.find((r) => r.user_id === prefer);
    if ((own || comped.has(prefer!)) && (await coversHome(ctx, prefer!, home))) {
      return own ? describe(own) : compedStatus(prefer!);
    }
  }

  // Then whoever else carries it with room for this home: lifetime first,
  // then the latest end.
  const ranked = [...active].sort((a, b) => {
    if (a.expires_at === null) return b.expires_at === null ? 0 : -1;
    if (b.expires_at === null) return 1;
    return b.expires_at - a.expires_at;
  });
  for (const row of ranked) {
    if (isMember && row.user_id === prefer) continue;
    if (await coversHome(ctx, row.user_id, home)) return describe(row);
  }
  for (const m of compedMembers) {
    if (isMember && m === prefer) continue;
    if (active.some((r) => r.user_id === m)) continue; // already judged above
    if (await coversHome(ctx, m, home)) return compedStatus(m);
  }
  return { pro: false };
}

function describe(row: Doc<"pro_entitlements">): ProStatus {
  return {
    pro: true,
    carriedBy: row.user_id,
    expiresAt: row.expires_at,
    willRenew: row.will_renew,
  };
}

/**
 * Whether this one person carries Plus themselves: their own active
 * entitlement, or the comp list. Not "is any house of theirs Plus" — that is
 * `homeProStatus` — and not capped: a person past `PLUS_HOMES_PER_PERSON`
 * homes still has Plus, it just covers only the first ones. For what Plus
 * grants a person rather than a house (more than one home, mature titles).
 */
export async function userHasPro(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<boolean> {
  if (compedUsers().has(userId)) return true;
  const row = await entitlementOf(ctx, userId);
  return row !== null && entitlementActive(row, Date.now());
}

/**
 * Whether a Plus feature that names no house may be used by this person: true
 * when enforcement is off, when they carry Plus themselves, or when any home
 * they belong to is Plus. For the few functions that take no `homeId` (old
 * builds call them without one). A person has a handful of homes, so this is
 * a handful of point reads.
 */
export async function anyHomeAllows(
  ctx: QueryCtx | MutationCtx,
  user: Doc<"users">,
): Promise<boolean> {
  if (!proEnforced()) return true;
  if (await userHasPro(ctx, user._id)) return true;
  for (const id of user.home_id ?? []) {
    const home = await ctx.db.get(id);
    if (!home || !(home.members ?? []).includes(user._id)) continue;
    if ((await homeProStatus(ctx, home)).pro) return true;
  }
  return false;
}

async function loadHome(
  ctx: QueryCtx | MutationCtx,
  home: Doc<"homes"> | Id<"homes">,
): Promise<Doc<"homes"> | null> {
  return typeof home === "string" ? await ctx.db.get(home) : home;
}

/**
 * Whether a Pro-only *choice* may stand for this house: true when enforcement
 * is off or the house is Pro. For the coercions (shopping categories), where
 * a free house's write still lands with the free value instead.
 */
export async function proAllows(
  ctx: QueryCtx | MutationCtx,
  home: Doc<"homes"> | Id<"homes">,
): Promise<boolean> {
  if (!proEnforced()) return true;
  const doc = await loadHome(ctx, home);
  if (!doc) return false;
  return (await homeProStatus(ctx, doc)).pro;
}

/**
 * Refuses a Pro write for a house without Pro.
 *
 * Throws `ConvexError({ code: "PRO_REQUIRED", feature })` — structured, so the
 * app can tell it from every other failure and open the paywall on `feature`
 * (convex-swift hands the data over as JSON). A no-op while `PRO_ENFORCE` is
 * not "on". Call it after the membership check, so a stranger learns nothing
 * about a house's plan.
 */
export async function requirePro(
  ctx: QueryCtx | MutationCtx,
  home: Doc<"homes"> | Id<"homes">,
  feature: ProFeature,
): Promise<void> {
  if (await proAllows(ctx, home)) return;
  throw proRequired(feature);
}

/** The refusal itself, for a gate that has already decided. */
export function proRequired(feature: ProFeature): ConvexError<{ code: string; feature: string }> {
  return new ConvexError({ code: "PRO_REQUIRED", feature });
}
