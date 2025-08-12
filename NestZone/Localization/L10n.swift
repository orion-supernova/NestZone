import Foundation

extension LocalizationManager {
    // MARK: - Settings
    static var settingsScreenTitle: String { t("settings_screen_title") }
    static var settingsProfileWelcomeBack: String { t("settings_profile_welcome_back") }
    static var settingsProfileCustomizeExperience: String { t("settings_profile_customize_experience") }

    static var settingsHomeManagementTitle: String { t("settings_home_management_title") }
    static var settingsCurrentHomeTitle: String { t("settings_current_home_title") }
    static var settingsMembersSingular: String { t("settings_members_singular") }
    static var settingsMembersPlural: String { t("settings_members_plural") }
    static var settingsInviteCodeTitle: String { t("settings_invite_code_title") }
    static var settingsInviteCodeCopyButton: String { t("settings_invite_code_copy_button") }
    static var settingsInviteCodeHelpText: String { t("settings_invite_code_help_text") }

    static var settingsAppearanceTitle: String { t("settings_appearance_title") }
    static var settingsThemeTitle: String { t("settings_theme_title") }
    static var settingsLanguageTitle: String { t("settings_language_title") }
    static var settingsThemeChooseTitle: String { t("settings_theme_choose_title") }
    static var settingsLanguageChooseTitle: String { t("settings_language_choose_title") }

    static var settingsAccountTitle: String { t("settings_account_title") }
    static var settingsProfileTitle: String { t("settings_profile_title") }
    static var settingsNotificationsTitle: String { t("settings_notifications_title") }

    static var settingsGeneralTitle: String { t("settings_general_title") }
    static var settingsHelpTitle: String { t("settings_help_title") }
    static var settingsAboutTitle: String { t("settings_about_title") }

    static var settingsLogoutButtonTitle: String { t("settings_logout_button_title") }

    // MARK: - Common
    static var commonDone: String { t("common_done") }
    static var commonCancel: String { t("common_cancel") }
    static var commonDelete: String { t("common_delete") }
    static var commonErrorTitle: String { t("common_error_title") }
    static var commonOkButton: String { t("common_ok_button") }

    // MARK: - Home Tab
    static func homeHelloUser(_ name: String) -> String { tFormat("home_hello_user", name) }
    static var homeHeaderSubtitle: String { t("home_header_subtitle") }
    static var homeMinigamesTitle: String { t("home_minigames_title") }
    static var homeMinigamesWatchTitle: String { t("home_minigames_watch_title") }
    static var homeMinigamesWatchDescription: String { t("home_minigames_watch_description") }
    static var homeStatsTitle: String { t("home_stats_title") }
    static var homeStatsNotesTitle: String { t("home_stats_notes_title") }
    static var homeStatsShoppingTitle: String { t("home_stats_shopping_title") }
    static var homeStatsIssuesTitle: String { t("home_stats_issues_title") }
    static var homeStatsTasksDoneTitle: String { t("home_stats_tasks_done_title") }

    // MARK: - Notes Tab
    static var notesScreenTitle: String { t("notes_screen_title") }
    static var notesEmptyStateTitle: String { t("notes_empty_state_title") }
    static var notesEmptyStateSubtitle: String { t("notes_empty_state_subtitle") }

    // MARK: - Management Tab
    static var managementScreenTitle: String { t("management_screen_title") }
    static var managementHeaderTitle: String { t("management_header_title") }
    static var managementHeaderSubtitle: String { t("management_header_subtitle") }
    
