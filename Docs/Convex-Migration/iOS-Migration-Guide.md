# NestZone iOS — PocketBase → Convex migration guide

This guide explains how to move the **iOS app** off PocketBase REST + SSE and onto
the (already‑deployed) **self‑hosted Convex** backend. No app code has been changed yet —
this is the playbook for doing it.

> Backend status: the Convex schema, auth, and your data (924 records) live on
> `https://nestzone-convex-api.walhallaa.com`. See `Backend-Deploy-Runbook.md` for what
> was deployed and the exact function names this guide references.

---

## 1. The mental-model shift (read this first)

| PocketBase (today) | Convex (target) |
|---|---|
| REST: `GET/POST/PATCH /api/collections/...` | Typed **functions**: `query` (read) / `mutation` (write) |
| You poll, or open an **SSE** stream and diff events | **Subscriptions**: a `query` you subscribe to re‑pushes automatically on any change |
| Records have 15‑char string `id` | Docs have a Convex `_id` (opaque string) + `_creationTime` |
| Relations are id strings you resolve manually | Relations are `_id`s; backend resolves them in the query |
| Auth: token in `Authorization` header | Convex Auth: JWT set on the client; backend reads the identity |
| Filters as query strings (`filter=...&sort=...`) | Filtering happens **inside** the Convex function |

**The biggest win:** `PocketBaseRealtimeManager.swift` (23 KB of SSE/event plumbing)
essentially **disappears**. Any screen that needs live data just subscribes to a query.

---

## 2. Add the Convex Swift SDK

In Xcode → *File ▸ Add Package Dependencies…* add:

- `https://github.com/get-convex/convex-swift` → product **`ConvexMobile`**

