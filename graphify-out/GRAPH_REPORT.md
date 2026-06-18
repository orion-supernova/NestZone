# Graph Report - .  (2026-06-18)

## Corpus Check
- 118 files · ~216,222 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1386 nodes · 2542 edges · 90 communities (89 shown, 1 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 111 edges (avg confidence: 0.8)
- Token cost: 0 input · 20,305 output

## Community Hubs (Navigation)
- [[_COMMUNITY_What-To-Watch Voting|What-To-Watch Voting]]
- [[_COMMUNITY_Localization Strings|Localization Strings]]
- [[_COMMUNITY_Model Coding Keys|Model Coding Keys]]
- [[_COMMUNITY_Confetti & Realtime Models|Confetti & Realtime Models]]
- [[_COMMUNITY_Movie API (TMDb)|Movie API (TMDb)]]
- [[_COMMUNITY_Recipe Theming|Recipe Theming]]
- [[_COMMUNITY_Movie List Model|Movie List Model]]
- [[_COMMUNITY_Realtime Event Manager|Realtime Event Manager]]
- [[_COMMUNITY_Movie UI Components|Movie UI Components]]
- [[_COMMUNITY_Polls Manager|Polls Manager]]
- [[_COMMUNITY_DTO Coding Keys|DTO Coding Keys]]
- [[_COMMUNITY_Movie Lists Manager|Movie Lists Manager]]
- [[_COMMUNITY_Messages View|Messages View]]
- [[_COMMUNITY_PocketBase Networking|PocketBase Networking]]
- [[_COMMUNITY_Home Tab ViewModel|Home Tab ViewModel]]
- [[_COMMUNITY_Home Creation & Tasks|Home Creation & Tasks]]
- [[_COMMUNITY_New Recipe Sheet|New Recipe Sheet]]
- [[_COMMUNITY_Shopping List UI|Shopping List UI]]
- [[_COMMUNITY_Sample Recipes|Sample Recipes]]
- [[_COMMUNITY_Management Tab ViewModel|Management Tab ViewModel]]
- [[_COMMUNITY_Notes ViewModel|Notes ViewModel]]
- [[_COMMUNITY_Unit & UI Tests|Unit & UI Tests]]
- [[_COMMUNITY_Match & Poll Summary|Match & Poll Summary]]
- [[_COMMUNITY_Messages Manager|Messages Manager]]
- [[_COMMUNITY_Home Tab Screen|Home Tab Screen]]
- [[_COMMUNITY_PocketBase Models|PocketBase Models]]
- [[_COMMUNITY_Movie Detail Sheet|Movie Detail Sheet]]
- [[_COMMUNITY_Cooking Mode|Cooking Mode]]
- [[_COMMUNITY_Poll Type Selection|Poll Type Selection]]
- [[_COMMUNITY_List & Difficulty Enums|List & Difficulty Enums]]
- [[_COMMUNITY_Movie List Detail|Movie List Detail]]
- [[_COMMUNITY_Note Color Extensions|Note Color Extensions]]
- [[_COMMUNITY_Movie Search ViewModel|Movie Search ViewModel]]
- [[_COMMUNITY_Message Bubble|Message Bubble]]
- [[_COMMUNITY_Authentication Screen|Authentication Screen]]
- [[_COMMUNITY_Home Selection Manager|Home Selection Manager]]
- [[_COMMUNITY_Auth Manager|Auth Manager]]
- [[_COMMUNITY_Expense & Item Models|Expense & Item Models]]
- [[_COMMUNITY_Premium Text Field|Premium Text Field]]
- [[_COMMUNITY_Simple Movie Detail|Simple Movie Detail]]
- [[_COMMUNITY_User Service|User Service]]
- [[_COMMUNITY_App Services Core|App Services Core]]
- [[_COMMUNITY_PocketBase Polls Schema|PocketBase Polls Schema]]
- [[_COMMUNITY_Chat Detail|Chat Detail]]
- [[_COMMUNITY_Movie Search Row|Movie Search Row]]
- [[_COMMUNITY_No-Homes Onboarding|No-Homes Onboarding]]
- [[_COMMUNITY_Login Screen|Login Screen]]
- [[_COMMUNITY_New Message Group|New Message Group]]
- [[_COMMUNITY_Poll Input Sheets|Poll Input Sheets]]
- [[_COMMUNITY_Previous Polls|Previous Polls]]
- [[_COMMUNITY_Theme Selection|Theme Selection]]
- [[_COMMUNITY_Recipe List View|Recipe List View]]
- [[_COMMUNITY_Read Receipts|Read Receipts]]
- [[_COMMUNITY_Note Creator|Note Creator]]
- [[_COMMUNITY_Home Setup Flow|Home Setup Flow]]
- [[_COMMUNITY_Swipe Deck|Swipe Deck]]
- [[_COMMUNITY_Home Selection View|Home Selection View]]
- [[_COMMUNITY_Switch Home Sheet|Switch Home Sheet]]
- [[_COMMUNITY_Genre Picker|Genre Picker]]
- [[_COMMUNITY_Swipe Card|Swipe Card]]
- [[_COMMUNITY_Recipe Card|Recipe Card]]
- [[_COMMUNITY_Chat Messages List|Chat Messages List]]
- [[_COMMUNITY_Edit Note Sheet|Edit Note Sheet]]
- [[_COMMUNITY_Auth DTOs|Auth DTOs]]
- [[_COMMUNITY_Auth Errors|Auth Errors]]
- [[_COMMUNITY_Message Types|Message Types]]
- [[_COMMUNITY_Loading Button|Loading Button]]
- [[_COMMUNITY_Preset List Card|Preset List Card]]
- [[_COMMUNITY_Search Results List|Search Results List]]
- [[_COMMUNITY_Language Selection|Language Selection]]
- [[_COMMUNITY_Match Options Sheet|Match Options Sheet]]
- [[_COMMUNITY_Vibrant Module Card|Vibrant Module Card]]
- [[_COMMUNITY_Chat Header|Chat Header]]
- [[_COMMUNITY_Message Input|Message Input]]
- [[_COMMUNITY_Expense Categories|Expense Categories]]
- [[_COMMUNITY_Authentication ViewModel|Authentication ViewModel]]
- [[_COMMUNITY_Custom List Row|Custom List Row]]
- [[_COMMUNITY_Overlay Views|Overlay Views]]
- [[_COMMUNITY_Message Hashing|Message Hashing]]
- [[_COMMUNITY_Management Tab Screen|Management Tab Screen]]
- [[_COMMUNITY_Tab Bar ViewModel|Tab Bar ViewModel]]
- [[_COMMUNITY_Note Card|Note Card]]
- [[_COMMUNITY_Event Categories|Event Categories]]
- [[_COMMUNITY_Task Types|Task Types]]
- [[_COMMUNITY_Create Movie List|Create Movie List]]
- [[_COMMUNITY_Mini Module Card|Mini Module Card]]
- [[_COMMUNITY_Module Cards Section|Module Cards Section]]
- [[_COMMUNITY_Notes View|Notes View]]
- [[_COMMUNITY_Task Priority|Task Priority]]
- [[_COMMUNITY_Bungalaven App Icon|Bungalaven App Icon]]

## God Nodes (most connected - your core abstractions)
1. `SwiftUI` - 88 edges
2. `CodingKeys` - 59 edges
3. `WhatToWatchViewModel` - 45 edges
4. `LocalizationManager` - 35 edges
5. `Movie` - 35 edges
6. `String` - 34 edges
7. `Foundation` - 29 edges
8. `MovieAPI` - 28 edges
9. `String` - 26 edges
10. `HomeTabViewModel` - 24 edges

## Surprising Connections (you probably didn't know these)
- `CardViewModel` --calls--> `UUID`  [INFERRED]
  NestZone/Modules/TabBarSubScreens/HomeTabScreen/MiniGames/MovieSelectionGame/WhatToWatchView.swift → NestZone/Models/HouseTask.swift
- `AuthenticationScreen` --calls--> `AuthenticationViewModel`  [INFERRED]
  NestZone/Modules/Auth/AuthenticationScreen.swift → NestZone/Modules/Auth/AuthenticationViewModel.swift
- `HomeSetupFlow` --calls--> `HomeManagementViewModel`  [INFERRED]
  NestZone/Modules/Auth/HomeSetupFlow.swift → NestZone/Modules/HomeManagement/HomeManagementViewModel.swift
- `CreateHomeView` --calls--> `HomeManagementViewModel`  [INFERRED]
  NestZone/Modules/HomeManagement/CreateHomeView.swift → NestZone/Modules/HomeManagement/HomeManagementViewModel.swift
- `JoinHomeView` --calls--> `HomeManagementViewModel`  [INFERRED]
  NestZone/Modules/HomeManagement/JoinHomeView.swift → NestZone/Modules/HomeManagement/HomeManagementViewModel.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Generic polls data model (polls, items, votes scoped to homes)** — pocketbase_readme_polls, pocketbase_readme_poll_items, pocketbase_readme_poll_votes, pocketbase_readme_homes [EXTRACTED 1.00]

## Communities (90 total, 1 thin omitted)

### Community 0 - "What-To-Watch Voting"
Cohesion: 0.05
Nodes (29): CardViewModel, WhatToWatchView, WinnerAnnouncementView, Bool, CardViewModel, Double, Int, Movie (+21 more)

### Community 1 - "Localization Strings"
Cohesion: 0.08
Nodes (22): CVarArg, LocalizationManager, Language, english, turkish, LocalizationManager, ModuleData, ModuleType (+14 more)

### Community 2 - "Model Coding Keys"
Cohesion: 0.04
Nodes (57): CodingKeys, address, allDay, amount, assignedTo, avatar, category, color (+49 more)

### Community 3 - "Confetti & Realtime Models"
Cohesion: 0.06
Nodes (28): Context, ConfettiView, HomeSelectionManager, PocketBaseAuthManager, Bool, CGSize, Bool, PocketBaseConversation (+20 more)

### Community 4 - "Movie API (TMDb)"
Cohesion: 0.15
Nodes (13): CastMember, Hashable, CastMember, Movie, MovieAPI, MovieExtras, MovieHistoryManager, Bool (+5 more)

### Community 5 - "Recipe Theming"
Cohesion: 0.07
Nodes (32): ColorScheme, Content, Color, Recipe, RecipeViewModel, String, Color, Home (+24 more)

### Community 6 - "Movie List Model"
Cohesion: 0.06
Nodes (30): CodingKeys, created, description, genres, homeId, id, imdbId, isPreset (+22 more)

### Community 7 - "Realtime Event Manager"
Cohesion: 0.10
Nodes (27): Action, LocalizedError, Any, Bool, Data, Error, PocketBaseRealtimeEvent, Set (+19 more)

### Community 8 - "Movie UI Components"
Cohesion: 0.06
Nodes (25): App, PollControls, SearchHeader, SearchLoadingView, WhatToWatchHeader, MovieListsView, MovieRow, ContentView (+17 more)

### Community 9 - "Polls Manager"
Cohesion: 0.17
Nodes (12): HomeLite, PBListResponse, Poll, PollItem, PollsManager, PollVote, User, Bool (+4 more)

### Community 10 - "DTO Coding Keys"
Cohesion: 0.06
Nodes (33): CodingKey, CodingKeys, avatar, created, email, entityType, externalId, genre (+25 more)

### Community 11 - "Movie Lists Manager"
Cohesion: 0.14
Nodes (12): HomeLite, MovieListsManager, PBListResponse, Bool, Int, Movie, MovieList, MovieListType (+4 more)

### Community 12 - "Messages View"
Cohesion: 0.11
Nodes (13): ConversationCard, MessagesView, Home, Int, PocketBaseAuthManager, PocketBaseConversation, String, Int (+5 more)

### Community 13 - "PocketBase Networking"
Cohesion: 0.15
Nodes (16): AFDataResponse, HTTPMethod, Any, Bool, Data, String, T, PocketBaseError (+8 more)

### Community 14 - "Home Tab ViewModel"
Cohesion: 0.15
Nodes (7): HomeTabViewModel, Color, Double, Error, NSObjectProtocol, String, PocketBaseTask

### Community 15 - "Home Creation & Tasks"
Cohesion: 0.10
Nodes (18): CreateHomeView, HomeManagementViewModel, JoinHomeView, HouseTaskViewModel, TaskType, cleaning, maintenance, shopping (+10 more)

### Community 16 - "New Recipe Sheet"
Cohesion: 0.12
Nodes (19): Binding, Field, Bool, Recipe, RecipeViewModel, Set, String, Void (+11 more)

### Community 17 - "Shopping List UI"
Cohesion: 0.18
Nodes (23): GroupedViewButton, MiniShoppingCard, PlainViewButton, RainbowNewItemSheet, ShimmerCategoryCard, ShimmerPlainItem, ShoppingCategoriesSection, ShoppingHeaderView (+15 more)

### Community 18 - "Sample Recipes"
Cohesion: 0.14
Nodes (18): Bool, Double, Int, Recipe, RecipeViewModel, String, Void, Int (+10 more)

### Community 19 - "Management Tab ViewModel"
Cohesion: 0.21
Nodes (6): ManagementTabViewModel, Color, Double, NSObjectProtocol, ShoppingItem, String

### Community 20 - "Notes ViewModel"
Cohesion: 0.19
Nodes (7): Bool, NSObjectProtocol, PocketBaseAuthManager, PocketBaseNote, PocketBaseUser, String, NotesViewModel

### Community 21 - "Unit & UI Tests"
Cohesion: 0.11
Nodes (7): NestZone, NestZoneTests, NestZoneUITests, NestZoneUITestsLaunchTests, Bool, XCTest, XCTestCase

### Community 22 - "Match & Poll Summary"
Cohesion: 0.15
Nodes (16): MatchesSection, MatchMovieCard, PollSummarySheet, StatBox, SummaryMovieRow, WinnerCard, Movie, Void (+8 more)

### Community 23 - "Messages Manager"
Cohesion: 0.19
Nodes (7): Bool, Int, PocketBaseConversation, PocketBaseMessage, PocketBaseUser, String, MessagesManager

### Community 24 - "Home Tab Screen"
Cohesion: 0.19
Nodes (13): HomeTabScreen, MiniGamesSection, NavigableStatCard, NavigableStatsSection, SimpleHeaderView, HomeTabViewModel, Bool, Color (+5 more)

### Community 25 - "PocketBase Models"
Cohesion: 0.23
Nodes (16): Difficulty, EventCategory, GeoPoint, Identifiable, Bool, String, TaskType, CalendarEvent (+8 more)

### Community 26 - "Movie Detail Sheet"
Cohesion: 0.25
Nodes (11): AddButtonsSection, MovieDetailInfoSheet, MovieDetailSheet, Color, Movie, MovieExtras, MovieList, MovieListsViewModel (+3 more)

### Community 27 - "Cooking Mode"
Cohesion: 0.18
Nodes (14): CookingPhase, Bool, Color, Int, Recipe, Set, String, Void (+6 more)

### Community 28 - "Poll Type Selection"
Cohesion: 0.16
Nodes (14): PollType, actor, decade, director, genre, nowPlaying, popular, topRated (+6 more)

### Community 29 - "List & Difficulty Enums"
Cohesion: 0.14
Nodes (14): CaseIterable, MovieListType, custom, watched, wishlist, Difficulty, easy, hard (+6 more)

### Community 30 - "Movie List Detail"
Cohesion: 0.19
Nodes (12): ActiveSheet, addMovies, movieDetail, MovieCardView, MovieListDetailView, Color, MovieList, MovieListsViewModel (+4 more)

### Community 31 - "Note Color Extensions"
Cohesion: 0.19
Nodes (12): Date, NoteColor, blue, green, orange, pink, purple, red (+4 more)

### Community 32 - "Movie Search ViewModel"
Cohesion: 0.18
Nodes (8): SearchMoviesForListSheet, Movie, MovieList, Void, Movie, Set, String, SearchMoviesViewModel

### Community 33 - "Message Bubble"
Cohesion: 0.21
Nodes (8): Bool, CGFloat, PocketBaseConversation, PocketBaseMessage, PocketBaseUser, String, MessageBubble, UserAvatar

### Community 34 - "Authentication Screen"
Cohesion: 0.17
Nodes (8): AuthenticationScreen, DragGesture, Bool, CGFloat, PocketBaseAuthManager, String, ThemeColors, ValidationState

### Community 35 - "Home Selection Manager"
Cohesion: 0.26
Nodes (5): HomeSelectionManager, Bool, Home, PocketBaseAuthManager, String

### Community 36 - "Auth Manager"
Cohesion: 0.32
Nodes (4): AuthUser, String, serverError, PocketBaseAuthManager

### Community 37 - "Expense & Item Models"
Cohesion: 0.24
Nodes (11): Codable, ExpenseCategory, Double, Int, T, Expense, GeoPoint, PocketBaseErrorResponse (+3 more)

### Community 38 - "Premium Text Field"
Cohesion: 0.20
Nodes (10): PremiumTextField, ValidationState, invalid, neutral, valid, Bool, LinearGradient, String (+2 more)

### Community 39 - "Simple Movie Detail"
Cohesion: 0.24
Nodes (9): CastMemberCard, CrewSection, SimpleMovieDetailSheet, StatCard, Color, Int, Movie, MovieExtras (+1 more)

### Community 40 - "User Service"
Cohesion: 0.38
Nodes (4): PocketBaseUser, Set, String, UserService

### Community 41 - "App Services Core"
Cohesion: 0.22
Nodes (3): Alamofire, Foundation, Notification.Name

### Community 42 - "PocketBase Polls Schema"
Cohesion: 0.33
Nodes (10): polls.candidates JSON (lightweight external IDs), PocketBase Generic Polls (REST, no realtime), Home membership access rules, homes collection (members relation), Migration path candidates JSON to poll_items, poll_items collection, poll_votes collection, Client polling without SSE/realtime (+2 more)

### Community 43 - "Chat Detail"
Cohesion: 0.33
Nodes (6): ChatDetailViewModel, ChatDetailView, Bool, PocketBaseConversation, String, Void

### Community 44 - "Movie Search Row"
Cohesion: 0.33
Nodes (8): ActionButtonView, MovieInfoView, MoviePosterView, MovieSearchRow, Bool, CGSize, Movie, Void

### Community 45 - "No-Homes Onboarding"
Cohesion: 0.22
Nodes (8): NoHomesView, OnboardingHero, WelcomeCard, Color, HomeSelectionManager, PocketBaseAuthManager, String, Void

### Community 46 - "Login Screen"
Cohesion: 0.25
Nodes (5): LoginScreen, LoginViewModel, PocketBaseAuthManager, PocketBaseAuthManager, String

### Community 47 - "New Message Group"
Cohesion: 0.22
Nodes (7): NewMessageView, Bool, Home, PocketBaseAuthManager, PocketBaseConversation, String, Void

### Community 48 - "Poll Input Sheets"
Cohesion: 0.44
Nodes (8): ActorInputSheet, DecadeInputSheet, DirectorInputSheet, YearInputSheet, Bool, Int, String, Void

### Community 49 - "Previous Polls"
Cohesion: 0.25
Nodes (7): deletePoll(), PollHistoryCard, Bool, Movie, Poll, String, Void

### Community 50 - "Theme Selection"
Cohesion: 0.36
Nodes (6): AppTheme, Bool, String, Void, ThemeButton, ThemeSelectionSheet

### Community 51 - "Recipe List View"
Cohesion: 0.29
Nodes (6): Bool, PocketBaseAuthManager, String, Void, RecipeListView, TagPill

### Community 52 - "Read Receipts"
Cohesion: 0.32
Nodes (5): PocketBaseMessage, PocketBaseUser, String, ReadReceiptRow, ReadReceiptsSheet

### Community 53 - "Note Creator"
Cohesion: 0.32
Nodes (7): Bool, Color, NotesViewModel, String, Void, ModernColorCircle, ModernNoteCreator

### Community 54 - "Home Setup Flow"
Cohesion: 0.29
Nodes (6): HomeSetupCard, HomeSetupFlow, Color, PocketBaseAuthManager, String, Void

### Community 55 - "Swipe Deck"
Cohesion: 0.33
Nodes (6): PollCompleteView, SwipeDeckView, CardViewModel, Movie, Void, VotingStats

### Community 56 - "Home Selection View"
Cohesion: 0.29
Nodes (6): HomeSelectionCard, HomeSelectionView, Home, HomeSelectionManager, PocketBaseAuthManager, Void

### Community 57 - "Switch Home Sheet"
Cohesion: 0.29
Nodes (6): SwitchHomeRow, SwitchHomeSheet, Bool, Home, HomeSelectionManager, Void

### Community 58 - "Genre Picker"
Cohesion: 0.43
Nodes (6): GenreCard, GenrePickerSheet, Bool, Set, String, Void

### Community 59 - "Swipe Card"
Cohesion: 0.29
Nodes (6): SwipeCard, CGFloat, CGSize, Double, Movie, Void

### Community 60 - "Recipe Card"
Cohesion: 0.48
Nodes (4): Color, Recipe, String, RecipeCard

### Community 61 - "Chat Messages List"
Cohesion: 0.33
Nodes (6): Bool, PocketBaseConversation, PocketBaseMessage, String, ChatMessagesList, PreviewWrapper

### Community 62 - "Edit Note Sheet"
Cohesion: 0.33
Nodes (5): Double, NotesViewModel, PocketBaseNote, String, EditNoteSheet

### Community 63 - "Auth DTOs"
Cohesion: 0.43
Nodes (6): AuthUser, Bool, String, AuthResponse, AuthUser, UserCreationResponse

### Community 64 - "Auth Errors"
Cohesion: 0.29
Nodes (7): AuthError, emailAlreadyExists, invalidCredentials, networkError, passwordMismatch, unauthorized, weakPassword

### Community 65 - "Message Types"
Cohesion: 0.29
Nodes (7): MessageType, audio, document, gif, image, system, video

### Community 66 - "Loading Button"
Cohesion: 0.33
Nodes (5): LoadingButton, Bool, Double, String, Void

### Community 67 - "Preset List Card"
Cohesion: 0.33
Nodes (5): PresetListCard, Color, Int, String, Void

### Community 68 - "Search Results List"
Cohesion: 0.33
Nodes (5): SearchResultsList, Movie, Set, String, Void

### Community 69 - "Language Selection"
Cohesion: 0.40
Nodes (5): Language, Bool, Void, LanguageButton, LanguageSelectionSheet

### Community 70 - "Match Options Sheet"
Cohesion: 0.47
Nodes (5): MatchMovieRow, MatchOptionsSheet, Bool, Movie, Void

### Community 71 - "Vibrant Module Card"
Cohesion: 0.33
Nodes (5): Bool, Color, Int, ModuleData, VibrantModuleCard

### Community 72 - "Chat Header"
Cohesion: 0.33
Nodes (4): PocketBaseConversation, String, Void, ChatHeader

### Community 73 - "Message Input"
Cohesion: 0.40
Nodes (5): Bool, String, Void, ChatMessageInputPreview, ChatMessageInputView

### Community 74 - "Expense Categories"
Cohesion: 0.33
Nodes (6): ExpenseCategory, groceries, household, other, rent, utilities

### Community 75 - "Authentication ViewModel"
Cohesion: 0.70
Nodes (3): AuthenticationViewModel, PocketBaseAuthManager, String

### Community 76 - "Custom List Row"
Cohesion: 0.40
Nodes (4): CustomListRow, Int, MovieList, Void

### Community 77 - "Overlay Views"
Cohesion: 0.60
Nodes (4): ErrorOverlay, SuccessOverlay, Bool, String

### Community 78 - "Message Hashing"
Cohesion: 0.50
Nodes (3): Hasher, MessageType, PocketBaseMessage

### Community 79 - "Management Tab Screen"
Cohesion: 0.40
Nodes (3): ManagementTabScreen, ModuleData, PocketBaseAuthManager

### Community 80 - "Tab Bar ViewModel"
Cohesion: 0.40
Nodes (4): Home, PocketBaseAuthManager, ObservableObject, TabBarScreenViewModel

### Community 81 - "Note Card"
Cohesion: 0.40
Nodes (4): PocketBaseNote, String, Void, NoteCard

### Community 82 - "Event Categories"
Cohesion: 0.40
Nodes (5): EventCategory, cleaning, maintenance, other, social

### Community 83 - "Task Types"
Cohesion: 0.40
Nodes (5): TaskType, cleaning, general, maintenance, shopping

### Community 84 - "Create Movie List"
Cohesion: 0.50
Nodes (3): CreateMovieListSheet, String, Void

### Community 85 - "Mini Module Card"
Cohesion: 0.50
Nodes (3): Color, String, MiniModuleCard

### Community 86 - "Module Cards Section"
Cohesion: 0.50
Nodes (3): Bool, ModuleData, ModuleCardsSection

### Community 87 - "Notes View"
Cohesion: 0.50
Nodes (3): PocketBaseAuthManager, PocketBaseNote, NotesView

### Community 88 - "Task Priority"
Cohesion: 0.50
Nodes (4): TaskPriority, high, low, medium

## Knowledge Gaps
- **454 isolated node(s):** `PocketBaseAuthManager`, `english`, `turkish`, `Notification.Name`, `String` (+449 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SwiftUI` connect `Movie UI Components` to `What-To-Watch Voting`, `Localization Strings`, `Confetti & Realtime Models`, `Movie API (TMDb)`, `Recipe Theming`, `Movie List Model`, `Messages View`, `Home Tab ViewModel`, `Home Creation & Tasks`, `New Recipe Sheet`, `Shopping List UI`, `Sample Recipes`, `Management Tab ViewModel`, `Notes ViewModel`, `Match & Poll Summary`, `Home Tab Screen`, `Movie Detail Sheet`, `Cooking Mode`, `Poll Type Selection`, `Movie List Detail`, `Note Color Extensions`, `Movie Search ViewModel`, `Message Bubble`, `Authentication Screen`, `Premium Text Field`, `Simple Movie Detail`, `App Services Core`, `Chat Detail`, `Movie Search Row`, `No-Homes Onboarding`, `Login Screen`, `New Message Group`, `Poll Input Sheets`, `Previous Polls`, `Theme Selection`, `Recipe List View`, `Read Receipts`, `Note Creator`, `Home Setup Flow`, `Swipe Deck`, `Home Selection View`, `Switch Home Sheet`, `Genre Picker`, `Swipe Card`, `Recipe Card`, `Chat Messages List`, `Edit Note Sheet`, `Loading Button`, `Preset List Card`, `Search Results List`, `Language Selection`, `Match Options Sheet`, `Vibrant Module Card`, `Chat Header`, `Message Input`, `Custom List Row`, `Overlay Views`, `Management Tab Screen`, `Note Card`, `Create Movie List`, `Mini Module Card`, `Module Cards Section`, `Notes View`?**
  _High betweenness centrality (0.282) - this node is a cross-community bridge._
- **Why does `Foundation` connect `App Services Core` to `What-To-Watch Voting`, `Localization Strings`, `Confetti & Realtime Models`, `Movie API (TMDb)`, `Movie List Model`, `Realtime Event Manager`, `Polls Manager`, `Movie Lists Manager`, `Messages View`, `Home Tab ViewModel`, `Home Creation & Tasks`, `Sample Recipes`, `Management Tab ViewModel`, `Notes ViewModel`, `Messages Manager`, `PocketBase Models`, `Note Color Extensions`, `Movie Search ViewModel`, `Login Screen`, `Auth DTOs`?**
  _High betweenness centrality (0.252) - this node is a cross-community bridge._
- **Why does `WhatToWatchViewModel` connect `What-To-Watch Voting` to `Tab Bar ViewModel`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **What connects `PocketBaseAuthManager`, `english`, `turkish` to the rest of the system?**
  _456 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What-To-Watch Voting` be split into smaller, more focused modules?**
  _Cohesion score 0.05405405405405406 - nodes in this community are weakly interconnected._
- **Should `Localization Strings` be split into smaller, more focused modules?**
  _Cohesion score 0.07936507936507936 - nodes in this community are weakly interconnected._
- **Should `Model Coding Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.03508771929824561 - nodes in this community are weakly interconnected._