    // Module types
    static var managementModuleShoppingTitle: String { t("management_module_shopping_title") }
    static var managementModuleShoppingSubtitle: String { t("management_module_shopping_subtitle") }
    static var managementModuleRecipesTitle: String { t("management_module_recipes_title") }
    static var managementModuleRecipesSubtitle: String { t("management_module_recipes_subtitle") }
    static var managementModuleMoviesTitle: String { t("management_module_movies_title") }
    static var managementModuleMoviesSubtitle: String { t("management_module_movies_subtitle") }
    static var managementModuleMaintenanceTitle: String { t("management_module_maintenance_title") }
    static var managementModuleMaintenanceSubtitle: String { t("management_module_maintenance_subtitle") }
    static var managementModuleFinanceTitle: String { t("management_module_finance_title") }
    static var managementModuleFinanceSubtitle: String { t("management_module_finance_subtitle") }
    static var managementModuleNotesTitle: String { t("management_module_notes_title") }
    static var managementModuleNotesSubtitle: String { t("management_module_notes_subtitle") }
    static var managementModuleCalendarTitle: String { t("management_module_calendar_title") }
    static var managementModuleCalendarSubtitle: String { t("management_module_calendar_subtitle") }
    
    static var managementComingSoon: String { t("management_coming_soon") }
    
    // Shopping
    static var shoppingScreenTitle: String { t("shopping_screen_title") }
    static var shoppingHeaderTitle: String { t("shopping_header_title") }
    static var shoppingHeaderSubtitle: String { t("shopping_header_subtitle") }
    static var shoppingBackButton: String { t("shopping_back_button") }
    static var shoppingCategoriesTitle: String { t("shopping_categories_title") }
    static var shoppingAllItemsTitle: String { t("shopping_all_items_title") }
    static var shoppingListViewMode: String { t("shopping_list_view_mode") }
    static var shoppingCategoriesViewMode: String { t("shopping_categories_view_mode") }
    static var shoppingStatsTotal: String { t("shopping_stats_total") }
    static var shoppingStatsDone: String { t("shopping_stats_done") }
    static var shoppingStatsLeft: String { t("shopping_stats_left") }
    static var shoppingItemsCount: String { t("shopping_items_count") }
    static var shoppingEmptyStateTitle: String { t("shopping_empty_state_title") }
    static var shoppingEmptyStateSubtitle: String { t("shopping_empty_state_subtitle") }
    static var shoppingAddItemTitle: String { t("shopping_add_item_title") }
    static var shoppingDeleteItemTitle: String { t("shopping_delete_item_title") }
    static var shoppingDeleteItemMessage: String { t("shopping_delete_item_message") }
    static var shoppingCategoryGroceries: String { t("shopping_category_groceries") }
    static var shoppingCategoryHousehold: String { t("shopping_category_household") }
    static var shoppingCategoryCleaning: String { t("shopping_category_cleaning") }
    static var shoppingCategoryOther: String { t("shopping_category_other") }
    
    // Add item form
    static var shoppingAddItemDetails: String { t("shopping_add_item_details") }
    static var shoppingAddItemName: String { t("shopping_add_item_name") }
    static var shoppingAddItemDescription: String { t("shopping_add_item_description") }
    static var shoppingAddItemQuantityCategory: String { t("shopping_add_item_quantity_category") }
    static var shoppingAddItemQuantity: String { t("shopping_add_item_quantity") }
    static var shoppingAddItemCategory: String { t("shopping_add_item_category") }
    static var shoppingAddItemCancel: String { t("shopping_add_item_cancel") }
    static var shoppingAddItemAdd: String { t("shopping_add_item_add") }
    
    // Common buttons
    static var commonAdd: String { t("common_add") }
    static var commonBack: String { t("common_back") }
    static var commonClose: String { t("common_close") }
    static var commonCreate: String { t("common_create") }
    static var userUnknown: String { t("user_unknown") }

    // MARK: - Tab Bar
    static var tabBarHome: String { t("tab_bar_home") }
    static var tabBarHub: String { t("tab_bar_hub") }
    static var tabBarNotes: String { t("tab_bar_notes") }
    static var tabBarMessages: String { t("tab_bar_messages") }
    static var tabBarSettings: String { t("tab_bar_settings") }
    static var tabBarLoading: String { t("tab_bar_loading") }

