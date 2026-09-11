# NestZone

A shared-household iOS app: tasks, shopping, notes, messages, recipes, movie
lists, house problems, and a "what should we watch" swipe game. SwiftUI + The
Composable Architecture on the client, self-hosted Convex on the server.

## Layout

```
NestZone/                 the app target — one module, four layers
  App/                    AppFeature (root), MainFeature (tabs), AppView
  Core/
    Models/               domain types, typed ids, Timestamp, AppError
    Network/              ConvexConnection + one @DependencyClient per domain
    Localization/         L10n accessors for the String Catalog
  Design/                 Liquid Glass surfaces, theme, motion, components
  Features/               one folder per feature: <Name>Feature.swift + <Name>View.swift
  Resources/              Localizable.xcstrings, bundled sample recipes
backend/convex/           Convex functions (queries, mutations, actions)
```

Features never reach into each other. They meet in `MainFeature`, which is the
only place that knows the shape of the whole app.

## Conventions

- **Every read is a live subscription.** `ConvexConnection.subscribe` returns an
  `AsyncThrowingStream` that yields on every server-side change. Do not add a
  fetch-once-and-refresh path; Convex pushes. `ConvexConnection.first` exists for
  genuinely one-shot reads only.
- **Mutations go through `ConvexConnection.mutate`**, never
  `client.mutation(_:with:)` — the SDK's no-result overload decodes the response
  as a `String` and fails on anything that returns a document.
- **Writes are optimistic, and every one of them owns its rollback.** Mutate
  state, fire the effect, and let the live subscription confirm it. It cannot
  *correct* it: a write that failed changed nothing on the server, so there is
  no push coming. The failure handler has to put the old value back itself,
  which means the failure action carries whatever it needs to do that — the
  previous value, the removed element and its index, the text that was cleared.
  This rule used to read "no manual rollback", which held only by accident:
  Convex re-publishes every query in its set on every query-set change, so an
  unrelated screen swapping a subscription would eventually re-deliver the true
  value and quietly undo the wrong one. `ConvexConnection.subscribe` now drops
  duplicate payloads, so that accident is gone and the rollback has to be real.
- **Strings** live in `Resources/Localizable.xcstrings`, reached through `L10n`.
  Nothing user-visible is a literal. The catalog is **hand-maintained**: add a
  case to `L10n.swift` and the matching entry in Xcode's String Catalog editor.
  Automatic extraction is off (`SWIFT_EMIT_LOC_STRINGS = NO`) on purpose —
  `L10n.r(_:_:)` hides the key behind a parameter, so the extractor cannot see it
  and re-adds every English default as its own key on each build. Turning it back
  on re-pollutes the catalog with hundreds of duplicates.
- **Colours** are `static let` constants in `Palette`. Never build a `Color` or
  gradient inside a `body`.
- **Glass goes on things that float** — cards, controls, bars. Never on a
  full-screen background. Sibling glass belongs in a `GlassGroup`.
- **Shared settings** are `@Shared` app-storage keys in `Design/AppSettings.swift`.
  Keys are camelCase with no dots (a `.` defeats key-value observation). Mutate
  through `withLock`.
- Errors surface as `AppError`, which maps to copy a person can act on. Raw
  server strings never reach the UI — but `ConvexConnection.mapped` keeps the
  server's message on the error and logs it, so failures stay diagnosable.
- **Enums decode leniently** (`decodeLenient`). A list is decoded as one array,
  so an unrecognised value must degrade its own field rather than throw and blank
  the screen.
- **Convex Auth rotates the refresh token on every exchange.** A successful
  restore consumes the stored token and returns a replacement, so two concurrent
  restores destroy the session — `ConvexAppleAuthProvider` serialises them behind
  a semaphore. Clear the stored token **only** when the server explicitly rejects
  it; a network failure must leave it in place and retry, or a two-second blip
  signs the user out permanently.
- **Sign-out unregisters the push token first**, while there is still an identity
  to authorise the mutation with.
- **Mutation arguments are camelCase (`homeId`); document fields are snake_case
  (`home_id`).** Check the handler in `backend/convex/` before adding a call —
  Convex validates strictly and rejects the whole request on a name mismatch.

## Commands

```bash
# build + run
xcodebuild -scheme NestZone -destination 'platform=iOS Simulator,name=iPhone 17' build

# tests (reducer tests via TestStore, plus a UI walk of every tab)
xcodebuild test -scheme NestZone -destination 'platform=iOS Simulator,name=iPhone 17'

# backend
cd backend && npx tsc --noEmit -p tsconfig.json   # typecheck
cd backend && npx convex deploy                   # deploy
cd backend && npx convex env set TMDB_API_KEY <k> # secrets live here, never in the app

# APNs. The auth key is team-wide, not per-app: one .p8 signs for every app
# under the same Team ID, and the bundle id travels per-request in `apns-topic`.
#   npx convex env set APNS_KEY_ID    <10-char id, from the .p8 filename>
#   npx convex env set APNS_TEAM_ID   <10-char Apple Developer team id>
#   npx convex env set APNS_BUNDLE_ID com.walhallaa.NestZone
#   npx convex env set -- APNS_KEY_P8 "$(cat AuthKey_XXXXXXXXXX.p8)"
# Push is a quiet no-op until all four are set. To check a key without sending
# a real push, sign a JWT and POST to a fake device: `BadDeviceToken` means the
# credentials are good, `InvalidProviderToken` means they are not.
```

