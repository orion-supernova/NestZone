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
    Inbox/                the bell: household activity + the app's changelog
  Resources/              Localizable.xcstrings, bundled sample recipes
backend/convex/           Convex functions (queries, mutations, actions)
backend/changelog.json    the app's release notes — see "Shipping a change"
backend/DEPRECATIONS.md   what may be removed from the backend, and when
deploy.sh                 the whole release: backend, changelog, archive, upload
```

Features never reach into each other. They meet in `MainFeature`, which is the
only place that knows the shape of the whole app.

## Shipping a change

```bash
./deploy.sh              # backend, changelog, archive, upload — the lot
./deploy.sh --backend    # backend + changelog only
./deploy.sh --bump patch # 1.9.0 -> 1.9.1 first
./deploy.sh --dry-run    # say what would happen, touch nothing
```

**Backend first, then the app** — which is the order the script uses and the
reason it is one script. A new app build needs backend functions that only a
new backend has; an old app build must keep working against that same backend.
Deploy the backend first and both hold at every moment in between. Ship the app
first and there is a window — minutes if it goes well, a week if the upload
fails — where the newest build calls functions that do not exist.

The script refuses to ship a version with no changelog entry, bumps the build
number before archiving (Apple rejects a repeat, and it tells you *after* the
upload), and skips the upload cleanly when `ASC_KEY_ID` / `ASC_ISSUER_ID` are
unset.

## One deployment, every app version

**A backend change must not break any app version still in use.** Add, never
remove. Widen, never narrow. Default, never require.

There is one deployment and it serves every build that exists — including the
one from March on the phone of somebody with automatic updates off, and the one
still in review. None of them can be asked to update first. Convex makes the
failure mode sharp: argument validation is **strict**, so an unexpected or
missing argument rejects the whole request, and the screen that called it stops
working on a build you cannot patch.

A rename or a signature change therefore takes three deploys, never one: add
the new thing beside the old, ship an app build that uses it, wait until nobody
needs the old one, then remove it.

**`backend/DEPRECATIONS.md` is where that waiting is recorded** — what is
deprecated, what replaced it, the condition for removing it, and the steps. A
row without a removal condition is a wish, not a deprecation. Write the row in
the same commit that deprecates the thing.

Whether it is safe yet is a question with an answer:

```bash
cd backend && npx convex run inbox:versionCensus '{}'
```

Every device reports its version when it registers for notifications — which
already happens once per launch, so it costs nothing extra. Two things to hold
in mind: **`unknown` is the important row** (a build too old to report at all),
and every number is a **floor**, because a device that declined notifications
never registers.


**A change a household would actually notice gets a changelog entry, in the
same commit as the change.** The entry goes at the top of
`backend/changelog.json`, and it reaches people through the bell on the Home
tab — the Updates half of it. A feature nobody is told about is a feature
nobody finds.

**Most commits do not earn one.** This is a changelog, not a commit log: it is
read by the people living in the house, and its only job is to tell them
something they can act on. The bar is *would somebody notice this without being
told, and be glad they were?*

- **Worth an entry:** a new screen or capability; a change to how something
  already works that people have to relearn; something that was broken and is
  now fixed, where people knew it was broken; anything that changes what the
  app costs, asks for or keeps.
- **Not worth an entry:** refactors, renames, comments, tests, dependency
  bumps, schema or index work, a padding tweak, a colour, a log line, a
  performance win nobody could feel, a bug fixed before anybody hit it. None of
  these are secrets — they are simply not news, and a changelog padded with
  them is one people stop opening, which costs the entries that mattered.
- **One entry per release, not per commit,** unless a release genuinely did two
  unrelated things. Six bullet points under one headline beat six headlines;
  that is what `highlights` is for.
- Write it for the household, not for the repository: "Notifications and
  updates, in one place", never "Add inbox module". If the entry cannot be
  written without naming a file, it probably should not exist.

```bash
cd backend && npx convex run inbox:syncChangelog "$(cat changelog.json)"
```

Idempotent by `slug`, so this runs on every deploy. Re-syncing does not
re-announce: an entry that already has a `published_at` keeps it, which is what
makes fixing a typo in an old note free.

- **`version` is a gate, not a label.** Put the app version the change ships
  in. Deploying the backend is not the same event as a build reaching a phone
  and never will be — the notes go live the moment the work lands, while the
  households reading them are on the last version, or two back, or waiting on
  review. A client compares its own `CFBundleShortVersionString` against the
  entry (`AppVersion` in `Core/Models/AppVersion.swift`, compared numerically —
  "1.10.0" is above "1.9.0" and a string comparison says the opposite) and
  draws anything above its own as **Coming soon** rather than promising a
  button that is not in this build. Omit it only for an announcement that is
  true on every version.
- **Bump `MARKETING_VERSION` when you write an entry for a new version.** The
  entry and the build have to agree or your own device shows your own work as
  "coming soon".
- **Never change a `slug` after it has shipped.** The slug is the upsert key;
  changing one files a second copy of the same note.
- `draft: true` keeps an entry out of the feed entirely — for a note written
  ahead of the release it describes.
- The in-app admin panel (the bell → ⋯ → Manage updates, for the accounts in
  `backend/convex/lib/admin.ts`) writes the same table and is for one-offs and
  emergencies. The file is what the repository can be read back from, so
  anything meant to last belongs in it.

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
- **Avatars are looked up, not passed.** `Avatar(initials:seed:size:)` resolves
  the photo itself from `AvatarDirectory`, keyed on the `seed` — which is
  already the user's id at every call site, because the tint has to match their
  slice of the contributions ring. So a screen holding a member *row* rather
  than a `User` draws photographs without being edited. The directory is a
  mirror of the server, filled inside the clients for the three reads a `User`
  arrives through (`users:me`, `homes:members`, `users:byIds`), so there is no
  path by which one arrives and the directory misses it. It holds no optimistic
  state and is cleared on sign-out. Faces load through `RemoteImage` with
  `persistence: .disk`, and `AvatarPhoto.renderSize` rounds the app's eight
  drawn sizes onto two so a member is one decoded bitmap, not eight.
  Tapping one opens it full screen, everywhere, off the same lookup — the
  directory carries the name so the photo has a title. That is `viewable`, and
  it defaults **on**: turn it off (and only off) where the avatar sits inside a
  control whose tap means something else — a member-selection row, a settle-up
  suggestion, a `Menu` label, `AvatarStack`. It works by `allowsHitTesting`, so
  a non-viewable avatar is transparent to touches rather than merely inert; an
  inert tap gesture would still swallow the row's tap.
  Uploads are capped by a **byte budget**, not a quality setting — quality is a
  knob on an encoder, not a size, and the same 0.85 that gives 90 KB for a plain
  background gives half a megabyte for a face in front of foliage. `compress`
  walks quality down and then resolution down until it fits `byteBudget`, trying
  HEIC *and* JPEG at each step and keeping the smaller: HEIC is about half the
  bytes on a photograph but hits a floor on detail it cannot model, where JPEG
  walks past it. The content type travels with the bytes (`PhotoUpload`) because
  Convex serves back whatever it was told. Real numbers: 137–212 KB before,
  23–73 KB after, at the same 1024px.
- **Every upload goes through `PhotoCompressor` and a `PhotoCompressionPlan`.**
  One ladder, two plans. `AvatarPhoto.plan` allows HEIC because a face is drawn
  by this app and nothing else ever sees it; `IssuePhoto.plan` does not, because
  a picture of a leak is the kind of thing somebody forwards to a plumber, and a
  storage URL opened in a browser that cannot decode HEIC is a broken image at
  the worst moment. Adding a third upload means adding a plan, not a ladder.
- **A house-problem photo is stored twice, and the pair is the point.**
  `issues.photos` holds the full picture and `issues.photo_thumbs` a 320-pixel
  copy — parallel arrays, written only by `attachPhotos` and `removePhoto` so
  they cannot drift, and `byHome` serves `photo_thumbs[0] ?? photos[0]`. The
  board used to draw its 44-point square by downloading the 2000-pixel original,
  once per device per problem: three photographed problems cost 532 KB to fill
  three postage stamps, and now cost 51 KB. `photo_thumbs` is optional and falls
  back, so problems photographed before it existed still draw.
- **`NSCameraUsageDescription` is required and localized; the photo-library one
  is deliberately absent.** Presenting a camera without the key is an instant
  crash, not a denial. The copy lives in `Resources/InfoPlist.xcstrings` (a
  second catalog — the Swift one cannot reach Info.plist), with the value in
  `Info.plist` as the base for an unlisted language. A system permission prompt
  follows the *device* language, not the in-app picker, so it has to be
  localized there or a Turkish phone gets English. No
  `NSPhotoLibraryUsageDescription`: every library read goes through
  `PhotosPicker`, which runs out of process, asks for nothing, and hands back
  only what was picked — declaring the key would claim access never requested.
- **Faces and problem photos load with `persistence: .disk`.** `.session` leaves
  survival across a relaunch to the `Cache-Control` header on a signed storage
  URL. Anything drawn on every screen, or on every row of one, gets `.disk`; a
  browsing surface with thousands of images (posters) stays on `.session`, which
  is what `URLCache` and its byte budget are for.
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

# How long a finished chore stays on the Done list before it falls into the
# Archive. Unset means 30. NOT a way to look at the Archive — there is one
# deployment and it moves the boundary for every real household on it. Archive
# a chore by hand instead; that is what the swipe is for.
cd backend && npx convex env set DONE_WINDOW_DAYS 14

# Release notes. Idempotent by slug — run it on every deploy.
cd backend && npx convex run inbox:syncChangelog "$(cat changelog.json)"

# Who may write the changelog from inside the app. The built-in admin is
# hardcoded in convex/lib/admin.ts; these add to it and never remove it.
#   npx convex env set ADMIN_EMAILS   "someone@example.com"
#   npx convex env set ADMIN_USER_IDS "jh7abc..."
# Prefer the id when Sign in with Apple is involved: Apple sends an email only
# on the FIRST authorization and sends a private-relay alias when "Hide My
# Email" was used, so the address on a users row is not reliably the one its
# owner would tell you. `npx convex run inbox:whoAmI '{}'` prints the id, and
# the Admin panel shows it too.

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
  `doneWindowDays()` splits `completed_at`: above it is `tasks:listByHome`'s
  finished half, below it is `tasks:archive`. Disjoint by construction — no
  flag to sweep, and no way for a chore to show up in both. A chore reaches the
  Archive by falling below the window or by being put there (`archived_at`, set
  by `tasks:setArchived`) — one shelf, two routes, and Done excludes both. The
  version to *not* go back to is the one where a History screen returned every
  completion ever, so a chore finished yesterday sat in Done and in History at
  once: that is not an archive, it is a second copy of the same list.
- **"Old or put away" is two index ranges, not a filter.** `tasks:archive`
  reads both off `by_home_completed` and merges them in JS, exactly as
  `openTasks` has always answered "false or absent" (lib/pending.ts). Reach for
  that pattern before concluding an index cannot express something — a filter
  over every chore the household ever finished is the scan this module exists
  to avoid.
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
- **The notification feed is written by `push`, not by its callers.**
  `push.notifyHome` and `push.notifyUsers` call `inbox.record` on the way past,
  so all thirty-odd places that already tell a household something land in the
  in-app panel without knowing it exists — and a module that starts notifying
  tomorrow cannot ship having remembered the push and forgotten the record. It
  runs *before* the APNs configuration check, because the feed is the durable
  half: a push may never arrive, and the panel has to be there either way.
  `notifyUsers` takes a `homeId` so an addressed notification can be filed with
  an `audience`, which is what keeps a private conversation out of everybody
  else's feed.
- **`inbox:badge` is the one query that is open all the time, so it is
  floored.** It never counts further back than a fortnight whatever the read
  watermark says, which is what stops the cost of the bell growing with the
  household's age. It returns both counts, both watermarks, both floors and the
  admin flag in one payload — a count and the list under it have to come from
  one read, the same rule `issues:byHome` follows. The floors travel with the
  counts so the "new" marks on the rows cannot disagree with the number on the
  bell.
- **The feed's newest page is live; its history is not.** An activity row is
  immutable — it records something that already happened — so there is no later
  state a subscription could deliver, and paging back through a household's
  year costs one query per page instead of one live query per page held open.
  This is the one place in the app where `ConvexConnection.first` is the right
  answer for a list.
- **Read state is a watermark, not a flag per row.** A household of four
  reading a hundred notifications a week would otherwise write four hundred rows
  a week to record that nothing happened.
- `home_activity.created` is **unique within a home** — `inbox.record` nudges a
  collision forward a millisecond. The feed pages on a strict `<` cursor, which
  is the cheapest correct cursor there is and is correct only while no two rows
  share a value.
- `convex/crons.ts` runs `inbox:sweep` daily at 03:00 UTC, which drops household
  activity older than 90 days in self-rescheduling batches. The feed is the one
  table here that is *meant* to be forgotten; kept forever it is not a storage
  bill but a slow bell.
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
