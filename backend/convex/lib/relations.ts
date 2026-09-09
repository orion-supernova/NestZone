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
 * Called when the last member leaves. Without this the home's rows survive with
 * no member able to satisfy `requireHomeMember`, i.e. permanently unreachable
 * data that no code path can ever read, write or clean up again.
 */
export async function cascadeDeleteHome(
  ctx: MutationCtx,
  homeId: Id<"homes">,
): Promise<Record<string, number>> {
  const removed: Record<string, number> = {};
  // Read before anything is deleted: the home doc carries the member list the
  // mirror-scrub below needs, and this function ends by deleting it.
  const memberIds = (await ctx.db.get(homeId))?.members ?? [];

  // Every table at once, and every row within a table at once.
  //
  // This was eleven index scans taken end to end and then one `delete` awaited
  // per row, which on any household with history cannot finish inside a
  // mutation's one second. It is called when the last member leaves — and the
  // comment above is the whole point: if it times out, the home's rows survive
  // with nobody able to satisfy `requireHomeMember`, which is precisely the
  // unreachable data this function exists to prevent.
  //
  // `issue_comments` is in here rather than behind a per-issue cascade for the
  // same reason: it carries `home_id` precisely so a household's entries are one
  // index range instead of one read per problem the household ever had.
  const simple = [
    "tasks", "shopping_items", "notes", "recipes", "movies", "meal_plans",
    "expenses", "settlements", "bills", "budgets", "events",
    "issues", "issue_comments",
  ] as const;
  await Promise.all(
    simple.map(async (table) => {
      const rows = await ctx.db
        .query(table)
        .withIndex("by_home", (q) => q.eq("home_id", homeId))
        .collect();
      await Promise.all(rows.map((r) => ctx.db.delete(r._id)));
      removed[table] = rows.length;
    }),
  );

  const [lists, polls, convos, members] = await Promise.all([
    ctx.db
      .query("movie_lists")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect(),
    ctx.db
      .query("polls")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect(),
    ctx.db
      .query("conversations")
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect(),
    // The home's own members, not every user in the deployment. The old read
    // was `ctx.db.query("users").collect()` — an unindexed scan of the entire
    // user table to find the handful of rows whose mirror points here, growing
    // with the app's sign-ups rather than with the household being deleted.
    // `homes.members` is the authoritative membership list (it is what
    // `requireHomeMember` enforces) and the mirror is patched alongside it in
    // the same transaction, so these are exactly the users to scrub.
    Promise.all(memberIds.map((id) => ctx.db.get(id))),
  ]);

  const [, pollResults, messageCounts, scrubbed] = await Promise.all([
    Promise.all(lists.map((l) => cascadeDeleteMovieList(ctx, l._id))),
    Promise.all(polls.map((p) => cascadeDeletePoll(ctx, p._id))),
    Promise.all(convos.map((c) => cascadeDeleteConversation(ctx, c._id))),
    // Scrub the denormalised mirror on users so no user points at a dead home.
    Promise.all(
      members
        .filter((u) => u !== null && (u.home_id ?? []).some((h) => h === homeId))
        .map((u) =>
          ctx.db
            .patch(u!._id, {
              home_id: (u!.home_id ?? []).filter((h) => h !== homeId),
            })
            .then(() => 1),
        ),
    ),
  ]);

  removed["movie_lists"] = lists.length;
  removed["polls"] = polls.length;
  removed["poll_items"] = pollResults.reduce((n, r) => n + r.items, 0);
  removed["poll_votes"] = pollResults.reduce((n, r) => n + r.votes, 0);
  removed["conversations"] = convos.length;
  removed["messages"] = messageCounts.reduce((n, c) => n + c, 0);
  removed["users_scrubbed"] = scrubbed.length;

  await ctx.db.delete(homeId);
  removed["homes"] = 1;
  return removed;
}