    // MARK: - Recipes
    static var recipesExploreButton: String { t("recipes_explore_button") }
    static var recipesDeleteButton: String { t("recipes_delete_button") }
    static var recipesScreenTitle: String { t("recipes_screen_title") }
    static var recipesBackButton: String { t("recipes_back_button") }
    static var recipesHeaderTitle: String { t("recipes_header_title") }
    static var recipesHeaderSubtitle: String { t("recipes_header_subtitle") }
    static var recipesSearchPlaceholder: String { t("recipes_search_placeholder") }
    static var recipesTagAll: String { t("recipes_tag_all") }
    static var recipesEmptyStateTitle: String { t("recipes_empty_state_title") }
    static var recipesEmptyStateSubtitle: String { t("recipes_empty_state_subtitle") }

    static var recipesExploreAddToMyRecipes: String { t("recipes_explore_add_to_my_recipes") }
    static var recipesExploreScreenTitle: String { t("recipes_explore_screen_title") }
    static var recipesExploreCloseButton: String { t("recipes_explore_close_button") }
    static var recipesExploreHeaderTitle: String { t("recipes_explore_header_title") }
    static var recipesExploreHeaderSubtitle: String { t("recipes_explore_header_subtitle") }

    static var recipesExploreFiltersTitle: String { t("recipes_explore_filters_title") }
    static var recipesExploreFiltersClearAll: String { t("recipes_explore_filters_clear_all") }
    static var recipesExploreFiltersNoRecipesFound: String { t("recipes_explore_filters_no_recipes_found") }
    static var recipesExploreFiltersAdjustMessage: String { t("recipes_explore_filters_adjust_message") }
    static var recipesExploreFiltersClearButton: String { t("recipes_explore_filters_clear_button") }
    static var recipesExploreFilterSheetTitle: String { t("recipes_explore_filter_sheet_title") }
    static var recipesExploreFilterSheetReset: String { t("recipes_explore_filter_sheet_reset") }
    static var recipesExploreFilterSheetDone: String { t("recipes_explore_filter_sheet_done") }
    static var recipesExploreFilterDifficultyTitle: String { t("recipes_explore_filter_difficulty_title") }
    static var recipesExploreFilterCategoryTitle: String { t("recipes_explore_filter_category_title") }
    static var recipesExploreFilterTimeTitle: String { t("recipes_explore_filter_time_title") }
    static var recipesExploreFilterTimeAny: String { t("recipes_explore_filter_time_any") }
    static var recipesExploreFilterServingsTitle: String { t("recipes_explore_filter_servings_title") }
    static var recipesExploreFilterServingsAny: String { t("recipes_explore_filter_servings_any") }
    static var recipesExploreFilterRecipeFoundSingular: String { t("recipes_explore_filter_recipe_found_singular") }
    static var recipesExploreFilterRecipeFoundPlural: String { t("recipes_explore_filter_recipe_found_plural") }

    static var recipesNewRecipeTitleField: String { t("recipes_new_recipe_title_field") }
    static var recipesNewRecipeTitlePlaceholder: String { t("recipes_new_recipe_title_placeholder") }
    static var recipesNewRecipeDescriptionField: String { t("recipes_new_recipe_description_field") }
    static var recipesNewRecipeDescriptionPlaceholder: String { t("recipes_new_recipe_description_placeholder") }
    static var recipesNewRecipeScreenTitle: String { t("recipes_new_recipe_screen_title") }
    static var recipesNewRecipeAddButton: String { t("recipes_new_recipe_add_button") }
    static var recipesNewRecipeHeaderTitle: String { t("recipes_new_recipe_header_title") }
    static var recipesNewRecipeHeaderSubtitle: String { t("recipes_new_recipe_header_subtitle") }
    static var recipesNewRecipeTagsSectionTitle: String { t("recipes_new_recipe_tags_section_title") }
    static func recipesNewRecipeTagsLimitInfo(_ maxTags: Int) -> String { tFormat("recipes_new_recipe_tags_limit_info", maxTags) }
    static var recipesNewRecipeTimeServingsSectionTitle: String { t("recipes_new_recipe_time_servings_section_title") }
    static var recipesNewRecipePrepTimePlaceholder: String { t("recipes_new_recipe_prep_time_placeholder") }
    static var recipesNewRecipeCookTimePlaceholder: String { t("recipes_new_recipe_cook_time_placeholder") }
    static var recipesNewRecipeServingsPlaceholder: String { t("recipes_new_recipe_servings_placeholder") }
    static var recipesNewRecipeDifficultyPicker: String { t("recipes_new_recipe_difficulty_picker") }
    static var recipesNewRecipeIngredientsEditorTitle: String { t("recipes_new_recipe_ingredients_editor_title") }
    static var recipesNewRecipeStepsEditorTitle: String { t("recipes_new_recipe_steps_editor_title") }

