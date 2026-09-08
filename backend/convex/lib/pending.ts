import { QueryCtx } from "../_generated/server";
import { Doc, Id } from "../_generated/dataModel";

/**
 * The unfinished half of a household's lists.
 *
 * Both of these answer the same shape of question — what is still on the
 * shopping list, what is still to be done — and both used to be answered the
 * same wrong way: collect every row the home has ever had and filter in
 * JavaScript.
 *
 * That read is unbounded in the household's history and it never shrinks.
 * Buying something does not remove it and neither does finishing a chore; both
 * flip a flag, and the row stays. A year of use is thousands of documents
 * fetched to produce a number in the low tens, and it is what spent the whole
 * one-second query budget in `events:detail` and failed the event sheet
 * outright.
 *
 * It was also far too wide a *read set*, which is the half that bites soonest.
 * Convex re-runs a query when anything it read changes, so a query that reads
 * every row re-runs on every write to that table — including the finished rows
 * it only ever discarded. Ticking one item off re-ran the whole scan, which is
 * why the timeout showed up while working down a list rather than on open.
 *
 * Indexed, the read *is* the answer: only unfinished rows are touched, so only
 * a change to an unfinished row can invalidate it.
 *
 * ---
 *
 * Both flags are `v.optional(v.boolean())`, so "not done" is two distinct index
 * keys rather than one: an explicit `false`, which is what every write in this
 * codebase sets, and a missing value. Nothing should be writing the second any
 * more, but an index range cannot match "false or absent" in one pass, and a
 * count that silently omitted a row would be a worse bug than one extra scan of
 * a range that is nearly always empty. So both buckets are read.
 */
const FALSY = [false, undefined] as const;

/** Everything on the household's shopping list that nobody has bought yet. */
export async function outstandingItems(
  ctx: QueryCtx,
  homeId: Id<"homes">,
): Promise<Doc<"shopping_items">[]> {
  const buckets = await Promise.all(
    FALSY.map((purchased) =>
      ctx.db
        .query("shopping_items")
        .withIndex("by_home_purchased", (q) =>
          q.eq("home_id", homeId).eq("is_purchased", purchased),
        )
        .collect(),
    ),
  );
  return buckets.flat();
}

/**
 * The outstanding list as a set of comparable names.
 *
 * Trimmed and lowercased because that is how every caller compares them, and
 * doing it in one place keeps "already on the list" meaning the same thing in
 * the button that offers a write and the mutation that performs it.
 */
export async function outstandingNames(
  ctx: QueryCtx,
  homeId: Id<"homes">,
): Promise<Set<string>> {
  const items = await outstandingItems(ctx, homeId);
  return new Set(items.map((it) => (it.name ?? "").trim().toLowerCase()));
}

/** Every task in the home that is still to be done. */
export async function openTasks(
  ctx: QueryCtx,
  homeId: Id<"homes">,
): Promise<Doc<"tasks">[]> {
  const buckets = await Promise.all(
    FALSY.map((completed) =>
      ctx.db
        .query("tasks")
        .withIndex("by_home_completed", (q) =>
          q.eq("home_id", homeId).eq("is_completed", completed),
        )
        .collect(),
    ),
  );
  return buckets.flat();
}
