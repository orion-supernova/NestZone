# Graph Report - NestZone  (2026-09-08)

## Corpus Check
- 162 files · ~368,528 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4022 nodes · 8530 edges · 223 communities (214 shown, 9 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 331 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a677205d`
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
- Action
- EventDetailFeature
- RecipePickerFeature
- FinanceFeature
- State
- Verdict
- recipes.ts
- String
- AppFeature
- .phrase
- CancelID
- EventEdit
- CalendarView
- EventDetailFeature.swift
- DecodingTests
- BillCycle
- crons.ts
- DevicesClient
- NewShoppingItem
- NotesClient
- CancelID
- SectionHeader
- AuthFeature.swift
- HubFeature
- NewShoppingItem
- KeyboardDismisser
- StepDuration
- HubView
- Sparkline
- Tab
- MainFeature
- SectionHeader
- HubFeature.swift
- Path
- NotesFeature
- AppSettings.swift
- Scope
- MemberRow
- ConfirmationDialogState
- CancelID
- Alert

## God Nodes (most connected - your core abstractions)
1. `L10n` - 123 edges
2. `AppError` - 70 edges
3. `Timestamp` - 70 edges
4. `EventOccurrence` - 67 edges
5. `ComposableArchitecture` - 66 edges
6. `Foundation` - 66 edges
7. `Action` - 64 edges
8. `Date` - 63 edges
9. `User` - 63 edges
10. `Action` - 62 edges

## Surprising Connections (you probably didn't know these)
- `ManageHomesTests` --calls--> `Home`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Home.swift
- `MovieHandoffTests` --calls--> `MovieList`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Movie.swift
- `MovieHandoffTests` --calls--> `PollItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Poll.swift
- `ShoppingTests` --calls--> `ShoppingItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/ShoppingItem.swift
- `CalendarFeatureTests` --references--> `CalendarDay`  [EXTRACTED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/CalendarEvent.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Generic polls data model (polls, items, votes scoped to homes)** — docs_pocketbase_readme_polls, docs_pocketbase_readme_poll_items, docs_pocketbase_readme_poll_votes, docs_pocketbase_readme_homes [EXTRACTED 1.00]

## Communities (223 total, 9 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.11
Nodes (20): ContentMode, KeyedDecodingContainer, Int, T, DecodedImageCache, ImageLoader, ImagePlaceholder, Key (+12 more)

### Community 1 - "Localization Strings"
Cohesion: 0.28
Nodes (4): DependencyValues, CalendarFeatureTests, Double, Void

### Community 2 - "Model Coding Keys"
Cohesion: 0.16
Nodes (10): RelativeTime, RelativeTimeClock, Duration, Int, Never, Task, Void, NSObjectProtocol (+2 more)

### Community 3 - "Confetti & Realtime Models"
Cohesion: 0.11
Nodes (25): Expense, ExpenseSplit, NewBill, NewExpense, NewSettlement, SpendCategory, dining, entertainment (+17 more)

### Community 4 - "Movie API (TMDb)"
Cohesion: 0.18
Nodes (15): Kind, generic, movie, recipe, PollVote, Status, active, closed (+7 more)

### Community 5 - "Recipe Theming"
Cohesion: 0.06
Nodes (6): L10n, Int, Locale, LocalizedStringResource, String, StaticString

### Community 6 - "Movie List Model"
Cohesion: 0.04
Nodes (51): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+43 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.10
Nodes (22): AuthProvider, CheckedContinuation, ConvexClient, Decodable, escaping, LocalizedError, AsyncSemaphore, ConvexAppleAuthProvider (+14 more)

### Community 8 - "Movie UI Components"
Cohesion: 0.06
Nodes (34): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+26 more)

### Community 9 - "Polls Manager"
Cohesion: 0.12
Nodes (15): Alert, confirmLeave, AlertState, CancelID, homes, HomeManagementFeature.Destination.State, State, Action (+7 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.15
Nodes (17): ClearTarget, category, event, meal, purchased, State, Action, AlertState (+9 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.06
Nodes (33): Action, allDayToggled, attendeeToggled, binding, delegate, deleteTapped, doneTapped, draftItemRemoved (+25 more)

### Community 12 - "Messages View"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.06
Nodes (32): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+24 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.05
Nodes (44): Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped, conversationsUpdated (+36 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.21
Nodes (10): CreateHomeFeature, JoinHomeFeature, ReducerOf, Self, Destination, create, join, Destination (+2 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.04
Nodes (52): CodingKeys, amount, attendees, budget, category, cookTime, created, createdBy (+44 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.15
Nodes (15): CatalogQuery, Kind, actor, decade, director, genre, nowPlaying, popular (+7 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.19
Nodes (10): Home, HomeAddress, Decoder, Double, HomeID, String, UserID, Bool (+2 more)

### Community 19 - "Management Tab ViewModel"
Cohesion: 0.20
Nodes (15): Category, cleaning, groceries, household, other, ShoppingItem, Bool, Decoder (+7 more)

### Community 20 - "Notes ViewModel"
Cohesion: 0.06
Nodes (31): Action, addMoviesTapped, addTapped, alert, allMoviesUpdated, binding, createListTapped, deleteListTapped (+23 more)

### Community 21 - "Unit & UI Tests"
Cohesion: 0.13
Nodes (9): LaunchUITests, Bool, SmokeFlowUITests, String, XCUIApplication, XCUIApplication, TabNavigationUITests, XCTest (+1 more)

### Community 22 - "Match & Poll Summary"
Cohesion: 0.18
Nodes (15): AddedToListToast, ComposeRecipeSheet, CookingModeView, Fact, RecipeCard, RecipeDetailView, RecipesView, Binding (+7 more)

### Community 23 - "Messages Manager"
Cohesion: 0.17
Nodes (28): Codable, Hashable, Identifiable, Bill, Budget, BudgetProgress, CalendarMonth, CategoryTotal (+20 more)

### Community 24 - "Home Tab Screen"
Cohesion: 0.07
Nodes (28): Action, alert, binding, copyInviteCodeTapped, delegate, destination, editNameTapped, failed (+20 more)

### Community 25 - "PocketBase Models"
Cohesion: 0.17
Nodes (19): Angle, Command, DeckSkeleton, MovieNightView, PollHistoryRow, PollKindSheet, PollOutcomeView, Bool (+11 more)

### Community 26 - "Movie Detail Sheet"
Cohesion: 0.08
Nodes (24): @auth/core, dependencies, @auth/core, convex, @convex-dev/auth, jose, description, devDependencies (+16 more)

### Community 27 - "Cooking Mode"
Cohesion: 0.21
Nodes (5): HomeFeature, ReducerOf, HomeView, StoreOf, HomeFeatureTests

### Community 28 - "Poll Type Selection"
Cohesion: 0.08
Nodes (30): currentUserId(), requireDocHome(), requireHomeMember(), requireUser(), assertAuthor(), assertParticipant(), create, listByHome (+22 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.06
Nodes (19): Self, FinanceFeature, Duration, ReducerOf, Self, BillComposerTests, ExpenseComposerTests, FinanceTests (+11 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.08
Nodes (29): checkedRecipes(), create, ensurePresetLists, get, join, leave, listMine, members (+21 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.12
Nodes (18): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+10 more)

### Community 32 - "Community 32"
Cohesion: 0.11
Nodes (23): Animatable, Configuration, GeometryEffect, IntegerFormatStyle, AnimatedNumber, AppearModifier, ButtonStyle, Motion (+15 more)

### Community 33 - "Community 33"
Cohesion: 0.19
Nodes (12): Poll, PollDetail, PollItem, PollOutcome, Result, agreed, closest, nothing (+4 more)

### Community 34 - "Community 34"
Cohesion: 0.25
Nodes (6): Comparable, Urgency, dueSoon, dueToday, overdue, upcoming

### Community 35 - "Community 35"
Cohesion: 0.61
Nodes (3): MealDate, Calendar, String

### Community 36 - "Auth Manager"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.06
Nodes (30): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+22 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.03
Nodes (58): CodingKeys, amount, autoSplit, billID, budget, budgets, categories, category (+50 more)

### Community 40 - "Community 40"
Cohesion: 0.11
Nodes (24): MealPlanID, MealPlan, Cuisine, HomeID, Kind, Recipe, UserID, AlreadyDecidedBanner (+16 more)

### Community 41 - "App Services Core"
Cohesion: 0.15
Nodes (18): AnyCancellable, Combine, ConvexClientWithAuth, ArgumentBox, CancellableBox, CancellableBoxPublic, ConnectionState, ConvexConnection (+10 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.26
Nodes (9): ContributionSlice, Count, HomeContributions, MemberContribution, Bool, Double, Int, String (+1 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.07
Nodes (30): AuthenticationServices, ComposableArchitecture, DependencyKey, Foundation, NestZone, CatalogClient, DependencyValues, MovieDetails (+22 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.15
Nodes (16): Conversation, Kind, audio, document, gif, image, system, text (+8 more)

### Community 46 - "Community 46"
Cohesion: 0.13
Nodes (15): Alert, confirmEndRound, AlertState, CancelID, detail, polls, recipes, Cuisine (+7 more)

### Community 47 - "New Message Group"
Cohesion: 0.12
Nodes (16): path, members, State, Action, AlertState, Bool, ConversationID, Destination (+8 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.25
Nodes (5): LockIsolated, Message, Kind, ChatFeature, MessagesTests

### Community 49 - "Previous Polls"
Cohesion: 0.19
Nodes (11): AppTheme, basic, cyberpunk, deepOcean, neonNight, retroWave, EnvironmentValues, Palette (+3 more)

### Community 50 - "Theme Selection"
Cohesion: 0.17
Nodes (11): CancelID, authState, currentUser, deviceToken, Screen, choosingHome, launching, main (+3 more)

### Community 51 - "Recipe List View"
Cohesion: 0.11
Nodes (33): EventPlan, EventReminder, atTime, oneDay, oneHour, oneWeek, tenMinutes, thirtyMinutes (+25 more)

### Community 52 - "Read Receipts"
Cohesion: 0.10
Nodes (21): Alert, confirmDelete, confirmEndRound, AlertState, CancelID, detail, polls, Destination (+13 more)

### Community 53 - "Note Creator"
Cohesion: 0.24
Nodes (11): DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Int, String, UNAuthorizationStatus (+3 more)

### Community 54 - "Community 54"
Cohesion: 0.25
Nodes (9): Layout, FlowLayout, Row, CGFloat, CGRect, CGSize, Int, ProposedViewSize (+1 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.08
Nodes (26): Action, alert, clearDinnerTapped, decideDinnerTapped, delegate, dinner, dinnerSuggestionAccepted, dinnerSuggestionSaved (+18 more)

### Community 56 - "Home Selection View"
Cohesion: 0.12
Nodes (16): Action, home, homePath, hub, messages, notes, settings, tabSelected (+8 more)

### Community 57 - "Switch Home Sheet"
Cohesion: 0.13
Nodes (13): Error, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline, server (+5 more)

### Community 58 - "Genre Picker"
Cohesion: 0.11
Nodes (19): CodingKeys, created, entityType, externalID, genre, homeID, id, isYes (+11 more)

### Community 59 - "Swipe Card"
Cohesion: 0.21
Nodes (11): State, Action, AlertState, Bool, Destination, HomeID, Int, Kind (+3 more)

### Community 60 - "Recipe Card"
Cohesion: 0.05
Nodes (43): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+35 more)

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
Cohesion: 0.20
Nodes (5): DinnerCandidate, DinnerFeature, ReducerOf, DinnerTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.14
Nodes (19): ClosedRange, CalendarDay, Calendar, Self, DayCell, DayTimeline, EventRow, MonthGrid (+11 more)

### Community 67 - "Preset List Card"
Cohesion: 0.12
Nodes (16): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+8 more)

### Community 68 - "Search Results List"
Cohesion: 0.21
Nodes (7): ContributionsFeature, ReducerOf, Self, ContributionsView, StoreOf, ContributionsFeatureTests, Int

### Community 69 - "Language Selection"
Cohesion: 0.17
Nodes (11): BindableAction, Action, binding, failed, finished, submitTapped, succeeded, State (+3 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.15
Nodes (13): CodingKeys, created, cuisine, date, event, homeID, id, kind (+5 more)

### Community 71 - "Vibrant Module Card"
Cohesion: 0.15
Nodes (11): App, AppDelegate, NestZoneApp, Void, NSObject, Scene, UIApplicationDelegate, UNNotification (+3 more)

### Community 72 - "Chat Header"
Cohesion: 0.11
Nodes (20): Phase, cooking, ingredients, State, StepDuration, StepTimer, Action, AlertState (+12 more)

### Community 73 - "Message Input"
Cohesion: 0.33
Nodes (6): CancelID, addConfirmation, meals, saved, shopping, timer

### Community 74 - "Community 74"
Cohesion: 0.12
Nodes (17): AnyShapeStyle, Int, LocalizedStringResource, AddItemField, DisclosureRow, EventComposerSheet, EventComposerToolbar, EventDetailSheet (+9 more)

### Community 75 - "Community 75"
Cohesion: 0.22
Nodes (9): HubModule, calendar, finance, maintenance, movies, recipes, shopping, Bool (+1 more)

### Community 76 - "Custom List Row"
Cohesion: 0.19
Nodes (14): Seed, State, Action, Bool, ConfirmationDialogState, HomeID, IdentifiedArrayOf, Int (+6 more)

### Community 77 - "Overlay Views"
Cohesion: 0.11
Nodes (19): MovieGenre, action, adventure, animation, comedy, crime, documentary, drama (+11 more)

### Community 78 - "Message Hashing"
Cohesion: 0.11
Nodes (19): Action, alert, authorsResolved, binding, colorSelected, composeTapped, deleteFailed, deleteTapped (+11 more)

### Community 79 - "Management Tab Screen"
Cohesion: 0.12
Nodes (21): Anchor, BubbleActionsAnchor, BubbleActionsAnchorKey, ChatView, ConversationRow, MessageActionsBar, MessageBubble, MessagesView (+13 more)

### Community 80 - "Community 80"
Cohesion: 0.14
Nodes (13): Footer, Palette, StickyColor, blue, green, orange, pink, purple (+5 more)

### Community 81 - "Note Card"
Cohesion: 0.32
Nodes (8): Cache, Recipe, SampleRecipe, SampleRecipeLoader, Bool, Int, Recipe, String

### Community 82 - "Community 82"
Cohesion: 0.36
Nodes (7): Action, EmptyStateView, Action, Bool, LocalizedStringResource, String, Void

### Community 83 - "Community 83"
Cohesion: 0.10
Nodes (20): Action, alert, binding, composeTapped, deleteTapped, destination, failed, finished (+12 more)

### Community 84 - "Create Movie List"
Cohesion: 0.06
Nodes (33): addMonths(), billCycle, createBill, createExpense, Cycle, DueNudge, financeCategory, listBills (+25 more)

### Community 85 - "Community 85"
Cohesion: 0.17
Nodes (7): ManageHomesFeature, ReducerOf, Self, SettingsFeature, ManageHomesTests, SettingsHomeTests, SignOutTests

### Community 86 - "Community 86"
Cohesion: 0.07
Nodes (33): addItems, cleanWeekdays(), collect(), create, detail, EventDoc, eventKind, EventNudge (+25 more)

### Community 87 - "Notes View"
Cohesion: 0.14
Nodes (11): assertParticipant(), create, listByHome, rename, requireMembers(), create, listByHome, priority (+3 more)

### Community 88 - "Task Priority"
Cohesion: 0.25
Nodes (12): CategoryHeader, GroupHeader, GroupMenu, ShoppingRow, ShoppingView, Bool, Int, Namespace (+4 more)

### Community 90 - "Community 90"
Cohesion: 0.10
Nodes (15): FALSY, openTasks(), outstandingItems(), outstandingNames(), category, create, createFromRecipe, listByHome (+7 more)

### Community 91 - "Community 91"
Cohesion: 0.26
Nodes (11): ContributionDay, ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat (+3 more)

### Community 92 - "Community 92"
Cohesion: 0.08
Nodes (26): CaseIterable, Cuisine, american, chinese, indian, italian, japanese, korean (+18 more)

### Community 93 - "Community 93"
Cohesion: 0.12
Nodes (15): Action, auth, authStatusChanged, currentUserChanged, deviceRegistrationFailed, deviceTokenReceived, homeGate, languageChanged (+7 more)

### Community 94 - "Community 94"
Cohesion: 0.23
Nodes (4): ContributionsMathTests, Int, String, UserID

### Community 95 - "Community 95"
Cohesion: 0.21
Nodes (17): Arc, Bill, BillCycle, BudgetRing, Flight, SpendBars, SpendCategory, SpendDonut (+9 more)

### Community 96 - "Community 96"
Cohesion: 0.12
Nodes (16): CodingKeys, cookTime, created, createdBy, difficulty, homeID, id, image (+8 more)

### Community 97 - "Community 97"
Cohesion: 0.13
Nodes (15): CodingKeys, assignedTo, created, createdBy, details, dueDate, homeID, id (+7 more)

### Community 98 - "Community 98"
Cohesion: 0.20
Nodes (10): Field, CreateHomeSheet, FormSheet, JoinHomeSheet, Bool, Int, LocalizedStringResource, StoreOf (+2 more)

### Community 99 - "Community 99"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (5): ⚠️ Auth caveat (the one real gotcha), Nestzone — PocketBase → Convex migration, Steps, Type/field mapping applied, What's here

### Community 101 - "Community 101"
Cohesion: 0.06
Nodes (32): Action, addOnDayTapped, addTapped, alert, binding, daySelected, deleteCommitFailed, deleteTapped (+24 more)

### Community 102 - "Community 102"
Cohesion: 0.12
Nodes (16): CodingKeys, category, created, createdBy, details, eventID, eventTitle, homeID (+8 more)

### Community 103 - "Community 103"
Cohesion: 0.07
Nodes (30): Action, addExpenseTapped, addItemTapped, alert, binding, bulkAddFinished, delegate, deleteTapped (+22 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.06
Nodes (37): EventRSVP, EventScope, occurrence, series, Alert, CalendarFeature, CalendarFeature.Destination.State, CancelID (+29 more)

### Community 106 - "Community 106"
Cohesion: 0.15
Nodes (13): CodingKeys, cleaning, completed, count, email, general, maintenance, name (+5 more)

### Community 107 - "Community 107"
Cohesion: 0.19
Nodes (18): CastMember, Kind, custom, watched, wishlist, Movie, MovieExtras, MovieList (+10 more)

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
Cohesion: 0.10
Nodes (25): LaunchView, MainView, OfflineView, Void, RoundView, NowBadge, SuggestedDinnerCard, Void (+17 more)

### Community 113 - "Community 113"
Cohesion: 0.29
Nodes (7): CancelID, bills, events, handoff, movies, recipes, shopping

### Community 114 - "Community 114"
Cohesion: 0.23
Nodes (12): DependencyValues, DinnerDecision, MealsClient, async, AsyncThrowingStream, Cuisine, Error, EventID (+4 more)

### Community 115 - "Community 115"
Cohesion: 0.24
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 116 - "Community 116"
Cohesion: 0.06
Nodes (34): EventKind, anniversary, appointment, birthday, chore, cinema, concert, deadline (+26 more)

### Community 117 - "Community 117"
Cohesion: 0.13
Nodes (10): BillCycle, biweekly, monthly, once, quarterly, weekly, yearly, ExpenseWeight (+2 more)

### Community 118 - "Community 118"
Cohesion: 0.33
Nodes (6): Backend notes, Commands, Conventions, graphify, Layout, NestZone

### Community 119 - "Community 119"
Cohesion: 0.18
Nodes (10): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Data cleanup + indexing (2026‑09‑03, deployed), NestZone backend — Convex deploy & data‑import runbook, Notes, Production hardening pass (2026‑09‑03), Referential integrity (2026‑09‑03), Reproducing the deploy + import (already executed) (+2 more)

### Community 120 - "Community 120"
Cohesion: 0.12
Nodes (17): ConvexMobile, DependencyValues, MessagesClient, async, AsyncThrowingStream, ConversationID, Error, HomeID (+9 more)

### Community 121 - "Community 121"
Cohesion: 0.09
Nodes (19): EventOccurrence, BinaryInteger, Date, Bool, Decoder, Double, Encoder, Timestamp (+11 more)

### Community 122 - "Community 122"
Cohesion: 0.24
Nodes (5): HomeManagementFeature, ReducerOf, HomeManagementView, StoreOf, HomeManagementTests

### Community 123 - "Community 123"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 124 - "Community 124"
Cohesion: 0.24
Nodes (5): ShoppingFeature, Duration, ReducerOf, ShoppingTests, TestStore

### Community 125 - "Community 125"
Cohesion: 0.14
Nodes (6): Decimal, Money, health, Set, String, FinanceLogicTests

### Community 126 - "Community 126"
Cohesion: 0.13
Nodes (18): Kind, cuisine, custom, recipe, Route, set, vote, State (+10 more)

### Community 127 - "Community 127"
Cohesion: 0.19
Nodes (9): RSVPStatus, declined, going, maybe, CalendarView, Bool, Gesture, StoreOf (+1 more)

### Community 128 - "Community 128"
Cohesion: 0.07
Nodes (38): BillCycle, Action, alert, binding, delegate, deleteTapped, everyoneTapped, failed (+30 more)

### Community 129 - "Community 129"
Cohesion: 0.16
Nodes (12): MovieList.Kind, State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf (+4 more)

### Community 130 - "Community 130"
Cohesion: 0.19
Nodes (18): BillRow, BudgetCard, DayHeader, EventSpendRow, ExpenseRow, FinanceView, PayerRow, Bill (+10 more)

### Community 131 - "Community 131"
Cohesion: 0.16
Nodes (13): Alert, confirmDeleteList, AlertState, CreateMovieListFeature, Destination, createList, list, MovieListFeature (+5 more)

### Community 132 - "Community 132"
Cohesion: 0.13
Nodes (11): Color, String, Backdrop, BudgetProgress.Health, ConfettiBurst, TimeInterval, MemberTint, Double (+3 more)

### Community 133 - "Community 133"
Cohesion: 0.08
Nodes (24): CustomStringConvertible, ExpressibleByStringLiteral, BillsTable, BudgetsTable, ConversationsTable, ConvexID, EventsTable, ExpensesTable (+16 more)

### Community 134 - "Community 134"
Cohesion: 0.16
Nodes (17): AmountField, BillComposerSheet, BudgetEditorSheet, ComposerToolbar, ExpenseComposerSheet, InlineError, MemberLabel, PayBillSheet (+9 more)

### Community 135 - "Community 135"
Cohesion: 0.13
Nodes (13): AlertState, ComposeRecipeFeature, Destination, compose, detail, Recipe.Difficulty, RecipeDetailFeature, RecipesFeature.Destination.State (+5 more)

### Community 136 - "Community 136"
Cohesion: 0.26
Nodes (8): Binding, Bool, CGFloat, Content, Gesture, LocalizedStringResource, Void, SwipeToDelete

### Community 137 - "Community 137"
Cohesion: 0.22
Nodes (9): CodingKey, CodingKeys, address, created, id, inviteCode, members, name (+1 more)

### Community 138 - "Community 138"
Cohesion: 0.15
Nodes (18): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+10 more)

### Community 139 - "Community 139"
Cohesion: 0.20
Nodes (7): Data, Error, Any, Bool, Data, Error, UIApplication

### Community 140 - "Community 140"
Cohesion: 0.36
Nodes (8): out, EventEdit, Bool, ConvexEncodable, RecipeID, Recurrence, String, UserID

### Community 141 - "Community 141"
Cohesion: 0.13
Nodes (15): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+7 more)

### Community 142 - "Community 142"
Cohesion: 0.19
Nodes (12): State, Action, AlertState, Bool, ConfirmationDialogState, IdentifiedArrayOf, Int, Set (+4 more)

### Community 143 - "Community 143"
Cohesion: 0.24
Nodes (8): ComposeNoteSheet, NoteCard, NotesView, Bool, Content, StoreOf, String, Void

### Community 144 - "Community 144"
Cohesion: 0.16
Nodes (13): Alert, confirmLeave, Delegate, dismissRequested, switchRequested, ManageHomesFeature.Destination.State, State, Action (+5 more)

### Community 145 - "Community 145"
Cohesion: 0.14
Nodes (14): Delegate, notificationsEnabled, openCalendar, openContributions, openEvent, openEventID, openMessages, openMovieNight (+6 more)

### Community 146 - "Community 146"
Cohesion: 0.19
Nodes (11): DependencyValues, EventsClient, StockUpResult, async, AsyncThrowingStream, Double, Error, EventID (+3 more)

### Community 147 - "Community 147"
Cohesion: 0.22
Nodes (9): Delegate, deleted, deleteRequested, paid, saved, settled, BillID, BudgetID (+1 more)

### Community 148 - "Community 148"
Cohesion: 0.14
Nodes (13): Alert, confirmSignOut, AlertState, CancelID, copyReset, members, Destination, editName (+5 more)

### Community 149 - "Community 149"
Cohesion: 0.24
Nodes (7): CancelID, bills, budgets, expenses, summary, undo, Effect

### Community 150 - "State"
Cohesion: 0.31
Nodes (8): content, GlassCard, GlassGroup, Metrics, Bool, CGFloat, Content, View

### Community 151 - "SectionHeader"
Cohesion: 0.21
Nodes (18): Encodable, billArgs(), DependencyValues, expenseArgs(), ExpenseShareArgs, ExpenseWeightArgs, FinanceClient, monthArgs() (+10 more)

### Community 152 - "Community 152"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 153 - "Community 153"
Cohesion: 0.25
Nodes (6): edit, listByConversation, markRead, messageType, remove, send

### Community 154 - "Alert"
Cohesion: 0.13
Nodes (16): members, State, Action, AlertState, Bill, BillID, Bool, Destination (+8 more)

### Community 155 - "Community 155"
Cohesion: 0.18
Nodes (10): Alert, enableNotifications, AlertState, CancelID, events, meals, members, stats (+2 more)

### Community 156 - "Community 156"
Cohesion: 0.20
Nodes (10): ComposeTaskFeature, ReducerOf, Self, TasksFeature, ComposeTaskSheet, StoreOf, String, Void (+2 more)

### Community 157 - "Community 157"
Cohesion: 0.26
Nodes (11): Difficulty, easy, hard, medium, Recipe, Decoder, HomeID, Int (+3 more)

### Community 158 - "Community 158"
Cohesion: 0.13
Nodes (15): CodingKeys, conversationID, created, file, homeID, id, isGroupChat, kind (+7 more)

### Community 159 - "Community 159"
Cohesion: 0.17
Nodes (12): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+4 more)

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
Cohesion: 0.10
Nodes (23): ContributionWindow, allTime, month, week, LocalizedStringResource, Action, alert, binding (+15 more)

### Community 165 - "HomeStats"
Cohesion: 0.11
Nodes (17): Alert, confirmDelete, AlertState, BillComposerFeature, BudgetEditorFeature, ExpenseComposerFeature, PayBillFeature, SettleUpFeature (+9 more)

### Community 166 - "Delegate"
Cohesion: 0.14
Nodes (13): Alert, confirmClearCategory, confirmClearEvent, confirmClearMeal, confirmClearPurchased, AlertState, CancelID, items (+5 more)

### Community 167 - "Cache"
Cohesion: 0.42
Nodes (7): NewTask, Bool, ConvexEncodable, HomeID, String, UserID, TaskEdit

### Community 169 - "schema.ts"
Cohesion: 0.40
Nodes (4): eventKind, financeCategory, recurrence, rsvpStatus

### Community 171 - "State"
Cohesion: 0.25
Nodes (8): ArraySlice, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf, Int

### Community 172 - "HomeView"
Cohesion: 0.33
Nodes (6): ChoiceCard, HomeRow, Bool, LocalizedStringResource, String, Void

### Community 173 - "Action"
Cohesion: 0.40
Nodes (6): Avatar, AvatarStack, Member, CGFloat, Int, String

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
Cohesion: 0.25
Nodes (8): URL, TMDbImageWidth, original, w185, w342, w500, w780, w92

### Community 178 - "MainFeature"
Cohesion: 0.09
Nodes (18): State, HomeID, Int, Tab, CodingKeys, avatar, created, email (+10 more)

### Community 179 - "KeyboardDismisser"
Cohesion: 0.27
Nodes (6): BalanceBars, Bill.Urgency, MoneyText, Bool, Double, UserID

### Community 180 - "Action"
Cohesion: 0.26
Nodes (3): EventComposerFeature, Effect, EventComposerTests

### Community 181 - "TaskEdit"
Cohesion: 0.22
Nodes (6): CancelID, recipes, ConfirmationDialogState, RecipePickerFeature, ReducerOf, Self

### Community 182 - "Action"
Cohesion: 0.24
Nodes (5): MessagesFeature, NewConversationFeature, ReducerOf, Self, UserID

### Community 183 - "EventDetailFeature"
Cohesion: 0.39
Nodes (4): KeychainTokenStore, Any, String, Security

### Community 185 - "FinanceFeature"
Cohesion: 0.48
Nodes (6): Note, Decoder, HomeID, NoteID, String, UserID

### Community 186 - "State"
Cohesion: 0.27
Nodes (7): ASAuthorization, AuthFeature, ReducerOf, Self, AuthView, Error, StoreOf

### Community 187 - "Verdict"
Cohesion: 0.25
Nodes (7): Double, LocalizedStringResource, String, Verdict, even, lopsided, tilted

### Community 188 - "recipes.ts"
Cohesion: 0.40
Nodes (5): Delegate, chose, deleted, saved, EventID

### Community 189 - "String"
Cohesion: 0.29
Nodes (7): DependencyValues, HomesClient, async, AsyncThrowingStream, Error, HomeID, Void

### Community 190 - "AppFeature"
Cohesion: 0.24
Nodes (6): AppFeature, ReducerOf, Self, AppView, StoreOf, SessionRestoreTests

### Community 191 - ".phrase"
Cohesion: 0.67
Nodes (3): PollCandidate, ConvexEncodable, String

### Community 192 - "CancelID"
Cohesion: 0.27
Nodes (4): MoviesFeature, MoviesView, StoreOf, PresetListTests

### Community 193 - "EventEdit"
Cohesion: 0.52
Nodes (5): StatTile, Int, LocalizedStringResource, String, Void

### Community 194 - "CalendarView"
Cohesion: 0.09
Nodes (23): Equatable, Action, alert, appleSignInFailed, appleSignInSucceeded, signInFailed, signInSucceeded, Alert (+15 more)

### Community 195 - "EventDetailFeature.swift"
Cohesion: 0.22
Nodes (8): Alert, CancelID, plan, Scope, deleteAll, deleteThisOne, editAll, editThisOne

### Community 197 - "BillCycle"
Cohesion: 0.25
Nodes (8): DependencyValues, MoviesClient, async, AsyncThrowingStream, Error, HomeID, MovieListID, Void

### Community 199 - "DevicesClient"
Cohesion: 0.32
Nodes (7): APNSEnvironment, DependencyValues, DevicesClient, PushResult, Int, String, Void

### Community 200 - "NewShoppingItem"
Cohesion: 0.28
Nodes (8): AddedCount, DependencyValues, ShoppingClient, async, AsyncThrowingStream, Error, Int, Void

### Community 201 - "NotesClient"
Cohesion: 0.29
Nodes (7): DependencyValues, NotesClient, async, AsyncThrowingStream, Error, HomeID, Void

### Community 202 - "CancelID"
Cohesion: 0.33
Nodes (6): CancelID, all, lists, movies, saved, search

### Community 203 - "SectionHeader"
Cohesion: 0.13
Nodes (12): GlassTextField, Binding, Bool, LocalizedStringResource, String, LocalizedStringResource, Void, UndoToast (+4 more)

### Community 205 - "HubFeature"
Cohesion: 0.33
Nodes (5): HubFeature, Duration, ReducerOf, Self, HubNavigationTests

### Community 206 - "NewShoppingItem"
Cohesion: 0.50
Nodes (6): NewShoppingItem, RecipeIngredients, Double, HomeID, RecipeID, String

### Community 207 - "KeyboardDismisser"
Cohesion: 0.25
Nodes (5): KeyboardDismisser, Bool, UIGestureRecognizer, UIGestureRecognizerDelegate, UITouch

### Community 208 - "StepDuration"
Cohesion: 0.25
Nodes (8): Action, countsUpdated, moduleTapped, path, showShoppingList, task, Int, StackActionOf

### Community 209 - "HubView"
Cohesion: 0.32
Nodes (5): HubView, ModuleTile, Int, StoreOf, Void

### Community 210 - "Sparkline"
Cohesion: 0.38
Nodes (4): CGPoint, Sparkline, CGSize, Path

### Community 211 - "Tab"
Cohesion: 0.29
Nodes (7): LocalizedStringResource, Tab, home, hub, messages, notes, settings

### Community 212 - "MainFeature"
Cohesion: 0.33
Nodes (4): MainFeature, ReducerOf, Self, ContributionsNavigationTests

### Community 213 - "SectionHeader"
Cohesion: 0.53
Nodes (4): SectionHeader, LocalizedStringResource, String, Trailing

### Community 214 - "HubFeature.swift"
Cohesion: 0.47
Nodes (4): HubFeature.Path.State, State, HomeID, UserID

### Community 215 - "Path"
Cohesion: 0.33
Nodes (6): Path, calendar, finance, movies, recipes, shopping

### Community 217 - "AppSettings.swift"
Cohesion: 0.40
Nodes (4): Shared<String?>, SharedKey, HomeID, Self

### Community 218 - "Scope"
Cohesion: 0.40
Nodes (5): Scope, deleteAll, deleteThisOne, saveAll, saveThisOne

### Community 219 - "MemberRow"
Cohesion: 0.40
Nodes (5): MemberRow, Bool, Double, Int, String

### Community 221 - "CancelID"
Cohesion: 0.67
Nodes (3): CancelID, conversations, messages

### Community 222 - "Alert"
Cohesion: 0.67
Nodes (3): Alert, confirmDelete, confirmQuit

## Knowledge Gaps
- **1323 isolated node(s):** `launching`, `signedOut`, `offline`, `choosingHome`, `main` (+1318 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Movie Search Row` to `What-To-Watch Voting`, `Community 131`, `Community 132`, `Community 133`, `Realtime Event Manager`, `Community 135`, `Polls Manager`, `Community 138`, `Home Tab ViewModel`, `Home Creation & Tasks`, `Community 144`, `Sample Recipes`, `Management Tab ViewModel`, `Community 146`, `Community 148`, `Messages Manager`, `SectionHeader`, `Community 155`, `Community 157`, `Note Color Extensions`, `Community 33`, `SettingsView`, `HomeStats`, `Delegate`, `App Services Core`, `Chat Detail`, `No-Homes Onboarding`, `Community 46`, `Recipe`, `MainFeature`, `Theme Selection`, `Recipe List View`, `MainFeature`, `Note Creator`, `TaskEdit`, `EventDetailFeature`, `Home Selection View`, `RecipePickerFeature`, `Read Receipts`, `String`, `Community 64`, `CalendarView`, `EventDetailFeature.swift`, `BillCycle`, `DevicesClient`, `NewShoppingItem`, `NotesClient`, `Note Card`, `HubFeature.swift`, `Community 92`, `Community 105`, `Community 107`, `Community 108`, `Community 111`, `Community 114`, `Community 120`, `Community 121`?**
  _High betweenness centrality (0.160) - this node is a cross-community bridge._
- **Why does `L10n` connect `Recipe Theming` to `Community 132`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `SectionHeader` to `What-To-Watch Voting`, `Model Coding Keys`, `Community 130`, `Community 132`, `Community 131`, `Community 134`, `Community 135`, `Community 136`, `Community 143`, `State`, `Match & Poll Summary`, `PocketBase Models`, `Community 156`, `RecipeDetailFeature`, `Community 32`, `SettingsView`, `Community 40`, `Movie Search Row`, `Action`, `HomeView`, `MainFeature`, `Previous Polls`, `Recipe List View`, `Read Receipts`, `TaskEdit`, `Community 54`, `Chat Messages List`, `Loading Button`, `EventDetailFeature.swift`, `Search Results List`, `CalendarView`, `Vibrant Module Card`, `Community 74`, `Management Tab Screen`, `Community 80`, `HubView`, `Community 82`, `SectionHeader`, `HubFeature.swift`, `Task Priority`, `AppSettings.swift`, `Community 91`, `Community 95`, `Community 98`, `Community 104`, `Community 105`, `Community 112`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **What connects `launching`, `signedOut`, `offline` to the rest of the system?**
  _1323 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.10756302521008404 - nodes in this community are weakly interconnected._
- **Should `Confetti & Realtime Models` be split into smaller, more focused modules?**
  _Cohesion score 0.10707070707070707 - nodes in this community are weakly interconnected._
- **Should `Recipe Theming` be split into smaller, more focused modules?**
  _Cohesion score 0.06133333333333333 - nodes in this community are weakly interconnected._