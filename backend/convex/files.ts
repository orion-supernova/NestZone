// Claims for files attached before claims existed (lib/files.ts).
//
// Run once after the deploy that adds `file_claims`:
//
//   npx convex run files:backfillClaims '{}'
//
// It walks every table that owns a file field, a page at a time, and schedules
// its own continuation, so one invocation finishes the job. Idempotent: a file
// already claimed is skipped, so re-running costs a scan and writes nothing.
//
// Order matters where two owners name the same file, which only an unchecked
// writer could have caused: the first table to reach it keeps it. Faces go
// first, so a house row that names somebody's avatar can never free it; then
// problem photos and chat files, which came through the app's upload flows;
// then `tasks/notes/recipes.image`, which no build uploads to. A conflict is
// logged and left as it is.
//
// `reports` and `report_holds` own nothing: a report's snapshot names the
// reported row's file, which that row's table claims, and a hold keeps a file
// alive without making it anybody's.

import { v } from "convex/values";
import { internalMutation, MutationCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { FileOwner } from "./lib/files";

const PAGE = 100;

const ORDER = ["users", "issues", "messages", "tasks", "notes", "recipes"] as const;
type Table = (typeof ORDER)[number];

const tableValidator = v.union(
  v.literal("users"),
  v.literal("issues"),
  v.literal("messages"),
  v.literal("tasks"),
  v.literal("notes"),
  v.literal("recipes"),
);

type Counts = { claimed: number; already: number; conflicts: number; missing: number };

/** Claims one file for `owner` unless it is claimed already. Never throws. */
async function backfillOne(
  ctx: MutationCtx,
  storageId: Id<"_storage"> | undefined,
  owner: FileOwner,
  counts: Counts,
): Promise<void> {
  if (!storageId) return;
  const claim = await ctx.db
    .query("file_claims")
    .withIndex("by_storage", (q) => q.eq("storage_id", storageId))
    .first();
  if (claim) {
    const same = owner.homeId !== undefined
      ? claim.home_id === owner.homeId
      : claim.home_id === undefined && claim.user_id === owner.userId;
    if (same) {
      counts.already += 1;
    } else {
      counts.conflicts += 1;
      console.warn(
        `files:backfillClaims: ${storageId} is claimed by ${claim.home_id ?? `user ${claim.user_id}`} ` +
          `(${claim.kind}) and also named by ${owner.homeId ?? `user ${owner.userId}`} (${owner.kind}); left as it is`,
      );
    }
    return;
  }
  if (!(await ctx.db.system.get("_storage", storageId))) {
    counts.missing += 1;
    return;
  }
  await ctx.db.insert("file_claims", {
    storage_id: storageId,
    ...(owner.homeId !== undefined ? { home_id: owner.homeId } : {}),
    user_id: owner.userId,
    kind: owner.kind,
    created: Date.now(),
  });
  counts.claimed += 1;
}

async function backfillPage(
  ctx: MutationCtx,
  table: Table,
  cursor: string | null,
  counts: Counts,
): Promise<{ continueCursor: string; isDone: boolean }> {
  const opts = { numItems: PAGE, cursor };
  switch (table) {
    case "users": {
      const p = await ctx.db.query("users").paginate(opts);
      for (const r of p.page) {
        await backfillOne(ctx, r.avatar, { userId: r._id, kind: "avatar" }, counts);
      }
      return p;
    }
    case "issues": {
      const p = await ctx.db.query("issues").paginate(opts);
      for (const r of p.page) {
        const owner = { homeId: r.home_id, userId: r.reported_by };
        for (const id of r.photos ?? []) await backfillOne(ctx, id, { ...owner, kind: "issue_photo" }, counts);
        for (const id of r.photo_thumbs ?? []) await backfillOne(ctx, id, { ...owner, kind: "issue_thumb" }, counts);
      }
      return p;
    }
    case "messages": {
      const p = await ctx.db.query("messages").paginate(opts);
      for (const r of p.page) {
        if (!r.file) continue;
        const convo = await ctx.db.get(r.conversation_id);
        if (!convo) continue;
        await backfillOne(ctx, r.file, { homeId: convo.home_id, userId: r.sender_id, kind: "message" }, counts);
      }
      return p;
    }
    case "tasks": {
      const p = await ctx.db.query("tasks").paginate(opts);
      for (const r of p.page) {
        await backfillOne(ctx, r.image, { homeId: r.home_id, userId: r.created_by, kind: "task_image" }, counts);
      }
      return p;
    }
    case "notes": {
      const p = await ctx.db.query("notes").paginate(opts);
      for (const r of p.page) {
        await backfillOne(ctx, r.image, { homeId: r.home_id, userId: r.created_by, kind: "note_image" }, counts);
      }
      return p;
    }
    case "recipes": {
      const p = await ctx.db.query("recipes").paginate(opts);
      for (const r of p.page) {
        await backfillOne(ctx, r.image, { homeId: r.home_id, userId: r.created_by, kind: "recipe_image" }, counts);
      }
      return p;
    }
  }
}

/** One page of one table, then the next page (or table) scheduled. */
export const backfillClaims = internalMutation({
  args: {
    table: v.optional(tableValidator),
    cursor: v.optional(v.union(v.string(), v.null())),
  },
  returns: v.object({
    table: tableValidator,
    claimed: v.number(),
    already: v.number(),
    conflicts: v.number(),
    missing: v.number(),
    done: v.boolean(),
  }),
  handler: async (ctx, args) => {
    const table: Table = args.table ?? ORDER[0];
    const counts: Counts = { claimed: 0, already: 0, conflicts: 0, missing: 0 };
    const page = await backfillPage(ctx, table, args.cursor ?? null, counts);

    let done = false;
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.files.backfillClaims, {
        table,
        cursor: page.continueCursor,
      });
    } else {
      const next = ORDER[ORDER.indexOf(table) + 1];
      if (next) {
        await ctx.scheduler.runAfter(0, internal.files.backfillClaims, { table: next, cursor: null });
      } else {
        done = true;
      }
    }
    console.log(`files:backfillClaims ${table} ${JSON.stringify(counts)}${done ? " (finished)" : ""}`);
    return { table, ...counts, done };
  },
});
