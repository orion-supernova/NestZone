// Nestie, shared by the house.
//
// One live read (`forHome`) carries everything the card draws, so a count and
// the list under it always come from the same read, the rule `issues:byHome`
// and `inbox:badge` follow; the album is its own read (`album`), opened with
// its sheet. Writes are few and small: start one, care for it, celebrate it,
// dress the scene, choose the days, say where the house is. Buying is
// `shop:buy`.
//
// Growth is never written by a client. The modules that already record what a
// household does (`tasks:update`, `tasks:removeFinished`,
// `shopping:setPurchased`, `meals:set`, `meals:clear`, `issues:setStatus`,
// `polls:vote`, and the hourly sweep over events that have ended) each call
// `noteGrowth`, which schedules `reconcile`. The reconcile reads the thing back
// from its own table and makes the ledger agree with it, so it is right in any
// order and any number of times.

import {
  query,
  mutation,
  internalMutation,
  internalQuery,
  internalAction,
} from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v, Infer } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, requireDocHome } from "./lib/auth";
import { isAdminUser } from "./lib/admin";
import { __internals as eventMath } from "./events";
import { CATALOG } from "./lib/companionData";
import {
  COMPANION_VERSION,
  DAY_MS,
  HOLIDAYS,
  SPECIES,
  DECOR,
  QUICK_LOG_MS,
  QUICK_LOG_MULT,
  QUICK_FIX_MS,
  QUICK_FIX_MULT,
  W_CHORE,
  W_CHORE_MAINT,
  W_DINNER,
  W_EVENT_OTHER,
  W_EVENT_SOCIAL,
  W_FIX,
  W_MOVIE,
  addDays,
  availableDecor,
  bankAfterGap,
  bankStep,
  careGrowth,
  cleanLayout,
  cleanOffset,
  cleanRegion,
  dayOf,
  dayStart,
  dayTally,
  daysBetween,
  ensureHouse,
  growthKind,
  growthSource,
  houseFor,
  isDay,
  isEmptyLayout,
  isPetSpecies,
  isUsable,
  jarKind,
  keptHolidays,
  layoutArg,
  layoutValue,
  lifeGrowth,
  moveJar,
  shopContext,
  stageFor,
  standingOfSpecies,
  titleKey,
} from "./lib/companion";
import {
  NESTIE_CATEGORY,
  NESTIE_NOTES,
  PUSH_LANGUAGE,
  VOTE_MS,
  VOTE_ROWS_MAX,
  answeredAll,
  ranking,
  tally,
  voteHow,
  voteOptions,
  type NoteKey,
} from "./lib/companionVote";

const HOUR_MS = 3_600_000;

/** The album a read carries. A house grows one every couple of weeks. */
const ALBUM_MAX = 500;
/** The newest credited things, for the mood: two days of people and today's count. */
const RECENT_MAX = 120;
/** The jar's feed. */
const JAR_FEED_MAX = 30;
/** The caller's care days the card needs: this companion's, and no more than these. */
const CARE_DAYS_MAX = 60;
/** A day with more credited things than this has stopped growing anything anyway. */
const DAY_ROWS_MAX = 500;
/** Chores one backfill page credits; each page schedules the next. */
const BACKFILL_PAGE = 100;
/** Rows one purge pass deletes; each pass schedules the next. */
const PURGE_BATCH = 400;
/**
 * Growing companions one sweep page looks at, and events per house in each of
 * its two reads: 20 × (100 + 100) keeps a page near 4,000 reads.
 */
const SWEEP_PAGE = 20;
const SWEEP_EVENTS_PER_READ = 100;

/** One purchase run counts once: a second tick inside this is the same trip. */
const SAME_TRIP_MS = 12 * HOUR_MS;
/** An untick this soon after the tick was a slip, and takes the credit back. */
const UNTICK_GRACE_MS = 2 * HOUR_MS;
/** From this hour of a house's evening, the day's planned dinner counts. */
const DINNER_HOUR = 17;
/** `setPlace` moves the house's days at most this often… */
const PLACE_COOLDOWN_MS = DAY_MS;
/** …and its region, which turns the seasons round, at most this often. */
const REGION_COOLDOWN_MS = 30 * DAY_MS;

// Imports from the MVP's one-phone file. A door that closes: once every phone
// that ran the MVP has opened a build that imports, nothing should come
// through it, so the server shuts it on a date rather than waiting to be told.
/**
 * The earliest a phone's MVP file can honestly start: the day the MVP first
 * landed (a471076, 20 October 2026, Istanbul time).
 */
const IMPORT_EPOCH = Date.parse("2026-10-19T21:00:00Z");
/** After this, `importLocal` refuses. Move it only on purpose. */
const IMPORT_SUNSET = Date.parse("2027-03-31T00:00:00Z");
/** Care days an import may bring: the fortnight before it. */
const IMPORT_CARE_DAYS = 14;
/**
 * The fastest a companion may grow up: six days, the floor the curve was
 * tuned to (64 points at a 9 + 2 day). The curve alone can get closer — a
 * day split across a midnight counts twice — so `graduate` holds the floor
 * itself. An album card shorter than this was not grown, and the album as a
 * whole cannot hold more cards than six-day runs fit since the MVP began.
 */
const MIN_GROW_MS = 6 * DAY_MS;

/** Events that are about being together, which grow it the most. */
const SOCIAL_EVENTS = new Set([
  "houseParty", "dinnerParty", "movieNight", "gameNight", "visit", "dining", "concert",
  "cinema", "theatre", "sports", "picnic", "trip", "birthday", "anniversary", "holiday",
]);

// MARK: - The reads

const coinsValue = v.object({ leaves: v.number(), sparkles: v.number() });

const houseValue = v.object({
  leaves: v.number(),
  sparkles: v.number(),
  welcomed: v.boolean(),
  owned: v.array(v.string()),
  ownedSpecies: v.array(v.string()),
  layout: layoutValue,
  /** `null` means the region's defaults. */
  holidays: v.union(v.array(v.string()), v.null()),
  region: v.union(v.string(), v.null()),
  tzOffset: v.union(v.number(), v.null()),
  albumCount: v.number(),
  /**
   * The species the house has grown all the way, sorted: the shop's "grown
   * them all" reward reads it. Bounded by the catalog.
   */
  grownSpecies: v.array(v.string()),
});

const currentValue = v.object({
  id: v.id("companions"),
  uuid: v.string(),
  species: v.string(),
  seed: v.string(),
  startedAt: v.number(),
  points: v.number(),
  stage: v.number(),
  /**
   * `graduate` would take it now: the points, the six-day floor, and still the
   * one growing. The server's own decision (`readiness`), never re-derived
   * on a phone. The read runs again at `readyAt` on its own (`wake`).
   */
  isReady: v.boolean(),
  /** The points are there (64), whatever its age. */
  pointsReady: v.boolean(),
  /**
   * The earliest it may graduate: `startedAt` plus the six-day floor. With
   * the points not there yet this is still the floor; `isReady` says when
   * both hold.
   */
  readyAt: v.number(),
  paidStage: v.number(),
  lastCareAt: v.union(v.number(), v.null()),
  /** The caller's own care days on this one, newest first, `YYYY-MM-DD` in the house's days. */
  myCareDays: v.array(v.string()),
  /**
   * A seed the house hasn't chosen yet: growing since the last one graduated,
   * while `vote` runs or after it ended with no yes. `species` is only the
   * vote's first option; draw a seed (or an egg), not it.
   */
  undecided: v.boolean(),
});

const voteOptionValue = v.object({
  species: v.string(),
  isPet: v.boolean(),
  /** Already in the album: a tie goes to one that isn't. */
  grown: v.boolean(),
  /** Current members who said yes, and no. */
  yes: v.number(),
  no: v.number(),
});

const voteValue = v.object({
  /** The `generic` poll the ballots go to: `polls:vote` / `polls:unvote` with a species as the target. */
  pollId: v.id("polls"),
  status: v.union(v.literal("open"), v.literal("closed")),
  openedAt: v.number(),
  /** When it closes on its own if not everybody has answered every option. */
  closesAt: v.number(),
  closedAt: v.union(v.number(), v.null()),
  how: v.union(voteHow, v.null()),
  /** What it chose. `null` while open, and on a vote that ended with no yes: then anyone picks. */
  winner: v.union(v.string(), v.null()),
  /** Best first, which is also the tie-break's last word. */
  options: v.array(voteOptionValue),
  /** The caller's own answers. */
  mine: v.array(v.object({ species: v.string(), yes: v.boolean() })),
  members: v.number(),
  /** Members who have answered every option. */
  answered: v.number(),
  /**
   * Somebody other than the caller has answered. While false, `start` with any
   * species the house can grow is a straight pick; once true, the caller can
   * vote or `decide`, never pick past it.
   */
  othersVoted: v.boolean(),
});

const graduateValue = v.object({
  id: v.id("companions"),
  uuid: v.string(),
  species: v.string(),
  seed: v.string(),
  startedAt: v.number(),
  graduatedAt: v.number(),
});

const recentValue = v.object({
  kind: growthKind,
  at: v.number(),
  userId: v.union(v.id("users"), v.null()),
});

const jarEntryValue = v.object({
  id: v.id("jar_ledger"),
  kind: jarKind,
  leaves: v.number(),
  sparkles: v.number(),
  item: v.union(v.string(), v.null()),
  userId: v.union(v.id("users"), v.null()),
  at: v.number(),
});

/**
 * What the card draws, in one payload: the jar and the scene, the one growing
 * and its growth, the newest things the house did (for the mood) and the
 * jar's feed (who added, who spent).
 *
 * `house` is null until the house's first write: a house that never opened
 * Nestie has nothing here, and the card invites it in. `catalogVersion` is the
 * generated catalog's hash with the rules' version, so a build can tell when
 * the server answers differently from it.
 */
