# Graph Report - NestZone  (2026-09-18)

## Corpus Check
- 226 files · ~494,547 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 5565 nodes · 11859 edges · 262 communities (250 shown, 12 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 405 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `69c1f45a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- What-To-Watch Voting
- Localization Strings
- Model Coding Keys
- Confetti & Realtime Models
- Movie API (TMDb)
- Recipe Theming
- Movie List Model
- Realtime Event Manager
- Movie UI Components
- Polls Manager
- DTO Coding Keys
- Movie Lists Manager
- Messages View
- PocketBase Networking
- Home Tab ViewModel
- Home Creation & Tasks
- New Recipe Sheet
- Shopping List UI
- Sample Recipes
- Management Tab ViewModel
- Notes ViewModel
- Unit & UI Tests
- Match & Poll Summary
- Messages Manager
- Home Tab Screen
- PocketBase Models
- Movie Detail Sheet
- Cooking Mode
- Poll Type Selection
- List & Difficulty Enums
- Movie List Detail
- Note Color Extensions
- Community 32
- Community 33
- Community 34
- Community 35
- Auth Manager
- Expense & Item Models
- Premium Text Field
- Simple Movie Detail
- Community 40
- App Services Core
- PocketBase Polls Schema
- Chat Detail
- Movie Search Row
- No-Homes Onboarding
- Community 46
- New Message Group
- Poll Input Sheets
- Previous Polls
- Theme Selection
- Recipe List View
- Read Receipts
- Note Creator
- Community 54
- Swipe Deck
- Home Selection View
- Switch Home Sheet
- Genre Picker
- Swipe Card
- Recipe Card
- Chat Messages List
- Edit Note Sheet
- Auth DTOs
- Community 64
- Community 65
- Loading Button
- Preset List Card
- Search Results List
- Language Selection
- Match Options Sheet
- Vibrant Module Card
- Chat Header
- Message Input
- Community 74
- Community 75
- Custom List Row
- Overlay Views
- Message Hashing
- Management Tab Screen
- Community 80
- Note Card
- Community 82
- Community 83
- Create Movie List
- Community 85
- Community 86
- Notes View
- Task Priority
- Bungalaven App Icon
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101
- Community 102
- Community 103
- Community 104
- Community 105
- Community 106
- Community 107
- Community 108
- Community 109
- Community 110
- Community 111
- Community 112
- Community 113
- Community 114
- Community 115
- Community 116
- Community 117
- Community 118
- Community 119
- Community 120
- Community 121
- Community 122
- Community 123
- Community 124
- Community 125
- Community 126
- Community 127
- Community 128
- Community 129
- Community 130
- Community 131
- Community 132
- Community 133
- Community 134
- Community 135
- Community 136
- Community 137
- Community 138
- Community 139
- Community 140
- Community 141
- Community 142
- Community 143
- Community 144
- Community 145
- Community 146
- Community 147
- Community 148
- Community 149
- State
- SectionHeader
- Community 152
- Community 153
- Alert
- Community 155
- Community 156
- Community 157
- Community 158
- Community 159
- RecipeDetailFeature
- Community 161
- Community 162
- Community 163
- SettingsView
- HomeStats
- Delegate
- Cache
- auth.config.ts
- schema.ts
- README.md
- State
- HomeView
- Action
- MainFeature
- Recipe
- SpendCategory
- Kind
- MainFeature
- KeyboardDismisser
- Action
- TaskEdit
- HomesClient
- ManageHomesFeature.swift
- State
- FinanceFeature
- Community 186
- .send
- recipes.ts
- Community 189
- State
- Delegate
- Community 192
- ConfirmationDialogState
- CalendarView
- Cuisine
- Action
- Community 197
- crons.ts
- ChoiceCard
- NewShoppingItem
- CoreLogicTests
- CancelID
- StatTile
- AuthFeature.swift
- Community 205
- CoreLogicTests
- IssuesFeature
- PollsClient
- Urgency
- Delegate
- AvatarPickerFace
- Source
- CancelID
- Delegate
- CancelID
- UndoToast
- IssueComposerFeature
- InboxAdminFeature
- Community 219
- CancelID
- Community 221
- Alert
- Community 223
- Community 224
- .alert
- HomeStats
- AppSettings.swift
- Community 228
- FinanceFeature
- Self
- StepDuration
- Community 232
- PasteboardClient
- Community 234
- Community 235
- Community 236
- AvatarSourceSheet
- AvatarViewerBar
- CancelID
- Community 240
- Community 241
- Community 242
- Alert
- Community 245
- IssueComposerFeature
- CancelID
- .newestFirst
- MovieList.Kind
- ci_post_clone.sh
- Community 258
- Community 259
- Community 263
- Community 267
- Community 270
- Community 271
- Community 273
- Community 279
- Community 281
- Community 292

## God Nodes (most connected - your core abstractions)
1. `L10n` - 176 edges
2. `Timestamp` - 104 edges
3. `Foundation` - 90 edges
4. `SwiftUI` - 89 edges
5. `AppError` - 85 edges
6. `ComposableArchitecture` - 82 edges
7. `User` - 82 edges
8. `CodingKeys` - 79 edges
9. `Date` - 76 edges
10. `Color` - 71 edges

## Surprising Connections (you probably didn't know these)
- `MovieHandoffTests` --calls--> `MovieList`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Movie.swift
- `MovieHandoffTests` --calls--> `PollItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Poll.swift
- `ShoppingTests` --calls--> `ShoppingItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/ShoppingItem.swift
- `CalendarFeatureTests` --references--> `CalendarDay`  [EXTRACTED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/CalendarEvent.swift
- `EventPlanTests` --calls--> `EventOccurrence`  [EXTRACTED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/CalendarEvent.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Generic polls data model (polls, items, votes scoped to homes)** — docs_pocketbase_readme_polls, docs_pocketbase_readme_poll_items, docs_pocketbase_readme_poll_votes, docs_pocketbase_readme_homes [EXTRACTED 1.00]

## Communities (262 total, 12 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.07
Nodes (34): ContentMode, CryptoKit, KeyedDecodingContainer, Int, T, ImageDiskCache, CGFloat, String (+26 more)

### Community 1 - "Localization Strings"
Cohesion: 0.26
Nodes (4): DependencyValues, CalendarFeatureTests, Double, Void

### Community 2 - "Model Coding Keys"
Cohesion: 0.08
Nodes (25): Action, alert, binding, contributionsUpdated, loadFailed, task, Alert, CancelID (+17 more)

### Community 3 - "Confetti & Realtime Models"
Cohesion: 0.03
Nodes (76): CodingKeys, ageDays, amount, area, assignedTo, authorID, blockedReason, body (+68 more)

### Community 4 - "Movie API (TMDb)"
Cohesion: 0.12
Nodes (15): AvatarCrop, CGFloat, CGRect, CGSize, Self, AvatarCropSheet, AccessibilityAdjustmentDirection, CGFloat (+7 more)

### Community 5 - "Recipe Theming"
Cohesion: 0.06
Nodes (4): L10n, Int, Locale, StaticString

### Community 6 - "Movie List Model"
Cohesion: 0.03
Nodes (65): CodingKeys, amount, autoSplit, billID, budget, budgets, categories, category (+57 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.09
Nodes (23): AuthProvider, CheckedContinuation, ConvexClient, escaping, LocalizedError, AsyncSemaphore, ConvexAppleAuthProvider, ConvexAuthError (+15 more)

### Community 9 - "Polls Manager"
Cohesion: 0.14
Nodes (13): Footer, Palette, StickyColor, blue, green, orange, pink, purple (+5 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.09
Nodes (33): ActivityCategory, calendar, finance, home, issues, meals, messages, movies (+25 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.04
Nodes (52): CodingKeys, amount, attendees, budget, category, cookTime, created, createdBy (+44 more)

### Community 12 - "Messages View"
Cohesion: 0.05
Nodes (40): Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped, conversationsUpdated (+32 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.04
Nodes (51): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+43 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.07
Nodes (36): assertParticipant(), create, listByHome, rename, requireDocHome(), requireHomeMember(), requireUser(), assertAuthor() (+28 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.17
Nodes (11): BindableAction, Action, binding, failed, finished, submitTapped, succeeded, State (+3 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.05
Nodes (43): Action, addPartsTapped, alert, assignFailed, assignTapped, binding, confirm, delegate (+35 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.05
Nodes (33): addParts, assign, attachPhotos, byHome, comment, create, detail, EntryKind (+25 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.12
Nodes (8): NestZone, SettingsFeature, PhotoUpload, PushRegistrationTests, SettingsAvatarTests, SignOutTests, String, Testing

### Community 19 - "Management Tab ViewModel"
Cohesion: 0.19
Nodes (16): Category, cleaning, groceries, household, other, ShoppingItem, Bool, Decoder (+8 more)

### Community 20 - "Notes ViewModel"
Cohesion: 0.33
Nodes (6): CancelID, all, lists, movies, saved, search

### Community 21 - "Unit & UI Tests"
Cohesion: 0.13
Nodes (9): LaunchUITests, Bool, SmokeFlowUITests, String, XCUIApplication, XCUIApplication, TabNavigationUITests, XCTest (+1 more)

### Community 22 - "Match & Poll Summary"
Cohesion: 0.20
Nodes (14): AddedToListToast, ComposeRecipeSheet, CookingModeView, Fact, RecipeCard, RecipeDetailView, RecipesView, Binding (+6 more)

### Community 23 - "Messages Manager"
Cohesion: 0.19
Nodes (12): State, Action, AlertState, Bool, ConfirmationDialogState, IdentifiedArrayOf, Int, Set (+4 more)

### Community 24 - "Home Tab Screen"
Cohesion: 0.06
Nodes (33): addMonths(), billCycle, createBill, createExpense, Cycle, DueNudge, financeCategory, listBills (+25 more)

### Community 25 - "PocketBase Models"
Cohesion: 0.17
Nodes (19): Angle, Command, DeckSkeleton, MovieNightView, PollHistoryRow, PollKindSheet, PollOutcomeView, Bool (+11 more)

### Community 26 - "Movie Detail Sheet"
Cohesion: 0.08
Nodes (24): @auth/core, dependencies, @auth/core, convex, @convex-dev/auth, jose, description, devDependencies (+16 more)

### Community 27 - "Cooking Mode"
Cohesion: 0.10
Nodes (32): Bill, BillCycle, biweekly, monthly, once, quarterly, weekly, yearly (+24 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.07
Nodes (33): addItems, cleanWeekdays(), collect(), create, detail, EventDoc, eventKind, EventNudge (+25 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.06
Nodes (81): Codable, Hashable, Identifiable, AreaCount, CategoryCount, HouseIssue, IssueArea, balcony (+73 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.05
Nodes (41): Action, alert, avatarRemoved, avatarSelected, avatarUpdated, avatarUpdateFailed, binding, checkForUpdatesTapped (+33 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.18
Nodes (13): Poll, PollDetail, PollItem, PollOutcome, Result, agreed, closest, nothing (+5 more)

### Community 32 - "Community 32"
Cohesion: 0.20
Nodes (18): HouseHealthRing, IssueArea, IssueCategory, IssuePhotoStrip, IssueSeverity, IssueStatus, MeTooButton, RoomTile (+10 more)

### Community 33 - "Community 33"
Cohesion: 0.06
Nodes (34): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+26 more)

### Community 34 - "Community 34"
Cohesion: 0.16
Nodes (10): RelativeTime, RelativeTimeClock, Duration, Int, Never, Task, Text, Void (+2 more)

### Community 35 - "Community 35"
Cohesion: 0.04
Nodes (37): AvatarInitials, CGFloat, String, AvatarPickerFace, Bool, CGFloat, String, UIImage (+29 more)

### Community 36 - "Auth Manager"
Cohesion: 0.06
Nodes (34): Action, addTapped, advanceTapped, alert, areaFilterTapped, binding, boardUpdated, categoryFilterTapped (+26 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.06
Nodes (31): accounts, activity, activityCategories, allUpdates, anyAdminId(), badge, cachedReleaseCheck, countsAsUnread() (+23 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.05
Nodes (40): EventScope, occurrence, series, Action, addOnDayTapped, addTapped, alert, binding (+32 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.06
Nodes (33): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+25 more)

### Community 40 - "Community 40"
Cohesion: 0.07
Nodes (42): AppView, LaunchView, MainView, OfflineView, StoreOf, Void, AlreadyDecidedBanner, CuisineTile (+34 more)

### Community 41 - "App Services Core"
Cohesion: 0.12
Nodes (22): AnyCancellable, Combine, ConvexClientWithAuth, async, String, UsersClient, ArgumentBox, CancellableBox (+14 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.08
Nodes (39): CaseIterable, ContributionDay, ContributionSlice, ContributionWindow, allTime, month, week, Count (+31 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.06
Nodes (32): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+24 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.09
Nodes (19): Error, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline, server (+11 more)

### Community 46 - "Community 46"
Cohesion: 0.12
Nodes (18): Alert, confirmEndRound, CancelID, detail, polls, recipes, Delegate, finished (+10 more)

### Community 47 - "New Message Group"
Cohesion: 0.12
Nodes (17): members, State, Action, AlertState, Bill, BillID, Bool, Destination (+9 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.25
Nodes (5): LockIsolated, Message, Kind, ChatFeature, MessagesTests

### Community 49 - "Previous Polls"
Cohesion: 0.06
Nodes (31): Action, addMoviesTapped, addTapped, alert, allMoviesUpdated, binding, createListTapped, deleteListTapped (+23 more)

### Community 50 - "Theme Selection"
Cohesion: 0.05
Nodes (37): Action, home, homePath, hub, inbox, messages, notes, settings (+29 more)

### Community 51 - "Recipe List View"
Cohesion: 0.11
Nodes (27): EventPlan, EventRSVP, Frequency, daily, monthly, weekly, yearly, LinkedExpense (+19 more)

### Community 52 - "Read Receipts"
Cohesion: 0.05
Nodes (47): CodingKeys, canRestore, completedAt, email, id, kind, name, taskID (+39 more)

### Community 53 - "Note Creator"
Cohesion: 0.07
Nodes (30): Action, addExpenseTapped, addItemTapped, alert, binding, bulkAddFinished, delegate, deleteTapped (+22 more)

### Community 54 - "Community 54"
Cohesion: 0.06
Nodes (36): Action, activityFailed, activityUpdated, admin, adminTapped, alert, badgeFailed, badgeUpdated (+28 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.07
Nodes (30): CodingKeys, activity, activityFloor, activityReadAt, actor, actorName, body, cap (+22 more)

### Community 56 - "Home Selection View"
Cohesion: 0.25
Nodes (7): ContributionsView, MemberRow, Bool, Double, Int, StoreOf, String

### Community 57 - "Switch Home Sheet"
Cohesion: 0.06
Nodes (38): Action, alert, archiveTapped, binding, composeTapped, delegate, deleteFinishedFailed, deleteTapped (+30 more)

### Community 58 - "Genre Picker"
Cohesion: 0.26
Nodes (11): DependencyValues, DinnerDecision, MealsClient, async, Cuisine, Error, EventID, HomeID (+3 more)

### Community 59 - "Swipe Card"
Cohesion: 0.10
Nodes (23): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+15 more)

### Community 60 - "Recipe Card"
Cohesion: 0.05
Nodes (43): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+35 more)

### Community 61 - "Chat Messages List"
Cohesion: 0.42
Nodes (8): ButtonRole, IconButton, PrimaryButton, SecondaryButton, Bool, LocalizedStringResource, String, Void

### Community 62 - "Edit Note Sheet"
Cohesion: 0.08
Nodes (26): Action, alert, clearDinnerTapped, decideDinnerTapped, delegate, dinner, dinnerSuggestionAccepted, dinnerSuggestionSaved (+18 more)

### Community 63 - "Auth DTOs"
Cohesion: 0.11
Nodes (17): compilerOptions, allowJs, esModuleInterop, isolatedModules, lib, module, moduleResolution, noEmit (+9 more)

### Community 64 - "Community 64"
Cohesion: 0.25
Nodes (12): createRecipe(), DependencyValues, NewRecipe, RecipesClient, async, Bool, Error, HomeID (+4 more)

### Community 65 - "Community 65"
Cohesion: 0.18
Nodes (6): AlertState, DinnerFeature, ReducerOf, Self, DinnerTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.11
Nodes (22): checkedRecipes(), cascadeDeleteConversation(), cascadeDeleteHome(), cascadeDeleteMovieList(), cascadeDeletePoll(), requireMembers(), requireRef(), requireSameHome() (+14 more)

### Community 67 - "Preset List Card"
Cohesion: 0.22
Nodes (6): HubFeature, Duration, ReducerOf, Self, HubCountsTests, HubNavigationTests

### Community 68 - "Search Results List"
Cohesion: 0.11
Nodes (22): Equatable, Alert, CalendarFeature.Destination.State, Alert, confirmDelete, ComposeTaskFeature, Delegate, openArchive (+14 more)

### Community 69 - "Language Selection"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 71 - "Vibrant Module Card"
Cohesion: 0.15
Nodes (12): AsyncThrowingStream, DependencyValues, EventsClient, StockUpResult, async, Error, EventID, HomeID (+4 more)

### Community 72 - "Chat Header"
Cohesion: 0.16
Nodes (13): State, StepTimer, Action, AlertState, Bool, Destination, Double, HomeID (+5 more)

### Community 73 - "Message Input"
Cohesion: 0.12
Nodes (24): CastMember, Kind, custom, watched, wishlist, Movie, MovieExtras, StoredMovie (+16 more)

### Community 74 - "Community 74"
Cohesion: 0.10
Nodes (19): AnyShapeStyle, PlanSection, budget, menu, shopping, tickets, AddItemField, DisclosureRow (+11 more)

### Community 75 - "Community 75"
Cohesion: 0.05
Nodes (44): Action, alert, binding, cancelTapped, composer, delegate, deleteTapped, editTapped (+36 more)

### Community 76 - "Custom List Row"
Cohesion: 0.05
Nodes (36): CustomStringConvertible, ExpressibleByStringLiteral, AppUpdate, AppVersion, Bool, Int, String, UpdateAvailability (+28 more)

### Community 77 - "Overlay Views"
Cohesion: 0.18
Nodes (6): AvatarPhoto, CGFloat, Data, Int, UIImage, AvatarPhotoTests

### Community 78 - "Message Hashing"
Cohesion: 0.11
Nodes (16): Alert, CancelID, conversations, messages, Delegate, renamed, Destination, compose (+8 more)

### Community 79 - "Management Tab Screen"
Cohesion: 0.11
Nodes (22): Anchor, BubbleActionsAnchor, BubbleActionsAnchorKey, ChatView, ConversationRow, MessageActionsBar, MessageBubble, MessagesView (+14 more)

### Community 80 - "Community 80"
Cohesion: 0.12
Nodes (14): FALSY, openTasks(), outstandingItems(), outstandingNames(), category, create, createFromRecipe, listByHome (+6 more)

### Community 81 - "Note Card"
Cohesion: 0.11
Nodes (15): Binding, Bool, CGFloat, Content, Gesture, LocalizedStringResource, Void, SwipeToDelete (+7 more)

### Community 82 - "Community 82"
Cohesion: 0.13
Nodes (16): create, ensurePresetLists, get, join, leave, listMine, members, PRESET_LISTS (+8 more)

### Community 83 - "Community 83"
Cohesion: 0.11
Nodes (19): CodingKeys, created, entityType, externalID, genre, homeID, id, isYes (+11 more)

### Community 84 - "Create Movie List"
Cohesion: 0.11
Nodes (17): 1. Where the codebase actually stands, 2. Who is the subscriber?, 3. The seams, 4. The rule that makes it tractable, 5. Which features should be premium, 6. What to build before deciding any of it, 7. Open questions, Calendar ↔ Shopping and Recipes (+9 more)

### Community 85 - "Community 85"
Cohesion: 0.15
Nodes (16): Conversation, Kind, audio, document, gif, image, system, text (+8 more)

### Community 86 - "Community 86"
Cohesion: 0.11
Nodes (19): Action, alert, authorsResolved, binding, colorSelected, composeTapped, deleteFailed, deleteTapped (+11 more)

### Community 87 - "Notes View"
Cohesion: 0.23
Nodes (9): content, GlassCard, GlassGroup, Metrics, Bool, CGFloat, Content, View (+1 more)

### Community 88 - "Task Priority"
Cohesion: 0.18
Nodes (16): CategoryHeader, Folds, GroupHeader, GroupMenu, ShoppingRow, ShoppingView, Bool, EdgeInsets (+8 more)

### Community 90 - "Community 90"
Cohesion: 0.11
Nodes (18): CodingKeys, category, created, createdBy, details, eventID, eventTitle, homeID (+10 more)

### Community 91 - "Community 91"
Cohesion: 0.22
Nodes (12): AvatarPickerButton, Editing, Handover, Bool, CGFloat, Data, PhotosPickerItem, PhotoUpload (+4 more)

### Community 92 - "Community 92"
Cohesion: 0.23
Nodes (7): AvatarDirectory, String, URL, AvatarEntry, String, URL, AvatarDirectoryTests

### Community 93 - "Community 93"
Cohesion: 0.07
Nodes (36): Animatable, Configuration, GeometryEffect, IntegerFormatStyle, EnvironmentValues, GlassList, GlassListRow, GlassListStyle (+28 more)

### Community 94 - "Community 94"
Cohesion: 0.11
Nodes (18): MovieGenre, adventure, animation, comedy, crime, documentary, drama, family (+10 more)

### Community 95 - "Community 95"
Cohesion: 0.12
Nodes (19): Badge, Chip, Bool, String, Void, IssueComposerSheet, IssueInlineError, IssueSheetToolbar (+11 more)

### Community 96 - "Community 96"
Cohesion: 0.09
Nodes (27): CodingKeys, cookTime, created, createdBy, difficulty, homeID, id, image (+19 more)

### Community 97 - "Community 97"
Cohesion: 0.12
Nodes (12): archive, backfillCompletions, create, listByHome, priority, recordCompletion(), remove, removeFinished (+4 more)

### Community 98 - "Community 98"
Cohesion: 0.17
Nodes (15): Expense, ExpenseSplit, ExpenseWeight, NewExpense, NewSettlement, SplitMode, equal, exact (+7 more)

### Community 99 - "Community 99"
Cohesion: 0.12
Nodes (17): CodingKeys, assignedTo, completedBy, created, createdBy, details, dueDate, homeID (+9 more)

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (5): ⚠️ Auth caveat (the one real gotcha), Nestzone — PocketBase → Convex migration, Steps, Type/field mapping applied, What's here

### Community 101 - "Community 101"
Cohesion: 0.10
Nodes (20): GlassTextField, Binding, Bool, LocalizedStringResource, String, SectionHeader, LocalizedStringResource, String (+12 more)

### Community 102 - "Community 102"
Cohesion: 0.18
Nodes (15): Kind, generic, movie, recipe, PollVote, Status, active, closed (+7 more)

### Community 103 - "Community 103"
Cohesion: 0.27
Nodes (10): ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat, Double (+2 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.07
Nodes (38): Comparable, CalendarDay, EventOccurrence, Calendar, Int, Self, CalendarMonth, MonthGrid (+30 more)

### Community 106 - "Community 106"
Cohesion: 0.16
Nodes (12): Alert, confirmDelete, AlertState, CancelID, notes, ComposeNoteFeature, Destination, compose (+4 more)

### Community 107 - "Community 107"
Cohesion: 0.14
Nodes (14): Alert, confirmDeleteList, AlertState, CreateMovieListFeature, Destination, createList, list, MovieListFeature (+6 more)

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (12): ImageIO, PhotoCompressionPlan, Bool, CGFloat, Int, PhotoCompressor, Bool, CGFloat (+4 more)

### Community 109 - "Community 109"
Cohesion: 0.09
Nodes (29): MealPlanID, Cuisine, american, chinese, indian, italian, japanese, korean (+21 more)

### Community 110 - "Community 110"
Cohesion: 0.11
Nodes (17): Action, appEnteredForeground, auth, authStatusChanged, currentUserChanged, deviceRegistered, deviceRegistrationFailed, deviceTokenReceived (+9 more)

### Community 111 - "Community 111"
Cohesion: 0.13
Nodes (14): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Cleanup done in the same pass (2026‑09‑10), Data cleanup + indexing (2026‑09‑03, deployed), Host move (2026‑09‑10): zeynepmakine → instance‑20260910‑1151, NestZone backend — Convex deploy & data‑import runbook, Not errors, despite looking like one, Notes (+6 more)

### Community 112 - "Community 112"
Cohesion: 0.25
Nodes (9): bold(), die(), info(), run(), set_build_number(), set_marketing_version(), deploy.sh script, step() (+1 more)

### Community 113 - "Community 113"
Cohesion: 0.26
Nodes (8): Note, Decoder, HomeID, NoteID, String, UserID, NotesFeature, NotesTests

### Community 114 - "Community 114"
Cohesion: 0.15
Nodes (15): CatalogQuery, Kind, actor, decade, director, genre, nowPlaying, popular (+7 more)

### Community 115 - "Community 115"
Cohesion: 0.22
Nodes (4): BillComposerTests, ExpenseComposerTests, Bill, IdentifiedArrayOf

### Community 116 - "Community 116"
Cohesion: 0.13
Nodes (15): CodingKeys, conversationID, created, file, homeID, id, isGroupChat, kind (+7 more)

### Community 117 - "Community 117"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 118 - "Community 118"
Cohesion: 0.25
Nodes (8): Backend notes, Commands, Conventions, graphify, Layout, NestZone, One deployment, every app version, Shipping a change

### Community 119 - "Community 119"
Cohesion: 0.16
Nodes (12): MovieList, Kind, State, Action, AlertState, Bool, Destination, HomeID (+4 more)

### Community 120 - "Community 120"
Cohesion: 0.08
Nodes (32): IssueEdit, IssuePhotoUpload, PhotoUpload, Action, areaTapped, assigneeTapped, binding, categoryTapped (+24 more)

### Community 121 - "Community 121"
Cohesion: 0.33
Nodes (6): CodingKey, CodingKeys, changelogVersion, checkedAt, storeUrl, storeVersion

### Community 122 - "Community 122"
Cohesion: 0.29
Nodes (7): PartsDraft, StatusNote, Bool, Effect, IssueStatus, LocalizedStringResource, String

### Community 123 - "Community 123"
Cohesion: 0.19
Nodes (12): State, Action, Bool, ConfirmationDialogState, Effect, HomeID, IdentifiedArrayOf, Int (+4 more)

### Community 124 - "Community 124"
Cohesion: 0.11
Nodes (13): HomeFeature, ReducerOf, HomeView, StoreOf, ShoppingFeature, Duration, ReducerOf, HomeFeatureTests (+5 more)

### Community 125 - "Community 125"
Cohesion: 0.12
Nodes (7): Decimal, Money, Settlement, Set, String, FinanceLogicTests, SettlementID

### Community 126 - "Community 126"
Cohesion: 0.13
Nodes (15): Delegate, notificationsEnabled, openCalendar, openContributions, openEvent, openEventID, openIssues, openMessages (+7 more)

### Community 127 - "Community 127"
Cohesion: 0.15
Nodes (15): State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Int, IssueArea (+7 more)

### Community 128 - "Community 128"
Cohesion: 0.07
Nodes (39): BillCycle, Action, alert, binding, delegate, deleteTapped, everyoneTapped, failed (+31 more)

### Community 129 - "Community 129"
Cohesion: 0.15
Nodes (13): Budget, SpendCategory, dining, entertainment, groceries, health, household, other (+5 more)

### Community 130 - "Community 130"
Cohesion: 0.18
Nodes (19): BillRow, BudgetCard, DayHeader, EventSpendRow, ExpenseRow, FinanceView, PayerRow, RepairSpendRow (+11 more)

### Community 131 - "Community 131"
Cohesion: 0.12
Nodes (16): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+8 more)

### Community 132 - "Community 132"
Cohesion: 0.18
Nodes (14): activityArgs(), DependencyValues, InboxClient, ReleaseCheck, AppUpdate, AppUpdateID, async, ConvexEncodable (+6 more)

### Community 133 - "Community 133"
Cohesion: 0.22
Nodes (9): DependencyValues, MessagesClient, async, ConversationID, Error, HomeID, Int, MessageID (+1 more)

### Community 134 - "Community 134"
Cohesion: 0.13
Nodes (15): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+7 more)

### Community 135 - "Community 135"
Cohesion: 0.33
Nodes (8): Avatar, Source, directory, photo, Bool, CGFloat, String, URL

### Community 136 - "Community 136"
Cohesion: 0.25
Nodes (4): AvatarCropTests, PhotoZoomTests, CGFloat, CGSize

### Community 137 - "Community 137"
Cohesion: 0.29
Nodes (4): ContributionsFeature, ReducerOf, Self, ContributionsFeatureTests

### Community 138 - "Community 138"
Cohesion: 0.25
Nodes (9): Layout, FlowLayout, Row, CGFloat, CGRect, CGSize, Int, ProposedViewSize (+1 more)

### Community 139 - "Community 139"
Cohesion: 0.10
Nodes (24): ColorScheme, Control, Glass, GlassListLab, LabRow, LabSurface, Model, SpacingSample (+16 more)

### Community 140 - "Community 140"
Cohesion: 0.32
Nodes (8): Cache, Recipe, SampleRecipe, SampleRecipeLoader, Bool, Int, Recipe, String

### Community 141 - "Community 141"
Cohesion: 0.16
Nodes (15): IssuesFeature, Duration, Effect, ReducerOf, Self, IssueRow, IssuesView, RowBadge (+7 more)

### Community 142 - "Community 142"
Cohesion: 0.15
Nodes (18): ClearTarget, category, event, issue, meal, purchased, State, Action (+10 more)

### Community 143 - "Community 143"
Cohesion: 0.06
Nodes (34): Color, String, Backdrop, StatTile, Int, LocalizedStringResource, String, Void (+26 more)

### Community 144 - "Community 144"
Cohesion: 0.17
Nodes (14): PlanRow, PlanState, active, done, empty, Bool, Double, LocalizedStringResource (+6 more)

### Community 145 - "Community 145"
Cohesion: 0.21
Nodes (11): apiKey(), details, discover, fetchJSON(), fetchPages(), GENRE_NAMES, GENRES, TMDbCredit (+3 more)

### Community 146 - "Community 146"
Cohesion: 0.07
Nodes (24): AppFeature, ReducerOf, Self, CodingKeys, address, created, id, inviteCode (+16 more)

### Community 147 - "Community 147"
Cohesion: 0.15
Nodes (16): AddMoviesSheet, CreateMovieListSheet, ListChip, ListRow, MovieInfoSheet, MoviesView, PosterCard, Bool (+8 more)

### Community 148 - "Community 148"
Cohesion: 0.15
Nodes (13): CodingKeys, cleaning, completed, count, email, general, maintenance, name (+5 more)

### Community 149 - "Community 149"
Cohesion: 0.29
Nodes (4): DecodingTests, Data, UserID, UserDecodingTests

### Community 150 - "State"
Cohesion: 0.14
Nodes (10): AvatarSubject, String, URL, AvatarViewer, AccessibilityAdjustmentDirection, CGFloat, CGSize, Double (+2 more)

### Community 151 - "SectionHeader"
Cohesion: 0.23
Nodes (17): Encodable, billArgs(), DependencyValues, expenseArgs(), ExpenseShareArgs, ExpenseWeightArgs, FinanceClient, monthArgs() (+9 more)

### Community 152 - "Community 152"
Cohesion: 0.15
Nodes (13): CodingKeys, created, cuisine, date, event, homeID, id, kind (+5 more)

### Community 153 - "Community 153"
Cohesion: 0.13
Nodes (17): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+9 more)

### Community 154 - "Alert"
Cohesion: 0.39
Nodes (5): PhotoZoom, Bool, CGFloat, CGSize, Self

### Community 155 - "Community 155"
Cohesion: 0.24
Nodes (5): HomeManagementFeature, ReducerOf, HomeManagementView, StoreOf, HomeManagementTests

### Community 156 - "Community 156"
Cohesion: 0.21
Nodes (10): CreateHomeFeature, JoinHomeFeature, ReducerOf, Self, Destination, create, join, Destination (+2 more)

### Community 157 - "Community 157"
Cohesion: 0.22
Nodes (8): Alert, CancelID, plan, Scope, deleteAll, deleteThisOne, editAll, editThisOne

### Community 158 - "Community 158"
Cohesion: 0.17
Nodes (10): CurrencyDefaults, Shared<String?>, SharedKey, HomeID, Self, String, CurrencyPicker, Bool (+2 more)

### Community 159 - "Community 159"
Cohesion: 0.21
Nodes (14): DayCell, DayTimeline, EventRow, Placed, PlanRing, Bool, CGFloat, ClosedRange (+6 more)

### Community 160 - "RecipeDetailFeature"
Cohesion: 0.32
Nodes (6): ComposeTaskSheet, StoreOf, String, Void, TaskListRow, TasksView

### Community 161 - "Community 161"
Cohesion: 0.25
Nodes (7): Alert, CancelID, badge, categories, feed, Delegate, open

### Community 162 - "Community 162"
Cohesion: 0.29
Nodes (6): Deprecations, Is it safe to remove yet?, Notes on what is already here, Row format, The register, What that means in practice

### Community 163 - "Community 163"
Cohesion: 0.23
Nodes (5): ManageHomesFeature, ReducerOf, Self, ManageHomesTests, SettingsHomeTests

### Community 164 - "SettingsView"
Cohesion: 0.12
Nodes (15): Alert, confirmSignOut, AlertState, Destination, editName, manageHomes, EditNameFeature, SettingsFeature.Destination.State (+7 more)

### Community 165 - "HomeStats"
Cohesion: 0.07
Nodes (26): Alert, confirmDelete, AlertState, BillComposerFeature, BudgetEditorFeature, Delegate, deleted, deleteRequested (+18 more)

### Community 166 - "Delegate"
Cohesion: 0.22
Nodes (8): AlertState, CancelID, items, undo, ShoppingItem.Category, LocalizedStringResource, Self, String

### Community 167 - "Cache"
Cohesion: 0.15
Nodes (12): Actions, `ci_scripts/` — why the first builds failed, Did it work?, Environment, Finally, Post-Actions, Start Conditions, The division of labour (+4 more)

### Community 168 - "auth.config.ts"
Cohesion: 0.17
Nodes (11): parts, PollCandidate, ConvexEncodable, String, Cuisine, DinnerCandidate, Kind, cuisine (+3 more)

### Community 169 - "schema.ts"
Cohesion: 0.17
Nodes (11): Alert, CancelID, detail, Confirm, delete, Delegate, deleteRequested, openEvent (+3 more)

### Community 170 - "README.md"
Cohesion: 0.18
Nodes (10): eventKind, financeCategory, issueArea, issueCategory, issueEntryKind, issueSeverity, issueStatus, recurrence (+2 more)

### Community 171 - "State"
Cohesion: 0.25
Nodes (8): ArraySlice, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Loaded

### Community 172 - "HomeView"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 173 - "Action"
Cohesion: 0.18
Nodes (11): CodingKeys, issuesChange, messagesChange, notes, notesChange, openIssues, openTasks, shoppingChange (+3 more)

### Community 174 - "MainFeature"
Cohesion: 0.18
Nodes (10): Alert, enableNotifications, AlertState, CancelID, events, meals, members, stats (+2 more)

### Community 176 - "SpendCategory"
Cohesion: 0.20
Nodes (7): Data, Error, Any, Bool, Data, Error, UIApplication

### Community 177 - "Kind"
Cohesion: 0.16
Nodes (13): Alert, confirmLeave, Delegate, dismissRequested, switchRequested, ManageHomesFeature.Destination.State, State, Action (+5 more)

### Community 178 - "MainFeature"
Cohesion: 0.19
Nodes (10): rows, State, Action, AlertState, AppUpdate, Bool, HomeID, IdentifiedArrayOf (+2 more)

### Community 179 - "KeyboardDismisser"
Cohesion: 0.21
Nodes (10): State, Action, AlertState, Bool, Cuisine, HomeID, IdentifiedArrayOf, Int (+2 more)

### Community 180 - "Action"
Cohesion: 0.50
Nodes (6): NewShoppingItem, RecipeIngredients, Double, HomeID, RecipeID, String

### Community 181 - "TaskEdit"
Cohesion: 0.10
Nodes (30): CGPoint, Arc, BalanceBars, Bill, Bill.Urgency, BillCycle, BudgetProgress.Health, BudgetRing (+22 more)

### Community 182 - "HomesClient"
Cohesion: 0.17
Nodes (11): Context, CameraPicker, Coordinator, Any, Bool, Data, Void, UIImagePickerController (+3 more)

### Community 183 - "ManageHomesFeature.swift"
Cohesion: 0.10
Nodes (21): Alert, confirmDelete, confirmEndRound, AlertState, CancelID, detail, polls, Destination (+13 more)

### Community 184 - "State"
Cohesion: 0.20
Nodes (10): Field, CreateHomeSheet, FormSheet, JoinHomeSheet, Bool, Int, LocalizedStringResource, StoreOf (+2 more)

### Community 185 - "FinanceFeature"
Cohesion: 0.14
Nodes (9): AlertState, ComposeRecipeFeature, RecipeDetailFeature, RecipesFeature, ReducerOf, Self, RecipeShoppingTests, SavedRecipeTests (+1 more)

### Community 186 - "Community 186"
Cohesion: 0.24
Nodes (11): DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Int, String, UNAuthorizationStatus (+3 more)

### Community 187 - ".send"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 188 - "recipes.ts"
Cohesion: 0.21
Nodes (11): Action, countsUpdated, moduleTapped, path, showShoppingList, task, HubFeature.Path.State, IssueCounts (+3 more)

### Community 189 - "Community 189"
Cohesion: 0.42
Nodes (7): NewTask, Bool, ConvexEncodable, HomeID, String, UserID, TaskEdit

### Community 190 - "State"
Cohesion: 0.33
Nodes (4): IssuePhoto, Data, UIImage, IssuePhotoTests

### Community 191 - "Delegate"
Cohesion: 0.25
Nodes (6): HubView, ModuleTile, Bool, Int, StoreOf, Void

### Community 192 - "Community 192"
Cohesion: 0.10
Nodes (13): CoreGraphics, Foundation, DependencyValues, StatsClient, Error, HomeID, IssuePhotoIDs, String (+5 more)

### Community 193 - "ConfirmationDialogState"
Cohesion: 0.32
Nodes (5): Animation, EditNameSheet, SettingsView, StoreOf, String

### Community 194 - "CalendarView"
Cohesion: 0.09
Nodes (19): ASAuthorization, Action, alert, appleSignInFailed, appleSignInSucceeded, signInFailed, signInSucceeded, Alert (+11 more)

### Community 195 - "Cuisine"
Cohesion: 0.40
Nodes (4): Void, UNNotification, UNNotificationPresentationOptions, UNUserNotificationCenter

### Community 197 - "Community 197"
Cohesion: 0.13
Nodes (13): Screen, choosingHome, launching, main, offline, signedOut, State, PushRegistration (+5 more)

### Community 198 - "crons.ts"
Cohesion: 0.33
Nodes (5): Decodable, PushResult, Int, Discarded, Decoder

### Community 199 - "ChoiceCard"
Cohesion: 0.33
Nodes (6): ChoiceCard, HomeRow, Bool, LocalizedStringResource, String, Void

### Community 200 - "NewShoppingItem"
Cohesion: 0.22
Nodes (6): CancelID, recipes, ConfirmationDialogState, RecipePickerFeature, ReducerOf, Self

### Community 202 - "CancelID"
Cohesion: 0.25
Nodes (9): State, Action, AlertState, ConfirmationDialogState, HomeID, IdentifiedArrayOf, Int, URL (+1 more)

### Community 203 - "StatTile"
Cohesion: 0.24
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 204 - "AuthFeature.swift"
Cohesion: 0.35
Nodes (3): ContributionsMathTests, Int, String

### Community 205 - "Community 205"
Cohesion: 0.32
Nodes (6): IssueDetailFeature, ReducerOf, Self, IssueDetailView, PhotosPickerItem, StoreOf

### Community 206 - "CoreLogicTests"
Cohesion: 0.20
Nodes (9): CodingKeys, body, color, created, createdBy, homeID, id, image (+1 more)

### Community 207 - "IssuesFeature"
Cohesion: 0.22
Nodes (8): App, AppDelegate, NestZoneApp, View, NSObject, Scene, UIApplicationDelegate, UNUserNotificationCenterDelegate

### Community 208 - "PollsClient"
Cohesion: 0.29
Nodes (7): DependencyValues, PollsClient, async, Error, HomeID, PollID, Void

### Community 209 - "Urgency"
Cohesion: 0.06
Nodes (36): AuthenticationServices, ComposableArchitecture, ConvexMobile, DependencyKey, CatalogClient, DependencyValues, MovieDetails, async (+28 more)

### Community 210 - "Delegate"
Cohesion: 0.22
Nodes (9): HubModule, calendar, finance, maintenance, movies, recipes, shopping, Bool (+1 more)

### Community 211 - "AvatarPickerFace"
Cohesion: 0.31
Nodes (7): ComposeNoteSheet, NoteCard, NotesView, Bool, StoreOf, String, Void

### Community 212 - "Source"
Cohesion: 0.43
Nodes (5): AvatarStack, Member, CGFloat, Int, String

### Community 213 - "CancelID"
Cohesion: 0.33
Nodes (6): CancelID, authState, currentUser, deviceRegistration, deviceToken, foreground

### Community 214 - "Delegate"
Cohesion: 0.15
Nodes (16): Double, AffectedCount, DependencyValues, IssueEdit, IssuesClient, ScheduledVisit, async, ConvexEncodable (+8 more)

### Community 215 - "CancelID"
Cohesion: 0.18
Nodes (10): AppLanguage, english, system, turkish, L10n, Locale, Delegate, homeSwitched (+2 more)

### Community 216 - "UndoToast"
Cohesion: 0.25
Nodes (7): Alert, Delegate, openEvent, openIssue, FinanceFeature.Destination.State, EventID, IssueID

### Community 217 - "IssueComposerFeature"
Cohesion: 0.25
Nodes (8): CancelID, bills, events, handoff, issues, movies, recipes, shopping

### Community 218 - "InboxAdminFeature"
Cohesion: 0.33
Nodes (6): Section, bills, budgets, ledger, overview, LocalizedStringResource

### Community 220 - "CancelID"
Cohesion: 0.29
Nodes (7): Path, calendar, finance, issues, movies, recipes, shopping

### Community 221 - "Community 221"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 222 - "Alert"
Cohesion: 0.11
Nodes (18): CancelID, addConfirmation, meals, saved, shopping, timer, Delegate, openShoppingList (+10 more)

### Community 223 - "Community 223"
Cohesion: 0.33
Nodes (6): Alert, confirmClearCategory, confirmClearEvent, confirmClearMeal, confirmClearParts, confirmClearPurchased

### Community 224 - "Community 224"
Cohesion: 0.10
Nodes (24): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+16 more)

### Community 225 - ".alert"
Cohesion: 0.40
Nodes (5): Delegate, chose, deleted, saved, EventID

### Community 226 - "HomeStats"
Cohesion: 0.50
Nodes (3): HomeStats, Decoder, Int

### Community 227 - "AppSettings.swift"
Cohesion: 0.60
Nodes (3): Seed, RecipeID, String

### Community 228 - "Community 228"
Cohesion: 0.40
Nodes (4): c, http, iv, t0

### Community 229 - "FinanceFeature"
Cohesion: 0.17
Nodes (11): CancelID, bills, budgets, expenses, summary, undo, FinanceFeature, Duration (+3 more)

### Community 230 - "Self"
Cohesion: 0.40
Nodes (5): Scope, deleteAll, deleteThisOne, saveAll, saveThisOne

### Community 231 - "StepDuration"
Cohesion: 0.50
Nodes (4): StepDuration, Int, Regex, Substring

### Community 233 - "PasteboardClient"
Cohesion: 0.60
Nodes (4): State, HomeID, Loaded, UserID

### Community 234 - "Community 234"
Cohesion: 0.50
Nodes (3): client, iv, started

### Community 235 - "Community 235"
Cohesion: 0.15
Nodes (14): pending, path, members, State, Action, AlertState, Bool, Destination (+6 more)

### Community 236 - "Community 236"
Cohesion: 0.40
Nodes (4): CancelID, members, tasks, undo

### Community 237 - "AvatarSourceSheet"
Cohesion: 0.50
Nodes (3): Element, Error, Sendable

### Community 239 - "CancelID"
Cohesion: 0.15
Nodes (11): UserID, Alert, CancelID, board, handoff, members, undo, Delegate (+3 more)

### Community 240 - "Community 240"
Cohesion: 0.67
Nodes (3): Loaded, Int, OptionSet

### Community 243 - "Alert"
Cohesion: 0.67
Nodes (3): Alert, confirmDelete, confirmQuit

### Community 245 - "Community 245"
Cohesion: 0.05
Nodes (46): EventKind, anniversary, appointment, birthday, chore, cinema, concert, deadline (+38 more)

### Community 247 - "IssueComposerFeature"
Cohesion: 0.50
Nodes (3): IssueComposerFeature, ReducerOf, Self

### Community 248 - "CancelID"
Cohesion: 0.50
Nodes (4): CancelID, copyReset, members, pushTokenCopyReset

### Community 250 - "MovieList.Kind"
Cohesion: 0.67
Nodes (3): MovieList.Kind, LocalizedStringResource, String

### Community 258 - "Community 258"
Cohesion: 0.22
Nodes (5): KeyboardDismisser, Bool, UIGestureRecognizer, UIGestureRecognizerDelegate, UITouch

### Community 259 - "Community 259"
Cohesion: 0.32
Nodes (7): AddedCount, DependencyValues, ShoppingClient, async, Error, Int, Void

### Community 263 - "Community 263"
Cohesion: 0.15
Nodes (5): Self, FinanceTests, BillID, ExpenseID, Int

### Community 267 - "Community 267"
Cohesion: 0.60
Nodes (3): AvatarRollback, String, URL

### Community 270 - "Community 270"
Cohesion: 0.08
Nodes (21): ActivityID, Calendar, HomeActivity, UserID, BinaryInteger, Date, Decoder, Double (+13 more)

### Community 271 - "Community 271"
Cohesion: 0.12
Nodes (15): Alert, confirmLeave, AlertState, CancelID, homes, HomeManagementFeature.Destination.State, State, Action (+7 more)

### Community 273 - "Community 273"
Cohesion: 0.36
Nodes (7): Action, EmptyStateView, Action, Bool, LocalizedStringResource, String, Void

### Community 279 - "Community 279"
Cohesion: 0.47
Nodes (4): PhotoUpload, Data, Int, String

### Community 281 - "Community 281"
Cohesion: 0.10
Nodes (16): CodingKeys, avatar, avatarURL, created, email, homeIDs, id, name (+8 more)

### Community 292 - "Community 292"
Cohesion: 0.06
Nodes (33): Action, allDayToggled, attendeeToggled, binding, delegate, deleteTapped, doneTapped, draftItemRemoved (+25 more)

## Knowledge Gaps
- **1849 isolated node(s):** `id`, `targets`, `launching`, `signedOut`, `offline` (+1844 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Community 192` to `What-To-Watch Voting`, `Model Coding Keys`, `Community 259`, `Community 132`, `Community 133`, `Realtime Event Manager`, `DTO Coding Keys`, `Community 267`, `Community 140`, `Community 270`, `Home Creation & Tasks`, `Community 271`, `Community 146`, `Management Tab ViewModel`, `Sample Recipes`, `State`, `SectionHeader`, `Community 279`, `Community 281`, `Community 153`, `Cooking Mode`, `List & Difficulty Enums`, `Community 157`, `Note Color Extensions`, `Community 161`, `Community 35`, `SettingsView`, `HomeStats`, `Delegate`, `App Services Core`, `schema.ts`, `Chat Detail`, `No-Homes Onboarding`, `Community 46`, `MainFeature`, `Kind`, `Theme Selection`, `Recipe List View`, `Read Receipts`, `ManageHomesFeature.swift`, `Genre Picker`, `Community 186`, `recipes.ts`, `Community 64`, `CalendarView`, `Search Results List`, `Community 197`, `Vibrant Module Card`, `NewShoppingItem`, `Message Input`, `Community 75`, `Custom List Row`, `CoreLogicTests`, `Message Hashing`, `PollsClient`, `Urgency`, `Community 85`, `Delegate`, `CancelID`, `UndoToast`, `Community 92`, `Alert`, `Community 224`, `Community 96`, `HomeStats`, `Community 105`, `Community 106`, `Community 107`, `Community 109`, `CancelID`, `Community 120`?**
  _High betweenness centrality (0.114) - this node is a cross-community bridge._
- **Why does `L10n` connect `Recipe Theming` to `Movie UI Components`, `Community 35`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Community 35` to `What-To-Watch Voting`, `Community 258`, `Model Coding Keys`, `Movie API (TMDb)`, `Community 130`, `Community 135`, `Polls Manager`, `DTO Coding Keys`, `Community 138`, `Community 139`, `Community 141`, `Community 143`, `Community 144`, `Community 273`, `Community 146`, `Community 147`, `State`, `Match & Poll Summary`, `PocketBase Models`, `Community 157`, `Community 158`, `Community 159`, `Community 32`, `RecipeDetailFeature`, `Community 34`, `Community 40`, `Recipe List View`, `Read Receipts`, `TaskEdit`, `HomesClient`, `ManageHomesFeature.swift`, `Home Selection View`, `State`, `recipes.ts`, `Chat Messages List`, `Delegate`, `ConfirmationDialogState`, `Search Results List`, `ChoiceCard`, `NewShoppingItem`, `Community 74`, `Overlay Views`, `Management Tab Screen`, `IssuesFeature`, `Note Card`, `Urgency`, `AvatarPickerFace`, `Source`, `Notes View`, `UndoToast`, `Task Priority`, `Community 91`, `Community 93`, `Alert`, `Community 95`, `Community 101`, `Community 103`, `Community 104`, `Community 105`, `Community 107`, `Community 108`, `CancelID`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **What connects `id`, `targets`, `launching` to the rest of the system?**
  _1849 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.0655367231638418 - nodes in this community are weakly interconnected._
- **Should `Model Coding Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.08374384236453201 - nodes in this community are weakly interconnected._
- **Should `Confetti & Realtime Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02631578947368421 - nodes in this community are weakly interconnected._