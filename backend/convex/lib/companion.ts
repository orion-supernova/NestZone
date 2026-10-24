// Nestie's rules on the server: what a thing costs and whether a house can
// have it today, paying from the jar, and how what a household does becomes
// growth.
//
// The catalog half is a port of CompanionCatalog.swift (`ShopContext.standing`,
// `CompanionHouse.checkout`, `Exchange`), reading the data the app's own Swift
// exported (`companionData.ts`). Where this file and the app disagree, this
// file is what the jar obeys; the generated data keeps the disagreement down
// to the logic, which is short enough to read side by side.
//
// The growth half is the curve the plan settled on (Docs/Companion/tools/
// growth_sim.py, `growth_results.txt`): a saturating day of life — the first
// things a house does in a day count most, so nobody buys speed with volume —
// plus a small, capped day of care.

import { v, Infer } from "convex/values";
import { Doc, Id } from "../_generated/dataModel";
import { MutationCtx, QueryCtx } from "../_generated/server";
import { internal } from "../_generated/api";
import { CATALOG, CATALOG_VERSION } from "./companionData";
import type { Access, CatalogHoliday, DecorKind, Price, Reward, Season } from "./companionTypes";

// MARK: - The catalog, by id

/**
 * Bump when a rule in this file changes what a house can have or pay — a
 * standing, the checkout, the curve. With the generated catalog's hash it makes
 * `COMPANION_VERSION`, which `forHome` sends, so a build can tell when the
 * server no longer answers the way it does.
 */
export const RULES_VERSION = 1;
export const COMPANION_VERSION = `${CATALOG_VERSION}-r${RULES_VERSION}`;

export const SPECIES = new Map(CATALOG.species.map((s) => [s.id, s]));
export const DECOR = new Map(CATALOG.decor.map((d) => [d.id, d]));
export const PACKS = new Map(CATALOG.packs.map((p) => [p.id, p]));
export const HOLIDAYS = new Map(CATALOG.holidays.map((h) => [h.id, h]));
const FREE_TO_HAVE = CATALOG.freeToHave;
const SOUTHERN = new Set(CATALOG.southern);

// MARK: - Days
//
// Everything here counts in the house's own days. Convex runs in UTC, so a
// house carries its offset (`companion_homes.tz_offset`, minutes east of UTC,
// the same convention as `events.tz_offset`) and a day is read by shifting the
// instant and taking the UTC date — the trick `events.ts` uses, with no
// timezone database.

export const DAY_MS = 86_400_000;
const MINUTE_MS = 60_000;

/** Offsets that exist on Earth: UTC−12 to UTC+14. */
export function cleanOffset(minutes: number | undefined): number | undefined {
  if (minutes === undefined || !Number.isFinite(minutes)) return undefined;
  return Math.min(Math.max(Math.round(minutes), -720), 840);
}

export function dayOf(at: number, tzOffset: number): string {
  return new Date(at + tzOffset * MINUTE_MS).toISOString().slice(0, 10);
}

function dayToUtc(day: string): number {
  return Date.parse(`${day}T00:00:00Z`);
}

/** The instant a house's day begins. */
export function dayStart(day: string, tzOffset: number): number {
  return dayToUtc(day) - tzOffset * MINUTE_MS;
}

export function addDays(day: string, n: number): string {
  return new Date(dayToUtc(day) + n * DAY_MS).toISOString().slice(0, 10);
}

/** Whole days from `a` to `b`. */
export function daysBetween(a: string, b: string): number {
  return Math.round((dayToUtc(b) - dayToUtc(a)) / DAY_MS);
}

export function isDay(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(dayToUtc(value));
}

// MARK: - Holidays (Holidays.swift)

export function isSouthern(region: string | undefined): boolean {
  return region ? SOUTHERN.has(region) : false;
}

/** What a house keeps before anybody chooses: `Holiday.defaults(for:)`. */
export function defaultHolidays(region: string | undefined): string[] {
  return CATALOG.holidayDefaults[region ?? ""] ?? CATALOG.holidayDefaults["*"];
}

