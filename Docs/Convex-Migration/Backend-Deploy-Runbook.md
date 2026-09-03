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
   **Resolved by the data cleanup below:** rather than backfill, the 23 ownerless legacy
   polls were purged and `owner_id` is now a required field, so `requirePollOwner` is an
   unconditional owner check.

4. **`homes:leave`** now asserts membership before patching (previously any authenticated
   user could touch any home's `updated`). **`movies:addMovie`** now rejects a `listId`
   that belongs to a different home than `homeId`.

**Resolved by the data cleanup below.**

**Intentionally not restored:** `polls.candidates`, `polls.config`, `polls.expires_at` and
`poll_votes.item_id`. The client moved to `poll_items` / `target_external_id` and no Swift
code reads any of them; all 349 votes carry `target_external_id`, so no votes were lost.

## Data cleanup + indexing (2026‑09‑03, deployed)

Run through a temporary `convex/maintenance.ts` holding `internalQuery`/`internalMutation`
helpers — not publicly callable, invoked with `npx convex run` under the admin key — then
deleted and redeployed. Live function list is now exactly the domain functions plus the
four `auth:*` entries: no `debug:`, no `maintenance:`, no `migrate:`.

**A full audit found more than the original one did.** The migration's own audit checked
only for *dangling* references and so skipped nulls entirely. The real gaps were:

| gap | rows | disposition |
|---|---|---|
| `polls.owner_id` null | 23 of 23 | **purged** (all polls) |
| `poll_votes.user_id` null | 60 of 349 | **purged** |
| `messages.sender_id` null | 4 of 62 | **purged** — see below |
| `shopping_items.created_by` null | 3 of 3 | **kept** — metadata only, access is via `home_id` |

**Poll domain purged.** Every poll lacked `owner_id`, so "delete the ownerless ones" meant
the whole poll history: 23 polls, 460 items, 349 votes. Accepted deliberately — poll
history is disposable and new polls are cheap to recreate. Backed up first to
`backend/data/poll-domain-backup-2026-09-03.json` (gitignored) via `dumpPollDomain`, so it
is reversible.

**Schema tightened** now that the tables are clean, which is what makes the bad states
unrepresentable rather than merely absent:
- `polls.home_id`, `polls.owner_id` → required
- `poll_items.poll_id`, `poll_items.external_id` → required
- `poll_votes.poll_id`, `poll_votes.user_id`, `poll_votes.target_external_id`,
  `poll_votes.vote` → required
- `messages.sender_id`, `messages.conversation_id` → required (see the senderless-message
  cleanup below)
- `shopping_items.created_by` stays optional **on purpose**: 3 live rows have no creator
  and the value cannot be reconstructed, so requiring it would fail schema validation on
  push. It is never rendered — `ShoppingItem.createdBy` is `String?` and no view reads it —
  so those items display normally.

**11 indexes added, 12 table scans removed.** Every `listByHome` was doing
`.filter(q => q.eq(q.field("home_id"), homeId))`, which reads the whole table on every
call — including on live subscriptions, so the cost recurred on every reactive update.
New indexes: `by_home` on tasks / shopping_items / notes / conversations / recipes /
polls / movies / movie_lists, `by_list` on movies, `by_invite_code` on homes, and
`by_poll_user_target` on poll_votes (which also collapsed the vote-lookup from an indexed
read plus a filter into a single compound-index read).

`homes:listMine` still scans `homes` (5 rows) and filters on the `members` array —
Convex cannot index array containment, so this needs a join table if homes ever grow.

**Not done:** `returns:` validators on the ~50 public functions. The Convex lint asks for
them and they are worth adding, but a wrong return validator rejects a valid response at
runtime, so it is a change to make deliberately with the client in front of you — not as
a drive-by during a data cleanup.

### Senderless messages purged (2026‑09‑03)

The 4 `messages` rows with a null `sender_id` were deleted. Inspected first: all four were
throwaway tests from Aug 2025 ("123", "test", "Amber", "Naber\*\*"), all in one
conversation, and none was any conversation's `last_message` preview — so no real content
was lost and no chat-list entry pointed at them. The cleanup mutation recomputed the
affected conversation's `last_message` / `last_message_at` from the newest surviving
message regardless, so the preview cannot go stale even if that had been the case.

Messages went 62 → 58. `messages.sender_id` and `messages.conversation_id` are now
**required**, which is what makes a senderless message unrepresentable rather than merely
absent — `messages:send` has always taken the sender from the authenticated session, so
nothing in the app could produce one anyway.

**`shopping_items.created_by` deliberately left alone.** All 3 rows lack it, but the field
is never displayed (`ShoppingItem.createdBy` is `String?`, no view reads it) and access is
governed by `home_id`, not by the creator — so the items render and function normally.
Deleting real shopping-list content to tidy an invisible metadata field would be a net
loss, and the field must stay `v.optional` for schema validation to pass.

## Referential integrity (2026‑09‑03)

**Convex has no foreign keys.** `v.id("table")` is a *type*: it is not checked against the
target table on write, and there is no `ON DELETE CASCADE`. Every relation therefore has to
be validated in code when written and cleaned up when its parent goes away. That lives in
`convex/lib/relations.ts`:

| helper | use |
|---|---|
| `requireRef(ctx, id, label)` | load a referenced doc or throw — before storing any `v.id()` |
| `requireSameHome(doc, homeId, label)` | referenced doc must live in the expected home |
| `requireMembers(ctx, home, userIds, label)` | every named user exists *and* is a member |
| `cascadeDeleteConversation` / `cascadeDeletePoll` / `cascadeDeleteMovieList` / `cascadeDeleteHome` | delete a parent and all its children |

**Rule: never call a bare `ctx.db.delete` on a row that owns children — use a cascade.**

**Holes this closed.** A relation audit of the live data came back clean (0 dangling refs,
0 cross‑home refs, 0 memberless homes, 0 non‑member participants), so nothing needed
repairing — but the *code* could still create all of them:

1. **`conversations:create` never validated `participants`.** It accepted any
   `v.id("users")` array and stored it verbatim. Naming a user from another home would
   then let them through `messages:assertParticipant` and hand them the entire
   conversation — the cross‑home leak the migration off PocketBase existed to fix. Now
   every participant must exist and be a member of the conversation's home.
2. **`tasks:create` / `tasks:update` never validated `assigned_to`** — a task could be
   assigned to a deleted user or to someone outside the household.
3. **`homes:leave` could strand an entire home.** When the last member left, the home and
   all its tasks, notes, shopping items, recipes, conversations, messages, polls and movie
   lists stayed in the database with nobody able to satisfy `requireHomeMember` — data no
   code path could ever read, write or clean up again. The last member out now triggers
   `cascadeDeleteHome`, which also scrubs the home from every user's `home_id` mirror.
   It returns `{ deletedHome: true, removed: {...} }` so the client can tell the two cases
   apart.

**13 more relation fields are now required** (`homes.members`, `tasks.home_id/created_by`,
`shopping_items.home_id`, `notes.home_id/created_by`, `conversations.home_id/participants`,
`recipes.home_id/created_by`, `movies.home_id/list_id`, `movie_lists.home_id`). Schema
validation passing on deploy is the proof that every live row satisfies them.

Still optional **on purpose** — see the header comment in `schema.ts` for the full list.
The one that matters: **`users.home_id` must stay optional**, because a brand‑new signup
belongs to no home until they create or join one. Making it required would break
registration.

## Auth replaced: Sign in with Apple only (2026‑09‑03)

Email/password sign-in is **gone**. Not a preference — it was actively broken, and the
failure was structural rather than a tuning problem:

**What broke.** `@convex-dev/auth`'s Password provider hashes with Lucia's `Scrypt`
(N=16384, **r=16** — twice the standard cost factor) implemented in pure JavaScript, and it
calls that hash from **inside a mutation** (`createAccountFromCredentials.ts:66`). Convex
gives a mutation a hard **1-second** budget. On this self-hosted backend the hash did not
fit, so sign-up failed with `Function execution timed out (maximum duration: 1s)`. It was
marginal rather than hopeless, which is the worst case: one attempt squeaked through and
left a half-usable account, and the rest failed. The `InvalidAccountId` errors seen
alongside it were a *different* thing — the normal "migrated user has no password account
yet" path, thrown before that account existed.

**Why Apple rather than faster hashing.** Cheaper hashing was measured and would have
worked (native PBKDF2-HMAC-SHA256 at OWASP's 600k iterations uses under a third of the
mutation budget, where three fit and five time out). But it keeps the app in the business
of storing and verifying secrets. Apple verifies the user instead and we store only an
opaque identifier.

**How it works now.**
- The iOS app uses the **native** `ASAuthorizationAppleIDProvider`
  (`AppleSignInCoordinator.swift`) — no browser redirect, no OAuth callback. That is not
  just a nicety here: this deployment only proxies `/.well-known/*` to the HTTP-actions
  origin (see the tunnel section above), so the redirect-based OAuth routes would not be
  reachable at all.
- Apple returns a signed identity token; `convex/lib/apple.ts` verifies it against Apple's
  published JWKS, checking RS256, `iss=https://appleid.apple.com`, `aud=<bundle id>`
  (a **native** token's audience is the bundle id, not a Services ID) and expiry.
- `convex/auth.ts` keys accounts on Apple's **`sub`**, never on email. `sub` is the only
  claim present on every sign-in — Apple sends the email and the user's name **only on the
  very first authorization**. Linking by email is allowed only when Apple says the address
  is verified and is not a private-relay alias, since relay addresses are per-app and
  matching one to another profile would be meaningless.
- There is no sign-up flow. One button covers first and subsequent sign-ins; the backend
  creates the account on demand.

**Client-side:** `ConvexPasswordAuthProvider` → `ConvexAppleAuthProvider` (same
`auth:signIn` / `auth:signOut` action contract, `{provider:"apple", params:{identityToken,
name}}`). The email/password forms, the login/register toggle and the password validation
in `AuthenticationScreen` and `LoginScreen` are removed. `NestZone.entitlements` carries
`com.apple.developer.applesignin`, applied to the app target's Debug and Release configs
only — deliberately **not** the test targets, where it would break signing.

**Also fixed while in here:** `authRefreshTokens` had grown to **5,596 rows against 3
sessions**. That is what made the account cleanup time out. All were purged. Worth watching
whether it regrows — a client reconnect loop is the likely cause.

**`tr.json` had a trailing comma** (invalid JSON). `JSONSerialization` happens to tolerate
it, so Turkish was never actually broken, but every stricter parser rejects the file. Fixed.
