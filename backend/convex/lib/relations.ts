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
  for (const id of userIds) {
    await requireRef(ctx, id, `${label} user`);
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
  for (const m of messages) await ctx.db.delete(m._id);
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
  for (const i of items) await ctx.db.delete(i._id);
  const votes = await ctx.db
    .query("poll_votes")
    .withIndex("by_poll", (q) => q.eq("poll_id", pollId))
    .collect();
  for (const v of votes) await ctx.db.delete(v._id);
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
  for (const m of movies) await ctx.db.delete(m._id);
  await ctx.db.delete(listId);
  return movies.length;
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

  const simple = ["tasks", "shopping_items", "notes", "recipes", "movies"] as const;
  for (const table of simple) {
    const rows = await ctx.db
      .query(table)
      .withIndex("by_home", (q) => q.eq("home_id", homeId))
      .collect();
    for (const r of rows) await ctx.db.delete(r._id);
    removed[table] = rows.length;
  }

  const lists = await ctx.db
    .query("movie_lists")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .collect();
  for (const l of lists) await cascadeDeleteMovieList(ctx, l._id);
  removed["movie_lists"] = lists.length;

  const polls = await ctx.db
    .query("polls")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .collect();
  let pollItems = 0;
  let pollVotes = 0;
  for (const p of polls) {
    const r = await cascadeDeletePoll(ctx, p._id);
    pollItems += r.items;
    pollVotes += r.votes;
  }
  removed["polls"] = polls.length;
  removed["poll_items"] = pollItems;
  removed["poll_votes"] = pollVotes;

  const convos = await ctx.db
    .query("conversations")
    .withIndex("by_home", (q) => q.eq("home_id", homeId))
    .collect();
  let messages = 0;
  for (const c of convos) messages += await cascadeDeleteConversation(ctx, c._id);
  removed["conversations"] = convos.length;
  removed["messages"] = messages;

  // Scrub the denormalised mirror on users so no user points at a dead home.
  const users = await ctx.db.query("users").collect();
  let scrubbed = 0;
  for (const u of users) {
    const homes = u.home_id ?? [];
    if (homes.some((h) => h === homeId)) {
      await ctx.db.patch(u._id, { home_id: homes.filter((h) => h !== homeId) });
      scrubbed++;
    }
  }
  removed["users_scrubbed"] = scrubbed;

  await ctx.db.delete(homeId);
  removed["homes"] = 1;
  return removed;
}
