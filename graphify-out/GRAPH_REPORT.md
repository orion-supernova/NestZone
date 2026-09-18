# Graph Report - NestZone  (2026-09-18)

## Corpus Check
- 224 files · ~491,249 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 5547 nodes · 11813 edges · 258 communities (248 shown, 10 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 402 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `063b534c`
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
- Community 294

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

## Communities (258 total, 10 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.07
Nodes (32): ContentMode, CryptoKit, KeyedDecodingContainer, Int, T, ImageDiskCache, CGFloat, String (+24 more)

### Community 1 - "Localization Strings"
Cohesion: 0.28
Nodes (4): DependencyValues, CalendarFeatureTests, Double, Void

### Community 2 - "Model Coding Keys"
Cohesion: 0.08
Nodes (26): BindableAction, Action, alert, binding, contributionsUpdated, loadFailed, task, Alert (+18 more)

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
Cohesion: 0.16
Nodes (14): AuthProvider, CheckedContinuation, ConvexClient, Decodable, escaping, AsyncSemaphore, ConvexAppleAuthProvider, ConvexAuthTokens (+6 more)

### Community 9 - "Polls Manager"
Cohesion: 0.13
Nodes (19): Footer, EventPlan, LinkedExpense, LinkedItem, MenuRecipe, Double, Palette, StickyColor (+11 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.07
Nodes (38): ActivityID, ActivityCategory, calendar, finance, home, issues, meals, messages (+30 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.04
Nodes (52): CodingKeys, amount, attendees, budget, category, cookTime, created, createdBy (+44 more)

### Community 12 - "Messages View"
Cohesion: 0.04
Nodes (50): Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped, conversationsUpdated (+42 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.04
Nodes (51): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+43 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.07
Nodes (36): assertParticipant(), create, listByHome, rename, requireDocHome(), requireHomeMember(), requireUser(), assertAuthor() (+28 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.07
Nodes (30): Field, Action, binding, failed, finished, submitTapped, succeeded, CreateHomeFeature (+22 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.05
Nodes (43): Action, addPartsTapped, alert, assignFailed, assignTapped, binding, confirm, delegate (+35 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.05
Nodes (33): addParts, assign, attachPhotos, byHome, comment, create, detail, EntryKind (+25 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.07
Nodes (20): NestZone, AlertState, HomeFeature, ReducerOf, Self, ManageHomesFeature, ReducerOf, Self (+12 more)

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
Cohesion: 0.16
Nodes (18): BudgetProgress, CategoryTotal, EventSpend, FinanceSummary, Health, close, healthy, over (+10 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.07
Nodes (33): addItems, cleanWeekdays(), collect(), create, detail, EventDoc, eventKind, EventNudge (+25 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.10
Nodes (48): Codable, Hashable, AreaCount, CategoryCount, HouseIssue, IssueBoard, IssueDetail, IssueEntry (+40 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.04
Nodes (56): PushRegistration, failed, none, registered, Bool, String, Action, alert (+48 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.17
Nodes (14): Poll, PollDetail, PollItem, PollOutcome, Result, agreed, closest, nothing (+6 more)

### Community 32 - "Community 32"
Cohesion: 0.05
Nodes (39): Element, Error, Sendable, AvatarDirectory, String, URL, AvatarEntry, String (+31 more)

### Community 33 - "Community 33"
Cohesion: 0.06
Nodes (34): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+26 more)

### Community 34 - "Community 34"
Cohesion: 0.20
Nodes (9): RelativeTime, RelativeTimeClock, Duration, Int, Never, Task, Text, Void (+1 more)

### Community 35 - "Community 35"
Cohesion: 0.04
Nodes (44): CaseIterable, LocalizedStringResource, Tab, home, hub, messages, notes, settings (+36 more)

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
Nodes (32): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+24 more)

### Community 40 - "Community 40"
Cohesion: 0.10
Nodes (28): LaunchView, OfflineView, Void, CropCircleMask, AlreadyDecidedBanner, CuisineTile, DinnerPlanCard, DinnerSheet (+20 more)

### Community 41 - "App Services Core"
Cohesion: 0.08
Nodes (33): AnyCancellable, Combine, ConvexClientWithAuth, DependencyValues, InboxClient, AppUpdate, AppUpdateID, async (+25 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.20
Nodes (16): Identifiable, ContributionDay, ContributionSlice, ContributionWindow, allTime, month, week, Count (+8 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.06
Nodes (32): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+24 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.07
Nodes (25): Error, LocalizedError, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline (+17 more)

### Community 46 - "Community 46"
Cohesion: 0.17
Nodes (10): Alert, confirmEndRound, AlertState, CancelID, detail, polls, recipes, Delegate (+2 more)

### Community 47 - "New Message Group"
Cohesion: 0.07
Nodes (33): IssueArea, balcony, basement, bathroom, bedroom, exterior, garage, garden (+25 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.09
Nodes (26): LockIsolated, MainFeature.State, Conversation, Kind, audio, document, gif, image (+18 more)

### Community 49 - "Previous Polls"
Cohesion: 0.05
Nodes (46): Action, addMoviesTapped, addTapped, alert, allMoviesUpdated, binding, createListTapped, deleteListTapped (+38 more)

### Community 50 - "Theme Selection"
Cohesion: 0.05
Nodes (37): Action, appEnteredForeground, auth, authStatusChanged, currentUserChanged, deviceRegistered, deviceRegistrationFailed, deviceTokenReceived (+29 more)

### Community 51 - "Recipe List View"
Cohesion: 0.10
Nodes (29): EventOccurrence, EventReminder, atTime, oneDay, oneHour, oneWeek, tenMinutes, thirtyMinutes (+21 more)

### Community 52 - "Read Receipts"
Cohesion: 0.05
Nodes (46): CodingKeys, canRestore, completedAt, email, id, kind, name, taskID (+38 more)

### Community 53 - "Note Creator"
Cohesion: 0.07
Nodes (30): Action, addExpenseTapped, addItemTapped, alert, binding, bulkAddFinished, delegate, deleteTapped (+22 more)

### Community 54 - "Community 54"
Cohesion: 0.07
Nodes (30): Action, activityFailed, activityUpdated, admin, adminTapped, alert, badgeFailed, badgeUpdated (+22 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.07
Nodes (29): CodingKeys, activity, activityFloor, activityReadAt, actor, actorName, body, cap (+21 more)

### Community 56 - "Home Selection View"
Cohesion: 0.09
Nodes (19): AvatarSourceRow, Void, Color, String, Backdrop, BudgetProgress.Health, ConfettiBurst, TimeInterval (+11 more)

### Community 57 - "Switch Home Sheet"
Cohesion: 0.07
Nodes (27): Action, alert, archiveTapped, binding, composeTapped, delegate, deleteFinishedFailed, deleteTapped (+19 more)

### Community 58 - "Genre Picker"
Cohesion: 0.22
Nodes (13): MealPlanID, MealPlan, Cuisine, HomeID, Kind, Recipe, UserID, DinnerDecision (+5 more)

### Community 59 - "Swipe Card"
Cohesion: 0.10
Nodes (23): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+15 more)

### Community 60 - "Recipe Card"
Cohesion: 0.03
Nodes (72): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+64 more)

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
Cohesion: 0.27
Nodes (4): DinnerFeature, ReducerOf, DinnerTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.11
Nodes (22): checkedRecipes(), cascadeDeleteConversation(), cascadeDeleteHome(), cascadeDeleteMovieList(), cascadeDeletePoll(), requireMembers(), requireRef(), requireSameHome() (+14 more)

### Community 67 - "Preset List Card"
Cohesion: 0.22
Nodes (6): HubFeature, Duration, ReducerOf, Self, HubCountsTests, HubNavigationTests

### Community 68 - "Search Results List"
Cohesion: 0.12
Nodes (18): Alert, confirmDelete, Delegate, openArchive, Filter, all, done, open (+10 more)

### Community 69 - "Language Selection"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 71 - "Vibrant Module Card"
Cohesion: 0.12
Nodes (14): AsyncThrowingStream, DependencyValues, EventsClient, StockUpResult, async, Error, EventID, HomeID (+6 more)

### Community 72 - "Chat Header"
Cohesion: 0.16
Nodes (13): State, StepTimer, Action, AlertState, Bool, Destination, Double, HomeID (+5 more)

### Community 73 - "Message Input"
Cohesion: 0.11
Nodes (30): CastMember, Kind, custom, watched, wishlist, Movie, MovieExtras, MovieList (+22 more)

### Community 74 - "Community 74"
Cohesion: 0.10
Nodes (19): PlanSection, budget, menu, shopping, tickets, AddItemField, DisclosureRow, EventComposerSheet (+11 more)

### Community 75 - "Community 75"
Cohesion: 0.08
Nodes (25): Action, alert, binding, cancelTapped, composer, delegate, deleteTapped, editTapped (+17 more)

### Community 76 - "Custom List Row"
Cohesion: 0.09
Nodes (21): AppUpdatesTable, BillsTable, BudgetsTable, ConversationsTable, EventsTable, ExpensesTable, HomeActivityTable, HomesTable (+13 more)

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
Cohesion: 0.13
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
Cohesion: 0.13
Nodes (15): CustomStringConvertible, ExpressibleByStringLiteral, AppUpdate, AppVersion, Bool, Int, String, UpdateAvailability (+7 more)

### Community 86 - "Community 86"
Cohesion: 0.05
Nodes (43): CodingKeys, body, color, created, createdBy, homeID, id, image (+35 more)

### Community 87 - "Notes View"
Cohesion: 0.23
Nodes (9): content, GlassCard, GlassGroup, Metrics, Bool, CGFloat, Content, View (+1 more)

### Community 88 - "Task Priority"
Cohesion: 0.25
Nodes (8): Folds, ShoppingView, EdgeInsets, EventID, IssueID, RecipeID, Set, StoreOf

### Community 90 - "Community 90"
Cohesion: 0.11
Nodes (18): CodingKeys, category, created, createdBy, details, eventID, eventTitle, homeID (+10 more)

### Community 91 - "Community 91"
Cohesion: 0.20
Nodes (13): AvatarPickerButton, Editing, Handover, Bool, CGFloat, Data, PhotosPickerItem, PhotoUpload (+5 more)

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
Cohesion: 0.26
Nodes (10): Expense, ExpenseSplit, ExpenseWeight, NewExpense, Settlement, EventID, ExpenseID, IssueID (+2 more)

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
Cohesion: 0.18
Nodes (15): Kind, generic, movie, recipe, PollVote, Status, active, closed (+7 more)

### Community 103 - "Community 103"
Cohesion: 0.27
Nodes (10): ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat, Double (+2 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.10
Nodes (20): CalendarFeature, CancelID, events, members, undo, State, Action, AlertState (+12 more)

### Community 106 - "Community 106"
Cohesion: 0.11
Nodes (17): Alert, confirmDelete, AlertState, CancelID, notes, ComposeNoteFeature, Destination, compose (+9 more)

### Community 107 - "Community 107"
Cohesion: 0.14
Nodes (12): InboxFeature, Effect, ReducerOf, Self, activity, updates, InboxBell, InboxPanel (+4 more)

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (12): ImageIO, PhotoCompressionPlan, Bool, CGFloat, Int, PhotoCompressor, Bool, CGFloat (+4 more)

### Community 109 - "Community 109"
Cohesion: 0.11
Nodes (17): Cuisine, american, chinese, indian, italian, japanese, korean, mediterranean (+9 more)

### Community 110 - "Community 110"
Cohesion: 0.13
Nodes (13): HomePath, contributions, movieNight, recipeDetail, taskArchive, tasks, ComposeRecipeFeature, Destination (+5 more)

### Community 111 - "Community 111"
Cohesion: 0.13
Nodes (14): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Cleanup done in the same pass (2026‑09‑10), Data cleanup + indexing (2026‑09‑03, deployed), Host move (2026‑09‑10): zeynepmakine → instance‑20260910‑1151, NestZone backend — Convex deploy & data‑import runbook, Not errors, despite looking like one, Notes (+6 more)

### Community 112 - "Community 112"
Cohesion: 0.25
Nodes (9): bold(), die(), info(), run(), set_build_number(), set_marketing_version(), deploy.sh script, step() (+1 more)

### Community 113 - "Community 113"
Cohesion: 0.13
Nodes (14): Action, home, homePath, hub, inbox, messages, notes, settings (+6 more)

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
Cohesion: 0.26
Nodes (11): Difficulty, easy, hard, medium, Recipe, Decoder, HomeID, Int (+3 more)

### Community 120 - "Community 120"
Cohesion: 0.08
Nodes (30): IssueEdit, IssuePhotoUpload, PhotoUpload, Action, areaTapped, assigneeTapped, binding, categoryTapped (+22 more)

### Community 121 - "Community 121"
Cohesion: 0.33
Nodes (6): CodingKey, CodingKeys, changelogVersion, checkedAt, storeUrl, storeVersion

### Community 122 - "Community 122"
Cohesion: 0.15
Nodes (17): PartsDraft, State, StatusNote, Action, AlertState, Bool, ConfirmationDialogState, Effect (+9 more)

### Community 123 - "Community 123"
Cohesion: 0.33
Nodes (6): DependencyValues, HomesClient, async, Error, HomeID, Void

### Community 124 - "Community 124"
Cohesion: 0.14
Nodes (7): ShoppingFeature, Duration, ReducerOf, ShoppingTests, Duration, ShoppingItemID, TestStoreOf

### Community 125 - "Community 125"
Cohesion: 0.11
Nodes (6): Decimal, Money, SplitMath, Set, String, FinanceLogicTests

### Community 126 - "Community 126"
Cohesion: 0.13
Nodes (15): Delegate, notificationsEnabled, openCalendar, openContributions, openEvent, openEventID, openIssues, openMessages (+7 more)

### Community 127 - "Community 127"
Cohesion: 0.11
Nodes (19): IssueComposerFeature, ReducerOf, Self, members, State, Action, AlertState, Bool (+11 more)

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
Cohesion: 0.30
Nodes (4): Duration, TasksFeature, TasksFeatureTests, TestClock

### Community 132 - "Community 132"
Cohesion: 0.24
Nodes (9): ReleaseCheck, Decoder, String, URL, UpdateCheck, checking, failed, idle (+1 more)

### Community 133 - "Community 133"
Cohesion: 0.22
Nodes (9): DependencyValues, MessagesClient, async, ConversationID, Error, HomeID, Int, MessageID (+1 more)

### Community 134 - "Community 134"
Cohesion: 0.15
Nodes (18): AmountField, BillComposerSheet, BudgetEditorSheet, ComposerToolbar, ExpenseComposerSheet, InlineError, MemberLabel, mutating() (+10 more)

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
Cohesion: 0.25
Nodes (9): Layout, FlowLayout, Row, CGFloat, CGRect, CGSize, Int, ProposedViewSize (+1 more)

### Community 139 - "Community 139"
Cohesion: 0.09
Nodes (27): ColorScheme, Control, Glass, restingTilt(), Double, String, GlassListLab, LabRow (+19 more)

### Community 140 - "Community 140"
Cohesion: 0.32
Nodes (8): Cache, Recipe, SampleRecipe, SampleRecipeLoader, Bool, Int, Recipe, String

### Community 141 - "Community 141"
Cohesion: 0.15
Nodes (16): IssuesFeature, Duration, ReducerOf, Self, IssueRow, IssuesView, RowBadge, SettledRow (+8 more)

### Community 142 - "Community 142"
Cohesion: 0.11
Nodes (25): Alert, confirmClearCategory, confirmClearEvent, confirmClearMeal, confirmClearParts, confirmClearPurchased, ClearTarget, category (+17 more)

### Community 143 - "Community 143"
Cohesion: 0.19
Nodes (11): AppTheme, basic, cyberpunk, deepOcean, neonNight, retroWave, EnvironmentValues, Palette (+3 more)

### Community 144 - "Community 144"
Cohesion: 0.18
Nodes (13): PlanRow, PlanState, active, done, empty, Bool, Double, LocalizedStringResource (+5 more)

### Community 145 - "Community 145"
Cohesion: 0.21
Nodes (11): apiKey(), details, discover, fetchJSON(), fetchPages(), GENRE_NAMES, GENRES, TMDbCredit (+3 more)

### Community 146 - "Community 146"
Cohesion: 0.06
Nodes (30): App, AppFeature, ReducerOf, Self, AppView, StoreOf, CodingKeys, address (+22 more)

### Community 147 - "Community 147"
Cohesion: 0.07
Nodes (27): AlertState, CreateMovieListFeature, Destination, createList, list, MovieListFeature, MoviesFeature, ReducerOf (+19 more)

### Community 148 - "Community 148"
Cohesion: 0.15
Nodes (13): CodingKeys, cleaning, completed, count, email, general, maintenance, name (+5 more)

### Community 149 - "Community 149"
Cohesion: 0.20
Nodes (11): State, Action, AlertState, Bool, Destination, Effect, HomeID, IdentifiedArrayOf (+3 more)

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
Cohesion: 0.09
Nodes (24): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+16 more)

### Community 154 - "Alert"
Cohesion: 0.39
Nodes (5): PhotoZoom, Bool, CGFloat, CGSize, Self

### Community 155 - "Community 155"
Cohesion: 0.24
Nodes (5): HomeManagementFeature, ReducerOf, HomeManagementView, StoreOf, HomeManagementTests

### Community 156 - "Community 156"
Cohesion: 0.18
Nodes (9): AvatarInitials, CGFloat, String, HomeView, NowBadge, SuggestedDinnerCard, StoreOf, Void (+1 more)

### Community 157 - "Community 157"
Cohesion: 0.40
Nodes (5): Scope, deleteAll, deleteThisOne, editAll, editThisOne

### Community 158 - "Community 158"
Cohesion: 0.33
Nodes (6): CurrencyDefaults, String, CurrencyPicker, Bool, String, Void

### Community 159 - "Community 159"
Cohesion: 0.22
Nodes (13): DayCell, DayTimeline, EventRow, Placed, PlanRing, Bool, CGFloat, ClosedRange (+5 more)

### Community 160 - "RecipeDetailFeature"
Cohesion: 0.16
Nodes (11): ComposeTaskFeature, Destination, compose, ReducerOf, Self, ComposeTaskSheet, StoreOf, String (+3 more)

### Community 161 - "Community 161"
Cohesion: 0.50
Nodes (4): CancelID, badge, categories, feed

### Community 162 - "Community 162"
Cohesion: 0.29
Nodes (6): Deprecations, Is it safe to remove yet?, Notes on what is already here, Row format, The register, What that means in practice

### Community 163 - "Community 163"
Cohesion: 0.43
Nodes (5): GlassTextField, Binding, Bool, LocalizedStringResource, String

### Community 164 - "SettingsView"
Cohesion: 0.09
Nodes (20): Alert, confirmSignOut, AlertState, CancelID, copyReset, members, pushTokenCopyReset, Delegate (+12 more)

### Community 165 - "HomeStats"
Cohesion: 0.12
Nodes (14): AlertState, BillComposerFeature, BudgetEditorFeature, ExpenseComposerFeature, PayBillFeature, SettleUpFeature, ReducerOf, Self (+6 more)

### Community 166 - "Delegate"
Cohesion: 0.33
Nodes (5): AlertState, ShoppingItem.Category, LocalizedStringResource, Self, String

### Community 167 - "Cache"
Cohesion: 0.17
Nodes (11): Actions, Did it work?, Environment, Finally, Post-Actions, Start Conditions, The division of labour, The setup, once (+3 more)

### Community 168 - "auth.config.ts"
Cohesion: 0.24
Nodes (8): parts, Cuisine, DinnerCandidate, Kind, cuisine, custom, recipe, Recipe

### Community 169 - "schema.ts"
Cohesion: 0.33
Nodes (6): Delegate, deleteRequested, openEvent, openShoppingList, EventID, IssueID

### Community 170 - "README.md"
Cohesion: 0.18
Nodes (10): eventKind, financeCategory, issueArea, issueCategory, issueEntryKind, issueSeverity, issueStatus, recurrence (+2 more)

### Community 171 - "State"
Cohesion: 0.25
Nodes (8): ArraySlice, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Loaded

### Community 172 - "HomeView"
Cohesion: 0.36
Nodes (8): out, EventEdit, Bool, ConvexEncodable, RecipeID, Recurrence, String, UserID

### Community 173 - "Action"
Cohesion: 0.18
Nodes (11): CodingKeys, issuesChange, messagesChange, notes, notesChange, openIssues, openTasks, shoppingChange (+3 more)

### Community 174 - "MainFeature"
Cohesion: 0.33
Nodes (6): CancelID, events, meals, members, stats, tasks

### Community 176 - "SpendCategory"
Cohesion: 0.20
Nodes (7): Data, Error, Any, Bool, Data, Error, UIApplication

### Community 177 - "Kind"
Cohesion: 0.08
Nodes (28): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+20 more)

### Community 178 - "MainFeature"
Cohesion: 0.25
Nodes (9): State, Action, AlertState, AppUpdate, Bool, HomeID, IdentifiedArrayOf, Tab (+1 more)

### Community 179 - "KeyboardDismisser"
Cohesion: 0.21
Nodes (10): State, Action, AlertState, Bool, Cuisine, HomeID, IdentifiedArrayOf, Int (+2 more)

### Community 180 - "Action"
Cohesion: 0.50
Nodes (6): NewShoppingItem, RecipeIngredients, Double, HomeID, RecipeID, String

### Community 181 - "TaskEdit"
Cohesion: 0.12
Nodes (27): CGPoint, Arc, BalanceBars, Bill, Bill.Urgency, BillCycle, BudgetRing, Flight (+19 more)

### Community 182 - "HomesClient"
Cohesion: 0.29
Nodes (8): CameraPicker, Coordinator, Bool, Data, Void, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIViewControllerRepresentable

### Community 183 - "ManageHomesFeature.swift"
Cohesion: 0.10
Nodes (17): AlertState, CancelID, detail, polls, Destination, history, movieInfo, pickKind (+9 more)

### Community 184 - "State"
Cohesion: 0.12
Nodes (17): Bill, BillCycle, biweekly, monthly, once, quarterly, weekly, yearly (+9 more)

### Community 185 - "FinanceFeature"
Cohesion: 0.40
Nodes (3): RecipesFeature, SavedRecipeTests, RecipeID

### Community 186 - "Community 186"
Cohesion: 0.27
Nodes (10): DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Int, String, UNAuthorizationStatus (+2 more)

### Community 187 - ".send"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 188 - "recipes.ts"
Cohesion: 0.12
Nodes (18): Loaded, Int, Action, countsUpdated, moduleTapped, path, showShoppingList, task (+10 more)

### Community 189 - "Community 189"
Cohesion: 0.42
Nodes (7): NewTask, Bool, ConvexEncodable, HomeID, String, UserID, TaskEdit

### Community 190 - "State"
Cohesion: 0.25
Nodes (8): State, Action, AlertState, AppUpdate, Bool, IdentifiedArrayOf, Set, UserID

### Community 191 - "Delegate"
Cohesion: 0.14
Nodes (15): HubModule, calendar, finance, maintenance, movies, recipes, shopping, Bool (+7 more)

### Community 192 - "Community 192"
Cohesion: 0.05
Nodes (19): AuthenticationServices, ComposableArchitecture, ConvexMobile, CoreGraphics, Foundation, CancelID, recipes, CancelID (+11 more)

### Community 193 - "ConfirmationDialogState"
Cohesion: 0.40
Nodes (4): Animation, SettingsView, StoreOf, String

### Community 194 - "CalendarView"
Cohesion: 0.27
Nodes (7): ASAuthorization, AuthFeature, ReducerOf, Self, AuthView, Error, StoreOf

### Community 195 - "Cuisine"
Cohesion: 0.22
Nodes (8): AppDelegate, Void, NSObject, UIApplicationDelegate, UNNotification, UNNotificationPresentationOptions, UNUserNotificationCenter, UNUserNotificationCenterDelegate

### Community 197 - "Community 197"
Cohesion: 0.04
Nodes (53): Equatable, Screen, choosingHome, launching, main, offline, signedOut, MainFeature.HomePath.State (+45 more)

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
Cohesion: 0.33
Nodes (3): RelativeTimeTests, Int, TimeInterval

### Community 202 - "CancelID"
Cohesion: 0.22
Nodes (9): Delegate, deleted, deleteRequested, paid, saved, settled, BillID, BudgetID (+1 more)

### Community 203 - "StatTile"
Cohesion: 0.43
Nodes (5): StatTile, Int, LocalizedStringResource, String, Void

### Community 204 - "AuthFeature.swift"
Cohesion: 0.39
Nodes (8): CategoryHeader, GroupHeader, GroupMenu, ShoppingRow, Bool, Int, String, Void

### Community 205 - "Community 205"
Cohesion: 0.32
Nodes (6): IssueDetailFeature, ReducerOf, Self, IssueDetailView, PhotosPickerItem, StoreOf

### Community 207 - "IssuesFeature"
Cohesion: 0.33
Nodes (3): Context, Any, UIImagePickerController

### Community 208 - "PollsClient"
Cohesion: 0.29
Nodes (7): DependencyValues, PollsClient, async, Error, HomeID, PollID, Void

### Community 209 - "Urgency"
Cohesion: 0.08
Nodes (26): DependencyKey, CatalogClient, DependencyValues, async, DependencyValues, MealsClient, async, Error (+18 more)

### Community 210 - "Delegate"
Cohesion: 0.26
Nodes (8): Binding, Bool, CGFloat, Content, Gesture, LocalizedStringResource, Void, SwipeToDelete

### Community 211 - "AvatarPickerFace"
Cohesion: 0.29
Nodes (6): AvatarPickerFace, Bool, CGFloat, String, UIImage, URL

### Community 212 - "Source"
Cohesion: 0.33
Nodes (7): MealPlan.Kind, Source, custom, explore, saved, LocalizedStringResource, String

### Community 213 - "CancelID"
Cohesion: 0.33
Nodes (6): CancelID, authState, currentUser, deviceRegistration, deviceToken, foreground

### Community 214 - "Delegate"
Cohesion: 0.15
Nodes (16): Double, AffectedCount, DependencyValues, IssueEdit, IssuesClient, ScheduledVisit, async, ConvexEncodable (+8 more)

### Community 215 - "CancelID"
Cohesion: 0.29
Nodes (6): AppLanguage, english, system, turkish, L10n, Locale

### Community 216 - "UndoToast"
Cohesion: 0.53
Nodes (4): LocalizedStringResource, String, Void, UndoToast

### Community 217 - "IssueComposerFeature"
Cohesion: 0.25
Nodes (8): CancelID, bills, events, handoff, issues, movies, recipes, shopping

### Community 218 - "InboxAdminFeature"
Cohesion: 0.40
Nodes (4): InboxAdminFeature, InboxComposerFeature, ReducerOf, Self

### Community 220 - "CancelID"
Cohesion: 0.29
Nodes (7): Path, calendar, finance, issues, movies, recipes, shopping

### Community 221 - "Community 221"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 222 - "Alert"
Cohesion: 0.14
Nodes (13): CancelID, addConfirmation, meals, saved, shopping, timer, Delegate, openShoppingList (+5 more)

### Community 223 - "Community 223"
Cohesion: 0.25
Nodes (8): Comparable, CalendarDay, Calendar, Self, CalendarMonth, MonthGrid, Calendar, String

### Community 224 - "Community 224"
Cohesion: 0.15
Nodes (19): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+11 more)

### Community 225 - ".alert"
Cohesion: 0.33
Nodes (5): Action, AlertState, Bool, String, TaskDeleteWarning

### Community 226 - "HomeStats"
Cohesion: 0.50
Nodes (3): HomeStats, Decoder, Int

### Community 227 - "AppSettings.swift"
Cohesion: 0.40
Nodes (4): Shared<String?>, SharedKey, HomeID, Self

### Community 228 - "Community 228"
Cohesion: 0.40
Nodes (4): c, http, iv, t0

### Community 229 - "FinanceFeature"
Cohesion: 0.40
Nodes (4): FinanceFeature, Duration, ReducerOf, Self

### Community 231 - "StepDuration"
Cohesion: 0.50
Nodes (4): StepDuration, Int, Regex, Substring

### Community 233 - "PasteboardClient"
Cohesion: 0.50
Nodes (4): DependencyValues, PasteboardClient, String, Void

### Community 234 - "Community 234"
Cohesion: 0.50
Nodes (3): client, iv, started

### Community 235 - "Community 235"
Cohesion: 0.15
Nodes (15): pending, members, Pending, State, Action, AlertState, Bool, Destination (+7 more)

### Community 236 - "Community 236"
Cohesion: 0.40
Nodes (4): CancelID, members, tasks, undo

### Community 237 - "AvatarSourceSheet"
Cohesion: 0.50
Nodes (3): AvatarSourceSheet, Bool, Void

### Community 238 - "AvatarViewerBar"
Cohesion: 0.50
Nodes (3): AvatarViewerBar, String, Void

### Community 239 - "CancelID"
Cohesion: 0.50
Nodes (4): CancelID, board, handoff, undo

### Community 240 - "Community 240"
Cohesion: 0.67
Nodes (3): CancelID, items, undo

### Community 243 - "Alert"
Cohesion: 0.67
Nodes (3): Alert, confirmDelete, confirmQuit

### Community 245 - "Community 245"
Cohesion: 0.06
Nodes (31): EventKind, anniversary, appointment, birthday, chore, cinema, concert, deadline (+23 more)

### Community 258 - "Community 258"
Cohesion: 0.25
Nodes (5): KeyboardDismisser, Bool, UIGestureRecognizer, UIGestureRecognizerDelegate, UITouch

### Community 259 - "Community 259"
Cohesion: 0.29
Nodes (7): AddedCount, DependencyValues, ShoppingClient, async, Error, Int, Void

### Community 263 - "Community 263"
Cohesion: 0.16
Nodes (4): Self, FinanceTests, BillID, ExpenseID

### Community 267 - "Community 267"
Cohesion: 0.60
Nodes (3): AvatarRollback, String, URL

### Community 270 - "Community 270"
Cohesion: 0.09
Nodes (17): Calendar, MealDate, Calendar, String, BinaryInteger, Date, Decoder, Double (+9 more)

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
Cohesion: 0.20
Nodes (9): CodingKeys, avatar, avatarURL, created, email, homeIDs, id, name (+1 more)

### Community 292 - "Community 292"
Cohesion: 0.04
Nodes (58): EventScope, occurrence, series, Action, allDayToggled, attendeeToggled, binding, delegate (+50 more)

### Community 294 - "Community 294"
Cohesion: 0.67
Nodes (3): PollCandidate, ConvexEncodable, String

## Knowledge Gaps
- **1846 isolated node(s):** `id`, `targets`, `launching`, `signedOut`, `offline` (+1841 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Community 192` to `What-To-Watch Voting`, `Model Coding Keys`, `Realtime Event Manager`, `DTO Coding Keys`, `Community 267`, `Community 140`, `Messages View`, `Community 270`, `Home Creation & Tasks`, `Community 271`, `Community 146`, `Management Tab ViewModel`, `Sample Recipes`, `State`, `SectionHeader`, `Community 279`, `Community 281`, `Community 153`, `Cooking Mode`, `List & Difficulty Enums`, `Movie List Detail`, `Note Color Extensions`, `Community 32`, `SettingsView`, `App Services Core`, `Chat Detail`, `No-Homes Onboarding`, `Community 46`, `Poll Input Sheets`, `Kind`, `Recipe List View`, `Read Receipts`, `recipes.ts`, `Community 64`, `Search Results List`, `Community 197`, `crons.ts`, `Vibrant Module Card`, `NewShoppingItem`, `Message Input`, `Custom List Row`, `Urgency`, `Community 85`, `Community 86`, `CancelID`, `Delegate`, `Alert`, `Community 224`, `HomeStats`, `Community 106`, `Community 109`, `Community 119`, `Community 120`, `Community 123`?**
  _High betweenness centrality (0.122) - this node is a cross-community bridge._
- **Why does `L10n` connect `Recipe Theming` to `Community 192`, `Movie UI Components`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Community 192` to `What-To-Watch Voting`, `Model Coding Keys`, `Community 130`, `Movie API (TMDb)`, `Community 134`, `Community 135`, `Polls Manager`, `DTO Coding Keys`, `Community 138`, `Community 139`, `Community 141`, `Community 143`, `Home Creation & Tasks`, `Community 273`, `State`, `Match & Poll Summary`, `PocketBase Models`, `Community 156`, `Community 159`, `Community 32`, `RecipeDetailFeature`, `Community 35`, `Community 163`, `SettingsView`, `Community 40`, `Recipe List View`, `TaskEdit`, `Home Selection View`, `recipes.ts`, `Chat Messages List`, `Search Results List`, `Community 197`, `StatTile`, `Overlay Views`, `Message Hashing`, `Management Tab Screen`, `Note Card`, `Delegate`, `AvatarPickerFace`, `Notes View`, `UndoToast`, `Community 91`, `Community 93`, `Alert`, `Community 95`, `AppSettings.swift`, `Community 101`, `Community 103`, `Community 104`, `Community 106`, `Community 108`, `AvatarSourceSheet`, `AvatarViewerBar`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **What connects `id`, `targets`, `launching` to the rest of the system?**
  _1846 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Should `Model Coding Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.08045977011494253 - nodes in this community are weakly interconnected._
- **Should `Confetti & Realtime Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02631578947368421 - nodes in this community are weakly interconnected._