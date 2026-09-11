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
// What a household event *is*.
//
// Mostly a label — it picks the symbol and the colour — but it also decides
// which parts of the plan the composer opens with. A dinner party wants a menu;
// a concert wants a ticket link and a budget; a dentist appointment wants
// neither. The client owns that mapping (see `EventKind` in
// Core/Models/CalendarEvent.swift); the server only needs the vocabulary.
//
// Nineteen is a lot for a picker, which is why they are grouped rather than
// listed. The alternative — three kinds and a free-text label — throws away the
// only signal the app has about what an event needs prepared for it.
const eventKind = v.union(
  // At home
  v.literal("general"),
  v.literal("houseParty"),
  v.literal("dinnerParty"),
  v.literal("movieNight"),
  v.literal("gameNight"),
  v.literal("visit"),
  v.literal("chore"),
  // Going out
  v.literal("dining"),
  v.literal("concert"),
  v.literal("cinema"),
  v.literal("theatre"),
  v.literal("sports"),
  v.literal("picnic"),
  v.literal("trip"),
  // Occasions
  v.literal("birthday"),
  v.literal("anniversary"),
  v.literal("holiday"),
  // Admin
  v.literal("appointment"),
  v.literal("deadline"),
);

// Whether somebody is coming.
const rsvpStatus = v.union(
  v.literal("going"),
  v.literal("maybe"),
  v.literal("declined"),
);

/**
 * How an event repeats.
 *
 * Deliberately smaller than RRULE, and deliberately without `COUNT`. Every
 * other field can be answered by arithmetic — the nth occurrence is a closed
 * form — so expanding a window means jumping straight to the first occurrence
 * inside it. "The 30th time" cannot: it has to be counted from the series
 * start, which turns every read of next week into a walk over three years of
 * Tuesdays. "Until a date" and "forever" are what households actually mean, so
 * that is what this offers.
 */
const recurrence = v.object({
  freq: v.union(
    v.literal("daily"),
    v.literal("weekly"),
    v.literal("monthly"),
    v.literal("yearly"),
  ),
  /** Every `interval` days/weeks/months/years. At least 1. */
  interval: v.number(),
  /** 0=Sunday … 6=Saturday. Weekly only; empty means "the same weekday as the start". */
  weekdays: v.optional(v.array(v.number())),
  /** Last instant the series may produce an occurrence. Absent means forever. */
  until: v.optional(v.number()),
});

// --- House problems --------------------------------------------------------
//
// What is wrong with the house, as a vocabulary rather than free text. A
// household writes "tap drips" and "the tap in the kitchen drips again" for the
// same fault, so the only way the app can ever say "this is the fourth time the
// kitchen plumbing has gone" is if the *where* and the *what* are chosen from a
// list. Everything the Problems screen groups, charts or warns about is built
// on these three fields.

/** How far along a problem is. The order is the order it is drawn in. */
const issueStatus = v.union(
  /** Somebody has said it is broken. Nothing has happened yet. */
  v.literal("reported"),
  /** The household has seen it and agrees it is real. */
  v.literal("acknowledged"),
  /** Somebody is coming, or a date is set. */
  v.literal("scheduled"),
  /** Being worked on now. */
  v.literal("inProgress"),
  /** Stuck on something outside the house — a part, a landlord, a quote. */
  v.literal("blocked"),
  /** Fixed. */
  v.literal("fixed"),
  /** Decided against: the wobbly shelf everyone has made peace with. */
  v.literal("wontFix"),
);

/**
 * How badly it matters.
 *
 * Four steps, not five: the distinction people can actually hold is "annoying /
 * needs doing / needs doing soon / do not wait". A ten-point scale is a scale
 * nobody agrees on.
 */
const issueSeverity = v.union(
  v.literal("cosmetic"),
  v.literal("minor"),
  v.literal("major"),
  v.literal("urgent"),
);

/** Where in the house it is. */
const issueArea = v.union(
  v.literal("kitchen"),
  v.literal("bathroom"),
  v.literal("bedroom"),
  v.literal("living"),
  v.literal("hallway"),
  v.literal("laundry"),
  v.literal("garage"),
  v.literal("garden"),
  v.literal("balcony"),
  v.literal("basement"),
  v.literal("roof"),
  v.literal("exterior"),
  v.literal("whole"),
  v.literal("other"),
);