export const forHome = query({
  args: { homeId: v.id("homes") },
  returns: v.object({
    catalogVersion: v.string(),
    graduateAt: v.number(),
    house: v.union(houseValue, v.null()),
    current: v.union(currentValue, v.null()),
    recent: v.array(recentValue),
    jar: v.array(jarEntryValue),
    /**
     * The vote that chose (or is choosing) the one growing now, with the
     * tally: open while `current.undecided`, closed with its `winner` after,
     * for as long as that one grows. `null` when the one growing was picked
     * without a vote — a house of one, or a choice made through `start`.
     */
    vote: v.union(voteValue, v.null()),
  }),
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    const empty = {
      catalogVersion: COMPANION_VERSION,
      graduateAt: CATALOG.graduateAt,
      house: null,
      current: null,
      recent: [],
      jar: [],
      vote: null,
    };
    const house = await houseFor(ctx, homeId);
    if (!house) return empty;

    const loaded = house.current_id ? await ctx.db.get(house.current_id) : null;
    const growing = loaded && loaded.status === "growing" ? loaded : null;
    const ready = growing ? readiness(house, growing, Date.now()) : null;
    const startDay = growing ? dayOf(growing.started_at, tzOf(growing, house)) : "";

    const voteDoc = growing?.vote_id ? await ctx.db.get(growing.vote_id) : null;
    const [recent, jar, care, ballots] = await Promise.all([
      growing
        ? ctx.db
            .query("companion_growth")
            .withIndex("by_companion_at", (q) => q.eq("companion_id", growing._id))
            .order("desc")
            .take(RECENT_MAX)
        : Promise.resolve([]),
      ctx.db
        .query("jar_ledger")
        .withIndex("by_home_created", (q) => q.eq("home_id", homeId))
        .order("desc")
        .take(JAR_FEED_MAX),
      growing
        ? ctx.db
            .query("companion_growth")
            .withIndex("by_companion_kind_user", (q) =>
              q
                .eq("companion_id", growing._id)
                .eq("kind", "care")
                .eq("user_id", user._id)
                .gte("day", startDay),
            )
            .order("desc")
            .take(CARE_DAYS_MAX)
        : Promise.resolve([]),
      voteDoc
        ? ctx.db
            .query("poll_votes")
            .withIndex("by_poll", (q) => q.eq("poll_id", voteDoc.poll_id))
            .take(VOTE_ROWS_MAX)
        : Promise.resolve([]),
    ]);

    let vote: Infer<typeof voteValue> | null = null;
    if (voteDoc) {
      const counts = tally(voteDoc.options, ballots, home.members);
      const grown = new Set(house.grown_species ?? []);
      const members = new Set<string>(home.members);
      vote = {
        pollId: voteDoc.poll_id,
        status: voteDoc.status,
        openedAt: voteDoc.opened_at,
        closesAt: voteDoc.closes_at,
        closedAt: voteDoc.closed_at ?? null,
        how: voteDoc.how ?? null,
        winner: voteDoc.winner ?? null,
        options: voteDoc.options.map((species) => ({
          species,
          isPet: isPetSpecies(species),
          grown: grown.has(species),
          yes: counts.get(species)?.yes ?? 0,
          no: counts.get(species)?.no ?? 0,
        })),
        mine: ballots
          .filter((b) => b.user_id === user._id && voteDoc.options.includes(b.target_external_id))
          .map((b) => ({ species: b.target_external_id, yes: b.vote })),
        members: home.members.length,
        answered: answeredAll(voteDoc.options, ballots, home.members),
        othersVoted: ballots.some((b) => b.user_id !== user._id && members.has(b.user_id)),
      };
    }

    return {
      ...empty,
      house: {
        leaves: house.leaves,
        sparkles: house.sparkles,
        welcomed: house.welcomed,
        owned: house.owned_decor,
        ownedSpecies: house.owned_species,
        layout: house.layout,
        holidays: house.holidays ?? null,
        region: house.region ?? null,
        tzOffset: house.tz_offset ?? null,
        albumCount: house.album_count,
        grownSpecies: [...(house.grown_species ?? [])].sort(),
      },
      current: growing && ready
        ? {
            id: growing._id,
            uuid: growing.uuid,
            species: growing.species,
            seed: growing.seed,
            startedAt: growing.started_at,
            points: growing.points,
            stage: stageFor(growing.points, isPetSpecies(growing.species)),
            isReady: ready.isReady,
            pointsReady: ready.pointsReady,
            readyAt: ready.readyAt,
            paidStage: growing.paid_stage,
            lastCareAt: growing.last_care_at ?? null,
            myCareDays: care.map((row) => row.day),
            undecided: growing.undecided === true,
          }
        : null,
      recent: recent.map((row) => ({ kind: row.kind, at: row.at, userId: row.user_id ?? null })),
      jar: jar.map((row) => ({
        id: row._id,
        kind: row.kind,
        leaves: row.leaves,
        sparkles: row.sparkles,
        item: row.item ?? null,
        userId: row.user_id ?? null,
        at: row.created,
      })),
      vote,
    };
  },
});

/** The album, oldest first: read when its sheet opens, not with every push to the card. */
export const album = query({
  args: { homeId: v.id("homes") },
  returns: v.array(graduateValue),
  handler: async (ctx, { homeId }) => {
    await requireHomeMember(ctx, homeId);
    const rows = await ctx.db
      .query("companions")
      .withIndex("by_home_status_graduated", (q) => q.eq("home_id", homeId).eq("status", "graduated"))
      .order("desc")
      .take(ALBUM_MAX);
    return rows.reverse().map((c) => ({
      id: c._id,
      uuid: c.uuid,
      species: c.species,
      seed: c.seed,
      startedAt: c.started_at,
      graduatedAt: c.graduated_at ?? c.started_at,
    }));
  },
});

/** The offset a companion's days are counted in: its own, fixed when it arrived. */
function tzOf(companion: Doc<"companions">, house: Doc<"companion_homes">): number {
  return companion.tz_offset ?? house.tz_offset ?? 0;
}

function hasPoints(points: number): boolean {
  return points >= CATALOG.graduateAt - 1e-9;
}

/**
 * Whether a companion may graduate now, and from when: the one rule `graduate`,
 * `start` and `forHome` all ask. Growing, the house's current one, chosen (a
 * seed still waiting on its vote is not yet anything), its points there, and
 * six days old — however the days fell, nothing grows up in under
 * six: the floor the curve was tuned to, held here rather than trusted to the
 * arithmetic.
 */
function readiness(
  house: Doc<"companion_homes">,
  companion: Doc<"companions">,
  now: number,
): { isReady: boolean; pointsReady: boolean; readyAt: number } {
  const readyAt = companion.started_at + MIN_GROW_MS;
  const pointsReady = hasPoints(companion.points);
  const isReady =
    companion.status === "growing" &&
    house.current_id === companion._id &&
    !companion.undecided &&
    pointsReady &&
    now >= readyAt;
  return { isReady, pointsReady, readyAt };
}

/**
 * Into the album, the graduation into the jar, and the house free to choose
 * the next. The caller has checked `readiness`. Paid once per album slot
 * (`graduation:<slot>`), as stages are, and only here does the slot move.
 */
async function graduateNow(
  ctx: MutationCtx,
  house: Doc<"companion_homes">,
  companion: Doc<"companions">,
  userId: Id<"users">,
  now: number,
): Promise<{ paid: { leaves: number; sparkles: number } | null }> {
  const slot = house.album_count;
  await ctx.db.patch(companion._id, { status: "graduated", graduated_at: now });
  const grown = new Set(house.grown_species ?? []);
  grown.add(companion.species);
  await ctx.db.patch(house._id, {
    current_id: undefined,
    album_count: slot + 1,
    grown_species: [...grown].sort(),
    updated: now,
  });
  const coins = CATALOG.rewards.graduation;
  const paid = await moveJar(ctx, house._id, {
    key: `graduation:${slot}`,
    kind: "graduation",
    leaves: coins.leaves,
    sparkles: coins.sparkles,
    userId,
    companionId: companion._id,
  });
  return { paid: paid ? coins : null };
}

/**
 * Schedules the one wake a companion gets, at its floor, if the floor is still
 * ahead. Called once per start: in `start` after the insert, and in
 * `importLocal` when it creates one or moves one's start.
 */
async function wakeAtFloor(ctx: MutationCtx, companionId: Id<"companions">, startedAt: number): Promise<void> {
  const readyAt = startedAt + MIN_GROW_MS;
  if (Date.now() < readyAt) {
    await ctx.scheduler.runAt(readyAt, internal.companion.wake, { companionId, startedAt });
  }
}

/**
 * The six-day floor has passed. Writes the moment on the row, which is all it
 * is for: `forHome` reads the clock, and a query doesn't re-run when time
 * passes, only when what it read changes. Pinned to the start it was
 * scheduled for, and a no-op after the first; run early, it puts itself back
 * at the floor rather than stamping.
 */
export const wake = internalMutation({
  args: { companionId: v.id("companions"), startedAt: v.number() },
  returns: v.null(),
  handler: async (ctx, { companionId, startedAt }) => {
    const companion = await ctx.db.get(companionId);
    if (!companion || companion.status !== "growing" || companion.of_age_at !== undefined) return null;
    if (companion.started_at !== startedAt) return null;
    if (Date.now() < startedAt + MIN_GROW_MS) {
      await wakeAtFloor(ctx, companionId, startedAt);
      return null;
    }
    await ctx.db.patch(companionId, { of_age_at: Date.now() });
    await announceReady(ctx, companionId);
    return null;
  },
});

/** Companions one `scheduleMissingWakes` page looks at; each page schedules the next. */
const WAKE_PAGE = 200;

/**
 * One-off, after the deploy that brought the wake: schedules it for every
 * companion growing whose floor is still ahead, which is exactly the range
 * `by_status` gives (`started_at` after six days ago, up to now). Duplicates
 * are accepted rather than stamped: one that already has a wake (started
 * after the deploy) gets a second, and whichever runs second finds
 * `of_age_at` set and does nothing. Running it twice is as harmless.
 *
 *   npx convex run companion:scheduleMissingWakes '{}'
 */
export const scheduleMissingWakes = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())), now: v.optional(v.number()) },
  returns: v.object({ scheduled: v.number(), done: v.boolean() }),
  handler: async (ctx, args): Promise<{ scheduled: number; done: boolean }> => {
    // Pinned across pages, so the range doesn't slide under the cursor.
    const now = args.now ?? Date.now();
    const page = await ctx.db
      .query("companions")
      .withIndex("by_status", (q) =>
        q.eq("status", "growing").gt("started_at", now - MIN_GROW_MS).lte("started_at", now),
      )
      .paginate({ cursor: args.cursor ?? null, numItems: WAKE_PAGE });
    let scheduled = 0;
    for (const companion of page.page) {
      if (companion.of_age_at !== undefined) continue;
      await wakeAtFloor(ctx, companion._id, companion.started_at);
      scheduled++;
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.companion.scheduleMissingWakes, {
        cursor: page.continueCursor,
        now,
      });
    }
    return { scheduled, done: page.isDone };
  },
});