function holidayStart(holiday: CatalogHoliday, year: number, region: string | undefined): string | undefined {
  // `.regional(rules, otherwise)`: a region with its own rule, else the rest.
  const table = (region && holiday.starts[region]) || holiday.starts["*"];
  return table?.[String(year)];
}

/** `Holiday.window(around:)`: from `lead` days before the first day to the end of the last. */
function inWindow(holiday: CatalogHoliday, day: string, region: string | undefined): boolean {
  const year = Number(day.slice(0, 4));
  for (const candidate of [year - 1, year, year + 1]) {
    const first = holidayStart(holiday, candidate, region);
    if (!first) continue;
    const opens = addDays(first, -holiday.lead);
    const closes = addDays(first, holiday.days);
    if (day >= opens && day < closes) return true;
  }
  return false;
}

/** The holidays dressing a house's scene on `day`, among the ones it keeps. */
export function activeHolidays(
  day: string,
  kept: Iterable<string>,
  region: string | undefined,
): CatalogHoliday[] {
  const out: CatalogHoliday[] = [];
  for (const id of kept) {
    const holiday = HOLIDAYS.get(id);
    if (holiday && inWindow(holiday, day, region)) out.push(holiday);
  }
  return out;
}

export function keptHolidays(house: { holidays?: string[]; region?: string }): string[] {
  return house.holidays ?? defaultHolidays(house.region);
}

// MARK: - Where a thing stands for one house today (`ShopContext`)

export type ShopContext = {
  day: string;
  southern: boolean;
  owned: Set<string>;
  ownedSpecies: Set<string>;
  /** How many the house has grown all the way, and which species among them. */
  albumCount: number;
  grownSpecies: Set<string>;
  holidays: CatalogHoliday[];
  isBirthday: boolean;
};

export type Standing =
  | { type: "free" }
  | { type: "have" }
  | { type: "freeToday" }
  | { type: "buy"; price: Price }
  | { type: "sale"; price: Price; freeToday: boolean }
  | { type: "locked" };

export type ShopItem = { kind: "decor" | "species" | "pack"; id: string };

export function shopContext(
  house: Doc<"companion_homes">,
  now: number,
  options: { isBirthday?: boolean } = {},
): ShopContext {
  const day = dayOf(now, house.tz_offset ?? 0);
  return {
    day,
    southern: isSouthern(house.region),
    owned: new Set(house.owned_decor),
    ownedSpecies: new Set(house.owned_species),
    albumCount: house.album_count,
    grownSpecies: new Set(house.grown_species ?? []),
    holidays: activeHolidays(day, keptHolidays(house), house.region),
    isBirthday: options.isBirthday ?? false,
  };
}

function seasonMonths(season: Season, southern: boolean): number[] {
  if (!southern || !season.followsNature) return season.months;
  return season.months.map((m) => ((m + 5) % 12) + 1);
}

function inSeason(season: Season, ctx: ShopContext): boolean {
  return seasonMonths(season, ctx.southern).includes(Number(ctx.day.slice(5, 7)));
}

function earned(reward: Reward, ctx: ShopContext): boolean {
  switch (reward.type) {
    case "graduations":
      return ctx.albumCount >= reward.count;
    case "birthday":
      return ctx.isBirthday;
    case "grownAll":
      return FREE_TO_HAVE.every((id) => ctx.grownSpecies.has(id));
  }
}

function brings(decorId: string, ctx: ShopContext): boolean {
  const decor = DECOR.get(decorId);
  if (decor?.wintry && ctx.southern) return false;
  return ctx.holidays.some((h) => h.decor.includes(decorId));
}

function packPrice(packId: string): Price | undefined {
  return PACKS.get(packId)?.price;
}

export function standingOfSpecies(id: string, ctx: ShopContext): Standing {
  const species = SPECIES.get(id);
  if (!species) return { type: "locked" };
  const access: Access = species.access;
  switch (access.type) {
    case "free":
      return { type: "free" };
    case "buy":
      return ctx.ownedSpecies.has(id) ? { type: "have" } : { type: "buy", price: access.price };
    case "pack": {
      const price = packPrice(access.pack);
      if (ctx.ownedSpecies.has(id)) return { type: "have" };
      return price ? { type: "buy", price } : { type: "locked" };
    }
    case "season":
      return inSeason(access.season, ctx) ? { type: "freeToday" } : { type: "locked" };
    case "reward":
      return earned(access.reward, ctx) ? { type: "have" } : { type: "locked" };
    default:
      return { type: "locked" };
  }
}

