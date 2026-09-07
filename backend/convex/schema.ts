// Nestzone — Convex schema migrated from PocketBase.
//
// Notes:
// - Relation fields were all v.optional(...) during the import, because the
//   two-pass importer inserted docs without relations first (the data has cycles:
//   users <-> homes, conversations <-> messages) and patched them afterwards.
//   That importer is retired, so as of 2026-09-03 every relation that the data
//   actually populates is REQUIRED. The ones still optional are deliberate:
//     users.home_id      — a brand-new signup belongs to no home yet
//     tasks.updated_by   — never-edited task
//     tasks.assigned_to  — unassigned task
//     shopping_items.created_by / updated_by — 3 migrated rows have no creator
//                          and the value cannot be reconstructed
//     messages.read_by   — nobody has read it yet
//     *.image / *.file / users.avatar — optional _storage attachments
// - `v.id()` is only a TYPE: Convex does not verify the target exists and has no
//   ON DELETE CASCADE. Integrity is enforced in code — see convex/lib/relations.ts.
// - `pbId` keeps the original PocketBase id so the importer can remap relations
//   and so you can cross-check after migration. You can drop it once you're happy.
// - Timestamps `created` / `updated` are epoch-ms numbers carried over from PB.
//   Convex also stamps its own `_creationTime` on every doc.
// - Relations point to proper Convex ids: v.id("table").
//
// Auth: uses @convex-dev/auth. The `users` table below overrides the default
// one from authTables and adds our profile fields. See README for the
// password-reset / account-linking caveat (PB bcrypt hashes are NOT migrated).

import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { authTables } from "@convex-dev/auth/server";

// The categories a household's money goes into. One list, shared by expenses,
// bills and budgets — a budget that could name a category no expense can carry
// would silently never fill.
const financeCategory = v.union(
  v.literal("groceries"),
  v.literal("utilities"),
  v.literal("rent"),
  v.literal("household"),
  v.literal("dining"),
  v.literal("transport"),
  v.literal("health"),
  v.literal("entertainment"),
  v.literal("subscriptions"),
  v.literal("other"),
);