/**
 * Pays stages `from + 1 … to` into the jar, each once per house slot.
 *
 * Keyed `stage:<album_count>:<n>` — the house's place in its album, not the
 * companion — so letting one go and starting another before anything
 * graduates can never pay the same stage twice. Only a graduation moves the
 * slot, and `graduate` refuses anything younger than six days. The house is read
 * fresh so the slot is the current one.
 */
async function payStages(
  ctx: MutationCtx,
  houseId: Id<"companion_homes">,
  companionId: Id<"companions">,
  from: number,
  to: number,
  options: { free?: boolean } = {},
): Promise<void> {
  const house = await ctx.db.get(houseId);
  if (!house) return;
  const coins = CATALOG.rewards.stage;
  for (let n = from + 1; n <= to; n++) {
    await moveJar(ctx, houseId, {
      key: `stage:${house.album_count}:${n}`,
      kind: "stage",
      leaves: options.free ? 0 : coins.leaves,
      sparkles: options.free ? 0 : coins.sparkles,
      companionId,
    });
  }
}


// MARK: - Choosing the next one together

/**
 * The welcome gift, once per house (`welcome`), with whichever one it starts.
 * `start` and a seed being chosen both pay it through here, so a house that
 * somehow graduated without it still gets it exactly once.
 */
async function welcomeIfNew(
  ctx: MutationCtx,
  house: Doc<"companion_homes">,
  userId: Id<"users"> | undefined,
  companionId: Id<"companions">,
): Promise<{ leaves: number; sparkles: number } | null> {
  const fresh = await ctx.db.get(house._id);
  if (!fresh || fresh.welcomed) return null;
  const gift = CATALOG.rewards.welcome;
  await moveJar(ctx, house._id, {
    key: "welcome",
    kind: "welcome",
    leaves: gift.leaves,
    sparkles: gift.sparkles,
    userId,
    companionId,
  });
  await ctx.db.patch(house._id, { welcomed: true });
  return gift;
}

/**
 * Who hears Nestie, from `COMPANION_NOTIFY`, until it ships to everyone:
 *
 * - unset or `off`: nobody. No push and no feed row; `notifyHome` is never
 *   scheduled. Every build reads the feed, and only Debug builds draw Nestie.
 * - `sandbox`: pushes to development-signed installs only (the APNs sandbox
 *   gateway, which is what an Xcode install registers), and no feed row.
 * - `on`: the whole house, push and feed, like every other notification.
 *
 * The key is written whatever this says, so turning it on later never
 * announces a "ready" that is days old.
 */
function companionNotify(): "off" | "sandbox" | "on" {
  const value = (process.env.COMPANION_NOTIFY ?? "").trim().toLowerCase();
  return value === "on" || value === "sandbox" ? value : "off";
}

/**
 * Says one of the three things, once per companion: the key goes on the row
 * in the same write that schedules the push, so a retry, a re-run or a second
 * phone finds it there and sends nothing. Through `push.notifyHome`, which
 * files it in the house's feed whether or not a push arrives. `alsoMark` are
 * keys this one stands in for, marked with it and never sent after it.
 */
async function announce(
  ctx: MutationCtx,
  companion: Doc<"companions">,
  key: NoteKey,
  actor?: Id<"users">,
  alsoMark: NoteKey[] = [],
): Promise<void> {
  const notified = companion.notified ?? [];
  if (notified.includes(key)) return;
  await ctx.db.patch(companion._id, { notified: [...new Set([...notified, key, ...alsoMark])] });
  const mode = companionNotify();
  if (mode === "off") return;
  const copy = NESTIE_NOTES[key][PUSH_LANGUAGE];
  await ctx.scheduler.runAfter(0, internal.push.notifyHome, {
    homeId: companion.home_id,
    actor,
    title: copy.title,
    body: copy.body,
    category: NESTIE_CATEGORY,
    ...(mode === "sandbox" ? { environment: "sandbox" as const, skipFeed: true } : {}),
  });
}

/**
 * "All grown up", the moment `readiness` first says so: from the wake (the
 * floor passed with the points there), from a recount (the points arrived
 * after the floor), or from a seed being chosen. To the whole house.
 */
async function announceReady(
  ctx: MutationCtx,
  companionId: Id<"companions">,
  alsoMark: NoteKey[] = [],
): Promise<boolean> {
  const companion = await ctx.db.get(companionId);
  if (!companion || (companion.notified ?? []).includes("ready")) return false;
  const house = await houseFor(ctx, companion.home_id);
  if (!house || !readiness(house, companion, Date.now()).isReady) return false;
  await announce(ctx, companion, "ready", undefined, alsoMark);
  return true;
}

/**
 * Opens the vote for the next one, in the write that graduated `graduated`,
 * for a house of two or more with at least two things to choose from.
 *
 * The seed starts growing now — the first option stands in for its species —
 * so what the house does while it decides is counted like any other day. The
 * ballot is a `generic` poll, which no shipped build lists; the deadline is
 * one scheduled `closeVote`. Returns the poll, or null when the house just
 * picks (one member, or one choice).
 */
async function openVote(
  ctx: MutationCtx,
  home: Doc<"homes">,
  graduated: Doc<"companions">,
  userId: Id<"users">,
  now: number,
): Promise<Id<"polls"> | null> {
  if ((home.members ?? []).length < 2) return null;
  const house = await houseFor(ctx, home._id);
  if (!house || house.current_id) return null;
  const options = voteOptions(house, now, graduated.species);
  if (options.length < 2) return null;

  const pollId = await ctx.db.insert("polls", {
    home_id: home._id,
    owner_id: userId,
    // The app draws its own, localised; this is for the dashboard.
    title: "Who's next?",
    type: "generic",
    status: "active",
    genre: "companion",
    created: now,
    updated: now,
  });
  await Promise.all(
    options.map((species, order) =>
      ctx.db.insert("poll_items", {
        poll_id: pollId,
        external_id: species,
        label: species,
        order,
        created: now,
        updated: now,
      }),
    ),
  );

  const companionId = await ctx.db.insert("companions", {
    home_id: home._id,
    uuid: crypto.randomUUID().toUpperCase(),
    species: options[0],
    seed: `${home._id}-${house.album_count}`,
    started_at: now,
    status: "growing",
    points: 0,
    paid_stage: 0,
    tz_offset: house.tz_offset ?? 0,
    origin: "server",
    created: now,
    // Not `follows`: that is `start`'s record of a graduation it did itself,
    // and a retried `start` reports it. The vote keeps `after_id`.
    undecided: true,
  });
  const closesAt = now + VOTE_MS;
  const voteId = await ctx.db.insert("companion_votes", {
    home_id: home._id,
    poll_id: pollId,
    companion_id: companionId,
    after_id: graduated._id,
    options,
    status: "open",
    opened_at: now,
    closes_at: closesAt,
  });
  await ctx.db.patch(companionId, { vote_id: voteId });
  await wakeAtFloor(ctx, companionId, now);
  await ctx.db.patch(house._id, { current_id: companionId, updated: now });
  await ctx.scheduler.runAt(closesAt, internal.companion.closeVote, { voteId });
  await announce(ctx, (await ctx.db.get(companionId))!, "vote", userId);
  return pollId;
}

/**
 * Gives a seed its species: the vote's winner, or somebody's pick. Exactly
 * `start`'s rule — only what the house can grow today — so nothing the vote
 * offered can start once it has gone out of season, and nothing `start` would
 * refuse starts here. The growth so far stays; the stages are measured again
 * for what it turned out to be, and paid once per slot as ever.
 */
async function chooseSeed(
  ctx: MutationCtx,
  house: Doc<"companion_homes">,
  seed: Doc<"companions">,
  species: string,
  userId: Id<"users"> | undefined,
  now: number,
): Promise<{ leaves: number; sparkles: number } | null> {
  if (!SPECIES.has(species)) throw new Error("There's no such companion");
  if (!isUsable(standingOfSpecies(species, shopContext(house, now)))) {
    throw new Error("That one can't be grown yet");
  }
  const stage = stageFor(seed.points, isPetSpecies(species));
  await ctx.db.patch(seed._id, {
    species,
    undecided: undefined,
    chosen_at: now,
    paid_stage: Math.max(stage, seed.paid_stage),
  });
  if (stage > seed.paid_stage) await payStages(ctx, house._id, seed._id, seed.paid_stage, stage);
  const welcome = await welcomeIfNew(ctx, house, userId, seed._id);
  // A seed left undecided long enough is all grown up the moment it is
  // chosen. Then "ready" says both, and "arrived" is marked with it rather
  // than sent a second later.
  await announceReady(ctx, seed._id, ["arrived"]);
  return welcome;
}

/** "The new one's here": only where there was a vote to wait on. */
async function announceArrived(
  ctx: MutationCtx,
  seedId: Id<"companions">,
  home: Doc<"homes">,
  actor: Id<"users"> | undefined,
): Promise<void> {
  if ((home.members ?? []).length < 2) return;
  const seed = await ctx.db.get(seedId);
  if (seed) await announce(ctx, seed, "arrived", actor);
}

async function closePoll(ctx: MutationCtx, pollId: Id<"polls">, now: number): Promise<void> {
  const poll = await ctx.db.get(pollId);
  if (poll && poll.status !== "closed") await ctx.db.patch(pollId, { status: "closed", updated: now });
}

/**
 * Ends a vote and applies what it chose. Idempotent: a vote already closed
 * answers with what it chose and writes nothing, so two phones finishing it at
 * once, the deadline landing as the last ballot does, or a retried `decide`
 * all come to one choice — Convex runs the two writes one after the other,
 * and the second finds the first's `closed`.
 *
 * The winner is the most yeses among current members (`ranking`), the first
 * of them the house can still grow. No yes at all closes it with no winner:
 * the seed keeps growing and the first person to pick, picks.
 */