export function standingOfDecor(id: string, ctx: ShopContext): Standing {
  const decor = DECOR.get(id);
  if (!decor) return { type: "locked" };
  const freeToday = brings(id, ctx);
  const access: Access = decor.access;
  switch (access.type) {
    case "free":
      return { type: "free" };
    case "buy":
      if (ctx.owned.has(id)) return { type: "have" };
      // An everyday thing a holiday brings is free while it lasts.
      return freeToday ? { type: "sale", price: access.price, freeToday: true } : { type: "buy", price: access.price };
    case "holiday":
      return freeToday ? { type: "freeToday" } : { type: "locked" };
    case "holidaySale":
      if (ctx.owned.has(id)) return { type: "have" };
      if (ctx.holidays.some((h) => h.sells && h.decor.includes(id))) {
        return { type: "sale", price: access.price, freeToday };
      }
      return freeToday ? { type: "freeToday" } : { type: "locked" };
    case "seasonSale":
      if (ctx.owned.has(id)) return { type: "have" };
      return inSeason(access.season, ctx)
        ? { type: "sale", price: access.price, freeToday: false }
        : { type: "locked" };
    case "reward":
      if (!earned(access.reward, ctx)) return { type: "locked" };
      return access.reward.type === "birthday" ? { type: "freeToday" } : { type: "have" };
    default:
      return { type: "locked" };
  }
}

export function standingOf(item: ShopItem, ctx: ShopContext): Standing {
  switch (item.kind) {
    case "decor":
      return standingOfDecor(item.id, ctx);
    case "species":
      return standingOfSpecies(item.id, ctx);
    case "pack": {
      const pack = PACKS.get(item.id);
      if (!pack) return { type: "locked" };
      return pack.species.every((s) => ctx.ownedSpecies.has(s)) ? { type: "have" } : { type: "buy", price: pack.price };
    }
  }
}

export function isUsable(standing: Standing): boolean {
  return (
    standing.type === "free" ||
    standing.type === "have" ||
    standing.type === "freeToday" ||
    (standing.type === "sale" && standing.freeToday)
  );
}

export function standingPrice(standing: Standing): Price | undefined {
  return standing.type === "buy" || standing.type === "sale" ? standing.price : undefined;
}

/** `ShopItem.bought`: a pet from a pack comes with its pack. */
export function boughtItem(item: ShopItem): ShopItem {
  if (item.kind === "species") {
    const access = SPECIES.get(item.id)?.access;
    if (access?.type === "pack") return { kind: "pack", id: access.pack };
  }
  return item;
}

/** `ShopItem.price`: what the shop asks for it, whether or not it is on sale today. */
export function itemPrice(item: ShopItem): Price | undefined {
  switch (item.kind) {
    case "decor": {
      const access = DECOR.get(item.id)?.access;
      if (!access) return undefined;
      return access.type === "buy" || access.type === "holidaySale" || access.type === "seasonSale"
        ? access.price
        : undefined;
    }
    case "species": {
      const access = SPECIES.get(item.id)?.access;
      if (access?.type === "buy") return access.price;
      if (access?.type === "pack") return packPrice(access.pack);
      return undefined;
    }
    case "pack":
      return packPrice(item.id);
  }
}

export function knownItem(item: ShopItem): boolean {
  return item.kind === "decor" ? DECOR.has(item.id) : item.kind === "species" ? SPECIES.has(item.id) : PACKS.has(item.id);
}

// MARK: - Paying (`CompanionHouse.checkout`, `Exchange`)

export type Coins = { leaves: number; sparkles: number };

export type Checkout =
  | { type: "pay"; coins: Coins }
  | { type: "makeUp"; coins: Coins; short: number }
  | { type: "short"; sparkles: number };

/** The Sparkles that make up for this many Leaves, rounded up. */
export function sparklesForLeaves(leaves: number): number {
  const per = CATALOG.leavesPerSparkle;
  return Math.floor((Math.max(leaves, 0) + per - 1) / per);
}