(Confirm the latest version in the repo's README at integration time.)

Create one shared client. Suggested location: `NestZone/Network/Convex/ConvexClientProvider.swift`.

```swift
import ConvexMobile

enum Convex {
    /// Deployment (cloud) origin of the self-hosted backend.
    static let deploymentURL = "https://nestzone-convex-api.walhallaa.com"

    /// Single shared client for the whole app.
    static let client = ConvexClientWithAuth(
        deploymentUrl: deploymentURL,
        authProvider: ConvexAuthProvider()   // see §3
    )
}
```

If you don't want auth wired on day one, start with plain `ConvexClient(deploymentUrl:)`
and add auth later — queries that call `requireUser` will simply error until a user is signed in.

---

## 3. Auth: replace `PocketBaseAuthManager`

The backend uses **Convex Auth** with the **Password** provider. Crucially, it
**auto‑links your 7 migrated users by email**: when one of them signs up again with
their existing email, the new password account binds to their migrated profile, so
they keep their home, messages and votes. (PocketBase bcrypt hashes cannot be reused —
this is the supported path.)

### Behaviour mapping

| `PocketBaseAuthManager` | Convex equivalent |
|---|---|
| `login(email:password:)` → `/auth-with-password` | `signIn(provider:"password", flow:"signIn")` |
| `register(email:password:fullName:)` → create user + login | `signIn(provider:"password", flow:"signUp")` (auto‑links if email exists) |
| `refreshAuth()` | Handled by the SDK's stored refresh token |
| `logout()` | `signOut()` |
| `currentUser` (`AuthUser`) | `users:me` query (reactive) |
| token in `UserDefaults` | SDK stores tokens in the Keychain |

### Sketch of a `ConvexAuthManager`

```swift
import ConvexMobile
import Combine

@MainActor
final class ConvexAuthManager: ObservableObject {
    @Published var currentUser: NZUser?          // from users:me
    @Published var isAuthenticated = false

    private let client = Convex.client
    private var bag = Set<AnyCancellable>()

    func bootstrap() {
        // Reactively track auth state + the signed-in profile.
        client.subscribe(to: "users:me", yielding: NZUser?.self)
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = (user != nil)
            }
            .store(in: &bag)
    }

    func signIn(email: String, password: String) async throws {
        try await client.signIn(
            provider: "password",
            params: ["email": email, "password": password, "flow": "signIn"]
        )
    }

    func signUp(email: String, password: String, name: String) async throws {
        try await client.signIn(
            provider: "password",
            params: ["email": email, "password": password, "name": name, "flow": "signUp"]
        )
    }

    func signOut() async { await client.signOut() }
}
```

> The exact `signIn`/auth-provider API names come from `convex-swift` + `@convex-dev/auth`.
> Verify against the SDK README — the **flow** (`signIn` vs `signUp`) and the
> `email`/`password`/`name`/`flow` params are what the Password provider expects.

**Migrated-user UX:** tell your 7 users to "sign up" with the **same email** they used in
PocketBase and choose a new password. They'll land on their existing home automatically.
(Optionally add a "first time back? create a new password" note on the sign‑in screen.)

---

## 4. Replace `PocketBaseManager` with typed calls

Delete the generic REST wrapper. There's no central "manager" in Convex — each screen/VM
calls a named function. Two primitives:

```swift
// READ (live): pushes a new value whenever underlying data changes
Convex.client
    .subscribe(to: "tasks:listByHome", with: ["homeId": homeId], yielding: [NZTask].self)
    .replaceError(with: [])
    .receive(on: DispatchQueue.main)
    .assign(to: &$tasks)

// WRITE: returns when committed
let id: String = try await Convex.client.mutation(
    "tasks:create",
    with: ["homeId": homeId, "title": title, "priority": "high"]
)
```

- `"file:function"` is the path: file `convex/tasks.ts`, export `create` → `"tasks:create"`.
- Args are a `[String: ConvexEncodable]` dictionary; keys match the function's `args`.
- Convex ids are plain `String` on the Swift side — pass them straight back as args.

---

## 5. Models / DTOs (`PocketBaseModels.swift`)

Keep using `Codable` structs, with three adjustments:

1. **IDs:** decode `_id` (not `id`) and `_creationTime` (a `Double`, ms since epoch).
2. **Migrated timestamps:** `created` / `updated` are **numbers** (ms), not ISO strings.
3. **Selects** decode as plain `String`; **geoPoint** as `{ lat, lng }`.

```swift
struct NZUser: Codable, Identifiable {
    let _id: String
    var id: String { _id }
    let name: String?
    let email: String?
    let home_id: [String]?     // array of home _ids
    let created: Double?
    let updated: Double?
}

struct NZHome: Codable, Identifiable {
    let _id: String
    var id: String { _id }
    let name: String?
    let address: GeoPoint?
    let members: [String]?     // array of user _ids
    let invite_code: String?
}
struct GeoPoint: Codable { let lat: Double; let lng: Double }
```

Field names in the deployed functions deliberately **kept the PocketBase names**
(`home_id`, `sender_id`, `read_by`, `is_purchased`, …) to minimise churn in your models.

---

## 6. Realtime: delete `PocketBaseRealtimeManager`

Everything that file did is now "subscribe to a query":

| Old SSE concern | New |
|---|---|
| Subscribe to `messages` collection, diff events | `subscribe("messages:listByConversation", ...)` |
| Re‑fetch conversation list on change | `subscribe("conversations:listByHome", ...)` |
| Poll for poll/vote updates | `subscribe("polls:detail", ...)` — items + votes + my votes in one push |
| Manual reconnect / backoff | SDK handles the socket |

A VM keeps an `AnyCancellable` per subscription and assigns into a `@Published` array.
When the screen closes, cancel the subscription.

---

## 7. File‑by‑file plan

| iOS file | Action |
|---|---|
| `Network/PocketBaseManager.swift` | **Remove.** Replace with `Convex/ConvexClientProvider.swift`. |
| `Network/PocketBaseAuthManager.swift` | **Replace** with `ConvexAuthManager` (§3). |
| `Network/PocketBaseAuthDTOs.swift` | **Remove** (Convex Auth handles tokens). |
| `Network/PocketBaseRealtimeManager.swift` | **Remove** (§6). |
| `Network/PocketBaseModels.swift` | **Adapt** → `ConvexModels.swift` (`_id`/`_creationTime`, numeric dates). |
| `Network/MessagesManager.swift` | Rewrite calls → `messages:*` / `conversations:*`. |
| `Network/UserService.swift` | Rewrite → `users:me`, `users:updateProfile`, `users:byIds`. |
| `Managers/HomeSelectionManager.swift` | Source homes from `homes:listMine`. |
| `Modules/Auth/*` | Point view models at `ConvexAuthManager`. |
| `Modules/HomeManagement/*` | `homes:create` / `homes:join` / `homes:members`. |
| Polls / Movies / Recipes / Shopping / Notes / Tasks modules | Map to the function tables in §8. |

---

## 8. Backend function reference (what to call)

All reads are **subscribable** (live). All writes are `mutation`s. Auth is required
unless noted; home‑scoped calls check membership server‑side.

### users (`users.ts`)
- `users:me` → current profile or `null`
- `users:updateProfile` `{ name?, avatar? }`
- `users:byIds` `{ ids: [userId] }`

### homes (`homes.ts`)
- `homes:listMine` · `homes:get {homeId}` · `homes:members {homeId}`
- `homes:create {name, address?}` · `homes:join {inviteCode}` · `homes:leave {homeId}`

### tasks (`tasks.ts`)
- `tasks:listByHome {homeId}`
- `tasks:create {homeId, title, description?, assigned_to?, priority?, type?, due_date?}`
- `tasks:update {id, ...}` · `tasks:remove {id}`

### shopping (`shopping.ts`)
- `shopping:listByHome {homeId}` · `shopping:create {homeId, name, quantity?, category?}`
- `shopping:setPurchased {id, is_purchased}` · `shopping:remove {id}`

### notes (`notes.ts`)
- `notes:listByHome {homeId}` · `notes:create {homeId, description, color?, image?}`
- `notes:update {id, ...}` · `notes:remove {id}`

### chat (`conversations.ts`, `messages.ts`)
- `conversations:listByHome {homeId}` · `conversations:create {homeId, participants, title?, is_group_chat?}`
- `messages:listByConversation {conversationId, limit?}` ← **subscribe for live chat**
- `messages:send {conversationId, content, message_type?, file?}`
- `messages:markRead {conversationId}`

### polls (`polls.ts`)
- `polls:listByHome {homeId}`
- `polls:detail {pollId}` → `{ poll, items, votes, myVotes }` (subscribe)
- `polls:create {homeId, title, type, genre?, items?}`
- `polls:vote {pollId, target_external_id, vote}` · `polls:setStatus {pollId, status}`

### movies (`movies.ts`)
- `movies:listsByHome {homeId}` · `movies:moviesInList {listId}`
- `movies:createList {homeId, name, type?}` · `movies:addMovie {homeId, listId, title, imdb_id?, year?, poster?, genres?}`
- `movies:removeMovie {id}`

### recipes (`recipes.ts`)
- `recipes:listByHome {homeId}` · `recipes:get {id}`
- `recipes:create {homeId, title, ingredients?, steps?, ...}` · `recipes:remove {id}`

---

## 9. File uploads (avatars / note & message images)

PocketBase file fields are migrated as `_storage` ids (currently empty — no files in the
data). When you add uploads:

1. `let url = try await client.mutation("files:generateUploadUrl")` *(add this helper)*.
2. `PUT` the bytes to `url` → returns a `storageId`.
3. Pass `storageId` into the relevant mutation (`notes:create { image: storageId }`).
4. To display: add a small `files:getUrl {storageId}` query returning a signed URL.

(These two helpers aren't deployed yet — add them when you implement uploads.)

---

## 10. Suggested cutover order

1. **Auth** — get sign‑in/up working; confirm a migrated user lands on their home.
2. **Homes** — `listMine` / `create` / `join`.
3. **One simple list** — tasks or shopping (proves the read/write loop).
4. **Chat** — proves live subscriptions end‑to‑end.
5. **Polls / Movies / Recipes / Notes** — repeat the pattern.
6. Delete the `PocketBase*` files once nothing imports them.

**Rollback:** PocketBase is untouched and still live at
`https://nestzone-pocketbase-dashboard.walhallaa.com`. Until you ship the Convex build,
the current app keeps working. Keep both backends up through one TestFlight cycle.

---

## 10b. Troubleshooting: `InvalidAccountId` on sign‑in

```
Uncaught Error: InvalidAccountId
  at retrieveAccount (@convex-dev/auth/.../implementation/index.ts)
  at authorize (@convex-dev/auth/.../providers/Password.ts)
```

**Cause:** `signIn` (flow `"signIn"`) was called for an email that has **no password
account**. This is expected for every migrated user on their first login — they have a
profile but no credential (PocketBase bcrypt hashes were not imported).

**Fix:** call the **sign‑up** flow the first time:
`signIn(provider:"password", params:[... ,"flow":"signUp"])`. That creates the password
credential and auto‑links it to the migrated `users` doc by email (see §3). Afterwards,
`flow:"signIn"` works normally.

**UX implication:** route the 7 migrated users (and any new user) through *Register*, not
*Login*, the first time. A good pattern: on `InvalidAccountId`, prompt "No account yet —
create a password" and retry with `flow:"signUp"`.

## 11. Gotchas checklist

- [ ] Decode `_id` / `_creationTime`, not `id`. Pass ids back as plain `String`.
- [ ] `created`/`updated`/`*_at` are **ms numbers** — convert with `Date(timeIntervalSince1970: ms/1000)`.
- [ ] Home‑scoped functions throw if you're not a member — handle the error.
- [ ] Subscriptions must be retained (`AnyCancellable`) and cancelled on teardown.
- [ ] `Info.plist`: allow the deployment domain (it's HTTPS, so ATS is fine).
- [ ] The 7 migrated users must **sign up again** with the same email (one‑time).
- [ ] Remove the `nestzone.walhallaa.com` base URL — that host never existed; PocketBase
      was only ever reachable at `nestzone-pocketbase-dashboard.walhallaa.com`.