async function resolveVote(
  ctx: MutationCtx,
  vote: Doc<"companion_votes">,
  how: Infer<typeof voteHow>,
  actor: Id<"users"> | undefined,
): Promise<{ winner: string | null }> {
  if (vote.status !== "open") return { winner: vote.winner ?? null };
  const now = Date.now();
  const [seed, house, home] = await Promise.all([
    ctx.db.get(vote.companion_id),
    houseFor(ctx, vote.home_id),
    ctx.db.get(vote.home_id),
  ]);
  const close = async (patch: Partial<Doc<"companion_votes">>) => {
    await ctx.db.patch(vote._id, { status: "closed", closed_at: now, closed_by: actor, ...patch });
    await closePoll(ctx, vote.poll_id, now);
  };
  if (!seed || !house || !home || house.current_id !== seed._id || seed.status !== "growing" || !seed.undecided) {
    await close({ how: "moved" });
    return { winner: null };
  }
  const ballots = await ctx.db
    .query("poll_votes")
    .withIndex("by_poll", (q) => q.eq("poll_id", vote.poll_id))
    .take(VOTE_ROWS_MAX);
  const ranked = ranking(vote.options, tally(vote.options, ballots, home.members), new Set(house.grown_species ?? []));
  const shop = shopContext(house, now);
  const winner = ranked.find((id) => isUsable(standingOfSpecies(id, shop))) ?? null;
  await close({ how, winner: winner ?? undefined });
  if (winner) {
    await chooseSeed(ctx, house, seed, winner, actor, now);
    await announceArrived(ctx, seed._id, home, actor);
  }
  return { winner };
}

/**
 * Settles the vote now on the ballots so far — for the one who'd rather not
 * wait. Not a way round anyone: every answer already given counts exactly as
 * it would at the deadline, and with no yes yet there is nothing to settle
 * (`noVotes`, and it stays open). The feed names who settled it.
 *
 * Only once somebody else has answered (`alone` before that, still open).
 * Settling a vote nobody else has touched is picking, and `start` already
 * does that honestly, as a pick. A minimum age would only make the one who's
 * there wait, and protect nobody.
 */
export const decide = mutation({
  args: { homeId: v.id("homes") },
  returns: v.object({
    status: v.union(
      v.literal("chosen"),
      v.literal("noVotes"),
      v.literal("alone"),
      v.literal("closed"),
      v.literal("none"),
    ),
    winner: v.union(v.string(), v.null()),
  }),
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    const house = await houseFor(ctx, homeId);
    const seed = house?.current_id ? await ctx.db.get(house.current_id) : null;
    const vote = seed?.vote_id ? await ctx.db.get(seed.vote_id) : null;
    if (!vote) return { status: "none" as const, winner: null };
    if (vote.status === "closed") return { status: "closed" as const, winner: vote.winner ?? null };
    const ballots = await ctx.db
      .query("poll_votes")
      .withIndex("by_poll", (q) => q.eq("poll_id", vote.poll_id))
      .take(VOTE_ROWS_MAX);
    const members = new Set<string>(home.members);
    if (!ballots.some((b) => b.user_id !== user._id && members.has(b.user_id))) {
      return { status: "alone" as const, winner: null };
    }
    const counts = tally(vote.options, ballots, home.members);
    if (![...counts.values()].some((c) => c.yes > 0)) return { status: "noVotes" as const, winner: null };
    const { winner } = await resolveVote(ctx, vote, "decided", user._id);
    return winner ? { status: "chosen" as const, winner } : { status: "closed" as const, winner: null };
  },
});

/** Closes the vote if every current member has answered every option. */
async function closeIfEveryone(
  ctx: MutationCtx,
  vote: Doc<"companion_votes"> | null,
  actor: Id<"users"> | undefined,
): Promise<void> {
  if (!vote || vote.status !== "open") return;
  const home = await ctx.db.get(vote.home_id);
  if (!home) return;
  const ballots = await ctx.db
    .query("poll_votes")
    .withIndex("by_poll", (q) => q.eq("poll_id", vote.poll_id))
    .take(VOTE_ROWS_MAX);
  if (answeredAll(vote.options, ballots, home.members) >= home.members.length) {
    await resolveVote(ctx, vote, "everyone", actor);
  }
}

/**
 * After a ballot that changed something (`polls:vote` schedules it): closes
 * the vote once every current member has answered every option.
 */
export const voteChanged = internalMutation({
  args: { pollId: v.id("polls"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { pollId, userId }) => {
    const vote = await ctx.db
      .query("companion_votes")
      .withIndex("by_poll", (q) => q.eq("poll_id", pollId))
      .first();
    await closeIfEveryone(ctx, vote, userId);
    return null;
  },
});

/**
 * After someone leaves the house (`homes:leave` schedules it): the one still
 * to answer may have been them, so "everyone" is asked again of who is left.
 */
export const membersChanged = internalMutation({
  args: { homeId: v.id("homes") },
  returns: v.null(),
  handler: async (ctx, { homeId }) => {
    const house = await houseFor(ctx, homeId);
    const seed = house?.current_id ? await ctx.db.get(house.current_id) : null;
    const vote = seed?.vote_id ? await ctx.db.get(seed.vote_id) : null;
    await closeIfEveryone(ctx, vote, undefined);
    return null;
  },
});

/** The deadline, scheduled once by `openVote`. A no-op on a vote already closed. */
export const closeVote = internalMutation({
  args: { voteId: v.id("companion_votes") },
  returns: v.null(),
  handler: async (ctx, { voteId }) => {
    const vote = await ctx.db.get(voteId);
    if (!vote || vote.status !== "open") return null;
    if (Date.now() < vote.closes_at) {
      await ctx.scheduler.runAt(vote.closes_at, internal.companion.closeVote, { voteId });
      return null;
    }
    await resolveVote(ctx, vote, "deadline", undefined);
    return null;
  },
});

// MARK: - The house's writes

const placeArgs = {
  /** Minutes east of UTC on this phone. Used only if this call makes the house's row. */
  tzOffset: v.optional(v.number()),
  /** The phone's region. Used only if this call makes the house's row. */
  region: v.optional(v.union(v.string(), v.null())),
};

/**
 * Where the house is: its offset (whose days growth is counted in) and its
 * region (the default holidays, which way round the seasons go).
 *
 * The only thing that moves either once the house has a row, and at most once
 * a day — a phone travelling does not move the house, and the house's days
 * cannot be shifted back and forth to make more of them. Call it when the
 * house has none (`tzOffset` null in `forHome`) or when somebody changes it on
 * purpose. `changed` is false when nothing moved, or it moved too recently.
 */
export const setPlace = mutation({
  args: {
    homeId: v.id("homes"),
    tzOffset: v.optional(v.number()),
    region: v.optional(v.union(v.string(), v.null())),
  },
  returns: v.object({ changed: v.boolean() }),
  handler: async (ctx, { homeId, tzOffset, region }) => {
    await requireHomeMember(ctx, homeId);
    const nextRegion = cleanRegion(region);
    const nextTz = cleanOffset(tzOffset);
    if (nextRegion === undefined && nextTz === undefined) return { changed: false };
    const house = await houseFor(ctx, homeId);
    if (!house) {
      await ensureHouse(ctx, homeId, { tzOffset, region });
      return { changed: true };
    }
    const patch: Partial<Doc<"companion_homes">> = {};
    if (nextRegion !== undefined && (nextRegion ?? undefined) !== house.region) patch.region = nextRegion ?? undefined;
    if (nextTz !== undefined && nextTz !== house.tz_offset) patch.tz_offset = nextTz;
    if (Object.keys(patch).length === 0) return { changed: false };
    const now = Date.now();
    // Filling in what the house never had is not a move; changing it is, and
    // waits: a day for the offset, thirty for the region. A field still
    // cooling down is left as it is; the other may move on its own.
    const regionMoves = "region" in patch && house.region !== undefined;
    const tzMoves = "tz_offset" in patch && house.tz_offset !== undefined;
    if (regionMoves && house.region_set_at !== undefined && now - house.region_set_at < REGION_COOLDOWN_MS) {
      delete patch.region;
    }
    if (tzMoves && house.place_set_at !== undefined && now - house.place_set_at < PLACE_COOLDOWN_MS) {
      delete patch.tz_offset;
    }
    if (Object.keys(patch).length === 0) return { changed: false };
    await ctx.db.patch(house._id, {
      ...patch,
      ...("tz_offset" in patch ? { place_set_at: now } : {}),
      ...("region" in patch ? { region_set_at: now } : {}),
      updated: now,
    });
    return { changed: true };
  },
});

/**
 * Starts growing one: chosen on Choose, or straight after it was bought there.
 *
 * Only what the house can grow today (`Standing.isUsable`): every house's,
 * bought, earned, or in its season. Choosing again before anything graduates
 * lets the one growing go, as on the phone. The house's first comes with the
 * welcome gift, once, keyed `welcome`.
 *
 * One that is ready to graduate is never let go: it graduates first, in this
 * same write, paid exactly as `graduate` pays it, and then the new one starts
 * in the next album slot. That is the case where a phone's `graduate` failed
 * and it moved on to Choose anyway, or a second phone chose while the first
 * was still in the ceremony; either way the house grew it, and losing the
 * album card and the reward for a tap order would be the server's mistake,
 * not the household's. `graduated` says it happened, so the phone can show
 * the card. A later `graduate` for it finds it graduated and pays nothing.
 * The species is checked against the house after that graduation, so what
 * it earns (a graduation count, "grown them all") counts for this choice.
 */
export const start = mutation({
  args: {
    homeId: v.id("homes"),
    species: v.string(),
    /**
     * The tap's id. A retry with the same one, while what it started is still
     * the house's current, returns the first answer and starts nothing.
     */
    requestId: v.optional(v.string()),
    ...placeArgs,
  },
  returns: v.object({
    companionId: v.id("companions"),
    /** The welcome gift landed with this one. */
    welcome: v.union(coinsValue, v.null()),
    /** The one that was ready, graduated by this call before the new one started. */
    graduated: v.union(
      v.object({
        companionId: v.id("companions"),
        species: v.string(),
        paid: v.union(coinsValue, v.null()),
      }),
      v.null(),
    ),
  }),
  handler: async (ctx, { homeId, species, requestId, tzOffset, region }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);
    if (!SPECIES.has(species)) throw new Error("There's no such companion");
    let house = await ensureHouse(ctx, homeId, { tzOffset, region });
    const now = Date.now();
    const request = requestId?.trim().slice(0, 128) || undefined;

    const previous = house.current_id ? await ctx.db.get(house.current_id) : null;
    // A retry of the call that started the one growing: the same answer,
    // nothing released, nothing started, nothing paid again.
    if (request !== undefined && previous?.start_request === request) {
      const followed = previous.follows ? await ctx.db.get(previous.follows) : null;
      return {
        companionId: previous._id,
        welcome: null,
        graduated: followed ? { companionId: followed._id, species: followed.species, paid: null } : null,
      };
    }
    // A seed the house hasn't chosen yet: this is the choice, and it keeps
    // the growth since the last one graduated. While its vote is open that is
    // a straight pick only until somebody else has answered; after that the
    // ballots decide (`decide`), and no answer is ever thrown away.
    if (previous?.status === "growing" && previous.undecided) {
      const home = await ctx.db.get(homeId);
      const vote = previous.vote_id ? await ctx.db.get(previous.vote_id) : null;
      if (home && vote?.status === "open") {
        const ballots = await ctx.db
          .query("poll_votes")
          .withIndex("by_poll", (q) => q.eq("poll_id", vote.poll_id))
          .take(VOTE_ROWS_MAX);
        const members = new Set<string>(home.members);
        if (ballots.some((b) => b.user_id !== user._id && members.has(b.user_id))) {
          throw new Error("The house is voting on the next one");
        }
        await ctx.db.patch(vote._id, {
          status: "closed",
          closed_at: now,
          how: "picked",
          winner: species,
          closed_by: user._id,
        });
        await closePoll(ctx, vote.poll_id, now);
      }
      const welcome = await chooseSeed(ctx, house, previous, species, user._id, now);
      await ctx.db.patch(previous._id, { start_request: request });
      if (home) await announceArrived(ctx, previous._id, home, user._id);
      return { companionId: previous._id, welcome, graduated: null };
    }
    // What the house voted for stays until it graduates. A pick that lands
    // after the vote chose — a phone that was offline, a Choose screen left
    // open — agrees with it (same answer, nothing written) or is refused;
    // it never lets the vote's choice go. A "picked" seed was one person's
    // choice before anyone else answered, and can change like any pick. Once
    // it is ready, `start` graduates it first as always.
    if (previous?.status === "growing" && previous.vote_id && !readiness(house, previous, now).isReady) {
      const vote = await ctx.db.get(previous.vote_id);
      if (vote?.status === "closed" && vote.winner !== undefined && vote.how !== "picked") {
        if (species !== previous.species) throw new Error("The house already chose");
        return { companionId: previous._id, welcome: null, graduated: null };
      }
    }
    // Without an id: a double tap, or two phones choosing the same one at once.
    // A seed counts from when it was chosen, not from when it was planted.
    if (
      previous?.status === "growing" &&
      previous.species === species &&
      now - (previous.chosen_at ?? previous.created) < 10_000
    ) {
      return { companionId: previous._id, welcome: null, graduated: null };
    }
    let graduated: { companionId: Id<"companions">; species: string; paid: { leaves: number; sparkles: number } | null } | null =
      null;
    if (previous && readiness(house, previous, now).isReady) {
      const { paid } = await graduateNow(ctx, house, previous, user._id, now);
      graduated = { companionId: previous._id, species: previous.species, paid };
      house = (await ctx.db.get(house._id))!;
    } else if (previous?.status === "growing") {
      await ctx.db.patch(previous._id, { status: "released" });
    }
    // Checked after any graduation; a refusal throws, which undoes it too.
    if (!isUsable(standingOfSpecies(species, shopContext(house, now)))) {
      throw new Error("That one can't be grown yet");
    }

    const companionId = await ctx.db.insert("companions", {
      home_id: homeId,
      uuid: crypto.randomUUID().toUpperCase(),
      species,
      seed: `${homeId}-${house.album_count}`,
      started_at: now,
      status: "growing",
      points: 0,
      paid_stage: 0,
      tz_offset: house.tz_offset ?? 0,
      origin: "server",
      created: now,
      start_request: request,
      follows: graduated?.companionId,
    });
    // Its one wake, at the floor.
    await wakeAtFloor(ctx, companionId, now);
    await ctx.db.patch(house._id, { current_id: companionId, updated: now });

    const welcome = await welcomeIfNew(ctx, house, user._id, companionId);
    return { companionId, welcome, graduated };
  },
});