export function checkout(jar: Coins, price: Price): Checkout {
  // A refunded top-up can take the jar below zero; nothing below zero pays.
  const leaves = Math.max(jar.leaves, 0);
  const sparkles = Math.max(jar.sparkles, 0);
  if (price.currency === "leaves") {
    if (leaves >= price.amount) return { type: "pay", coins: { leaves: price.amount, sparkles: 0 } };
    const short = price.amount - leaves;
    const makeUp = sparklesForLeaves(short);
    if (sparkles >= makeUp) return { type: "makeUp", coins: { leaves, sparkles: makeUp }, short };
    return { type: "short", sparkles: makeUp - sparkles };
  }
  if (sparkles >= price.amount) return { type: "pay", coins: { leaves: 0, sparkles: price.amount } };
  return { type: "short", sparkles: price.amount - sparkles };
}

// MARK: - The scene (`SceneLayout`)

export const SPOTS = ["above", "sky", "weather", "tree", "wearing", "pot", "left", "right", "ground"] as const;
type Spot = (typeof SPOTS)[number];

const SPOT_KIND: Record<Spot, DecorKind> = {
  above: "above",
  sky: "sky",
  weather: "weather",
  tree: "tree",
  wearing: "wearing",
  pot: "pot",
  left: "floor",
  right: "floor",
  ground: "ground",
};

const optionalSpot = v.optional(v.union(v.string(), v.null()));

/** A layout as a client sends it: a spot is a decoration id, absent, or null. */
export const layoutArg = v.object({
  above: optionalSpot,
  sky: optionalSpot,
  weather: optionalSpot,
  tree: v.optional(v.array(v.string())),
  wearing: optionalSpot,
  pot: optionalSpot,
  left: optionalSpot,
  right: optionalSpot,
  ground: optionalSpot,
});

/** A layout as stored and served: empty spots are absent. */
export const layoutValue = v.object({
  above: v.optional(v.string()),
  sky: v.optional(v.string()),
  weather: v.optional(v.string()),
  tree: v.array(v.string()),
  wearing: v.optional(v.string()),
  pot: v.optional(v.string()),
  left: v.optional(v.string()),
  right: v.optional(v.string()),
  ground: v.optional(v.string()),
});

export type Layout = Infer<typeof layoutValue>;

function decorKind(raw: string): DecorKind | undefined {
  if (raw.startsWith("flags.")) return HOLIDAYS.has(raw.slice(6)) ? "above" : undefined;
  return DECOR.get(raw)?.kind;
}

/**
 * What can be in the scene today (`State.available`): what the jar bought,
 * what every house has, what today's holidays bring, and their flags.
 */
export function availableDecor(ctx: ShopContext): Set<string> {
  const ids = new Set(ctx.owned);
  for (const decor of CATALOG.decor) {
    if (isUsable(standingOfDecor(decor.id, ctx))) ids.add(decor.id);
  }
  for (const holiday of ctx.holidays) {
    for (const raw of holiday.decor) if (raw.startsWith("flags.")) ids.add(raw);
  }
  return ids;
}

/**
 * A layout made safe to keep: every spot holds something that fits it and
 * that the house can put out today, the tree holds at most four, and a floor
 * thing stands on one side only. The same filter `decorateDone` applies on the
 * phone — a preview that was never bought goes back on the shelf.
 */
export function cleanLayout(input: Infer<typeof layoutArg>, available: Set<string>): Layout {
  const fits = (raw: string | null | undefined, spot: Spot): string | undefined =>
    raw && decorKind(raw) === SPOT_KIND[spot] && available.has(raw) ? raw : undefined;
  const tree: string[] = [];
  for (const raw of input.tree ?? []) {
    if (tree.length >= CATALOG.treeLimit) break;
    if (fits(raw, "tree") && !tree.includes(raw)) tree.push(raw);
  }
  const out: Layout = { tree };
  for (const spot of SPOTS) {
    if (spot === "tree") continue;
    const raw = fits(input[spot], spot);
    if (raw) out[spot] = raw;
  }
  if (out.left && out.left === out.right) delete out.right;
  return out;
}

