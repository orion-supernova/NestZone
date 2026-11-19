// Household Pro: who carries it, and the one check every Pro write makes.
//
// A house is Pro while any current member holds an unexpired `pro`
// entitlement (a `pro_entitlements` row, written from RevenueCat's answer by
// convex/pro.ts). Read per member: a house is a handful of people, so this is
// a handful of indexed point reads, never a scan.
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
  | "expenseFromElsewhere";

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
 * Whether `home` is Pro, and who carries it.
 *
 * `prefer` names the member to credit when several carry it — the caller,
 * so "your Pro covers this house" is said to the person who pays rather than
 * to whoever sorts first. Otherwise lifetime beats a date, and the latest
 * date wins.
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

  // The caller first, paid or comped; then whoever else carries it.
  const isMember = prefer !== undefined && members.includes(prefer);
  const own = isMember ? active.find((r) => r.user_id === prefer) : undefined;
  if (own) return describe(own);
  if (isMember && comped.has(prefer!)) return compedStatus(prefer!);

  if (active.length > 0) {
    const best = active.reduce((a, b) => {
      if (a.expires_at === null) return a;
      if (b.expires_at === null) return b;
      return b.expires_at > a.expires_at ? b : a;
    });
    return describe(best);
  }
  const compedMember = members.find((m) => comped.has(m));
  return compedMember ? compedStatus(compedMember) : { pro: false };
}

function describe(row: Doc<"pro_entitlements">): ProStatus {
  return {
    pro: true,
    carriedBy: row.user_id,
    expiresAt: row.expires_at,
    willRenew: row.will_renew,
  };
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
