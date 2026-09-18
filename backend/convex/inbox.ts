// The bell in the corner: one button, two feeds.
//
// `home_activity` is the household's own log — every notification this backend
// has ever sent about a chore, a bill, a leak or a bag of shopping, kept after
// the banner is swiped away. `app_updates` is the app's changelog, written by
// hand from the in-app admin panel. They share a button and nothing else; see
// the block comment above their tables in schema.ts for why they are not one
// table.
//
// Three things this file is careful about, because the bell is on screen
// whenever the app is:
//
//  1. **The badge is one query, and it is bounded.** `badge` returns both
//     counts, both watermarks and the admin flag in a single payload, so a
//     count can never contradict the list under it — the same rule
//     `issues:byHome` follows. It is also the only subscription of the three
//     that is open all the time, so it is floored: it never looks further back
//     than a fortnight, which means the read costs what a fortnight costs and
//     not what the household's whole history costs.
//
//  2. **Filtering is an index range, never a filter.** A household that has
//     been running for a year has thousands of rows, and the four about money
//     must not be found by walking the other three thousand.
//     `by_home_category_created` exists for exactly that, next to
//     `by_home_created` for the unfiltered feed — the "two index ranges, not a
//     filter" move that `tasks:archive` and `lib/pending.ts` already make.
//
//  3. **Only the newest page is live.** The feed's first page is a real
//     subscription, so a chore ticked in the kitchen appears at the top while
//     the panel is open. Everything older is fetched once, because an activity
//     row is immutable — it is the record of a thing that already happened, and
//     there is no later state for a subscription to deliver. That is precisely
//     the "genuinely one-shot read" `ConvexConnection.first` exists for, and it
//     is the difference between a household's year of history costing one
//     websocket query and costing forty.

import { v } from "convex/values";
import {
  action,
  internalMutation,
  internalQuery,
  mutation,
  query,
} from "./_generated/server";
import { Doc, Id } from "./_generated/dataModel";
import { internal } from "./_generated/api";
import { requireUser, requireHomeMember, currentUserId } from "./lib/auth";
import { requireAdmin, callerIsAdmin, isAdminUser } from "./lib/admin";

// MARK: - Shapes and limits

/** A feed page, and the ceiling on one. */
const DEFAULT_PAGE = 30;
const MAX_PAGE = 60;

/**
 * How many raw rows a page reads before filtering.
 *
 * A page is filtered in JS for exactly one reason — `audience`, which an index
 * cannot express — so a page of thirty may need to look at more than thirty
 * rows to find thirty the caller may see. Three times, capped, because
 * addressed rows are a small minority of any household's feed and reading two
 * hundred documents to fill a page of thirty would be worse than the short page
 * it prevents.
 */
function fetchWidth(limit: number): number {
  return Math.min(limit * 3, 150);
}

/**
 * How far back the badge is willing to count.
 *
 * The count is the only read here that is open the whole time the app is, so it
 * is the one that must not grow with the household's age. A fortnight bounds it
 * absolutely: whatever the watermark says, at most two weeks of rows are ever
 * examined.
 *
 * It also answers the awkward case of somebody who has never opened the panel
 * and has no watermark at all. Counting from zero would greet a new member with
 * their household's entire history as unread, which is not news — it is a
 * number so large it says nothing. A fortnight is.
 */
const BADGE_FLOOR_MS = 14 * 24 * 60 * 60 * 1000;

/**
 * The same idea for the changelog, and looser.
 *
 * A release note is worth hearing about for longer than a shopping item is, and
 * a new install genuinely should arrive to "here is what this app has been
 * doing lately". A quarter is long enough to cover anybody who skipped a few
 * versions and short enough that the first launch is not a wall of them.
 */
const UPDATES_FLOOR_MS = 90 * 24 * 60 * 60 * 1000;

/**
 * Stop counting here.
 *
 * The badge is drawn in a capsule about twenty points wide. The difference
 * between forty unread and four hundred is not information, and the read that
 * tells them apart is the expensive one.
 */
const BADGE_CAP = 99;

/** How long a household's log is kept. See `sweep` at the bottom. */
const RETENTION_DAYS = 90;

// MARK: - Visibility

/**
 * Whether a feed row is addressed to this person.
 *
 * Absent `audience` is the broadcast case and the overwhelming majority: the
 * whole household hears about the shopping. A present one is already a targeted
 * notification — a direct message, a repair handed to somebody by name — and
 * showing it to the rest of the household would tell them a conversation exists
 * that they are not in.
 */
function visibleTo(row: Doc<"home_activity">, userId: Id<"users">): boolean {
  return !row.audience || row.audience.some((id) => id === userId);
}

/**
 * Whether a row should make the bell light up *for this person*.
 *
 * Your own actions never do. Being told that you added milk, seconds after
 * adding milk, is the single fastest way to teach somebody that the badge means
 * nothing — and it is already why `notifyHome` excludes the actor from the push
 * it sends. The row is still in the feed, because the feed is the household's
 * log and you are part of the household; it simply is not *news to you*.
 */