export function isEmptyLayout(layout: Layout): boolean {
  return layout.tree.length === 0 && SPOTS.every((s) => s === "tree" || !layout[s]);
}

// MARK: - Growth
//
// One day of a house: `raw` from what it did, a rest bank paid into the first
// busy day after a quiet stretch, then `LIFE_CAP·(1 − e^(−raw/R_N))` plus the
// care track. The constants are growth_sim.py's, as settled (64 to graduate,
// a 9 + 2 day at most, so nobody in under a week).

const LIFE_CAP = 9.0;
const R0 = 7.0;
const SIZE_ALPHA = 0.35;

const W_CHORE = 1.0;
const W_CHORE_MAINT = 1.5;
const QUICK_LOG_MULT = 0.5;
/** A chore ticked this soon after its own author wrote it is a log, not a plan. */
export const QUICK_LOG_MS = 10 * MINUTE_MS;
const DUP_TITLE_MULT = 0.25;
const CHORE_FULL_PER_PERSON = 4;
const W_TRIP_BASE = 1.5;
const W_TRIP_ITEM = 0.25;
const TRIP_MAX = 3.0;
const TRIPS_PER_DAY = 2;
/** Purchases by one person this close together are one trip. */
const TRIP_GAP_MS = 60 * MINUTE_MS;
export const W_DINNER = 2.0;
export const W_EVENT_SOCIAL = 3.0;
export const W_EVENT_OTHER = 1.0;
const EVENTS_PER_DAY = 2;
/** A day counts its two biggest fixes, as it does its two biggest events. */
const FIXES_PER_DAY = 2;
/** A problem fixed this soon after it was written down is a log, not a repair. */
export const QUICK_FIX_MS = 10 * MINUTE_MS;
export const QUICK_FIX_MULT = 0.5;
export const W_FIX: Record<string, number> = { cosmetic: 2.0, minor: 3.0, major: 5.0, urgent: 6.0 };
export const W_MOVIE = 3.0;
const REST_PER_QUIET_DAY = 1.5;
const REST_MAX = 6.0;
const QUIET_RAW = 1.0;
const PAYOUT_RAW = 2.0;
const CARE_FIRST = 0.8;
const CARE_EACH_MORE = 0.4;
const CARE_TOGETHER = 0.5;
const CARE_CAP = 2.0;

export { W_CHORE, W_CHORE_MAINT, QUICK_LOG_MULT };

export const growthKind = v.union(
  v.literal("chore"),
  v.literal("purchase"),
  v.literal("dinner"),
  v.literal("event"),
  v.literal("fix"),
  v.literal("movie"),
  v.literal("care"),
);

export type GrowthRow = Pick<Doc<"companion_growth">, "kind" | "at" | "user_id" | "weight" | "title_key">;

/** A day's raw life growth and how many people cared, with every per-day rule applied. */
export function dayTally(rows: GrowthRow[]): { raw: number; carers: number } {
  const sorted = [...rows].sort((a, b) => a.at - b.at);
  let raw = 0;

  // Chores: a repeated title counts a quarter, and past four a person's
  // chores halve each, so thirty fake ticks a day buy nothing.
  const perPerson = new Map<string, number>();
  const titles = new Set<string>();
  for (const row of sorted) {
    if (row.kind !== "chore") continue;
    let w = row.weight;
    if (row.title_key) {
      if (titles.has(row.title_key)) w *= DUP_TITLE_MULT;
      titles.add(row.title_key);
    }
    const who = row.user_id ?? "?";
    const k = (perPerson.get(who) ?? 0) + 1;
    perPerson.set(who, k);
    if (k > CHORE_FULL_PER_PERSON) w *= 0.5 ** (k - CHORE_FULL_PER_PERSON);
    raw += w;
  }

  // Shopping: one person's purchases close together are a trip, and a day
  // counts its two best trips.
  const trips: number[] = [];
  const lastBy = new Map<string, { at: number; index: number }>();
  for (const row of sorted) {
    if (row.kind !== "purchase") continue;
    const who = row.user_id ?? "?";
    const last = lastBy.get(who);
    if (last && row.at - last.at <= TRIP_GAP_MS) {
      trips[last.index] += 1;
      lastBy.set(who, { at: row.at, index: last.index });
    } else {
      trips.push(1);
      lastBy.set(who, { at: row.at, index: trips.length - 1 });
    }
  }
  raw += trips
    .map((items) => Math.min(TRIP_MAX, W_TRIP_BASE + W_TRIP_ITEM * items))
    .sort((a, b) => b - a)
    .slice(0, TRIPS_PER_DAY)
    .reduce((s, x) => s + x, 0);

  const of = (kind: GrowthRow["kind"]) => sorted.filter((r) => r.kind === kind).map((r) => r.weight);
  raw += Math.max(0, ...of("dinner"));
  raw += of("event").sort((a, b) => b - a).slice(0, EVENTS_PER_DAY).reduce((s, x) => s + x, 0);
  raw += of("fix").sort((a, b) => b - a).slice(0, FIXES_PER_DAY).reduce((s, x) => s + x, 0);
  raw += Math.max(0, ...of("movie"));

  const carers = new Set(sorted.filter((r) => r.kind === "care").map((r) => r.user_id ?? "?")).size;
  return { raw, carers };
}