export default defineSchema({
  ...authTables,

  users: defineTable({
    // --- Convex Auth managed fields ---
    name: v.optional(v.string()),
    email: v.optional(v.string()),
    emailVerificationTime: v.optional(v.number()),
    phone: v.optional(v.string()),
    phoneVerificationTime: v.optional(v.number()),
    isAnonymous: v.optional(v.boolean()),
    image: v.optional(v.string()),
    // --- migrated profile fields ---
    pbId: v.optional(v.string()),
    avatar: v.optional(v.id("_storage")), // PB file field (empty in current data)
    home_id: v.optional(v.array(v.id("homes"))), // PB maxSelect=999 -> array
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("email", ["email"])
    .index("by_pbId", ["pbId"]),

  // One row per device that has agreed to receive pushes. A user can have
  // several (phone, iPad), and a token can move between users if a device is
  // handed on — `by_token` exists so re-registration replaces rather than
  // duplicates.
  push_tokens: defineTable({
    user_id: v.id("users"),
    /// Hex device token from `didRegisterForRemoteNotificationsWithDeviceToken`.
    token: v.string(),
    /// Which APNs gateway this token is valid on. A sandbox token is rejected
    /// by the production gateway and vice versa, so it must be stored.
    environment: v.union(v.literal("sandbox"), v.literal("production")),
    created: v.number(),
    updated: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_token", ["token"]),

  // The signed APNs provider JWT, cached. Apple rejects a provider that mints
  // tokens more than once every 20 minutes (`TooManyProviderTokenUpdates`), and
  // actions are stateless, so the token has to live somewhere.
  apns_credentials: defineTable({
    jwt: v.string(),
    issued: v.number(),
  }),

  homes: defineTable({
    pbId: v.optional(v.string()),
    name: v.optional(v.string()),
    address: v.optional(v.object({ lat: v.number(), lng: v.number() })), // PB geoPoint
    members: v.array(v.id("users")),
    invite_code: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_invite_code", ["invite_code"]),

  tasks: defineTable({
    pbId: v.optional(v.string()),
    title: v.optional(v.string()),
    description: v.optional(v.string()),
    created_by: v.id("users"),
    updated_by: v.optional(v.id("users")),
    assigned_to: v.optional(v.id("users")),
    is_completed: v.optional(v.boolean()),
    // Who ticked the box. `updated_by` is only *approximately* this — an edit to
    // the title overwrites it — so completion is recorded separately, and the
    // stats attribute a chore to the person who actually finished it. Optional:
    // never-completed tasks have none, and every row migrated from PocketBase
    // predates the field (see `creditFor` in convex/stats.ts for the fallback).
    completed_by: v.optional(v.id("users")),
    image: v.optional(v.id("_storage")),
    home_id: v.id("homes"),
    priority: v.optional(v.union(v.literal("low"), v.literal("medium"), v.literal("high"))),
    type: v.optional(
      v.union(
        v.literal("cleaning"),
        v.literal("shopping"),
        v.literal("maintenance"),
        v.literal("general"),
      ),
    ),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
    due_date: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  shopping_items: defineTable({
    pbId: v.optional(v.string()),
    name: v.optional(v.string()),
    description: v.optional(v.string()),
    quantity: v.optional(v.number()),
    is_purchased: v.optional(v.boolean()),
    category: v.optional(
      v.union(
        v.literal("groceries"),
        v.literal("household"),
        v.literal("cleaning"),
        v.literal("other"),
      ),
    ),
    created_by: v.optional(v.id("users")),
    updated_by: v.optional(v.id("users")),
    home_id: v.id("homes"),
    // Set when the item came from a recipe's ingredient list, so the shopping
    // list can group "everything for Sunday's lasagne" and point back at it.
    // The title is denormalised on purpose: the shopping screen subscribes to
    // items only, and a group heading must not cost it a second subscription
    // or break when the recipe is later deleted.
    recipe_id: v.optional(v.id("recipes")),
    recipe_title: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  notes: defineTable({
    pbId: v.optional(v.string()),
    description: v.optional(v.string()),
    created_by: v.id("users"),
    home_id: v.id("homes"),
    image: v.optional(v.id("_storage")),
    color: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  conversations: defineTable({
    pbId: v.optional(v.string()),
    participants: v.array(v.id("users")),
    home_id: v.id("homes"),
    is_group_chat: v.optional(v.boolean()),
    title: v.optional(v.string()),
    last_message: v.optional(v.string()),
    last_message_at: v.optional(v.number()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  messages: defineTable({
    pbId: v.optional(v.string()),
    // Required: 4 senderless test messages migrated from PocketBase rendered
    // with a blank name and no avatar; deleted 2026-09-03. messages:send always
    // takes the sender from the authenticated session.
    sender_id: v.id("users"),
    conversation_id: v.id("conversations"),
    content: v.optional(v.string()),
    message_type: v.optional(
      v.union(v.literal("text"), v.literal("image"), v.literal("system")),
    ),
    file: v.optional(v.id("_storage")),
    read_by: v.optional(v.array(v.id("users"))),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_pbId", ["pbId"])
    .index("by_conversation", ["conversation_id"]),

  recipes: defineTable({
    pbId: v.optional(v.string()),
    title: v.optional(v.string()),
    description: v.optional(v.string()),
    ingredients: v.optional(v.any()), // PB json
    steps: v.optional(v.any()), // PB json
    prep_time: v.optional(v.number()),
    cook_time: v.optional(v.number()),
    servings: v.optional(v.number()),
    difficulty: v.optional(
      v.union(v.literal("easy"), v.literal("medium"), v.literal("hard")),
    ),
    image: v.optional(v.id("_storage")),
    home_id: v.id("homes"),
    created_by: v.id("users"),
    tags: v.optional(v.array(v.string())), // PB multi-select; kept loose for flexibility
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  // What the household is eating, one row per home per day. The winner of a
  // "what should we cook" round writes one, and so does planning a recipe by
  // hand. `date` is a plain YYYY-MM-DD string in the home's own reckoning: the
  // question is "what are we eating tonight", which is a calendar day, not an
  // instant, and an epoch stamp would put half the household on yesterday.
  meal_plans: defineTable({
    home_id: v.id("homes"),
    // Dinner is a decision before it is a dish: cook something, order it in, or
    // go out. Only `cook` carries a recipe; the other two carry a cuisine and,
    // if anyone has decided, where from.
    kind: v.union(v.literal("cook"), v.literal("order"), v.literal("out")),
    recipe_id: v.optional(v.id("recipes")),
    // Cooking something that is not a recipe — leftovers, a family dish nobody
    // has written down. Carries the name so the card has something to show.
    title: v.optional(v.string()),
    cuisine: v.optional(v.string()),
    place: v.optional(v.string()),
    date: v.string(),
    planned_by: v.optional(v.id("users")),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_home", ["home_id"])
    .index("by_home_date", ["home_id", "date"]),

  polls: defineTable({
    pbId: v.optional(v.string()),
    // Required: the legacy PocketBase polls that lacked these were purged
    // 2026-09-03, and polls:create always sets both. `requireDocHome` and
    // `requirePollOwner` can therefore never hit an unattached/unowned poll.
    home_id: v.id("homes"),
    owner_id: v.id("users"),
    title: v.optional(v.string()),
    type: v.optional(
      v.union(v.literal("movie"), v.literal("recipe"), v.literal("generic")),
    ),
    status: v.optional(
      v.union(v.literal("draft"), v.literal("active"), v.literal("closed")),
    ),
    genre: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  poll_items: defineTable({
    pbId: v.optional(v.string()),
    poll_id: v.id("polls"),
    external_id: v.string(),
    label: v.optional(v.string()),
    thumbnail_url: v.optional(v.string()),
    payload: v.optional(v.any()), // PB json
    order: v.optional(v.number()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_pbId", ["pbId"])
    .index("by_poll", ["poll_id"]),

  poll_votes: defineTable({
    pbId: v.optional(v.string()),
    // Required: 60 migrated votes had a null user_id, so they counted toward
    // tallies while belonging to nobody. Purged 2026-09-03; polls:vote always
    // takes the voter from the authenticated session.
    poll_id: v.id("polls"),
    target_external_id: v.string(),
    vote: v.boolean(),
    user_id: v.id("users"),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_pbId", ["pbId"])
    .index("by_poll", ["poll_id"])
    .index("by_poll_user_target", ["poll_id", "user_id", "target_external_id"]),

  movies: defineTable({
    pbId: v.optional(v.string()),
    imdb_id: v.optional(v.string()),
    home_id: v.id("homes"),
    list_id: v.id("movie_lists"),
    title: v.optional(v.string()),
    year: v.optional(v.number()),
    poster: v.optional(v.string()),
    genres: v.optional(v.any()), // PB json
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"])
    .index("by_list", ["list_id"]),

  movie_lists: defineTable({
    pbId: v.optional(v.string()),
    home_id: v.id("homes"),
    name: v.optional(v.string()),
    description: v.optional(v.string()),
    type: v.optional(
      v.union(v.literal("wishlist"), v.literal("watched"), v.literal("custom")),
    ),
    is_preset: v.optional(v.boolean()),
    runtime: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),
  // --- Bills & Finance -------------------------------------------------------
  //
  // Money is stored in **minor units** (cents, kuruş) as integers, never as a
  // decimal amount. A three-way split of 10.00 is 334 + 333 + 333, which is
  // exact; the same split in floating-point euros is not, and a household
  // ledger that loses a cent per expense stops adding up after a month.
  // `v.number()` is float64, so these are integer-valued doubles.
  //
  // Currency travels on each document rather than living on the home: a
  // household that pays rent in one currency and a holiday in another still
  // gets both formatted correctly, and nothing has to be converted behind
  // anyone's back.

  expenses: defineTable({
    home_id: v.id("homes"),
    title: v.optional(v.string()),
    /** Total, in minor units. */
    amount: v.number(),
    /** ISO 4217, e.g. "EUR". */
    currency: v.string(),
    category: v.optional(financeCategory),
    /** Who actually put the money down. */
    paid_by: v.id("users"),
    /**
     * The resolved shares. Always sums to `amount` exactly — the remainder of an
     * uneven division is handed out a minor unit at a time — so a balance never
     * drifts from the sum of the expenses that produced it.
     */
    splits: v.array(v.object({ user_id: v.id("users"), amount: v.number() })),
    split_mode: v.union(v.literal("equal"), v.literal("shares"), v.literal("exact")),
    /**
     * What the split was *authored* as, so reopening the editor shows the two
     * shares the person typed rather than the amounts those happened to resolve
     * to. Absent for an equal split, where the participants are the whole story.
     */
    weights: v.optional(
      v.array(v.object({ user_id: v.id("users"), weight: v.number() })),
    ),
    note: v.optional(v.string()),
    /** When the money was spent, which is not always when it was entered. */
    spent_at: v.number(),
    /** Set when this expense was logged by paying a recurring bill. */
    bill_id: v.optional(v.id("bills")),
    created_by: v.id("users"),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_home", ["home_id"])
    .index("by_home_spent", ["home_id", "spent_at"]),

  // A payment from one member to another, squaring up what the expenses say
  // they owe. Kept as its own table rather than as a negative expense: it moves
  // money without anything being *spent*, so it must never reach a category
  // total, a budget or the month's spend.
  settlements: defineTable({
    home_id: v.id("homes"),
    from_user: v.id("users"),
    to_user: v.id("users"),
    amount: v.number(),
    currency: v.string(),
    note: v.optional(v.string()),
    settled_at: v.number(),
    created_by: v.id("users"),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_home", ["home_id"]),

  // The bills that come round again — rent, power, the streaming service nobody
  // admits to. A bill is a *schedule*, not a spend: paying one writes an
  // expense and rolls `due_date` forward, so the ledger records what happened
  // and the timeline records what is next.
  bills: defineTable({
    home_id: v.id("homes"),
    title: v.optional(v.string()),
    amount: v.number(),
    currency: v.string(),
    category: v.optional(financeCategory),
    cycle: v.union(
      v.literal("once"),
      v.literal("weekly"),
      v.literal("biweekly"),
      v.literal("monthly"),
      v.literal("quarterly"),
      v.literal("yearly"),
    ),
    /** Next payment due, epoch-ms. */
    due_date: v.number(),
    /** Whose job it is to actually pay it. Nobody's, by default. */
    responsible: v.optional(v.id("users")),
    /** Whether paying it splits equally across the household. */
    auto_split: v.optional(v.boolean()),
    /** Retired rather than deleted, so the expenses it produced keep their source. */
    is_archived: v.optional(v.boolean()),
    /**
     * Whole days before `due_date` to nudge the household, e.g. `[3, 1, 0]`.
     * At most three: a bill that pings four times is a bill people mute.
     */
    reminders: v.optional(v.array(v.number())),
    /**
     * Which nudges have already gone out, as `"<due_date>:<daysBefore>"` (plus
     * `"<due_date>:overdue"` for the one late nudge).
     *
     * Keyed by the due date on purpose: the sweep runs daily and would
     * otherwise send the same reminder every morning, and paying the bill moves
     * `due_date`, which retires every key belonging to the cycle just closed.
     */
    reminded: v.optional(v.array(v.string())),
    last_paid_at: v.optional(v.number()),
    created_by: v.id("users"),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_home", ["home_id"]),

  // A monthly ceiling for one category. One row per home per category — a
  // budget is a standing intention, not a per-month document, so changing it
  // does not rewrite history.
  budgets: defineTable({
    home_id: v.id("homes"),
    category: financeCategory,
    /** Monthly limit, in minor units. */
    limit: v.number(),
    currency: v.string(),
    created_by: v.id("users"),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_home", ["home_id"])
    .index("by_home_category", ["home_id", "category"]),
});