/**
 * Water or pet it. Counts once per person per day, for the care track; every
 * other tap is the phone's own reaction and writes nothing.
 */
export const care = mutation({
  args: { homeId: v.id("homes") },
  returns: v.object({ counted: v.boolean() }),
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);
    const house = await houseFor(ctx, homeId);
    const companion = house?.current_id ? await ctx.db.get(house.current_id) : null;
    if (!house || !companion || companion.status !== "growing") return { counted: false };

    const now = Date.now();
    const tz = tzOf(companion, house);
    const day = dayOf(now, tz);
    const key = `care:${companion._id}:${user._id}:${day}`;
    const days = await putEntry(ctx, companion, tz, { key, kind: "care", at: now, userId: user._id, weight: 1, keepAt: true });
    // The mood reads the last care, so a later tap the same day still says
    // someone came by — a minute apart, not on every tap of a happy burst.
    if (days.length || now - (companion.last_care_at ?? 0) > 60_000) {
      await ctx.db.patch(companion._id, { last_care_at: now });
    }
    if (days.length) await recount(ctx, companion._id, house, days);
    return { counted: days.length > 0 };
  },
});

/**
 * The ceremony's end: into the album, the graduation into the jar, and the
 * house free to choose the next. Idempotent: a second call finds it graduated.
 */
export const graduate = mutation({
  args: { homeId: v.id("homes"), companionId: v.id("companions") },
  returns: v.object({
    paid: v.union(coinsValue, v.null()),
    /**
     * The vote for the next one this opened, in a house of two or more; then
     * the next one is already growing as a seed (`forHome.current.undecided`).
     * `null`: this house just picks (`start`), as before. Absent from a
     * repeat call, which opens nothing.
     */
    vote: v.optional(v.union(v.id("polls"), v.null())),
  }),
  handler: async (ctx, { homeId, companionId }) => {
    const user = await requireUser(ctx);
    const home = await requireHomeMember(ctx, homeId);
    const companion = await ctx.db.get(companionId);
    if (!companion || companion.home_id !== homeId) throw new Error("Companion not found");
    await requireDocHome(ctx, companion, "Companion");
    if (companion.status === "graduated") return { paid: null };
    const house = await ensureHouse(ctx, homeId);
    const now = Date.now();
    // The points, the six-day floor, and only the one growing: one let go
    // can't be brought back for a second reward.
    if (!readiness(house, companion, now).isReady) throw new Error("Not grown up yet");
    const { paid } = await graduateNow(ctx, house, companion, user._id, now);
    const vote = await openVote(ctx, home, companion, user._id, now);
    return { paid, vote };
  },
});

/**
 * Decorate's Done. Keeps what fits each spot and what the house can put out
 * today — bought, every house's, or brought by today's holidays — and drops
 * the rest, exactly as the phone does before it saves. Returns what was kept.
 *
 * The party hat is let through on any day: whether today is somebody's
 * birthday is the calendar's to say, and every phone already hides it on the
 * days it isn't.
 */
export const setLayout = mutation({
  args: { homeId: v.id("homes"), layout: layoutArg },
  returns: layoutValue,
  handler: async (ctx, { homeId, layout }) => {
    await requireHomeMember(ctx, homeId);
    const house = await ensureHouse(ctx, homeId);
    const kept = cleanLayout(layout, availableDecor(shopContext(house, Date.now(), { isBirthday: true })));
    await ctx.db.patch(house._id, { layout: kept, updated: Date.now() });
    return kept;
  },
});

/** Our holidays. `null` goes back to the region's defaults. Unknown ids are dropped. */
export const setHolidays = mutation({
  args: { homeId: v.id("homes"), holidays: v.union(v.array(v.string()), v.null()) },
  returns: v.union(v.array(v.string()), v.null()),
  handler: async (ctx, { homeId, holidays }) => {
    await requireHomeMember(ctx, homeId);
    const house = await ensureHouse(ctx, homeId);
    const chosen = holidays === null ? undefined : inCatalogOrder(holidays);
    await ctx.db.patch(house._id, { holidays: chosen, updated: Date.now() });
    return chosen ?? null;
  },
});

function inCatalogOrder(ids: string[]): string[] {
  const wanted = new Set(ids);
  return CATALOG.holidays.map((h) => h.id).filter((id) => wanted.has(id));
}

// MARK: - Bringing a phone's MVP file to the house

const importedCompanion = v.object({
  species: v.string(),
  seed: v.string(),
  startedAt: v.number(),
  careDays: v.optional(v.array(v.string())),
});

const importedGraduate = v.object({
  id: v.string(),
  species: v.string(),
  seed: v.string(),
  startedAt: v.number(),
  graduatedAt: v.number(),
});

/**
 * One test phone's MVP file, `companion-<home>.json`, merged into the house.
 *
 * The MVP only ever ran on Debug builds, so the honest callers are a few test
 * phones: the admins (`lib/admin.ts`) and the ids in
 * `COMPANION_IMPORT_USER_IDS`. Anybody else, and anybody after
 * `IMPORT_SUNSET`, gets `closed`. Once per person per house.
 *
 * Even then a file is a phone's word, taken only as far as the house could
 * really have got, with the same house whichever phone comes first:
 *
 * - **No Sparkles, ever, and nothing priced in them.** The MVP's Sparkles were
 *   free tests; real ones are money.
 * - **Leaves** are capped at what the file could have earned — the welcome
 *   (unless the house already had it here), six stages and a graduation per
 *   album card accepted, and the paid stages of the one growing — and credited
 *   only above the most any import has brought (`import_max_leaves`), so
 *   imports come to the largest, never a sum.
 * - **What was bought**: the union of Leaves-priced things only.
 * - **The album**: cards that could have been grown — at least six days each,
 *   none overlapping another card or the one the house is growing, and no
 *   more of them than six-day runs fit since the MVP began.
 * - **The one growing**: the earliest started, its start clamped to the MVP's
 *   first day, if the house could grow it today (checked before this file's
 *   purchases count) and it started after the album's last card. A later
 *   phone replaces one an import made, never one chosen on the server. Its
 *   scene comes with it.
 * - **Holidays**: the union with what the house keeps now, defaults included.
 * - **Care days** from the last fortnight only. The lab stays on the phone.
 *
 * Growth is recounted from the chores since the one growing started, so an
 * imported companion may land at a lower stage than the phone showed: the
 * server's curve is the truth. Stages already paid are never paid again or
 * taken back.
 */