export function lifeGrowth(raw: number, members: number): number {
  const r = R0 * (Math.max(members, 1) / 2) ** SIZE_ALPHA;
  return LIFE_CAP * (1 - Math.exp(-raw / r));
}

export function careGrowth(carers: number): number {
  if (carers <= 0) return 0;
  let g = CARE_FIRST + CARE_EACH_MORE * (carers - 1);
  if (carers >= 2) g += CARE_TOGETHER;
  return Math.min(CARE_CAP, g);
}

/** One step of the rest bank: what a day pays out and carries on. */
export function bankStep(bankIn: number, raw: number): { paid: number; bankOut: number } {
  if (raw < QUIET_RAW) return { paid: 0, bankOut: Math.min(REST_MAX, bankIn + REST_PER_QUIET_DAY) };
  if (raw >= PAYOUT_RAW && bankIn > 0) return { paid: bankIn, bankOut: 0 };
  return { paid: 0, bankOut: bankIn };
}

export function bankAfterGap(bankOut: number, emptyDays: number): number {
  return Math.min(REST_MAX, bankOut + REST_PER_QUIET_DAY * Math.max(emptyDays, 0));
}

/** `CompanionMath.stage(progress:isPet:)`. */
export function stageFor(points: number, isPet: boolean): number {
  const progress = Math.min(points / CATALOG.graduateAt, 1);
  const stages = isPet ? CATALOG.stages.pet : CATALOG.stages.plant;
  let stage = 0;
  stages.forEach((threshold, index) => {
    if (progress >= threshold) stage = index;
  });
  return stage;
}

export function isPetSpecies(id: string): boolean {
  return SPECIES.get(id)?.isPet ?? false;
}

/** A chore's title, for spotting the same chore twice in a day. */
export function titleKey(title: string | undefined): string | undefined {
  const key = title?.trim().toLowerCase().replace(/\s+/g, " ");
  return key ? key.slice(0, 80) : undefined;
}

// MARK: - The house and its jar

export async function houseFor(
  ctx: QueryCtx | MutationCtx,
  homeId: Id<"homes">,
): Promise<Doc<"companion_homes"> | null> {
  return await ctx.db
    .query("companion_homes")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .first();
}

/**
 * The house's companion row, made on its first write. Every house has the
 * watering can.
 *
 * `place` is used only when the row is made: after that the region and the
 * offset belong to the house and move only through `companion:setPlace`, so
 * a member's phone abroad cannot drag the house's days with it.
 */
export async function ensureHouse(
  ctx: MutationCtx,
  homeId: Id<"homes">,
  place: { region?: string | null; tzOffset?: number } = {},
): Promise<Doc<"companion_homes">> {
  const existing = await houseFor(ctx, homeId);
  if (existing) return existing;
  const region = cleanRegion(place.region);
  const tz = cleanOffset(place.tzOffset);
  const now = Date.now();
  const id = await ctx.db.insert("companion_homes", {
    home_id: homeId,
    leaves: 0,
    sparkles: 0,
    welcomed: false,
    owned_decor: ["wateringCan"],
    owned_species: [],
    layout: { tree: [] },
    region: region ?? undefined,
    tz_offset: tz,
    album_count: 0,
    grown_species: [],
    place_set_at: now,
    region_set_at: now,
    created: now,
    updated: now,
  });
  return (await ctx.db.get(id))!;
}

