// Referential integrity helpers.
//
// Convex's `v.id("table")` is a TYPE, not a foreign key: it does not check that
// the target row exists, it is not enforced on write, and there is no ON DELETE
// CASCADE. Every relation therefore has to be validated when it is written and
// cleaned up when its parent is deleted — that is what this module is for.
//
// Rules used throughout:
//   - writing a reference  -> `requireRef` (target exists) and, where the target
//     is home-scoped, `requireSameHome` / `requireMembers`
//   - deleting a parent    -> a `cascadeDelete*` below, never a bare ctx.db.delete

import { Doc, Id, TableNames } from "../_generated/dataModel";
import { MutationCtx, QueryCtx } from "../_generated/server";
import { internal } from "../_generated/api";

/** Load a referenced document or throw. Use before storing any v.id(). */
export async function requireRef<T extends TableNames>(
  ctx: QueryCtx | MutationCtx,
  id: Id<T>,
  label: string,
): Promise<Doc<T>> {
  const doc = await ctx.db.get(id);
  if (!doc) throw new Error(`${label} not found`);
  return doc as Doc<T>;
}

/** Assert a referenced, home-scoped document lives in the expected home. */
export function requireSameHome(
  doc: { home_id?: Id<"homes"> },
  homeId: Id<"homes">,
  label: string,
): void {
  if (doc.home_id !== homeId) {
    throw new Error(`${label} belongs to another home`);
  }
}

/**
 * Assert every user id is a member of `home`. Guards the case that matters most:
 * a conversation (or task assignment) naming somebody outside the household,
 * which would otherwise hand them access to that home's content.
 */
export async function requireMembers(
  ctx: QueryCtx | MutationCtx,
  home: Doc<"homes">,
  userIds: Id<"users">[],
  label: string,
): Promise<void> {
  const members = new Set(home.members ?? []);
  // Checked in one round rather than one person at a time. Everything in this
  // module is on the hot path of a write, and a mutation gets one second of
  // execution — spending it on sequential round trips is what took out
  // `events:stockUp` and `stats:forHome`.
  await Promise.all(userIds.map((id) => requireRef(ctx, id, `${label} user`)));
  for (const id of userIds) {
    if (!members.has(id)) {
      throw new Error(`${label} includes a user who is not a member of this home`);
    }
  }
}

/** Delete a conversation and every message in it. */
export async function cascadeDeleteConversation(
  ctx: MutationCtx,
  conversationId: Id<"conversations">,
): Promise<number> {
  const messages = await ctx.db
    .query("messages")
    .withIndex("by_conversation", (q) => q.eq("conversation_id", conversationId))
    .collect();
  await Promise.all(messages.map((m) => ctx.db.delete(m._id)));
  await ctx.db.delete(conversationId);
  return messages.length;
}

/** Delete a poll and every item and vote under it. */
export async function cascadeDeletePoll(
  ctx: MutationCtx,
  pollId: Id<"polls">,
): Promise<{ items: number; votes: number }> {
  const items = await ctx.db
    .query("poll_items")
    .withIndex("by_poll", (q) => q.eq("poll_id", pollId))
    .collect();
  const votes = await ctx.db
    .query("poll_votes")
    .withIndex("by_poll", (q) => q.eq("poll_id", pollId))
    .collect();
  await Promise.all([
    ...items.map((i) => ctx.db.delete(i._id)),
    ...votes.map((v) => ctx.db.delete(v._id)),
  ]);
  await ctx.db.delete(pollId);
  return { items: items.length, votes: votes.length };
}

/** Delete a movie list and every movie filed under it. */
export async function cascadeDeleteMovieList(
  ctx: MutationCtx,
  listId: Id<"movie_lists">,
): Promise<number> {
  const movies = await ctx.db
    .query("movies")
    .withIndex("by_list", (q) => q.eq("list_id", listId))
    .collect();
  await Promise.all(movies.map((m) => ctx.db.delete(m._id)));
  await ctx.db.delete(listId);
  return movies.length;
}