export const importLocal = mutation({
  args: {
    homeId: v.id("homes"),
    current: v.optional(v.union(importedCompanion, v.null())),
    album: v.optional(v.array(importedGraduate)),
    leaves: v.optional(v.number()),
    sparkles: v.optional(v.number()),
    welcomed: v.optional(v.boolean()),
    owned: v.optional(v.array(v.string())),
    ownedSpecies: v.optional(v.array(v.string())),
    layout: v.optional(layoutArg),
    holidays: v.optional(v.union(v.array(v.string()), v.null())),
    paidStage: v.optional(v.number()),
    ...placeArgs,
  },
  returns: v.object({
    status: v.union(v.literal("imported"), v.literal("already"), v.literal("closed")),
    current: v.union(v.literal("created"), v.literal("replaced"), v.literal("kept"), v.literal("none")),
    album: v.number(),
  }),
  handler: async (
    ctx,
    args,
  ): Promise<{
    status: "imported" | "already" | "closed";
    current: "created" | "replaced" | "kept" | "none";
    album: number;
  }> => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, args.homeId);
    const now = Date.now();
    const closed = { status: "closed" as const, current: "none" as const, album: 0 };
    if (now >= IMPORT_SUNSET || !mayImport(user)) return closed;

    const key = `import:${user._id}`;
    const seen = await ctx.db
      .query("jar_ledger")
      .withIndex("by_home_key", (q) => q.eq("home_id", args.homeId).eq("key", key))
      .first();
    if (seen) return { status: "already", current: "none", album: 0 };

    let house = await ensureHouse(ctx, args.homeId, { tzOffset: args.tzOffset, region: args.region });
    const tz = house.tz_offset ?? 0;
    const honest = (at: number) => Number.isFinite(at) && at >= IMPORT_EPOCH && at <= now;
    const wasWelcomed = house.welcomed;

    // What the house is growing now, if the server chose it: the album can't
    // have grown another beside it.
    const currentDoc = house.current_id ? await ctx.db.get(house.current_id) : null;
    const growing = currentDoc?.status === "growing" ? currentDoc : null;

    // The album: cards that could have been grown, one at a time.
    const existing = await ctx.db
      .query("companions")
      .withIndex("by_home_status_graduated", (q) => q.eq("home_id", args.homeId).eq("status", "graduated"))
      .take(ALBUM_MAX);
    const spans: (readonly [number, number])[] = existing.map((c) => [c.started_at, c.graduated_at ?? c.started_at] as const);
    const blocked = growing && growing.origin === "server" ? [[growing.started_at, now] as const] : [];
    let room = Math.floor((now - IMPORT_EPOCH) / MIN_GROW_MS) - house.album_count;
    let added = 0;
    const grown = new Set(house.grown_species ?? []);
    const incomingAlbum = [...(args.album ?? [])].slice(0, ALBUM_MAX).sort((a, b) => a.startedAt - b.startedAt);
    for (const g of incomingAlbum) {
      if (room <= 0) break;
      if (!SPECIES.has(g.species) || !honest(g.startedAt) || !honest(g.graduatedAt)) continue;
      if (g.graduatedAt - g.startedAt < MIN_GROW_MS) continue;
      if ([...spans, ...blocked].some(([s, e]) => g.startedAt < e && s < g.graduatedAt)) continue;
      const uuid = g.id.trim().toUpperCase().slice(0, 64);
      if (!uuid) continue;
      const duplicate = await ctx.db
        .query("companions")
        .withIndex("by_home_uuid", (q) => q.eq("home_id", args.homeId).eq("uuid", uuid))
        .first();
      if (duplicate) continue;
      await ctx.db.insert("companions", {
        home_id: args.homeId,
        uuid,
        species: g.species,
        seed: g.seed.slice(0, 120),
        started_at: g.startedAt,
        status: "graduated",
        graduated_at: g.graduatedAt,
        points: CATALOG.graduateAt,
        paid_stage: stageFor(CATALOG.graduateAt, isPetSpecies(g.species)),
        origin: "import",
        created: now,
      });
      spans.push([g.startedAt, g.graduatedAt]);
      grown.add(g.species);
      added++;
      room--;
    }
    const lastGraduation = spans.reduce((latest, [, e]) => Math.max(latest, e), 0);

    // The one growing, judged against the house as it was — before this
    // file's purchases count — so a file can't grant itself a species and then
    // pass the check with it.
    if (added > 0) {
      await ctx.db.patch(house._id, {
        album_count: house.album_count + added,
        grown_species: [...grown].sort(),
        updated: now,
      });
      house = (await ctx.db.get(house._id))!;
    }
    const incoming = args.current ?? null;
    const startedAt = incoming ? Math.min(Math.max(incoming.startedAt, IMPORT_EPOCH), now) : 0;
    const growable =
      incoming !== null &&
      SPECIES.has(incoming.species) &&
      Number.isFinite(incoming.startedAt) &&
      startedAt >= lastGraduation &&
      isUsable(standingOfSpecies(incoming.species, shopContext(house, now)));
    const stageCount = incoming && SPECIES.has(incoming.species) ? stageFor(CATALOG.graduateAt, isPetSpecies(incoming.species)) : 0;
    const sentStage = args.paidStage !== undefined && Number.isFinite(args.paidStage) ? Math.floor(args.paidStage) : 0;
    const paidStage = growable ? Math.min(Math.max(sentStage, 0), stageCount) : 0;

    // What was bought: Leaves-priced things only. Then the days kept.
    const ownedDecor = new Set(house.owned_decor);
    for (const id of args.owned ?? []) {
      const access = DECOR.get(id)?.access;
      if (access?.type === "buy" && access.price.currency === "leaves") ownedDecor.add(id);
    }
    const ownedSpecies = new Set(house.owned_species);
    for (const id of args.ownedSpecies ?? []) {
      const access = SPECIES.get(id)?.access;
      if (access?.type === "buy" && access.price.currency === "leaves") ownedSpecies.add(id);
    }
    let holidays = house.holidays;
    if (args.holidays) {
      const incomingDays = args.holidays.filter((id) => HOLIDAYS.has(id));
      holidays = inCatalogOrder([...keptHolidays(house), ...incomingDays]);
    }

    // Leaves, capped at what the file could have earned, above the mark.
    const rewards = CATALOG.rewards;
    const earnable =
      (args.welcomed && !wasWelcomed ? rewards.welcome.leaves : 0) +
      added * (6 * rewards.stage.leaves + rewards.graduation.leaves) +
      paidStage * rewards.stage.leaves;
    const sent = args.leaves !== undefined && Number.isFinite(args.leaves) ? Math.max(Math.floor(args.leaves), 0) : 0;
    const sentLeaves = Math.min(sent, earnable);
    const markLeaves = house.import_max_leaves ?? 0;

    await ctx.db.patch(house._id, {
      owned_decor: [...ownedDecor],
      owned_species: [...ownedSpecies],
      holidays,
      welcomed: house.welcomed || (args.welcomed ?? false),
      import_max_leaves: Math.max(markLeaves, sentLeaves),
      updated: now,
    });
    // Recorded even when nothing moves: the row is this person's import, once.
    await moveJar(ctx, house._id, {
      key,
      kind: "import",
      leaves: Math.max(sentLeaves - markLeaves, 0),
      sparkles: 0,
      userId: user._id,
    });
    house = (await ctx.db.get(house._id))!;

    let outcome: "created" | "replaced" | "kept" | "none" = "none";
    if (incoming && growable) {
      let companionId: Id<"companions"> | null = null;
      if (!growing) {
        companionId = await ctx.db.insert("companions", {
          home_id: args.homeId,
          uuid: crypto.randomUUID().toUpperCase(),
          species: incoming.species,
          seed: incoming.seed.slice(0, 120),
          started_at: startedAt,
          status: "growing",
          points: 0,
          paid_stage: paidStage,
          tz_offset: tz,
          origin: "import",
          created: now,
        });
        outcome = "created";
      } else if (growing.origin === "import" && startedAt < growing.started_at) {
        await ctx.db.patch(growing._id, {
          species: incoming.species,
          seed: incoming.seed.slice(0, 120),
          started_at: startedAt,
          paid_stage: Math.max(growing.paid_stage, paidStage),
          tz_offset: growing.tz_offset ?? tz,
        });
        companionId = growing._id;
        outcome = "replaced";
      } else {
        outcome = "kept";
      }

      if (companionId) {
        // The stages the file was paid for are paid in this slot: marked, at
        // nothing, so the slot never pays them again.
        await payStages(ctx, house._id, companionId, 0, paidStage, { free: true });
        const patch: Partial<Doc<"companion_homes">> = { current_id: companionId };
        if (args.layout) {
          patch.layout = cleanLayout(args.layout, availableDecor(shopContext(house, now, { isBirthday: true })));
        }
        await ctx.db.patch(house._id, patch);

        // The fortnight's care days, as this person's.
        const companion = (await ctx.db.get(companionId))!;
        // Created, or its start moved: its one wake, at the new floor (a wake
        // pinned to the old start finds it moved and does nothing).
        await wakeAtFloor(ctx, companion._id, companion.started_at);
        const ctz = companion.tz_offset ?? tz;
        const today = dayOf(now, ctz);
        const earliest = [dayOf(companion.started_at, ctz), addDays(today, -(IMPORT_CARE_DAYS - 1))].sort()[1];
        const days: string[] = [];
        for (const day of new Set(incoming.careDays ?? [])) {
          if (!isDay(day) || day < earliest || day > today) continue;
          days.push(
            ...(await putEntry(ctx, companion, ctz, {
              key: `care:${companion._id}:${user._id}:${day}`,
              kind: "care",
              at: Math.min(Math.max(dayStart(day, ctz) + 12 * HOUR_MS, companion.started_at), now),
              userId: user._id,
              weight: 1,
              keepAt: true,
            })),
          );
        }
        if (days.length) await recount(ctx, companion._id, (await ctx.db.get(house._id))!, days);
        // And the chores since it started, a page at a time.
        await ctx.scheduler.runAfter(0, internal.companion.reconcile, {
          homeId: args.homeId,
          source: { kind: "backfill", companionId, startedAt: companion.started_at },
        });
      }
    } else if (args.layout && isEmptyLayout(house.layout)) {
      // No companion came with this file, but its scene may be the house's only one.
      await ctx.db.patch(house._id, {
        layout: cleanLayout(args.layout, availableDecor(shopContext(house, now, { isBirthday: true }))),
      });
    }

    return { status: "imported", current: outcome, album: added };
  },
});

