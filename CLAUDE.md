# NestZone

A shared-household iOS app: tasks, shopping, notes, messages, recipes, movie
lists, and a "what should we watch" swipe game. SwiftUI + The Composable
Architecture on the client, self-hosted Convex on the server.

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
- **Writes are optimistic.** Mutate state, fire the effect, and let the live
  subscription confirm or correct it. No manual rollback.
- **Strings** live in `Resources/Localizable.xcstrings`, reached through `L10n`.
  Nothing user-visible is a literal.
- **Colours** are `static let` constants in `Palette`. Never build a `Color` or
  gradient inside a `body`.
- **Glass goes on things that float** — cards, controls, bars. Never on a
  full-screen background. Sibling glass belongs in a `GlassGroup`.
- **Shared settings** are `@Shared` app-storage keys in `Design/AppSettings.swift`.
  Keys are camelCase with no dots (a `.` defeats key-value observation). Mutate
  through `withLock`.
- Errors surface as `AppError`, which maps to copy a person can act on. Raw
  server strings never reach the UI.

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
```

## Backend notes

- `stats:forHome` computes the Home tab's counters server-side. The client must
  not go back to downloading whole collections to count them.
- `catalog:discover` / `catalog:details` proxy TMDb so the API key stays on the
  server. Nothing in the app may call api.themoviedb.org directly.
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