    static var recipesCookingQuitAlertTitle: String { t("recipes_cooking_quit_alert_title") }
    static var recipesCookingQuitAlertQuitButton: String { t("recipes_cooking_quit_alert_quit_button") }
    static var recipesCookingQuitAlertMessage: String { t("recipes_cooking_quit_alert_message") }
    static var recipesCookingPrepareIngredients: String { t("recipes_cooking_prepare_ingredients") }
    static var recipesCookingCookRecipe: String { t("recipes_cooking_cook_recipe") }
    static var recipesCookingProgressLabel: String { t("recipes_cooking_progress_label") }
    static func recipesCookingIngredientsProgress(_ checked: Int, _ total: Int) -> String { tFormat("recipes_cooking_ingredients_progress", checked, total) }
    static func recipesCookingStepsProgress(_ current: Int, _ total: Int) -> String { tFormat("recipes_cooking_steps_progress", current, total) }
    static var recipesCookingCheckIngredientsInstruction: String { t("recipes_cooking_check_ingredients_instruction") }
    static var recipesCookingStartCookingButton: String { t("recipes_cooking_start_cooking_button") }
    static var recipesCookingBackButton: String { t("recipes_cooking_back_button") }
    static var recipesCookingFinishButton: String { t("recipes_cooking_finish_button") }
    static var recipesCookingNextStepButton: String { t("recipes_cooking_next_step_button") }
    static func recipesCookingStepCardTitle(_ stepNumber: Int, _ totalSteps: Int) -> String { tFormat("recipes_cooking_step_card_title", stepNumber, totalSteps) }

    static func recipesCardTimeFormat(_ minutes: Int) -> String { tFormat("recipes_card_time_format", minutes) }
    static var recipesCardTimeNotSpecified: String { t("recipes_card_time_not_specified") }

    static func recipesDetailTimeTotalFormat(_ minutes: Int) -> String { tFormat("recipes_detail_time_total_format", minutes) }
    static var recipesDetailTimeNotSpecified: String { t("recipes_detail_time_not_specified") }
    static var recipesDetailStartPreparingButton: String { t("recipes_detail_start_preparing_button") }
    static var recipesDetailDeleteAlertTitle: String { t("recipes_detail_delete_alert_title") }
    static func recipesDetailDeleteAlertMessage(_ recipeTitle: String) -> String { tFormat("recipes_detail_delete_alert_message", recipeTitle) }
    static var recipesDetailInfoCardPrep: String { t("recipes_detail_info_card_prep") }
    static var recipesDetailInfoCardCook: String { t("recipes_detail_info_card_cook") }
    static var recipesDetailInfoCardServes: String { t("recipes_detail_info_card_serves") }
    static var recipesDetailInfoCardLevel: String { t("recipes_detail_info_card_level") }
    static var recipesDetailIngredientsSectionTitle: String { t("recipes_detail_ingredients_section_title") }
    static var recipesDetailInstructionsSectionTitle: String { t("recipes_detail_instructions_section_title") }