function countsAsUnread(
  row: Doc<"home_activity">,
  userId: Id<"users">,
  readAt: number,
): boolean {
  return row.created > readAt && row.actor !== userId && visibleTo(row, userId);
}

// MARK: - Watermarks

async function activityWatermark(
  ctx: { db: any },
  userId: Id<"users">,
  homeId: Id<"homes">,
): Promise<Doc<"activity_reads"> | null> {
  return await ctx.db
    .query("activity_reads")
    .withIndex("by_user_home", (q: any) =>
      q.eq("user_id", userId).eq("home_id", homeId),
    )
    .unique();
}

async function updatesWatermark(
  ctx: { db: any },
  userId: Id<"users">,
): Promise<Doc<"update_reads"> | null> {
  return await ctx.db
    .query("update_reads")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .unique();
}

// MARK: - The badge

/**
 * Everything the bell needs, in one payload.
 *
 * Both counts, both watermarks and whether this person may write the changelog.
 * One subscription rather than four: the counts must agree with each other and
 * with the lists they sit over, and the panel needs the watermarks anyway — it
 * marks the feed read the moment it opens, but goes on drawing the "new" marks
 * against the value it opened *with*, so the row you came to read does not stop
 * looking new while you are looking at it.
 *
 * `isAdmin` rides along because the alternative is a second always-open query
 * asking a question whose answer changes roughly never.
 */
export const badge = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);
    const now = Date.now();

    const [activityRead, updatesRead, admin] = await Promise.all([
      activityWatermark(ctx, user._id, homeId),
      updatesWatermark(ctx, user._id),
      callerIsAdmin(ctx),
    ]);

    // The floor is the point of this: `since` is never more than a fortnight
    // ago however stale — or absent — the watermark is, so the range below
    // reads a fortnight of rows at the very worst.
    const activitySince = Math.max(activityRead?.read_at ?? 0, now - BADGE_FLOOR_MS);
    const updatesSince = Math.max(updatesRead?.read_at ?? 0, now - UPDATES_FLOOR_MS);

    const [recent, published] = await Promise.all([
      ctx.db
        .query("home_activity")
        .withIndex("by_home_created", (q) =>
          q.eq("home_id", homeId).gt("created", activitySince),
        )
        .order("desc")
        // One more than the cap, so "99+" can be told from exactly 99.
        .take(BADGE_CAP + 1),
      ctx.db
        .query("app_updates")
        .withIndex("by_published", (q) => q.gt("published_at", updatesSince))
        .order("desc")
        .take(BADGE_CAP + 1),
    ]);

    // Counted here rather than by the index, because `audience` and "not my own
    // doing" are both per-caller questions. The set is at most a hundred rows
    // and already in memory.
    const unreadActivity = recent.filter((row) =>
      countsAsUnread(row, user._id, activityRead?.read_at ?? activitySince),
    );

    return {
      activity: unreadActivity.length,
      updates: published.length,
      /**
       * The newest unread category, so the bell can tint itself to whatever is
       * waiting rather than always to the accent — and so the panel can open on
       * the side that actually has something on it.
       */
      latestCategory: unreadActivity[0]?.category ?? null,
      activityReadAt: activityRead?.read_at ?? null,
      updatesReadAt: updatesRead?.read_at ?? null,
      /**
       * The floors this count was actually taken against.
       *
       * Sent because the panel draws a "new" mark per row and those marks have
       * to agree with the number on the bell. Somebody who has never opened the
       * panel has no watermark at all, and a client left to its own devices
       * would mark *every* row new while the badge — floored at a fortnight —
       * said four. The rule lives in one place and travels with the answer,
       * exactly as `tasks:archive` sends its window back with its rows.
       */
      activityFloor: now - BADGE_FLOOR_MS,
      updatesFloor: now - UPDATES_FLOOR_MS,
      isAdmin: admin,
      /** The cap, sent with the counts so the client never hardcodes "99+". */
      cap: BADGE_CAP,
    };
  },
});

// MARK: - The household's log

/**
 * One page of a household's activity, newest first.
 *
 * `before` is the cursor: absent for the first page, and otherwise the `created`
 * of the last row already held. Strict `<`, which is only correct because
 * `record` below guarantees `created` is unique within a home — see the field's
 * comment in schema.ts.
 *
 * `category` picks the index rather than filtering the result. Both indexes end
 * in `created`, so a filtered page costs a filtered page and an unfiltered one
 * costs an unfiltered one, with nothing in between being read and thrown away.
 */
