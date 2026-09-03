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
- **Backend project (in the repo):** `backend/`. Run all `npx convex` commands from there; creds load from `backend/.env.local`.
- **Source data:** PocketBase `data.db` → exported to `backend/data/*.jsonl` (924 records, secrets excluded)

## What was built (ready to deploy)
```
backend/
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

2. **Deploy schema + functions** (from `backend`, your Mac has Node):
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

## Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work

**Symptom:** iOS (convex‑swift) reaches `authenticated` then loops
`connected → connecting → connected …` forever. Server error on auth:
`InvalidAccountId` is a *different* issue (see iOS guide §10b); the **loop** is JWT
validation failing.

**Root cause:** Convex serves the auth metadata `/.well-known/jwks.json` and
`/.well-known/openid-configuration` on the **SITE origin (HTTP actions, port 3211)**, but
the Cloudflare tunnel routed the API hostname **only to the cloud origin (port 3210)**, and
`CONVEX_SITE_ORIGIN` was (mis)set equal to the cloud URL. So the token issuer URL
`https://nestzone-convex-api.walhallaa.com/.well-known/jwks.json` returned **404** and the
backend could not verify its own tokens.

**Fix (no container restart / DNS / redeploy):** added a **path‑based ingress rule** to
`/etc/cloudflared/config.yml` so only `/.well-known/*` goes to `:3211`:
```yaml
ingress:
  - hostname: nestzone-convex-api.walhallaa.com
    path: /\.well-known/.*
    service: http://127.0.0.1:3211     # site origin (HTTP actions) → serves JWKS
  - hostname: nestzone-convex-api.walhallaa.com
    service: http://127.0.0.1:3210     # cloud origin (sync/API) → everything else
  - hostname: nestzone-convex-dashboard.walhallaa.com
    service: http://127.0.0.1:6791
  - hostname: nestzone-pocketbase-dashboard.walhallaa.com
    service: http://127.0.0.1:8090
  - service: http_status:404
```
Then `sudo systemctl restart cloudflared-nestzone.service`. Verified publicly:
`/.well-known/jwks.json` and `/.well-known/openid-configuration` → **200**; `issuer` and
`jwks_uri` match the token's `iss`. Backup of the prior config:
`/etc/cloudflared/config.yml.bak.pre-wellknown` (restore + restart to roll back).

**Cleaner long‑term option:** give the site origin its own hostname
(`nestzone-convex-site.walhallaa.com → :3211`) and set `CONVEX_SITE_ORIGIN` to it in the
backend compose env. The path rule above is the minimal, reversible fix and is sufficient.

## Notes
- **Auth / the 7 users:** profiles are imported with `email` + `pbId` but no password
  account (PB used bcrypt). On first sign‑up with the same email, `auth.ts`
  `createOrUpdateUser` links the new account to the migrated profile. See the iOS guide §3.
- **Idempotency:** the importer refuses to run twice unless `--wipe` is passed.
- **PocketBase stays live** at `https://nestzone-pocketbase-dashboard.walhallaa.com`
  as rollback until the Convex‑based app ships.
- **Data integrity:** pre‑flight check found **0 dangling relations** across all 924 records.

## Production hardening pass (2026‑09‑03)

Applied to `backend/convex/` before the migration branch was committed.

1. **Deleted `convex/debug.ts`.** Its header claimed "SAFE to deploy: queries only, no
   writes", which stopped being true once `clearAuthForEmail` and `deleteUserByEmail`
   were added — both were **public mutations with no auth check** on a publicly
   reachable deployment. Chained with `auth.ts createOrUpdateUser` (which links a new
   signup to an existing profile by email) that was a remote account‑takeover path:
   clear a victim's auth, sign up with their email, inherit their user doc, home
   membership and chat history. **This still needs `npx convex deploy` to take effect —
   the functions remain live on the deployment until you redeploy.**

2. **Replaced 18 conditional auth checks.** `if (doc.home_id) await requireHomeMember(...)`
   skipped *both* membership and authentication whenever `home_id` was absent (every
   `home_id` is `v.optional` because PocketBase allowed empty relations). Now
   `requireDocHome(ctx, doc, label)` in `convex/lib/auth.ts` throws instead: a document
   not attached to a home is unreachable, not unprotected. Sites: polls (5), movies (4),
   shopping (3), notes (2), recipes (2), tasks (2).

3. **Restored PocketBase poll ownership.** `polls.owner_id` was dropped during the export,
   so "update/delete: owner‑only" (see `Docs/PocketBase/README.md`) had degraded to
   any‑home‑member. `owner_id` is back on the schema, `polls:create` records it, and
   `polls:remove` / `polls:setStatus` go through `requirePollOwner`. `polls:addItem` again
   requires the poll to be active, per the PB rule.
   **Open item:** the 23 polls migrated from PocketBase have no `owner_id` and stay
   member‑editable. To tighten, read `owner_id` per `pbId` from the live PocketBase and
   patch the matching Convex docs (`by_pbId` index is still in place).

4. **`homes:leave`** now asserts membership before patching (previously any authenticated
   user could touch any home's `updated`). **`movies:addMovie`** now rejects a `listId`
   that belongs to a different home than `homeId`.

**Open data item:** 60 of 349 `poll_votes` have `user_id: null`, concentrated in 4 polls.
The original audit reported "0 dangling relations" because that check skips nulls. Those
votes count toward totals but belong to nobody. Source values are still in PocketBase.

**Intentionally not restored:** `polls.candidates`, `polls.config`, `polls.expires_at` and
`poll_votes.item_id`. The client moved to `poll_items` / `target_external_id` and no Swift
code reads any of them; all 349 votes carry `target_external_id`, so no votes were lost.