    static var recipesDifficultyEasy: String { t("recipes_difficulty_easy") }
    static var recipesDifficultyMedium: String { t("recipes_difficulty_medium") }
    static var recipesDifficultyHard: String { t("recipes_difficulty_hard") }

    // MARK: - Messages
    static var messagesScreenTitle: String { t("messages_screen_title") }
    static var messagesNewMessageButton: String { t("messages_new_message_button") }
    static var messagesEmptyStateTitle: String { t("messages_empty_state_title") }
    static var messagesEmptyStateSubtitle: String { t("messages_empty_state_subtitle") }
    static var messagesCreateGroupChatButton: String { t("messages_create_group_chat_button") }
    static var messagesNoMessagesYet: String { t("messages_no_messages_yet") }
    static var messagesConversationCardGroupChatInitials: String { t("messages_conversation_card_group_chat_initials") }
    static var messagesConversationCardHouseholdMemberInitials: String { t("messages_conversation_card_household_member_initials") }
    static var messagesConversationCardDirectMessage: String { t("messages_conversation_card_direct_message") }
    static var messagesConversationCardHouseholdChat: String { t("messages_conversation_card_household_chat") }
    static var messagesLoadingConversations: String { t("messages_loading_conversations") }

    static var messagesNewGroupTitle: String { t("messages_new_group_title") }
    static var messagesNewGroupCancel: String { t("messages_new_group_cancel") }
    static var messagesNewGroupCreate: String { t("messages_new_group_create") }
    static var messagesNewGroupHeaderTitle: String { t("messages_new_group_header_title") }
    static func messagesNewGroupDescription(_ count: Int, _ homeName: String) -> String { tFormat("messages_new_group_description", count, homeName) }
    static var messagesNewGroupDescriptionGeneric: String { t("messages_new_group_description_generic") }
    static var messagesNewGroupNameLabel: String { t("messages_new_group_name_label") }
    static var messagesNewGroupNamePlaceholder: String { t("messages_new_group_name_placeholder") }
    static var messagesNewGroupFirstMessageLabel: String { t("messages_new_group_first_message_label") }
    static var messagesNewGroupFirstMessagePlaceholder: String { t("messages_new_group_first_message_placeholder") }
    static func messagesNewGroupMembersInfo(_ count: Int) -> String { tFormat("messages_new_group_members_info", count) }
    static var messagesNewGroupCreating: String { t("messages_new_group_creating") }
    static var messagesNewGroupErrorMissingInfo: String { t("messages_new_group_error_missing_info") }
    static func messagesNewGroupErrorCreationFailed(_ error: String) -> String { tFormat("messages_new_group_error_creation_failed", error) }

    static var messagesChatHeaderBack: String { t("messages_chat_header_back") }
    static var messagesChatLoading: String { t("messages_chat_loading") }
    static var messagesChatEmptyTitle: String { t("messages_chat_empty_title") }
    static var messagesChatEmptySubtitle: String { t("messages_chat_empty_subtitle") }
    static var messagesChatInputPlaceholder: String { t("messages_chat_input_placeholder") }
    static var messagesChatSendButton: String { t("messages_chat_send_button") }
    static var messagesChatMessageFailed: String { t("messages_chat_message_failed") }
    static var messagesChatMessageSending: String { t("messages_chat_message_sending") }
    static var messagesChatErrorTitle: String { t("messages_chat_error_title") }
    static var messagesChatErrorOk: String { t("messages_chat_error_ok") }
    static func messagesChatMembersCount(_ count: Int) -> String { tFormat("messages_chat_members_count", count) }