export const activity = query({
  args: {
    homeId: v.id("homes"),
    /**
     * Absent **or null** for "everything".
     *
     * `v.optional(v.string())` would be the honest validator and it is the
     * wrong one, because 1.9.0 shipped a client that sends an explicit
     * `null` here — a Swift dictionary written as `["category": value?.raw]`
     * puts the key in with a nil value rather than leaving it out — and Convex
     * rejects null against `v.optional`. Every unfiltered read of the feed was
     * refused, so the panel showed an error the moment it opened.
     *
     * The client is fixed, but the fix only reaches a phone when a build does,
     * and this deployment serves the build that is on people's phones today.
     * Widening costs a `?? undefined` below; narrowing it back would break
     * 1.9.0 for as long as anybody is still running it. See
     * backend/DEPRECATIONS.md — this is the rule, not an exception to it.
     */
    category: v.optional(v.union(v.string(), v.null())),
    before: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { homeId, category: requested, before, limit }) => {
    // One shape from here down: null and absent both mean "no filter".
    const category = requested ?? undefined;
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);

    const pageSize = Math.min(Math.max(Math.trunc(limit ?? DEFAULT_PAGE), 1), MAX_PAGE);
    const width = fetchWidth(pageSize);

    const raw = category
      ? await ctx.db
          .query("home_activity")
          .withIndex("by_home_category_created", (q) => {
            const scoped = q.eq("home_id", homeId).eq("category", category);
            return before === undefined ? scoped : scoped.lt("created", before);
          })
          .order("desc")
          .take(width)
      : await ctx.db
          .query("home_activity")
          .withIndex("by_home_created", (q) => {
            const scoped = q.eq("home_id", homeId);
            return before === undefined ? scoped : scoped.lt("created", before);
          })
          .order("desc")
          .take(width);

    const visible = raw.filter((row) => visibleTo(row, user._id));
    const rows = visible.slice(0, pageSize);

    // The cursor has to advance past everything *examined*, not past everything
    // returned — otherwise a page whose tail was all addressed to somebody else
    // would hand back a cursor that re-reads those same rows forever. When the
    // page filled, the last returned row is the boundary; when it did not, the
    // last raw row is.
    const exhausted = raw.length < width;
    const cursor =
      visible.length > pageSize
        ? rows[rows.length - 1].created
        : (raw[raw.length - 1]?.created ?? null);

    return {
      rows: rows.map((row) => ({
        _id: row._id,
        category: row.category,
        title: row.title,
        body: row.body,
        actor: row.actor ?? null,
        actor_name: row.actor_name ?? null,
        created: row.created,
      })),
      cursor,
      hasMore: visible.length > pageSize || !exhausted,
      /**
       * How long a household's log is kept, sent with the rows so the screen
       * can state the rule it is obeying instead of printing a number that can
       * drift from the sweep's — the same reason `tasks:archive` sends its
       * window back.
       */
      retentionDays: RETENTION_DAYS,
    };
  },
});

/**
 * How many rows there are per category, for the filter chips.
 *
 * Its own query and not part of `activity`, because it has a completely
 * different lifetime: the chips are drawn once when the panel opens and do not
 * change as you page, while `activity` is re-read on every filter change and
 * every scroll to the bottom. Folding one into the other would recount the
 * household on every page.
 *
 * Bounded to the same window the feed can actually reach.
 */
export const activityCategories = query({
  args: { homeId: v.id("homes") },
  handler: async (ctx, { homeId }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);

    const since = Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
    const rows = await ctx.db
      .query("home_activity")
      .withIndex("by_home_created", (q) => q.eq("home_id", homeId).gt("created", since))
      .order("desc")
      // A ceiling rather than a `collect`. The chips only need to know which
      // categories have anything in them and roughly how much; a household with
      // six thousand rows is not owed an exact tally it cannot read anyway.
      .take(1000);

    const counts: Record<string, number> = {};
    let total = 0;
    for (const row of rows) {
      if (!visibleTo(row, user._id)) continue;
      counts[row.category] = (counts[row.category] ?? 0) + 1;
      total += 1;
    }

    return {
      total,
      categories: Object.entries(counts)
        .map(([category, count]) => ({ category, count }))
        .sort((a, b) => b.count - a.count),
    };
  },
});

/**
 * Moves this person's watermark forward.
 *
 * `at` is the newest row they have actually been shown, so a panel opened on a
 * stale page cannot mark rows read that it never displayed. Absent means now.
 *
 * Never moves backwards. Two devices with the panel open would otherwise take
 * turns undoing each other's reads.
 */
export const markActivityRead = mutation({
  args: { homeId: v.id("homes"), at: v.optional(v.number()) },
  handler: async (ctx, { homeId, at }) => {
    const user = await requireUser(ctx);
    await requireHomeMember(ctx, homeId);

    const readAt = at ?? Date.now();
    const existing = await activityWatermark(ctx, user._id, homeId);

    if (!existing) {
      await ctx.db.insert("activity_reads", {
        user_id: user._id,
        home_id: homeId,
        read_at: readAt,
      });
      return { read_at: readAt };
    }
    if (readAt > existing.read_at) {
      await ctx.db.patch(existing._id, { read_at: readAt });
      return { read_at: readAt };
    }
    return { read_at: existing.read_at };
  },
});

// MARK: - The changelog

