// Stored files that nothing points at.
//
// A file can be orphaned in ways no delete path can see: the app uploads to a
// signed URL and is killed before the storage id reaches `attachPhotos` or
// `setAvatar`; a row is deleted whose file its house never claimed
// (`tasks.image`, `notes.image`, `recipes.image` are freed only when the
// claim is the house's, see `discardHomeFile`). This finds them.
//
// Log-only until `STORAGE_REAP=on`:
//
//   npx convex env set STORAGE_REAP on
//
// Off (the default), the weekly run reports how many files and bytes it would
// reclaim and deletes nothing. On, it deletes them through `discardFile`, so a
// file a report holds is deferred, never destroyed.
//
// "Referenced" is every `v.id("_storage")` field in schema.ts plus
// `report_holds`. A new table with a file field must be added to `REF_TABLES`
// below, or its files read as orphans — which is why the default is off and
// why a run that cannot read every reference deletes nothing.
//
// `file_claims` (lib/files.ts) is deliberately not a reference: a claim says
// whose a file is, not that anything uses it. An orphan's claim goes with it
// (`discardFile` drops it), and a reaping run also drops claims whose file is
// already gone (`pruneClaims`).

import { v } from "convex/values";
import { paginationOptsValidator } from "convex/server";
import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { discardFile } from "./lib/moderation";

/** A file must be at least this old to count: an upload in flight is not an orphan. */
const MIN_AGE_MS = 7 * 24 * 60 * 60 * 1000;
/** Rows read per page of a referencing table. */
const REF_PAGE = 250;
/** Files read per page of `_storage`. */
const STORAGE_PAGE = 500;
/** Pages any one table may take before the run gives up (and deletes nothing). */
const MAX_PAGES = 2000;
/** Orphans deleted per mutation when reaping is on. */
const DELETE_CHUNK = 100;
/** Orphans one run deletes at most; the rest wait for next week. */
const MAX_DELETES_PER_RUN = 2000;

const refTable = v.union(
  v.literal("users"),
  v.literal("tasks"),
  v.literal("notes"),
  v.literal("recipes"),
  v.literal("messages"),
  v.literal("issues"),
  v.literal("reports"),
  v.literal("report_holds"),
);

/** Every table with a `v.id("_storage")` field (schema.ts), plus the holds. */
const REF_TABLES = [
  "users", "tasks", "notes", "recipes", "messages", "issues", "reports", "report_holds",
] as const;

const pageResult = v.object({
  ids: v.array(v.string()),
  continueCursor: v.string(),
  isDone: v.boolean(),
});

