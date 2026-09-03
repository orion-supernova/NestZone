// Nestzone — Convex schema migrated from PocketBase.
//
// Notes:
// - Every relation field is v.optional(...) on purpose: the importer inserts
//   docs first WITHOUT relations (pass 1), then patches them (pass 2). This is
//   required because the data has cycles (users <-> homes, conversations <-> messages).
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

  homes: defineTable({
    pbId: v.optional(v.string()),
    name: v.optional(v.string()),
    address: v.optional(v.object({ lat: v.number(), lng: v.number() })), // PB geoPoint
    members: v.optional(v.array(v.id("users"))),
    invite_code: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_invite_code", ["invite_code"]),

  tasks: defineTable({
    pbId: v.optional(v.string()),
    title: v.optional(v.string()),
    description: v.optional(v.string()),
    created_by: v.optional(v.id("users")),
    updated_by: v.optional(v.id("users")),
    assigned_to: v.optional(v.id("users")),
    is_completed: v.optional(v.boolean()),
    image: v.optional(v.id("_storage")),
    home_id: v.optional(v.id("homes")),
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
    home_id: v.optional(v.id("homes")),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  notes: defineTable({
    pbId: v.optional(v.string()),
    description: v.optional(v.string()),
    created_by: v.optional(v.id("users")),
    home_id: v.optional(v.id("homes")),
    image: v.optional(v.id("_storage")),
    color: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

  conversations: defineTable({
    pbId: v.optional(v.string()),
    participants: v.optional(v.array(v.id("users"))),
    home_id: v.optional(v.id("homes")),
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
    sender_id: v.optional(v.id("users")),
    content: v.optional(v.string()),
    message_type: v.optional(
      v.union(v.literal("text"), v.literal("image"), v.literal("system")),
    ),
    file: v.optional(v.id("_storage")),
    read_by: v.optional(v.array(v.id("users"))),
    conversation_id: v.optional(v.id("conversations")),
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
    home_id: v.optional(v.id("homes")),
    created_by: v.optional(v.id("users")),
    tags: v.optional(v.array(v.string())), // PB multi-select; kept loose for flexibility
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"]),

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
    home_id: v.optional(v.id("homes")),
    list_id: v.optional(v.id("movie_lists")),
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
    home_id: v.optional(v.id("homes")),
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
});