/**
 * The published changelog, newest first — pinned entries first of all.
 *
 * Not paged, and deliberately. A changelog is written by one person by hand and
 * grows at the speed of releases; a hundred of them is years of work and is
 * still a smaller payload than one screen of a household's shopping. Paging it
 * would be machinery guarding against a size it will not reach, and it would
 * cost the thing that makes it worth reading — that you can scroll the lot.
 */
export const updates = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, { limit }) => {
    // Signed-in only, like everything else here, but membership of a home is
    // not required: a release note is not a household's property, and somebody
    // who has just signed up and not yet joined anywhere can still read it.
    await requireUser(ctx);

    const rows = await ctx.db
      .query("app_updates")
      // `.gt("published_at", 0)` is what excludes drafts. An absent value sorts
      // before every number in a Convex index, so the range simply does not
      // contain them — no filter, and no way to forget one.
      .withIndex("by_published", (q) => q.gt("published_at", 0))
      .order("desc")
      .take(Math.min(Math.max(Math.trunc(limit ?? 100), 1), 200));

    return rows.map(present).sort(pinnedFirst);
  },
});

/** Moves the changelog watermark. Same rules as `markActivityRead`. */
export const markUpdatesRead = mutation({
  args: { at: v.optional(v.number()) },
  handler: async (ctx, { at }) => {
    const user = await requireUser(ctx);
    const readAt = at ?? Date.now();
    const existing = await updatesWatermark(ctx, user._id);

    if (!existing) {
      await ctx.db.insert("update_reads", { user_id: user._id, read_at: readAt });
      return { read_at: readAt };
    }
    if (readAt > existing.read_at) {
      await ctx.db.patch(existing._id, { read_at: readAt });
      return { read_at: readAt };
    }
    return { read_at: existing.read_at };
  },
});

/**
 * One release note in one other language.
 *
 * Shared by `saveUpdate` and `syncChangelog` so the two cannot drift — they
 * write the same field and a difference between them would be a note that
 * loses its Turkish the first time somebody edits it in the app.
 */
const translationValidator = v.object({
  language: v.string(),
  title: v.string(),
  body: v.string(),
  highlights: v.optional(v.array(v.string())),
});

/** Trims a set of translations and drops the ones with nothing in them. */
function cleanTranslations(
  rows: Array<{
    language: string;
    title: string;
    body: string;
    highlights?: string[];
  }>,
) {
  const cleaned = rows
    .map((t) => ({
      language: t.language.trim(),
      title: t.title.trim(),
      body: t.body.trim(),
      highlights: (t.highlights ?? [])
        .map((h) => h.trim())
        .filter((h) => h.length > 0)
        .slice(0, 12),
    }))
    // A language with a title but no body, or the reverse, is half a note.
    // Dropped rather than stored, so the reader falls back to a complete
    // English one instead of reading a heading with nothing under it.
    .filter((t) => t.language && t.title && t.body)
    .map((t) => (t.highlights.length > 0 ? t : { ...t, highlights: undefined }));
  return cleaned.length > 0 ? cleaned : undefined;
}

// MARK: - The admin panel

/**
 * Every changelog entry, drafts included, newest written first.
 *
 * Admin-only, and ordered by `created` rather than `published_at` because this
 * is the author's desk: a draft has no publication date, and sorting by one
 * would file everything unfinished in a heap at the bottom.
 */
export const allUpdates = query({
  args: {},
  handler: async (ctx) => {
    await requireAdmin(ctx);
    const rows = await ctx.db
      .query("app_updates")
      .withIndex("by_created")
      .order("desc")
      .take(200);
    return rows.map(present);
  },
});

/**
 * Writes a changelog entry, new or existing.
 *
 * One mutation for both because the panel is one form for both, and splitting
 * it would mean two argument lists that have to stay identical. `id` absent is
 * a new entry.
 *
 * `publish` is the only thing that moves an entry between draft and live, and
 * it is explicit on every save: a field left out of a patch means "leave it
 * alone", which is exactly the wrong default for the flag that decides whether
 * a half-written note is on everybody's phone.
 */
export const saveUpdate = mutation({
  args: {
    id: v.optional(v.id("app_updates")),
    version: v.optional(v.string()),
    kind: v.union(
      v.literal("feature"),
      v.literal("improvement"),
      v.literal("fix"),
      v.literal("announcement"),
    ),
    title: v.string(),
    body: v.string(),
    highlights: v.optional(v.array(v.string())),
    translations: v.optional(v.array(translationValidator)),
    pinned: v.optional(v.boolean()),
    publish: v.boolean(),
  },
  handler: async (ctx, args) => {
    const admin = await requireAdmin(ctx);
    const now = Date.now();

    const title = args.title.trim();
    if (!title) throw new Error("An update needs a title");
    const body = args.body.trim();
    if (!body) throw new Error("An update needs something to say");

    const version = args.version?.trim() || undefined;
    const highlights = (args.highlights ?? [])
      .map((h) => h.trim())
      .filter((h) => h.length > 0)
      .slice(0, 12);

    const fields = {
      version,
      kind: args.kind,
      title,
      body,
      highlights: highlights.length > 0 ? highlights : undefined,
      translations: cleanTranslations(args.translations ?? []),
      pinned: args.pinned ?? false,
      updated: now,
    };

    if (args.id) {
      const existing = await ctx.db.get(args.id);
      if (!existing) throw new Error("That update is gone");
      await ctx.db.patch(args.id, {
        ...fields,
        // Publishing stamps the date once and keeps it. Re-saving a live entry
        // must not move it to the top of everybody's feed and light the badge
        // again — a typo fixed in a release note is not a new release note.
        published_at: args.publish ? (existing.published_at ?? now) : undefined,
      });
      return args.id;
    }

    return await ctx.db.insert("app_updates", {
      ...fields,
      published_at: args.publish ? now : undefined,
      author: admin._id,
      created: now,
    });
  },
});