    // MARK: - MiniGames - What to Watch
    static var whatToWatchTitle: String { t("what_to_watch_title") }
    static var whatToWatchInPollInstructions: String { t("what_to_watch_in_poll_instructions") }
    static var whatToWatchNoInPollInstructions: String { t("what_to_watch_no_in_poll_instructions") }
    static var whatToWatchLoadingMovies: String { t("what_to_watch_loading_movies") }
    static var whatToWatchLoadingMoviesDetails: String { t("what_to_watch_loading_movies_details") }
    static var whatToWatchCreatingPoll: String { t("what_to_watch_creating_poll") }
    static var whatToWatchCreatingPollDetails: String { t("what_to_watch_creating_poll_details") }
    
    // Winner Announcement
    static var whatToWatchWinnerAnnouncement: String { t("what_to_watch_winner_announcement") }
    static var whatToWatchWinnerHouseVotes: String { t("what_to_watch_winner_house_votes") }
    
    // Buttons
    static var whatToWatchEndPoll: String { t("what_to_watch_end_poll") }
    static var whatToWatchStartPoll: String { t("what_to_watch_start_poll") }
    static var whatToWatchPreviousPolls: String { t("what_to_watch_previous_polls") }
    
    // Poll Complete
    static var whatToWatchPollComplete: String { t("what_to_watch_poll_complete") }
    static var whatToWatchPollCompleteSubtitle: String { t("what_to_watch_poll_complete_subtitle") }
    static var whatToWatchVotingProgress: String { t("what_to_watch_voting_progress") }
    static var whatToWatchWaitingStats: String { t("what_to_watch_waiting_stats") }
    static func whatToWatchVotingProgressCount(_ current: Int, _ total: Int) -> String { tFormat("what_to_watch_voting_progress_count", current, total) }
    
    // Poll Types
    static var pollTypeGenre: String { t("poll_type_genre") }
    static var pollTypeGenreDescription: String { t("poll_type_genre_description") }
    static var pollTypeActor: String { t("poll_type_actor") }
    static var pollTypeActorDescription: String { t("poll_type_actor_description") }
    static var pollTypeDirector: String { t("poll_type_director") }
    static var pollTypeDirectorDescription: String { t("poll_type_director_description") }
    static var pollTypeYear: String { t("poll_type_year") }
    static var pollTypeYearDescription: String { t("poll_type_year_description") }
    static var pollTypeDecade: String { t("poll_type_decade") }
    static var pollTypeDecadeDescription: String { t("poll_type_decade_description") }
    static var pollTypeNowPlaying: String { t("poll_type_now_playing") }
    static var pollTypeNowPlayingDescription: String { t("poll_type_now_playing_description") }
    static var pollTypePopular: String { t("poll_type_popular") }
    static var pollTypePopularDescription: String { t("poll_type_popular_description") }
    static var pollTypeTopRated: String { t("poll_type_top_rated") }
    static var pollTypeTopRatedDescription: String { t("poll_type_top_rated_description") }
    static var pollTypeUpcoming: String { t("poll_type_upcoming") }
    static var pollTypeUpcomingDescription: String { t("poll_type_upcoming_description") }
    
    // Poll Type Selection
    static var pollTypeSelectionTitle: String { t("poll_type_selection_title") }
    static var pollTypeSelectionSubtitle: String { t("poll_type_selection_subtitle") }
    
    // Genre Selection
    static var genreSelectionTitle: String { t("genre_selection_title") }
    static var genreSelectionSubtitle: String { t("genre_selection_subtitle") }
    static var genreSelectionSelected: String { t("genre_selection_selected") }
    static var genreSelectionClearAll: String { t("genre_selection_clear_all") }
    static var genreSelectionCreatePoll: String { t("genre_selection_create_poll") }
    static var genreSelectionSelectOneMessage: String { t("genre_selection_select_one_message") }
    static var genreSelectionIncludeAdult: String { t("genre_selection_include_adult") }
    static var genreSelectionIncludeAdultDescription: String { t("genre_selection_include_adult_description") }
    
