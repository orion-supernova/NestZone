# Graph Report - NestZone  (2026-10-20)

## Corpus Check
- 263 files · ~783,873 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 6815 nodes · 14972 edges · 311 communities (302 shown, 9 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 577 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b7e1b934`
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
- TMDbImageWidth
- HomesClient
- HomeManagementFeature.swift
- Alert
- IssuesFeature
- ArchiveRow
- Community 263
- String
- .image
- KeychainTokenStore
- Section
- CancelID
- .userNotificationCenter
- Community 270
- StepDuration
- l10n_tool.py
- AppLanguage
- Chip
- CancelID
- StatTile
- Action
- EventComposerFeature.swift
- Community 279
- Kind
- Community 281
- GlanceClause
- UIImagePickerController
- MainFeature.State
- PushRegistration
- HomesClient
- AvatarPickerFace
- Sheet
- GarlandStyle
- Holiday dates: how they're worked out, and where they were checked
- CancelID
- Community 292
- Screen
- UndoToast
- InboxAdminFeature
- .alert
- duck.js
- Health
- Urgency
- CatalogClient.swift
- PhotoCompressionPlan
- Folds
- PollCandidate
- IssuePhotoIDs
- State
- Delegate
- CancelID
- CancelID
- Alert
- scenario.sh

## God Nodes (most connected - your core abstractions)
1. `L10n` - 228 edges
2. `Date` - 137 edges
3. `Timestamp` - 107 edges
4. `Foundation` - 103 edges
5. `SwiftUI` - 102 edges
6. `User` - 101 edges
7. `Color` - 101 edges
8. `ComposableArchitecture` - 98 edges
9. `AppError` - 89 edges
10. `EventOccurrence` - 81 edges

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

## Communities (311 total, 9 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.07
Nodes (34): ContentMode, CryptoKit, KeyedDecodingContainer, Int, T, ImageDiskCache, CGFloat, String (+26 more)

### Community 1 - "Localization Strings"
Cohesion: 0.07
Nodes (30): IdentifiedActionOf, Action, deferredOpen, delegate, path, screen, segmentPicked, statsTapped (+22 more)

### Community 2 - "Model Coding Keys"
Cohesion: 0.08
Nodes (23): Action, alert, binding, contributionsUpdated, loadFailed, task, CancelID, contributions (+15 more)

### Community 3 - "Confetti & Realtime Models"
Cohesion: 0.03
Nodes (76): CodingKeys, ageDays, amount, area, assignedTo, authorID, blockedReason, body (+68 more)

### Community 4 - "Movie API (TMDb)"
Cohesion: 0.12
Nodes (15): AvatarCrop, CGFloat, CGRect, CGSize, Self, AvatarCropSheet, AccessibilityAdjustmentDirection, CGFloat (+7 more)

### Community 5 - "Recipe Theming"
Cohesion: 0.05
Nodes (3): Int, LocalizedStringResource, StaticString

### Community 6 - "Movie List Model"
Cohesion: 0.03
Nodes (65): CodingKeys, amount, autoSplit, billID, budget, budgets, categories, category (+57 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.17
Nodes (13): AuthProvider, CheckedContinuation, ConvexClient, escaping, AsyncSemaphore, ConvexAppleAuthProvider, ConvexAuthTokens, PendingCredential (+5 more)

### Community 8 - "Movie UI Components"
Cohesion: 0.04
Nodes (3): L10n, Locale, String

### Community 9 - "Polls Manager"
Cohesion: 0.07
Nodes (30): Footer, IssuePhotoRef, CatalogQuery, Kind, actor, decade, director, genre (+22 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.07
Nodes (41): ActivityID, Decodable, ActivityCategory, calendar, finance, home, issues, meals (+33 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.03
Nodes (60): CodingKeys, amount, attendees, budget, budgeted, category, cookTime, created (+52 more)

### Community 12 - "Messages View"
Cohesion: 0.04
Nodes (64): pending, Action, actionsDismissed, alert, backgroundTapped, binding, bubbleHeld, composeTapped (+56 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.04
Nodes (54): Action, addConfirmationExpired, addedToShopping, addIngredientTapped, addStepTapped, addToShoppingTapped, alert, allIngredientsToggled (+46 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.07
Nodes (36): assertParticipant(), create, listByHome, rename, requireDocHome(), requireHomeMember(), requireUser(), assertAuthor() (+28 more)

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.11
Nodes (20): Field, CreateHomeFeature, JoinHomeFeature, ReducerOf, Self, CreateHomeSheet, FormSheet, JoinHomeSheet (+12 more)

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
Nodes (9): Money, Decimal, Set, String, CurrencyPicker, Bool, String, Void (+1 more)

### Community 21 - "Unit & UI Tests"
Cohesion: 0.13
Nodes (9): LaunchUITests, Bool, SmokeFlowUITests, String, XCUIApplication, XCUIApplication, TabNavigationUITests, XCTest (+1 more)

### Community 22 - "Match & Poll Summary"
Cohesion: 0.22
Nodes (13): AddedToListToast, ComposeRecipeSheet, CookingModeView, Fact, RecipeCard, RecipeDetailView, RecipesView, Int (+5 more)

### Community 23 - "Messages Manager"
Cohesion: 0.25
Nodes (8): State, Action, AlertState, AppUpdate, Bool, IdentifiedArrayOf, Set, UserID

### Community 24 - "Home Tab Screen"
Cohesion: 0.06
Nodes (33): addMonths(), billCycle, createBill, createExpense, Cycle, DueNudge, financeCategory, listBills (+25 more)

### Community 25 - "PocketBase Models"
Cohesion: 0.16
Nodes (21): Angle, Command, DeckSkeleton, MovieNightView, PollHistoryRow, PollHistorySheet, PollKindSheet, PollOutcomeView (+13 more)

### Community 26 - "Movie Detail Sheet"
Cohesion: 0.08
Nodes (24): @auth/core, dependencies, @auth/core, convex, @convex-dev/auth, jose, description, devDependencies (+16 more)

### Community 27 - "Cooking Mode"
Cohesion: 0.17
Nodes (14): CGRect, GraphicsContext, SceneFrame, ScenePainter, SceneSpace, Bool, CGPoint, CGRect (+6 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.06
Nodes (34): addItems, cleanWeekdays(), collect(), create, detail, EventDoc, eventKind, EventNudge (+26 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.06
Nodes (74): Comparable, Hashable, AreaCount, CategoryCount, HouseIssue, IssueArea, balcony, basement (+66 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.05
Nodes (42): Action, alert, avatarRemoved, avatarSelected, avatarUpdated, avatarUpdateFailed, binding, checkForUpdatesTapped (+34 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.20
Nodes (10): PollDetail, PollItem, PollOutcome, Result, agreed, closest, nothing, Int (+2 more)

### Community 32 - "Community 32"
Cohesion: 0.05
Nodes (38): Element, Error, Sendable, AvatarDirectory, String, URL, AvatarEntry, String (+30 more)

### Community 33 - "Community 33"
Cohesion: 0.06
Nodes (34): Action, alert, backTapped, ballotToggled, binding, cuisineChosen, customAdded, delegate (+26 more)

### Community 34 - "Community 34"
Cohesion: 0.10
Nodes (24): CancelID, captured, presentSettings, CaptureKind, open(), owner(), push(), route() (+16 more)

### Community 35 - "Community 35"
Cohesion: 0.05
Nodes (18): AuthenticationServices, CancelID, handoff, AvatarInitials, CGFloat, String, AvatarViewerBar, String (+10 more)

### Community 36 - "Auth Manager"
Cohesion: 0.06
Nodes (34): Action, addTapped, advanceTapped, alert, areaFilterTapped, binding, boardUpdated, categoryFilterTapped (+26 more)

### Community 37 - "Expense & Item Models"
Cohesion: 0.06
Nodes (31): accounts, activity, activityCategories, allUpdates, anyAdminId(), badge, cachedReleaseCheck, countsAsUnread() (+23 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.09
Nodes (37): AlreadyDecidedBanner, CuisineTile, DinnerPlanCard, DinnerSheet, KindCard, RecipeChoice, RoundView, RouteCard (+29 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.06
Nodes (32): Action, addFailed, addFinished, addTapped, alert, binding, categoryToggled, clearCategoryTapped (+24 more)

### Community 40 - "Community 40"
Cohesion: 0.11
Nodes (18): CodingKeys, assignedTo, completedAt, completedBy, created, createdBy, details, dueDate (+10 more)

### Community 41 - "App Services Core"
Cohesion: 0.10
Nodes (25): AnyCancellable, Combine, ConvexClientWithAuth, DependencyValues, async, String, UsersClient, ArgumentBox (+17 more)

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.05
Nodes (37): CaseIterable, SplitMode, equal, exact, shares, IssueEntryKind, comment, link (+29 more)

### Community 44 - "Movie Search Row"
Cohesion: 0.05
Nodes (39): Action, alert, binding, confirmed, deleteConfirmed, deleteFailed, deleteTapped, destination (+31 more)

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.06
Nodes (31): Error, LocalizedError, AppError, cancelled, decoding, noHomeSelected, notAuthenticated, offline (+23 more)

### Community 46 - "Community 46"
Cohesion: 0.18
Nodes (13): DinnerCandidate, State, Action, AlertState, Bool, Cuisine, HomeID, IdentifiedArrayOf (+5 more)

### Community 47 - "New Message Group"
Cohesion: 0.06
Nodes (42): Action, addTapped, alert, binding, cancelTapped, classified, composer, delegate (+34 more)

### Community 48 - "Poll Input Sheets"
Cohesion: 0.11
Nodes (21): LockIsolated, Conversation, Kind, audio, document, gif, image, system (+13 more)

### Community 49 - "Previous Polls"
Cohesion: 0.06
Nodes (37): Action, addMoviesTapped, addTapped, alert, allMoviesUpdated, binding, createListTapped, delegate (+29 more)

### Community 50 - "Theme Selection"
Cohesion: 0.08
Nodes (25): Action, capture, capturedDismissed, capturedOpenTapped, companion, customize, home, house (+17 more)

### Community 51 - "Recipe List View"
Cohesion: 0.13
Nodes (19): HubModule, calendar, finance, maintenance, movies, notes, recipes, shopping (+11 more)

### Community 52 - "Read Receipts"
Cohesion: 0.09
Nodes (21): Action, alert, archiveUpdated, deleteFailed, deleteTapped, loadFailed, restoreFailed, restoreTapped (+13 more)

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
Cohesion: 0.22
Nodes (8): RelativeTimeClock, Duration, Int, Never, Task, Text, Void, NSObjectProtocol

### Community 57 - "Switch Home Sheet"
Cohesion: 0.07
Nodes (28): Action, alert, archiveTapped, binding, composeTapped, contributionsTapped, delegate, deleteFinishedFailed (+20 more)

### Community 58 - "Genre Picker"
Cohesion: 0.26
Nodes (12): DependencyValues, DinnerDecision, MealsClient, async, Cuisine, Error, EventID, HomeID (+4 more)

### Community 59 - "Swipe Card"
Cohesion: 0.10
Nodes (23): Kind, actor, decade, director, genre, nowPlaying, popular, topRated (+15 more)

### Community 60 - "Recipe Card"
Cohesion: 0.03
Nodes (76): Action, addBillTapped, addBudgetTapped, addExpenseTapped, alert, billPaid, billRestored, billsUpdated (+68 more)

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
Cohesion: 0.24
Nodes (12): createRecipe(), DependencyValues, NewRecipe, RecipesClient, async, Bool, Error, HomeID (+4 more)

### Community 65 - "Community 65"
Cohesion: 0.15
Nodes (8): MealDate, Calendar, String, DinnerFeature, ReducerOf, DinnerOccasionTests, DinnerTests, Recipe

### Community 66 - "Loading Button"
Cohesion: 0.08
Nodes (30): checkedRecipes(), create, ensurePresetLists, get, join, leave, listMine, members (+22 more)

### Community 67 - "Preset List Card"
Cohesion: 0.15
Nodes (11): HeroCard, HomeView, SuggestedDinnerCard, Bill, Bool, LocalizedStringResource, StoreOf, String (+3 more)

### Community 68 - "Search Results List"
Cohesion: 0.11
Nodes (28): Bill, BudgetProgress, EventSpend, Expense, ExpenseSplit, ExpenseWeight, FinanceSummary, MemberFinance (+20 more)

### Community 69 - "Language Selection"
Cohesion: 0.10
Nodes (23): Alert, alertArgs, cachedJWT, correctTokenEnvironment, currentUserId, deliver(), Device, dropToken (+15 more)

### Community 70 - "Match Options Sheet"
Cohesion: 0.08
Nodes (24): 10. Suggested cutover order, 10b. Troubleshooting: `InvalidAccountId` on sign‑in, 11. Gotchas checklist, 1. The mental-model shift (read this first), 2. Add the Convex Swift SDK, 3. Auth: replace `PocketBaseAuthManager`, 4. Replace `PocketBaseManager` with typed calls, 5. Models / DTOs (`PocketBaseModels.swift`) (+16 more)

### Community 71 - "Vibrant Module Card"
Cohesion: 0.09
Nodes (27): out, DependencyValues, EventEdit, EventsClient, StockUpResult, async, Bool, ConvexEncodable (+19 more)

### Community 72 - "Chat Header"
Cohesion: 0.12
Nodes (17): Phase, cooking, ingredients, State, StepTimer, Action, AlertState, Bool (+9 more)

### Community 73 - "Message Input"
Cohesion: 0.27
Nodes (10): CastMember, Kind, custom, watched, wishlist, Movie, MovieExtras, Double (+2 more)

### Community 74 - "Community 74"
Cohesion: 0.18
Nodes (17): Identifiable, ContributionDay, ContributionSlice, ContributionWindow, allTime, month, week, Count (+9 more)

### Community 75 - "Community 75"
Cohesion: 0.07
Nodes (30): Action, alert, binding, cancelTapped, composer, delegate, deleteTapped, editTapped (+22 more)

### Community 76 - "Custom List Row"
Cohesion: 0.05
Nodes (36): CustomStringConvertible, ExpressibleByStringLiteral, AppUpdate, AppVersion, Bool, Int, String, UpdateAvailability (+28 more)

### Community 77 - "Overlay Views"
Cohesion: 0.18
Nodes (6): AvatarPhoto, CGFloat, Data, Int, UIImage, AvatarPhotoTests

### Community 78 - "Message Hashing"
Cohesion: 0.28
Nodes (4): CalendarFeatureTests, DependencyValues, Double, Void

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
Cohesion: 0.16
Nodes (12): State, Action, AlertState, AppUpdate, Bool, Effect, HomeID, IdentifiedArrayOf (+4 more)

### Community 86 - "Community 86"
Cohesion: 0.11
Nodes (19): Action, alert, authorsResolved, binding, colorSelected, composeTapped, deleteFailed, deleteTapped (+11 more)

### Community 87 - "Notes View"
Cohesion: 0.26
Nodes (7): GlassCard, GlassGroup, Metrics, Bool, CGFloat, Content, View

### Community 88 - "Task Priority"
Cohesion: 0.42
Nodes (8): CategoryHeader, GroupHeader, GroupMenu, ShoppingRow, Bool, Int, String, Void

### Community 90 - "Community 90"
Cohesion: 0.11
Nodes (18): CodingKeys, category, created, createdBy, details, eventID, eventTitle, homeID (+10 more)

### Community 91 - "Community 91"
Cohesion: 0.27
Nodes (10): DependencyValues, PushClient, PushTokenBroker, AsyncStream, Bool, Int, String, UNAuthorizationStatus (+2 more)

### Community 92 - "Community 92"
Cohesion: 0.16
Nodes (18): Kind, generic, movie, recipe, Poll, PollVote, Status, active (+10 more)

### Community 93 - "Community 93"
Cohesion: 0.06
Nodes (38): Animatable, Configuration, GeometryEffect, Glass, IntegerFormatStyle, EnvironmentValues, GlassList, GlassListRow (+30 more)

### Community 94 - "Community 94"
Cohesion: 0.11
Nodes (19): MovieGenre, action, adventure, animation, comedy, crime, documentary, drama (+11 more)

### Community 95 - "Community 95"
Cohesion: 0.15
Nodes (13): Budget, SpendCategory, dining, entertainment, groceries, health, household, other (+5 more)

### Community 96 - "Community 96"
Cohesion: 0.09
Nodes (27): CodingKeys, cookTime, created, createdBy, difficulty, homeID, id, image (+19 more)

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
Cohesion: 0.11
Nodes (18): GlassTextField, Bool, LocalizedStringResource, String, SectionHeader, LocalizedStringResource, String, AdminUpdateRow (+10 more)

### Community 102 - "Community 102"
Cohesion: 0.09
Nodes (26): MealPlanID, Cuisine, american, chinese, indian, italian, japanese, korean (+18 more)

### Community 103 - "Community 103"
Cohesion: 0.30
Nodes (10): ActivityChart, Arc, ContributionDonut, ContributionLegend, ContributionSlice, ShareBar, CGFloat, Double (+2 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (5): LoadingView, SkeletonList, CGFloat, Int, LocalizedStringResource

### Community 105 - "Community 105"
Cohesion: 0.11
Nodes (17): CalendarFeature, members, State, Action, AlertState, Bool, Destination, Duration (+9 more)

### Community 106 - "Community 106"
Cohesion: 0.33
Nodes (5): Alert, confirmDelete, AlertState, NoteID, Self

### Community 107 - "Community 107"
Cohesion: 0.04
Nodes (50): ID, bastilleDay, bonfireNight, canadaDay, carnival, childrensDayTR, christmas, dayOfTheDead (+42 more)

### Community 108 - "Community 108"
Cohesion: 0.17
Nodes (10): ImageIO, PhotoCompressor, Bool, CGFloat, Data, UIImage, PhotoCompressorTests, UIImage (+2 more)

### Community 109 - "Community 109"
Cohesion: 0.09
Nodes (21): CancelID, members, tasks, undo, ComposeTaskFeature, Delegate, openArchive, openContributions (+13 more)

### Community 110 - "Community 110"
Cohesion: 0.10
Nodes (19): Action, appEnteredForeground, auth, authStatusChanged, currentUserChanged, deviceRegistered, deviceRegistrationFailed, deviceTokenReceived (+11 more)

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
Cohesion: 0.10
Nodes (14): ShoppingFeature, Duration, ReducerOf, ShoppingView, EdgeInsets, StoreOf, CustomizeTests, GroupExtrasTests (+6 more)

### Community 115 - "Community 115"
Cohesion: 0.06
Nodes (35): Codable, tree, CompanionHouse, Decor, flags, item, Graduate, Jar (+27 more)

### Community 116 - "Community 116"
Cohesion: 0.12
Nodes (16): CodingKeys, content, conversationID, created, file, homeID, id, isGroupChat (+8 more)

### Community 117 - "Community 117"
Cohesion: 0.13
Nodes (15): CodingKeys, created, genres, homeID, id, imdbID, isPreset, kind (+7 more)

### Community 118 - "Community 118"
Cohesion: 0.20
Nodes (10): Backend notes, Commands, Conventions, graphify, Layout, Navigation, Nestie (the companion), NestZone (+2 more)

### Community 119 - "Community 119"
Cohesion: 0.16
Nodes (12): MovieList.Kind, State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf (+4 more)

### Community 120 - "Community 120"
Cohesion: 0.08
Nodes (30): IssueEdit, IssuePhotoUpload, PhotoUpload, Action, areaTapped, assigneeTapped, binding, categoryTapped (+22 more)

### Community 121 - "Community 121"
Cohesion: 0.05
Nodes (26): Animation, PushResult, Int, ManageHomesFeature, ReducerOf, Self, AlertState, Destination (+18 more)

### Community 122 - "Community 122"
Cohesion: 0.12
Nodes (20): CancelID, detail, PartsDraft, State, StatusNote, Action, AlertState, Bool (+12 more)

### Community 123 - "Community 123"
Cohesion: 0.26
Nodes (9): Int, Anchor, Clock, DateReader, DateWords, Reading, Bool, Set (+1 more)

### Community 124 - "Community 124"
Cohesion: 0.06
Nodes (34): App, AppFeature, ReducerOf, Self, CodingKeys, address, created, id (+26 more)

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
Cohesion: 0.07
Nodes (39): BillCycle, Action, alert, binding, delegate, deleteTapped, everyoneTapped, failed (+31 more)

### Community 129 - "Community 129"
Cohesion: 0.29
Nodes (8): CameraPicker, Coordinator, Bool, Data, Void, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIViewControllerRepresentable

### Community 130 - "Community 130"
Cohesion: 0.18
Nodes (19): BillRow, BudgetCard, DayHeader, EventSpendRow, ExpenseRow, FinanceView, PayerRow, RepairSpendRow (+11 more)

### Community 131 - "Community 131"
Cohesion: 0.09
Nodes (26): IndexSet, Action, cancelTapped, delegate, doneTapped, resetTapped, sectionsMoved, visibilityPicked (+18 more)

### Community 132 - "Community 132"
Cohesion: 0.18
Nodes (14): activityArgs(), DependencyValues, InboxClient, ReleaseCheck, AppUpdate, AppUpdateID, async, ConvexEncodable (+6 more)

### Community 133 - "Community 133"
Cohesion: 0.12
Nodes (15): Character, parts, AmountReader, CaptureDate, Decimal, Substring, Vocabulary.Hit, CaptureKind (+7 more)

### Community 134 - "Community 134"
Cohesion: 0.07
Nodes (28): Action, alert, binding, createTapped, destination, homeSelected, homesFailed, homesUpdated (+20 more)

### Community 135 - "Community 135"
Cohesion: 0.13
Nodes (22): CaptureAmount, CaptureConfidence, none, strong, weak, CaptureDraft, CaptureKind, chore (+14 more)

### Community 136 - "Community 136"
Cohesion: 0.25
Nodes (4): AvatarCropTests, PhotoZoomTests, CGFloat, CGSize

### Community 137 - "Community 137"
Cohesion: 0.33
Nodes (5): MemberRow, Bool, Double, Int, String

### Community 138 - "Community 138"
Cohesion: 0.05
Nodes (41): DecorItem, autumnLeaves, bats, bouquet, bunting, candyBowl, colourPowder, confetti (+33 more)

### Community 139 - "Community 139"
Cohesion: 0.10
Nodes (22): ColorScheme, Control, Backdrop, GlassListLab, LabRow, Model, SpacingSample, SpacingSampleStack (+14 more)

### Community 140 - "Community 140"
Cohesion: 0.32
Nodes (8): Cache, Recipe, SampleRecipe, SampleRecipeLoader, Bool, Int, Recipe, String

### Community 141 - "Community 141"
Cohesion: 0.15
Nodes (15): Bool, Decoder, Int, String, TaskID, UserID, TaskArchive, TaskCompletion (+7 more)

### Community 142 - "Community 142"
Cohesion: 0.15
Nodes (19): ClearTarget, category, event, issue, meal, purchased, State, Action (+11 more)

### Community 143 - "Community 143"
Cohesion: 0.16
Nodes (14): AddItemField, DisclosureRow, EventComposerSheet, EventComposerToolbar, EventDetailSheet, RecapTile, RecipePickerSheet, Bool (+6 more)

### Community 144 - "Community 144"
Cohesion: 0.25
Nodes (8): Counter, events, problems, shopping, unread, Loaded, Int, OptionSet

### Community 145 - "Community 145"
Cohesion: 0.21
Nodes (11): apiKey(), details, discover, fetchJSON(), fetchPages(), GENRE_NAMES, GENRES, TMDbCredit (+3 more)

### Community 146 - "Community 146"
Cohesion: 0.16
Nodes (18): FoundationModels, LanguageModelSession, CaptureClassifierClient, CaptureModel, CaptureVerdict, chore, event, expense (+10 more)

### Community 147 - "Community 147"
Cohesion: 0.11
Nodes (16): AnyShapeStyle, Bool, CGFloat, Content, Gesture, LocalizedStringResource, Void, SwipeToDelete (+8 more)

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
Cohesion: 0.14
Nodes (16): AppleCredential, AuthClient, AuthStatus, authenticated, unauthenticated, unknown, DependencyValues, RestoreOutcome (+8 more)

### Community 154 - "Alert"
Cohesion: 0.12
Nodes (16): CodingKey, CodingKeys, canRestore, completedAt, email, id, kind, name (+8 more)

### Community 155 - "Community 155"
Cohesion: 0.11
Nodes (21): AppView, CapturedToast, LaunchView, MainView, NowSheets, OfflineView, RouteStackView, SegmentedRoot (+13 more)

### Community 156 - "Community 156"
Cohesion: 0.19
Nodes (11): AppTheme, basic, cyberpunk, deepOcean, neonNight, retroWave, EnvironmentValues, Palette (+3 more)

### Community 157 - "Community 157"
Cohesion: 0.15
Nodes (6): AlertState, HomeFeature, Duration, ReducerOf, Self, HomeFeatureTests

### Community 158 - "Community 158"
Cohesion: 0.06
Nodes (37): Action, albumTapped, buyTapped, careTapped, celebrateTapped, ceremonyFinished, chooseTapped, chose (+29 more)

### Community 159 - "Community 159"
Cohesion: 0.17
Nodes (15): CountdownText, DayCell, DayTimeline, EventRow, Placed, PlanRing, Bool, CGFloat (+7 more)

### Community 160 - "RecipeDetailFeature"
Cohesion: 0.10
Nodes (21): Action, addTapped, alert, decideDinnerTapped, delegate, dinner, dinnerSuggestionAccepted, dockTapped (+13 more)

### Community 161 - "Community 161"
Cohesion: 0.17
Nodes (14): IssueComposerSheet, IssueInlineError, IssueSheetToolbar, PartsSheet, StatusNoteSheet, Bool, Int, IssueArea (+6 more)

### Community 162 - "Community 162"
Cohesion: 0.29
Nodes (6): Deprecations, Is it safe to remove yet?, Notes on what is already here, Row format, The register, What that means in practice

### Community 163 - "Community 163"
Cohesion: 0.11
Nodes (20): BinaryInteger, Date, Decoder, Double, RelativeTimeText, Burst, CompanionScene, Kind (+12 more)

### Community 164 - "SettingsView"
Cohesion: 0.40
Nodes (5): Delegate, customizeTapped, homeSwitched, languageChanged, notificationsEnabled

### Community 165 - "HomeStats"
Cohesion: 0.08
Nodes (19): AlertState, BillComposerFeature, BudgetEditorFeature, ExpenseComposerFeature, PayBillFeature, SettleUpFeature, ReducerOf, Self (+11 more)

### Community 166 - "Delegate"
Cohesion: 0.33
Nodes (5): AlertState, ShoppingItem.Category, LocalizedStringResource, Self, String

### Community 167 - "Cache"
Cohesion: 0.15
Nodes (12): Actions, `ci_scripts/` — why the first builds failed, Did it work?, Environment, Finally, Post-Actions, Start Conditions, The division of labour (+4 more)

### Community 168 - "auth.config.ts"
Cohesion: 0.12
Nodes (22): DateInterval, Holiday, HolidayTables, LunarIndex, MonthDay, Rule, easter, fixed (+14 more)

### Community 169 - "schema.ts"
Cohesion: 0.15
Nodes (14): Alert, confirmDelete, State, Action, AlertState, Bool, Destination, Effect (+6 more)

### Community 170 - "README.md"
Cohesion: 0.18
Nodes (10): eventKind, financeCategory, issueArea, issueCategory, issueEntryKind, issueSeverity, issueStatus, recurrence (+2 more)

### Community 171 - "State"
Cohesion: 0.13
Nodes (18): ArraySlice, Alarm, issue, SetupStep, customize, dinner, firstChore, invite (+10 more)

### Community 172 - "HomeView"
Cohesion: 0.23
Nodes (9): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+1 more)

### Community 173 - "Action"
Cohesion: 0.18
Nodes (11): CodingKeys, issuesChange, messagesChange, notes, notesChange, openIssues, openTasks, shoppingChange (+3 more)

### Community 174 - "MainFeature"
Cohesion: 0.16
Nodes (15): Bloom, Branch, HSL, Leaf, Params, PlantModel, PlantPainter, Pose (+7 more)

### Community 175 - "Recipe"
Cohesion: 0.17
Nodes (12): Action, alert, delegate, detail, historyFailed, historyUpdated, rowTapped, task (+4 more)

### Community 176 - "SpendCategory"
Cohesion: 0.11
Nodes (25): CompanionFeature, ReducerOf, Self, AlbumView, CeremonyView, ChooseView, CompanionSheet, DecorateView (+17 more)

### Community 177 - "Kind"
Cohesion: 0.08
Nodes (27): Action, alert, createTapped, delegate, destination, doneTapped, homeTapped, joinTapped (+19 more)

### Community 178 - "MainFeature"
Cohesion: 0.25
Nodes (9): Layout, FlowLayout, Row, CGFloat, CGRect, CGSize, Int, ProposedViewSize (+1 more)

### Community 179 - "KeyboardDismisser"
Cohesion: 0.67
Nodes (3): CancelID, events, stats

### Community 180 - "Action"
Cohesion: 0.25
Nodes (8): AddedCount, DependencyValues, ShoppingClient, async, Error, Int, ShoppingItemID, Void

### Community 181 - "TaskEdit"
Cohesion: 0.11
Nodes (28): CategoryTotal, SpendPoint, Arc, BalanceBars, Bill, Bill.Urgency, BillCycle, BudgetProgress.Health (+20 more)

### Community 182 - "HomesClient"
Cohesion: 0.13
Nodes (12): Color, String, ConfettiBurst, TimeInterval, MemberTint, Double, LinearGradient, String (+4 more)

### Community 183 - "ManageHomesFeature.swift"
Cohesion: 0.14
Nodes (11): AlertState, Destination, history, movieInfo, pickKind, summary, PollHistoryFeature, PollKindFeature (+3 more)

### Community 184 - "State"
Cohesion: 0.50
Nodes (4): CancelID, badge, categories, feed

### Community 185 - "FinanceFeature"
Cohesion: 0.15
Nodes (13): Alert, confirmEndRound, AlertState, Cuisine, Delegate, finished, MealPlan.Kind, Source (+5 more)

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
Cohesion: 0.07
Nodes (34): AlertState, CancelID, all, lists, movies, saved, search, CreateMovieListFeature (+26 more)

### Community 191 - "Delegate"
Cohesion: 0.26
Nodes (5): CaptureParser, Calendar, Locale, Vocabulary, S

### Community 192 - "Community 192"
Cohesion: 0.05
Nodes (30): ComposableArchitecture, ConvexMobile, CoreGraphics, Foundation, NestZone, CancelID, history, CompanionFlag (+22 more)

### Community 193 - "ConfirmationDialogState"
Cohesion: 0.33
Nodes (8): Avatar, Source, directory, photo, Bool, CGFloat, String, URL

### Community 194 - "CalendarView"
Cohesion: 0.14
Nodes (13): HomeStats, Decoder, Int, Action, delegate, statsUpdated, task, tileTapped (+5 more)

### Community 195 - "Cuisine"
Cohesion: 0.09
Nodes (24): Hasher, IssueDetailFeature, ReducerOf, Self, Fallback, IssueDetailView, Optional, PlanRow (+16 more)

### Community 197 - "Community 197"
Cohesion: 0.18
Nodes (11): EventScope, occurrence, series, Delegate, deleted, edit, rsvpChanged, EventID (+3 more)

### Community 198 - "crons.ts"
Cohesion: 0.13
Nodes (8): AsyncThrowingStream, ConfirmationDialogState, EventComposerFeature, RecipePickerFeature, Effect, ReducerOf, Self, EventComposerTests

### Community 199 - "ChoiceCard"
Cohesion: 0.33
Nodes (6): ChoiceCard, HomeRow, Bool, LocalizedStringResource, String, Void

### Community 200 - "NewShoppingItem"
Cohesion: 0.25
Nodes (5): KeyboardDismisser, Bool, UIGestureRecognizer, UIGestureRecognizerDelegate, UITouch

### Community 201 - "PhotoZoom"
Cohesion: 0.39
Nodes (5): PhotoZoom, Bool, CGFloat, CGSize, Self

### Community 202 - "CancelID"
Cohesion: 0.09
Nodes (22): CodingKeys, above, album, bonus, careDays, current, ground, holidays (+14 more)

### Community 203 - "StatTile"
Cohesion: 0.15
Nodes (14): State, Action, AlertState, Bool, Destination, HomeID, IdentifiedArrayOf, String (+6 more)

### Community 205 - "Community 205"
Cohesion: 0.22
Nodes (9): MessagesFeature, NewConversationFeature, ReducerOf, Self, MessagesStack, MessagesView, NewConversationSheet, Root (+1 more)

### Community 206 - "CoreLogicTests"
Cohesion: 0.20
Nodes (9): CodingKeys, body, color, created, createdBy, homeID, id, image (+1 more)

### Community 207 - "IssuesFeature"
Cohesion: 0.12
Nodes (17): Delegate, open, EventID, IssueID, Recipe, Target, contributions, decideDinner (+9 more)

### Community 208 - "PollsClient"
Cohesion: 0.12
Nodes (15): Alert, CalendarFeature.Destination.State, CancelID, events, undo, Destination, compose, detail (+7 more)

### Community 209 - "Urgency"
Cohesion: 0.06
Nodes (33): DependencyKey, APNSEnvironment, DependencyValues, DevicesClient, String, Void, DependencyValues, MessagesClient (+25 more)

### Community 210 - "Delegate"
Cohesion: 0.17
Nodes (9): EventDetailFeature, ReducerOf, State, Action, AlertState, HomeID, IdentifiedArrayOf, UserID (+1 more)

### Community 211 - "AvatarPickerFace"
Cohesion: 0.20
Nodes (9): ComposeNoteFeature, Destination, compose, ReducerOf, ComposeNoteSheet, NoteCard, Bool, String (+1 more)

### Community 212 - "Source"
Cohesion: 0.50
Nodes (4): Delegate, capture, openEvent, openMovieNight

### Community 213 - "SymbolBounceModifier"
Cohesion: 0.15
Nodes (13): CodingKeys, created, cuisine, date, event, homeID, id, kind (+5 more)

### Community 214 - "Delegate"
Cohesion: 0.39
Nodes (6): AffectedCount, IssueEdit, ConvexEncodable, Int, String, VisitBooking

### Community 215 - "CancelID"
Cohesion: 0.19
Nodes (4): CompanionTests, Calendar, Int, String

### Community 216 - "UndoToast"
Cohesion: 0.21
Nodes (11): care_growth(), day(), grid(), life_growth(), poisson(), r_for(), NestZone companion growth simulation (v2: two tracks).  Daily growth = life grow, (life_raw, any_signal, carers) for one household-day, rules applied. (+3 more)

### Community 217 - "IssueComposerFeature"
Cohesion: 0.13
Nodes (12): AvatarSource, camera, library, remove, view, Bool, LocalizedStringResource, AvatarSourceRow (+4 more)

### Community 218 - "InboxAdminFeature"
Cohesion: 0.27
Nodes (7): ASAuthorization, AuthFeature, ReducerOf, Self, AuthView, Error, StoreOf

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
Cohesion: 0.24
Nodes (8): CompanionMath, Completion, Bool, Calendar, Double, Int, Mood, UserID

### Community 224 - "Community 224"
Cohesion: 0.11
Nodes (23): HouseTask, Kind, cleaning, general, maintenance, shopping, Priority, high (+15 more)

### Community 225 - ".alert"
Cohesion: 0.22
Nodes (12): CompanionMath, Decor, DecorItem, Holiday.Family, Holiday.ID, Mood, Species, Spot (+4 more)

### Community 226 - "HomeStats"
Cohesion: 0.29
Nodes (7): CancelID, bills, events, issues, members, stats, tasks

### Community 227 - "AppSettings.swift"
Cohesion: 0.40
Nodes (5): Delegate, decideDinner, openEvent, openShoppingList, EventID

### Community 228 - "Community 228"
Cohesion: 0.40
Nodes (4): c, http, iv, t0

### Community 229 - "FinanceFeature"
Cohesion: 0.29
Nodes (7): CancelID, clock, events, meals, members, polls, stats

### Community 230 - "Self"
Cohesion: 0.23
Nodes (6): content, NotesFeature, NotesView, Content, StoreOf, NotesTests

### Community 231 - "StepDuration"
Cohesion: 0.33
Nodes (6): Delegate, deleteRequested, openEvent, openShoppingList, EventID, IssueID

### Community 233 - "PasteboardClient"
Cohesion: 0.13
Nodes (17): DockItem, add, dinner, dinnerSuggestion, dinnerUndecided, happening, movieRound, startingSoon (+9 more)

### Community 234 - "Community 234"
Cohesion: 0.50
Nodes (3): client, iv, started

### Community 235 - "Community 235"
Cohesion: 0.13
Nodes (13): AlertState, ComposeRecipeFeature, Destination, compose, detail, Recipe.Difficulty, RecipeDetailFeature, RecipesFeature.Destination.State (+5 more)

### Community 236 - "Scope"
Cohesion: 0.14
Nodes (12): Decided, Handoff: Nestie, the household companion, How we got here, Next steps, Still open (your call), Things learned the hard way, What's built, Working agreements (from this machine's memory) (+4 more)

### Community 237 - "AvatarSourceSheet"
Cohesion: 0.14
Nodes (12): Alert, confirmClearLeftovers, AlertState, CancelID, plan, ConfirmationDialogState, Scope, deleteAll (+4 more)

### Community 238 - "AvatarViewerBar"
Cohesion: 0.40
Nodes (3): RecipesFeature, SavedRecipeTests, RecipeID

### Community 239 - "CancelID"
Cohesion: 0.50
Nodes (4): CancelID, board, handoff, undo

### Community 240 - "PollCandidate"
Cohesion: 0.29
Nodes (7): CompanionCard, Bool, LocalizedStringResource, StoreOf, String, Void, Companion

### Community 243 - "Alert"
Cohesion: 0.20
Nodes (9): Backend notes, Commands, Conventions, graphify, Layout, Navigation, NestZone, One deployment, every app version (+1 more)

### Community 245 - "Community 245"
Cohesion: 0.06
Nodes (33): EventKind, anniversary, appointment, birthday, chore, cinema, concert, deadline (+25 more)

### Community 247 - "IssuePhotoIDs"
Cohesion: 0.21
Nodes (6): Ink, Random, Double, String, T, UInt32

### Community 248 - "CancelID"
Cohesion: 0.60
Nodes (3): AvatarRollback, String, URL

### Community 249 - ".newestFirst"
Cohesion: 0.17
Nodes (11): BindableAction, Action, binding, failed, finished, submitTapped, succeeded, State (+3 more)

### Community 250 - "MovieList.Kind"
Cohesion: 0.17
Nodes (12): Family, buddhist, christian, eastAsian, hindu, jewish, muslim, national (+4 more)

### Community 252 - "BillCycle"
Cohesion: 0.06
Nodes (35): Equatable, NewTask, Bool, ConvexEncodable, HomeID, String, UserID, TaskEdit (+27 more)

### Community 253 - "IssueComposerFeature"
Cohesion: 0.38
Nodes (5): HouseStatsFeature, ReducerOf, Self, HouseStatsView, StoreOf

### Community 254 - "PushRegistration"
Cohesion: 0.18
Nodes (11): HouseStatsGrid, HouseStatTile, events, issues, messages, notes, shopping, tasks (+3 more)

### Community 255 - "HomeStats"
Cohesion: 0.08
Nodes (44): CurrencyTotal, EventHistory, EventOccurrence, EventPlan, EventReminder, atTime, oneDay, oneHour (+36 more)

### Community 256 - "CancelID"
Cohesion: 0.14
Nodes (11): MealPlan, NowDock, Bool, StoreOf, String, Text, NowFeature, Duration (+3 more)

### Community 257 - "TMDbImageWidth"
Cohesion: 0.25
Nodes (8): URL, TMDbImageWidth, original, w185, w342, w500, w780, w92

### Community 258 - "HomesClient"
Cohesion: 0.50
Nodes (4): DependencyValues, PasteboardClient, String, Void

### Community 259 - "HomeManagementFeature.swift"
Cohesion: 0.22
Nodes (7): EventHistoryFeature, ReducerOf, Self, EventHistorySheet, LocalizedStringResource, StoreOf, String

### Community 260 - "Alert"
Cohesion: 0.33
Nodes (6): Alert, confirmClearCategory, confirmClearEvent, confirmClearMeal, confirmClearParts, confirmClearPurchased

### Community 261 - "IssuesFeature"
Cohesion: 0.20
Nodes (7): Route.State, Segment, Bool, MealPlan, ReducerOf, Self, UserID

### Community 262 - "ArchiveRow"
Cohesion: 0.36
Nodes (7): Action, EmptyStateView, Action, Bool, LocalizedStringResource, String, Void

### Community 263 - "Community 263"
Cohesion: 0.14
Nodes (7): CalendarMonth, Calendar, Self, FinanceTests, BillID, ExpenseID, Int

### Community 264 - "String"
Cohesion: 0.22
Nodes (9): Kind, cuisine, custom, recipe, Route, set, vote, Recipe (+1 more)

### Community 265 - ".image"
Cohesion: 0.22
Nodes (7): BillCycle, biweekly, monthly, once, quarterly, weekly, yearly

### Community 266 - "KeychainTokenStore"
Cohesion: 0.39
Nodes (4): KeychainTokenStore, Any, String, Security

### Community 267 - "Section"
Cohesion: 0.31
Nodes (6): CurrencyDefaults, Shared<String?>, SharedKey, HomeID, Self, String

### Community 268 - "CancelID"
Cohesion: 0.50
Nodes (3): IssueComposerFeature, ReducerOf, Self

### Community 269 - ".userNotificationCenter"
Cohesion: 0.22
Nodes (8): AppDelegate, Void, NSObject, UIApplicationDelegate, UNNotification, UNNotificationPresentationOptions, UNUserNotificationCenter, UNUserNotificationCenterDelegate

### Community 270 - "Community 270"
Cohesion: 0.22
Nodes (9): Delegate, deleted, deleteRequested, paid, saved, settled, BillID, BudgetID (+1 more)

### Community 271 - "StepDuration"
Cohesion: 0.50
Nodes (4): StepDuration, Int, Substring, Regex

### Community 272 - "l10n_tool.py"
Cohesion: 0.43
Nodes (7): accessor(), localization(), main(), Apply a spec of string changes to L10n.swift and Localizable.xcstrings.  Usage:, %1$@ is %2$lld days' -> '\\(a0) is \\(a1) days'., swift_default(), unit()

### Community 273 - "AppLanguage"
Cohesion: 0.29
Nodes (6): AppLanguage, english, system, turkish, L10n, Locale

### Community 274 - "Chip"
Cohesion: 0.43
Nodes (5): Badge, Chip, Bool, String, Void

### Community 275 - "CancelID"
Cohesion: 0.33
Nodes (6): CancelID, addConfirmation, meals, saved, shopping, timer

### Community 276 - "StatTile"
Cohesion: 0.43
Nodes (5): StatTile, Int, LocalizedStringResource, String, Void

### Community 277 - "Action"
Cohesion: 0.25
Nodes (8): Action, alert, appleSignInFailed, appleSignInSucceeded, signInFailed, signInSucceeded, Alert, PresentationAction

### Community 278 - "EventComposerFeature.swift"
Cohesion: 0.25
Nodes (7): CancelID, recipes, Scope, deleteAll, deleteThisOne, saveAll, saveThisOne

### Community 279 - "Community 279"
Cohesion: 0.47
Nodes (4): PhotoUpload, Data, Int, String

### Community 280 - "Kind"
Cohesion: 0.25
Nodes (8): Kind, above, floor, ground, pot, sky, tree, weather

### Community 281 - "Community 281"
Cohesion: 0.07
Nodes (19): CodingKeys, avatar, avatarURL, created, email, homeIDs, id, name (+11 more)

### Community 282 - "GlanceClause"
Cohesion: 0.25
Nodes (8): GlanceClause, alarm, chores, eventToday, happening, next, tonight, MealPlan

### Community 283 - "UIImagePickerController"
Cohesion: 0.33
Nodes (3): Context, Any, UIImagePickerController

### Community 284 - "MainFeature.State"
Cohesion: 0.29
Nodes (3): MainFeature.State, CaptureKind, MainFeature

### Community 285 - "PushRegistration"
Cohesion: 0.29
Nodes (6): PushRegistration, failed, none, registered, Bool, String

### Community 286 - "HomesClient"
Cohesion: 0.33
Nodes (6): DependencyValues, HomesClient, async, Error, HomeID, Void

### Community 287 - "AvatarPickerFace"
Cohesion: 0.29
Nodes (6): AvatarPickerFace, Bool, CGFloat, String, UIImage, URL

### Community 288 - "Sheet"
Cohesion: 0.29
Nodes (7): Sheet, album, ceremony, choose, decorate, holidays, lab

### Community 289 - "GarlandStyle"
Cohesion: 0.29
Nodes (7): GarlandStyle, crescents, flags, hearts, lanterns, papel, shamrocks

### Community 290 - "Holiday dates: how they're worked out, and where they were checked"
Cohesion: 0.33
Nodes (5): Computed days, checked (2026–2027), Holiday dates: how they're worked out, and where they were checked, How a date is found, Sources, Tables (New Delhi), 2026–2030

### Community 291 - "CancelID"
Cohesion: 0.33
Nodes (6): CancelID, authState, currentUser, deviceRegistration, deviceToken, foreground

### Community 292 - "Community 292"
Cohesion: 0.05
Nodes (52): Action, allDayToggled, attendeeToggled, binding, delegate, deleteTapped, doneTapped, draftItemRemoved (+44 more)

### Community 293 - "Screen"
Cohesion: 0.33
Nodes (6): Screen, choosingHome, launching, main, offline, signedOut

### Community 294 - "UndoToast"
Cohesion: 0.53
Nodes (4): LocalizedStringResource, String, Void, UndoToast

### Community 295 - "InboxAdminFeature"
Cohesion: 0.40
Nodes (4): InboxAdminFeature, InboxComposerFeature, ReducerOf, Self

### Community 296 - ".alert"
Cohesion: 0.33
Nodes (5): Action, AlertState, Bool, String, TaskDeleteWarning

### Community 297 - "duck.js"
Cohesion: 0.60
Nodes (3): eyes(), head(), svg()

### Community 298 - "Health"
Cohesion: 0.40
Nodes (4): Health, close, healthy, over

### Community 299 - "Urgency"
Cohesion: 0.40
Nodes (5): Urgency, dueSoon, dueToday, overdue, upcoming

### Community 300 - "CatalogClient.swift"
Cohesion: 0.60
Nodes (4): CatalogClient, DependencyValues, MovieDetails, async

### Community 301 - "PhotoCompressionPlan"
Cohesion: 0.70
Nodes (4): PhotoCompressionPlan, Bool, CGFloat, Int

### Community 302 - "Folds"
Cohesion: 0.40
Nodes (5): Folds, EventID, IssueID, RecipeID, Set

### Community 303 - "PollCandidate"
Cohesion: 0.67
Nodes (3): PollCandidate, ConvexEncodable, String

### Community 305 - "State"
Cohesion: 0.50
Nodes (3): State, Action, AlertState

### Community 306 - "Delegate"
Cohesion: 0.50
Nodes (4): Delegate, openEvent, openShoppingList, EventID

### Community 307 - "CancelID"
Cohesion: 0.50
Nodes (4): CancelID, copyReset, members, pushTokenCopyReset

### Community 308 - "CancelID"
Cohesion: 0.67
Nodes (3): CancelID, items, undo

### Community 309 - "Alert"
Cohesion: 0.67
Nodes (3): Alert, confirmDelete, confirmQuit

## Knowledge Gaps
- **2267 isolated node(s):** `scenario.sh script`, `id`, `targets`, `launching`, `signedOut` (+2262 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Community 192` to `What-To-Watch Voting`, `Community 131`, `Community 132`, `Realtime Event Manager`, `Community 135`, `DTO Coding Keys`, `KeychainTokenStore`, `Community 140`, `Community 141`, `Messages View`, `AppLanguage`, `Community 146`, `Management Tab ViewModel`, `State`, `SectionHeader`, `Community 279`, `Community 281`, `Community 153`, `EventComposerFeature.swift`, `List & Difficulty Enums`, `PushRegistration`, `Note Color Extensions`, `HomesClient`, `Community 32`, `Community 34`, `Community 35`, `Community 163`, `auth.config.ts`, `App Services Core`, `CatalogClient.swift`, `No-Homes Onboarding`, `New Message Group`, `Poll Input Sheets`, `IssuePhotoIDs`, `Kind`, `FinanceFeature`, `State`, `CalendarView`, `Search Results List`, `crons.ts`, `Message Input`, `Community 74`, `Custom List Row`, `CoreLogicTests`, `PollsClient`, `Urgency`, `Delegate`, `Community 224`, `Community 96`, `.alert`, `Community 102`, `Community 235`, `AvatarSourceSheet`, `Community 109`, `Community 115`, `CancelID`, `Community 122`, `Community 124`, `HomeStats`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **Why does `AppError` connect `No-Homes Onboarding` to `Community 128`, `Model Coding Keys`, `Community 132`, `Community 134`, `Messages View`, `PocketBase Networking`, `New Recipe Sheet`, `Sample Recipes`, `Action`, `SectionHeader`, `Community 153`, `List & Difficulty Enums`, `HomesClient`, `Movie List Detail`, `RecipeDetailFeature`, `Community 33`, `Community 292`, `Auth Manager`, `Simple Movie Detail`, `App Services Core`, `schema.ts`, `Movie Search Row`, `Recipe`, `New Message Group`, `Kind`, `Previous Polls`, `Poll Input Sheets`, `Action`, `Note Creator`, `Community 54`, `Read Receipts`, `Switch Home Sheet`, `Recipe Card`, `Edit Note Sheet`, `Community 64`, `crons.ts`, `Vibrant Module Card`, `Community 75`, `Urgency`, `Community 85`, `Community 86`, `InboxAdminFeature`, `Community 98`, `Community 105`, `AvatarViewerBar`, `Community 114`, `Community 120`, `.newestFirst`, `Community 122`, `BillCycle`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Why does `L10n` connect `Movie UI Components` to `Community 35`, `Recipe Theming`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **What connects `scenario.sh script`, `id`, `targets` to the rest of the system?**
  _2267 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.0655367231638418 - nodes in this community are weakly interconnected._
- **Should `Localization Strings` be split into smaller, more focused modules?**
  _Cohesion score 0.07258064516129033 - nodes in this community are weakly interconnected._
- **Should `Model Coding Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.08064516129032258 - nodes in this community are weakly interconnected._