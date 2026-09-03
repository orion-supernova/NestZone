# Nestzone — PocketBase → Convex migration

Migrates the live PocketBase data (`pb_data/data.db` on the PocketBase host — see the
team password manager for the address) into the self-hosted Convex deployment
(`nestzone-convex`). **924 records, 13 tables, no files.**

## What's here
- `data/*.jsonl` — exported PocketBase data (one file per collection, secrets excluded).
  **Gitignored — production PII** (real emails/names, chat bodies, home invite codes). Local only.
- `convex/schema.ts` — Convex schema (proper `v.id()` relations, `pbId` kept for remap).
- `convex/migrate.ts` — one-shot two-pass importer (insert → remap relations). Cycle-safe.
- `scripts/run-migration.mjs` — loads the JSONL and calls the importer.

## Steps
1. **Copy into your Convex app**
   - Merge `convex/schema.ts` into your app's `convex/schema.ts` (it includes `...authTables`).
   - Drop `convex/migrate.ts` into your app's `convex/` folder.
2. **Set the secret** on the deployment:
   `npx convex env set MIGRATION_SECRET "$(openssl rand -hex 24)"` (use the same value below).
3. **Deploy** so the schema + importer are live: `npx convex deploy` (or `dev`).
4. **Run the import** (from this folder, after `npm i convex`):
   ```bash
   CONVEX_URL=https://nestzone-convex-api.walhallaa.com \
   MIGRATION_SECRET=<the value from step 2> \
   node scripts/run-migration.mjs
   ```
   Re-run with `--wipe` to clear and reimport.
5. **Verify** counts, then **delete `convex/migrate.ts`** and redeploy. Optionally drop the
   `pbId` fields + `by_pbId` indexes once you're confident.

## Type/field mapping applied
| PocketBase | Convex |
|---|---|
| relation (single) | `v.id("target")` |
| relation (maxSelect>1) | `v.array(v.id("target"))` |
| geoPoint `{lon,lat}` | `{ lat, lng }` |
| select | `v.union(v.literal(...))` |
| json | `v.any()` |
| file | `v.id("_storage")` (empty in current data) |
| autodate/date | epoch-ms `number` (`created`/`updated`) |

## ⚠️ Auth caveat (the one real gotcha)
PocketBase password hashes are **bcrypt** and are NOT migrated (Convex Auth's Password
provider uses a different KDF). The 7 user **profiles** are migrated (incl. `email`), but
there are no `authAccounts`, so:
- New sign-ups won't auto-link to the migrated profile.
- **Recommended:** on first sign-in, match the authenticated `email` to the migrated
  `users` doc and merge (copy `home_id` etc. onto the auth user, delete the placeholder),
  or pre-create password accounts and force "reset password" for those 7 emails.

This only affects the 7 users; all other data migrates with real relations intact.
