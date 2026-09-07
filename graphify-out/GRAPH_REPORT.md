# Graph Report - NestZone  (2026-09-07)

## Corpus Check
- 142 files · ~268,646 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2744 nodes · 5212 edges · 166 communities (161 shown, 5 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 180 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0e4a7772`
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
- Community 150
- Community 152
- Community 153
- Community 155
- Community 156
- Community 157
- Community 158
- Community 159
- Community 161
- Community 162
- Community 163
- State
- MainFeature

## God Nodes (most connected - your core abstractions)
1. `L10n` - 64 edges
2. `Action` - 64 edges
3. `Foundation` - 57 edges
4. `ComposableArchitecture` - 55 edges
5. `AppError` - 54 edges
6. `Action` - 49 edges
7. `SwiftUI` - 46 edges
8. `Action` - 45 edges
9. `Action` - 45 edges
10. `Timestamp` - 44 edges

## Surprising Connections (you probably didn't know these)
- `ManageHomesTests` --calls--> `Home`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Home.swift
- `MovieHandoffTests` --calls--> `MovieList`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Movie.swift
- `MovieHandoffTests` --calls--> `PollItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/Poll.swift
- `ShoppingTests` --calls--> `ShoppingItem`  [INFERRED]
  NestZoneTests/FeatureTests.swift → NestZone/Core/Models/ShoppingItem.swift
- `NestZoneApp` --calls--> `AppFeature`  [INFERRED]
  NestZone/NestZoneApp.swift → NestZone/App/AppFeature.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Generic polls data model (polls, items, votes scoped to homes)** — docs_pocketbase_readme_polls, docs_pocketbase_readme_poll_items, docs_pocketbase_readme_poll_votes, docs_pocketbase_readme_homes [EXTRACTED 1.00]

## Communities (166 total, 5 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.13
Nodes (17): ContentMode, KeyedDecodingContainer, T, DecodedImageCache, ImageLoader, ImagePlaceholder, Key, RemoteImage (+9 more)

### Community 1 - "Localization Strings"
Cohesion: 0.17
Nodes (12): ComposeTaskFeature, Destination, compose, ReducerOf, Self, TasksFeature, ComposeTaskSheet, StoreOf (+4 more)

### Community 2 - "Model Coding Keys"
Cohesion: 0.20
Nodes (9): RelativeTime, RelativeTimeClock, Duration, Int, Never, Task, Void, NSObjectProtocol (+1 more)

### Community 3 - "Confetti & Realtime Models"
Cohesion: 0.20
Nodes (14): AddedCount, DependencyValues, NewShoppingItem, RecipeIngredients, ShoppingClient, async, AsyncThrowingStream, Double (+6 more)

### Community 5 - "Recipe Theming"
Cohesion: 0.11
Nodes (6): L10n, Int, Locale, LocalizedStringResource, String, StaticString

### Community 6 - "Movie List Model"
Cohesion: 0.04
Nodes (51): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+43 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.06
Nodes (35): AuthProvider, CheckedContinuation, ConvexClient, Decodable, escaping, LocalizedError, PushResult, Int (+27 more)

### Community 8 - "Movie UI Components"
Cohesion: 0.11
Nodes (14): GlassTextField, Binding, Bool, LocalizedStringResource, String, SectionHeader, LocalizedStringResource, String (+6 more)

### Community 9 - "Polls Manager"
Cohesion: 0.21
Nodes (11): Equatable, Alert, CancelID, conversations, messages, Delegate, renamed, MessagesFeature.Destination.State (+3 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.15
Nodes (15): ClearTarget, category, meal, purchased, State, Action, AlertState, Bool (+7 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.21
Nodes (6): AppFeature, Bool, Effect, ReducerOf, Self, SessionRestoreTests

### Community 12 - "Messages View"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.06
Nodes (31): Action, alert, binding, confirmed, deleteConfirmed, deleteTapped, destination, detailLoaded (+23 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.06
Nodes (34): Action, alert, binding, composeTapped, conversationsUpdated, conversationTapped, delegate, deleteFailed (+26 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.21
Nodes (10): CreateHomeFeature, JoinHomeFeature, ReducerOf, Self, Destination, create, join, Destination (+2 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.20
Nodes (10): Field, CreateHomeSheet, FormSheet, JoinHomeSheet, Bool, Int, LocalizedStringResource, StoreOf (+2 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.07
Nodes (30): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+22 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.17
Nodes (15): Calendar, MealPlanID, Kind, cook, order, out, MealDate, MealPlan (+7 more)

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
Cohesion: 0.31
Nodes (7): ComposeNoteSheet, NoteCard, NotesView, Bool, StoreOf, String, Void

### Community 24 - "Home Tab Screen"
Cohesion: 0.07
Nodes (28): Action, alert, binding, copyInviteCodeTapped, delegate, destination, editNameTapped, failed (+20 more)

### Community 25 - "PocketBase Models"
Cohesion: 0.16
Nodes (21): Angle, Command, DeckSkeleton, MovieNightView, PollHistoryRow, PollHistorySheet, PollKindSheet, PollOutcomeView (+13 more)

### Community 26 - "Movie Detail Sheet"
Cohesion: 0.08
Nodes (24): @auth/core, dependencies, @auth/core, convex, @convex-dev/auth, jose, description, devDependencies (+16 more)

### Community 27 - "Cooking Mode"
Cohesion: 0.06
Nodes (32): Action, alert, binding, contributionsUpdated, loadFailed, task, Alert, CancelID (+24 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.11
Nodes (20): currentUserId(), requireDocHome(), requireHomeMember(), clear, forHome, mealKind, set, create (+12 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.13
Nodes (19): DinnerCandidate, Kind, cuisine, custom, recipe, Route, set, vote (+11 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.11
Nodes (22): cascadeDeleteConversation(), cascadeDeleteHome(), cascadeDeleteMovieList(), cascadeDeletePoll(), requireMembers(), requireRef(), requireSameHome(), addMovie (+14 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.15
Nodes (14): AppleCredential, AuthClient, DependencyValues, RestoreOutcome, noSession, restored, transientFailure, async (+6 more)

### Community 32 - "Community 32"
Cohesion: 0.11
Nodes (22): Animatable, Configuration, GeometryEffect, IntegerFormatStyle, AnimatedNumber, AppearModifier, ButtonStyle, Motion (+14 more)

### Community 33 - "Community 33"
Cohesion: 0.13
Nodes (23): Poll, PollDetail, PollItem, PollOutcome, PollVote, Result, agreed, closest (+15 more)

### Community 34 - "Community 34"
Cohesion: 0.21
Nodes (12): BinaryInteger, Date, Decoder, Double, NewTask, Bool, ConvexEncodable, HomeID (+4 more)

### Community 35 - "Community 35"
Cohesion: 0.15
Nodes (17): MovieListFeature, AddMoviesSheet, CreateMovieListSheet, ListChip, ListRow, MovieInfoSheet, MovieListView, MoviesView (+9 more)

### Community 36 - "Auth Manager"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.07
Nodes (26): Action, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped, clearFailed (+18 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.15
Nodes (16): Avatar, AvatarStack, Member, CGFloat, Int, String, ChatView, ConversationRow (+8 more)

### Community 40 - "Community 40"
Cohesion: 0.16
Nodes (20): AlreadyDecidedBanner, CuisineTile, DinnerPlanCard, DinnerSheet, KindCard, RecipeChoice, RoundView, RouteCard (+12 more)

### Community 41 - "App Services Core"
Cohesion: 0.16
Nodes (14): AnyCancellable, Combine, ConvexClientWithAuth, CancellableBox, CancellableBoxPublic, ConvexConnection, ConvexID, DiagnosticsBag (+6 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.20
Nodes (17): Identifiable, ContributionDay, ContributionSlice, ContributionWindow, allTime, month, week, Count (+9 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.18
Nodes (11): DependencyValues, PollCandidate, PollsClient, async, AsyncThrowingStream, ConvexEncodable, Error, HomeID (+3 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.15
Nodes (16): Conversation, Kind, audio, document, gif, image, system, text (+8 more)

### Community 46 - "Community 46"
Cohesion: 0.27
Nodes (7): ASAuthorization, AuthFeature, ReducerOf, Self, AuthView, Error, StoreOf

### Community 47 - "New Message Group"
Cohesion: 0.12
Nodes (17): path, members, Pending, State, Action, AlertState, Bool, ConversationID (+9 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.27
Nodes (5): LockIsolated, Message, Kind, ChatFeature, MessagesTests

### Community 49 - "Previous Polls"
Cohesion: 0.19
Nodes (11): AppTheme, basic, cyberpunk, deepOcean, neonNight, retroWave, EnvironmentValues, Palette (+3 more)

### Community 50 - "Theme Selection"
Cohesion: 0.24
Nodes (5): ManageHomesSheet, Bool, LocalizedStringResource, StoreOf, String

### Community 51 - "Recipe List View"
Cohesion: 0.22
Nodes (8): CancelID, handoff, movies, recipes, shopping, HubFeature.Path.State, State, HomeID

### Community 52 - "Read Receipts"
Cohesion: 0.11
Nodes (19): Alert, confirmDelete, confirmEndRound, AlertState, CancelID, detail, polls, Destination (+11 more)

### Community 53 - "Note Creator"
Cohesion: 0.19
Nodes (7): Destination, compose, MessagesFeature, NewConversationFeature, ReducerOf, Self, UserID

### Community 54 - "Community 54"
Cohesion: 0.25
Nodes (9): CGRect, Layout, FlowLayout, Row, CGFloat, CGSize, Int, ProposedViewSize (+1 more)

### Community 55 - "Swipe Deck"
Cohesion: 0.11
Nodes (19): Action, alert, clearDinnerTapped, decideDinnerTapped, delegate, dinner, loadFailed, mealsUpdated (+11 more)

### Community 56 - "Home Selection View"
Cohesion: 0.22
Nodes (9): Action, home, homePath, hub, messages, notes, settings, tabSelected (+1 more)

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
Cohesion: 0.23
Nodes (5): ManageHomesFeature, ReducerOf, Self, ManageHomesTests, SettingsHomeTests

### Community 61 - "Chat Messages List"
Cohesion: 0.42
Nodes (8): ButtonRole, IconButton, PrimaryButton, SecondaryButton, Bool, LocalizedStringResource, String, Void

### Community 62 - "Edit Note Sheet"
Cohesion: 0.15
Nodes (11): AuthenticationServices, ComposableArchitecture, Shared<String?>, SharedKey, HomeID, Self, DependencyValues, PasteboardClient (+3 more)

### Community 63 - "Auth DTOs"
Cohesion: 0.11
Nodes (17): compilerOptions, allowJs, esModuleInterop, isolatedModules, lib, module, moduleResolution, noEmit (+9 more)

### Community 64 - "Community 64"
Cohesion: 0.23
Nodes (13): createRecipe(), DependencyValues, NewRecipe, RecipesClient, async, AsyncThrowingStream, Bool, Error (+5 more)

### Community 65 - "Community 65"
Cohesion: 0.24
Nodes (5): DinnerFeature, ReducerOf, Self, DinnerTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.12
Nodes (15): Alert, confirmLeave, AlertState, CancelID, homes, HomeManagementFeature.Destination.State, State, Action (+7 more)

### Community 67 - "Preset List Card"
Cohesion: 0.12
Nodes (16): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+8 more)

### Community 68 - "Search Results List"
Cohesion: 0.16
Nodes (13): Delegate, homeSwitched, languageChanged, notificationsEnabled, State, Action, AlertState, Bool (+5 more)

### Community 69 - "Language Selection"
Cohesion: 0.25
Nodes (7): ContributionsView, MemberRow, Bool, Double, Int, StoreOf, String

### Community 70 - "Match Options Sheet"
Cohesion: 0.33
Nodes (6): ChoiceCard, HomeRow, Bool, LocalizedStringResource, String, Void

### Community 71 - "Vibrant Module Card"
Cohesion: 0.21
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, Set (+1 more)

### Community 72 - "Chat Header"
Cohesion: 0.13
Nodes (17): State, StepDuration, StepTimer, Action, AlertState, Bool, Destination, Double (+9 more)

### Community 73 - "Message Input"
Cohesion: 0.11
Nodes (18): Alert, confirmDelete, confirmQuit, CancelID, addConfirmation, meals, saved, shopping (+10 more)

### Community 74 - "Community 74"
Cohesion: 0.20
Nodes (10): DependencyValues, MessagesClient, async, AsyncThrowingStream, ConversationID, Error, HomeID, Int (+2 more)

### Community 75 - "Community 75"
Cohesion: 0.22
Nodes (9): HubModule, calendar, finance, maintenance, movies, recipes, shopping, Bool (+1 more)

### Community 76 - "Custom List Row"
Cohesion: 0.17
Nodes (11): BindableAction, Action, binding, failed, finished, submitTapped, succeeded, State (+3 more)

### Community 77 - "Overlay Views"
Cohesion: 0.11
Nodes (19): MovieGenre, action, adventure, animation, comedy, crime, documentary, drama (+11 more)

### Community 78 - "Message Hashing"
Cohesion: 0.11
Nodes (19): Action, alert, authorsResolved, binding, colorSelected, composeTapped, deleteFailed, deleteTapped (+11 more)

### Community 79 - "Management Tab Screen"
Cohesion: 0.29
Nodes (8): Gesture, Binding, Bool, CGFloat, Content, LocalizedStringResource, Void, SwipeToDelete

### Community 80 - "Community 80"
Cohesion: 0.14
Nodes (13): Footer, Palette, StickyColor, blue, green, orange, pink, purple (+5 more)

### Community 81 - "Note Card"
Cohesion: 0.29
Nodes (7): DependencyValues, HomesClient, async, AsyncThrowingStream, Error, HomeID, Void

### Community 82 - "Community 82"
Cohesion: 0.36
Nodes (7): Action, EmptyStateView, Action, Bool, LocalizedStringResource, String, Void

### Community 83 - "Community 83"
Cohesion: 0.11
Nodes (19): Action, alert, binding, composeTapped, deleteTapped, destination, failed, finished (+11 more)

### Community 85 - "Community 85"
Cohesion: 0.25
Nodes (8): CodingKeys, avatar, created, email, homeIDs, id, name, updated

### Community 86 - "Community 86"
Cohesion: 0.17
Nodes (12): Color, String, Backdrop, StatTile, Int, LocalizedStringResource, String, Void (+4 more)

### Community 87 - "Notes View"
Cohesion: 0.43
Nodes (5): Badge, Chip, Bool, String, Void

### Community 88 - "Task Priority"
Cohesion: 0.25
Nodes (12): Namespace, CategoryHeader, GroupMenu, MealHeader, ShoppingRow, ShoppingView, Bool, Int (+4 more)

### Community 90 - "Community 90"
Cohesion: 0.14
Nodes (14): assertParticipant(), create, listByHome, rename, requireUser(), assertAuthor(), assertParticipant(), edit (+6 more)

### Community 91 - "Community 91"
Cohesion: 0.24
Nodes (11): AnyShapeStyle, ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat (+3 more)

### Community 92 - "Community 92"
Cohesion: 0.15
Nodes (13): Cuisine, american, chinese, indian, italian, japanese, korean, mediterranean (+5 more)

### Community 93 - "Community 93"
Cohesion: 0.15
Nodes (13): Action, auth, authStatusChanged, currentUserChanged, deviceRegistrationFailed, deviceTokenReceived, homeGate, languageChanged (+5 more)

### Community 94 - "Community 94"
Cohesion: 0.10
Nodes (7): ContributionsMathTests, DecodingTests, PollTests, Bool, Int, String, UserID

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
Cohesion: 0.13
Nodes (15): CodingKeys, conversationID, created, file, homeID, id, isGroupChat, kind (+7 more)

### Community 99 - "Community 99"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (5): ⚠️ Auth caveat (the one real gotcha), Nestzone — PocketBase → Convex migration, Steps, Type/field mapping applied, What's here

### Community 101 - "Community 101"
Cohesion: 0.17
Nodes (11): CancelID, authState, currentUser, deviceToken, Screen, choosingHome, launching, main (+3 more)

### Community 102 - "Community 102"
Cohesion: 0.14
Nodes (14): CodingKeys, category, created, createdBy, details, homeID, id, isPurchased (+6 more)

### Community 103 - "Community 103"
Cohesion: 0.07
Nodes (30): App, DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Data, Error (+22 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.14
Nodes (14): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+6 more)

### Community 106 - "Community 106"
Cohesion: 0.15
Nodes (13): CodingKeys, cleaning, completed, count, email, general, maintenance, name (+5 more)

### Community 107 - "Community 107"
Cohesion: 0.10
Nodes (32): Codable, Hashable, CastMember, Kind, custom, watched, wishlist, Movie (+24 more)

### Community 108 - "Community 108"
Cohesion: 0.23
Nodes (9): content, GlassCard, GlassGroup, Metrics, Bool, CGFloat, Content, View (+1 more)

### Community 109 - "Community 109"
Cohesion: 0.21
Nodes (11): apiKey(), details, discover, fetchJSON(), fetchPages(), GENRE_NAMES, GENRES, TMDbCredit (+3 more)

### Community 110 - "Community 110"
Cohesion: 0.18
Nodes (11): CancelID, members, tasks, State, Action, AlertState, Bool, Destination (+3 more)

### Community 111 - "Community 111"
Cohesion: 0.13
Nodes (14): CaseIterable, AppLanguage, english, system, turkish, L10n, Locale, Kind (+6 more)

### Community 112 - "Community 112"
Cohesion: 0.54
Nodes (5): CatalogQuery, Bool, Int, Self, String

### Community 113 - "Community 113"
Cohesion: 0.17
Nodes (12): CodingKeys, created, cuisine, date, homeID, id, kind, place (+4 more)

### Community 114 - "Community 114"
Cohesion: 0.24
Nodes (11): DependencyValues, DinnerDecision, MealsClient, async, AsyncThrowingStream, Cuisine, Error, HomeID (+3 more)

### Community 115 - "Community 115"
Cohesion: 0.33
Nodes (6): DependencyValues, async, AsyncThrowingStream, Error, Void, TasksClient

### Community 116 - "Community 116"
Cohesion: 0.32
Nodes (5): HubView, ModuleTile, Int, StoreOf, Void

### Community 117 - "Community 117"
Cohesion: 0.29
Nodes (7): LocalizedStringResource, Tab, home, hub, messages, notes, settings

### Community 118 - "Community 118"
Cohesion: 0.33
Nodes (6): Backend notes, Commands, Conventions, graphify, Layout, NestZone

### Community 119 - "Community 119"
Cohesion: 0.18
Nodes (10): Auth/JWKS tunnel fix (2026‑06‑19) — required for sign‑in to work, Auth replaced: Sign in with Apple only (2026‑09‑03), Data cleanup + indexing (2026‑09‑03, deployed), NestZone backend — Convex deploy & data‑import runbook, Notes, Production hardening pass (2026‑09‑03), Referential integrity (2026‑09‑03), Reproducing the deploy + import (already executed) (+2 more)

### Community 120 - "Community 120"
Cohesion: 0.24
Nodes (7): HomeStats, Int, DependencyValues, StatsClient, AsyncThrowingStream, Error, HomeID

### Community 121 - "Community 121"
Cohesion: 0.14
Nodes (12): Action, alert, appleSignInFailed, appleSignInSucceeded, signInFailed, signInSucceeded, Alert, State (+4 more)

### Community 122 - "Community 122"
Cohesion: 0.17
Nodes (12): Home, HomeAddress, Decoder, Double, HomeID, String, UserID, HomeManagementFeature (+4 more)

### Community 123 - "Community 123"
Cohesion: 0.22
Nodes (7): AppleIdToken, { auth, signIn, signOut, store, isAuthenticated }, http, APPLE_JWKS_URL, AppleIdentity, jwks, verifyAppleIdentityToken()

### Community 124 - "Community 124"
Cohesion: 0.15
Nodes (8): ShoppingFeature, Duration, ReducerOf, ShoppingTests, Duration, ShoppingItemID, TestClock, TestStoreOf

### Community 125 - "Community 125"
Cohesion: 0.18
Nodes (10): addItem, create, detail, listByHome, pollStatus, pollType, remove, setStatus (+2 more)

### Community 126 - "Community 126"
Cohesion: 0.20
Nodes (3): contributions, forHome, TaskDoc

### Community 127 - "Community 127"
Cohesion: 0.20
Nodes (9): CodingKeys, body, color, created, createdBy, homeID, id, image (+1 more)

### Community 128 - "Community 128"
Cohesion: 0.22
Nodes (7): HomePath, contributions, movieNight, recipeDetail, tasks, MainFeature.HomePath.State, MainFeature.State

### Community 129 - "Community 129"
Cohesion: 0.18
Nodes (11): Alert, confirmDeleteList, AlertState, CreateMovieListFeature, Destination, createList, list, MoviesFeature.Destination.State (+3 more)

### Community 130 - "Community 130"
Cohesion: 0.50
Nodes (4): AuthStatus, authenticated, unauthenticated, unknown

### Community 131 - "Community 131"
Cohesion: 0.33
Nodes (6): CancelID, all, lists, movies, saved, search

### Community 132 - "Community 132"
Cohesion: 0.16
Nodes (8): HomeFeature, ReducerOf, HomeView, StoreOf, Void, TaskRow, HomeFeatureTests, Double

### Community 133 - "Community 133"
Cohesion: 0.10
Nodes (19): CustomStringConvertible, ExpressibleByStringLiteral, ConversationsTable, ConvexID, HomesTable, MealPlansTable, MessagesTable, MovieListsTable (+11 more)

### Community 134 - "Community 134"
Cohesion: 0.19
Nodes (9): AppView, LaunchView, MainView, OfflineView, StoreOf, Void, MainFeature, ReducerOf (+1 more)

### Community 135 - "Community 135"
Cohesion: 0.29
Nodes (7): DependencyValues, NotesClient, async, AsyncThrowingStream, Error, HomeID, Void

### Community 136 - "Community 136"
Cohesion: 0.24
Nodes (9): Alert, Filter, all, done, open, HouseTask.Kind, HouseTask.Priority, LocalizedStringResource (+1 more)

### Community 137 - "Community 137"
Cohesion: 0.14
Nodes (14): CatalogClient, DependencyValues, Kind, actor, decade, director, genre, nowPlaying (+6 more)

### Community 138 - "Community 138"
Cohesion: 0.14
Nodes (19): Comparable, HouseTask, Kind, cleaning, general, maintenance, shopping, Priority (+11 more)

### Community 139 - "Community 139"
Cohesion: 0.22
Nodes (8): create, ensurePresetLists, get, join, leave, listMine, members, PRESET_LISTS

### Community 140 - "Community 140"
Cohesion: 0.16
Nodes (9): AlertState, ComposeRecipeFeature, Destination, compose, detail, RecipeDetailFeature, ReducerOf, Self (+1 more)

### Community 141 - "Community 141"
Cohesion: 0.16
Nodes (13): Alert, confirmLeave, Delegate, dismissRequested, switchRequested, ManageHomesFeature.Destination.State, State, Action (+5 more)

### Community 142 - "Community 142"
Cohesion: 0.22
Nodes (9): CodingKey, CodingKeys, address, created, id, inviteCode, members, name (+1 more)

### Community 143 - "Community 143"
Cohesion: 0.22
Nodes (8): category, create, createFromRecipe, listByHome, remove, removeMany, setPurchased, update

### Community 144 - "Community 144"
Cohesion: 0.14
Nodes (10): State, HomeID, Int, Tab, Decoder, HomeID, String, UserID (+2 more)

### Community 145 - "Community 145"
Cohesion: 0.20
Nodes (10): Delegate, notificationsEnabled, openContributions, openMessages, openMovieNight, openNotes, openRecipe, openShoppingList (+2 more)

### Community 146 - "Community 146"
Cohesion: 0.12
Nodes (18): ConvexMobile, DependencyKey, APNSEnvironment, DependencyValues, DevicesClient, String, Void, DependencyValues (+10 more)

### Community 147 - "Community 147"
Cohesion: 0.48
Nodes (6): Note, Decoder, HomeID, NoteID, String, UserID

### Community 148 - "Community 148"
Cohesion: 0.10
Nodes (18): Alert, confirmSignOut, AlertState, CancelID, copyReset, members, Destination, editName (+10 more)

### Community 149 - "Community 149"
Cohesion: 0.15
Nodes (14): Alert, CancelID, detail, polls, recipes, Cuisine, Delegate, finished (+6 more)

### Community 150 - "Community 150"
Cohesion: 0.67
Nodes (3): MovieList.Kind, LocalizedStringResource, String

### Community 152 - "Community 152"
Cohesion: 0.33
Nodes (5): client, data, dataDir, __dir, wipe

### Community 153 - "Community 153"
Cohesion: 0.16
Nodes (12): Alert, confirmDelete, AlertState, CancelID, notes, ComposeNoteFeature, Destination, compose (+4 more)

### Community 155 - "Community 155"
Cohesion: 0.22
Nodes (8): Alert, enableNotifications, AlertState, CancelID, meals, stats, tasks, Self

### Community 156 - "Community 156"
Cohesion: 0.17
Nodes (12): Action, countsUpdated, moduleTapped, path, showShoppingList, task, Path, movies (+4 more)

### Community 158 - "Community 158"
Cohesion: 0.33
Nodes (5): HubFeature, Duration, ReducerOf, Self, HubNavigationTests

### Community 159 - "Community 159"
Cohesion: 0.40
Nodes (3): RecipesFeature, SavedRecipeTests, RecipeID

### Community 161 - "Community 161"
Cohesion: 0.40
Nodes (4): c, http, iv, t0

### Community 163 - "Community 163"
Cohesion: 0.50
Nodes (3): client, iv, started

### Community 171 - "State"
Cohesion: 0.29
Nodes (7): ArraySlice, State, Action, AlertState, Bool, HomeID, IdentifiedArrayOf

### Community 174 - "MainFeature"
Cohesion: 0.22
Nodes (5): Foundation, NestZone, ContributionsNavigationTests, Security, Testing

## Knowledge Gaps
- **880 isolated node(s):** `launching`, `signedOut`, `offline`, `choosingHome`, `main` (+875 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `MainFeature` to `Community 128`, `What-To-Watch Voting`, `Community 129`, `Confetti & Realtime Models`, `Community 133`, `Community 135`, `Movie UI Components`, `Community 137`, `Community 138`, `Realtime Event Manager`, `Polls Manager`, `Community 141`, `Community 136`, `Sample Recipes`, `Management Tab ViewModel`, `Community 146`, `Community 149`, `Community 148`, `Community 153`, `Cooking Mode`, `Community 155`, `Note Color Extensions`, `Community 33`, `Community 34`, `App Services Core`, `Chat Detail`, `Movie Search Row`, `No-Homes Onboarding`, `Recipe List View`, `Read Receipts`, `Switch Home Sheet`, `Community 64`, `Loading Button`, `Message Input`, `Community 74`, `Custom List Row`, `Note Card`, `Community 95`, `Community 96`, `Community 101`, `Community 103`, `Community 107`, `Community 111`, `Community 114`, `Community 115`, `Community 120`, `Community 121`, `Community 127`?**
  _High betweenness centrality (0.168) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Movie UI Components` to `What-To-Watch Voting`, `Community 129`, `Model Coding Keys`, `Localization Strings`, `Community 132`, `Community 134`, `Community 136`, `New Recipe Sheet`, `Community 148`, `Match & Poll Summary`, `Messages Manager`, `PocketBase Models`, `Cooking Mode`, `Community 32`, `Community 35`, `Simple Movie Detail`, `Community 40`, `Previous Polls`, `Theme Selection`, `Recipe List View`, `Read Receipts`, `Community 54`, `Chat Messages List`, `Edit Note Sheet`, `Language Selection`, `Match Options Sheet`, `Message Input`, `Community 80`, `Community 82`, `Community 86`, `Notes View`, `Task Priority`, `Community 91`, `Community 103`, `Community 104`, `Community 108`, `Community 116`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Why does `L10n` connect `Recipe Theming` to `Movie UI Components`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **What connects `launching`, `signedOut`, `offline` to the rest of the system?**
  _880 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.12873563218390804 - nodes in this community are weakly interconnected._
- **Should `Recipe Theming` be split into smaller, more focused modules?**
  _Cohesion score 0.1117141564902759 - nodes in this community are weakly interconnected._
- **Should `Movie List Model` be split into smaller, more focused modules?**
  _Cohesion score 0.0392156862745098 - nodes in this community are weakly interconnected._