    // Genre names and descriptions
    static var genreAction: String { t("genre_action") }
    static var genreActionDescription: String { t("genre_action_description") }
    static var genreAdventure: String { t("genre_adventure") }
    static var genreAdventureDescription: String { t("genre_adventure_description") }
    static var genreComedy: String { t("genre_comedy") }
    static var genreComedyDescription: String { t("genre_comedy_description") }
    static var genreDrama: String { t("genre_drama") }
    static var genreDramaDescription: String { t("genre_drama_description") }
    static var genreFantasy: String { t("genre_fantasy") }
    static var genreFantasyDescription: String { t("genre_fantasy_description") }
    static var genreHorror: String { t("genre_horror") }
    static var genreHorrorDescription: String { t("genre_horror_description") }
    static var genreRomance: String { t("genre_romance") }
    static var genreRomanceDescription: String { t("genre_romance_description") }
    static var genreSciFi: String { t("genre_sci_fi") }
    static var genreSciFiDescription: String { t("genre_sci_fi_description") }
    static var genreThriller: String { t("genre_thriller") }
    static var genreThrillerDescription: String { t("genre_thriller_description") }
    static var genreAnimation: String { t("genre_animation") }
    static var genreAnimationDescription: String { t("genre_animation_description") }
    
    // Actor Input
    static var actorInputTitle: String { t("actor_input_title") }
    static var actorInputSubtitle: String { t("actor_input_subtitle") }
    static var actorInputPlaceholder: String { t("actor_input_placeholder") }
    static var actorInputCreatePoll: String { t("actor_input_create_poll") }
    static var actorInputCreatingPoll: String { t("actor_input_creating_poll") }
    
    // Director Input
    static var directorInputTitle: String { t("director_input_title") }
    static var directorInputSubtitle: String { t("director_input_subtitle") }
    static var directorInputPlaceholder: String { t("director_input_placeholder") }
    static var directorInputCreatePoll: String { t("director_input_create_poll") }
    static var directorInputCreatingPoll: String { t("director_input_creating_poll") }
    
    // Year Input
    static var yearInputTitle: String { t("year_input_title") }
    static var yearInputSubtitle: String { t("year_input_subtitle") }
    static var yearInputSelectedYear: String { t("year_input_selected_year") }
    static func yearInputCreatePoll(_ year: Int) -> String { tFormat("year_input_create_poll", year) }
    static var yearInputCreatingPoll: String { t("year_input_creating_poll") }
    
    // Decade Input
    static var decadeInputTitle: String { t("decade_input_title") }
    static var decadeInputSubtitle: String { t("decade_input_subtitle") }
    static var decadeInputSelectedDecade: String { t("decade_input_selected_decade") }
    static func decadeInputCreatePoll(_ decade: Int) -> String { tFormat("decade_input_create_poll", decade) }
    static var decadeInputCreatingPoll: String { t("decade_input_creating_poll") }
    
    // Swipe Card
    static var swipeCardLike: String { t("swipe_card_like") }
    static var swipeCardNope: String { t("swipe_card_nope") }
    static var swipeCardTapForDetails: String { t("swipe_card_tap_for_details") }
    
    // Movie Details
    static var movieDetailsTitle: String { t("movie_details_title") }
    static var movieDetailsGenres: String { t("movie_details_genres") }
    static var movieDetailsOverview: String { t("movie_details_overview") }
    static var movieDetailsStatistics: String { t("movie_details_statistics") }
    static var movieDetailsRating: String { t("movie_details_rating") }
    static var movieDetailsVotes: String { t("movie_details_votes") }
    static var movieDetailsBudget: String { t("movie_details_budget") }
    static var movieDetailsRevenue: String { t("movie_details_revenue") }
    static var movieDetailsCast: String { t("movie_details_cast") }
    static var movieDetailsCrew: String { t("movie_details_crew") }
    static var movieDetailsDirectors: String { t("movie_details_directors") }
    static var movieDetailsWriters: String { t("movie_details_writers") }
    static var movieDetailsProduction: String { t("movie_details_production") }
    static var movieDetailsKeywords: String { t("movie_details_keywords") }
    static var movieDetailsLoadingDetails: String { t("movie_details_loading_details") }
    static func movieDetailsMinutes(_ minutes: Int) -> String { tFormat("movie_details_minutes", minutes) }
    