/**
 * Detach everything that pointed at an event, without deleting any of it.
 *
 * Deliberately not a cascade. The expenses linked to Saturday's party are money
 * that actually moved: deleting them because somebody tidied their calendar
 * would silently rewrite the household's balances, which is the one thing the
 * ledger must never do. The shopping items are the same argument in a smaller
 * key — the ice is still needed, it just is not "for" anything any more.
 *
 * The denormalised `event_title` goes with the link, or the shopping screen
 * would head a group after an event that no longer exists.
 */
export async function unlinkEvent(
  ctx: MutationCtx,
  eventId: Id<"events">,
): Promise<{ expenses: number; items: number }> {
  const [expenses, items, meals] = await Promise.all([
    ctx.db
      .query("expenses")
      .withIndex("by_event", (q) => q.eq("event_id", eventId))
      .collect(),
    ctx.db
      .query("shopping_items")
      .withIndex("by_event", (q) => q.eq("event_id", eventId))
      .collect(),
    // The household is still eating that night; only the party is off.
    //
    // Indexed now. The comment that used to sit here said meal plans are one
    // row per home per day so the set is small — true per home, but `filter`
    // has no index behind it, so this walked every meal plan in the database,
    // every other household's included, on every event delete.
    ctx.db
      .query("meal_plans")
      .withIndex("by_event", (q) => q.eq("event_id", eventId))
      .collect(),
  ]);

  await Promise.all([
    ...expenses.map((e) => ctx.db.patch(e._id, { event_id: undefined })),
    ...items.map((i) =>
      ctx.db.patch(i._id, { event_id: undefined, event_title: undefined }),
    ),
    ...meals.map((m) => ctx.db.patch(m._id, { event_id: undefined })),
  ]);

  return { expenses: expenses.length, items: items.length };
}

/**
 * Delete a home and everything scoped to it, and scrub it from every user's
 * `home_id` mirror.
 *
 * Called when the last member leaves (or deletes their account). Without this
 * the home's rows survive with no member able to satisfy `requireHomeMember`,
 * i.e. permanently unreachable data that no code path can ever read, write or
 * clean up again.
 *
 * In two halves, because a household with years of history cannot be deleted
 * inside one transaction's read and write limits — and when it was tried in
 * one, a scheduled caller (account deletion) could fail half-way with nothing
 * left to finish the job. So the part that decides access goes now, in the
 * caller's transaction: the home document, every member's mirror, Nestie's
 * row. The household's rows are then unreachable to everyone, and drain in
 * bounded batches behind it (`homes:purgeHomeData`, `purgeHomeBatch` below),
 * the same way Nestie's ledger already did (`companion:purgeHome`).
 */
export async function cascadeDeleteHome(
  ctx: MutationCtx,
  homeId: Id<"homes">,
): Promise<Record<string, number>> {
  const removed: Record<string, number> = {};
  // Read before anything is deleted: the home doc carries the member list the
  // mirror-scrub below needs.
  const memberIds = (await ctx.db.get(homeId))?.members ?? [];

  // The home's own members, not every user in the deployment: `homes.members`
  // is the authoritative membership list (it is what `requireHomeMember`
  // enforces) and the mirror is patched alongside it in the same transaction,
  // so these are exactly the users to scrub.
  const members = await Promise.all(memberIds.map((id) => ctx.db.get(id)));
  const scrubbed = await Promise.all(
    members
      .filter((u) => u !== null && (u.home_id ?? []).some((h) => h === homeId))
      .map((u) =>
        ctx.db
          .patch(u!._id, { home_id: (u!.home_id ?? []).filter((h) => h !== homeId) })
          .then(() => 1),
      ),
  );
  removed["users_scrubbed"] = scrubbed.length;

  // Nestie's rows outlive nothing either, but a companion's ledger grows with
  // the house's age, so only the one `companion_homes` row goes here and the
  // rest drain in batches behind it (`companion:purgeHome`).
  const companionHomes = await ctx.db
    .query("companion_homes")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .take(10);
  await Promise.all(companionHomes.map((row) => ctx.db.delete(row._id)));
  if (companionHomes.length > 0) {
    await ctx.scheduler.runAfter(0, internal.companion.purgeHome, { homeId });
  }
  removed["companion_homes"] = companionHomes.length;

  await ctx.db.delete(homeId);
  removed["homes"] = 1;

  // Everything else, scheduled. Scheduling cannot fail the way a long delete
  // can, so leaving stays one quick transaction.
  await ctx.scheduler.runAfter(0, internal.homes.purgeHomeData, { homeId });
  return removed;
}