/** One page of one referencing table, as the storage ids it names. */
export const refPage = internalQuery({
  args: { table: refTable, paginationOpts: paginationOptsValidator },
  returns: pageResult,
  handler: async (ctx, { table, paginationOpts }) => {
    const opts = { ...paginationOpts, numItems: Math.min(paginationOpts.numItems, REF_PAGE) };
    const ids: string[] = [];
    const push = (id: Id<"_storage"> | undefined) => {
      if (id) ids.push(id);
    };
    switch (table) {
      case "users": {
        const p = await ctx.db.query("users").paginate(opts);
        for (const r of p.page) push(r.avatar);
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
      case "tasks": {
        const p = await ctx.db.query("tasks").paginate(opts);
        for (const r of p.page) push(r.image);
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
      case "notes": {
        const p = await ctx.db.query("notes").paginate(opts);
        for (const r of p.page) push(r.image);
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
      case "recipes": {
        const p = await ctx.db.query("recipes").paginate(opts);
        for (const r of p.page) push(r.image);
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
      case "messages": {
        const p = await ctx.db.query("messages").paginate(opts);
        for (const r of p.page) push(r.file);
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
      case "issues": {
        const p = await ctx.db.query("issues").paginate(opts);
        for (const r of p.page) {
          for (const id of r.photos ?? []) push(id);
          for (const id of r.photo_thumbs ?? []) push(id);
        }
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
      case "reports": {
        const p = await ctx.db.query("reports").paginate(opts);
        for (const r of p.page) {
          push(r.snapshot.storage_id);
          push(r.snapshot.thumb_id);
        }
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
      case "report_holds": {
        const p = await ctx.db.query("report_holds").paginate(opts);
        for (const r of p.page) push(r.storage_id);
        return { ids, continueCursor: p.continueCursor, isDone: p.isDone };
      }
    }
  },
});

/** One page of the `_storage` system table. */
export const storagePage = internalQuery({
  args: { paginationOpts: paginationOptsValidator },
  returns: v.object({
    files: v.array(v.object({ id: v.id("_storage"), created: v.number(), size: v.number() })),
    continueCursor: v.string(),
    isDone: v.boolean(),
  }),
  handler: async (ctx, { paginationOpts }) => {
    const opts = { ...paginationOpts, numItems: Math.min(paginationOpts.numItems, STORAGE_PAGE) };
    const p = await ctx.db.system.query("_storage").paginate(opts);
    return {
      files: p.page.map((f) => ({ id: f._id, created: f._creationTime, size: f.size })),
      continueCursor: p.continueCursor,
      isDone: p.isDone,
    };
  },
});

/** Deletes orphans through `discardFile`, so a held file is deferred instead. */
export const discardOrphans = internalMutation({
  args: { ids: v.array(v.id("_storage")) },
  returns: v.null(),
  handler: async (ctx, { ids }) => {
    for (const id of ids.slice(0, DELETE_CHUNK)) await discardFile(ctx, id);
    return null;
  },
});

/** Claims read per page when pruning. */
const CLAIM_PAGE = 200;

/** Drops one page of claims whose file no longer exists. */
export const pruneClaims = internalMutation({
  args: { cursor: v.union(v.string(), v.null()) },
  returns: v.object({ dropped: v.number(), continueCursor: v.string(), isDone: v.boolean() }),
  handler: async (ctx, { cursor }) => {
    const p = await ctx.db.query("file_claims").paginate({ numItems: CLAIM_PAGE, cursor });
    let dropped = 0;
    for (const claim of p.page) {
      if (await ctx.db.system.get("_storage", claim.storage_id)) continue;
      await ctx.db.delete(claim._id);
      dropped += 1;
    }
    return { dropped, continueCursor: p.continueCursor, isDone: p.isDone };
  },
});

/**
 * The weekly report: files older than a week that no row and no hold names,
 * their count and bytes, logged. Deletes them only when `STORAGE_REAP=on`, and
 * never when any referencing table could not be read in full.
 */
export const reapReport = internalAction({
  args: {},
  returns: v.object({
    files: v.number(),
    bytes: v.number(),
    orphans: v.number(),
    orphanBytes: v.number(),
    deleted: v.number(),
    claimsDropped: v.number(),
    reaping: v.boolean(),
    complete: v.boolean(),
  }),
  handler: async (ctx) => {
    const reaping = process.env.STORAGE_REAP === "on";

    // Every reference first. A table that runs past its page cap leaves the
    // set incomplete, and an incomplete set must never decide a delete.
    const referenced = new Set<string>();
    let complete = true;
    for (const table of REF_TABLES) {
      let cursor: string | null = null;
      let pages = 0;
      for (;;) {
        const page: { ids: string[]; continueCursor: string; isDone: boolean } =
          await ctx.runQuery(internal.storage.refPage, {
            table,
            paginationOpts: { numItems: REF_PAGE, cursor },
          });
        for (const id of page.ids) referenced.add(id);
        pages += 1;
        if (page.isDone) break;
        if (pages >= MAX_PAGES) {
          console.error(`storage:reapReport: ${table} has more than ${MAX_PAGES * REF_PAGE} rows; nothing will be deleted`);
          complete = false;
          break;
        }
        cursor = page.continueCursor;
      }
    }

    // Then every file.
    const cutoff = Date.now() - MIN_AGE_MS;
    let files = 0;
    let bytes = 0;
    let orphanBytes = 0;
    const orphans: Id<"_storage">[] = [];
    let cursor: string | null = null;
    let pages = 0;
    for (;;) {
      const page: {
        files: { id: Id<"_storage">; created: number; size: number }[];
        continueCursor: string;
        isDone: boolean;
      } = await ctx.runQuery(internal.storage.storagePage, {
        paginationOpts: { numItems: STORAGE_PAGE, cursor },
      });
      for (const f of page.files) {
        files += 1;
        bytes += f.size;
        if (f.created <= cutoff && !referenced.has(f.id)) {
          orphans.push(f.id);
          orphanBytes += f.size;
        }
      }
      pages += 1;
      if (page.isDone) break;
      if (pages >= MAX_PAGES) {
        console.error(`storage:reapReport: _storage has more than ${MAX_PAGES * STORAGE_PAGE} files; counted the first ones only`);
        break;
      }
      cursor = page.continueCursor;
    }

    let deleted = 0;
    if (reaping && complete) {
      const batch = orphans.slice(0, MAX_DELETES_PER_RUN);
      for (let i = 0; i < batch.length; i += DELETE_CHUNK) {
        const chunk = batch.slice(i, i + DELETE_CHUNK);
        await ctx.runMutation(internal.storage.discardOrphans, { ids: chunk });
        deleted += chunk.length;
      }
    }

    // Claims on files that are gone, so none outlives its file.
    let claimsDropped = 0;
    if (reaping) {
      let claimCursor: string | null = null;
      for (let pages = 0; pages < MAX_PAGES; pages++) {
        const r: { dropped: number; continueCursor: string; isDone: boolean } =
          await ctx.runMutation(internal.storage.pruneClaims, { cursor: claimCursor });
        claimsDropped += r.dropped;
        if (r.isDone) break;
        claimCursor = r.continueCursor;
      }
    }

    const summary = {
      files,
      bytes,
      orphans: orphans.length,
      orphanBytes,
      deleted,
      claimsDropped,
      reaping,
      complete,
    };
    console.log(
      `storage:reapReport ${JSON.stringify(summary)}` +
        (orphans.length > 0 ? ` sample=${orphans.slice(0, 10).join(",")}` : ""),
    );
    return summary;
  },
});