    // Match Options
    static var matchOptionsTitle: String { t("match_options_title") }
    static var matchOptionsMatchesFound: String { t("match_options_matches_found") }
    static var matchOptionsMatchesDescription: String { t("match_options_matches_description") }
    static var matchOptionsContinuePoll: String { t("match_options_continue_poll") }
    static func matchOptionsChooseWinner(_ movieTitle: String) -> String { tFormat("match_options_choose_winner", movieTitle) }
    static var matchOptionsEndPollSeeResults: String { t("match_options_end_poll_see_results") }
    
    // Poll Summary
    static var pollSummaryTitle: String { t("poll_summary_title") }
    static var pollSummaryComplete: String { t("poll_summary_complete") }
    static var pollSummaryDescription: String { t("poll_summary_description") }
    static var pollSummaryTotalVotes: String { t("poll_summary_total_votes") }
    static var pollSummaryParticipants: String { t("poll_summary_participants") }
    static var pollSummaryMatches: String { t("poll_summary_matches") }
    static var pollSummaryWinner: String { t("poll_summary_winner") }
    static var pollSummaryAllMatches: String { t("poll_summary_all_matches") }
    
    // Previous Polls
    static var previousPollsTitle: String { t("previous_polls_title") }
    static var previousPollsLoading: String { t("previous_polls_loading") }
    static var previousPollsEmpty: String { t("previous_polls_empty") }
    static var previousPollsEmptyDescription: String { t("previous_polls_empty_description") }
    static var previousPollsDeleteAlert: String { t("previous_polls_delete_alert") }
    static var previousPollsDeleteMessage: String { t("previous_polls_delete_message") }
    static var previousPollsDeleteError: String { t("previous_polls_delete_error") }
    static var previousPollsMoviePoll: String { t("previous_polls_movie_poll") }
    static var previousPollsWinner: String { t("previous_polls_winner") }
    static var previousPollsNoWinner: String { t("previous_polls_no_winner") }
    
    // Poll Controls
    static var pollControlsExitPoll: String { t("poll_controls_exit_poll") }
    static var pollControlsGetNewMovies: String { t("poll_controls_get_new_movies") }
    
    // Matches Section
    static var matchesSectionPopularChoices: String { t("matches_section_popular_choices") }
    static var matchesSectionDescription: String { t("matches_section_description") }
    
    // Poll Titles (for ViewModel)
    static func pollTitleGenre(_ genres: String) -> String { tFormat("poll_title_genre", genres) }
    static func pollTitleActor(_ actorName: String) -> String { tFormat("poll_title_actor", actorName) }
    static func pollTitleDirector(_ directorName: String) -> String { tFormat("poll_title_director", directorName) }
    static func pollTitleYear(_ year: Int) -> String { tFormat("poll_title_year", year) }
    static func pollTitleDecade(_ decade: Int) -> String { tFormat("poll_title_decade", decade) }
    static var pollTitleMixed: String { t("poll_title_mixed") }
    static var pollTitleNowPlaying: String { t("poll_title_now_playing") }
    static var pollTitlePopular: String { t("poll_title_popular") }
    static var pollTitleTopRated: String { t("poll_title_top_rated") }
    static var pollTitleUpcoming: String { t("poll_title_upcoming") }

    // Movie Lists
    static var movieDetailsAddToLists: String { t("movie_details_add_to_lists") }
    static func movieDetailsAddedToList(_ listName: String) -> String { tFormat("movie_details_added_to_list", listName) }
    static var movieListsDefaultListName: String { t("movie_lists_default_list_name") }

    static var yearInputPickerTitle: String { t("year_input_picker_title") }
}