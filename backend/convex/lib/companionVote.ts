// Choosing the next one together, and the three things Nestie says out loud.
//
// The rules here are pure: which species a vote offers, how its ballots add
// up, who wins. The writes that use them are in convex/companion.ts (opening,
// closing, applying the winner) and convex/polls.ts (the guard on a ballot).

import { v } from "convex/values";
import type { Doc, Id } from "../_generated/dataModel";
import type { QueryCtx, MutationCtx } from "../_generated/server";
import { CATALOG } from "./companionData";
import { DAY_MS, SPECIES, isUsable, shopContext, standingOfSpecies } from "./companion";

/** How many a vote offers: a plant, a pet, and the best of the rest. */
export const VOTE_OPTIONS = 3;
/** How long a vote stays open if not everybody answers first. */
export const VOTE_MS = DAY_MS;
/** Ballots one read takes: members × options, with room to spare. */
export const VOTE_ROWS_MAX = 500;

export const voteHow = v.union(
  v.literal("everyone"),
  v.literal("deadline"),
  v.literal("decided"),
  v.literal("picked"),
  v.literal("moved"),
);

/** The vote that makes this poll Nestie's, if it is one. One indexed read, for `generic` polls only. */
export async function companionVoteFor(
  ctx: QueryCtx | MutationCtx,
  poll: Doc<"polls">,
): Promise<Doc<"companion_votes"> | null> {
  if (poll.type !== "generic") return null;
  return await ctx.db
    .query("companion_votes")
    .withIndex("by_poll", (q) => q.eq("poll_id", poll._id))
    .first();
}

// MARK: - The options

/**
 * Lower is offered first. Something the house bought and hasn't grown yet is
 * "the newest arrival" and leads; then what is in season today (it won't be
 * for long), then what was earned, then every house's own. Anything already in
 * the album comes after everything that isn't.
 */
function tier(id: string, grown: Set<string>): number {
  const access = SPECIES.get(id)?.access;
  const base =
    access?.type === "buy" || access?.type === "pack"
      ? 0
      : access?.type === "season"
        ? 1
        : access?.type === "reward"
          ? 2
          : 3;
  return base + (grown.has(id) ? 4 : 0);
}

/**
 * What a vote offers, best first: only what `start` would accept today
 * (`isUsable` — every house's, bought, earned, or in season), never the one
 * that just graduated, at most one plant and one pet before the best of the
 * rest. Within a tier the catalog order turns by the album's count, so two
 * graduations in a row don't offer the same three.
 *
 * Fewer than two means there is nothing to vote on, and the house just picks.
 */
export function voteOptions(house: Doc<"companion_homes">, now: number, exclude?: string): string[] {
  const shop = shopContext(house, now);
  const grown = new Set(house.grown_species ?? []);
  const usable = CATALOG.species.filter((s) => s.id !== exclude && isUsable(standingOfSpecies(s.id, shop)));

  const byTier = new Map<number, string[]>();
  for (const s of usable) {
    const t = tier(s.id, grown);
    byTier.set(t, [...(byTier.get(t) ?? []), s.id]);
  }
  const ranked: string[] = [];
  for (const t of [...byTier.keys()].sort((a, b) => a - b)) {
    const ids = byTier.get(t)!;
    const turn = house.album_count % ids.length;
    ranked.push(...ids.slice(turn), ...ids.slice(0, turn));
  }

  const isPet = (id: string) => SPECIES.get(id)?.isPet ?? false;
  const chosen = new Set<string>();
  const plant = ranked.find((id) => !isPet(id));
  const pet = ranked.find((id) => isPet(id));
  if (plant) chosen.add(plant);
  if (pet) chosen.add(pet);
  for (const id of ranked) {
    if (chosen.size >= VOTE_OPTIONS) break;
    chosen.add(id);
  }
  return ranked.filter((id) => chosen.has(id));
}

// MARK: - The ballots

export type Tally = Map<string, { yes: number; no: number }>;

/**
 * Each current member's answer to each option, once. A ballot from someone
 * who has left the house no longer counts; one on something that isn't an
 * option never did.
 */