/** Publishes or retracts an entry without going through the whole form. */
export const setUpdatePublished = mutation({
  args: { id: v.id("app_updates"), published: v.boolean() },
  handler: async (ctx, { id, published }) => {
    await requireAdmin(ctx);
    const existing = await ctx.db.get(id);
    if (!existing) throw new Error("That update is gone");
    await ctx.db.patch(id, {
      published_at: published ? (existing.published_at ?? Date.now()) : undefined,
      updated: Date.now(),
    });
  },
});

export const removeUpdate = mutation({
  args: { id: v.id("app_updates") },
  handler: async (ctx, { id }) => {
    await requireAdmin(ctx);
    await ctx.db.delete(id);
  },
});

/**
 * Who the server thinks you are.
 *
 * A session query, so the app can ask it. The CLI **cannot** — an
 * `npx convex run` carries a deploy key, not a session, so this returns null
 * there. Use `inbox:accounts` below for that.
 *
 * See convex/lib/admin.ts for why an email allowlist is not always enough, and
 * the Admin panel's footer, which prints this id with a tap to copy it.
 */
export const whoAmI = query({
  args: {},
  handler: async (ctx) => {
    const uid = await currentUserId(ctx);
    if (!uid) return null;
    const user = await ctx.db.get(uid);
    if (!user) return null;
    return {
      _id: user._id,
      email: user.email ?? null,
      name: user.name ?? null,
      isAdmin: await callerIsAdmin(ctx),
    };
  },
});

/**
 * Accounts, for setting `ADMIN_USER_IDS`.
 *
 *   npx convex run inbox:accounts '{}'
 *
 * The CLI cannot be a signed-in user, so this is how somebody holding the
 * deployment finds the id of the account they sign in with — which is the
 * answer that always works, where an email is a coin flip on this app's
 * Sign in with Apple (the address arrives once, and may be a relay alias).
 *
 * `internalQuery`: reachable with a deploy key and from nothing else. A public
 * query listing everybody's email would be a directory of the deployment.
 */
export const accounts = internalQuery({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").take(50);
    return users.map((u) => ({
      _id: u._id,
      name: u.name ?? null,
      email: u.email ?? null,
      isAdmin: isAdminUser(u),
    }));
  },
});

// MARK: - Is there a newer build?

/** The app this deployment serves. Used for the App Store lookup. */
const BUNDLE_ID = "com.walhallaa.NestZone";

/**
 * How long an App Store answer is worth reusing.
 *
 * Six hours. The value changes when a build is approved, which is to say a
 * handful of times a year, and the alternative is a household of four tapping
 * "Check for updates" out of curiosity and sending four requests to somebody
 * else's endpoint for the same string.
 */
const RELEASE_CACHE_MS = 6 * 60 * 60 * 1000;

/**
 * What the newest version is, from the two places that know.
 *
 * Two answers, deliberately, because they are two different facts and the
 * Settings screen needs both:
 *
 *  - `storeVersion` is what the App Store will actually give somebody who taps
 *    Update. Absent when the app is not published yet, which is a state and not
 *    a failure.
 *  - `changelogVersion` is the newest version this deployment has release notes
 *    for — which runs *ahead* of the store, because notes are published when
 *    the work lands and the build is still in review. It is what lets the app
 *    say "there is something coming" rather than only "you are up to date".
 *
 * The comparison itself happens on the phone. This hands back strings; which of
 * them is newer than the build asking is the client's decision, for the same
 * reason the "coming soon" gate is — see `AppVersion` in Swift.
 */
