# Graph Report - NestZone  (2026-09-18)

## Corpus Check
- 223 files · ~489,383 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 5534 nodes · 11801 edges · 241 communities (230 shown, 11 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 402 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9b542180`
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
- AuthFeature.swift
- Community 205
- IssuesFeature
- Urgency
- Delegate
- Delegate
- CancelID
- IssueComposerFeature
- Community 219
- CancelID
- Community 221
- Alert
- Community 223
- Community 224
- Community 228
- Community 232
- Community 234
- Community 235
- Community 236
- Community 240
- Community 241
- Community 242
- Community 245
- Community 258
- Community 259
- Community 260
- Community 263
- Community 267
- Community 270
- Community 271
- Community 273
- Community 279
- Community 281
- Community 292
- Community 294
- Community 296
- Community 298

## God Nodes (most connected - your core abstractions)
1. `L10n` - 175 edges
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
- `EventPlanTests` --calls--> `Timestamp`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Timestamps.swift
- `CalendarFeatureTests` --references--> `CalendarDay`  [EXTRACTED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/CalendarEvent.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Generic polls data model (polls, items, votes scoped to homes)** — docs_pocketbase_readme_polls, docs_pocketbase_readme_poll_items, docs_pocketbase_readme_poll_votes, docs_pocketbase_readme_homes [EXTRACTED 1.00]

## Communities (241 total, 11 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.07
Nodes (32): ContentMode, CryptoKit, KeyedDecodingContainer, Int, T, ImageDiskCache, CGFloat, String (+24 more)

### Community 1 - "Localization Strings"
Cohesion: 0.28
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
Nodes (23): AuthProvider, CheckedContinuation, ConvexClient, Decodable, escaping, LocalizedError, AsyncSemaphore, ConvexAppleAuthProvider (+15 more)

### Community 9 - "Polls Manager"
Cohesion: 0.08
Nodes (30): Footer, IssuePhotoRef, CatalogQuery, Kind, actor, decade, director, genre (+22 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.17
Nodes (16): ActivityCategoryCounts, ActivityPage, AppUpdate, InboxBadge, Row, AppUpdateID, Bool, Decoder (+8 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.04
Nodes (52): CodingKeys, amount, attendees, budget, category, cookTime, created, createdBy (+44 more)

### Community 12 - "Messages View"
Cohesion: 0.05
Nodes (37): Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped, conversationsUpdated (+29 more)

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
Cohesion: 0.09
Nodes (14): AppFeature, ReducerOf, Self, ManageHomesFeature, ReducerOf, Self, SettingsFeature, ManageHomesTests (+6 more)

### Community 19 - "Management Tab ViewModel"
Cohesion: 0.19
Nodes (16): Category, cleaning, groceries, household, other, ShoppingItem, Bool, Decoder (+8 more)

### Community 20 - "Notes ViewModel"
Cohesion: 0.11
Nodes (18): Alert, confirmDeleteList, AlertState, CancelID, all, lists, movies, saved (+10 more)

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
Nodes (42): Bill, BudgetProgress, CategoryTotal, EventSpend, Expense, ExpenseSplit, FinanceSummary, MemberFinance (+34 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.07
Nodes (33): addItems, cleanWeekdays(), collect(), create, detail, EventDoc, eventKind, EventNudge (+25 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.10
Nodes (31): Identifiable, HouseIssue, IssueDetail, IssueEntry, IssueEventLink, IssueExpense, IssuePart, IssuePrecedent (+23 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.05
Nodes (41): Action, alert, avatarRemoved, avatarSelected, avatarUpdated, avatarUpdateFailed, binding, checkForUpdatesTapped (+33 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.13
Nodes (22): Kind, generic, movie, recipe, Poll, PollDetail, PollItem, PollVote (+14 more)

### Community 32 - "Community 32"
Cohesion: 0.05
Nodes (39): Element, Error, Sendable, AvatarDirectory, String, URL, AvatarEntry, String (+31 more)

### Community 33 - "Community 33"
Cohesion: 0.06
Nodes (34): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+26 more)

### Community 34 - "Community 34"
Cohesion: 0.07
Nodes (26): Context, CurrencyDefaults, Shared<String?>, SharedKey, HomeID, Self, String, CameraPicker (+18 more)

### Community 35 - "Community 35"
Cohesion: 0.07
Nodes (27): CaseIterable, LocalizedStringResource, Tab, home, hub, messages, notes, settings (+19 more)

### Community 36 - "Auth Manager"
Cohesion: 0.06
Nodes (34): Action, addTapped, advanceTapped, alert, areaFilterTapped, binding, boardUpdated, categoryFilterTapped (+26 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.07
Nodes (30): accounts, activity, activityCategories, allUpdates, anyAdminId(), badge, cachedReleaseCheck, countsAsUnread() (+22 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.06
Nodes (35): Action, addOnDayTapped, addTapped, alert, binding, daySelected, deleteCommitFailed, deleteTapped (+27 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.06
Nodes (33): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+25 more)

### Community 40 - "Community 40"
Cohesion: 0.12
Nodes (18): AlreadyDecidedBanner, CuisineTile, DinnerPlanCard, DinnerSheet, KindCard, RecipeChoice, RoundView, RouteCard (+10 more)

### Community 41 - "App Services Core"
Cohesion: 0.13
Nodes (19): AnyCancellable, Combine, ConvexClientWithAuth, ArgumentBox, CancellableBox, CancellableBoxPublic, ConnectionState, ConvexConnection (+11 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.20
Nodes (16): Hashable, ContributionDay, ContributionSlice, ContributionWindow, allTime, month, week, Count (+8 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.06
Nodes (32): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+24 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.11
Nodes (20): Equatable, Alert, confirmDelete, Alert, CancelID, conversations, messages, Delegate (+12 more)

### Community 46 - "Community 46"
Cohesion: 0.12
Nodes (17): Alert, confirmEndRound, AlertState, CancelID, detail, polls, recipes, Cuisine (+9 more)

### Community 47 - "New Message Group"
Cohesion: 0.11
Nodes (32): Codable, AreaCount, CategoryCount, IssueArea, balcony, basement, bathroom, bedroom (+24 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.11
Nodes (18): LockIsolated, Conversation, Message, Bool, ConversationID, Decoder, HomeID, Kind (+10 more)

### Community 49 - "Previous Polls"
Cohesion: 0.06
Nodes (31): Action, addMoviesTapped, addTapped, alert, allMoviesUpdated, binding, createListTapped, deleteListTapped (+23 more)

### Community 50 - "Theme Selection"
Cohesion: 0.06
Nodes (30): Action, appEnteredForeground, auth, authStatusChanged, currentUserChanged, deviceRegistered, deviceRegistrationFailed, deviceTokenReceived (+22 more)

### Community 51 - "Recipe List View"
Cohesion: 0.09
Nodes (39): EventOccurrence, EventPlan, EventReminder, atTime, oneDay, oneHour, oneWeek, tenMinutes (+31 more)

### Community 52 - "Read Receipts"
Cohesion: 0.29
Nodes (9): Bool, Decoder, Int, String, TaskID, UserID, TaskArchive, TaskCompletion (+1 more)

### Community 53 - "Note Creator"
Cohesion: 0.07
Nodes (30): Action, addExpenseTapped, addItemTapped, alert, binding, bulkAddFinished, delegate, deleteTapped (+22 more)

### Community 54 - "Community 54"
Cohesion: 0.06
Nodes (33): Action, activityFailed, activityUpdated, admin, adminTapped, alert, badgeFailed, badgeUpdated (+25 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.07
Nodes (29): CodingKeys, activity, activityFloor, activityReadAt, actor, actorName, body, cap (+21 more)

### Community 56 - "Home Selection View"
Cohesion: 0.06
Nodes (32): Color, String, Backdrop, BudgetProgress.Health, StatTile, Int, LocalizedStringResource, String (+24 more)

### Community 57 - "Switch Home Sheet"
Cohesion: 0.07
Nodes (30): ConversationID, Effect, Action, alert, archiveTapped, binding, composeTapped, delegate (+22 more)

### Community 58 - "Genre Picker"
Cohesion: 0.19
Nodes (13): MealPlanID, Kind, cook, order, LinkedEvent, MealPlan, Cuisine, Decoder (+5 more)

### Community 59 - "Swipe Card"
Cohesion: 0.10
Nodes (23): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+15 more)

### Community 60 - "Recipe Card"
Cohesion: 0.03
Nodes (84): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+76 more)

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
Cohesion: 0.14
Nodes (7): DinnerFeature, ReducerOf, RecipeDetailFeature, DinnerOccasionTests, DinnerTests, RecipeShoppingTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.11
Nodes (22): checkedRecipes(), cascadeDeleteConversation(), cascadeDeleteHome(), cascadeDeleteMovieList(), cascadeDeletePoll(), requireMembers(), requireRef(), requireSameHome() (+14 more)

### Community 67 - "Preset List Card"
Cohesion: 0.09
Nodes (15): NestZone, HubFeature, Duration, ReducerOf, Self, RecipesFeature, HubCountsTests, HubNavigationTests (+7 more)

### Community 68 - "Search Results List"
Cohesion: 0.07
Nodes (30): Alert, confirmDelete, CancelID, members, tasks, undo, ComposeTaskFeature, Delegate (+22 more)

### Community 69 - "Language Selection"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 71 - "Vibrant Module Card"
Cohesion: 0.14
Nodes (12): AsyncThrowingStream, DependencyValues, EventsClient, StockUpResult, async, Error, EventID, HomeID (+4 more)

### Community 72 - "Chat Header"
Cohesion: 0.13
Nodes (17): State, StepDuration, StepTimer, Action, AlertState, Bool, Destination, Double (+9 more)

### Community 73 - "Message Input"
Cohesion: 0.15
Nodes (18): CastMember, Kind, custom, watched, wishlist, Movie, MovieExtras, Double (+10 more)

### Community 74 - "Community 74"
Cohesion: 0.08
Nodes (31): AppView, LaunchView, MainView, OfflineView, StoreOf, Void, PlanSection, budget (+23 more)

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
Cohesion: 0.22
Nodes (10): EnvironmentValues, GlassList, GlassListRow, GlassListStyle, GlassRow, Bool, CGFloat, Content (+2 more)

### Community 79 - "Management Tab Screen"
Cohesion: 0.11
Nodes (22): Anchor, BubbleActionsAnchor, BubbleActionsAnchorKey, ChatView, ConversationRow, MessageActionsBar, MessageBubble, MessagesView (+14 more)

### Community 80 - "Community 80"
Cohesion: 0.12
Nodes (14): FALSY, openTasks(), outstandingItems(), outstandingNames(), category, create, createFromRecipe, listByHome (+6 more)

### Community 81 - "Note Card"
Cohesion: 0.12
Nodes (13): AnyShapeStyle, AvatarStack, Member, CGFloat, Int, String, CalendarView, Bool (+5 more)

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
Cohesion: 0.48
Nodes (6): Note, Decoder, HomeID, NoteID, String, UserID

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
Cohesion: 0.15
Nodes (12): Section, board, history, list, rooms, Sort, attention, due (+4 more)

### Community 93 - "Community 93"
Cohesion: 0.11
Nodes (23): Animatable, Configuration, GeometryEffect, IntegerFormatStyle, AnimatedNumber, AppearModifier, ButtonStyle, Motion (+15 more)

### Community 94 - "Community 94"
Cohesion: 0.11
Nodes (19): MovieGenre, action, adventure, animation, comedy, crime, documentary, drama (+11 more)

### Community 95 - "Community 95"
Cohesion: 0.12
Nodes (19): Badge, Chip, Bool, String, Void, IssueComposerSheet, IssueInlineError, IssueSheetToolbar (+11 more)

### Community 96 - "Community 96"
Cohesion: 0.12
Nodes (16): CodingKeys, cookTime, created, createdBy, difficulty, homeID, id, image (+8 more)

### Community 97 - "Community 97"
Cohesion: 0.12
Nodes (12): archive, backfillCompletions, create, listByHome, priority, recordCompletion(), remove, removeFinished (+4 more)

### Community 98 - "Community 98"
Cohesion: 0.24
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 99 - "Community 99"
Cohesion: 0.12
Nodes (17): CodingKeys, assignedTo, completedBy, created, createdBy, details, dueDate, homeID (+9 more)

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (5): ⚠️ Auth caveat (the one real gotcha), Nestzone — PocketBase → Convex migration, Steps, Type/field mapping applied, What's here

### Community 101 - "Community 101"
Cohesion: 0.16
Nodes (13): SectionHeader, LocalizedStringResource, String, AdminUpdateRow, InboxAdminView, InboxComposerSheet, AppUpdate, Bool (+5 more)

### Community 102 - "Community 102"
Cohesion: 0.12
Nodes (16): Action, alert, archiveUpdated, deleteFailed, deleteTapped, loadFailed, restoreFailed, restoreTapped (+8 more)

### Community 103 - "Community 103"
Cohesion: 0.27
Nodes (10): ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat, Double (+2 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.07
Nodes (28): Alert, CalendarFeature, CalendarFeature.Destination.State, CancelID, events, members, undo, Mode (+20 more)

### Community 106 - "Community 106"
Cohesion: 0.16
Nodes (12): Alert, confirmDelete, AlertState, CancelID, notes, ComposeNoteFeature, Destination, compose (+4 more)

### Community 107 - "Community 107"
Cohesion: 0.18
Nodes (11): InboxFeature, ReducerOf, Self, ActivityRow, InboxBell, InboxPanel, AppUpdate, Bool (+3 more)

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (12): ImageIO, PhotoCompressionPlan, Bool, CGFloat, Int, PhotoCompressor, Bool, CGFloat (+4 more)

### Community 109 - "Community 109"
Cohesion: 0.15
Nodes (13): Cuisine, american, chinese, indian, italian, japanese, korean, mediterranean (+5 more)

### Community 110 - "Community 110"
Cohesion: 0.14
Nodes (14): ActivityCategory, calendar, finance, home, issues, meals, messages, movies (+6 more)

### Community 111 - "Community 111"
Cohesion: 0.13
Nodes (14): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Cleanup done in the same pass (2026‑09‑10), Data cleanup + indexing (2026‑09‑03, deployed), Host move (2026‑09‑10): zeynepmakine → instance‑20260910‑1151, NestZone backend — Convex deploy & data‑import runbook, Not errors, despite looking like one, Notes (+6 more)

### Community 112 - "Community 112"
Cohesion: 0.28
Nodes (9): bold(), die(), info(), run(), set_build_number(), set_marketing_version(), deploy.sh script, step() (+1 more)

### Community 113 - "Community 113"
Cohesion: 0.06
Nodes (29): Action, home, homePath, hub, inbox, messages, notes, settings (+21 more)

### Community 114 - "Community 114"
Cohesion: 0.26
Nodes (11): DependencyValues, DinnerDecision, MealsClient, async, Cuisine, Error, EventID, HomeID (+3 more)

### Community 115 - "Community 115"
Cohesion: 0.15
Nodes (13): IssueCategory, appliance, cosmetic, damp, electrical, furniture, heating, internet (+5 more)

### Community 116 - "Community 116"
Cohesion: 0.08
Nodes (23): CodingKeys, conversationID, created, file, homeID, id, isGroupChat, kind (+15 more)

### Community 117 - "Community 117"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 118 - "Community 118"
Cohesion: 0.25
Nodes (8): Backend notes, Commands, Conventions, graphify, Layout, NestZone, One deployment, every app version, Shipping a change

### Community 119 - "Community 119"
Cohesion: 0.26
Nodes (11): Difficulty, easy, hard, medium, Recipe, Decoder, HomeID, Int (+3 more)

### Community 120 - "Community 120"
Cohesion: 0.08
Nodes (30): IssueEdit, Action, areaTapped, assigneeTapped, binding, categoryTapped, delegate, failed (+22 more)

### Community 121 - "Community 121"
Cohesion: 0.33
Nodes (6): CodingKey, CodingKeys, changelogVersion, checkedAt, storeUrl, storeVersion

### Community 122 - "Community 122"
Cohesion: 0.12
Nodes (20): IssueComposerFeature, ReducerOf, Self, PartsDraft, State, StatusNote, Action, AlertState (+12 more)

### Community 123 - "Community 123"
Cohesion: 0.33
Nodes (6): DependencyValues, HomesClient, async, Error, HomeID, Void

### Community 124 - "Community 124"
Cohesion: 0.14
Nodes (7): ShoppingFeature, Duration, ReducerOf, ShoppingTests, Duration, ShoppingItemID, TestStoreOf

### Community 125 - "Community 125"
Cohesion: 0.11
Nodes (7): Decimal, Money, health, SplitMath, Int, Set, FinanceLogicTests

### Community 126 - "Community 126"
Cohesion: 0.13
Nodes (15): Delegate, notificationsEnabled, openCalendar, openContributions, openEvent, openEventID, openIssues, openMessages (+7 more)

### Community 127 - "Community 127"
Cohesion: 0.14
Nodes (16): members, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Int (+8 more)

### Community 128 - "Community 128"
Cohesion: 0.06
Nodes (41): BillCycle, Budget, BudgetID, Action, alert, binding, delegate, deleteTapped (+33 more)

### Community 129 - "Community 129"
Cohesion: 0.16
Nodes (12): MovieList.Kind, State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf (+4 more)

### Community 130 - "Community 130"
Cohesion: 0.18
Nodes (19): BillRow, BudgetCard, DayHeader, EventSpendRow, ExpenseRow, FinanceView, PayerRow, RepairSpendRow (+11 more)

### Community 131 - "Community 131"
Cohesion: 0.13
Nodes (15): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+7 more)

### Community 132 - "Community 132"
Cohesion: 0.24
Nodes (9): ReleaseCheck, Decoder, String, URL, UpdateCheck, checking, failed, idle (+1 more)

### Community 133 - "Community 133"
Cohesion: 0.22
Nodes (9): DependencyValues, MessagesClient, async, ConversationID, Error, HomeID, Int, MessageID (+1 more)

### Community 134 - "Community 134"
Cohesion: 0.14
Nodes (19): AmountField, BillComposerSheet, BudgetEditorSheet, ComposerToolbar, ExpenseComposerSheet, InlineError, MemberLabel, mutating() (+11 more)

### Community 135 - "Community 135"
Cohesion: 0.33
Nodes (8): Avatar, Source, directory, photo, Bool, CGFloat, String, URL

### Community 136 - "Community 136"
Cohesion: 0.25
Nodes (4): AvatarCropTests, PhotoZoomTests, CGFloat, CGSize

### Community 137 - "Community 137"
Cohesion: 0.23
Nodes (6): ContributionsFeature, ReducerOf, Self, ContributionsView, StoreOf, ContributionsFeatureTests

### Community 138 - "Community 138"
Cohesion: 0.36
Nodes (6): PollOutcome, Result, agreed, closest, nothing, Int

### Community 139 - "Community 139"
Cohesion: 0.09
Nodes (27): ColorScheme, Control, Glass, restingTilt(), Double, String, GlassListLab, LabRow (+19 more)

### Community 140 - "Community 140"
Cohesion: 0.32
Nodes (8): Cache, Recipe, SampleRecipe, SampleRecipeLoader, Bool, Int, Recipe, String

### Community 141 - "Community 141"
Cohesion: 0.29
Nodes (10): IssueRow, IssuesView, RowBadge, SettledRow, Bool, IssueID, Namespace, StoreOf (+2 more)

### Community 142 - "Community 142"
Cohesion: 0.15
Nodes (18): ClearTarget, category, event, issue, meal, purchased, State, Action (+10 more)

### Community 143 - "Community 143"
Cohesion: 0.31
Nodes (7): ComposeNoteSheet, NoteCard, NotesView, Bool, StoreOf, String, Void

### Community 144 - "Community 144"
Cohesion: 0.11
Nodes (20): IssueDetailFeature, ReducerOf, Self, IssueDetailView, PlanRow, PlanState, active, done (+12 more)

### Community 145 - "Community 145"
Cohesion: 0.21
Nodes (11): apiKey(), details, discover, fetchJSON(), fetchPages(), GENRE_NAMES, GENRES, TMDbCredit (+3 more)

### Community 146 - "Community 146"
Cohesion: 0.08
Nodes (25): CodingKeys, address, created, id, inviteCode, members, name, updated (+17 more)

### Community 147 - "Community 147"
Cohesion: 0.14
Nodes (18): MovieListFeature, AddMoviesSheet, CreateMovieListSheet, ListChip, ListRow, MovieInfoSheet, MovieListView, MoviesView (+10 more)

### Community 148 - "Community 148"
Cohesion: 0.15
Nodes (13): CodingKeys, cleaning, completed, count, email, general, maintenance, name (+5 more)

### Community 149 - "Community 149"
Cohesion: 0.25
Nodes (8): DependencyValues, InboxClient, AppUpdate, AppUpdateID, async, Error, HomeID, Void

### Community 150 - "State"
Cohesion: 0.14
Nodes (10): AvatarSubject, String, URL, AvatarViewer, AccessibilityAdjustmentDirection, CGFloat, CGSize, Double (+2 more)

### Community 151 - "SectionHeader"
Cohesion: 0.11
Nodes (29): Encodable, Error, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline (+21 more)

### Community 152 - "Community 152"
Cohesion: 0.15
Nodes (13): CodingKeys, created, cuisine, date, event, homeID, id, kind (+5 more)

### Community 153 - "Community 153"
Cohesion: 0.14
Nodes (16): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+8 more)

### Community 154 - "Alert"
Cohesion: 0.39
Nodes (5): PhotoZoom, Bool, CGFloat, CGSize, Self

### Community 155 - "Community 155"
Cohesion: 0.26
Nodes (3): HomeFeature, ReducerOf, HomeFeatureTests

### Community 156 - "Community 156"
Cohesion: 0.20
Nodes (10): Field, CreateHomeSheet, FormSheet, JoinHomeSheet, Bool, Int, LocalizedStringResource, StoreOf (+2 more)

### Community 157 - "Community 157"
Cohesion: 0.22
Nodes (8): Alert, CancelID, plan, Scope, deleteAll, deleteThisOne, editAll, editThisOne

### Community 158 - "Community 158"
Cohesion: 0.31
Nodes (4): CurrencyPicker, Bool, String, Void

### Community 159 - "Community 159"
Cohesion: 0.13
Nodes (20): CalendarDay, Calendar, Self, DayCell, DayTimeline, EventRow, MonthGrid, Placed (+12 more)

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
Cohesion: 0.43
Nodes (5): GlassTextField, Binding, Bool, LocalizedStringResource, String

### Community 164 - "SettingsView"
Cohesion: 0.13
Nodes (14): Alert, confirmSignOut, AlertState, CancelID, copyReset, members, pushTokenCopyReset, Destination (+6 more)

### Community 165 - "HomeStats"
Cohesion: 0.08
Nodes (17): AlertState, BillComposerFeature, BudgetEditorFeature, ExpenseComposerFeature, PayBillFeature, SettleUpFeature, ReducerOf, Self (+9 more)

### Community 166 - "Delegate"
Cohesion: 0.22
Nodes (8): AlertState, CancelID, items, undo, ShoppingItem.Category, LocalizedStringResource, Self, String

### Community 167 - "Cache"
Cohesion: 0.33
Nodes (6): Alert, confirmClearCategory, confirmClearEvent, confirmClearMeal, confirmClearParts, confirmClearPurchased

### Community 168 - "auth.config.ts"
Cohesion: 0.21
Nodes (10): CreateHomeFeature, JoinHomeFeature, ReducerOf, Self, Destination, create, join, Destination (+2 more)

### Community 169 - "schema.ts"
Cohesion: 0.17
Nodes (11): Alert, CancelID, detail, Confirm, delete, Delegate, deleteRequested, openEvent (+3 more)

### Community 170 - "README.md"
Cohesion: 0.18
Nodes (10): eventKind, financeCategory, issueArea, issueCategory, issueEntryKind, issueSeverity, issueStatus, recurrence (+2 more)

### Community 171 - "State"
Cohesion: 0.25
Nodes (8): ArraySlice, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Loaded

### Community 173 - "Action"
Cohesion: 0.10
Nodes (18): CodingKeys, issuesChange, messagesChange, notes, notesChange, openIssues, openTasks, shoppingChange (+10 more)

### Community 174 - "MainFeature"
Cohesion: 0.33
Nodes (6): CancelID, events, meals, members, stats, tasks

### Community 176 - "SpendCategory"
Cohesion: 0.50
Nodes (4): Delegate, homeSwitched, languageChanged, notificationsEnabled

### Community 177 - "Kind"
Cohesion: 0.16
Nodes (13): Alert, confirmLeave, Delegate, dismissRequested, switchRequested, ManageHomesFeature.Destination.State, State, Action (+5 more)

### Community 178 - "MainFeature"
Cohesion: 0.15
Nodes (13): ActivityID, rows, HomeActivity, UserID, State, Action, AlertState, AppUpdate (+5 more)

### Community 179 - "KeyboardDismisser"
Cohesion: 0.12
Nodes (21): parts, DinnerCandidate, Kind, cuisine, custom, recipe, Route, set (+13 more)

### Community 180 - "Action"
Cohesion: 0.50
Nodes (6): NewShoppingItem, RecipeIngredients, Double, HomeID, RecipeID, String

### Community 181 - "TaskEdit"
Cohesion: 0.08
Nodes (38): CGPoint, Layout, Arc, BalanceBars, Bill, Bill.Urgency, BillCycle, BudgetRing (+30 more)

### Community 183 - "ManageHomesFeature.swift"
Cohesion: 0.10
Nodes (21): Alert, confirmDelete, confirmEndRound, AlertState, CancelID, detail, polls, Destination (+13 more)

### Community 184 - "State"
Cohesion: 0.13
Nodes (13): BillCycle, biweekly, monthly, once, quarterly, weekly, yearly, ExpenseWeight (+5 more)

### Community 185 - "FinanceFeature"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 186 - "Community 186"
Cohesion: 0.07
Nodes (29): App, DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Data, Error (+21 more)

### Community 187 - ".send"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 188 - "recipes.ts"
Cohesion: 0.21
Nodes (11): Action, countsUpdated, moduleTapped, path, showShoppingList, task, HubFeature.Path.State, IssueCounts (+3 more)

### Community 189 - "Community 189"
Cohesion: 0.20
Nodes (9): CodingKeys, body, color, created, createdBy, homeID, id, image (+1 more)

### Community 191 - "Delegate"
Cohesion: 0.14
Nodes (15): HubModule, calendar, finance, maintenance, movies, recipes, shopping, Bool (+7 more)

### Community 192 - "Community 192"
Cohesion: 0.13
Nodes (9): CoreGraphics, Foundation, IssuePhotoIDs, String, Action, AlertState, Bool, String (+1 more)

### Community 193 - "ConfirmationDialogState"
Cohesion: 0.32
Nodes (5): Animation, EditNameSheet, SettingsView, StoreOf, String

### Community 194 - "CalendarView"
Cohesion: 0.09
Nodes (19): ASAuthorization, Action, alert, appleSignInFailed, appleSignInSucceeded, signInFailed, signInSucceeded, Alert (+11 more)

### Community 195 - "Cuisine"
Cohesion: 0.20
Nodes (10): CodingKeys, canRestore, completedAt, email, id, kind, name, taskID (+2 more)

### Community 197 - "Community 197"
Cohesion: 0.20
Nodes (9): Alert, CancelID, board, handoff, undo, Delegate, openEvent, openShoppingList (+1 more)

### Community 198 - "crons.ts"
Cohesion: 0.33
Nodes (7): APNSEnvironment, DependencyValues, DevicesClient, PushResult, Int, String, Void

### Community 199 - "ChoiceCard"
Cohesion: 0.33
Nodes (6): ChoiceCard, HomeRow, Bool, LocalizedStringResource, String, Void

### Community 200 - "NewShoppingItem"
Cohesion: 0.39
Nodes (4): KeychainTokenStore, Any, String, Security

### Community 201 - "CoreLogicTests"
Cohesion: 0.29
Nodes (5): IssuesFeature, Duration, Effect, ReducerOf, Self

### Community 202 - "CancelID"
Cohesion: 0.22
Nodes (9): Delegate, deleted, deleteRequested, paid, saved, settled, BillID, BudgetID (+1 more)

### Community 204 - "AuthFeature.swift"
Cohesion: 0.25
Nodes (9): MovieList, StoredMovie, Bool, Decoder, HomeID, Kind, MovieListID, StoredMovieID (+1 more)

### Community 205 - "Community 205"
Cohesion: 0.28
Nodes (7): State, Action, AlertState, Bool, HomeID, Set, UserID

### Community 207 - "IssuesFeature"
Cohesion: 0.29
Nodes (6): PushRegistration, failed, none, registered, Bool, String

### Community 209 - "Urgency"
Cohesion: 0.05
Nodes (42): AuthenticationServices, ComposableArchitecture, ConvexMobile, DependencyKey, CatalogClient, DependencyValues, MovieDetails, async (+34 more)

### Community 210 - "Delegate"
Cohesion: 0.26
Nodes (8): Binding, Bool, CGFloat, Content, Gesture, LocalizedStringResource, Void, SwipeToDelete

### Community 214 - "Delegate"
Cohesion: 0.15
Nodes (16): Double, AffectedCount, DependencyValues, IssueEdit, IssuesClient, ScheduledVisit, async, ConvexEncodable (+8 more)

### Community 215 - "CancelID"
Cohesion: 0.29
Nodes (6): AppLanguage, english, system, turkish, L10n, Locale

### Community 217 - "IssueComposerFeature"
Cohesion: 0.25
Nodes (8): CancelID, bills, events, handoff, issues, movies, recipes, shopping

### Community 220 - "CancelID"
Cohesion: 0.29
Nodes (7): Path, calendar, finance, issues, movies, recipes, shopping

### Community 221 - "Community 221"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 222 - "Alert"
Cohesion: 0.08
Nodes (23): Alert, confirmDelete, confirmQuit, AlertState, CancelID, addConfirmation, meals, saved (+15 more)

### Community 223 - "Community 223"
Cohesion: 0.33
Nodes (6): Comparable, Urgency, dueSoon, dueToday, overdue, upcoming

### Community 224 - "Community 224"
Cohesion: 0.11
Nodes (24): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+16 more)

### Community 228 - "Community 228"
Cohesion: 0.40
Nodes (4): c, http, iv, t0

### Community 234 - "Community 234"
Cohesion: 0.50
Nodes (3): client, iv, started

### Community 235 - "Community 235"
Cohesion: 0.14
Nodes (16): pending, path, members, Pending, State, Action, AlertState, Bool (+8 more)

### Community 240 - "Community 240"
Cohesion: 0.31
Nodes (4): ReducerOf, Self, TaskArchiveFeature, TaskArchiveFeatureTests

### Community 245 - "Community 245"
Cohesion: 0.06
Nodes (37): EventKind, anniversary, appointment, birthday, chore, cinema, concert, deadline (+29 more)

### Community 258 - "Community 258"
Cohesion: 0.04
Nodes (38): AvatarInitials, CGFloat, String, AvatarPickerFace, Bool, CGFloat, String, UIImage (+30 more)

### Community 259 - "Community 259"
Cohesion: 0.32
Nodes (7): AddedCount, DependencyValues, ShoppingClient, async, Error, Int, Void

### Community 260 - "Community 260"
Cohesion: 0.33
Nodes (5): ArchiveRow, Bool, StoreOf, String, TaskArchiveView

### Community 263 - "Community 263"
Cohesion: 0.14
Nodes (7): CalendarMonth, Calendar, Self, FinanceTests, Bill, BillID, ExpenseID

### Community 267 - "Community 267"
Cohesion: 0.60
Nodes (3): AvatarRollback, String, URL

### Community 270 - "Community 270"
Cohesion: 0.10
Nodes (20): MealDate, Calendar, String, BinaryInteger, Date, Decoder, Double, NewTask (+12 more)

### Community 271 - "Community 271"
Cohesion: 0.07
Nodes (31): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+23 more)

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
Cohesion: 0.04
Nodes (67): EventScope, occurrence, series, Action, allDayToggled, attendeeToggled, binding, delegate (+59 more)

### Community 294 - "Community 294"
Cohesion: 0.67
Nodes (3): PollCandidate, ConvexEncodable, String

### Community 296 - "Community 296"
Cohesion: 0.60
Nodes (4): State, HomeID, Loaded, UserID

### Community 298 - "Community 298"
Cohesion: 0.25
Nodes (7): Alert, enableNotifications, AlertState, Loaded, Int, Self, OptionSet

## Knowledge Gaps
- **1837 isolated node(s):** `id`, `targets`, `launching`, `signedOut`, `offline` (+1832 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Community 192` to `What-To-Watch Voting`, `Model Coding Keys`, `Community 259`, `Community 133`, `Realtime Event Manager`, `DTO Coding Keys`, `Community 267`, `Community 140`, `Community 270`, `Home Creation & Tasks`, `Community 271`, `Community 146`, `Management Tab ViewModel`, `Notes ViewModel`, `Community 149`, `State`, `SectionHeader`, `Community 279`, `Community 281`, `Community 153`, `Cooking Mode`, `Community 157`, `Note Color Extensions`, `Community 32`, `Community 161`, `Community 292`, `HomeStats`, `Delegate`, `SettingsView`, `App Services Core`, `Community 298`, `Chat Detail`, `schema.ts`, `Action`, `Community 46`, `New Message Group`, `No-Homes Onboarding`, `Kind`, `Theme Selection`, `Recipe List View`, `Read Receipts`, `ManageHomesFeature.swift`, `Home Selection View`, `Genre Picker`, `Community 186`, `Recipe Card`, `Community 189`, `recipes.ts`, `Community 64`, `CalendarView`, `Preset List Card`, `Search Results List`, `Community 197`, `crons.ts`, `Vibrant Module Card`, `NewShoppingItem`, `Message Input`, `Community 75`, `Custom List Row`, `IssuesFeature`, `Urgency`, `Delegate`, `CancelID`, `Alert`, `Community 224`, `Community 102`, `Community 105`, `Community 106`, `Community 113`, `Community 114`, `Community 116`, `Community 119`, `Community 120`, `Community 123`?**
  _High betweenness centrality (0.126) - this node is a cross-community bridge._
- **Why does `L10n` connect `Recipe Theming` to `Home Selection View`, `Movie UI Components`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Community 258` to `What-To-Watch Voting`, `Model Coding Keys`, `Community 130`, `Movie API (TMDb)`, `Community 260`, `Community 134`, `Community 135`, `Polls Manager`, `DTO Coding Keys`, `Community 139`, `Community 141`, `Community 143`, `Community 144`, `Community 273`, `Community 146`, `Community 147`, `Notes ViewModel`, `State`, `Match & Poll Summary`, `PocketBase Models`, `Community 156`, `Community 157`, `Community 158`, `Community 159`, `Community 32`, `RecipeDetailFeature`, `Community 34`, `Community 163`, `Community 292`, `Community 40`, `Recipe List View`, `TaskEdit`, `ManageHomesFeature.swift`, `Home Selection View`, `Community 186`, `Recipe Card`, `Chat Messages List`, `recipes.ts`, `Delegate`, `ConfirmationDialogState`, `Search Results List`, `Community 197`, `ChoiceCard`, `Community 74`, `Overlay Views`, `Message Hashing`, `Management Tab Screen`, `Note Card`, `Delegate`, `Urgency`, `Notes View`, `Task Priority`, `Community 91`, `Community 93`, `Alert`, `Community 95`, `Community 101`, `Community 102`, `Community 103`, `Community 104`, `Community 105`, `Community 107`, `Community 108`?**
  _High betweenness centrality (0.068) - this node is a cross-community bridge._
- **What connects `id`, `targets`, `launching` to the rest of the system?**
  _1837 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Should `Model Coding Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.08374384236453201 - nodes in this community are weakly interconnected._
- **Should `Confetti & Realtime Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02631578947368421 - nodes in this community are weakly interconnected._