/** Rows of one home-scoped table deleted per batch. */
const PURGE_ROWS = 150;
/** Parents (polls, conversations) emptied per batch, each up to PURGE_ROWS children. */
const PURGE_PARENTS = 5;

/**
 * Tables with a `by_home` index, deleted row by row. The ones the reminder
 * and growth sweeps read come first, so a deleted house stops being looked
 * at soonest.
 *
 * `issue_comments` carries `home_id` precisely so a household's entries are
 * one index range instead of one read per problem. `task_completions` — which
 * nothing else in the app may delete, the record of who did the housework —
 * does not outlive the household it belongs to. `home_activity` and
 * `activity_reads` are home-scoped like the rest; `app_updates` belongs to
 * the app, not to any home. `movies` goes by its own `by_home`, so a list is
 * empty by the time it is deleted.
 */
const HOME_TABLES = [
  "bills", "events", "issues", "tasks", "task_completions", "shopping_items",
  "notes", "recipes", "movies", "meal_plans", "expenses", "settlements",
  "budgets", "issue_comments", "home_activity", "activity_reads",
] as const;

/**
 * Deletes one bounded batch of a deleted home's rows (about 5,000 writes at
 * most). `more` is whether anything is left. Idempotent: it reads what is
 * there, so a retried or overlapping batch only finds less.
 */
export async function purgeHomeBatch(
  ctx: MutationCtx,
  homeId: Id<"homes">,
): Promise<{ removed: number; more: boolean }> {
  let removed = 0;
  let more = false;

  const counts = await Promise.all(
    HOME_TABLES.map(async (table) => {
      const rows = await ctx.db
        .query(table)
        .withIndex("by_home", (q) => q.eq("home_id", homeId))
        .take(PURGE_ROWS);
      await Promise.all(rows.map((r) => ctx.db.delete(r._id)));
      return rows.length;
    }),
  );
  for (const n of counts) {
    removed += n;
    if (n === PURGE_ROWS) more = true;
  }

  // Movie lists after their movies (above, by home), so a batch never
  // strands a film under a list that is gone.
  const lists = await ctx.db
    .query("movie_lists")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .take(PURGE_ROWS);
  if (counts[HOME_TABLES.indexOf("movies")] < PURGE_ROWS) {
    await Promise.all(lists.map((l) => ctx.db.delete(l._id)));
    removed += lists.length;
    if (lists.length === PURGE_ROWS) more = true;
  } else if (lists.length > 0) {
    more = true;
  }

  // Polls and conversations: empty a few, deleting each only once empty.
  const polls = await ctx.db
    .query("polls")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .take(PURGE_PARENTS);
  for (const poll of polls) {
    const [items, votes] = await Promise.all([
      ctx.db.query("poll_items").withIndex("by_poll", (q) => q.eq("poll_id", poll._id)).take(PURGE_ROWS),
      ctx.db.query("poll_votes").withIndex("by_poll", (q) => q.eq("poll_id", poll._id)).take(PURGE_ROWS),
    ]);
    await Promise.all([...items, ...votes].map((r) => ctx.db.delete(r._id)));
    removed += items.length + votes.length;
    if (items.length < PURGE_ROWS && votes.length < PURGE_ROWS) {
      await ctx.db.delete(poll._id);
      removed += 1;
    } else {
      more = true;
    }
  }
  if (polls.length === PURGE_PARENTS) more = true;

  const convos = await ctx.db
    .query("conversations")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .take(PURGE_PARENTS);
  for (const convo of convos) {
    const messages = await ctx.db
      .query("messages")
      .withIndex("by_conversation", (q) => q.eq("conversation_id", convo._id))
      .take(PURGE_ROWS);
    await Promise.all(messages.map((m) => ctx.db.delete(m._id)));
    removed += messages.length;
    if (messages.length < PURGE_ROWS) {
      await ctx.db.delete(convo._id);
      removed += 1;
    } else {
      more = true;
    }
  }
  if (convos.length === PURGE_PARENTS) more = true;

  return { removed, more };
}