export const latestRelease = action({
  args: {},
  handler: async (
    ctx,
  ): Promise<{
    storeVersion: string | null;
    storeUrl: string | null;
    changelogVersion: string | null;
    checkedAt: number;
  }> => {
    const [cached, changelogVersion] = await Promise.all([
      ctx.runQuery(internal.inbox.cachedReleaseCheck, {}),
      ctx.runQuery(internal.inbox.newestPublishedVersion, {}),
    ]);

    if (cached && Date.now() - cached.checked_at < RELEASE_CACHE_MS) {
      return {
        storeVersion: cached.store_version ?? null,
        storeUrl: cached.store_url ?? null,
        changelogVersion,
        checkedAt: cached.checked_at,
      };
    }

    let storeVersion: string | null = null;
    let storeUrl: string | null = null;
    try {
      // `country` is required for a meaningful answer — Apple scopes the
      // catalogue per storefront, and an app not yet released in one comes back
      // empty there while being live in another.
      const response = await fetch(
        `https://itunes.apple.com/lookup?bundleId=${BUNDLE_ID}&country=TR`,
      );
      if (response.ok) {
        const payload = await response.json();
        const entry = payload?.results?.[0];
        if (entry) {
          storeVersion =
            typeof entry.version === "string" ? entry.version : null;
          storeUrl =
            typeof entry.trackViewUrl === "string" ? entry.trackViewUrl : null;
        }
      }
    } catch (error) {
      // Somebody else's endpoint being unreachable is not this app's failure.
      // The stale cache — or an honest "we do not know" — is a better answer
      // than an error dialog over a button somebody pressed out of curiosity.
      console.warn(`App Store lookup failed: ${String(error)}`);
      if (cached) {
        return {
          storeVersion: cached.store_version ?? null,
          storeUrl: cached.store_url ?? null,
          changelogVersion,
          checkedAt: cached.checked_at,
        };
      }
    }

    const checkedAt = Date.now();
    await ctx.runMutation(internal.inbox.storeReleaseCheck, {
      storeVersion: storeVersion ?? undefined,
      storeUrl: storeUrl ?? undefined,
      checkedAt,
    });
    return { storeVersion, storeUrl, changelogVersion, checkedAt };
  },
});

export const cachedReleaseCheck = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("release_checks")
      .withIndex("by_platform", (q) => q.eq("platform", "ios"))
      .unique();
  },
});

export const storeReleaseCheck = internalMutation({
  args: {
    storeVersion: v.optional(v.string()),
    storeUrl: v.optional(v.string()),
    checkedAt: v.number(),
  },
  handler: async (ctx, { storeVersion, storeUrl, checkedAt }) => {
    const existing = await ctx.db
      .query("release_checks")
      .withIndex("by_platform", (q) => q.eq("platform", "ios"))
      .unique();
    const fields = {
      platform: "ios",
      store_version: storeVersion,
      store_url: storeUrl,
      checked_at: checkedAt,
    };
    if (existing) {
      await ctx.db.patch(existing._id, fields);
      return;
    }
    await ctx.db.insert("release_checks", fields);
  },
});

/** The newest version this deployment has published release notes for. */
export const newestPublishedVersion = internalQuery({
  args: {},
  handler: async (ctx): Promise<string | null> => {
    const rows = await ctx.db
      .query("app_updates")
      .withIndex("by_published", (q) => q.gt("published_at", 0))
      .order("desc")
      .take(50);
    // The newest *version*, not the newest entry: an announcement carries no
    // version and a fix for an old release can be published after a newer one.
    const versions = rows
      .map((r) => r.version)
      .filter((v): v is string => Boolean(v));
    return versions.length > 0 ? versions.sort(compareVersions).at(-1)! : null;
  },
});

/**
 * Semantic comparison, the same rule the client uses.
 *
 * Component by component as numbers. "1.10.0" is above "1.9.0" and a string
 * comparison says the opposite — which would invert the answer for exactly one
 * release in ten, silently.
 */
function compareVersions(a: string, b: string): number {
  const parts = (value: string) =>
    value
      .trim()
      .split(".")
      .map((part) => Number.parseInt(part, 10) || 0);
  const left = parts(a);
  const right = parts(b);
  for (let i = 0; i < Math.max(left.length, right.length); i += 1) {
    const diff = (left[i] ?? 0) - (right[i] ?? 0);
    if (diff !== 0) return diff;
  }
  return 0;
}

/**
 * Which app versions are still out there.
 *
 * The query that makes `backend/DEPRECATIONS.md` real: nothing is removed from
 * this backend until this says nobody needs it. Run it from the CLI —
 *
 *   npx convex run inbox:versionCensus '{}'
 *
 * `unknown` counts devices registered by a build too old to report a version
 * at all, which is the most important row on the list: it is the one that says
 * old clients exist without saying which.
 *
 * Undercounts by construction — a device that declined notifications never
 * registers — so treat every number as a floor. A floor is the safe direction
 * for a question whose wrong answer breaks somebody's app.
 *
 * `internalQuery`, which is what makes the command above work at all: an
 * `npx convex run` carries a deploy key and not a user session, so a public
 * query guarded by `requireAdmin` throws "Not authenticated" before it reads
 * anything. Internal is also the honest classification — this is an operational
 * tool for whoever holds the deployment, and no screen in the app asks it.
 */