/** The test phones: the admins, and anyone listed in `COMPANION_IMPORT_USER_IDS`. */
function mayImport(user: Doc<"users">): boolean {
  if (isAdminUser(user)) return true;
  const listed = (process.env.COMPANION_IMPORT_USER_IDS ?? "").split(/[\s,]+/).filter(Boolean);
  return listed.includes(user._id);
}

// MARK: - The growth ledger

type Entry = {
  key: string;
  kind: Infer<typeof growthKind>;
  at: number;
  userId?: Id<"users">;
  weight: number;
  titleKey?: string;
  /** Keep the time first credited: for things whose own row has no clean timestamp. */
  keepAt?: boolean;
};

async function entryFor(ctx: MutationCtx, companion: Doc<"companions">, key: string) {
  return await ctx.db
    .query("companion_growth")
    .withIndex("by_companion_key", (q) => q.eq("companion_id", companion._id).eq("key", key))
    .first();
}

/**
 * Credits one thing to the companion growing now. Returns the days whose
 * tally changed. A thing done before it arrived is not its to count, and a
 * graduate's credits are its own: they are never moved or touched.
 */
async function putEntry(
  ctx: MutationCtx,
  companion: Doc<"companions">,
  tz: number,
  entry: Entry,
): Promise<string[]> {
  const existing = await entryFor(ctx, companion, entry.key);
  const at = entry.keepAt && existing ? existing.at : entry.at;
  if (at < companion.started_at) return await dropEntry(ctx, companion, entry.key);
  const day = dayOf(at, tz);

  if (existing) {
    if (
      existing.day === day &&
      existing.at === at &&
      existing.weight === entry.weight &&
      existing.user_id === entry.userId &&
      existing.title_key === entry.titleKey
    ) {
      return [];
    }
    await ctx.db.patch(existing._id, {
      kind: entry.kind,
      day,
      at,
      user_id: entry.userId,
      weight: entry.weight,
      title_key: entry.titleKey,
    });
    return [existing.day, day];
  }
  await ctx.db.insert("companion_growth", {
    home_id: companion.home_id,
    companion_id: companion._id,
    key: entry.key,
    kind: entry.kind,
    day,
    at,
    user_id: entry.userId,
    weight: entry.weight,
    title_key: entry.titleKey,
  });
  return [day];
}

/** Takes a credit back from the one growing. */
async function dropEntry(ctx: MutationCtx, companion: Doc<"companions">, key: string): Promise<string[]> {
  const existing = await entryFor(ctx, companion, key);
  if (!existing) return [];
  await ctx.db.delete(existing._id);
  return [existing.day];
}

/** A finished chore's credit: the same weight on the live path and the backfill. */
function choreEntry(task: Doc<"tasks">): Entry | null {
  if (!task.is_completed || task.completed_at === undefined) return null;
  const written = task.created ?? task._creationTime;
  const quick = task.completed_by === task.created_by && task.completed_at - written < QUICK_LOG_MS;
  const base = task.type === "maintenance" ? W_CHORE_MAINT : W_CHORE;
  return {
    key: `task:${task._id}`,
    kind: "chore",
    at: task.completed_at,
    userId: task.completed_by,
    weight: base * (quick ? QUICK_LOG_MULT : 1),
    titleKey: titleKey(task.title),
  };
}

/**
 * Recounts the given days from the ledger, carries the rest bank forward
 * through every later day, moves `points` by the difference, and pays any
 * stage newly reached into the jar.
 *
 * The size of the house is taken as of each day: it is written on the day's
 * row the first time the day is counted and kept on every recount, so a
 * member moving in does not regrow last month.
 */
async function recount(
  ctx: MutationCtx,
  companionId: Id<"companions">,
  house: Doc<"companion_homes">,
  touched: string[],
): Promise<void> {
  const companion = await ctx.db.get(companionId);
  if (!companion || companion.status !== "growing" || touched.length === 0) return;
  const home = await ctx.db.get(companion.home_id);
  const membersNow = Math.max(home?.members.length ?? 1, 1);
  const days = [...new Set(touched)].sort();

  // Each touched day's tally, from its ledger rows.
  for (const day of days) {
    const rows = await ctx.db
      .query("companion_growth")
      .withIndex("by_companion_day", (q) => q.eq("companion_id", companionId).eq("day", day))
      .take(DAY_ROWS_MAX);
    const { raw, carers } = dayTally(rows);
    const row = await ctx.db
      .query("companion_days")
      .withIndex("by_companion_day", (q) => q.eq("companion_id", companionId).eq("day", day))
      .unique();
    if (row) {
      if (row.raw !== raw || row.carers !== carers || row.members === undefined) {
        await ctx.db.patch(row._id, { raw, carers, members: row.members ?? membersNow });
      }
    } else {
      await ctx.db.insert("companion_days", {
        home_id: companion.home_id,
        companion_id: companionId,
        day,
        raw,
        carers,
        paid: 0,
        bank_out: 0,
        growth: 0,
        members: membersNow,
      });
    }
  }

  // The bank, from the day before the first touched one.
  const first = days[0];
  const before = await ctx.db
    .query("companion_days")
    .withIndex("by_companion_day", (q) => q.eq("companion_id", companionId).lt("day", first))
    .order("desc")
    .first();
  const after = await ctx.db
    .query("companion_days")
    .withIndex("by_companion_day", (q) => q.eq("companion_id", companionId).gte("day", first))
    .take(1000);

  let prevDay = before?.day ?? addDays(dayOf(companion.started_at, tzOf(companion, house)), -1);
  let bank = before?.bank_out ?? 0;
  let delta = 0;
  for (const row of after) {
    const bankIn = bankAfterGap(bank, daysBetween(prevDay, row.day) - 1);
    const { paid, bankOut } = bankStep(bankIn, row.raw);
    const growth = lifeGrowth(row.raw + paid, row.members ?? membersNow) + careGrowth(row.carers);
    delta += growth - row.growth;
    if (paid !== row.paid || bankOut !== row.bank_out || growth !== row.growth) {
      await ctx.db.patch(row._id, { paid, bank_out: bankOut, growth });
    }
    bank = bankOut;
    prevDay = row.day;
  }

  const points = Math.max(0, companion.points + delta);
  // An undecided seed's species is only the vote's first option, whose curve
  // may not be the one it turns out to grow on (a pet has more stages, earlier
  // on). It grows, but pays no stage until it is chosen: `chooseSeed` pays up
  // to the real species' stage then.
  const stage = companion.undecided ? companion.paid_stage : stageFor(points, isPetSpecies(companion.species));
  const paidStage = Math.max(stage, companion.paid_stage);
  if (points !== companion.points || paidStage !== companion.paid_stage) {
    await ctx.db.patch(companionId, { points, paid_stage: paidStage });
  }
  if (stage > companion.paid_stage) await payStages(ctx, house._id, companionId, companion.paid_stage, stage);
  if (hasPoints(points) && !(companion.notified ?? []).includes("ready")) await announceReady(ctx, companionId);
}

/**
 * Makes the ledger agree with one credited thing, read back from its own
 * table. Scheduled by `noteGrowth` from the modules that record what a house
 * does, by the event sweep, and by an import.
 */