## Backend notes

- `stats:forHome` computes the Home tab's counters server-side. The client must
  not go back to downloading whole collections to count them.
- **A finished chore is a document, not a flag.** Ticking a box writes a
  `task_completions` row; unticking it is the only thing that deletes one.
  `stats:contributions` and `tasks:archive` read that table and nothing else,
  which is what makes the split unrewritable by accident — it used to be tallied
  by collecting the whole `tasks` table, so deleting a finished chore quietly
  took somebody's credit with it, and the read grew with the household's age.
- **Erasing a completion is a different function from deleting a task.**
  `tasks:remove` takes open chores only and needs no confirming — nothing was
  ever done. `tasks:removeFinished` takes the completion with the task, and the
  client never calls it except behind a dialog that names the chore, names whose
  credit goes, and says the split will change. The point was never to make the
  record unreachable; it was to stop reaching it being silent. The gentler route
  is still there — reopen the chore, which retracts the credit visibly, then
  delete it as an open task.
- **Done and Archive are two halves of one boundary, not two lists.**
  `DONE_WINDOW_DAYS` splits `completed_at`: above it is `tasks:listByHome`'s
  finished half, below it is `tasks:archive`. Disjoint by construction — no
  flag, no sweep, and no way for a chore to show up in both. There is no
  archiving *verb*; a chore is in the Archive because it got old. An earlier
  version had a manual `archived_at` **and** a History screen returning every
  completion ever, so a chore finished yesterday sat in Done and in History at
  once. That is not an archive, it is a second copy of the same list.
  Both queries send the window back with the rows so each screen can state the
  rule it obeyed rather than hardcoding a number that can drift from it.
  `completed_at` is denormalised onto the task because it is the last field of
  `by_home_completed`; reopening clears it with `completed_by`.
- New deployments must run `npx convex run tasks:backfillCompletions '{}'` once.
  It is idempotent and self-scheduling, and until it has run, chores finished
  before the ledger shipped are missing from both the contribution tally and the
  Done list's date range.
- `catalog:discover` / `catalog:details` proxy TMDb so the API key stays on the
  server. Nothing in the app may call api.themoviedb.org directly.
- `finance:summary` computes the whole Finance screen server-side — balances,
  the settle-up plan, the category split, six months of history, budget
  progress. Balances are all-time and the spend figures are month-scoped; that
  asymmetry is deliberate. Money is stored in **minor units** as integers and
  the *server* owns every split (`resolveSplits`), so no client version can
  write a ledger whose shares do not add up to its total. `SplitMath` on the
  client is the same arithmetic, for the composer's preview only.
- **Money is per-document, not per-home.** Every expense, bill and budget
  carries its own `currency`, and `finance:summary` is scoped to one of them —
  adding 500 lira to 20 dollars is not a number, and no rate is ever invented on
  a household's behalf. The client filters the ledger to match. Sums are scoped;
  counts (overdue bills, say) are not, and are derived client-side so a badge
  can never contradict the list under it.
- **House problems are not a second task list.** A chore is finished when
  somebody does it; a problem is a thing that is *wrong*, it outlives attempts
  to fix it, it costs money, it needs parts, and the same one comes back. So
  `issues` keeps its own state machine and links *out* rather than copying:
  `tasks.issue_id`, `issues.event_id`, `shopping_items.issue_id`,
  `expenses.issue_id`. Deleting a problem detaches all of them and deletes only
  its own timeline — the washer is still needed and the plumber's invoice is
  still money that moved.
- `issues:byHome` returns the rows **and** the aggregates in one payload, so a
  badge reading "2 urgent" can never sit over three urgent rows. It is bounded
  by `is_open` — a denormalised boolean, because an index cannot range over
  "any of five statuses" and fixed problems only accumulate. `issues:setStatus`
  is the only thing that writes `status`, so the two cannot drift.
- Photos go up through `issues:uploadUrl`: the phone POSTs the bytes straight to
  a signed URL and only the storage id reaches a mutation. `issues:detail`
  returns `photo_refs` — ids *and* URLs — because the screen has to draw a photo
  and delete it, and a signed URL is not an identity.
- `convex/crons.ts` runs `finance:sweepReminders` daily at 08:00 UTC. It is
  idempotent by design — every nudge is recorded against
  `<due_date>:<daysBefore>` before it is sent, because a duplicate reminder is
  worse than a missed one. Paying a bill moves `due_date`, which retires the
  keys for the cycle just closed. `issues:sweepStale` runs at 09:00 on the same
  terms, keyed by `<due_by>:overdue` and `<last_activity_at>:stale` — any
  activity at all retires the stale key, so a quiet stretch nudges exactly once.
- `convex/lib/auth.ts` has the permission helpers. Prefer `requireDocHome` over
  a conditional `home_id` check — every `home_id` is optional in the schema, so
  the conditional form silently skips both the membership check and auth.

## graphify

This project has a knowledge graph at `graphify-out/`.

- For codebase questions, run `graphify query "<question>"` first when
  `graphify-out/graph.json` exists. Use `graphify path "<A>" "<B>"` for
  relationships and `graphify explain "<concept>"` for focused concepts.
- If `graphify-out/wiki/index.md` exists, use it for broad navigation.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review.
- After modifying code, run `graphify update .` to keep the graph current.