export const versionCensus = internalQuery({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("push_tokens").take(2000);
    const counts: Record<string, { devices: number; lastSeen: number }> = {};
    for (const row of rows) {
      const key = row.app_version ?? "unknown";
      const entry = counts[key] ?? { devices: 0, lastSeen: 0 };
      entry.devices += 1;
      entry.lastSeen = Math.max(entry.lastSeen, row.updated);
      counts[key] = entry;
    }
    return {
      devices: rows.length,
      versions: Object.entries(counts)
        .map(([version, entry]) => ({ version, ...entry }))
        .sort((a, b) => b.devices - a.devices),
    };
  },
});

// MARK: - Recording

/**
 * Files one thing that happened.
 *
 * Called by `push.notifyHome` and `push.notifyUsers` on their way past, which
 * is the whole design: thirty-odd places in this backend already know how to
 * tell a household something, and none of them should have to learn a second
 * way. A module that starts notifying tomorrow is in the feed tomorrow without
 * being changed.
 *
 * Runs *before* the APNs configuration check on purpose. The feed is the
 * durable half of a notification and has to exist on a deployment with no push
 * keys at all — which is every deployment on its first day.
 */
export const record = internalMutation({
  args: {
    homeId: v.id("homes"),
    category: v.optional(v.string()),
    title: v.string(),
    body: v.string(),
    actor: v.optional(v.id("users")),
    audience: v.optional(v.array(v.id("users"))),
  },
  handler: async (ctx, args) => {
    // No `requireHomeMember`: this is internal, and its callers are actions
    // scheduled by mutations that have already checked. Re-checking here would
    // mean the *actor* has to still be a member at the moment the scheduler
    // gets to it, which is not the same question and is occasionally false.
    const home = await ctx.db.get(args.homeId);
    if (!home) return null;

    // Denormalised now rather than resolved per row on the way out. One read
    // here against one read per row per page for the rest of the row's life.
    let actorName: string | undefined;
    if (args.actor) {
      const actor = await ctx.db.get(args.actor);
      actorName = actor?.name ?? undefined;
    }

    return await ctx.db.insert("home_activity", {
      home_id: args.homeId,
      category: args.category ?? "other",
      title: args.title,
      body: args.body,
      actor: args.actor,
      actor_name: actorName,
      audience: args.audience,
      created: await uniqueStamp(ctx, args.homeId),
    });
  },
});

/**
 * Now, or the first free millisecond after it in this home.
 *
 * The feed pages with a strict `<` cursor, which is the cheapest correct cursor
 * available and is correct only while no two rows in a home share a `created`.
 * Two notifications scheduled by the same mutation — a repair assigned *and*
 * reported, a bill paid *and* settled — land as two independent actions that
 * can very easily agree on the millisecond.
 *
 * One indexed point read, and almost always exactly one: a collision needs two
 * actions inside the same millisecond in the same household. The loop is
 * bounded because a household that can produce five in a row has a bigger
 * problem than a cursor.
 */
async function uniqueStamp(
  ctx: { db: any },
  homeId: Id<"homes">,
): Promise<number> {
  let stamp = Date.now();
  for (let i = 0; i < 5; i += 1) {
    const clash = await ctx.db
      .query("home_activity")
      .withIndex("by_home_created", (q: any) =>
        q.eq("home_id", homeId).eq("created", stamp),
      )
      .first();
    if (!clash) return stamp;
    stamp += 1;
  }
  return stamp;
}

// MARK: - Retention

/**
 * Drops household activity older than the retention window.
 *
 * A feed is the one table in this schema that is *supposed* to be forgotten.
 * Everything else a household owns is the household's — its chores, its money,
 * its problems — but "somebody added bread" stopped being useful the week it
 * was written, and kept forever it is both a bill and a slow query: the cost of
 * the badge, the filter chips and the first page all scale with how long the
 * household has been running.
 *
 * Self-scheduling and bounded, in the shape `tasks:backfillCompletions` uses: a
 * deployment with a year of backlog on the day this ships would not finish in
 * one pass, and a sweep that times out is a sweep that never gets past its
 * first batch.
 */
export const sweep = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
    const stale = await ctx.db
      .query("home_activity")
      // Ascending — oldest first — so a backlog drains from the far end
      // rather than re-reading the same newest rows on every pass.
      .withIndex("by_created", (q) => q.lt("created", cutoff))
      .take(SWEEP_BATCH);

    await Promise.all(stale.map((row) => ctx.db.delete(row._id)));

    // A full batch means there is probably more. Rescheduled rather than
    // looped, so each pass gets its own execution budget instead of sharing
    // one second with however much backlog exists.
    if (stale.length >= SWEEP_BATCH) {
      await ctx.scheduler.runAfter(0, internal.inbox.sweep, {});
    }
    return { deleted: stale.length };
  },
});

/** How many rows one pass of the sweep removes. */
const SWEEP_BATCH = 400;

// MARK: - Publishing from the repo

