# NestZone backend — Convex deploy & data‑import runbook

> ✅ **DONE (2026‑06‑18).** Schema + auth + all domain functions are deployed to the
> remote self‑hosted Convex, and all **924 records were imported and verified**
> (relations remapped to real Convex ids; bidirectional integrity confirmed). The
> one‑shot import endpoint was removed, `MIGRATION_SECRET` unset, and local admin‑key
> files scrubbed. The section below is retained as the reproducible procedure (e.g. for a
> re‑import via `_archive/migrate.ts.done`).

Status of the **remote** self‑hosted Convex migration and how it was done.

- **Deployment (cloud) URL:** `https://nestzone-convex-api.walhallaa.com`
- **Dashboard:** `https://nestzone-convex-dashboard.walhallaa.com`
- **Backend project (not in the iOS repo):** `~/nestzone-migration/`
- **Source data:** PocketBase `data.db` → exported to `~/nestzone-migration/data/*.jsonl` (924 records, secrets excluded)

## What was built (ready to deploy)
```
~/nestzone-migration/
├── package.json / tsconfig.json
├── convex/
│   ├── schema.ts            # 13 tables + Convex Auth tables; relations as v.id()
│   ├── auth.ts              # Password provider + email auto-linking of migrated users
│   ├── auth.config.ts, http.ts
│   ├── lib/auth.ts          # requireUser / requireHomeMember helpers
│   ├── migrate.ts           # two-pass importer (insert → remap relations); cycle-safe
│   ├── users.ts homes.ts tasks.ts shopping.ts notes.ts
│   ├── conversations.ts messages.ts polls.ts movies.ts recipes.ts
├── scripts/run-migration.mjs
└── data/*.jsonl
```

## Reproducing the deploy + import (already executed)

> The admin key never needs to be pasted into a chat. Generate it and keep it in your shell.

1. **Generate an admin key** (on the server):
   ```bash
   docker exec nestzone-backend ./generate_admin_key.sh
   ```

2. **Deploy schema + functions** (from `~/nestzone-migration`, your Mac has Node):
   ```bash
   export CONVEX_SELF_HOSTED_URL="https://nestzone-convex-api.walhallaa.com"
   export CONVEX_SELF_HOSTED_ADMIN_KEY="<paste-key-here>"
   npx convex deploy
   ```

3. **Set the import secret** (gate for the one‑shot importer):
   ```bash
   npx convex env set MIGRATION_SECRET "$(openssl rand -hex 24)"   # remember this value
   ```

4. **Import the data** (two‑pass; remaps every PocketBase id to a Convex id):
   ```bash
   CONVEX_URL="$CONVEX_SELF_HOSTED_URL" MIGRATION_SECRET="<same value>" \
     node scripts/run-migration.mjs            # add --wipe to clear & reimport
   ```
   Expected: `inserted` counts matching — users 7, homes 5, messages 62, poll_items 460,
   poll_votes 349, polls 23, movies 5, movie_lists 3, notes 4, shopping_items 3,
   conversations 2, recipes 1, tasks 0.

5. **Verify** in the dashboard, then **lock down**:
   - Delete `convex/migrate.ts` and re‑`npx convex deploy` (removes the import endpoint).
   - Optionally unset `MIGRATION_SECRET`.
   - The `pbId` fields + `by_pbId` indexes can stay (handy for cross‑checks) or be dropped later.

## Notes
- **Auth / the 7 users:** profiles are imported with `email` + `pbId` but no password
  account (PB used bcrypt). On first sign‑up with the same email, `auth.ts`
  `createOrUpdateUser` links the new account to the migrated profile. See the iOS guide §3.
- **Idempotency:** the importer refuses to run twice unless `--wipe` is passed.
- **PocketBase stays live** at `https://nestzone-pocketbase-dashboard.walhallaa.com`
  as rollback until the Convex‑based app ships.
- **Data integrity:** pre‑flight check found **0 dangling relations** across all 924 records.