/** What kind of thing is broken — which decides who you call. */
const issueCategory = v.union(
  v.literal("plumbing"),
  v.literal("electrical"),
  v.literal("heating"),
  v.literal("appliance"),
  v.literal("furniture"),
  v.literal("structural"),
  v.literal("internet"),
  v.literal("pest"),
  v.literal("damp"),
  v.literal("safety"),
  v.literal("cosmetic"),
  v.literal("other"),
);

/** What an entry on a problem's timeline is. */
const issueEntryKind = v.union(
  /** Somebody wrote something. */
  v.literal("comment"),
  /** The status moved. Carries both ends of the move. */
  v.literal("status"),
  /** Something was attached — a chore, a visit, parts, a receipt. */
  v.literal("link"),
  /** The app said something on the household's behalf. */
  v.literal("system"),
);

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
    /**
     * When the box was ticked.
     *
     * The record of *that* lives in `task_completions`; this is the display
     * copy, and it exists so the Done list can be an index range rather than a
     * scan. Without it the nearest thing was `updated`, which every incidental
     * edit bumps, and the only orderable field on the index was `_creationTime`
     * — the date the chore was *written down*, which for anything that sat on
     * the list for a fortnight is not the date it was done.
     *
     * It is also the whole of what "archived" means here. A chore is on the
     * Done list if it was finished inside the window and in the Archive if it
     * was not, which makes the two lists disjoint by construction — there is no
     * flag to set, nothing to sweep, and no way for a chore to appear in both.
     * An archive that also carried everything still on the working list would
     * not be an archive; it would be a second copy of it.
     *
     * Cleared when a task is reopened, alongside `completed_by`, so it never
     * outlives the completion it describes. Absent on rows finished before it
     * shipped until `backfillCompletions` fills it in.
     */
    completed_at: v.optional(v.number()),
    /**
     * When somebody put this finished chore away by hand.
     *
     * The Archive holds two kinds of chore and this is what separates them: one
     * fell below the window on its own, the other was pushed. They are the same
     * shelf and the same idea — *finished, and off the working list* — which is
     * why there is one screen and not two, and why `Done` and the Archive stay
     * disjoint whichever route a row took.
     *
     * "Archived OR old" is not one index range, but it is two, and merging two
     * index reads is how `openTasks` has always answered "false or absent" (see
     * lib/pending.ts). Two bounded reads beat the filter this would otherwise
     * become.
     *
     * Only ever set on a completed task, and cleared on reopen: an open chore is
     * work outstanding, and hiding it from the list of work outstanding is just
     * losing it.
     */
    archived_at: v.optional(v.number()),
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
    /**
     * Set when this chore exists because something in the house is broken.
     *
     * A link, not an owner, in both directions: deleting the problem leaves the
     * chore standing (somebody still has to do it) and deleting the chore leaves
     * the problem standing (it is still broken). What the link buys is the one
     * thing neither table could say alone — finishing the chore is news on the
     * problem's timeline, which is where `tasks:update` posts it.
     */
    issue_id: v.optional(v.id("issues")),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"])
    // "What is still to be done" — the Home tab's one task number, and the only
    // one anything displays. Counting it used to mean collecting every task the
    // household had ever finished as well, which is a set that only grows.
    // `is_completed` is optional, so an open task sits under `false` *or*
    // `undefined` — see `openTasks` in lib/pending.ts.
    //
    // The trailing fields are what make the *finished* half bounded too. Open
    // reads still use the `["home_id", "is_completed"]` prefix and are
    // unaffected. Everything else is a range on this one index:
    //
    //   Done      eq(archived_at, undefined), gte(completed_at, cutoff)
    //   aged out  eq(archived_at, undefined), lt(completed_at, cutoff)
    //   put away  gte(archived_at, 0)
    //
    // The Archive is the last two merged — `undefined` sorts before every
    // number in a Convex index, so "never archived" and "archived" are two
    // clean ranges rather than one range and a filter.
    .index("by_home_completed", ["home_id", "is_completed", "archived_at", "completed_at"]),

  /**
   * Every chore this household has ever finished. The record, not the work.
   *
   * A task row is *current state* — it can be edited, reopened, archived and
   * deleted. History derived from current state is history anybody can rewrite
   * by accident, and that is exactly what happened here: the contribution
   * split was tallied by walking the `tasks` table, so deleting a finished
   * chore silently took somebody's credit for it with them. One swipe on the
   * Tasks screen could change who the app said was doing the housework.
   *
   * So a completion is its own document, written when the box is ticked and
   * removed only when it is *unticked* — which is the one act that genuinely
   * means "this was not done after all", and which the person doing it can see
   * the effect of. Deleting a finished task cannot reach this table at all;
   * `tasks:remove` refuses completed rows outright and offers Archive instead.
   *
   * It is also the read `stats:contributions` wanted all along. That query used
   * to `.collect()` every task in the household to tally six numbers — the
   * unbounded scan the rest of this schema spends its comments fighting. Here
   * the window the screen actually asked for *is* an index range, and the rows
   * are a fraction of the size of the tasks they describe.
   */
  task_completions: defineTable({
    home_id: v.id("homes"),
    /**
     * The chore this was. Kept live: a completion is deleted with its task
     * (which can only happen once the task has been reopened, or with the whole
     * home), so this never dangles.
     */
    task_id: v.id("tasks"),
    /**
     * Who it counts for. Absent when the app cannot say — a chore imported from
     * PocketBase with no author, or finished by somebody who has since left.
     * Kept as a row rather than dropped, so the shares still add up to the
     * total.
     */
    user_id: v.optional(v.id("users")),
    /**
     * What the chore was called when it was finished, and what kind of work it
     * was. Snapshots, so both readers of this table — the contribution tally
     * and the History screen — can answer from it alone without fetching a task
     * per row. `tasks:update` keeps the title in step while the task lives, so
     * the copy is a performance decision rather than a second version of the
     * truth.
     */
    title: v.optional(v.string()),
    type: v.optional(
      v.union(
        v.literal("cleaning"),
        v.literal("shopping"),
        v.literal("maintenance"),
        v.literal("general"),
      ),
    ),
    completed_at: v.number(),
  })
    // For `cascadeDeleteHome`, which finds a household's rows by index rather
    // than walking the tasks it once had.
    .index("by_home", ["home_id"])
    // The read behind both the contribution tally and the History screen: one
    // household, newest first, bounded by the window that was asked for.
    .index("by_home_at", ["home_id", "completed_at"])
    // Retracting credit when a chore is reopened, and keeping the title snapshot
    // in step when it is renamed.
    .index("by_task", ["task_id"]),

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
    // Set when the item is on the list *for* something in the calendar. Same
    // denormalised-title trick as the recipe link above, and for the same
    // reason: the shopping screen subscribes to items only, so a group heading
    // must not cost it a second subscription or break when the event is gone.
    event_id: v.optional(v.id("events")),
    event_title: v.optional(v.string()),
    // Set when the line is a *part* — the washer for the dripping tap, the bulb
    // for the dead hall light. The third of the three reasons a household adds
    // something to the list, and the same denormalised-title trick as the two
    // above, for the same reason: the shopping screen subscribes to items only,
    // so a group heading must not cost it a second subscription or break when
    // the problem is closed and tidied away.
    issue_id: v.optional(v.id("issues")),
    issue_title: v.optional(v.string()),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  }).index("by_pbId", ["pbId"])
    .index("by_home", ["home_id"])
    // "What is still on the list" — the question four different call sites ask
    // before adding to it (`events:detail`, `events:stockUp`, `events:addItems`,
    // `shopping:createFromRecipe`). They each used to answer it by collecting
    // the home's whole shopping history and filtering in JS, which grows without
    // bound and is what timed `events:detail` out at one second. `is_purchased`
    // is optional, so a bought item sits under `true` and an outstanding one
    // under `false` *or* `undefined` — see `outstandingNames` in lib/shopping.ts.
    .index("by_home_purchased", ["home_id", "is_purchased"])
    .index("by_event", ["event_id"])
    .index("by_issue", ["issue_id"]),

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
    /**
     * Set when the meal belongs to something in the calendar — Saturday's
     * dinner party rather than Saturday's dinner.
     *
     * The one link between the two, and deliberately only one. A meal plan
     * answers "what are we eating on day D"; an event answers "what is
     * happening at time T, and what has to be ready". A dinner party is both,
     * and this is the field that says so — so the Home tab's tonight card can
     * point at the event that owns the budget, the shopping and the menu
     * instead of a second copy of any of them.
     *
     * A link, not an owner: deleting the event leaves the household still
     * eating that night.
     */
    event_id: v.optional(v.id("events")),
    planned_by: v.optional(v.id("users")),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_home", ["home_id"])
    .index("by_home_date", ["home_id", "date"])
    // Which days an event is already the dinner on. Without it the only way to
    // ask was a filter over every meal plan in the *database* — see
    // `unlinkEvent`, which did exactly that on every event delete.
    .index("by_event", ["event_id"]),

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
    /**
     * Set when the money was spent *on* something in the calendar — the
     * caterer for Saturday's party, the tickets for the gig.
     *
     * A link, not an owner: deleting the event unlinks these rather than
     * deleting them, because the money still moved and a household's balances
     * must not change because somebody tidied their calendar.
     */
    event_id: v.optional(v.id("events")),
    /**
     * Set when the money was spent *fixing* something — the plumber, the part,
     * the replacement kettle.
     *
     * The same shape of link as `event_id` above and it keeps the same promise:
     * closing the problem never touches the ledger, because the money moved
     * whatever the household later decided about the shelf. It is what lets a
     * problem say what it actually cost without keeping a second copy of the
     * figure, and what lets the ledger explain a line nobody remembers.
     */
    issue_id: v.optional(v.id("issues")),
    created_by: v.id("users"),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_home", ["home_id"])
    .index("by_home_spent", ["home_id", "spent_at"])
    .index("by_event", ["event_id"])
    .index("by_issue", ["issue_id"]),

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
  }).index("by_home", ["home_id"])
    // For `finance:sweepReminders`, the daily cron. It has to consider every
    // household, so it is the one bill read that is not home-scoped — which
    // made it a scan of every bill in the deployment, growing with the number
    // of people using the app rather than with the work actually due. A bill
    // can only be nudged from `MAX_REMINDER_DAYS` before its date until it goes
    // overdue, so a range on the date is the whole working set.
    .index("by_due_date", ["due_date"]),

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

  // --- Calendar & Events -----------------------------------------------------
  //
  // One row is a *series*, not an appointment. A one-off event is a series of
  // one; "every other Tuesday" is a single row that the server expands into
  // concrete occurrences for whatever window the client is looking at. The
  // client never does recurrence arithmetic and never holds an event it is not
  // showing — the same reasoning that put `finance:summary` and `stats:forHome`
  // on the server.
  //
  // Times are absolute epoch-ms, unlike `meal_plans.date`. An event happens at
  // an instant; dinner happens on a day. `tz_offset` rides along so "the 14th
  // at 9am, monthly" keeps meaning the 14th at 9am rather than drifting by the
  // reader's zone (see `expand` in convex/events.ts).
  events: defineTable({
    home_id: v.id("homes"),
    title: v.optional(v.string()),
    notes: v.optional(v.string()),
    location: v.optional(v.string()),
    kind: v.optional(eventKind),
    /** First occurrence, epoch-ms. */
    starts_at: v.number(),
    /** End of the first occurrence. Every later one carries the same duration. */
    ends_at: v.number(),
    /**
     * An all-day event. `starts_at` is local midnight and `ends_at` local
     * midnight on the day after the last — so a one-day event is a 24h span,
     * and the UI never has to show a time that was never chosen.
     */
    is_all_day: v.optional(v.boolean()),
    /** Minutes east of UTC where the series was written. */
    tz_offset: v.optional(v.number()),
    recurrence: v.optional(recurrence),
    /**
     * The last instant this row can still produce an occurrence: the end of a
     * one-off, the recurrence's `until`, or `FOREVER`.
     *
     * Denormalised so that "what is on this month" is one index range rather
     * than a scan of every event the household has ever held. Without it the
     * only way to find a weekly series that started two years ago is to read
     * two years of rows and throw nearly all of them away.
     */
    series_end: v.number(),
    /**
     * Occurrence start times lifted out of the series — a cancelled Tuesday, or
     * one moved and re-saved as its own event. Kept on the series rather than
     * as tombstone rows: the expansion already walks this row, and a `Set`
     * lookup costs nothing.
     */
    exdates: v.optional(v.array(v.number())),
    /**
     * Somewhere to go for the thing itself — the ticket, the booking, the
     * listing. One field rather than a "tickets" sub-object: what a household
     * actually keeps is the link somebody sent in the chat.
     */
    url: v.optional(v.string()),

    // --- The plan --------------------------------------------------------
    //
    // An event is rarely just a time. A house party is a menu, a shop and a
    // bill; a concert is a ticket and a night out that costs something. These
    // three links are what turn the calendar from a list of dates into the
    // place the rest of the app is organised from — and each one points at the
    // module that already owns that data rather than copying it:
    //
    //   money    -> `expenses.event_id`      (the ledger stays the ledger)
    //   shopping -> `shopping_items.event_id` (the list stays the list)
    //   food     -> `recipe_ids` here         (recipes are read through)
    //
    // Nothing is denormalised except a title, and only where a group heading
    // has to survive the thing it names being deleted.
    //
    // The plan belongs to the *series*. For a one-off — which is what parties,
    // concerts and dinners are — that is exactly right. For "movie night, every
    // Friday" it reads as a standing plan: the snacks you always buy, the
    // budget for the season.

    /** What the household means to spend on it, in minor units. */
    budget: v.optional(v.number()),
    /** ISO 4217 for `budget`. Per-document, like every other amount in the app. */
    currency: v.optional(v.string()),
    /** The menu. Read through on the way out so no screen subscribes to recipes. */
    recipe_ids: v.optional(v.array(v.id("recipes"))),

    /** Who is expected. Members of this home, checked on write. */
    attendees: v.optional(v.array(v.id("users"))),
    /** Who has answered, and how. Per series — an RSVP to "every Tuesday" is one answer. */
    rsvps: v.optional(v.array(v.object({ user_id: v.id("users"), status: rsvpStatus }))),
    /**
     * Whole minutes before an occurrence to nudge the household, e.g.
     * `[1440, 30]`. At most three, like a bill's.
     */
    reminders: v.optional(v.array(v.number())),
    /**
     * Nudges already sent, as `"<occurrence_start>:<minutesBefore>"`.
     *
     * Keyed by the occurrence rather than the row, because one row is many
     * appointments — and pruned as it goes (see `markReminded` in
     * convex/events.ts), or a standing Tuesday would grow this array forever.
     */
    reminded: v.optional(v.array(v.string())),
    created_by: v.id("users"),
    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_home", ["home_id"])
    .index("by_home_series_end", ["home_id", "series_end"])
    .index("by_series_end", ["series_end"]),

  // --- House problems --------------------------------------------------------
  //
  // Everything in a shared home that is broken, and what the household is doing
  // about it. One row is one fault, from the moment somebody notices it to the
  // moment it is fixed — or to the moment everyone agrees to live with it.
  //
  // It is deliberately not a task list. A chore is a thing to *do* and it is
  // finished when somebody does it; a problem is a thing that is *wrong*, it can
  // outlive several attempts to fix it, it costs money, it needs parts, and the
  // same one comes back. So it keeps its own state machine, its own history, and
  // links out to the modules that already own the work:
  //
  //   the chore     -> `tasks.issue_id`          (the task list stays the task list)
  //   the visit     -> `issues.event_id`         (the calendar stays the calendar)
  //   the parts     -> `shopping_items.issue_id` (the list stays the list)
  //   what it cost  -> `expenses.issue_id`       (the ledger stays the ledger)
  //
  // Nothing is copied across those links except a title, and only where a group
  // heading has to survive the thing it names being deleted.
  issues: defineTable({
    home_id: v.id("homes"),
    title: v.optional(v.string()),
    details: v.optional(v.string()),
    area: issueArea,
    category: issueCategory,
    severity: issueSeverity,
    status: issueStatus,

    /**
     * Whether this problem is still outstanding — `status` is neither `fixed`
     * nor `wontFix`.
     *
     * Denormalised, and the two indexes below are why. "What is still wrong"
     * is the question every screen in this module asks, and an index cannot
     * range over "any of five statuses" in one pass. Without it, the list read
     * every problem the household had ever had — including the fixed ones,
     * which only accumulate — and the daily sweep read every problem in the
     * deployment. Kept in step by `setStatus` in convex/issues.ts, which — with the two plan
     * mutations that move a problem along as a side effect — is all that ever
     * writes `status`.
     */
    is_open: v.boolean(),

    reported_by: v.id("users"),
    /** Whose job it is. Nobody's, by default. */
    assigned_to: v.optional(v.id("users")),

    /**
     * Pictures of the fault. Nothing explains a leak like a photo of it, and a
     * plumber asked over the phone will ask for one.
     *
     * `_storage` ids, resolved to URLs on the way out (see `photoUrls` in
     * convex/issues.ts) so no client ever holds a storage id it has to know
     * what to do with. Capped — see `MAX_PHOTOS`.
     */
    photos: v.optional(v.array(v.id("_storage"))),

    /** When it has to be sorted by, if anything makes it urgent. */
    due_by: v.optional(v.number()),
    /** Why it is stuck. Only meaningful while `status` is `blocked`. */
    blocked_reason: v.optional(v.string()),

    resolved_at: v.optional(v.number()),
    resolved_by: v.optional(v.id("users")),
    /** What actually fixed it, for the next time it happens. */
    resolution: v.optional(v.string()),

    /** What the household expects it to cost, in minor units. */
    cost_estimate: v.optional(v.number()),
    /** ISO 4217 for `cost_estimate`. Per-document, like every other amount. */
    currency: v.optional(v.string()),

    /** Who to call. A name and a number beats a memory of a name. */
    vendor_name: v.optional(v.string()),
    vendor_phone: v.optional(v.string()),
    vendor_url: v.optional(v.string()),
    /** Covered until. A broken appliance is a different problem under warranty. */
    warranty_until: v.optional(v.number()),

    /**
     * Everyone else who has hit this too.
     *
     * The cheapest useful signal in a shared house: one person reporting a cold
     * radiator is a maintenance note, three people reporting it is the heating.
     * It sorts the list and it is the only thing anybody has to do to agree.
     */
    me_too: v.optional(v.array(v.id("users"))),

    /** The chore made of it, if somebody made one. */
    task_id: v.optional(v.id("tasks")),
    /** The visit booked for it, if somebody booked one. */
    event_id: v.optional(v.id("events")),

    /**
     * When anything last happened here — a comment, a status move, a part
     * added. Not `updated`, which every incidental patch bumps.
     *
     * This is what "nobody has touched this in a fortnight" is measured
     * against, and it is half of the index the daily sweep reads.
     */
    last_activity_at: v.number(),
    /**
     * Nudges already sent, as `"<due_by>:overdue"` and
     * `"<last_activity_at>:stale"`.
     *
     * Keyed by the thing that caused them, exactly as a bill's are keyed by its
     * due date: any activity moves `last_activity_at`, which retires the stale
     * key and lets the next quiet stretch nudge once on its own account. A
     * reminder that repeats every morning is a reminder people turn off.
     */
    reminded: v.optional(v.array(v.string())),

    created: v.optional(v.number()),
    updated: v.optional(v.number()),
  })
    .index("by_home", ["home_id"])
    // "What is still wrong here" — the read behind the whole module. See
    // `is_open` above for why this is a boolean rather than a status range.
    .index("by_home_open", ["home_id", "is_open"])
    // For the daily sweep, which has to consider every household and so is the
    // one issue read that is not home-scoped. Bounded on both ends by the
    // activity range: a problem is only worth nudging about between a few days
    // and a few weeks of silence.
    .index("by_open_activity", ["is_open", "last_activity_at"]),

  // A problem's history: what people said, and what the app watched happen.
  //
  // Its own table rather than an array on the issue, for the reason every
  // append-only list in this schema is: a comment is a write, and a write to an
  // array field rewrites — and re-publishes — the whole document, so a busy
  // problem would push its photos and its vendor details to every subscriber
  // every time somebody typed a line.
  issue_comments: defineTable({
    issue_id: v.id("issues"),
    /**
     * Carried as well as `issue_id`, so `cascadeDeleteHome` can find a
     * household's entries by index instead of walking every problem it ever
     * had to collect the children of each.
     */
    home_id: v.id("homes"),
    /** Absent for an entry the app wrote rather than a person. */
    author_id: v.optional(v.id("users")),
    kind: issueEntryKind,
    body: v.optional(v.string()),
    /** Both ends of a status move, so the timeline reads as a sentence. */
    from_status: v.optional(issueStatus),
    to_status: v.optional(issueStatus),
    created: v.number(),
  })
    .index("by_issue", ["issue_id"])
    .index("by_home", ["home_id"]),
});