/**
 * The changelog as the repository states it, synced into the deployment.
 *
 * This is how release notes actually get written here. `backend/changelog.json`
 * is the source of truth, it is edited in the same commit as the work it
 * describes, and this is run on deploy:
 *
 *   npx convex run inbox:syncChangelog "$(cat changelog.json)"
 *
 * `internalMutation`, so it is reachable with a deploy key and not from any
 * signed-in session — the repo is the author here, and there is no user to
 * check. The admin panel in the app writes through `saveUpdate` instead, which
 * does check.
 *
 * Idempotent by `slug`. Running it on every deploy is the point: nothing is
 * duplicated, an edited note is edited in place, and a note whose `published_at`
 * is already set keeps it — so fixing a typo in the 1.8 notes does not move
 * them to the top of everybody's feed and light the badge again.
 *
 * It does not delete. An entry removed from the file stays in the deployment,
 * because a household that has read it should not watch it disappear, and
 * because "the file no longer mentions it" and "retract it" are different
 * intentions — the second one is `setUpdatePublished`.
 */
export const syncChangelog = internalMutation({
  args: {
    entries: v.array(
      v.object({
        slug: v.string(),
        version: v.optional(v.string()),
        kind: v.union(
          v.literal("feature"),
          v.literal("improvement"),
          v.literal("fix"),
          v.literal("announcement"),
        ),
        title: v.string(),
        body: v.string(),
        highlights: v.optional(v.array(v.string())),
        translations: v.optional(v.array(translationValidator)),
        pinned: v.optional(v.boolean()),
        /** Left out means published. A draft has to say so. */
        draft: v.optional(v.boolean()),
      }),
    ),
    /** Who the entries are attributed to. Falls back to the first admin seen. */
    author: v.optional(v.id("users")),
    /**
     * Ignored — the file's own instructions, carried so they can live beside
     * the data they describe.
     *
     * Declared rather than stripped because Convex validates arguments
     * strictly and rejects the whole request on an unknown key: without this,
     * `npx convex run inbox:syncChangelog "$(cat changelog.json)"` fails on the
     * README at the top of the file, which is the one line of that file
     * somebody is guaranteed to read first.
     */
    _readme: v.optional(v.array(v.string())),
  },
  handler: async (ctx, { entries, author }) => {
    const now = Date.now();
    let created = 0;
    let updated = 0;

    // Resolved once rather than per entry. `author` is only ever used for a
    // *new* row, and an existing row keeps whoever wrote it.
    const fallbackAuthor = author ?? (await anyAdminId(ctx));

    for (const entry of entries) {
      const slug = entry.slug.trim();
      if (!slug) continue;

      const title = entry.title.trim();
      const body = entry.body.trim();
      if (!title || !body) continue;

      const highlights = (entry.highlights ?? [])
        .map((h) => h.trim())
        .filter((h) => h.length > 0)
        .slice(0, 12);

      const fields = {
        slug,
        version: entry.version?.trim() || undefined,
        kind: entry.kind,
        title,
        body,
        highlights: highlights.length > 0 ? highlights : undefined,
        translations: cleanTranslations(entry.translations ?? []),
        pinned: entry.pinned ?? false,
        updated: now,
      };

      const existing = await ctx.db
        .query("app_updates")
        .withIndex("by_slug", (q) => q.eq("slug", slug))
        .unique();

      if (existing) {
        await ctx.db.patch(existing._id, {
          ...fields,
          // Kept if it already has one. A re-sync is not a re-release.
          published_at: entry.draft
            ? undefined
            : (existing.published_at ?? now),
        });
        updated += 1;
        continue;
      }

      if (!fallbackAuthor) {
        throw new Error(
          "No author for a new changelog entry: pass `author`, or sign in once " +
            "as an administrator so there is somebody to attribute it to.",
        );
      }

      await ctx.db.insert("app_updates", {
        ...fields,
        published_at: entry.draft ? undefined : now,
        author: fallbackAuthor,
        created: now,
      });
      created += 1;
    }

    return { created, updated, total: entries.length };
  },
});

/**
 * Somebody to attribute a synced entry to.
 *
 * The sync has no session — it is run with a deploy key — so there is no
 * caller to credit. It takes the configured administrator if that account
 * exists in this deployment, and the earliest account otherwise, which on a
 * personal deployment is the same person.
 */
async function anyAdminId(ctx: {
  db: any;
}): Promise<Id<"users"> | undefined> {
  const users: Doc<"users">[] = await ctx.db.query("users").take(50);
  const admin = users.find((u) => isAdminUser(u));
  return (admin ?? users[0])?._id;
}

// MARK: - Presentation

/** One changelog row, as the app reads it. */
function present(row: Doc<"app_updates">) {
  return {
    _id: row._id,
    version: row.version ?? null,
    slug: row.slug ?? null,
    kind: row.kind,
    title: row.title,
    body: row.body,
    highlights: row.highlights ?? [],
    translations: row.translations ?? [],
    pinned: row.pinned ?? false,
    published_at: row.published_at ?? null,
    created: row.created,
    updated: row.updated,
  };
}

type Presented = ReturnType<typeof present>;

/** Pinned entries float, and within each group the newest wins. */
function pinnedFirst(a: Presented, b: Presented): number {
  if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
  return (b.published_at ?? b.created) - (a.published_at ?? a.created);
}
