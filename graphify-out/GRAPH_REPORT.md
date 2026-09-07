# Graph Report - NestZone  (2026-09-07)

## Corpus Check
- 152 files · ~312,853 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3357 nodes · 6749 edges · 184 communities (175 shown, 9 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 225 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6b7d1615`
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
- schema.ts
- State
- HomeView
- MainFeature
- Recipe
- SpendCategory
- Verdict
- Action
- TaskEdit
- Action
- Section
- FinanceFeature
- recipes.ts
- .phrase
- CancelID
- crons.ts

## God Nodes (most connected - your core abstractions)
1. `L10n` - 91 edges
2. `Action` - 64 edges
3. `Foundation` - 61 edges
4. `AppError` - 61 edges
5. `ComposableArchitecture` - 60 edges
6. `Action` - 57 edges
7. `CodingKeys` - 54 edges
8. `Timestamp` - 52 edges
9. `Action` - 52 edges
10. `SwiftUI` - 51 edges

## Surprising Connections (you probably didn't know these)
- `ManageHomesTests` --calls--> `Home`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Home.swift
- `MovieHandoffTests` --calls--> `MovieList`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Movie.swift
- `MovieHandoffTests` --calls--> `PollItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Poll.swift
- `ShoppingTests` --calls--> `ShoppingItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/ShoppingItem.swift
- `BillComposerTests` --references--> `User`  [EXTRACTED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/User.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Generic polls data model (polls, items, votes scoped to homes)** — docs_pocketbase_readme_polls, docs_pocketbase_readme_poll_items, docs_pocketbase_readme_poll_votes, docs_pocketbase_readme_homes [EXTRACTED 1.00]

## Communities (184 total, 9 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.11
Nodes (20): ContentMode, KeyedDecodingContainer, Int, T, DecodedImageCache, ImageLoader, ImagePlaceholder, Key (+12 more)

### Community 1 - "Localization Strings"
Cohesion: 0.20
Nodes (14): BillCycle, State, AlertState, Bill, Bool, Double, HomeID, IdentifiedArrayOf (+6 more)

### Community 2 - "Model Coding Keys"
Cohesion: 0.16
Nodes (10): RelativeTime, RelativeTimeClock, Duration, Int, Never, Task, Void, NSObjectProtocol (+2 more)

### Community 3 - "Confetti & Realtime Models"
Cohesion: 0.20
Nodes (14): AddedCount, DependencyValues, NewShoppingItem, RecipeIngredients, ShoppingClient, async, AsyncThrowingStream, Double (+6 more)

### Community 4 - "Movie API (TMDb)"
Cohesion: 0.18
Nodes (15): Kind, generic, movie, recipe, PollVote, Status, active, closed (+7 more)

### Community 5 - "Recipe Theming"
Cohesion: 0.08
Nodes (6): L10n, Int, Locale, LocalizedStringResource, String, StaticString

### Community 6 - "Movie List Model"
Cohesion: 0.04
Nodes (51): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+43 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.06
Nodes (36): AuthProvider, CheckedContinuation, ConvexClient, Decodable, escaping, LocalizedError, PushResult, Int (+28 more)

### Community 8 - "Movie UI Components"
Cohesion: 0.06
Nodes (31): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+23 more)

### Community 9 - "Polls Manager"
Cohesion: 0.10
Nodes (20): Color, String, Backdrop, BudgetProgress.Health, ConfettiBurst, TimeInterval, StatTile, Int (+12 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.15
Nodes (15): ClearTarget, category, meal, purchased, State, Action, AlertState, Bool (+7 more)

### Community 12 - "Messages View"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.06
Nodes (32): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+24 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.05
Nodes (37): Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped, conversationsUpdated (+29 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.21
Nodes (10): CreateHomeFeature, JoinHomeFeature, ReducerOf, Self, Destination, create, join, Destination (+2 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.20
Nodes (10): Field, CreateHomeSheet, FormSheet, JoinHomeSheet, Bool, Int, LocalizedStringResource, StoreOf (+2 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.09
Nodes (28): Alert, Cuisine, Delegate, finished, Kind, cuisine, custom, recipe (+20 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.16
Nodes (12): Home, HomeAddress, Decoder, Double, HomeID, String, UserID, ManageHomesSheet (+4 more)

### Community 19 - "Management Tab ViewModel"
Cohesion: 0.21
Nodes (14): Category, cleaning, groceries, household, other, ShoppingItem, Bool, Decoder (+6 more)

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
Cohesion: 0.20
Nodes (9): NotesFeature, ComposeNoteSheet, NoteCard, NotesView, Bool, StoreOf, String, Void (+1 more)

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
Cohesion: 0.32
Nodes (5): ContributionsFeature, ReducerOf, Self, ContributionsView, StoreOf

### Community 28 - "Poll Type Selection"
Cohesion: 0.11
Nodes (20): currentUserId(), requireDocHome(), requireHomeMember(), clear, forHome, mealKind, set, create (+12 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.09
Nodes (10): Self, BillComposerTests, ExpenseComposerTests, FinanceTests, Bill, BillID, ExpenseID, IdentifiedArrayOf (+2 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.11
Nodes (22): cascadeDeleteConversation(), cascadeDeleteHome(), cascadeDeleteMovieList(), cascadeDeletePoll(), requireMembers(), requireRef(), requireSameHome(), addMovie (+14 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.13
Nodes (17): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+9 more)

### Community 32 - "Community 32"
Cohesion: 0.11
Nodes (23): Animatable, Configuration, GeometryEffect, IntegerFormatStyle, AnimatedNumber, AppearModifier, ButtonStyle, Motion (+15 more)

### Community 33 - "Community 33"
Cohesion: 0.19
Nodes (12): Poll, PollDetail, PollItem, PollOutcome, Result, agreed, closest, nothing (+4 more)

### Community 34 - "Community 34"
Cohesion: 0.12
Nodes (18): Comparable, Bill, Settlement, BillID, Calendar, Urgency, dueSoon, dueToday (+10 more)

### Community 35 - "Community 35"
Cohesion: 0.19
Nodes (17): Codable, Identifiable, BudgetProgress, CalendarMonth, CategoryTotal, FinanceSummary, Health, close (+9 more)

### Community 36 - "Auth Manager"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.07
Nodes (27): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+19 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.04
Nodes (52): CodingKeys, amount, autoSplit, billID, budgets, categories, category, created (+44 more)

### Community 40 - "Community 40"
Cohesion: 0.10
Nodes (29): AppView, LaunchView, MainView, OfflineView, StoreOf, Void, DinnerCandidate, AlreadyDecidedBanner (+21 more)

### Community 41 - "App Services Core"
Cohesion: 0.16
Nodes (14): AnyCancellable, Combine, ConvexClientWithAuth, CancellableBox, CancellableBoxPublic, ConvexConnection, ConvexID, DiagnosticsBag (+6 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.20
Nodes (16): Hashable, ContributionDay, ContributionSlice, ContributionWindow, allTime, month, week, Count (+8 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.18
Nodes (11): DependencyValues, PollCandidate, PollsClient, async, AsyncThrowingStream, ConvexEncodable, Error, HomeID (+3 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.15
Nodes (16): Conversation, Kind, audio, document, gif, image, system, text (+8 more)

### Community 46 - "Community 46"
Cohesion: 0.09
Nodes (19): ASAuthorization, Action, alert, appleSignInFailed, appleSignInSucceeded, signInFailed, signInSucceeded, Alert (+11 more)

### Community 47 - "New Message Group"
Cohesion: 0.14
Nodes (15): path, members, Pending, State, Action, AlertState, Bool, Destination (+7 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.25
Nodes (5): LockIsolated, Message, Kind, ChatFeature, MessagesTests

### Community 49 - "Previous Polls"
Cohesion: 0.19
Nodes (11): AppTheme, basic, cyberpunk, deepOcean, neonNight, retroWave, EnvironmentValues, Palette (+3 more)

### Community 50 - "Theme Selection"
Cohesion: 0.12
Nodes (27): CGPoint, Arc, BalanceBars, Bill, Bill.Urgency, BillCycle, BudgetRing, Flight (+19 more)

### Community 51 - "Recipe List View"
Cohesion: 0.20
Nodes (10): CancelID, bills, handoff, movies, recipes, shopping, HubFeature.Path.State, State (+2 more)

### Community 52 - "Read Receipts"
Cohesion: 0.10
Nodes (21): Alert, confirmDelete, confirmEndRound, AlertState, CancelID, detail, polls, Destination (+13 more)

### Community 53 - "Note Creator"
Cohesion: 0.13
Nodes (17): DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Data, Error, Int (+9 more)

### Community 54 - "Community 54"
Cohesion: 0.25
Nodes (9): Layout, FlowLayout, Row, CGFloat, CGRect, CGSize, Int, ProposedViewSize (+1 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.11
Nodes (19): Action, alert, clearDinnerTapped, decideDinnerTapped, delegate, dinner, loadFailed, mealsUpdated (+11 more)

### Community 56 - "Home Selection View"
Cohesion: 0.18
Nodes (9): MainFeature.HomePath.State, MainFeature.State, LocalizedStringResource, Tab, home, hub, messages, notes (+1 more)

### Community 57 - "Switch Home Sheet"
Cohesion: 0.14
Nodes (13): Error, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline, server (+5 more)

### Community 58 - "Genre Picker"
Cohesion: 0.11
Nodes (19): CodingKeys, created, entityType, externalID, genre, homeID, id, isYes (+11 more)

### Community 59 - "Swipe Card"
Cohesion: 0.10
Nodes (23): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+15 more)

### Community 60 - "Recipe Card"
Cohesion: 0.05
Nodes (39): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+31 more)

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
Cohesion: 0.23
Nodes (5): DinnerFeature, ReducerOf, Self, DinnerTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.14
Nodes (12): AlertState, CancelID, homes, HomeManagementFeature.Destination.State, State, Action, AlertState, Bool (+4 more)

### Community 67 - "Preset List Card"
Cohesion: 0.11
Nodes (19): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+11 more)

### Community 68 - "Search Results List"
Cohesion: 0.40
Nodes (6): Avatar, AvatarStack, Member, CGFloat, Int, String

### Community 69 - "Language Selection"
Cohesion: 0.17
Nodes (11): BindableAction, Action, binding, failed, finished, submitTapped, succeeded, State (+3 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.11
Nodes (15): SectionHeader, LocalizedStringResource, String, LocalizedStringResource, Void, UndoToast, ChoiceCard, HomeRow (+7 more)

### Community 72 - "Chat Header"
Cohesion: 0.13
Nodes (17): State, StepDuration, StepTimer, Action, AlertState, Bool, Destination, Double (+9 more)

### Community 73 - "Message Input"
Cohesion: 0.11
Nodes (18): Alert, confirmDelete, confirmQuit, CancelID, addConfirmation, meals, saved, shopping (+10 more)

### Community 74 - "Community 74"
Cohesion: 0.50
Nodes (4): DependencyValues, PasteboardClient, String, Void

### Community 75 - "Community 75"
Cohesion: 0.15
Nodes (12): HubModule, calendar, finance, maintenance, movies, recipes, shopping, Bool (+4 more)

### Community 76 - "Custom List Row"
Cohesion: 0.07
Nodes (32): CodingKeys, content, conversationID, created, file, homeID, id, isGroupChat (+24 more)

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
Cohesion: 0.10
Nodes (19): BillCycle, biweekly, monthly, once, quarterly, weekly, yearly, NewBill (+11 more)

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
Cohesion: 0.09
Nodes (17): ManageHomesFeature, ReducerOf, Self, AlertState, Destination, editName, manageHomes, EditNameFeature (+9 more)

### Community 86 - "Community 86"
Cohesion: 0.22
Nodes (9): Action, home, homePath, hub, messages, notes, settings, tabSelected (+1 more)

### Community 87 - "Notes View"
Cohesion: 0.18
Nodes (10): addItem, create, detail, listByHome, pollStatus, pollType, remove, setStatus (+2 more)

### Community 88 - "Task Priority"
Cohesion: 0.25
Nodes (12): CategoryHeader, GroupMenu, MealHeader, ShoppingRow, ShoppingView, Bool, Int, Namespace (+4 more)

### Community 90 - "Community 90"
Cohesion: 0.14
Nodes (14): assertParticipant(), create, listByHome, rename, requireUser(), assertAuthor(), assertParticipant(), edit (+6 more)

### Community 91 - "Community 91"
Cohesion: 0.24
Nodes (11): AnyShapeStyle, ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat (+3 more)

### Community 92 - "Community 92"
Cohesion: 0.10
Nodes (20): Cuisine, american, chinese, indian, italian, japanese, korean, mediterranean (+12 more)

### Community 93 - "Community 93"
Cohesion: 0.06
Nodes (30): Action, auth, authStatusChanged, currentUserChanged, deviceRegistrationFailed, deviceTokenReceived, homeGate, languageChanged (+22 more)

### Community 94 - "Community 94"
Cohesion: 0.30
Nodes (3): ContributionsMathTests, Int, String

### Community 95 - "Community 95"
Cohesion: 0.15
Nodes (12): Alert, confirmClearCategory, confirmClearMeal, confirmClearPurchased, AlertState, CancelID, items, undo (+4 more)

### Community 96 - "Community 96"
Cohesion: 0.09
Nodes (27): CodingKeys, cookTime, created, createdBy, difficulty, homeID, id, image (+19 more)

### Community 97 - "Community 97"
Cohesion: 0.13
Nodes (15): CodingKeys, assignedTo, created, createdBy, details, dueDate, homeID, id (+7 more)

### Community 98 - "Community 98"
Cohesion: 0.43
Nodes (5): GlassTextField, Binding, Bool, LocalizedStringResource, String

### Community 99 - "Community 99"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (5): ⚠️ Auth caveat (the one real gotcha), Nestzone — PocketBase → Convex migration, Steps, Type/field mapping applied, What's here

### Community 101 - "Community 101"
Cohesion: 0.31
Nodes (8): MealPlanID, MealPlan, Cuisine, Decoder, HomeID, Kind, Recipe, UserID

### Community 102 - "Community 102"
Cohesion: 0.14
Nodes (14): CodingKeys, category, created, createdBy, details, homeID, id, isPurchased (+6 more)

### Community 103 - "Community 103"
Cohesion: 0.40
Nodes (4): Shared<String?>, SharedKey, HomeID, Self

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.40
Nodes (3): Effect, ConversationID, Effect

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
Cohesion: 0.22
Nodes (13): AddMoviesSheet, ListChip, ListRow, MovieListView, MoviesView, PosterCard, Bool, CGSize (+5 more)

### Community 113 - "Community 113"
Cohesion: 0.17
Nodes (12): CodingKeys, created, cuisine, date, homeID, id, kind, place (+4 more)

### Community 114 - "Community 114"
Cohesion: 0.24
Nodes (11): DependencyValues, DinnerDecision, MealsClient, async, AsyncThrowingStream, Cuisine, Error, HomeID (+3 more)

### Community 115 - "Community 115"
Cohesion: 0.24
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 116 - "Community 116"
Cohesion: 0.25
Nodes (8): CaseIterable, SplitMode, equal, exact, shares, Tab, explore, mine

### Community 117 - "Community 117"
Cohesion: 0.13
Nodes (14): Budget, Expense, ExpenseSplit, ExpenseWeight, NewExpense, NewSettlement, SplitMath, BudgetID (+6 more)

### Community 118 - "Community 118"
Cohesion: 0.33
Nodes (6): Backend notes, Commands, Conventions, graphify, Layout, NestZone

### Community 119 - "Community 119"
Cohesion: 0.18
Nodes (10): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Data cleanup + indexing (2026‑09‑03, deployed), NestZone backend — Convex deploy & data‑import runbook, Notes, Production hardening pass (2026‑09‑03), Referential integrity (2026‑09‑03), Reproducing the deploy + import (already executed) (+2 more)

### Community 120 - "Community 120"
Cohesion: 0.24
Nodes (9): Alert, Filter, all, done, open, HouseTask.Kind, HouseTask.Priority, LocalizedStringResource (+1 more)

### Community 121 - "Community 121"
Cohesion: 0.29
Nodes (7): DependencyValues, HomesClient, async, AsyncThrowingStream, Error, HomeID, Void

### Community 122 - "Community 122"
Cohesion: 0.27
Nodes (5): HomeManagementFeature, ReducerOf, HomeManagementView, StoreOf, HomeManagementTests

### Community 123 - "Community 123"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 124 - "Community 124"
Cohesion: 0.14
Nodes (7): ShoppingFeature, Duration, ReducerOf, ShoppingTests, Duration, ShoppingItemID, TestClock

### Community 125 - "Community 125"
Cohesion: 0.16
Nodes (5): Decimal, Money, Set, String, FinanceLogicTests

### Community 126 - "Community 126"
Cohesion: 0.20
Nodes (3): contributions, forHome, TaskDoc

### Community 127 - "Community 127"
Cohesion: 0.21
Nodes (9): Alert, CancelID, contributions, State, Action, AlertState, Effect, HomeID (+1 more)

### Community 128 - "Community 128"
Cohesion: 0.09
Nodes (23): Action, alert, binding, delegate, deleteTapped, everyoneTapped, failed, onlyMeTapped (+15 more)

### Community 129 - "Community 129"
Cohesion: 0.16
Nodes (12): MovieList.Kind, State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf (+4 more)

### Community 130 - "Community 130"
Cohesion: 0.20
Nodes (17): BillRow, BudgetCard, DayHeader, ExpenseRow, FinanceView, PayerRow, Bill, Bool (+9 more)

### Community 131 - "Community 131"
Cohesion: 0.16
Nodes (13): Alert, confirmDeleteList, AlertState, CreateMovieListFeature, Destination, createList, list, MovieListFeature (+5 more)

### Community 132 - "Community 132"
Cohesion: 0.16
Nodes (8): HomeFeature, ReducerOf, HomeView, StoreOf, Void, TaskRow, HomeFeatureTests, Double

### Community 133 - "Community 133"
Cohesion: 0.08
Nodes (23): CustomStringConvertible, ExpressibleByStringLiteral, BillsTable, BudgetsTable, ConversationsTable, ConvexID, ExpensesTable, HomesTable (+15 more)

### Community 134 - "Community 134"
Cohesion: 0.16
Nodes (17): AmountField, BillComposerSheet, BudgetEditorSheet, ComposerToolbar, ExpenseComposerSheet, InlineError, MemberLabel, PayBillSheet (+9 more)

### Community 135 - "Community 135"
Cohesion: 0.29
Nodes (7): DependencyValues, NotesClient, async, AsyncThrowingStream, Error, HomeID, Void

### Community 136 - "Community 136"
Cohesion: 0.26
Nodes (7): HubFeature, Duration, ReducerOf, Self, HubView, StoreOf, HubNavigationTests

### Community 137 - "Community 137"
Cohesion: 0.16
Nodes (16): CatalogQuery, Kind, actor, decade, director, genre, nowPlaying, popular (+8 more)

### Community 138 - "Community 138"
Cohesion: 0.15
Nodes (18): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+10 more)

### Community 139 - "Community 139"
Cohesion: 0.22
Nodes (8): create, ensurePresetLists, get, join, leave, listMine, members, PRESET_LISTS

### Community 140 - "Community 140"
Cohesion: 0.16
Nodes (9): AlertState, ComposeRecipeFeature, Destination, compose, detail, RecipeDetailFeature, ReducerOf, Self (+1 more)

### Community 141 - "Community 141"
Cohesion: 0.13
Nodes (15): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+7 more)

### Community 142 - "Community 142"
Cohesion: 0.22
Nodes (9): CodingKey, CodingKeys, address, created, id, inviteCode, members, name (+1 more)

### Community 143 - "Community 143"
Cohesion: 0.22
Nodes (8): category, create, createFromRecipe, listByHome, remove, removeMany, setPurchased, update

### Community 144 - "Community 144"
Cohesion: 0.10
Nodes (17): MainFeature, ReducerOf, Self, CodingKeys, avatar, created, email, homeIDs (+9 more)

### Community 145 - "Community 145"
Cohesion: 0.20
Nodes (10): Delegate, notificationsEnabled, openContributions, openMessages, openMovieNight, openNotes, openRecipe, openShoppingList (+2 more)

### Community 146 - "Community 146"
Cohesion: 0.40
Nodes (5): HomePath, contributions, movieNight, recipeDetail, tasks

### Community 147 - "Community 147"
Cohesion: 0.22
Nodes (9): Delegate, deleted, deleteRequested, paid, saved, settled, BillID, BudgetID (+1 more)

### Community 148 - "Community 148"
Cohesion: 0.16
Nodes (11): Foundation, NestZone, Alert, confirmSignOut, CancelID, copyReset, members, SettingsFeature.Destination.State (+3 more)

### Community 149 - "Community 149"
Cohesion: 0.16
Nodes (13): Alert, confirmLeave, Delegate, dismissRequested, switchRequested, ManageHomesFeature.Destination.State, State, Action (+5 more)

### Community 151 - "SectionHeader"
Cohesion: 0.21
Nodes (18): Encodable, billArgs(), DependencyValues, expenseArgs(), ExpenseShareArgs, ExpenseWeightArgs, FinanceClient, monthArgs() (+10 more)

### Community 152 - "Community 152"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 153 - "Community 153"
Cohesion: 0.15
Nodes (11): App, AppDelegate, NestZoneApp, Void, NSObject, Scene, UIApplicationDelegate, UNNotification (+3 more)

### Community 154 - "Alert"
Cohesion: 0.14
Nodes (16): members, State, Action, AlertState, Bill, BillID, Bool, Destination (+8 more)

### Community 155 - "Community 155"
Cohesion: 0.22
Nodes (8): Alert, enableNotifications, AlertState, CancelID, meals, stats, tasks, Self

### Community 156 - "Community 156"
Cohesion: 0.17
Nodes (12): ComposeTaskFeature, Destination, compose, ReducerOf, Self, TasksFeature, ComposeTaskSheet, StoreOf (+4 more)

### Community 157 - "Community 157"
Cohesion: 0.25
Nodes (5): KeyboardDismisser, Bool, UIGestureRecognizer, UIGestureRecognizerDelegate, UITouch

### Community 159 - "Community 159"
Cohesion: 0.50
Nodes (4): CancelID, detail, polls, recipes

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
Cohesion: 0.22
Nodes (9): Action, alert, binding, contributionsUpdated, loadFailed, task, Alert, BindingAction (+1 more)

### Community 165 - "HomeStats"
Cohesion: 0.13
Nodes (15): Alert, confirmDelete, AlertState, BillComposerFeature, BudgetEditorFeature, ExpenseComposerFeature, PayBillFeature, ReducerOf (+7 more)

### Community 171 - "State"
Cohesion: 0.20
Nodes (9): ArraySlice, HomeStats, Int, State, Action, AlertState, Bool, HomeID (+1 more)

### Community 172 - "HomeView"
Cohesion: 0.07
Nodes (31): AuthenticationServices, ComposableArchitecture, ConvexMobile, DependencyKey, CatalogClient, DependencyValues, async, APNSEnvironment (+23 more)

### Community 174 - "MainFeature"
Cohesion: 0.25
Nodes (8): DependencyValues, MoviesClient, async, AsyncThrowingStream, Error, HomeID, MovieListID, Void

### Community 175 - "Recipe"
Cohesion: 0.20
Nodes (9): CodingKeys, body, color, created, createdBy, homeID, id, image (+1 more)

### Community 176 - "SpendCategory"
Cohesion: 0.40
Nodes (3): RecipesFeature, SavedRecipeTests, RecipeID

### Community 179 - "Verdict"
Cohesion: 0.25
Nodes (7): Double, LocalizedStringResource, String, Verdict, even, lopsided, tilted

### Community 180 - "Action"
Cohesion: 0.15
Nodes (13): Action, countsUpdated, moduleTapped, path, showShoppingList, task, Path, finance (+5 more)

### Community 181 - "TaskEdit"
Cohesion: 0.21
Nodes (13): DependencyValues, NewTask, async, AsyncThrowingStream, Bool, ConvexEncodable, Error, HomeID (+5 more)

### Community 182 - "Action"
Cohesion: 0.33
Nodes (6): CancelID, all, lists, movies, saved, search

### Community 184 - "Section"
Cohesion: 0.22
Nodes (8): Alert, FinanceFeature.Destination.State, Section, bills, budgets, ledger, overview, LocalizedStringResource

### Community 185 - "FinanceFeature"
Cohesion: 0.48
Nodes (6): Note, Decoder, HomeID, NoteID, String, UserID

### Community 188 - "recipes.ts"
Cohesion: 0.10
Nodes (21): Equatable, State, HomeID, Int, Tab, Alert, CancelID, conversations (+13 more)

### Community 191 - ".phrase"
Cohesion: 0.23
Nodes (4): ContributionsFeatureTests, RelativeTimeTests, Int, TimeInterval

### Community 192 - "CancelID"
Cohesion: 0.17
Nodes (11): CancelID, bills, budgets, expenses, summary, undo, FinanceFeature, Duration (+3 more)

## Knowledge Gaps
- **1066 isolated node(s):** `launching`, `signedOut`, `offline`, `choosingHome`, `main` (+1061 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Community 148` to `What-To-Watch Voting`, `Confetti & Realtime Models`, `Community 131`, `Community 133`, `Community 135`, `Realtime Event Manager`, `Community 138`, `Community 144`, `Shopping List UI`, `Sample Recipes`, `Management Tab ViewModel`, `Community 149`, `SectionHeader`, `Community 155`, `Note Color Extensions`, `Community 33`, `Community 34`, `Community 35`, `HomeStats`, `App Services Core`, `Chat Detail`, `State`, `No-Homes Onboarding`, `HomeView`, `Recipe`, `MainFeature`, `Movie Search Row`, `Community 46`, `Recipe List View`, `Read Receipts`, `TaskEdit`, `Note Creator`, `Home Selection View`, `Section`, `recipes.ts`, `Community 64`, `Loading Button`, `Language Selection`, `Match Options Sheet`, `Message Input`, `Community 92`, `Community 93`, `Community 95`, `Community 96`, `Community 107`, `Community 108`, `Community 111`, `Community 114`, `Community 120`, `Community 121`, `Community 127`?**
  _High betweenness centrality (0.147) - this node is a cross-community bridge._
- **Why does `L10n` connect `Recipe Theming` to `Match Options Sheet`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Match Options Sheet` to `What-To-Watch Voting`, `Model Coding Keys`, `Community 130`, `Community 132`, `Community 131`, `Community 134`, `Polls Manager`, `New Recipe Sheet`, `Sample Recipes`, `Match & Poll Summary`, `Messages Manager`, `PocketBase Models`, `Community 153`, `Cooking Mode`, `Community 156`, `RecipeDetailFeature`, `Community 32`, `Community 40`, `HomeView`, `Previous Polls`, `Theme Selection`, `Recipe List View`, `Read Receipts`, `Community 54`, `Section`, `Chat Messages List`, `Search Results List`, `Message Input`, `Community 75`, `Custom List Row`, `Management Tab Screen`, `Community 80`, `Community 82`, `Community 85`, `Task Priority`, `Community 91`, `Community 98`, `Community 103`, `Community 104`, `Community 112`, `Community 120`, `Community 127`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **What connects `launching`, `signedOut`, `offline` to the rest of the system?**
  _1066 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.10873440285204991 - nodes in this community are weakly interconnected._
- **Should `Recipe Theming` be split into smaller, more focused modules?**
  _Cohesion score 0.0812171127888355 - nodes in this community are weakly interconnected._
- **Should `Movie List Model` be split into smaller, more focused modules?**
  _Cohesion score 0.0392156862745098 - nodes in this community are weakly interconnected._