/**
 * `undefined` leaves the region alone; `null` clears it; anything else must be
 * a two-letter region code.
 */
export function cleanRegion(region: string | null | undefined): string | null | undefined {
  if (region === undefined) return undefined;
  if (region === null) return null;
  const code = region.trim().toUpperCase();
  return /^[A-Z]{2}$/.test(code) ? code : undefined;
}

export const jarKind = v.union(
  v.literal("welcome"),
  v.literal("stage"),
  v.literal("graduation"),
  v.literal("buy"),
  v.literal("import"),
  v.literal("topUp"),
  v.literal("refund"),
);

/**
 * Moves coins in or out of the jar, once per `key`.
 *
 * The ledger row and the balance are written in the same transaction, so the
 * balance is always the sum of the ledger. Returns false — and changes
 * nothing — when the key has been seen, which is what makes a retried welcome,
 * stage payment, graduation or purchase a no-op.
 */
export async function moveJar(
  ctx: MutationCtx,
  houseId: Id<"companion_homes">,
  entry: {
    key: string;
    kind: Infer<typeof jarKind>;
    leaves: number;
    sparkles: number;
    userId?: Id<"users">;
    item?: string;
    madeUp?: number;
    companionId?: Id<"companions">;
  },
): Promise<boolean> {
  const house = await ctx.db.get(houseId);
  if (!house) throw new Error("No companion for this home");
  const seen = await ctx.db
    .query("jar_ledger")
    .withIndex("by_home_key", (q) => q.eq("home_id", house.home_id).eq("key", entry.key))
    .first();
  if (seen) return false;
  const now = Date.now();
  await ctx.db.insert("jar_ledger", {
    home_id: house.home_id,
    key: entry.key,
    kind: entry.kind,
    leaves: entry.leaves,
    sparkles: entry.sparkles,
    user_id: entry.userId,
    item: entry.item,
    made_up: entry.madeUp,
    companion_id: entry.companionId,
    created: now,
  });
  await ctx.db.patch(houseId, {
    leaves: house.leaves + entry.leaves,
    sparkles: house.sparkles + entry.sparkles,
    updated: now,
  });
  return true;
}

// MARK: - Hooks from the rest of the app

/** What a reconcile looks at: one credited thing, read back from its own table. */
export const growthSource = v.union(
  v.object({ kind: v.literal("task"), id: v.id("tasks") }),
  v.object({ kind: v.literal("shopping"), id: v.id("shopping_items") }),
  v.object({ kind: v.literal("meal"), date: v.string() }),
  v.object({ kind: v.literal("issue"), id: v.id("issues") }),
  v.object({ kind: v.literal("poll"), id: v.id("polls") }),
  v.object({ kind: v.literal("event"), id: v.id("events"), start: v.number() }),
  /**
   * After an import: the chores finished since this companion arrived, a page
   * at a time, each page scheduling the next.
   */
  v.object({
    kind: v.literal("backfill"),
    companionId: v.id("companions"),
    /** The start it was scheduled for: an import that moves it starts a new chain. */
    startedAt: v.number(),
    cursor: v.optional(v.string()),
  }),
);

export type GrowthSource = Infer<typeof growthSource>;

/**
 * Tells Nestie something may have happened, from inside another module's
 * write.
 *
 * One indexed read and, only for a house that is growing one, one scheduled
 * call. The reconcile it schedules reads the thing back from its own table, so
 * it is right whatever order the calls land in and however often a box is
 * ticked and unticked; nothing about the calling mutation's arguments, return
 * or speed changes. A house without Nestie pays the read and nothing else.
 */
export async function noteGrowth(
  ctx: MutationCtx,
  homeId: Id<"homes"> | undefined,
  source: GrowthSource,
): Promise<void> {
  if (!homeId) return;
  const house = await ctx.db
    .query("companion_homes")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .first();
  if (!house?.current_id) return;
  await ctx.scheduler.runAfter(0, internal.companion.reconcile, { homeId, source });
}
