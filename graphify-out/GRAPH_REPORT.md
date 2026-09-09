# Graph Report - NestZone  (2026-09-10)

## Corpus Check
- 173 files · ~416,787 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4670 nodes · 9950 edges · 229 communities (220 shown, 9 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 325 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0125be1e`
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
- schema.ts
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
- CancelID
- .send
- recipes.ts
- CancelID
- AppFeature
- Delegate
- EventDetailFeature
- ConfirmationDialogState
- CalendarView
- Cuisine
- Action
- MemberRow
- crons.ts
- ChoiceCard
- NewShoppingItem
- CoreLogicTests
- CancelID
- DecodingTests
- AuthFeature.swift
- NotesClient
- NotesFeature
- IssuesFeature
- EventScope
- Urgency
- Delegate
- PlanSection
- AppSettings.swift
- .save
- Delegate
- CancelID
- Delegate
- IssueComposerFeature
- Confirm
- Action
- CancelID
- PushRegistration
- Alert
- TasksClient
- FinanceFeature.swift
- Alert
- StepDuration
- ConfirmationDialogState
- CancelID

## God Nodes (most connected - your core abstractions)
1. `L10n` - 152 edges
2. `Timestamp` - 84 edges
3. `CodingKeys` - 79 edges
4. `AppError` - 76 edges
5. `ComposableArchitecture` - 73 edges
6. `Date` - 73 edges
7. `User` - 73 edges
8. `Foundation` - 72 edges
9. `EventOccurrence` - 67 edges
10. `Action` - 64 edges

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

## Communities (229 total, 9 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.12
Nodes (18): ContentMode, KeyedDecodingContainer, Int, T, DecodedImageCache, ImageLoader, ImagePlaceholder, Key (+10 more)

### Community 1 - "Localization Strings"
Cohesion: 0.28
Nodes (4): DependencyValues, CalendarFeatureTests, Double, Void

### Community 2 - "Model Coding Keys"
Cohesion: 0.17
Nodes (20): HouseHealthRing, IssueArea, IssueCategory, IssuePhoto, IssuePhotoStrip, IssueSeverity, IssueStatus, MeTooButton (+12 more)

### Community 3 - "Confetti & Realtime Models"
Cohesion: 0.09
Nodes (61): Codable, Hashable, Identifiable, AreaCount, CategoryCount, HouseIssue, IssueBoard, IssueCategory (+53 more)

### Community 4 - "Movie API (TMDb)"
Cohesion: 0.18
Nodes (15): Kind, generic, movie, recipe, PollVote, Status, active, closed (+7 more)

### Community 5 - "Recipe Theming"
Cohesion: 0.05
Nodes (6): L10n, Int, Locale, LocalizedStringResource, String, StaticString

### Community 6 - "Movie List Model"
Cohesion: 0.04
Nodes (51): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+43 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.09
Nodes (23): AuthProvider, CheckedContinuation, ConvexClient, escaping, LocalizedError, AsyncSemaphore, ConvexAppleAuthProvider, ConvexAuthError (+15 more)

### Community 8 - "Movie UI Components"
Cohesion: 0.06
Nodes (34): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+26 more)

### Community 9 - "Polls Manager"
Cohesion: 0.14
Nodes (13): Footer, Palette, StickyColor, blue, green, orange, pink, purple (+5 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.16
Nodes (15): Alert, confirmClearCategory, confirmClearEvent, confirmClearMeal, confirmClearParts, confirmClearPurchased, ClearTarget, category (+7 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.06
Nodes (34): Action, allDayToggled, attendeeToggled, binding, delegate, deleteTapped, doneTapped, draftItemRemoved (+26 more)

### Community 12 - "Messages View"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.06
Nodes (32): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+24 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.05
Nodes (40): Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped, conversationsUpdated (+32 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.17
Nodes (11): BindableAction, Action, binding, failed, finished, submitTapped, succeeded, State (+3 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.04
Nodes (52): CodingKeys, amount, attendees, budget, category, cookTime, created, createdBy (+44 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.14
Nodes (16): Layout, Action, EmptyStateView, Action, Bool, LocalizedStringResource, String, Void (+8 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.08
Nodes (18): AppFeature, ReducerOf, Self, AppView, StoreOf, Home, HomeAddress, Decoder (+10 more)

### Community 19 - "Management Tab ViewModel"
Cohesion: 0.19
Nodes (16): Category, cleaning, groceries, household, other, ShoppingItem, Bool, Decoder (+8 more)

### Community 20 - "Notes ViewModel"
Cohesion: 0.06
Nodes (31): Action, addMoviesTapped, addTapped, alert, allMoviesUpdated, binding, createListTapped, deleteListTapped (+23 more)

### Community 21 - "Unit & UI Tests"
Cohesion: 0.13
Nodes (9): LaunchUITests, Bool, SmokeFlowUITests, String, XCUIApplication, XCUIApplication, TabNavigationUITests, XCTest (+1 more)

### Community 22 - "Match & Poll Summary"
Cohesion: 0.16
Nodes (16): AddedToListToast, ComposeRecipeSheet, CookingModeView, Fact, RecipeCard, RecipeDetailView, RecipesView, Binding (+8 more)

### Community 23 - "Messages Manager"
Cohesion: 0.19
Nodes (12): State, Action, AlertState, Bool, ConfirmationDialogState, IdentifiedArrayOf, Int, Set (+4 more)

### Community 24 - "Home Tab Screen"
Cohesion: 0.06
Nodes (32): Action, alert, binding, copyInviteCodeTapped, copyPushTokenTapped, delegate, destination, deviceRowTapped (+24 more)

### Community 25 - "PocketBase Models"
Cohesion: 0.17
Nodes (19): Angle, Command, DeckSkeleton, MovieNightView, PollHistoryRow, PollKindSheet, PollOutcomeView, Bool (+11 more)

### Community 26 - "Movie Detail Sheet"
Cohesion: 0.08
Nodes (24): @auth/core, dependencies, @auth/core, convex, @convex-dev/auth, jose, description, devDependencies (+16 more)

### Community 27 - "Cooking Mode"
Cohesion: 0.19
Nodes (13): Expense, ExpenseSplit, ExpenseWeight, NewExpense, SplitMode, equal, exact, shares (+5 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.08
Nodes (27): currentUserId(), requireDocHome(), requireHomeMember(), create, listByHome, remove, update, addItem (+19 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.15
Nodes (6): Self, FinanceTests, BillID, ExpenseID, Int, String

### Community 30 - "Movie List Detail"
Cohesion: 0.08
Nodes (30): checkedRecipes(), create, ensurePresetLists, get, join, leave, listMine, members (+22 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.12
Nodes (18): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+10 more)

### Community 32 - "Community 32"
Cohesion: 0.11
Nodes (23): Animatable, Configuration, GeometryEffect, IntegerFormatStyle, AnimatedNumber, AppearModifier, ButtonStyle, Motion (+15 more)

### Community 33 - "Community 33"
Cohesion: 0.06
Nodes (32): Action, addOnDayTapped, addTapped, alert, binding, daySelected, deleteCommitFailed, deleteTapped (+24 more)

### Community 34 - "Community 34"
Cohesion: 0.15
Nodes (11): App, AppDelegate, NestZoneApp, Void, NSObject, Scene, UIApplicationDelegate, UNNotification (+3 more)

### Community 35 - "Community 35"
Cohesion: 0.08
Nodes (36): Budget, BudgetProgress, CategoryTotal, EventSpend, FinanceSummary, Health, close, healthy (+28 more)

### Community 36 - "Auth Manager"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.06
Nodes (31): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+23 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.03
Nodes (60): CodingKeys, amount, autoSplit, billID, budget, budgets, categories, category (+52 more)

### Community 40 - "Community 40"
Cohesion: 0.10
Nodes (32): MealPlanID, MealPlan, Cuisine, HomeID, Kind, Recipe, UserID, AlreadyDecidedBanner (+24 more)

### Community 41 - "App Services Core"
Cohesion: 0.13
Nodes (20): AnyCancellable, Combine, ConvexClientWithAuth, ArgumentBox, CancellableBox, CancellableBoxPublic, ConnectionState, ConvexConnection (+12 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.27
Nodes (10): ContributionDay, ContributionSlice, Count, HomeContributions, MemberContribution, Bool, Double, Int (+2 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.13
Nodes (14): Alert, confirmSignOut, AlertState, CancelID, copyReset, members, pushTokenCopyReset, Destination (+6 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.13
Nodes (14): Comparable, CalendarDay, Calendar, Self, CalendarMonth, Calendar, Date, CountdownText (+6 more)

### Community 46 - "Community 46"
Cohesion: 0.20
Nodes (11): Alert, confirmEndRound, Cuisine, Delegate, finished, MealPlan.Kind, Source, custom (+3 more)

### Community 47 - "New Message Group"
Cohesion: 0.15
Nodes (14): pending, path, members, State, Action, AlertState, Bool, Destination (+6 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.16
Nodes (13): LockIsolated, Conversation, Message, Bool, ConversationID, Decoder, HomeID, Kind (+5 more)

### Community 49 - "Previous Polls"
Cohesion: 0.19
Nodes (11): AppTheme, basic, cyberpunk, deepOcean, neonNight, retroWave, EnvironmentValues, Palette (+3 more)

### Community 50 - "Theme Selection"
Cohesion: 0.11
Nodes (17): Action, appEnteredForeground, auth, authStatusChanged, currentUserChanged, deviceRegistered, deviceRegistrationFailed, deviceTokenReceived (+9 more)

### Community 51 - "Recipe List View"
Cohesion: 0.11
Nodes (35): EventOccurrence, EventPlan, EventReminder, atTime, oneDay, oneHour, oneWeek, tenMinutes (+27 more)

### Community 52 - "Read Receipts"
Cohesion: 0.10
Nodes (21): Alert, confirmDelete, confirmEndRound, AlertState, CancelID, detail, polls, Destination (+13 more)

### Community 53 - "Note Creator"
Cohesion: 0.03
Nodes (76): CodingKeys, ageDays, amount, area, assignedTo, authorID, blockedReason, body (+68 more)

### Community 54 - "Community 54"
Cohesion: 0.15
Nodes (15): CatalogQuery, Kind, actor, decade, director, genre, nowPlaying, popular (+7 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.08
Nodes (26): Action, alert, clearDinnerTapped, decideDinnerTapped, delegate, dinner, dinnerSuggestionAccepted, dinnerSuggestionSaved (+18 more)

### Community 56 - "Home Selection View"
Cohesion: 0.09
Nodes (22): Action, home, homePath, hub, messages, notes, settings, tabSelected (+14 more)

### Community 57 - "Switch Home Sheet"
Cohesion: 0.12
Nodes (13): Error, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline, server (+5 more)

### Community 58 - "Genre Picker"
Cohesion: 0.11
Nodes (19): CodingKeys, created, entityType, externalID, genre, homeID, id, isYes (+11 more)

### Community 59 - "Swipe Card"
Cohesion: 0.10
Nodes (23): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+15 more)

### Community 60 - "Recipe Card"
Cohesion: 0.05
Nodes (42): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+34 more)

### Community 61 - "Chat Messages List"
Cohesion: 0.42
Nodes (8): ButtonRole, IconButton, PrimaryButton, SecondaryButton, Bool, LocalizedStringResource, String, Void

### Community 63 - "Auth DTOs"
Cohesion: 0.11
Nodes (17): compilerOptions, allowJs, esModuleInterop, isolatedModules, lib, module, moduleResolution, noEmit (+9 more)

### Community 64 - "Community 64"
Cohesion: 0.23
Nodes (13): createRecipe(), DependencyValues, NewRecipe, RecipesClient, async, AsyncThrowingStream, Bool, Error (+5 more)

### Community 65 - "Community 65"
Cohesion: 0.10
Nodes (9): AlertState, DinnerFeature, ReducerOf, Self, HomeFeature, ReducerOf, DinnerTests, HomeFeatureTests (+1 more)

### Community 66 - "Loading Button"
Cohesion: 0.17
Nodes (17): ClosedRange, RSVPStatus, declined, going, maybe, DayCell, DayTimeline, EventRow (+9 more)

### Community 67 - "Preset List Card"
Cohesion: 0.12
Nodes (15): Alert, confirmLeave, AlertState, CancelID, homes, HomeManagementFeature.Destination.State, State, Action (+7 more)

### Community 68 - "Search Results List"
Cohesion: 0.06
Nodes (36): AuthenticationServices, ComposableArchitecture, ConvexMobile, DependencyKey, CatalogClient, DependencyValues, async, DependencyValues (+28 more)

### Community 69 - "Language Selection"
Cohesion: 0.12
Nodes (17): members, State, Action, AlertState, Bill, BillID, Bool, Destination (+9 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.15
Nodes (13): Color, String, Backdrop, BudgetProgress.Health, StatTile, Int, LocalizedStringResource, String (+5 more)

### Community 71 - "Vibrant Module Card"
Cohesion: 0.16
Nodes (17): DependencyValues, EventEdit, EventsClient, StockUpResult, async, AsyncThrowingStream, Bool, ConvexEncodable (+9 more)

### Community 72 - "Chat Header"
Cohesion: 0.16
Nodes (13): State, StepTimer, Action, AlertState, Bool, Destination, Double, HomeID (+5 more)

### Community 73 - "Message Input"
Cohesion: 0.11
Nodes (20): Equatable, Alert, State, Action, AlertState, Alert, CalendarFeature.Destination.State, Alert (+12 more)

### Community 74 - "Community 74"
Cohesion: 0.18
Nodes (11): AddItemField, DisclosureRow, EventComposerToolbar, EventDetailSheet, RecipePickerSheet, Bool, LocalizedStringResource, Recipe (+3 more)

### Community 75 - "Community 75"
Cohesion: 0.12
Nodes (9): Foundation, NestZone, BillComposerTests, ExpenseComposerTests, PresetListTests, SettleUpTests, Bill, IdentifiedArrayOf (+1 more)

### Community 76 - "Custom List Row"
Cohesion: 0.20
Nodes (15): BillCycle, State, AlertState, Bill, Bool, EventID, HomeID, IdentifiedArrayOf (+7 more)

### Community 77 - "Overlay Views"
Cohesion: 0.11
Nodes (19): MovieGenre, action, adventure, animation, comedy, crime, documentary, drama (+11 more)

### Community 78 - "Message Hashing"
Cohesion: 0.11
Nodes (19): Action, alert, authorsResolved, binding, colorSelected, composeTapped, deleteFailed, deleteTapped (+11 more)

### Community 79 - "Management Tab Screen"
Cohesion: 0.10
Nodes (25): Anchor, Avatar, AvatarStack, Member, CGFloat, Int, String, BubbleActionsAnchor (+17 more)

### Community 80 - "Community 80"
Cohesion: 0.24
Nodes (6): HubFeature, Duration, ReducerOf, Self, HubCountsTests, HubNavigationTests

### Community 81 - "Note Card"
Cohesion: 0.22
Nodes (9): Delegate, deleted, deleteRequested, paid, saved, settled, BillID, BudgetID (+1 more)

### Community 82 - "Community 82"
Cohesion: 0.16
Nodes (11): CancelID, bills, budgets, expenses, summary, undo, FinanceFeature, Duration (+3 more)

### Community 83 - "Community 83"
Cohesion: 0.10
Nodes (20): Action, alert, binding, composeTapped, deleteTapped, destination, failed, finished (+12 more)

### Community 84 - "Create Movie List"
Cohesion: 0.06
Nodes (33): addMonths(), billCycle, createBill, createExpense, Cycle, DueNudge, financeCategory, listBills (+25 more)

### Community 85 - "Community 85"
Cohesion: 0.05
Nodes (43): Action, addPartsTapped, alert, assignFailed, assignTapped, binding, confirm, delegate (+35 more)

### Community 86 - "Community 86"
Cohesion: 0.07
Nodes (33): addItems, cleanWeekdays(), collect(), create, detail, EventDoc, eventKind, EventNudge (+25 more)

### Community 87 - "Notes View"
Cohesion: 0.05
Nodes (33): addParts, assign, attachPhotos, byHome, comment, create, detail, EntryKind (+25 more)

### Community 88 - "Task Priority"
Cohesion: 0.25
Nodes (12): CategoryHeader, GroupHeader, GroupMenu, ShoppingRow, ShoppingView, Bool, Int, Namespace (+4 more)

### Community 90 - "Community 90"
Cohesion: 0.08
Nodes (21): FALSY, openTasks(), outstandingItems(), outstandingNames(), category, create, createFromRecipe, listByHome (+13 more)

### Community 91 - "Community 91"
Cohesion: 0.27
Nodes (10): ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat, Double (+2 more)

### Community 92 - "Community 92"
Cohesion: 0.05
Nodes (42): CaseIterable, IssueArea, balcony, basement, bathroom, bedroom, exterior, garage (+34 more)

### Community 93 - "Community 93"
Cohesion: 0.32
Nodes (8): Cache, Recipe, SampleRecipe, SampleRecipeLoader, Bool, Int, Recipe, String

### Community 94 - "Community 94"
Cohesion: 0.28
Nodes (4): ContributionsMathTests, Int, String, UserID

### Community 95 - "Community 95"
Cohesion: 0.11
Nodes (29): CGPoint, Arc, BalanceBars, Bill, Bill.Urgency, BillCycle, BudgetRing, ConfettiBurst (+21 more)

### Community 96 - "Community 96"
Cohesion: 0.09
Nodes (27): CodingKeys, cookTime, created, createdBy, difficulty, homeID, id, image (+19 more)

### Community 97 - "Community 97"
Cohesion: 0.12
Nodes (16): CodingKeys, assignedTo, created, createdBy, details, dueDate, homeID, id (+8 more)

### Community 98 - "Community 98"
Cohesion: 0.24
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 99 - "Community 99"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (5): ⚠️ Auth caveat (the one real gotcha), Nestzone — PocketBase → Convex migration, Steps, Type/field mapping applied, What's here

### Community 101 - "Community 101"
Cohesion: 0.17
Nodes (14): IssueComposerSheet, IssueInlineError, IssueSheetToolbar, PartsSheet, StatusNoteSheet, Bool, Int, IssueArea (+6 more)

### Community 102 - "Community 102"
Cohesion: 0.11
Nodes (18): CodingKeys, category, created, createdBy, details, eventID, eventTitle, homeID (+10 more)

### Community 103 - "Community 103"
Cohesion: 0.07
Nodes (30): Action, addExpenseTapped, addItemTapped, alert, binding, bulkAddFinished, delegate, deleteTapped (+22 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.07
Nodes (29): EventScope, occurrence, series, CalendarFeature, CancelID, events, members, undo (+21 more)

### Community 106 - "Community 106"
Cohesion: 0.15
Nodes (13): CodingKeys, cleaning, completed, count, email, general, maintenance, name (+5 more)

### Community 107 - "Community 107"
Cohesion: 0.12
Nodes (27): CastMember, Kind, custom, watched, wishlist, Movie, MovieExtras, MovieList (+19 more)

### Community 108 - "Community 108"
Cohesion: 0.16
Nodes (12): Alert, confirmDelete, AlertState, CancelID, notes, ComposeNoteFeature, Destination, compose (+4 more)

### Community 109 - "Community 109"
Cohesion: 0.21
Nodes (11): apiKey(), details, discover, fetchJSON(), fetchPages(), GENRE_NAMES, GENRES, TMDbCredit (+3 more)

### Community 110 - "Community 110"
Cohesion: 0.18
Nodes (11): CancelID, members, tasks, State, Action, AlertState, Bool, Destination (+3 more)

### Community 111 - "Community 111"
Cohesion: 0.18
Nodes (10): AppLanguage, english, system, turkish, L10n, Locale, Delegate, homeSwitched (+2 more)

### Community 112 - "Community 112"
Cohesion: 0.11
Nodes (22): SectionHeader, LocalizedStringResource, String, MovieListFeature, MoviesFeature, AddMoviesSheet, CreateMovieListSheet, ListChip (+14 more)

### Community 113 - "Community 113"
Cohesion: 0.12
Nodes (10): ManageHomesFeature, ReducerOf, Self, ManageHomesSheet, Bool, LocalizedStringResource, StoreOf, String (+2 more)

### Community 114 - "Community 114"
Cohesion: 0.23
Nodes (12): DependencyValues, DinnerDecision, MealsClient, async, AsyncThrowingStream, Cuisine, Error, EventID (+4 more)

### Community 115 - "Community 115"
Cohesion: 0.20
Nodes (10): parts, Kind, cuisine, custom, recipe, Route, set, vote (+2 more)

### Community 116 - "Community 116"
Cohesion: 0.07
Nodes (29): EventKind, anniversary, appointment, birthday, chore, cinema, concert, deadline (+21 more)

### Community 117 - "Community 117"
Cohesion: 0.06
Nodes (34): Action, addTapped, advanceTapped, alert, areaFilterTapped, binding, boardUpdated, categoryFilterTapped (+26 more)

### Community 118 - "Community 118"
Cohesion: 0.33
Nodes (6): Backend notes, Commands, Conventions, graphify, Layout, NestZone

### Community 119 - "Community 119"
Cohesion: 0.18
Nodes (10): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Data cleanup + indexing (2026‑09‑03, deployed), NestZone backend — Convex deploy & data‑import runbook, Notes, Production hardening pass (2026‑09‑03), Referential integrity (2026‑09‑03), Reproducing the deploy + import (already executed) (+2 more)

### Community 120 - "Community 120"
Cohesion: 0.08
Nodes (30): IssueEdit, Action, areaTapped, assigneeTapped, binding, categoryTapped, delegate, failed (+22 more)

### Community 121 - "Community 121"
Cohesion: 0.22
Nodes (9): CodingKey, CodingKeys, address, created, id, inviteCode, members, name (+1 more)

### Community 122 - "Community 122"
Cohesion: 0.16
Nodes (17): PartsDraft, State, StatusNote, Action, AlertState, Bool, ConfirmationDialogState, Effect (+9 more)

### Community 123 - "Community 123"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 124 - "Community 124"
Cohesion: 0.13
Nodes (11): ShoppingFeature, Duration, ReducerOf, RecipeDetailFeature, RecipeShoppingTests, ShoppingTests, Duration, ShoppingItemID (+3 more)

### Community 125 - "Community 125"
Cohesion: 0.12
Nodes (4): Decimal, health, SplitMath, FinanceLogicTests

### Community 126 - "Community 126"
Cohesion: 0.14
Nodes (19): Decodable, Double, AffectedCount, DependencyValues, IssueEdit, IssuesClient, ScheduledVisit, async (+11 more)

### Community 127 - "Community 127"
Cohesion: 0.13
Nodes (16): members, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Int (+8 more)

### Community 128 - "Community 128"
Cohesion: 0.08
Nodes (24): Action, alert, binding, delegate, deleteTapped, everyoneTapped, failed, onlyMeTapped (+16 more)

### Community 129 - "Community 129"
Cohesion: 0.21
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, Set (+1 more)

### Community 130 - "Community 130"
Cohesion: 0.19
Nodes (18): BillRow, BudgetCard, DayHeader, EventSpendRow, ExpenseRow, FinanceView, PayerRow, Bill (+10 more)

### Community 131 - "Community 131"
Cohesion: 0.20
Nodes (9): CreateMovieListFeature, Destination, createList, list, MovieList.Kind, MoviesFeature.Destination.State, LocalizedStringResource, ReducerOf (+1 more)

### Community 132 - "Community 132"
Cohesion: 0.12
Nodes (16): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+8 more)

### Community 133 - "Community 133"
Cohesion: 0.10
Nodes (19): BillsTable, BudgetsTable, ConversationsTable, EventsTable, ExpensesTable, HomesTable, IssueCommentsTable, IssuesTable (+11 more)

### Community 134 - "Community 134"
Cohesion: 0.15
Nodes (18): AmountField, BillComposerSheet, BudgetEditorSheet, ComposerToolbar, ExpenseComposerSheet, InlineError, MemberLabel, mutating() (+10 more)

### Community 135 - "Community 135"
Cohesion: 0.19
Nodes (14): Seed, State, Action, Bool, ConfirmationDialogState, HomeID, IdentifiedArrayOf, Int (+6 more)

### Community 136 - "Community 136"
Cohesion: 0.26
Nodes (8): Binding, Bool, CGFloat, Content, Gesture, LocalizedStringResource, Void, SwipeToDelete

### Community 137 - "Community 137"
Cohesion: 0.18
Nodes (13): Poll, PollDetail, PollItem, PollOutcome, Result, agreed, closest, nothing (+5 more)

### Community 138 - "Community 138"
Cohesion: 0.15
Nodes (19): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+11 more)

### Community 139 - "Community 139"
Cohesion: 0.13
Nodes (15): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+7 more)

### Community 140 - "Community 140"
Cohesion: 0.15
Nodes (11): RelativeTime, RelativeTimeClock, Duration, Int, Never, Task, Text, Void (+3 more)

### Community 141 - "Community 141"
Cohesion: 0.13
Nodes (17): IssuesFeature, Duration, Effect, ReducerOf, Self, IssueRow, IssuesView, RowBadge (+9 more)

### Community 142 - "Community 142"
Cohesion: 0.18
Nodes (10): State, Action, AlertState, Bool, Double, Effect, HomeID, IdentifiedArrayOf (+2 more)

### Community 143 - "Community 143"
Cohesion: 0.31
Nodes (7): ComposeNoteSheet, NoteCard, NotesView, Bool, StoreOf, String, Void

### Community 144 - "Community 144"
Cohesion: 0.18
Nodes (13): PlanRow, PlanState, active, done, empty, Double, LocalizedStringResource, Namespace (+5 more)

### Community 145 - "Community 145"
Cohesion: 0.13
Nodes (15): Delegate, notificationsEnabled, openCalendar, openContributions, openEvent, openEventID, openIssues, openMessages (+7 more)

### Community 146 - "Community 146"
Cohesion: 0.24
Nodes (5): HomeManagementFeature, ReducerOf, HomeManagementView, StoreOf, HomeManagementTests

### Community 147 - "Community 147"
Cohesion: 0.25
Nodes (9): content, GlassCard, GlassGroup, Metrics, Bool, CGFloat, Content, View (+1 more)

### Community 148 - "Community 148"
Cohesion: 0.18
Nodes (11): CodingKeys, issuesChange, messagesChange, notes, notesChange, openIssues, openTasks, shoppingChange (+3 more)

### Community 149 - "Community 149"
Cohesion: 0.14
Nodes (11): CancelID, recipes, ConfirmationDialogState, RecipePickerFeature, Scope, deleteAll, deleteThisOne, saveAll (+3 more)

### Community 150 - "State"
Cohesion: 0.21
Nodes (10): CreateHomeFeature, JoinHomeFeature, ReducerOf, Self, Destination, create, join, Destination (+2 more)

### Community 151 - "SectionHeader"
Cohesion: 0.21
Nodes (18): Encodable, billArgs(), DependencyValues, expenseArgs(), ExpenseShareArgs, ExpenseWeightArgs, FinanceClient, monthArgs() (+10 more)

### Community 152 - "Community 152"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 153 - "Community 153"
Cohesion: 0.15
Nodes (13): assertParticipant(), create, listByHome, rename, requireUser(), assertAuthor(), assertParticipant(), edit (+5 more)

### Community 154 - "Alert"
Cohesion: 0.27
Nodes (4): ContributionsFeature, ReducerOf, Self, ContributionsFeatureTests

### Community 155 - "Community 155"
Cohesion: 0.24
Nodes (11): DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Int, String, UNAuthorizationStatus (+3 more)

### Community 156 - "Community 156"
Cohesion: 0.20
Nodes (10): Field, CreateHomeSheet, FormSheet, JoinHomeSheet, Bool, Int, LocalizedStringResource, StoreOf (+2 more)

### Community 157 - "Community 157"
Cohesion: 0.20
Nodes (10): ComposeTaskFeature, ReducerOf, Self, TasksFeature, ComposeTaskSheet, StoreOf, String, Void (+2 more)

### Community 158 - "Community 158"
Cohesion: 0.08
Nodes (23): CodingKeys, conversationID, created, file, homeID, id, isGroupChat, kind (+15 more)

### Community 159 - "Community 159"
Cohesion: 0.18
Nodes (8): AnyShapeStyle, CalendarView, Bool, Gesture, Int, LocalizedStringResource, StoreOf, UserID

### Community 160 - "RecipeDetailFeature"
Cohesion: 0.43
Nodes (5): Badge, Chip, Bool, String, Void

### Community 161 - "Community 161"
Cohesion: 0.40
Nodes (4): c, http, iv, t0

### Community 163 - "Community 163"
Cohesion: 0.50
Nodes (3): client, iv, started

### Community 164 - "SettingsView"
Cohesion: 0.24
Nodes (10): ContributionWindow, allTime, month, week, LocalizedStringResource, State, Action, AlertState (+2 more)

### Community 165 - "HomeStats"
Cohesion: 0.13
Nodes (15): Alert, confirmDelete, AlertState, BillComposerFeature, BudgetEditorFeature, ExpenseComposerFeature, PayBillFeature, ReducerOf (+7 more)

### Community 166 - "Delegate"
Cohesion: 0.20
Nodes (9): AlertState, CancelID, items, undo, ShoppingItem.Category, Int, LocalizedStringResource, Self (+1 more)

### Community 167 - "Cache"
Cohesion: 0.42
Nodes (7): NewTask, Bool, ConvexEncodable, HomeID, String, UserID, TaskEdit

### Community 169 - "schema.ts"
Cohesion: 0.20
Nodes (9): eventKind, financeCategory, issueArea, issueCategory, issueEntryKind, issueSeverity, issueStatus, recurrence (+1 more)

### Community 171 - "State"
Cohesion: 0.25
Nodes (8): ArraySlice, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Loaded

### Community 172 - "HomeView"
Cohesion: 0.20
Nodes (8): PlanSection, budget, menu, shopping, tickets, EventComposerSheet, Recurrence, StoreOf

### Community 174 - "MainFeature"
Cohesion: 0.20
Nodes (11): Alert, Destination, compose, Filter, all, done, open, HouseTask.Kind (+3 more)

### Community 175 - "Recipe"
Cohesion: 0.20
Nodes (9): CodingKeys, body, color, created, createdBy, homeID, id, image (+1 more)

### Community 176 - "SpendCategory"
Cohesion: 0.40
Nodes (3): RecipesFeature, SavedRecipeTests, RecipeID

### Community 177 - "Kind"
Cohesion: 0.47
Nodes (5): APNSEnvironment, DependencyValues, DevicesClient, String, Void

### Community 178 - "MainFeature"
Cohesion: 0.38
Nodes (4): PollCandidate, ConvexEncodable, String, DinnerCandidate

### Community 179 - "KeyboardDismisser"
Cohesion: 0.24
Nodes (9): State, Action, AlertState, Bool, Cuisine, HomeID, IdentifiedArrayOf, Int (+1 more)

### Community 180 - "Action"
Cohesion: 0.20
Nodes (9): Alert, CancelID, board, handoff, undo, Delegate, openEvent, openShoppingList (+1 more)

### Community 181 - "TaskEdit"
Cohesion: 0.06
Nodes (28): MainFeature.State, State, HomeID, Int, Tab, CodingKeys, avatar, created (+20 more)

### Community 182 - "HomesClient"
Cohesion: 0.29
Nodes (7): DependencyValues, HomesClient, async, AsyncThrowingStream, Error, HomeID, Void

### Community 183 - "ManageHomesFeature.swift"
Cohesion: 0.16
Nodes (13): Alert, confirmLeave, Delegate, dismissRequested, switchRequested, ManageHomesFeature.Destination.State, State, Action (+5 more)

### Community 184 - "State"
Cohesion: 0.25
Nodes (8): DependencyValues, MoviesClient, async, AsyncThrowingStream, Error, HomeID, MovieListID, Void

### Community 185 - "FinanceFeature"
Cohesion: 0.26
Nodes (8): Note, Decoder, HomeID, NoteID, String, UserID, NotesFeature, NotesTests

### Community 186 - "CancelID"
Cohesion: 0.14
Nodes (13): CancelID, authState, currentUser, deviceRegistration, deviceToken, foreground, Screen, choosingHome (+5 more)

### Community 187 - ".send"
Cohesion: 0.18
Nodes (10): Alert, enableNotifications, AlertState, CancelID, events, meals, members, stats (+2 more)

### Community 188 - "recipes.ts"
Cohesion: 0.10
Nodes (22): Action, countsUpdated, moduleTapped, path, showShoppingList, task, HubFeature.Path.State, IssueCounts (+14 more)

### Community 189 - "CancelID"
Cohesion: 0.50
Nodes (3): HomeStats, Decoder, Int

### Community 190 - "AppFeature"
Cohesion: 0.22
Nodes (7): AlertState, ComposeRecipeFeature, Destination, compose, detail, ReducerOf, Self

### Community 191 - "Delegate"
Cohesion: 0.14
Nodes (15): HubModule, calendar, finance, maintenance, movies, recipes, shopping, Bool (+7 more)

### Community 192 - "EventDetailFeature"
Cohesion: 0.09
Nodes (14): IssueEntryID, BinaryInteger, Bool, Decoder, Double, Encoder, Timestamp, Destination (+6 more)

### Community 193 - "ConfirmationDialogState"
Cohesion: 0.32
Nodes (5): Animation, EditNameSheet, SettingsView, StoreOf, String

### Community 194 - "CalendarView"
Cohesion: 0.27
Nodes (7): ASAuthorization, AuthFeature, ReducerOf, Self, AuthView, Error, StoreOf

### Community 195 - "Cuisine"
Cohesion: 0.06
Nodes (35): CodingKeys, created, cuisine, date, event, homeID, id, kind (+27 more)

### Community 196 - "Action"
Cohesion: 0.14
Nodes (13): Action, alert, binding, contributionsUpdated, loadFailed, task, Alert, CancelID (+5 more)

### Community 197 - "MemberRow"
Cohesion: 0.25
Nodes (7): ContributionsView, MemberRow, Bool, Double, Int, StoreOf, String

### Community 199 - "ChoiceCard"
Cohesion: 0.08
Nodes (20): Shared<String?>, SharedKey, HomeID, Self, GlassTextField, Binding, Bool, LocalizedStringResource (+12 more)

### Community 200 - "NewShoppingItem"
Cohesion: 0.20
Nodes (14): AddedCount, DependencyValues, NewShoppingItem, RecipeIngredients, ShoppingClient, async, AsyncThrowingStream, Double (+6 more)

### Community 201 - "CoreLogicTests"
Cohesion: 0.22
Nodes (8): Alert, CancelID, plan, Scope, deleteAll, deleteThisOne, editAll, editThisOne

### Community 202 - "CancelID"
Cohesion: 0.33
Nodes (6): CancelID, all, lists, movies, saved, search

### Community 205 - "NotesClient"
Cohesion: 0.22
Nodes (7): LaunchView, MainView, OfflineView, Void, MainFeature, ReducerOf, Self

### Community 206 - "NotesFeature"
Cohesion: 0.25
Nodes (7): Double, LocalizedStringResource, String, Verdict, even, lopsided, tilted

### Community 207 - "IssuesFeature"
Cohesion: 0.20
Nodes (7): Data, Error, Any, Bool, Data, Error, UIApplication

### Community 208 - "EventScope"
Cohesion: 0.25
Nodes (7): CustomStringConvertible, ExpressibleByStringLiteral, ConvexID, Decoder, Encoder, String, RawRepresentable

### Community 209 - "Urgency"
Cohesion: 0.14
Nodes (13): Bill, BillCycle, biweekly, monthly, once, quarterly, weekly, yearly (+5 more)

### Community 210 - "Delegate"
Cohesion: 0.17
Nodes (11): Alert, CancelID, detail, Confirm, delete, Delegate, deleteRequested, openEvent (+3 more)

### Community 211 - "PlanSection"
Cohesion: 0.67
Nodes (3): Loaded, Int, OptionSet

### Community 212 - "AppSettings.swift"
Cohesion: 0.25
Nodes (8): DependencyValues, PollsClient, async, AsyncThrowingStream, Error, HomeID, PollID, Void

### Community 214 - "Delegate"
Cohesion: 0.40
Nodes (5): Delegate, chose, deleted, saved, EventID

### Community 215 - "CancelID"
Cohesion: 0.28
Nodes (7): IssueDetailFeature, ReducerOf, Self, IssueDetailView, Bool, PhotosPickerItem, StoreOf

### Community 216 - "Delegate"
Cohesion: 0.40
Nodes (5): Delegate, deleted, edit, rsvpChanged, EventID

### Community 217 - "IssueComposerFeature"
Cohesion: 0.50
Nodes (3): IssueComposerFeature, ReducerOf, Self

### Community 218 - "Confirm"
Cohesion: 0.25
Nodes (5): KeyboardDismisser, Bool, UIGestureRecognizer, UIGestureRecognizerDelegate, UITouch

### Community 219 - "Action"
Cohesion: 0.25
Nodes (8): Action, alert, appleSignInFailed, appleSignInSucceeded, signInFailed, signInSucceeded, Alert, PresentationAction

### Community 220 - "CancelID"
Cohesion: 0.25
Nodes (8): CancelID, bills, events, handoff, issues, movies, recipes, shopping

### Community 221 - "PushRegistration"
Cohesion: 0.29
Nodes (6): PushRegistration, failed, none, registered, Bool, String

### Community 222 - "Alert"
Cohesion: 0.11
Nodes (18): Alert, confirmDelete, confirmQuit, CancelID, addConfirmation, meals, saved, shopping (+10 more)

### Community 223 - "TasksClient"
Cohesion: 0.33
Nodes (6): DependencyValues, async, AsyncThrowingStream, Error, Void, TasksClient

### Community 224 - "FinanceFeature.swift"
Cohesion: 0.33
Nodes (5): Alert, Delegate, openEvent, FinanceFeature.Destination.State, EventID

### Community 225 - "Alert"
Cohesion: 0.33
Nodes (5): Alert, confirmDeleteList, AlertState, MovieListID, Self

### Community 226 - "StepDuration"
Cohesion: 0.50
Nodes (4): StepDuration, Int, Regex, Substring

### Community 228 - "CancelID"
Cohesion: 0.50
Nodes (4): CancelID, detail, polls, recipes

## Knowledge Gaps
- **1612 isolated node(s):** `launching`, `signedOut`, `offline`, `choosingHome`, `main` (+1607 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Community 75` to `What-To-Watch Voting`, `Confetti & Realtime Models`, `Community 131`, `Community 133`, `Read Receipts`, `Realtime Event Manager`, `Community 137`, `Community 138`, `Sample Recipes`, `Management Tab ViewModel`, `Community 149`, `State`, `SectionHeader`, `Community 155`, `Community 158`, `Note Color Extensions`, `Community 35`, `HomeStats`, `Delegate`, `App Services Core`, `Chat Detail`, `Movie Search Row`, `Community 46`, `Recipe`, `MainFeature`, `Kind`, `Recipe List View`, `Action`, `TaskEdit`, `HomesClient`, `ManageHomesFeature.swift`, `Home Selection View`, `Switch Home Sheet`, `CancelID`, `State`, `.send`, `CancelID`, `recipes.ts`, `EventDetailFeature`, `Community 64`, `Cuisine`, `Search Results List`, `Action`, `Preset List Card`, `ChoiceCard`, `Vibrant Module Card`, `NewShoppingItem`, `Message Input`, `CoreLogicTests`, `Delegate`, `AppSettings.swift`, `PushRegistration`, `Community 93`, `TasksClient`, `Community 96`, `FinanceFeature.swift`, `Alert`, `Community 105`, `Community 107`, `Community 108`, `Community 111`, `Community 114`, `Community 120`, `Community 126`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `ChoiceCard` to `What-To-Watch Voting`, `Model Coding Keys`, `Community 130`, `Community 131`, `Community 134`, `Community 136`, `Polls Manager`, `Community 140`, `Community 141`, `Community 143`, `Community 144`, `Shopping List UI`, `Community 147`, `Community 149`, `Match & Poll Summary`, `PocketBase Models`, `Community 156`, `Community 157`, `RecipeDetailFeature`, `Community 32`, `Community 34`, `Community 40`, `MainFeature`, `Previous Polls`, `Recipe List View`, `Action`, `Read Receipts`, `recipes.ts`, `Chat Messages List`, `Delegate`, `ConfirmationDialogState`, `Loading Button`, `Search Results List`, `Action`, `Match Options Sheet`, `MemberRow`, `CoreLogicTests`, `Community 74`, `NotesClient`, `Management Tab Screen`, `Task Priority`, `Community 91`, `Alert`, `Community 95`, `FinanceFeature.swift`, `Community 101`, `Community 104`, `Community 105`, `Community 112`, `Community 113`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `AppError` connect `Switch Home Sheet` to `Community 128`, `Confetti & Realtime Models`, `Community 132`, `Movie List Model`, `Realtime Event Manager`, `Movie UI Components`, `Movie Lists Manager`, `Community 139`, `Community 141`, `Community 142`, `Home Creation & Tasks`, `Home Tab ViewModel`, `PocketBase Networking`, `Notes ViewModel`, `SectionHeader`, `Home Tab Screen`, `Note Color Extensions`, `Community 33`, `Premium Text Field`, `App Services Core`, `Poll Input Sheets`, `SpendCategory`, `HomesClient`, `Swipe Deck`, `State`, `Recipe Card`, `Community 64`, `CalendarView`, `Search Results List`, `Action`, `Vibrant Module Card`, `NewShoppingItem`, `Message Input`, `Message Hashing`, `Community 82`, `Community 83`, `Community 85`, `Action`, `TasksClient`, `Community 103`, `Community 105`, `Community 117`, `Community 120`, `Community 122`, `Community 124`, `Community 126`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **What connects `launching`, `signedOut`, `offline` to the rest of the system?**
  _1612 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.11742424242424243 - nodes in this community are weakly interconnected._
- **Should `Confetti & Realtime Models` be split into smaller, more focused modules?**
  _Cohesion score 0.0882716049382716 - nodes in this community are weakly interconnected._
- **Should `Recipe Theming` be split into smaller, more focused modules?**
  _Cohesion score 0.05035609551738584 - nodes in this community are weakly interconnected._