export const reconcile = internalMutation({
  args: { homeId: v.id("homes"), source: growthSource },
  returns: v.null(),
  handler: async (ctx, { homeId, source }): Promise<null> => {
    const house = await houseFor(ctx, homeId);
    if (!house?.current_id) return null;
    const companion = await ctx.db.get(house.current_id);
    if (!companion || companion.status !== "growing") return null;
    const tz = tzOf(companion, house);
    const now = Date.now();
    const days: string[] = [];
    const put = async (entry: Entry) => days.push(...(await putEntry(ctx, companion, tz, entry)));
    const drop = async (key: string) => days.push(...(await dropEntry(ctx, companion, key)));

    switch (source.kind) {
      case "task": {
        const task = await ctx.db.get(source.id);
        const entry = task && task.home_id === homeId ? choreEntry(task) : null;
        if (entry) await put(entry);
        else await drop(`task:${source.id}`);
        break;
      }

      case "shopping": {
        // One credit per trip, keyed by when it was bought. A slip — an untick
        // soon after the tick — takes that credit back; unticking something
        // bought last week takes nothing, because that trip happened.
        const item = await ctx.db.get(source.id);
        if (!item || item.home_id !== homeId) break;
        const newest = await ctx.db
          .query("companion_growth")
          .withIndex("by_companion_key", (q) =>
            q.eq("companion_id", companion._id).gte("key", `shop:${source.id}:`).lt("key", `shop:${source.id};`),
          )
          .order("desc")
          .first();
        if (!item.is_purchased) {
          if (newest && now - newest.at < UNTICK_GRACE_MS) await drop(newest.key);
          break;
        }
        if (newest && now - newest.at < SAME_TRIP_MS) break;
        const at = Math.min(item.updated ?? now, now);
        await put({ key: `shop:${source.id}:${at}`, kind: "purchase", at, userId: item.updated_by, weight: 1 });
        break;
      }

      case "meal": {
        if (!isDay(source.date)) break;
        const key = `meal:${source.date}`;
        const plan = await ctx.db
          .query("meal_plans")
          .withIndex("by_home_date", (q) => q.eq("home_id", homeId).eq("date", source.date))
          .unique();
        const today = dayOf(now, tz);
        if (!plan) {
          await drop(key);
        } else if (source.date > today || (source.date === today && now < dayStart(today, tz) + DINNER_HOUR * HOUR_MS)) {
          // Not yet evening on its day: the hourly sweep counts it at 17:00
          // there, if it is still the plan then. Nothing is scheduled per
          // write, so planning a month of dinners costs what one does.
        } else if (daysBetween(source.date, today) <= 2) {
          const at = source.date === today ? now : dayStart(source.date, tz) + 19 * HOUR_MS;
          await put({ key, kind: "dinner", at, userId: plan.planned_by, weight: W_DINNER, keepAt: true });
        }
        break;
      }

      case "issue": {
        const key = `fix:${source.id}`;
        const issue = await ctx.db.get(source.id);
        if (!issue || issue.home_id !== homeId || issue.status !== "fixed") {
          await drop(key);
          break;
        }
        const fixedAt = issue.resolved_at ?? now;
        const quick = fixedAt - (issue.created ?? issue._creationTime) < QUICK_FIX_MS;
        await put({
          key,
          kind: "fix",
          at: fixedAt,
          userId: issue.resolved_by,
          weight: (W_FIX[issue.severity] ?? W_FIX.minor) * (quick ? QUICK_FIX_MULT : 1),
        });
        break;
      }

      case "poll": {
        // A movie round counts once the house agrees on something: one title
        // that two people (or the only person) said yes to.
        const key = `poll:${source.id}`;
        const poll = await ctx.db.get(source.id);
        if (!poll || poll.home_id !== homeId || poll.type !== "movie") {
          await drop(key);
          break;
        }
        const home = await ctx.db.get(homeId);
        const need = Math.min(2, Math.max(home?.members.length ?? 1, 1));
        // Read until one title has its yeses, and no further.
        const yes = new Map<string, Set<string>>();
        let agreed = false;
        let read = 0;
        for await (const vote of ctx.db.query("poll_votes").withIndex("by_poll", (q) => q.eq("poll_id", source.id))) {
          if (++read > 5000) break;
          if (!vote.vote) continue;
          const voters = yes.get(vote.target_external_id) ?? new Set<string>();
          voters.add(vote.user_id);
          yes.set(vote.target_external_id, voters);
          if (voters.size >= need) {
            agreed = true;
            break;
          }
        }
        if (agreed) {
          await put({ key, kind: "movie", at: now, userId: poll.owner_id, weight: W_MOVIE, keepAt: true });
        } else {
          await drop(key);
        }
        break;
      }

      case "event": {
        const key = `event:${source.id}:${source.start}`;
        const event = await ctx.db.get(source.id);
        if (!event || event.home_id !== homeId) {
          await drop(key);
          break;
        }
        const end = source.start + Math.max(0, event.ends_at - event.starts_at);
        const happened = eventMath.expand(event, source.start, source.start).includes(source.start);
        if (!happened || end > now) {
          await drop(key);
          break;
        }
        const going = (event.rsvps ?? []).filter((r) => r.status === "going").length;
        const social =
          SOCIAL_EVENTS.has(event.kind ?? "general") || (event.attendees?.length ?? 0) >= 2 || going >= 2;
        await put({
          key,
          kind: "event",
          at: end,
          userId: event.created_by,
          weight: social ? W_EVENT_SOCIAL : W_EVENT_OTHER,
        });
        break;
      }

      case "backfill": {
        // For the companion it was scheduled for only: if the house has moved
        // on, there is nothing left to fill in.
        if (source.companionId !== companion._id || source.startedAt !== companion.started_at) break;
        const page = await ctx.db
          .query("task_completions")
          .withIndex("by_home_at", (q) => q.eq("home_id", homeId).gte("completed_at", companion.started_at))
          .paginate({ cursor: source.cursor ?? null, numItems: BACKFILL_PAGE });
        for (const row of page.page) {
          const task = await ctx.db.get(row.task_id);
          const entry = task && task.home_id === homeId ? choreEntry(task) : null;
          if (entry) await put(entry);
        }
        if (!page.isDone) {
          await ctx.scheduler.runAfter(0, internal.companion.reconcile, {
            homeId,
            source: {
              kind: "backfill",
              companionId: companion._id,
              startedAt: companion.started_at,
              cursor: page.continueCursor,
            },
          });
        }
        break;
      }
    }

    if (days.length) await recount(ctx, companion._id, house, days);
    return null;
  },
});

// MARK: - Events that ended

const occurrenceValue = v.object({ homeId: v.id("homes"), eventId: v.id("events"), start: v.number() });
const dinnerValue = v.object({ homeId: v.id("homes"), date: v.string() });


/**
 * One page of houses growing a companion, and the event occurrences in each
 * that ended inside `(from, to]`. Walks the companions that are growing — not
 * the deployment's events — and each house's own events by `series_end`, so
 * the sweep costs what Nestie's houses hold and nothing else.
 */
export const endedOccurrences = internalQuery({
  args: { from: v.number(), to: v.number(), cursor: v.union(v.string(), v.null()) },
  returns: v.object({
    items: v.array(occurrenceValue),
    dinners: v.array(dinnerValue),
    cursor: v.string(),
    isDone: v.boolean(),
  }),
  handler: async (ctx, { from, to, cursor }) => {
    const page = await ctx.db
      .query("companions")
      .withIndex("by_status", (q) => q.eq("status", "growing"))
      .paginate({ cursor, numItems: SWEEP_PAGE });
    const items: Infer<typeof occurrenceValue>[] = [];
    const dinners: Infer<typeof dinnerValue>[] = [];
    for (const companion of page.page) {
      // Tonight's dinner, once it is evening in the house and not yet counted.
      const house = await houseFor(ctx, companion.home_id);
      if (house?.current_id === companion._id) {
        const tz = tzOf(companion, house);
        const today = dayOf(to, tz);
        const evening = to >= dayStart(today, tz) + DINNER_HOUR * HOUR_MS;
        if (evening) {
          const [plan, counted] = await Promise.all([
            ctx.db
              .query("meal_plans")
              .withIndex("by_home_date", (q) => q.eq("home_id", companion.home_id).eq("date", today))
              .first(),
            ctx.db
              .query("companion_growth")
              .withIndex("by_companion_key", (q) => q.eq("companion_id", companion._id).eq("key", `meal:${today}`))
              .first(),
          ]);
          if (plan && !counted) dinners.push({ homeId: companion.home_id, date: today });
        }
      }

      // Two reads, so a house with many one-offs planned ahead can't push its
      // standing series out: what could only have ended inside the window
      // (one-offs, and series whose last day falls in it), and what runs on
      // past it, longest-running first — `FOREVER` series lead.
      const [endingNow, runningOn] = await Promise.all([
        ctx.db
          .query("events")
          .withIndex("by_home_series_end", (q) =>
            q.eq("home_id", companion.home_id).gt("series_end", from).lte("series_end", to),
          )
          .take(SWEEP_EVENTS_PER_READ),
        ctx.db
          .query("events")
          .withIndex("by_home_series_end", (q) => q.eq("home_id", companion.home_id).gt("series_end", to))
          .order("desc")
          .take(SWEEP_EVENTS_PER_READ),
      ]);
      for (const event of [...endingNow, ...runningOn]) {
        const duration = Math.max(0, event.ends_at - event.starts_at);
        for (const start of eventMath.expand(event, from, to)) {
          const end = start + duration;
          if (end > from && end <= to) items.push({ homeId: event.home_id, eventId: event._id, start });
        }
      }
    }
    return { items, dinners, cursor: page.continueCursor, isDone: page.isDone };
  },
});

/**
 * Hourly: credits every event that ended in the last three hours, and
 * tonight's dinner in every house where it is evening. The window
 * overlaps the last run on purpose; the ledger's key makes a second credit of
 * the same occurrence a no-op, so a late or doubled run loses and repeats
 * nothing.
 */
export const sweepEvents = internalAction({
  args: {},
  returns: v.object({ credited: v.number() }),
  handler: async (ctx): Promise<{ credited: number }> => {
    const to = Date.now();
    const from = to - 3 * HOUR_MS;
    let cursor: string | null = null;
    let credited = 0;
    // One house failing must not cost every house after it its growth: each
    // credit and each page is caught and logged, and the next hour retries
    // whatever was missed (the window overlaps).
    for (;;) {
      let page: {
        items: Infer<typeof occurrenceValue>[];
        dinners: Infer<typeof dinnerValue>[];
        cursor: string;
        isDone: boolean;
      };
      try {
        page = await ctx.runQuery(internal.companion.endedOccurrences, { from, to, cursor });
      } catch (error) {
        console.error("companion sweep: a page failed; stopping until the next hour", error);
        break;
      }
      const credits: { homeId: Id<"homes">; source: Infer<typeof growthSource> }[] = [
        ...page.dinners.map((d) => ({ homeId: d.homeId, source: { kind: "meal" as const, date: d.date } })),
        ...page.items.map((i) => ({
          homeId: i.homeId,
          source: { kind: "event" as const, id: i.eventId, start: i.start },
        })),
      ];
      for (const credit of credits) {
        try {
          await ctx.runMutation(internal.companion.reconcile, credit);
          credited++;
        } catch (error) {
          console.error(`companion sweep: home ${credit.homeId} failed`, credit.source, error);
        }
      }
      if (page.isDone) break;
      cursor = page.cursor;
    }
    return { credited };
  },
});

// MARK: - A house deleted

/**
 * Drains a deleted house's companion rows, a batch per pass, each pass
 * scheduling the next, as `inbox:sweep` drains the feed. `cascadeDeleteHome`
 * deletes the one `companion_homes` row itself and hands the rest here, so
 * leaving a house never waits on, or fails for, a long-lived companion's
 * ledger.
 */
export const purgeHome = internalMutation({
  args: { homeId: v.id("homes") },
  returns: v.object({ deleted: v.number(), done: v.boolean() }),
  handler: async (ctx, { homeId }): Promise<{ deleted: number; done: boolean }> => {
    const batches = [
      () => ctx.db.query("companion_growth").withIndex("by_home", (q) => q.eq("home_id", homeId)).take(PURGE_BATCH),
      () => ctx.db.query("companion_days").withIndex("by_home", (q) => q.eq("home_id", homeId)).take(PURGE_BATCH),
      () =>
        ctx.db
          .query("companions")
          .withIndex("by_home_status_graduated", (q) => q.eq("home_id", homeId))
          .take(PURGE_BATCH),
      () => ctx.db.query("jar_ledger").withIndex("by_home_created", (q) => q.eq("home_id", homeId)).take(PURGE_BATCH),
      () =>
        ctx.db
          .query("companion_votes")
          .withIndex("by_home_opened", (q) => q.eq("home_id", homeId))
          .take(PURGE_BATCH),
      () => ctx.db.query("companion_homes").withIndex("by_home", (q) => q.eq("home_id", homeId)).take(PURGE_BATCH),
    ];
    for (const batch of batches) {
      const rows = await batch();
      if (rows.length === 0) continue;
      await Promise.all(rows.map((row) => ctx.db.delete(row._id)));
      await ctx.scheduler.runAfter(0, internal.companion.purgeHome, { homeId });
      return { deleted: rows.length, done: false };
    }
    return { deleted: 0, done: true };
  },
});
