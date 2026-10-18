# Graph Report - NestZone  (2026-10-18)

## Corpus Check
- 243 files · ~532,838 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 6228 nodes · 13530 edges · 273 communities (261 shown, 12 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 478 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `36316735`
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
- PhotoZoom
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
- SymbolBounceModifier
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
- Scope
- AvatarSourceSheet
- AvatarViewerBar
- CancelID
- PollCandidate
- Community 241
- Community 242
- Alert
- Community 245
- IssuePhotoIDs
- CancelID
- .newestFirst
- MovieList.Kind
- ci_post_clone.sh
- BillCycle
- IssueComposerFeature
- PushRegistration
- HomeStats
- CancelID
- HomesClient
- HomeManagementFeature.swift
- Alert
- IssuesFeature
- ArchiveRow
- Community 263
- .image
- Section
- CancelID
- .userNotificationCenter
- Community 270
- StepDuration
- CancelID
- Community 279
- Community 281
- Community 292

## God Nodes (most connected - your core abstractions)
1. `L10n` - 211 edges
2. `Timestamp` - 107 edges
3. `Date` - 103 edges
4. `User` - 101 edges
5. `Foundation` - 98 edges
6. `SwiftUI` - 95 edges
7. `ComposableArchitecture` - 94 edges
8. `AppError` - 89 edges
9. `EventOccurrence` - 81 edges
10. `CodingKeys` - 79 edges

## Surprising Connections (you probably didn't know these)
- `MovieHandoffTests` --calls--> `MovieList`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Movie.swift
- `MovieHandoffTests` --calls--> `PollItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Poll.swift
- `ShoppingTests` --calls--> `ShoppingItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/ShoppingItem.swift
- `CalendarFeatureTests` --references--> `CalendarDay`  [EXTRACTED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/CalendarEvent.swift
- `ManageHomesTests` --calls--> `Home`  [EXTRACTED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Home.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Generic polls data model (polls, items, votes scoped to homes)** — docs_pocketbase_readme_polls, docs_pocketbase_readme_poll_items, docs_pocketbase_readme_poll_votes, docs_pocketbase_readme_homes [EXTRACTED 1.00]

## Communities (273 total, 12 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.07
Nodes (34): ContentMode, CryptoKit, KeyedDecodingContainer, Int, T, ImageDiskCache, CGFloat, String (+26 more)

### Community 1 - "Localization Strings"
Cohesion: 0.04
Nodes (56): IdentifiedActionOf, Action, deferredOpen, delegate, path, screen, segmentPicked, statsTapped (+48 more)

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
Cohesion: 0.04
Nodes (3): L10n, Int, Locale

### Community 6 - "Movie List Model"
Cohesion: 0.03
Nodes (65): CodingKeys, amount, autoSplit, billID, budget, budgets, categories, category (+57 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.09
Nodes (23): AuthProvider, CheckedContinuation, ConvexClient, escaping, LocalizedError, AsyncSemaphore, ConvexAppleAuthProvider, ConvexAuthError (+15 more)

### Community 8 - "Movie UI Components"
Cohesion: 0.04
Nodes (3): LocalizedStringResource, String, StaticString

### Community 9 - "Polls Manager"
Cohesion: 0.14
Nodes (13): Footer, Palette, StickyColor, blue, green, orange, pink, purple (+5 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.08
Nodes (39): ActivityID, Decodable, ActivityCategory, calendar, finance, home, issues, meals (+31 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.03
Nodes (60): CodingKeys, amount, attendees, budget, budgeted, category, cookTime, created (+52 more)

### Community 12 - "Messages View"
Cohesion: 0.05
Nodes (38): Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped, conversationsUpdated (+30 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.04
Nodes (54): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+46 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.07
Nodes (36): assertParticipant(), create, listByHome, rename, requireDocHome(), requireHomeMember(), requireUser(), assertAuthor() (+28 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.07
Nodes (31): BindableAction, Field, Action, binding, failed, finished, submitTapped, succeeded (+23 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.04
Nodes (45): Action, addPartsTapped, alert, assignFailed, assignTapped, binding, confirm, delegate (+37 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.05
Nodes (33): addParts, assign, attachPhotos, byHome, comment, create, detail, EntryKind (+25 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.06
Nodes (33): Action, addOnDayTapped, addTapped, alert, binding, daySelected, deleteCommitFailed, deleteTapped (+25 more)

### Community 19 - "Management Tab ViewModel"
Cohesion: 0.19
Nodes (16): Category, cleaning, groceries, household, other, ShoppingItem, Bool, Decoder (+8 more)

### Community 20 - "Notes ViewModel"
Cohesion: 0.12
Nodes (6): Money, health, Decimal, Set, String, FinanceLogicTests

### Community 21 - "Unit & UI Tests"
Cohesion: 0.13
Nodes (9): LaunchUITests, Bool, SmokeFlowUITests, String, XCUIApplication, XCUIApplication, TabNavigationUITests, XCTest (+1 more)

### Community 22 - "Match & Poll Summary"
Cohesion: 0.22
Nodes (13): AddedToListToast, ComposeRecipeSheet, CookingModeView, Fact, RecipeCard, RecipeDetailView, RecipesView, Int (+5 more)

### Community 23 - "Messages Manager"
Cohesion: 0.11
Nodes (19): Alert, confirmDelete, CancelID, updates, Delegate, saved, InboxAdminFeature, InboxComposerFeature (+11 more)

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
Nodes (17): AmountField, BillComposerSheet, BudgetEditorSheet, ComposerToolbar, ExpenseComposerSheet, InlineError, MemberLabel, PayBillSheet (+9 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.06
Nodes (34): addItems, cleanWeekdays(), collect(), create, detail, EventDoc, eventKind, EventNudge (+26 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.06
Nodes (80): Codable, Hashable, AreaCount, CategoryCount, HouseIssue, IssueArea, balcony, basement (+72 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.05
Nodes (42): Action, alert, avatarRemoved, avatarSelected, avatarUpdated, avatarUpdateFailed, binding, checkForUpdatesTapped (+34 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.18
Nodes (13): Poll, PollDetail, PollItem, PollOutcome, Result, agreed, closest, nothing (+5 more)

### Community 32 - "Community 32"
Cohesion: 0.05
Nodes (38): Element, Error, Sendable, AvatarDirectory, String, URL, AvatarEntry, String (+30 more)

### Community 33 - "Community 33"
Cohesion: 0.06
Nodes (34): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+26 more)

### Community 34 - "Community 34"
Cohesion: 0.04
Nodes (53): Action, capture, capturedDismissed, capturedOpenTapped, customize, home, house, inbox (+45 more)

### Community 35 - "Community 35"
Cohesion: 0.05
Nodes (33): AvatarInitials, CGFloat, String, AvatarPickerFace, Bool, CGFloat, String, UIImage (+25 more)

### Community 36 - "Auth Manager"
Cohesion: 0.06
Nodes (34): Action, addTapped, advanceTapped, alert, areaFilterTapped, binding, boardUpdated, categoryFilterTapped (+26 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.06
Nodes (31): accounts, activity, activityCategories, allUpdates, anyAdminId(), badge, cachedReleaseCheck, countsAsUnread() (+23 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.12
Nodes (25): EventHistorySheet, LocalizedStringResource, StoreOf, String, DinnerCandidate, AlreadyDecidedBanner, CuisineTile, DinnerPlanCard (+17 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.06
Nodes (33): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+25 more)

### Community 40 - "Community 40"
Cohesion: 0.12
Nodes (17): CodingKeys, assignedTo, completedBy, created, createdBy, details, dueDate, homeID (+9 more)

### Community 41 - "App Services Core"
Cohesion: 0.12
Nodes (21): AnyCancellable, Combine, ConvexClientWithAuth, ArgumentBox, CancellableBox, CancellableBoxPublic, ConnectionState, ConvexConnection (+13 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.04
Nodes (48): CaseIterable, AppLanguage, english, system, turkish, L10n, Locale, Frequency (+40 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.06
Nodes (32): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+24 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.09
Nodes (20): Error, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline, server (+12 more)

### Community 46 - "Community 46"
Cohesion: 0.18
Nodes (12): State, Action, AlertState, Bool, Cuisine, HomeID, IdentifiedArrayOf, Int (+4 more)

### Community 47 - "New Message Group"
Cohesion: 0.15
Nodes (13): CaptureOutcome, State, Action, AlertState, Bool, CaptureKind, Effect, HomeID (+5 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.25
Nodes (5): LockIsolated, Message, Kind, ChatFeature, MessagesTests

### Community 49 - "Previous Polls"
Cohesion: 0.06
Nodes (34): Action, addMoviesTapped, addTapped, alert, allMoviesUpdated, binding, createListTapped, delegate (+26 more)

### Community 50 - "Theme Selection"
Cohesion: 0.24
Nodes (6): CustomizeFeature, ReducerOf, Self, CustomizeView, StoreOf, CustomizeTests

### Community 51 - "Recipe List View"
Cohesion: 0.11
Nodes (20): CaptureKind, HubModule, calendar, finance, maintenance, movies, notes, recipes (+12 more)

### Community 52 - "Read Receipts"
Cohesion: 0.12
Nodes (16): Action, alert, archiveUpdated, deleteFailed, deleteTapped, loadFailed, restoreFailed, restoreTapped (+8 more)

### Community 53 - "Note Creator"
Cohesion: 0.05
Nodes (44): Action, addExpenseTapped, addItemTapped, alert, binding, bulkAddFinished, clearLeftoversTapped, delegate (+36 more)

### Community 54 - "Community 54"
Cohesion: 0.07
Nodes (30): Action, activityFailed, activityUpdated, admin, adminTapped, alert, badgeFailed, badgeUpdated (+22 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.06
Nodes (31): CodingKeys, activity, activityFloor, activityReadAt, actor, actorName, body, cap (+23 more)

### Community 56 - "Home Selection View"
Cohesion: 0.20
Nodes (9): RelativeTime, RelativeTimeClock, Duration, Int, Never, Task, Text, Void (+1 more)

### Community 57 - "Switch Home Sheet"
Cohesion: 0.07
Nodes (28): Action, alert, archiveTapped, binding, composeTapped, contributionsTapped, delegate, deleteFinishedFailed (+20 more)

### Community 58 - "Genre Picker"
Cohesion: 0.25
Nodes (12): DependencyValues, DinnerDecision, MealsClient, async, Cuisine, Error, EventID, HomeID (+4 more)

### Community 59 - "Swipe Card"
Cohesion: 0.10
Nodes (23): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+15 more)

### Community 60 - "Recipe Card"
Cohesion: 0.03
Nodes (78): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+70 more)

### Community 61 - "Chat Messages List"
Cohesion: 0.42
Nodes (8): ButtonRole, IconButton, PrimaryButton, SecondaryButton, Bool, LocalizedStringResource, String, Void

### Community 62 - "Edit Note Sheet"
Cohesion: 0.07
Nodes (27): Action, alert, askForNotificationsIfNeeded, billsUpdated, claimFailed, delegate, issueClaimed, issuesUpdated (+19 more)

### Community 63 - "Auth DTOs"
Cohesion: 0.11
Nodes (17): compilerOptions, allowJs, esModuleInterop, isolatedModules, lib, module, moduleResolution, noEmit (+9 more)

### Community 64 - "Community 64"
Cohesion: 0.25
Nodes (12): createRecipe(), DependencyValues, NewRecipe, RecipesClient, async, Bool, Error, HomeID (+4 more)

### Community 65 - "Community 65"
Cohesion: 0.17
Nodes (6): DinnerFeature, ReducerOf, RecipeDetailFeature, DinnerTests, RecipeShoppingTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.08
Nodes (30): checkedRecipes(), create, ensurePresetLists, get, join, leave, listMine, members (+22 more)

### Community 67 - "Preset List Card"
Cohesion: 0.15
Nodes (11): HeroCard, HomeView, SuggestedDinnerCard, Bill, Bool, LocalizedStringResource, StoreOf, String (+3 more)

### Community 68 - "Search Results List"
Cohesion: 0.08
Nodes (39): Bill, BillCycle, biweekly, monthly, once, quarterly, weekly, yearly (+31 more)

### Community 69 - "Language Selection"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 71 - "Vibrant Module Card"
Cohesion: 0.10
Nodes (20): out, AsyncThrowingStream, DependencyValues, EventEdit, EventsClient, StockUpResult, async, Bool (+12 more)

### Community 72 - "Chat Header"
Cohesion: 0.15
Nodes (14): State, StepTimer, Action, AlertState, Bool, Destination, Double, HomeID (+6 more)

### Community 73 - "Message Input"
Cohesion: 0.12
Nodes (21): CastMember, Kind, custom, watched, wishlist, Movie, MovieExtras, Double (+13 more)

### Community 74 - "Community 74"
Cohesion: 0.17
Nodes (18): Identifiable, ContributionDay, ContributionSlice, ContributionWindow, allTime, month, week, Count (+10 more)

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
Cohesion: 0.33
Nodes (3): CalendarFeatureTests, DependencyValues, Void

### Community 79 - "Management Tab Screen"
Cohesion: 0.13
Nodes (18): BubbleActionsAnchor, BubbleActionsAnchorKey, ChatView, ConversationRow, MessageActionsBar, MessageBubble, Bool, CGFloat (+10 more)

### Community 80 - "Community 80"
Cohesion: 0.11
Nodes (15): FALSY, openTasks(), outstandingItems(), outstandingNames(), category, create, createFromRecipe, createMany (+7 more)

### Community 81 - "Note Card"
Cohesion: 0.43
Nodes (5): AvatarStack, Member, CGFloat, Int, String

### Community 82 - "Community 82"
Cohesion: 0.27
Nodes (8): discardAvatar(), publicUser, publicUsers(), avatarUploadUrl, byIds, me, setAvatar, updateProfile

### Community 83 - "Community 83"
Cohesion: 0.11
Nodes (19): CodingKeys, created, entityType, externalID, genre, homeID, id, isYes (+11 more)

### Community 84 - "Create Movie List"
Cohesion: 0.11
Nodes (17): 1. Where the codebase actually stands, 2. Who is the subscriber?, 3. The seams, 4. The rule that makes it tractable, 5. Which features should be premium, 6. What to build before deciding any of it, 7. Open questions, Calendar ↔ Shopping and Recipes (+9 more)

### Community 85 - "Community 85"
Cohesion: 0.15
Nodes (12): State, Action, AlertState, AppUpdate, Bool, Effect, HomeID, IdentifiedArrayOf (+4 more)

### Community 86 - "Community 86"
Cohesion: 0.11
Nodes (19): Action, alert, authorsResolved, binding, colorSelected, composeTapped, deleteFailed, deleteTapped (+11 more)

### Community 87 - "Notes View"
Cohesion: 0.08
Nodes (25): content, Color, String, Backdrop, StatTile, Int, LocalizedStringResource, String (+17 more)

### Community 88 - "Task Priority"
Cohesion: 0.18
Nodes (16): CategoryHeader, Folds, GroupHeader, GroupMenu, ShoppingRow, ShoppingView, Bool, EdgeInsets (+8 more)

### Community 90 - "Community 90"
Cohesion: 0.11
Nodes (18): CodingKeys, category, created, createdBy, details, eventID, eventTitle, homeID (+10 more)

### Community 91 - "Community 91"
Cohesion: 0.24
Nodes (11): DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Int, String, UNAuthorizationStatus (+3 more)

### Community 92 - "Community 92"
Cohesion: 0.18
Nodes (15): Kind, generic, movie, recipe, PollVote, Status, active, closed (+7 more)

### Community 93 - "Community 93"
Cohesion: 0.07
Nodes (36): Animatable, Configuration, GeometryEffect, IntegerFormatStyle, EnvironmentValues, GlassList, GlassListRow, GlassListStyle (+28 more)

### Community 94 - "Community 94"
Cohesion: 0.11
Nodes (19): MovieGenre, action, adventure, animation, comedy, crime, documentary, drama (+11 more)

### Community 95 - "Community 95"
Cohesion: 0.14
Nodes (17): Expense, ExpenseSplit, ExpenseWeight, NewExpense, SpendCategory, dining, entertainment, groceries (+9 more)

### Community 96 - "Community 96"
Cohesion: 0.12
Nodes (16): CodingKeys, cookTime, created, createdBy, difficulty, homeID, id, image (+8 more)

### Community 97 - "Community 97"
Cohesion: 0.12
Nodes (12): archive, backfillCompletions, create, listByHome, priority, recordCompletion(), remove, removeFinished (+4 more)

### Community 98 - "Community 98"
Cohesion: 0.13
Nodes (17): IssuesFeature, Duration, Effect, ReducerOf, Self, IssueRow, IssuesView, RowBadge (+9 more)

### Community 99 - "Community 99"
Cohesion: 0.15
Nodes (5): CaptureParserTests, Fixture, Calendar, Int, String

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (5): ⚠️ Auth caveat (the one real gotcha), Nestzone — PocketBase → Convex migration, Steps, Type/field mapping applied, What's here

### Community 101 - "Community 101"
Cohesion: 0.15
Nodes (14): SectionHeader, LocalizedStringResource, String, AdminUpdateRow, InboxAdminView, InboxComposerSheet, AppUpdate, Bool (+6 more)

### Community 102 - "Community 102"
Cohesion: 0.09
Nodes (29): MealPlanID, Cuisine, american, chinese, indian, italian, japanese, korean (+21 more)

### Community 103 - "Community 103"
Cohesion: 0.22
Nodes (11): AnyShapeStyle, ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat (+3 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.10
Nodes (20): CalendarFeature, CancelID, events, members, undo, State, Action, AlertState (+12 more)

### Community 106 - "Community 106"
Cohesion: 0.16
Nodes (12): Alert, confirmDelete, AlertState, CancelID, notes, ComposeNoteFeature, Destination, compose (+4 more)

### Community 107 - "Community 107"
Cohesion: 0.33
Nodes (6): CancelID, all, lists, movies, saved, search

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (12): ImageIO, PhotoCompressionPlan, Bool, CGFloat, Int, PhotoCompressor, Bool, CGFloat (+4 more)

### Community 109 - "Community 109"
Cohesion: 0.17
Nodes (12): Delegate, openArchive, openContributions, HouseTask.Kind, HouseTask.Priority, Kind, archive, delete (+4 more)

### Community 110 - "Community 110"
Cohesion: 0.06
Nodes (31): Action, appEnteredForeground, auth, authStatusChanged, currentUserChanged, deviceRegistered, deviceRegistrationFailed, deviceTokenReceived (+23 more)

### Community 111 - "Community 111"
Cohesion: 0.13
Nodes (14): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Cleanup done in the same pass (2026‑09‑10), Data cleanup + indexing (2026‑09‑03, deployed), Host move (2026‑09‑10): zeynepmakine → instance‑20260910‑1151, NestZone backend — Convex deploy & data‑import runbook, Not errors, despite looking like one, Notes (+6 more)

### Community 112 - "Community 112"
Cohesion: 0.25
Nodes (9): bold(), die(), info(), run(), set_build_number(), set_marketing_version(), deploy.sh script, step() (+1 more)

### Community 113 - "Community 113"
Cohesion: 0.48
Nodes (6): Note, Decoder, HomeID, NoteID, String, UserID

### Community 114 - "Community 114"
Cohesion: 0.15
Nodes (15): CatalogQuery, Kind, actor, decade, director, genre, nowPlaying, popular (+7 more)

### Community 115 - "Community 115"
Cohesion: 0.12
Nodes (16): Action, addTapped, alert, binding, cancelTapped, classified, composer, delegate (+8 more)

### Community 116 - "Community 116"
Cohesion: 0.13
Nodes (15): CodingKeys, conversationID, created, file, homeID, id, isGroupChat, kind (+7 more)

### Community 117 - "Community 117"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 118 - "Community 118"
Cohesion: 0.22
Nodes (9): Backend notes, Commands, Conventions, graphify, Layout, Navigation, NestZone, One deployment, every app version (+1 more)

### Community 119 - "Community 119"
Cohesion: 0.16
Nodes (12): MovieList.Kind, State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf (+4 more)

### Community 120 - "Community 120"
Cohesion: 0.08
Nodes (32): IssueEdit, IssuePhotoUpload, PhotoUpload, Action, areaTapped, assigneeTapped, binding, categoryTapped (+24 more)

### Community 121 - "Community 121"
Cohesion: 0.07
Nodes (16): PushResult, Int, ManageHomesFeature, ReducerOf, Self, ShoppingFeature, Duration, ReducerOf (+8 more)

### Community 122 - "Community 122"
Cohesion: 0.15
Nodes (18): CancelID, detail, PartsDraft, State, StatusNote, Action, AlertState, Bool (+10 more)

### Community 123 - "Community 123"
Cohesion: 0.28
Nodes (8): Int, Anchor, Clock, DateReader, DateWords, Bool, Set, Token

### Community 124 - "Community 124"
Cohesion: 0.06
Nodes (29): AppFeature, ReducerOf, Self, CodingKeys, address, created, id, inviteCode (+21 more)

### Community 125 - "Community 125"
Cohesion: 0.22
Nodes (12): AvatarPickerButton, Editing, Handover, Bool, CGFloat, Data, PhotosPickerItem, PhotoUpload (+4 more)

### Community 126 - "Community 126"
Cohesion: 0.08
Nodes (25): Delegate, acceptDinnerSuggestion, addChore, decideDinner, makeOccasion, notificationsEnabled, openCalendar, openContributions (+17 more)

### Community 127 - "Community 127"
Cohesion: 0.15
Nodes (15): State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Int, IssueArea (+7 more)

### Community 128 - "Community 128"
Cohesion: 0.06
Nodes (41): BillCycle, Budget, BudgetID, Action, alert, binding, delegate, deleteTapped (+33 more)

### Community 129 - "Community 129"
Cohesion: 0.17
Nodes (11): Context, CameraPicker, Coordinator, Any, Bool, Data, Void, UIImagePickerController (+3 more)

### Community 130 - "Community 130"
Cohesion: 0.18
Nodes (19): BillRow, BudgetCard, DayHeader, EventSpendRow, ExpenseRow, FinanceView, PayerRow, RepairSpendRow (+11 more)

### Community 131 - "Community 131"
Cohesion: 0.08
Nodes (28): IndexSet, Action, cancelTapped, delegate, doneTapped, resetTapped, sectionsMoved, visibilityPicked (+20 more)

### Community 132 - "Community 132"
Cohesion: 0.24
Nodes (10): activityArgs(), DependencyValues, InboxClient, AppUpdate, AppUpdateID, async, ConvexEncodable, Error (+2 more)

### Community 133 - "Community 133"
Cohesion: 0.20
Nodes (8): CaptureDate, CaptureKind, CaptureOutcome, CaptureView, Bool, LocalizedStringResource, StoreOf, String

### Community 134 - "Community 134"
Cohesion: 0.07
Nodes (31): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+23 more)

### Community 135 - "Community 135"
Cohesion: 0.12
Nodes (24): CaptureAmount, CaptureConfidence, none, strong, weak, CaptureDraft, CaptureKind, chore (+16 more)

### Community 136 - "Community 136"
Cohesion: 0.25
Nodes (4): AvatarCropTests, PhotoZoomTests, CGFloat, CGSize

### Community 137 - "Community 137"
Cohesion: 0.21
Nodes (6): ContributionsFeature, ReducerOf, Self, ContributionsView, StoreOf, ContributionsFeatureTests

### Community 138 - "Community 138"
Cohesion: 0.15
Nodes (16): Conversation, Kind, audio, document, gif, image, system, text (+8 more)

### Community 139 - "Community 139"
Cohesion: 0.11
Nodes (23): ColorScheme, Control, Glass, GlassListLab, LabRow, LabSurface, Model, SpacingSample (+15 more)

### Community 140 - "Community 140"
Cohesion: 0.32
Nodes (8): Cache, Recipe, SampleRecipe, SampleRecipeLoader, Bool, Int, Recipe, String

### Community 141 - "Community 141"
Cohesion: 0.29
Nodes (9): Bool, Decoder, Int, String, TaskID, UserID, TaskArchive, TaskCompletion (+1 more)

### Community 142 - "Community 142"
Cohesion: 0.15
Nodes (18): ClearTarget, category, event, issue, meal, purchased, State, Action (+10 more)

### Community 143 - "Community 143"
Cohesion: 0.11
Nodes (19): PlanSection, budget, menu, shopping, tickets, AddItemField, DisclosureRow, EventComposerSheet (+11 more)

### Community 144 - "Community 144"
Cohesion: 0.12
Nodes (15): Alert, enableNotifications, AlertState, Counter, events, problems, shopping, unread (+7 more)

### Community 145 - "Community 145"
Cohesion: 0.21
Nodes (11): apiKey(), details, discover, fetchJSON(), fetchPages(), GENRE_NAMES, GENRES, TMDbCredit (+3 more)

### Community 146 - "Community 146"
Cohesion: 0.16
Nodes (18): FoundationModels, LanguageModelSession, CaptureClassifierClient, CaptureModel, CaptureVerdict, chore, event, expense (+10 more)

### Community 147 - "Community 147"
Cohesion: 0.20
Nodes (7): CalendarView, Bool, Gesture, Int, LocalizedStringResource, StoreOf, UserID

### Community 148 - "Community 148"
Cohesion: 0.15
Nodes (13): CodingKeys, cleaning, completed, count, email, general, maintenance, name (+5 more)

### Community 149 - "Community 149"
Cohesion: 0.24
Nodes (7): CaptureFeature, Duration, ReducerOf, Set, CaptureFeatureTests, CaptureKind, DependencyValues

### Community 150 - "State"
Cohesion: 0.14
Nodes (10): AvatarSubject, String, URL, AvatarViewer, AccessibilityAdjustmentDirection, CGFloat, CGSize, Double (+2 more)

### Community 151 - "SectionHeader"
Cohesion: 0.23
Nodes (17): Encodable, billArgs(), DependencyValues, expenseArgs(), ExpenseShareArgs, ExpenseWeightArgs, FinanceClient, monthArgs() (+9 more)

### Community 152 - "Community 152"
Cohesion: 0.19
Nodes (14): InboxFeature, ReducerOf, Self, ActivityRow, InboxBell, InboxPanel, InboxPanelHost, AppUpdate (+6 more)

### Community 153 - "Community 153"
Cohesion: 0.09
Nodes (24): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+16 more)

### Community 154 - "Alert"
Cohesion: 0.20
Nodes (10): CodingKeys, canRestore, completedAt, email, id, kind, name, taskID (+2 more)

### Community 155 - "Community 155"
Cohesion: 0.14
Nodes (18): AppView, CapturedToast, LaunchView, MainView, NowSheets, OfflineView, RouteStackView, SegmentedRoot (+10 more)

### Community 156 - "Community 156"
Cohesion: 0.19
Nodes (11): AppTheme, basic, cyberpunk, deepOcean, neonNight, retroWave, EnvironmentValues, Palette (+3 more)

### Community 157 - "Community 157"
Cohesion: 0.18
Nodes (4): HomeFeature, Duration, ReducerOf, HomeFeatureTests

### Community 158 - "Community 158"
Cohesion: 0.29
Nodes (7): Bool, CGFloat, Content, Gesture, LocalizedStringResource, Void, SwipeToDelete

### Community 159 - "Community 159"
Cohesion: 0.22
Nodes (13): DayCell, DayTimeline, EventRow, Placed, PlanRing, Bool, CGFloat, ClosedRange (+5 more)

### Community 160 - "RecipeDetailFeature"
Cohesion: 0.10
Nodes (21): Action, addTapped, alert, decideDinnerTapped, delegate, dinner, dinnerSuggestionAccepted, dockTapped (+13 more)

### Community 161 - "Community 161"
Cohesion: 0.12
Nodes (19): Badge, Chip, Bool, String, Void, IssueComposerSheet, IssueInlineError, IssueSheetToolbar (+11 more)

### Community 162 - "Community 162"
Cohesion: 0.29
Nodes (6): Deprecations, Is it safe to remove yet?, Notes on what is already here, Row format, The register, What that means in practice

### Community 163 - "Community 163"
Cohesion: 0.14
Nodes (13): Alert, CancelID, model, CaptureFeature.Composer.State, Composer, event, expense, problem (+5 more)

### Community 164 - "SettingsView"
Cohesion: 0.10
Nodes (19): Alert, confirmSignOut, AlertState, CancelID, copyReset, members, pushTokenCopyReset, Delegate (+11 more)

### Community 165 - "HomeStats"
Cohesion: 0.06
Nodes (30): Alert, confirmDelete, AlertState, BillComposerFeature, BudgetEditorFeature, Delegate, deleted, deleteRequested (+22 more)

### Community 166 - "Delegate"
Cohesion: 0.22
Nodes (8): AlertState, CancelID, items, undo, ShoppingItem.Category, LocalizedStringResource, Self, String

### Community 167 - "Cache"
Cohesion: 0.15
Nodes (12): Actions, `ci_scripts/` — why the first builds failed, Did it work?, Environment, Finally, Post-Actions, Start Conditions, The division of labour (+4 more)

### Community 168 - "auth.config.ts"
Cohesion: 0.32
Nodes (6): Character, AmountReader, Reading, Decimal, Substring, Range

### Community 169 - "schema.ts"
Cohesion: 0.24
Nodes (10): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, Int (+2 more)

### Community 170 - "README.md"
Cohesion: 0.18
Nodes (10): eventKind, financeCategory, issueArea, issueCategory, issueEntryKind, issueSeverity, issueStatus, recurrence (+2 more)

### Community 171 - "State"
Cohesion: 0.11
Nodes (21): ArraySlice, GlanceClause, alarm, chores, eventToday, happening, next, tonight (+13 more)

### Community 172 - "HomeView"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 173 - "Action"
Cohesion: 0.18
Nodes (11): CodingKeys, issuesChange, messagesChange, notes, notesChange, openIssues, openTasks, shoppingChange (+3 more)

### Community 174 - "MainFeature"
Cohesion: 0.31
Nodes (4): ReducerOf, Self, TaskArchiveFeature, TaskArchiveFeatureTests

### Community 175 - "Recipe"
Cohesion: 0.08
Nodes (22): Destination, compose, detail, history, Action, alert, delegate, detail (+14 more)

### Community 176 - "SpendCategory"
Cohesion: 0.33
Nodes (6): CodingKey, CodingKeys, changelogVersion, checkedAt, storeUrl, storeVersion

### Community 177 - "Kind"
Cohesion: 0.08
Nodes (28): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+20 more)

### Community 178 - "MainFeature"
Cohesion: 0.09
Nodes (22): Layout, CurrencyDefaults, Shared<String?>, SharedKey, HomeID, Self, String, Action (+14 more)

### Community 179 - "KeyboardDismisser"
Cohesion: 0.20
Nodes (9): CancelID, events, stats, Delegate, open, openMessages, State, HomeID (+1 more)

### Community 180 - "Action"
Cohesion: 0.28
Nodes (8): AddedCount, DependencyValues, ShoppingClient, async, Error, Int, ShoppingItemID, Void

### Community 181 - "TaskEdit"
Cohesion: 0.11
Nodes (28): CGPoint, Arc, BalanceBars, Bill, Bill.Urgency, BillCycle, BudgetProgress.Health, BudgetRing (+20 more)

### Community 183 - "ManageHomesFeature.swift"
Cohesion: 0.10
Nodes (21): Alert, confirmDelete, confirmEndRound, AlertState, CancelID, detail, polls, Destination (+13 more)

### Community 184 - "State"
Cohesion: 0.25
Nodes (7): Alert, CancelID, badge, categories, feed, Delegate, open

### Community 185 - "FinanceFeature"
Cohesion: 0.10
Nodes (23): parts, Alert, confirmEndRound, AlertState, Cuisine, Delegate, finished, Kind (+15 more)

### Community 186 - "Community 186"
Cohesion: 0.32
Nodes (6): ComposeTaskSheet, StoreOf, String, Void, TaskListRow, TasksView

### Community 187 - ".send"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 188 - "recipes.ts"
Cohesion: 0.30
Nodes (6): CalendarDay, Calendar, Self, MonthGrid, Calendar, String

### Community 189 - "Community 189"
Cohesion: 0.20
Nodes (7): Data, Error, Any, Bool, Data, Error, UIApplication

### Community 190 - "State"
Cohesion: 0.15
Nodes (16): CreateMovieListSheet, ListChip, ListRow, MovieInfoSheet, MovieListView, MoviesView, PosterCard, Bool (+8 more)

### Community 191 - "Delegate"
Cohesion: 0.30
Nodes (4): CaptureParser, Calendar, Locale, S

### Community 192 - "Community 192"
Cohesion: 0.09
Nodes (18): ComposableArchitecture, CoreGraphics, Foundation, NestZone, DependencyValues, async, String, UsersClient (+10 more)

### Community 193 - "ConfirmationDialogState"
Cohesion: 0.33
Nodes (8): Avatar, Source, directory, photo, Bool, CGFloat, String, URL

### Community 194 - "CalendarView"
Cohesion: 0.09
Nodes (21): HomeStats, Decoder, Int, Action, delegate, statsUpdated, task, tileTapped (+13 more)

### Community 195 - "Cuisine"
Cohesion: 0.09
Nodes (26): Hasher, GlassTextField, Bool, LocalizedStringResource, String, Binding, Fallback, IssueDetailView (+18 more)

### Community 197 - "Community 197"
Cohesion: 0.11
Nodes (21): Equatable, EventScope, occurrence, series, Alert, CalendarFeature.Destination.State, PendingDelete, Scope (+13 more)

### Community 198 - "crons.ts"
Cohesion: 0.13
Nodes (16): Alert, confirmDeleteList, AlertState, CreateMovieListFeature, Delegate, openMovieNight, Destination, createList (+8 more)

### Community 199 - "ChoiceCard"
Cohesion: 0.33
Nodes (6): ChoiceCard, HomeRow, Bool, LocalizedStringResource, String, Void

### Community 200 - "NewShoppingItem"
Cohesion: 0.22
Nodes (5): KeyboardDismisser, Bool, UIGestureRecognizer, UIGestureRecognizerDelegate, UITouch

### Community 201 - "PhotoZoom"
Cohesion: 0.39
Nodes (5): PhotoZoom, Bool, CGFloat, CGSize, Self

### Community 202 - "CancelID"
Cohesion: 0.33
Nodes (6): DependencyValues, NotesClient, async, Error, HomeID, Void

### Community 203 - "StatTile"
Cohesion: 0.13
Nodes (15): PushRegistration, failed, none, registered, Bool, String, State, Action (+7 more)

### Community 205 - "Community 205"
Cohesion: 0.10
Nodes (21): Alert, CancelID, conversations, messages, Delegate, renamed, Destination, compose (+13 more)

### Community 206 - "CoreLogicTests"
Cohesion: 0.20
Nodes (9): CodingKeys, body, color, created, createdBy, homeID, id, image (+1 more)

### Community 207 - "IssuesFeature"
Cohesion: 0.22
Nodes (8): App, AppDelegate, NestZoneApp, View, NSObject, Scene, UIApplicationDelegate, UNUserNotificationCenterDelegate

### Community 208 - "PollsClient"
Cohesion: 0.33
Nodes (5): ComposeTaskFeature, Destination, compose, ReducerOf, Self

### Community 209 - "Urgency"
Cohesion: 0.11
Nodes (19): ConvexMobile, CatalogClient, DependencyValues, MovieDetails, async, APNSEnvironment, DependencyValues, DevicesClient (+11 more)

### Community 211 - "AvatarPickerFace"
Cohesion: 0.24
Nodes (8): ComposeNoteSheet, NoteCard, NotesView, Bool, Content, StoreOf, String, Void

### Community 212 - "Source"
Cohesion: 0.40
Nodes (4): Delegate, capture, openEvent, openMovieNight

### Community 213 - "SymbolBounceModifier"
Cohesion: 0.15
Nodes (13): CodingKeys, created, cuisine, date, event, homeID, id, kind (+5 more)

### Community 214 - "Delegate"
Cohesion: 0.12
Nodes (18): Double, AffectedCount, DependencyValues, IssueEdit, IssuesClient, ScheduledVisit, async, ConvexEncodable (+10 more)

### Community 215 - "CancelID"
Cohesion: 0.26
Nodes (11): Difficulty, easy, hard, medium, Recipe, Decoder, HomeID, Int (+3 more)

### Community 216 - "UndoToast"
Cohesion: 0.13
Nodes (17): pending, members, Pending, State, Action, AlertState, Bool, ConversationID (+9 more)

### Community 217 - "IssueComposerFeature"
Cohesion: 0.40
Nodes (4): CancelID, members, tasks, undo

### Community 218 - "InboxAdminFeature"
Cohesion: 0.21
Nodes (8): ASAuthorization, AuthenticationServices, AuthFeature, ReducerOf, Self, AuthView, Error, StoreOf

### Community 219 - "Community 219"
Cohesion: 0.25
Nodes (9): MovieList, StoredMovie, Bool, Decoder, HomeID, Kind, MovieListID, StoredMovieID (+1 more)

### Community 220 - "CancelID"
Cohesion: 0.50
Nodes (4): CancelID, detail, polls, recipes

### Community 221 - "Community 221"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 222 - "Alert"
Cohesion: 0.50
Nodes (6): NewShoppingItem, RecipeIngredients, Double, HomeID, RecipeID, String

### Community 223 - "Community 223"
Cohesion: 0.43
Nodes (4): CurrencyPicker, Bool, String, Void

### Community 224 - "Community 224"
Cohesion: 0.11
Nodes (24): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+16 more)

### Community 226 - "HomeStats"
Cohesion: 0.29
Nodes (7): CancelID, bills, events, issues, members, stats, tasks

### Community 227 - "AppSettings.swift"
Cohesion: 0.12
Nodes (15): Alert, confirmDelete, confirmQuit, Delegate, decideDinner, openEvent, openShoppingList, Phase (+7 more)

### Community 228 - "Community 228"
Cohesion: 0.40
Nodes (4): c, http, iv, t0

### Community 229 - "FinanceFeature"
Cohesion: 0.29
Nodes (7): CancelID, clock, events, meals, members, polls, stats

### Community 231 - "StepDuration"
Cohesion: 0.33
Nodes (6): Delegate, deleteRequested, openEvent, openShoppingList, EventID, IssueID

### Community 233 - "PasteboardClient"
Cohesion: 0.18
Nodes (11): DockItem, add, dinner, dinnerSuggestion, dinnerUndecided, happening, movieRound, startingSoon (+3 more)

### Community 234 - "Community 234"
Cohesion: 0.50
Nodes (3): client, iv, started

### Community 235 - "Community 235"
Cohesion: 0.22
Nodes (7): AlertState, ComposeRecipeFeature, Destination, compose, detail, ReducerOf, Self

### Community 236 - "Scope"
Cohesion: 0.28
Nodes (7): State, Action, AlertState, Bool, HomeID, Set, UserID

### Community 237 - "AvatarSourceSheet"
Cohesion: 0.14
Nodes (12): Alert, confirmClearLeftovers, AlertState, CancelID, plan, ConfirmationDialogState, Scope, deleteAll (+4 more)

### Community 238 - "AvatarViewerBar"
Cohesion: 0.17
Nodes (7): RecipesFeature, PhotoUpload, RelativeTimeTests, SavedRecipeTests, RecipeID, String, TimeInterval

### Community 239 - "CancelID"
Cohesion: 0.15
Nodes (11): UserID, Alert, CancelID, board, handoff, members, undo, Delegate (+3 more)

### Community 240 - "PollCandidate"
Cohesion: 0.67
Nodes (3): Alert, confirmDelete, TaskID

### Community 243 - "Alert"
Cohesion: 0.20
Nodes (9): Backend notes, Commands, Conventions, graphify, Layout, Navigation, NestZone, One deployment, every app version (+1 more)

### Community 245 - "Community 245"
Cohesion: 0.07
Nodes (29): EventKind, anniversary, appointment, birthday, chore, cinema, concert, deadline (+21 more)

### Community 247 - "IssuePhotoIDs"
Cohesion: 0.24
Nodes (9): ReleaseCheck, Decoder, String, URL, UpdateCheck, checking, failed, idle (+1 more)

### Community 248 - "CancelID"
Cohesion: 0.60
Nodes (3): AvatarRollback, String, URL

### Community 249 - ".newestFirst"
Cohesion: 0.32
Nodes (5): Animation, EditNameSheet, SettingsView, StoreOf, String

### Community 252 - "BillCycle"
Cohesion: 0.42
Nodes (7): NewTask, Bool, ConvexEncodable, HomeID, String, UserID, TaskEdit

### Community 253 - "IssueComposerFeature"
Cohesion: 0.32
Nodes (5): HouseStatsFeature, ReducerOf, Self, HouseStatsView, StoreOf

### Community 254 - "PushRegistration"
Cohesion: 0.12
Nodes (16): Comparable, CustomStringConvertible, ExpressibleByStringLiteral, AppUpdate, AppVersion, Bool, Int, String (+8 more)

### Community 255 - "HomeStats"
Cohesion: 0.05
Nodes (53): CurrencyTotal, EventHistory, EventOccurrence, EventPlan, EventReminder, atTime, oneDay, oneHour (+45 more)

### Community 256 - "CancelID"
Cohesion: 0.28
Nodes (6): MealPlan, NowDock, Bool, StoreOf, String, Text

### Community 258 - "HomesClient"
Cohesion: 0.14
Nodes (14): DependencyKey, DependencyValues, StatsClient, Error, HomeID, DependencyValues, async, Error (+6 more)

### Community 259 - "HomeManagementFeature.swift"
Cohesion: 0.29
Nodes (7): DependencyValues, MoviesClient, async, Error, HomeID, MovieListID, Void

### Community 260 - "Alert"
Cohesion: 0.33
Nodes (6): Alert, confirmClearCategory, confirmClearEvent, confirmClearMeal, confirmClearParts, confirmClearPurchased

### Community 261 - "IssuesFeature"
Cohesion: 0.29
Nodes (7): DependencyValues, PollsClient, async, Error, HomeID, PollID, Void

### Community 262 - "ArchiveRow"
Cohesion: 0.33
Nodes (5): ArchiveRow, Bool, StoreOf, String, TaskArchiveView

### Community 263 - "Community 263"
Cohesion: 0.14
Nodes (7): CalendarMonth, Calendar, Self, FinanceTests, BillID, Duration, ExpenseID

### Community 265 - ".image"
Cohesion: 0.50
Nodes (3): IssueDetailFeature, ReducerOf, Self

### Community 267 - "Section"
Cohesion: 0.29
Nodes (6): DayPart, afternoon, evening, morning, night, Calendar

### Community 268 - "CancelID"
Cohesion: 0.50
Nodes (3): IssueComposerFeature, ReducerOf, Self

### Community 269 - ".userNotificationCenter"
Cohesion: 0.40
Nodes (4): Void, UNNotification, UNNotificationPresentationOptions, UNUserNotificationCenter

### Community 270 - "Community 270"
Cohesion: 0.38
Nodes (6): State, AlertState, HomeID, IdentifiedArrayOf, Never, UserID

### Community 271 - "StepDuration"
Cohesion: 0.50
Nodes (4): StepDuration, Int, Substring, Regex

### Community 275 - "CancelID"
Cohesion: 0.33
Nodes (6): CancelID, addConfirmation, meals, saved, shopping, timer

### Community 279 - "Community 279"
Cohesion: 0.47
Nodes (4): PhotoUpload, Data, Int, String

### Community 281 - "Community 281"
Cohesion: 0.10
Nodes (22): CodingKeys, avatar, avatarURL, created, email, homeIDs, id, name (+14 more)

### Community 292 - "Community 292"
Cohesion: 0.04
Nodes (59): Action, allDayToggled, attendeeToggled, binding, delegate, deleteTapped, doneTapped, draftItemRemoved (+51 more)

## Knowledge Gaps
- **2050 isolated node(s):** `id`, `targets`, `launching`, `signedOut`, `offline` (+2045 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Community 192` to `What-To-Watch Voting`, `Model Coding Keys`, `Realtime Event Manager`, `DTO Coding Keys`, `Home Creation & Tasks`, `Management Tab ViewModel`, `Messages Manager`, `List & Difficulty Enums`, `Note Color Extensions`, `Community 32`, `Community 34`, `Community 35`, `App Services Core`, `Chat Detail`, `No-Homes Onboarding`, `Read Receipts`, `Genre Picker`, `Recipe Card`, `Community 64`, `Search Results List`, `Vibrant Module Card`, `Message Input`, `Community 74`, `Custom List Row`, `Community 91`, `Community 102`, `Community 106`, `Community 109`, `Community 110`, `Community 120`, `Community 122`, `Community 124`, `Community 131`, `Community 132`, `Community 134`, `Community 135`, `Community 138`, `Community 140`, `Community 141`, `Community 144`, `Community 146`, `State`, `SectionHeader`, `Community 153`, `Community 163`, `SettingsView`, `HomeStats`, `Delegate`, `Recipe`, `Kind`, `KeyboardDismisser`, `Action`, `ManageHomesFeature.swift`, `State`, `FinanceFeature`, `CalendarView`, `Community 197`, `crons.ts`, `CancelID`, `StatTile`, `Community 205`, `CoreLogicTests`, `Urgency`, `Source`, `Delegate`, `CancelID`, `Community 224`, `AppSettings.swift`, `AvatarSourceSheet`, `CancelID`, `CancelID`, `PushRegistration`, `HomeStats`, `HomesClient`, `HomeManagementFeature.swift`, `IssuesFeature`, `Community 279`, `Community 281`, `Community 292`?**
  _High betweenness centrality (0.117) - this node is a cross-community bridge._
- **Why does `L10n` connect `Recipe Theming` to `Movie UI Components`, `Community 35`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **Why does `AppError` connect `No-Homes Onboarding` to `Community 128`, `HomesClient`, `HomeManagementFeature.swift`, `Community 132`, `Model Coding Keys`, `Community 134`, `Realtime Event Manager`, `DTO Coding Keys`, `Messages View`, `PocketBase Networking`, `Community 142`, `Home Creation & Tasks`, `New Recipe Sheet`, `Sample Recipes`, `SectionHeader`, `Community 153`, `Movie List Detail`, `RecipeDetailFeature`, `Community 33`, `Community 292`, `Auth Manager`, `Simple Movie Detail`, `App Services Core`, `Movie Search Row`, `Recipe`, `New Message Group`, `Kind`, `Previous Polls`, `Poll Input Sheets`, `Action`, `Note Creator`, `Community 54`, `Read Receipts`, `Switch Home Sheet`, `Recipe Card`, `Edit Note Sheet`, `Community 192`, `Community 64`, `Community 197`, `Vibrant Module Card`, `CancelID`, `Community 75`, `Urgency`, `Community 85`, `Delegate`, `Community 86`, `UndoToast`, `InboxAdminFeature`, `Community 98`, `Community 105`, `MovieList.Kind`, `AvatarViewerBar`, `Community 115`, `Community 120`, `Community 121`, `Community 122`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **What connects `id`, `targets`, `launching` to the rest of the system?**
  _2050 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.0655367231638418 - nodes in this community are weakly interconnected._
- **Should `Localization Strings` be split into smaller, more focused modules?**
  _Cohesion score 0.03913273400317292 - nodes in this community are weakly interconnected._
- **Should `Model Coding Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.08374384236453201 - nodes in this community are weakly interconnected._