export function tally(options: string[], ballots: Doc<"poll_votes">[], members: Id<"users">[]): Tally {
  const people = new Set<string>(members);
  const answers = new Map<string, Map<string, boolean>>();
  for (const ballot of ballots) {
    if (!people.has(ballot.user_id) || !options.includes(ballot.target_external_id)) continue;
    const mine = answers.get(ballot.user_id) ?? new Map<string, boolean>();
    mine.set(ballot.target_external_id, ballot.vote);
    answers.set(ballot.user_id, mine);
  }
  const result: Tally = new Map(options.map((id) => [id, { yes: 0, no: 0 }]));
  for (const mine of answers.values()) {
    for (const [id, yes] of mine) {
      const row = result.get(id)!;
      if (yes) row.yes++;
      else row.no++;
    }
  }
  return result;
}

/** Members who have answered every option: when it is all of them, the vote is over. */
export function answeredAll(options: string[], ballots: Doc<"poll_votes">[], members: Id<"users">[]): number {
  const people = new Set<string>(members);
  const seen = new Map<string, Set<string>>();
  for (const ballot of ballots) {
    if (!people.has(ballot.user_id) || !options.includes(ballot.target_external_id)) continue;
    const mine = seen.get(ballot.user_id) ?? new Set<string>();
    mine.add(ballot.target_external_id);
    seen.set(ballot.user_id, mine);
  }
  return [...seen.values()].filter((mine) => mine.size === options.length).length;
}

/**
 * The options with at least one yes, winner first: the most yeses; a tie goes
 * to one the house hasn't grown yet, then to the one fewer people said no to,
 * then to the server's own order. Empty when nobody said yes to anything.
 */
export function ranking(options: string[], counts: Tally, grown: Set<string>): string[] {
  return options
    .filter((id) => (counts.get(id)?.yes ?? 0) > 0)
    .sort((a, b) => {
      const ca = counts.get(a)!;
      const cb = counts.get(b)!;
      if (ca.yes !== cb.yes) return cb.yes - ca.yes;
      const ga = grown.has(a) ? 1 : 0;
      const gb = grown.has(b) ? 1 : 0;
      if (ga !== gb) return ga - gb;
      if (ca.no !== cb.no) return ca.no - cb.no;
      return options.indexOf(a) - options.indexOf(b);
    });
}

// MARK: - What Nestie says

/**
 * At most three per companion: `ready` when the one growing is all grown up,
 * then — only in a house of two or more — `vote` when choosing the next one
 * opens, and `arrived` when it has been chosen. Nothing about falling behind,
 * nobody named for not voting, and nothing at all when a vote ends with no
 * yes: the card on Today asks, the phone doesn't.
 *
 * Every other push this server sends is English, because nothing on the
 * server knows a reader's language (`users` and `push_tokens` carry none).
 * These follow that and send `PUSH_LANGUAGE`; the Turkish is written and
 * waiting for the day a device says which it reads.
 */
export const PUSH_LANGUAGE: "en" | "tr" = "en";

export type NoteKey = "ready" | "vote" | "arrived";

export const NESTIE_NOTES: Record<NoteKey, Record<"en" | "tr", { title: string; body: string }>> = {
  ready: {
    en: { title: "Nestie's all grown up!", body: "It's the big moment. Come to Today." },
    tr: { title: "Nestie kocaman oldu!", body: "Büyük an geldi, Bugün'e bir uğra." },
  },
  vote: {
    en: { title: "Who's next?", body: "Nestie's in the album now. Help pick the next one." },
    tr: { title: "Sıradaki kim olsun?", body: "Nestie albüme girdi. Yenisini beraber seçiyoruz, gel oyunu ver." },
  },
  arrived: {
    en: { title: "The new one's here!", body: "Come say hi on Today." },
    tr: { title: "Yenisi geldi!", body: "Bugün'e gel, bir merhaba de." },
  },
};

/**
 * The feed's and the push's category. Not `polls`: every build routes a
 * `polls` row to the movie game. A build that doesn't know `companion` draws
 * a plain row that goes nowhere, which is the honest thing for it to do.
 */
export const NESTIE_CATEGORY = "companion";
