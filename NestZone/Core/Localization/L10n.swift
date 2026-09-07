// Typed accessors for `Resources/Localizable.xcstrings`.
//
// Originally produced by migrating the old `en.json` / `tr.json` locale files
// into a String Catalog; the catalog is the source of truth now, so add new
// strings by adding a case here and the matching entry in Xcode's String
// Catalog editor.
//
// Every string resolves against `L10n.locale`, which is what makes the in-app
// language picker work without relying on SwiftUI's environment reaching each
// call site.

import Foundation
import Synchronization

public enum L10n {
    private static let storedLocale = Mutex<Locale>(.autoupdatingCurrent)

    /// Language the app renders in. Owned by `AppFeature`, which mirrors it
    /// from persisted settings and re-identifies the root view when it changes.
    ///
    /// Lock-protected rather than `@MainActor`-isolated: reducers build alert
    /// and error copy off the main actor, and a main-actor-only accessor would
    /// put an `await` in front of every string in the app.
    public static var locale: Locale {
        get { storedLocale.withLock { $0 } }
        set { storedLocale.withLock { $0 = newValue } }
    }

    private static func r(
        _ key: StaticString,
        _ value: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, defaultValue: value, locale: locale, bundle: .main)
    }

    /// Settings
    public static var settingsScreenTitle: LocalizedStringResource {
        r("settings_screen_title", "Settings")
    }

    /// Welcome back!
    public static var settingsProfileWelcomeBack: LocalizedStringResource {
        r("settings_profile_welcome_back", "Welcome back!")
    }

    /// Customize your experience
    public static var settingsProfileCustomizeExperience: LocalizedStringResource {
        r("settings_profile_customize_experience", "Customize your experience")
    }

    /// Home Management
    public static var settingsHomeManagementTitle: LocalizedStringResource {
        r("settings_home_management_title", "Home Management")
    }

    /// Current Home
    public static var settingsCurrentHomeTitle: LocalizedStringResource {
        r("settings_current_home_title", "Current Home")
    }

    /// Invite Code
    public static var settingsInviteCodeTitle: LocalizedStringResource {
        r("settings_invite_code_title", "Invite Code")
    }

    /// Copy
    public static var settingsInviteCodeCopyButton: LocalizedStringResource {
        r("settings_invite_code_copy_button", "Copy")
    }

    /// Share this code with household members so they can join your home
    public static var settingsInviteCodeHelpText: LocalizedStringResource {
        r("settings_invite_code_help_text", "Share this code with household members so they can join your home")
    }

    /// Appearance
    public static var settingsAppearanceTitle: LocalizedStringResource {
        r("settings_appearance_title", "Appearance")
    }

    /// Theme
    public static var settingsThemeTitle: LocalizedStringResource {
        r("settings_theme_title", "Theme")
    }

    /// Language
    public static var settingsLanguageTitle: LocalizedStringResource {
        r("settings_language_title", "Language")
    }

    /// Choose Theme
    public static var settingsThemeChooseTitle: LocalizedStringResource {
        r("settings_theme_choose_title", "Choose Theme")
    }

    /// Choose Language
    public static var settingsLanguageChooseTitle: LocalizedStringResource {
        r("settings_language_choose_title", "Choose Language")
    }

    /// Account
    public static var settingsAccountTitle: LocalizedStringResource {
        r("settings_account_title", "Account")
    }

    /// Profile
    public static var settingsProfileTitle: LocalizedStringResource {
        r("settings_profile_title", "Profile")
    }

    /// Notifications
    public static var settingsNotificationsTitle: LocalizedStringResource {
        r("settings_notifications_title", "Notifications")
    }

    /// General
    public static var settingsGeneralTitle: LocalizedStringResource {
        r("settings_general_title", "General")
    }

    /// Help
    public static var settingsHelpTitle: LocalizedStringResource {
        r("settings_help_title", "Help")
    }

    /// About
    public static var settingsAboutTitle: LocalizedStringResource {
        r("settings_about_title", "About")
    }

    /// Logout
    public static var settingsLogoutButtonTitle: LocalizedStringResource {
        r("settings_logout_button_title", "Logout")
    }

    /// Done
    public static var commonDone: LocalizedStringResource {
        r("common_done", "Done")
    }

    /// Error
    public static var commonErrorTitle: LocalizedStringResource {
        r("common_error_title", "Error")
    }

    /// OK
    public static var commonOkButton: LocalizedStringResource {
        r("common_ok_button", "OK")
    }

    /// Cancel
    public static var commonCancel: LocalizedStringResource {
        r("common_cancel", "Cancel")
    }

    /// Add
    public static var commonAdd: LocalizedStringResource {
        r("common_add", "Add")
    }

    /// Delete
    public static var commonDelete: LocalizedStringResource {
        r("common_delete", "Delete")
    }

    /// Undo
    public static var commonUndo: LocalizedStringResource {
        r("common_undo", "Undo")
    }

    /// Deleted “%@”
    public static func shoppingItemDeleted(_ a0: String) -> LocalizedStringResource {
        r("shopping_item_deleted", "Deleted “\(a0)”")
    }

    /// Back
    public static var commonBack: LocalizedStringResource {
        r("common_back", "Back")
    }

    /// Close
    public static var commonClose: LocalizedStringResource {
        r("common_close", "Close")
    }

    /// Create
    public static var commonCreate: LocalizedStringResource {
        r("common_create", "Create")
    }

    /// Unknown User
    public static var userUnknown: LocalizedStringResource {
        r("user_unknown", "Unknown User")
    }

    /// Home
    public static var tabBarHome: LocalizedStringResource {
        r("tab_bar_home", "Home")
    }

    /// Hub
    public static var tabBarHub: LocalizedStringResource {
        r("tab_bar_hub", "Hub")
    }

    /// Notes
    public static var tabBarNotes: LocalizedStringResource {
        r("tab_bar_notes", "Notes")
    }

    /// Messages
    public static var tabBarMessages: LocalizedStringResource {
        r("tab_bar_messages", "Messages")
    }

    /// Settings
    public static var tabBarSettings: LocalizedStringResource {
        r("tab_bar_settings", "Settings")
    }

    /// Loading...
    public static var tabBarLoading: LocalizedStringResource {
        r("tab_bar_loading", "Loading...")
    }

    /// Hello %@!
    public static func homeHelloUser(_ a0: String) -> LocalizedStringResource {
        r("home_hello_user", "Hello \(a0)!")
    }

    /// Manage your shared home together!
    public static var homeHeaderSubtitle: LocalizedStringResource {
        r("home_header_subtitle", "Manage your shared home together!")
    }

    /// Mini Games
    public static var homeMinigamesTitle: LocalizedStringResource {
        r("home_minigames_title", "Mini Games")
    }

    /// What to watch tonight
    public static var homeMinigamesWatchTitle: LocalizedStringResource {
        r("home_minigames_watch_title", "What to watch tonight")
    }

    /// Can't decide what to watch tonight? Let's play a quick game to pick one!
    public static var homeMinigamesWatchDescription: LocalizedStringResource {
        r("home_minigames_watch_description", "Can't decide what to watch tonight? Let's play a quick game to pick one!")
    }

    /// House Statistics
    public static var homeStatsTitle: LocalizedStringResource {
        r("home_stats_title", "House Statistics")
    }

    /// Notes
    public static var homeStatsNotesTitle: LocalizedStringResource {
        r("home_stats_notes_title", "Notes")
    }

    /// Shopping
    public static var homeStatsShoppingTitle: LocalizedStringResource {
        r("home_stats_shopping_title", "Shopping")
    }

    /// To do
    ///
    /// Open tasks. Replaces two tiles that were both about tasks — "Issues", a
    /// high-priority count that read 0 in any household that never sets
    /// priority, and "Tasks Done", an all-time total that only grew. Named for
    /// the state rather than the noun, so it does not collide with the "Tasks"
    /// section directly below it.
    public static var homeStatsTodoTitle: LocalizedStringResource {
        r("home_stats_todo_title", "To do")
    }

    /// Unread
    public static var homeStatsMessagesTitle: LocalizedStringResource {
        r("home_stats_messages_title", "Unread")
    }

    // MARK: Contributions

    /// Who does what
    public static var contributionsSectionTitle: LocalizedStringResource {
        r("contributions_section_title", "Who does what")
    }

    /// Contributions
    public static var contributionsScreenTitle: LocalizedStringResource {
        r("contributions_screen_title", "Contributions")
    }

    /// Week
    public static var contributionsWindowWeek: LocalizedStringResource {
        r("contributions_window_week", "Week")
    }

    /// Month
    public static var contributionsWindowMonth: LocalizedStringResource {
        r("contributions_window_month", "Month")
    }

    /// All time
    public static var contributionsWindowAllTime: LocalizedStringResource {
        r("contributions_window_all_time", "All time")
    }

    /// tasks done
    public static var contributionsDonutCaption: LocalizedStringResource {
        r("contributions_donut_caption", "tasks done")
    }

    /// Leaderboard
    public static var contributionsLeaderboardTitle: LocalizedStringResource {
        r("contributions_leaderboard_title", "Leaderboard")
    }

    /// Daily activity
    public static var contributionsActivityTitle: LocalizedStringResource {
        r("contributions_activity_title", "Daily activity")
    }

    /// Tasks finished each day
    public static var contributionsActivitySubtitle: LocalizedStringResource {
        r("contributions_activity_subtitle", "Tasks finished each day")
    }

    /// Busiest day: %lld
    public static func contributionsActivityBusiestDay(_ a0: Int) -> LocalizedStringResource {
        r("contributions_activity_busiest_day", "Busiest day: \(a0)")
    }

    /// Task split
    public static var contributionsShareBarLabel: LocalizedStringResource {
        r("contributions_share_bar_label", "Task split")
    }

    /// You
    public static var contributionsYou: LocalizedStringResource {
        r("contributions_you", "You")
    }

    /// Unassigned
    public static var contributionsUnattributed: LocalizedStringResource {
        r("contributions_unattributed", "Unassigned")
    }

    /// %lld days
    public static func contributionsStreak(_ a0: Int) -> LocalizedStringResource {
        r("contributions_streak", "\(a0) days")
    }

    /// %lld done
    public static func contributionsDoneCount(_ a0: Int) -> LocalizedStringResource {
        r("contributions_done_count", "\(a0) done")
    }

    /// %lld open
    public static func contributionsOpenCount(_ a0: Int) -> LocalizedStringResource {
        r("contributions_open_count", "\(a0) open")
    }

    /// %lld overdue
    public static func contributionsOverdueCount(_ a0: Int) -> LocalizedStringResource {
        r("contributions_overdue_count", "\(a0) overdue")
    }

    /// Nothing done yet
    public static var contributionsEmptyTitle: LocalizedStringResource {
        r("contributions_empty_title", "Nothing done yet")
    }

    /// Tick a task off and this fills in.
    public static var contributionsEmptyMessage: LocalizedStringResource {
        r("contributions_empty_message", "Tick a task off and this fills in.")
    }

    /// Nicely balanced
    public static var contributionsBalanceEvenTitle: LocalizedStringResource {
        r("contributions_balance_even_title", "Nicely balanced")
    }

    /// Everyone is doing about their share. Keep it up.
    public static var contributionsBalanceEvenMessage: LocalizedStringResource {
        r(
            "contributions_balance_even_message",
            "Everyone is doing about their share. Keep it up."
        )
    }

    /// Slightly lopsided
    public static var contributionsBalanceTiltedTitle: LocalizedStringResource {
        r("contributions_balance_tilted_title", "Slightly lopsided")
    }

    /// The split is drifting. Assigning a few tasks would even it out.
    public static var contributionsBalanceTiltedMessage: LocalizedStringResource {
        r(
            "contributions_balance_tilted_message",
            "The split is drifting. Assigning a few tasks would even it out."
        )
    }

    /// Someone is carrying the house
    public static var contributionsBalanceLopsidedTitle: LocalizedStringResource {
        r("contributions_balance_lopsided_title", "Someone is carrying the house")
    }

    /// Almost all of the housework is falling to one person.
    public static var contributionsBalanceLopsidedMessage: LocalizedStringResource {
        r(
            "contributions_balance_lopsided_message",
            "Almost all of the housework is falling to one person."
        )
    }

    /// Notes
    public static var notesScreenTitle: LocalizedStringResource {
        r("notes_screen_title", "Notes")
    }

    /// No Notes Yet
    public static var notesEmptyStateTitle: LocalizedStringResource {
        r("notes_empty_state_title", "No Notes Yet")
    }

    /// Create your first family note and start sharing thoughts
    public static var notesEmptyStateSubtitle: LocalizedStringResource {
        r("notes_empty_state_subtitle", "Create your first family note\nand start sharing thoughts")
    }

    /// Management Hub
    public static var managementScreenTitle: LocalizedStringResource {
        r("management_screen_title", "Management Hub")
    }

    /// Management Hub 🏠
    public static var managementHeaderTitle: LocalizedStringResource {
        r("management_header_title", "Management Hub 🏠")
    }

    /// Manage everything in one place! ✨
    public static var managementHeaderSubtitle: LocalizedStringResource {
        r("management_header_subtitle", "Manage everything in one place! ✨")
    }

    /// Shopping Lists
    public static var managementModuleShoppingTitle: LocalizedStringResource {
        r("management_module_shopping_title", "Shopping Lists")
    }

    /// Manage your shopping lists
    public static var managementModuleShoppingSubtitle: LocalizedStringResource {
        r("management_module_shopping_subtitle", "Manage your shopping lists")
    }

    /// Recipes
    public static var managementModuleRecipesTitle: LocalizedStringResource {
        r("management_module_recipes_title", "Recipes")
    }

    /// Save delicious recipes & meal plans
    public static var managementModuleRecipesSubtitle: LocalizedStringResource {
        r("management_module_recipes_subtitle", "Save delicious recipes & meal plans")
    }

    /// Movies
    public static var managementModuleMoviesTitle: LocalizedStringResource {
        r("management_module_movies_title", "Movies")
    }

    /// Create & manage movie lists
    public static var managementModuleMoviesSubtitle: LocalizedStringResource {
        r("management_module_movies_subtitle", "Create & manage movie lists")
    }

    /// House Problems
    public static var managementModuleMaintenanceTitle: LocalizedStringResource {
        r("management_module_maintenance_title", "House Problems")
    }

    /// Track repairs & maintenance tasks
    public static var managementModuleMaintenanceSubtitle: LocalizedStringResource {
        r("management_module_maintenance_subtitle", "Track repairs & maintenance tasks")
    }

    /// Bills & Finance
    public static var managementModuleFinanceTitle: LocalizedStringResource {
        r("management_module_finance_title", "Bills & Finance")
    }

    /// Split bills & manage expenses
    public static var managementModuleFinanceSubtitle: LocalizedStringResource {
        r("management_module_finance_subtitle", "Split bills & manage expenses")
    }

    /// Notes & Ideas
    public static var managementModuleNotesTitle: LocalizedStringResource {
        r("management_module_notes_title", "Notes & Ideas")
    }

    /// Capture ideas & important notes
    public static var managementModuleNotesSubtitle: LocalizedStringResource {
        r("management_module_notes_subtitle", "Capture ideas & important notes")
    }

    /// Calendar & Events
    public static var managementModuleCalendarTitle: LocalizedStringResource {
        r("management_module_calendar_title", "Calendar & Events")
    }

    /// Organize events & schedules
    public static var managementModuleCalendarSubtitle: LocalizedStringResource {
        r("management_module_calendar_subtitle", "Organize events & schedules")
    }

    /// Soon!
    public static var managementComingSoon: LocalizedStringResource {
        r("management_coming_soon", "Soon!")
    }

    /// Shopping Lists
    public static var shoppingScreenTitle: LocalizedStringResource {
        r("shopping_screen_title", "Shopping Lists")
    }

    /// Shopping Lists 🛒
    public static var shoppingHeaderTitle: LocalizedStringResource {
        r("shopping_header_title", "Shopping Lists 🛒")
    }

    /// Let's get everything you need! ✨
    public static var shoppingHeaderSubtitle: LocalizedStringResource {
        r("shopping_header_subtitle", "Let's get everything you need! ✨")
    }

    /// Back
    public static var shoppingBackButton: LocalizedStringResource {
        r("shopping_back_button", "Back")
    }

    /// Shopping Categories
    public static var shoppingCategoriesTitle: LocalizedStringResource {
        r("shopping_categories_title", "Shopping Categories")
    }

    /// All Items
    public static var shoppingAllItemsTitle: LocalizedStringResource {
        r("shopping_all_items_title", "All Items")
    }

    /// List
    public static var shoppingListViewMode: LocalizedStringResource {
        r("shopping_list_view_mode", "List")
    }

    /// Categories
    public static var shoppingCategoriesViewMode: LocalizedStringResource {
        r("shopping_categories_view_mode", "Categories")
    }

    /// Total
    public static var shoppingStatsTotal: LocalizedStringResource {
        r("shopping_stats_total", "Total")
    }

    /// Done
    public static var shoppingStatsDone: LocalizedStringResource {
        r("shopping_stats_done", "Done")
    }

    /// Left
    public static var shoppingStatsLeft: LocalizedStringResource {
        r("shopping_stats_left", "Left")
    }

    /// items
    public static var shoppingItemsCount: LocalizedStringResource {
        r("shopping_items_count", "items")
    }

    /// No items yet
    public static var shoppingEmptyStateTitle: LocalizedStringResource {
        r("shopping_empty_state_title", "No items yet")
    }

    /// Add your first shopping item!
    public static var shoppingEmptyStateSubtitle: LocalizedStringResource {
        r("shopping_empty_state_subtitle", "Add your first shopping item!")
    }

    /// Add Item
    public static var shoppingAddItemTitle: LocalizedStringResource {
        r("shopping_add_item_title", "Add Item")
    }

    /// Delete Item
    public static var shoppingDeleteItemTitle: LocalizedStringResource {
        r("shopping_delete_item_title", "Delete Item")
    }

    /// Are you sure you want to delete this item?
    public static var shoppingDeleteItemMessage: LocalizedStringResource {
        r("shopping_delete_item_message", "Are you sure you want to delete this item?")
    }

    /// Groceries
    public static var shoppingCategoryGroceries: LocalizedStringResource {
        r("shopping_category_groceries", "Groceries")
    }

    /// Household
    public static var shoppingCategoryHousehold: LocalizedStringResource {
        r("shopping_category_household", "Household")
    }

    /// Cleaning
    public static var shoppingCategoryCleaning: LocalizedStringResource {
        r("shopping_category_cleaning", "Cleaning")
    }

    /// Other
    public static var shoppingCategoryOther: LocalizedStringResource {
        r("shopping_category_other", "Other")
    }

    /// Item Details
    public static var shoppingAddItemDetails: LocalizedStringResource {
        r("shopping_add_item_details", "Item Details")
    }

    /// Item Name
    public static var shoppingAddItemName: LocalizedStringResource {
        r("shopping_add_item_name", "Item Name")
    }

    /// Description (Optional)
    public static var shoppingAddItemDescription: LocalizedStringResource {
        r("shopping_add_item_description", "Description (Optional)")
    }

    /// Quantity & Category
    public static var shoppingAddItemQuantityCategory: LocalizedStringResource {
        r("shopping_add_item_quantity_category", "Quantity & Category")
    }

    /// Quantity
    public static var shoppingAddItemQuantity: LocalizedStringResource {
        r("shopping_add_item_quantity", "Quantity")
    }

    /// Category
    public static var shoppingAddItemCategory: LocalizedStringResource {
        r("shopping_add_item_category", "Category")
    }

    /// Cancel
    public static var shoppingAddItemCancel: LocalizedStringResource {
        r("shopping_add_item_cancel", "Cancel")
    }

    /// Add
    public static var shoppingAddItemAdd: LocalizedStringResource {
        r("shopping_add_item_add", "Add")
    }

    /// Explore Recipes
    public static var recipesExploreButton: LocalizedStringResource {
        r("recipes_explore_button", "Explore Recipes")
    }

    /// Delete
    public static var recipesDeleteButton: LocalizedStringResource {
        r("recipes_delete_button", "Delete")
    }

    /// Recipes
    public static var recipesScreenTitle: LocalizedStringResource {
        r("recipes_screen_title", "Recipes")
    }

    /// Back
    public static var recipesBackButton: LocalizedStringResource {
        r("recipes_back_button", "Back")
    }

    /// Meal Planning 🍽️
    public static var recipesHeaderTitle: LocalizedStringResource {
        r("recipes_header_title", "Meal Planning 🍽️")
    }

    /// Save and organize your family's favorite meals
    public static var recipesHeaderSubtitle: LocalizedStringResource {
        r("recipes_header_subtitle", "Save and organize your family's favorite meals")
    }

    /// Search recipes, tags…
    public static var recipesSearchPlaceholder: LocalizedStringResource {
        r("recipes_search_placeholder", "Search recipes, tags…")
    }

    /// All
    public static var recipesTagAll: LocalizedStringResource {
        r("recipes_tag_all", "All")
    }

    /// No recipes yet
    public static var recipesEmptyStateTitle: LocalizedStringResource {
        r("recipes_empty_state_title", "No recipes yet")
    }

    /// Add your first recipe and start planning meals!
    public static var recipesEmptyStateSubtitle: LocalizedStringResource {
        r("recipes_empty_state_subtitle", "Add your first recipe and start planning meals!")
    }

    /// Add to My Recipes
    public static var recipesExploreAddToMyRecipes: LocalizedStringResource {
        r("recipes_explore_add_to_my_recipes", "Add to My Recipes")
    }

    /// Explore Recipes
    public static var recipesExploreScreenTitle: LocalizedStringResource {
        r("recipes_explore_screen_title", "Explore Recipes")
    }

    /// Close
    public static var recipesExploreCloseButton: LocalizedStringResource {
        r("recipes_explore_close_button", "Close")
    }

    /// Curated Picks ✨
    public static var recipesExploreHeaderTitle: LocalizedStringResource {
        r("recipes_explore_header_title", "Curated Picks ✨")
    }

    /// Discover global favorites and Turkish classics
    public static var recipesExploreHeaderSubtitle: LocalizedStringResource {
        r("recipes_explore_header_subtitle", "Discover global favorites and Turkish classics")
    }

    /// Filters
    public static var recipesExploreFiltersTitle: LocalizedStringResource {
        r("recipes_explore_filters_title", "Filters")
    }

    /// Clear All
    public static var recipesExploreFiltersClearAll: LocalizedStringResource {
        r("recipes_explore_filters_clear_all", "Clear All")
    }

    /// No recipes found
    public static var recipesExploreFiltersNoRecipesFound: LocalizedStringResource {
        r("recipes_explore_filters_no_recipes_found", "No recipes found")
    }

    /// Try adjusting your filters to see more recipes
    public static var recipesExploreFiltersAdjustMessage: LocalizedStringResource {
        r("recipes_explore_filters_adjust_message", "Try adjusting your filters to see more recipes")
    }

    /// Clear Filters
    public static var recipesExploreFiltersClearButton: LocalizedStringResource {
        r("recipes_explore_filters_clear_button", "Clear Filters")
    }

    /// Filter Recipes
    public static var recipesExploreFilterSheetTitle: LocalizedStringResource {
        r("recipes_explore_filter_sheet_title", "Filter Recipes")
    }

    /// Reset
    public static var recipesExploreFilterSheetReset: LocalizedStringResource {
        r("recipes_explore_filter_sheet_reset", "Reset")
    }

    /// Done
    public static var recipesExploreFilterSheetDone: LocalizedStringResource {
        r("recipes_explore_filter_sheet_done", "Done")
    }

    /// Difficulty Level
    public static var recipesExploreFilterDifficultyTitle: LocalizedStringResource {
        r("recipes_explore_filter_difficulty_title", "Difficulty Level")
    }

    /// Category
    public static var recipesExploreFilterCategoryTitle: LocalizedStringResource {
        r("recipes_explore_filter_category_title", "Category")
    }

    /// Total Time
    public static var recipesExploreFilterTimeTitle: LocalizedStringResource {
        r("recipes_explore_filter_time_title", "Total Time")
    }

    /// Any
    public static var recipesExploreFilterTimeAny: LocalizedStringResource {
        r("recipes_explore_filter_time_any", "Any")
    }

    /// Servings
    public static var recipesExploreFilterServingsTitle: LocalizedStringResource {
        r("recipes_explore_filter_servings_title", "Servings")
    }

    /// Any
    public static var recipesExploreFilterServingsAny: LocalizedStringResource {
        r("recipes_explore_filter_servings_any", "Any")
    }

    /// Max Time
    public static var recipesExploreFilterMaxTimeLabel: LocalizedStringResource {
        r("recipes_explore_filter_max_time_label", "Max Time")
    }

    /// 10m
    public static var recipesExploreFilterMaxTimeMinLabel: LocalizedStringResource {
        r("recipes_explore_filter_max_time_min_label", "10m")
    }

    /// 5h+
    public static var recipesExploreFilterMaxTimeMaxLabel: LocalizedStringResource {
        r("recipes_explore_filter_max_time_max_label", "5h+")
    }

    /// Max Servings
    public static var recipesExploreFilterMaxServingsLabel: LocalizedStringResource {
        r("recipes_explore_filter_max_servings_label", "Max Servings")
    }

    /// 1
    public static var recipesExploreFilterMaxServingsMinLabel: LocalizedStringResource {
        r("recipes_explore_filter_max_servings_min_label", "1")
    }

    /// 20+
    public static var recipesExploreFilterMaxServingsMaxLabel: LocalizedStringResource {
        r("recipes_explore_filter_max_servings_max_label", "20+")
    }

    /// Recipe Title
    public static var recipesNewRecipeTitleField: LocalizedStringResource {
        r("recipes_new_recipe_title_field", "Recipe Title")
    }

    /// e.g., Spaghetti Carbonara
    public static var recipesNewRecipeTitlePlaceholder: LocalizedStringResource {
        r("recipes_new_recipe_title_placeholder", "e.g., Spaghetti Carbonara")
    }

    /// Description
    public static var recipesNewRecipeDescriptionField: LocalizedStringResource {
        r("recipes_new_recipe_description_field", "Description")
    }

    /// Short description (optional)
    public static var recipesNewRecipeDescriptionPlaceholder: LocalizedStringResource {
        r("recipes_new_recipe_description_placeholder", "Short description (optional)")
    }

    /// New Recipe
    public static var recipesNewRecipeScreenTitle: LocalizedStringResource {
        r("recipes_new_recipe_screen_title", "New Recipe")
    }

    /// Add
    public static var recipesNewRecipeAddButton: LocalizedStringResource {
        r("recipes_new_recipe_add_button", "Add")
    }

    /// Create Delicious ✨
    public static var recipesNewRecipeHeaderTitle: LocalizedStringResource {
        r("recipes_new_recipe_header_title", "Create Delicious ✨")
    }

    /// Add a new recipe with tags, timing, ingredients, and steps.
    public static var recipesNewRecipeHeaderSubtitle: LocalizedStringResource {
        r("recipes_new_recipe_header_subtitle", "Add a new recipe with tags, timing, ingredients, and steps.")
    }

    /// Tags
    public static var recipesNewRecipeTagsSectionTitle: LocalizedStringResource {
        r("recipes_new_recipe_tags_section_title", "Tags")
    }

    /// You can select up to %d tags.
    public static func recipesNewRecipeTagsLimitInfo(_ a0: Int) -> LocalizedStringResource {
        r("recipes_new_recipe_tags_limit_info", "You can select up to \(a0) tags.")
    }

    /// Time & Servings
    public static var recipesNewRecipeTimeServingsSectionTitle: LocalizedStringResource {
        r("recipes_new_recipe_time_servings_section_title", "Time & Servings")
    }

    /// Prep (min)
    public static var recipesNewRecipePrepTimePlaceholder: LocalizedStringResource {
        r("recipes_new_recipe_prep_time_placeholder", "Prep (min)")
    }

    /// Cook (min)
    public static var recipesNewRecipeCookTimePlaceholder: LocalizedStringResource {
        r("recipes_new_recipe_cook_time_placeholder", "Cook (min)")
    }

    /// Servings
    public static var recipesNewRecipeServingsPlaceholder: LocalizedStringResource {
        r("recipes_new_recipe_servings_placeholder", "Servings")
    }

    /// Difficulty
    public static var recipesNewRecipeDifficultyPicker: LocalizedStringResource {
        r("recipes_new_recipe_difficulty_picker", "Difficulty")
    }

    /// Ingredients (one per line)
    public static var recipesNewRecipeIngredientsEditorTitle: LocalizedStringResource {
        r("recipes_new_recipe_ingredients_editor_title", "Ingredients (one per line)")
    }

    /// Steps (one per line)
    public static var recipesNewRecipeStepsEditorTitle: LocalizedStringResource {
        r("recipes_new_recipe_steps_editor_title", "Steps (one per line)")
    }

    /// Quit Cooking
    public static var recipesCookingQuitAlertTitle: LocalizedStringResource {
        r("recipes_cooking_quit_alert_title", "Quit Cooking")
    }

    /// Quit
    public static var recipesCookingQuitAlertQuitButton: LocalizedStringResource {
        r("recipes_cooking_quit_alert_quit_button", "Quit")
    }

    /// Are you sure you want to quit cooking? Your progress will be lost.
    public static var recipesCookingQuitAlertMessage: LocalizedStringResource {
        r("recipes_cooking_quit_alert_message", "Are you sure you want to quit cooking? Your progress will be lost.")
    }

    /// Prepare Ingredients
    public static var recipesCookingPrepareIngredients: LocalizedStringResource {
        r("recipes_cooking_prepare_ingredients", "Prepare Ingredients")
    }

    /// Cook Recipe
    public static var recipesCookingCookRecipe: LocalizedStringResource {
        r("recipes_cooking_cook_recipe", "Cook Recipe")
    }

    /// Progress
    public static var recipesCookingProgressLabel: LocalizedStringResource {
        r("recipes_cooking_progress_label", "Progress")
    }

    /// %d/%d ingredients
    public static func recipesCookingIngredientsProgress(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("recipes_cooking_ingredients_progress", "\(a0)/\(a1) ingredients")
    }

    /// Step %d/%d
    public static func recipesCookingStepsProgress(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("recipes_cooking_steps_progress", "Step \(a0)/\(a1)")
    }

    /// Check off each ingredient as you gather it
    public static var recipesCookingCheckIngredientsInstruction: LocalizedStringResource {
        r("recipes_cooking_check_ingredients_instruction", "Check off each ingredient as you gather it")
    }

    /// Start Cooking
    public static var recipesCookingStartCookingButton: LocalizedStringResource {
        r("recipes_cooking_start_cooking_button", "Start Cooking")
    }

    /// Mark all
    public static var recipesCookingMarkAll: LocalizedStringResource {
        r("recipes_cooking_mark_all", "Mark all")
    }

    /// Clear all
    public static var recipesCookingClearAll: LocalizedStringResource {
        r("recipes_cooking_clear_all", "Clear all")
    }

    /// Back
    public static var recipesCookingBackButton: LocalizedStringResource {
        r("recipes_cooking_back_button", "Back")
    }

    /// Finish
    public static var recipesCookingFinishButton: LocalizedStringResource {
        r("recipes_cooking_finish_button", "Finish")
    }

    /// Next Step
    public static var recipesCookingNextStepButton: LocalizedStringResource {
        r("recipes_cooking_next_step_button", "Next Step")
    }

    /// Step %d of %d
    public static func recipesCookingStepCardTitle(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("recipes_cooking_step_card_title", "Step \(a0) of \(a1)")
    }

    /// %dmin
    public static func recipesCardTimeFormat(_ a0: Int) -> LocalizedStringResource {
        r("recipes_card_time_format", "\(a0)min")
    }

    /// —
    public static var recipesCardTimeNotSpecified: LocalizedStringResource {
        r("recipes_card_time_not_specified", "—")
    }

    /// %d min total
    public static func recipesDetailTimeTotalFormat(_ a0: Int) -> LocalizedStringResource {
        r("recipes_detail_time_total_format", "\(a0) min total")
    }

    /// No time specified
    public static var recipesDetailTimeNotSpecified: LocalizedStringResource {
        r("recipes_detail_time_not_specified", "No time specified")
    }

    /// Start Preparing
    public static var recipesDetailStartPreparingButton: LocalizedStringResource {
        r("recipes_detail_start_preparing_button", "Start Preparing")
    }

    /// Delete Recipe
    public static var recipesDetailDeleteAlertTitle: LocalizedStringResource {
        r("recipes_detail_delete_alert_title", "Delete Recipe")
    }

    /// Are you sure you want to delete '%@'? This action cannot be undone.
    public static func recipesDetailDeleteAlertMessage(_ a0: String) -> LocalizedStringResource {
        r("recipes_detail_delete_alert_message", "Are you sure you want to delete '\(a0)'? This action cannot be undone.")
    }

    /// Prep
    public static var recipesDetailInfoCardPrep: LocalizedStringResource {
        r("recipes_detail_info_card_prep", "Prep")
    }

    /// Cook
    public static var recipesDetailInfoCardCook: LocalizedStringResource {
        r("recipes_detail_info_card_cook", "Cook")
    }

    /// Serves
    public static var recipesDetailInfoCardServes: LocalizedStringResource {
        r("recipes_detail_info_card_serves", "Serves")
    }

    /// Level
    public static var recipesDetailInfoCardLevel: LocalizedStringResource {
        r("recipes_detail_info_card_level", "Level")
    }

    /// Ingredients
    public static var recipesDetailIngredientsSectionTitle: LocalizedStringResource {
        r("recipes_detail_ingredients_section_title", "Ingredients")
    }

    /// Instructions
    public static var recipesDetailInstructionsSectionTitle: LocalizedStringResource {
        r("recipes_detail_instructions_section_title", "Instructions")
    }

    /// Easy
    public static var recipesDifficultyEasy: LocalizedStringResource {
        r("recipes_difficulty_easy", "Easy")
    }

    /// Medium
    public static var recipesDifficultyMedium: LocalizedStringResource {
        r("recipes_difficulty_medium", "Medium")
    }

    /// Hard
    public static var recipesDifficultyHard: LocalizedStringResource {
        r("recipes_difficulty_hard", "Hard")
    }

    /// Messages
    public static var messagesScreenTitle: LocalizedStringResource {
        r("messages_screen_title", "Messages")
    }

    /// New Message
    public static var messagesNewMessageButton: LocalizedStringResource {
        r("messages_new_message_button", "New Message")
    }

    /// No Messages Yet
    public static var messagesEmptyStateTitle: LocalizedStringResource {
        r("messages_empty_state_title", "No Messages Yet")
    }

    /// Create a group chat to stay connected with your household
    public static var messagesEmptyStateSubtitle: LocalizedStringResource {
        r("messages_empty_state_subtitle", "Create a group chat to stay connected with your household")
    }

    /// Create Group Chat
    public static var messagesCreateGroupChatButton: LocalizedStringResource {
        r("messages_create_group_chat_button", "Create Group Chat")
    }

    /// No messages yet
    public static var messagesNoMessagesYet: LocalizedStringResource {
        r("messages_no_messages_yet", "No messages yet")
    }

    /// GC
    public static var messagesConversationCardGroupChatInitials: LocalizedStringResource {
        r("messages_conversation_card_group_chat_initials", "GC")
    }

    /// HM
    public static var messagesConversationCardHouseholdMemberInitials: LocalizedStringResource {
        r("messages_conversation_card_household_member_initials", "HM")
    }

    /// Direct Message
    public static var messagesConversationCardDirectMessage: LocalizedStringResource {
        r("messages_conversation_card_direct_message", "Direct Message")
    }

    /// Household Chat
    public static var messagesConversationCardHouseholdChat: LocalizedStringResource {
        r("messages_conversation_card_household_chat", "Household Chat")
    }

    /// Loading conversations...
    public static var messagesLoadingConversations: LocalizedStringResource {
        r("messages_loading_conversations", "Loading conversations...")
    }

    /// New Group Chat
    public static var messagesNewGroupTitle: LocalizedStringResource {
        r("messages_new_group_title", "New Group Chat")
    }

    /// Cancel
    public static var messagesNewGroupCancel: LocalizedStringResource {
        r("messages_new_group_cancel", "Cancel")
    }

    /// Create
    public static var messagesNewGroupCreate: LocalizedStringResource {
        r("messages_new_group_create", "Create")
    }

    /// Household Group Chat
    public static var messagesNewGroupHeaderTitle: LocalizedStringResource {
        r("messages_new_group_header_title", "Household Group Chat")
    }

    /// This chat will include all %d members of %@
    public static func messagesNewGroupDescription(_ a0: Int, _ a1: String) -> LocalizedStringResource {
        r("messages_new_group_description", "This chat will include all \(a0) members of \(a1)")
    }

    /// This chat will include all household members
    public static var messagesNewGroupDescriptionGeneric: LocalizedStringResource {
        r("messages_new_group_description_generic", "This chat will include all household members")
    }

    /// GROUP NAME (OPTIONAL)
    public static var messagesNewGroupNameLabel: LocalizedStringResource {
        r("messages_new_group_name_label", "GROUP NAME (OPTIONAL)")
    }

    /// e.g., Family Chat, House Updates...
    public static var messagesNewGroupNamePlaceholder: LocalizedStringResource {
        r("messages_new_group_name_placeholder", "e.g., Family Chat, House Updates...")
    }

    /// FIRST MESSAGE
    public static var messagesNewGroupFirstMessageLabel: LocalizedStringResource {
        r("messages_new_group_first_message_label", "FIRST MESSAGE")
    }

    /// Say hello to your household...
    public static var messagesNewGroupFirstMessagePlaceholder: LocalizedStringResource {
        r("messages_new_group_first_message_placeholder", "Say hello to your household...")
    }

    /// %d household members will be added to this chat
    public static func messagesNewGroupMembersInfo(_ a0: Int) -> LocalizedStringResource {
        r("messages_new_group_members_info", "\(a0) household members will be added to this chat")
    }

    /// Creating group chat...
    public static var messagesNewGroupCreating: LocalizedStringResource {
        r("messages_new_group_creating", "Creating group chat...")
    }

    /// Missing required information
    public static var messagesNewGroupErrorMissingInfo: LocalizedStringResource {
        r("messages_new_group_error_missing_info", "Missing required information")
    }

    /// Failed to create group chat: %@
    public static func messagesNewGroupErrorCreationFailed(_ a0: String) -> LocalizedStringResource {
        r("messages_new_group_error_creation_failed", "Failed to create group chat: \(a0)")
    }

    /// Back
    public static var messagesChatHeaderBack: LocalizedStringResource {
        r("messages_chat_header_back", "Back")
    }

    /// Loading messages...
    public static var messagesChatLoading: LocalizedStringResource {
        r("messages_chat_loading", "Loading messages...")
    }

    /// Start the conversation
    public static var messagesChatEmptyTitle: LocalizedStringResource {
        r("messages_chat_empty_title", "Start the conversation")
    }

    /// Send your first message to get things started
    public static var messagesChatEmptySubtitle: LocalizedStringResource {
        r("messages_chat_empty_subtitle", "Send your first message to get things started")
    }

    /// Type a message...
    public static var messagesChatInputPlaceholder: LocalizedStringResource {
        r("messages_chat_input_placeholder", "Type a message...")
    }

    /// Send
    public static var messagesChatSendButton: LocalizedStringResource {
        r("messages_chat_send_button", "Send")
    }

    /// Failed to send
    public static var messagesChatMessageFailed: LocalizedStringResource {
        r("messages_chat_message_failed", "Failed to send")
    }

    /// Sending...
    public static var messagesChatMessageSending: LocalizedStringResource {
        r("messages_chat_message_sending", "Sending...")
    }

    /// Error
    public static var messagesChatErrorTitle: LocalizedStringResource {
        r("messages_chat_error_title", "Error")
    }

    /// OK
    public static var messagesChatErrorOk: LocalizedStringResource {
        r("messages_chat_error_ok", "OK")
    }

    /// %d members
    public static func messagesChatMembersCount(_ a0: Int) -> LocalizedStringResource {
        r("messages_chat_members_count", "\(a0) members")
    }

    /// What to watch tonight
    public static var whatToWatchTitle: LocalizedStringResource {
        r("what_to_watch_title", "What to watch tonight")
    }

    /// Swipe right for Yes, left for No
    public static var whatToWatchInPollInstructions: LocalizedStringResource {
        r("what_to_watch_in_poll_instructions", "Swipe right for Yes, left for No")
    }

    /// Create polls and discover movies together
    public static var whatToWatchNoInPollInstructions: LocalizedStringResource {
        r("what_to_watch_no_in_poll_instructions", "Create polls and discover movies together")
    }

    /// Loading Movies
    public static var whatToWatchLoadingMovies: LocalizedStringResource {
        r("what_to_watch_loading_movies", "Loading Movies")
    }

    /// Fetching movie details for your poll...
    public static var whatToWatchLoadingMoviesDetails: LocalizedStringResource {
        r("what_to_watch_loading_movies_details", "Fetching movie details for your poll...")
    }

    /// Creating your movie poll...
    public static var whatToWatchCreatingPoll: LocalizedStringResource {
        r("what_to_watch_creating_poll", "Creating your movie poll...")
    }

    /// This may take a moment while we prepare your personalized movie selection
    public static var whatToWatchCreatingPollDetails: LocalizedStringResource {
        r("what_to_watch_creating_poll_details", "This may take a moment while we prepare your personalized movie selection")
    }

    /// 🎉 We have a winner! 🎉
    public static var whatToWatchWinnerAnnouncement: LocalizedStringResource {
        r("what_to_watch_winner_announcement", "🎉 We have a winner! 🎉")
    }

    /// This movie got the most votes from your house!
    public static var whatToWatchWinnerHouseVotes: LocalizedStringResource {
        r("what_to_watch_winner_house_votes", "This movie got the most votes from your house!")
    }

    /// End Poll
    public static var whatToWatchEndPoll: LocalizedStringResource {
        r("what_to_watch_end_poll", "End Poll")
    }

    /// Start Movie Poll
    public static var whatToWatchStartPoll: LocalizedStringResource {
        r("what_to_watch_start_poll", "Start Movie Poll")
    }

    /// Previous Polls
    public static var whatToWatchPreviousPolls: LocalizedStringResource {
        r("what_to_watch_previous_polls", "Previous Polls")
    }

    /// Poll Complete!
    public static var whatToWatchPollComplete: LocalizedStringResource {
        r("what_to_watch_poll_complete", "Poll Complete!")
    }

    /// All movies have been reviewed
    public static var whatToWatchPollCompleteSubtitle: LocalizedStringResource {
        r("what_to_watch_poll_complete_subtitle", "All movies have been reviewed")
    }

    /// Voting Progress
    public static var whatToWatchVotingProgress: LocalizedStringResource {
        r("what_to_watch_voting_progress", "Voting Progress")
    }

    /// Waiting for voting statistics...
    public static var whatToWatchWaitingStats: LocalizedStringResource {
        r("what_to_watch_waiting_stats", "Waiting for voting statistics...")
    }

    /// %d/%d
    public static func whatToWatchVotingProgressCount(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("what_to_watch_voting_progress_count", "\(a0)/\(a1)")
    }

    /// Genre
    public static var pollTypeGenre: LocalizedStringResource {
        r("poll_type_genre", "Genre")
    }

    /// Choose movies by genre
    public static var pollTypeGenreDescription: LocalizedStringResource {
        r("poll_type_genre_description", "Choose movies by genre")
    }

    /// Actor
    public static var pollTypeActor: LocalizedStringResource {
        r("poll_type_actor", "Actor")
    }

    /// Pick movies with specific actors
    public static var pollTypeActorDescription: LocalizedStringResource {
        r("poll_type_actor_description", "Pick movies with specific actors")
    }

    /// Director
    public static var pollTypeDirector: LocalizedStringResource {
        r("poll_type_director", "Director")
    }

    /// Select movies by director
    public static var pollTypeDirectorDescription: LocalizedStringResource {
        r("poll_type_director_description", "Select movies by director")
    }

    /// Year
    public static var pollTypeYear: LocalizedStringResource {
        r("poll_type_year", "Year")
    }

    /// Movies from a specific year
    public static var pollTypeYearDescription: LocalizedStringResource {
        r("poll_type_year_description", "Movies from a specific year")
    }

    /// Decade
    public static var pollTypeDecade: LocalizedStringResource {
        r("poll_type_decade", "Decade")
    }

    /// Movies from a decade
    public static var pollTypeDecadeDescription: LocalizedStringResource {
        r("poll_type_decade_description", "Movies from a decade")
    }

    /// Now Playing
    public static var pollTypeNowPlaying: LocalizedStringResource {
        r("poll_type_now_playing", "Now Playing")
    }

    /// Movies currently in theaters
    public static var pollTypeNowPlayingDescription: LocalizedStringResource {
        r("poll_type_now_playing_description", "Movies currently in theaters")
    }

    /// Popular
    public static var pollTypePopular: LocalizedStringResource {
        r("poll_type_popular", "Popular")
    }

    /// Most popular movies right now
    public static var pollTypePopularDescription: LocalizedStringResource {
        r("poll_type_popular_description", "Most popular movies right now")
    }

    /// Top Rated
    public static var pollTypeTopRated: LocalizedStringResource {
        r("poll_type_top_rated", "Top Rated")
    }

    /// Highest rated movies of all time
    public static var pollTypeTopRatedDescription: LocalizedStringResource {
        r("poll_type_top_rated_description", "Highest rated movies of all time")
    }

    /// Upcoming
    public static var pollTypeUpcoming: LocalizedStringResource {
        r("poll_type_upcoming", "Upcoming")
    }

    /// Movies coming soon
    public static var pollTypeUpcomingDescription: LocalizedStringResource {
        r("poll_type_upcoming_description", "Movies coming soon")
    }

    /// Create Movie Poll
    public static var pollTypeSelectionTitle: LocalizedStringResource {
        r("poll_type_selection_title", "Create Movie Poll")
    }

    /// Choose how you'd like to discover movies together
    public static var pollTypeSelectionSubtitle: LocalizedStringResource {
        r("poll_type_selection_subtitle", "Choose how you'd like to discover movies together")
    }

    /// Choose Your Movie Genres
    public static var genreSelectionTitle: LocalizedStringResource {
        r("genre_selection_title", "Choose Your Movie Genres")
    }

    /// Select one or more genres for your movie poll
    public static var genreSelectionSubtitle: LocalizedStringResource {
        r("genre_selection_subtitle", "Select one or more genres for your movie poll")
    }

    /// Selected:
    public static var genreSelectionSelected: LocalizedStringResource {
        r("genre_selection_selected", "Selected:")
    }

    /// Clear All
    public static var genreSelectionClearAll: LocalizedStringResource {
        r("genre_selection_clear_all", "Clear All")
    }

    /// Create Movie Poll
    public static var genreSelectionCreatePoll: LocalizedStringResource {
        r("genre_selection_create_poll", "Create Movie Poll")
    }

    /// Select at least one genre to continue
    public static var genreSelectionSelectOneMessage: LocalizedStringResource {
        r("genre_selection_select_one_message", "Select at least one genre to continue")
    }

    /// Include Adult Content
    public static var genreSelectionIncludeAdult: LocalizedStringResource {
        r("genre_selection_include_adult", "Include Adult Content")
    }

    /// Include movies with mature themes and content
    public static var genreSelectionIncludeAdultDescription: LocalizedStringResource {
        r("genre_selection_include_adult_description", "Include movies with mature themes and content")
    }

    /// Action
    public static var genreAction: LocalizedStringResource {
        r("genre_action", "Action")
    }

    /// Explosions, fights, and thrills
    public static var genreActionDescription: LocalizedStringResource {
        r("genre_action_description", "Explosions, fights, and thrills")
    }

    /// Adventure
    public static var genreAdventure: LocalizedStringResource {
        r("genre_adventure", "Adventure")
    }

    /// Epic journeys and quests
    public static var genreAdventureDescription: LocalizedStringResource {
        r("genre_adventure_description", "Epic journeys and quests")
    }

    /// Comedy
    public static var genreComedy: LocalizedStringResource {
        r("genre_comedy", "Comedy")
    }

    /// Laughs and good times
    public static var genreComedyDescription: LocalizedStringResource {
        r("genre_comedy_description", "Laughs and good times")
    }

    /// Drama
    public static var genreDrama: LocalizedStringResource {
        r("genre_drama", "Drama")
    }

    /// Emotional and compelling stories
    public static var genreDramaDescription: LocalizedStringResource {
        r("genre_drama_description", "Emotional and compelling stories")
    }

    /// Fantasy
    public static var genreFantasy: LocalizedStringResource {
        r("genre_fantasy", "Fantasy")
    }

    /// Magic and mythical worlds
    public static var genreFantasyDescription: LocalizedStringResource {
        r("genre_fantasy_description", "Magic and mythical worlds")
    }

    /// Horror
    public static var genreHorror: LocalizedStringResource {
        r("genre_horror", "Horror")
    }

    /// Scary and spine-chilling
    public static var genreHorrorDescription: LocalizedStringResource {
        r("genre_horror_description", "Scary and spine-chilling")
    }

    /// Romance
    public static var genreRomance: LocalizedStringResource {
        r("genre_romance", "Romance")
    }

    /// Love stories and relationships
    public static var genreRomanceDescription: LocalizedStringResource {
        r("genre_romance_description", "Love stories and relationships")
    }

    /// Sci-Fi
    public static var genreSciFi: LocalizedStringResource {
        r("genre_sci_fi", "Sci-Fi")
    }

    /// Future tech and space adventures
    public static var genreSciFiDescription: LocalizedStringResource {
        r("genre_sci_fi_description", "Future tech and space adventures")
    }

    /// Thriller
    public static var genreThriller: LocalizedStringResource {
        r("genre_thriller", "Thriller")
    }

    /// Suspense and edge-of-your-seat
    public static var genreThrillerDescription: LocalizedStringResource {
        r("genre_thriller_description", "Suspense and edge-of-your-seat")
    }

    /// Animation
    public static var genreAnimation: LocalizedStringResource {
        r("genre_animation", "Animation")
    }

    /// Animated movies and cartoons
    public static var genreAnimationDescription: LocalizedStringResource {
        r("genre_animation_description", "Animated movies and cartoons")
    }

    /// Search by Actor
    public static var actorInputTitle: LocalizedStringResource {
        r("actor_input_title", "Search by Actor")
    }

    /// Enter the name of your favorite actor
    public static var actorInputSubtitle: LocalizedStringResource {
        r("actor_input_subtitle", "Enter the name of your favorite actor")
    }

    /// Actor name (e.g., Tom Hanks)
    public static var actorInputPlaceholder: LocalizedStringResource {
        r("actor_input_placeholder", "Actor name (e.g., Tom Hanks)")
    }

    /// Create Actor Poll
    public static var actorInputCreatePoll: LocalizedStringResource {
        r("actor_input_create_poll", "Create Actor Poll")
    }

    /// Creating Poll...
    public static var actorInputCreatingPoll: LocalizedStringResource {
        r("actor_input_creating_poll", "Creating Poll...")
    }

    /// Search by Director
    public static var directorInputTitle: LocalizedStringResource {
        r("director_input_title", "Search by Director")
    }

    /// Enter the name of a film director
    public static var directorInputSubtitle: LocalizedStringResource {
        r("director_input_subtitle", "Enter the name of a film director")
    }

    /// Director name (e.g., Christopher Nolan)
    public static var directorInputPlaceholder: LocalizedStringResource {
        r("director_input_placeholder", "Director name (e.g., Christopher Nolan)")
    }

    /// Create Director Poll
    public static var directorInputCreatePoll: LocalizedStringResource {
        r("director_input_create_poll", "Create Director Poll")
    }

    /// Creating Poll...
    public static var directorInputCreatingPoll: LocalizedStringResource {
        r("director_input_creating_poll", "Creating Poll...")
    }

    /// Search by Year
    public static var yearInputTitle: LocalizedStringResource {
        r("year_input_title", "Search by Year")
    }

    /// Choose movies from a specific year
    public static var yearInputSubtitle: LocalizedStringResource {
        r("year_input_subtitle", "Choose movies from a specific year")
    }

    /// Selected Year
    public static var yearInputSelectedYear: LocalizedStringResource {
        r("year_input_selected_year", "Selected Year")
    }

    /// Create %d Poll
    public static func yearInputCreatePoll(_ a0: Int) -> LocalizedStringResource {
        r("year_input_create_poll", "Create \(a0) Poll")
    }

    /// Creating Poll...
    public static var yearInputCreatingPoll: LocalizedStringResource {
        r("year_input_creating_poll", "Creating Poll...")
    }

    /// Search by Decade
    public static var decadeInputTitle: LocalizedStringResource {
        r("decade_input_title", "Search by Decade")
    }

    /// Choose movies from a specific decade
    public static var decadeInputSubtitle: LocalizedStringResource {
        r("decade_input_subtitle", "Choose movies from a specific decade")
    }

    /// Selected Decade
    public static var decadeInputSelectedDecade: LocalizedStringResource {
        r("decade_input_selected_decade", "Selected Decade")
    }

    /// Create %ds Poll
    public static func decadeInputCreatePoll(_ a0: Int) -> LocalizedStringResource {
        r("decade_input_create_poll", "Create \(a0)s Poll")
    }

    /// Creating Poll...
    public static var decadeInputCreatingPoll: LocalizedStringResource {
        r("decade_input_creating_poll", "Creating Poll...")
    }

    /// LIKE
    public static var swipeCardLike: LocalizedStringResource {
        r("swipe_card_like", "LIKE")
    }

    /// NOPE
    public static var swipeCardNope: LocalizedStringResource {
        r("swipe_card_nope", "NOPE")
    }

    /// Tap for details
    public static var swipeCardTapForDetails: LocalizedStringResource {
        r("swipe_card_tap_for_details", "Tap for details")
    }

    /// Movie Details
    public static var movieDetailsTitle: LocalizedStringResource {
        r("movie_details_title", "Movie Details")
    }

    /// Genres
    public static var movieDetailsGenres: LocalizedStringResource {
        r("movie_details_genres", "Genres")
    }

    /// Overview
    public static var movieDetailsOverview: LocalizedStringResource {
        r("movie_details_overview", "Overview")
    }

    /// Statistics
    public static var movieDetailsStatistics: LocalizedStringResource {
        r("movie_details_statistics", "Statistics")
    }

    /// Rating
    public static var movieDetailsRating: LocalizedStringResource {
        r("movie_details_rating", "Rating")
    }

    /// Votes
    public static var movieDetailsVotes: LocalizedStringResource {
        r("movie_details_votes", "Votes")
    }

    /// Budget
    public static var movieDetailsBudget: LocalizedStringResource {
        r("movie_details_budget", "Budget")
    }

    /// Revenue
    public static var movieDetailsRevenue: LocalizedStringResource {
        r("movie_details_revenue", "Revenue")
    }

    /// Cast
    public static var movieDetailsCast: LocalizedStringResource {
        r("movie_details_cast", "Cast")
    }

    /// Crew
    public static var movieDetailsCrew: LocalizedStringResource {
        r("movie_details_crew", "Crew")
    }

    /// Director(s)
    public static var movieDetailsDirectors: LocalizedStringResource {
        r("movie_details_directors", "Director(s)")
    }

    /// Writer(s)
    public static var movieDetailsWriters: LocalizedStringResource {
        r("movie_details_writers", "Writer(s)")
    }

    /// Production
    public static var movieDetailsProduction: LocalizedStringResource {
        r("movie_details_production", "Production")
    }

    /// Keywords
    public static var movieDetailsKeywords: LocalizedStringResource {
        r("movie_details_keywords", "Keywords")
    }

    /// Loading details...
    public static var movieDetailsLoadingDetails: LocalizedStringResource {
        r("movie_details_loading_details", "Loading details...")
    }

    /// %d min
    public static func movieDetailsMinutes(_ a0: Int) -> LocalizedStringResource {
        r("movie_details_minutes", "\(a0) min")
    }

    /// Poll Matches
    public static var matchOptionsTitle: LocalizedStringResource {
        r("match_options_title", "Poll Matches")
    }

    /// 🎉 Matches Found! 🎉
    public static var matchOptionsMatchesFound: LocalizedStringResource {
        r("match_options_matches_found", "🎉 Matches Found! 🎉")
    }

    /// These movies got positive votes from your house members
    public static var matchOptionsMatchesDescription: LocalizedStringResource {
        r("match_options_matches_description", "These movies got positive votes from your house members")
    }

    /// Continue Poll
    public static var matchOptionsContinuePoll: LocalizedStringResource {
        r("match_options_continue_poll", "Continue Poll")
    }

    /// Choose "%@" as Winner
    public static func matchOptionsChooseWinner(_ a0: String) -> LocalizedStringResource {
        r("match_options_choose_winner", "Choose \"\(a0)\" as Winner")
    }

    /// End Poll & See All Results
    public static var matchOptionsEndPollSeeResults: LocalizedStringResource {
        r("match_options_end_poll_see_results", "End Poll & See All Results")
    }

    /// Poll Results
    public static var pollSummaryTitle: LocalizedStringResource {
        r("poll_summary_title", "Poll Results")
    }

    /// 🏆 Poll Complete! 🏆
    public static var pollSummaryComplete: LocalizedStringResource {
        r("poll_summary_complete", "🏆 Poll Complete! 🏆")
    }

    /// Here's how your house voted
    public static var pollSummaryDescription: LocalizedStringResource {
        r("poll_summary_description", "Here's how your house voted")
    }

    /// Total Votes
    public static var pollSummaryTotalVotes: LocalizedStringResource {
        r("poll_summary_total_votes", "Total Votes")
    }

    /// Participants
    public static var pollSummaryParticipants: LocalizedStringResource {
        r("poll_summary_participants", "Participants")
    }

    /// Matches
    public static var pollSummaryMatches: LocalizedStringResource {
        r("poll_summary_matches", "Matches")
    }

    /// 🥇 Winner
    public static var pollSummaryWinner: LocalizedStringResource {
        r("poll_summary_winner", "🥇 Winner")
    }

    /// All Matches
    public static var pollSummaryAllMatches: LocalizedStringResource {
        r("poll_summary_all_matches", "All Matches")
    }

    /// Previous Polls
    public static var previousPollsTitle: LocalizedStringResource {
        r("previous_polls_title", "Previous Polls")
    }

    /// Loading previous polls...
    public static var previousPollsLoading: LocalizedStringResource {
        r("previous_polls_loading", "Loading previous polls...")
    }

    /// No Previous Polls
    public static var previousPollsEmpty: LocalizedStringResource {
        r("previous_polls_empty", "No Previous Polls")
    }

    /// Your completed movie polls will appear here
    public static var previousPollsEmptyDescription: LocalizedStringResource {
        r("previous_polls_empty_description", "Your completed movie polls will appear here")
    }

    /// Delete Poll
    public static var previousPollsDeleteAlert: LocalizedStringResource {
        r("previous_polls_delete_alert", "Delete Poll")
    }

    /// Are you sure you want to delete this poll? This action cannot be undone.
    public static var previousPollsDeleteMessage: LocalizedStringResource {
        r("previous_polls_delete_message", "Are you sure you want to delete this poll? This action cannot be undone.")
    }

    /// Delete Error
    public static var previousPollsDeleteError: LocalizedStringResource {
        r("previous_polls_delete_error", "Delete Error")
    }

    /// Movie Poll
    public static var previousPollsMoviePoll: LocalizedStringResource {
        r("previous_polls_movie_poll", "Movie Poll")
    }

    /// Winner:
    public static var previousPollsWinner: LocalizedStringResource {
        r("previous_polls_winner", "Winner:")
    }

    /// No winner determined
    public static var previousPollsNoWinner: LocalizedStringResource {
        r("previous_polls_no_winner", "No winner determined")
    }

    /// Exit Poll
    public static var pollControlsExitPoll: LocalizedStringResource {
        r("poll_controls_exit_poll", "Exit Poll")
    }

    /// Get New Movies
    public static var pollControlsGetNewMovies: LocalizedStringResource {
        r("poll_controls_get_new_movies", "Get New Movies")
    }

    /// Popular Choices
    public static var matchesSectionPopularChoices: LocalizedStringResource {
        r("matches_section_popular_choices", "Popular Choices")
    }

    /// Movies getting positive votes from house members
    public static var matchesSectionDescription: LocalizedStringResource {
        r("matches_section_description", "Movies getting positive votes from house members")
    }

    /// Genre Poll: %@
    public static func pollTitleGenre(_ a0: String) -> LocalizedStringResource {
        r("poll_title_genre", "Genre Poll: \(a0)")
    }

    /// Actor Poll: %@
    public static func pollTitleActor(_ a0: String) -> LocalizedStringResource {
        r("poll_title_actor", "Actor Poll: \(a0)")
    }

    /// Director Poll: %@
    public static func pollTitleDirector(_ a0: String) -> LocalizedStringResource {
        r("poll_title_director", "Director Poll: \(a0)")
    }

    /// Year Poll: %d
    public static func pollTitleYear(_ a0: Int) -> LocalizedStringResource {
        r("poll_title_year", "Year Poll: \(a0)")
    }

    /// Decade Poll: %ds
    public static func pollTitleDecade(_ a0: Int) -> LocalizedStringResource {
        r("poll_title_decade", "Decade Poll: \(a0)s")
    }

    /// Mixed Movie Poll
    public static var pollTitleMixed: LocalizedStringResource {
        r("poll_title_mixed", "Mixed Movie Poll")
    }

    /// Now Playing Movies
    public static var pollTitleNowPlaying: LocalizedStringResource {
        r("poll_title_now_playing", "Now Playing Movies")
    }

    /// Popular Movies
    public static var pollTitlePopular: LocalizedStringResource {
        r("poll_title_popular", "Popular Movies")
    }

    /// Top Rated Movies
    public static var pollTitleTopRated: LocalizedStringResource {
        r("poll_title_top_rated", "Top Rated Movies")
    }

    /// Upcoming Movies
    public static var pollTitleUpcoming: LocalizedStringResource {
        r("poll_title_upcoming", "Upcoming Movies")
    }

    /// Add to Lists
    public static var movieDetailsAddToLists: LocalizedStringResource {
        r("movie_details_add_to_lists", "Add to Lists")
    }

    /// Added to %d
    public static func movieDetailsAddedToList(_ a0: Int) -> LocalizedStringResource {
        r("movie_details_added_to_list", "Added to \(a0)")
    }

    /// List
    public static var movieListsDefaultListName: LocalizedStringResource {
        r("movie_lists_default_list_name", "List")
    }

    /// Year
    public static var yearInputPickerTitle: LocalizedStringResource {
        r("year_input_picker_title", "Year")
    }

    /// Added %d pending items
    public static func managementModuleShoppingSubtitleDynamic(_ a0: Int) -> LocalizedStringResource {
        r("management_module_shopping_subtitle_dynamic", "Added \(a0) pending items")
    }

    /// No items yet
    public static var managementModuleShoppingSubtitleEmpty: LocalizedStringResource {
        r("management_module_shopping_subtitle_empty", "No items yet")
    }

    /// Failed to update item: %@
    public static func managementErrorUpdateItem(_ a0: String) -> LocalizedStringResource {
        r("management_error_update_item", "Failed to update item: \(a0)")
    }

    /// Failed to add item: %@
    public static func managementErrorAddItem(_ a0: String) -> LocalizedStringResource {
        r("management_error_add_item", "Failed to add item: \(a0)")
    }

    /// Failed to delete item: %@
    public static func managementErrorDeleteItem(_ a0: String) -> LocalizedStringResource {
        r("management_error_delete_item", "Failed to delete item: \(a0)")
    }

    /// Movie Collections
    public static var movieListsTitle: LocalizedStringResource {
        r("movie_lists_title", "Movie Collections")
    }

    /// Organize your movie watchlists and collections
    public static var movieListsSubtitle: LocalizedStringResource {
        r("movie_lists_subtitle", "Organize your movie watchlists and collections")
    }

    /// Quick Collections
    public static var movieListsQuickCollections: LocalizedStringResource {
        r("movie_lists_quick_collections", "Quick Collections")
    }

    /// Wishlist
    public static var movieListsWishlistTitle: LocalizedStringResource {
        r("movie_lists_wishlist_title", "Wishlist")
    }

    /// Movies you want to watch
    public static var movieListsWishlistSubtitle: LocalizedStringResource {
        r("movie_lists_wishlist_subtitle", "Movies you want to watch")
    }

    /// Watched
    public static var movieListsWatchedTitle: LocalizedStringResource {
        r("movie_lists_watched_title", "Watched")
    }

    /// Movies you've seen
    public static var movieListsWatchedSubtitle: LocalizedStringResource {
        r("movie_lists_watched_subtitle", "Movies you've seen")
    }

    /// Custom Lists
    public static var movieListsCustomLists: LocalizedStringResource {
        r("movie_lists_custom_lists", "Custom Lists")
    }

    /// No Custom Lists Yet
    public static var movieListsNoCustomLists: LocalizedStringResource {
        r("movie_lists_no_custom_lists", "No Custom Lists Yet")
    }

    /// Create themed collections like "Horror Movies" or "Rom-Com Classics"
    public static var movieListsNoCustomListsSubtitle: LocalizedStringResource {
        r("movie_lists_no_custom_lists_subtitle", "Create themed collections like \"Horror Movies\" or \"Rom-Com Classics\"")
    }

    /// Create Your First List
    public static var movieListsCreateFirstList: LocalizedStringResource {
        r("movie_lists_create_first_list", "Create Your First List")
    }

    /// Create Movie List
    public static var createMovieListTitle: LocalizedStringResource {
        r("create_movie_list_title", "Create Movie List")
    }

    /// Organize movies by theme, genre, or any criteria you want
    public static var createMovieListSubtitle: LocalizedStringResource {
        r("create_movie_list_subtitle", "Organize movies by theme, genre, or any criteria you want")
    }

    /// List Name
    public static var createMovieListNameLabel: LocalizedStringResource {
        r("create_movie_list_name_label", "List Name")
    }

    /// e.g., Horror Classics, Rom-Com Favorites
    public static var createMovieListNamePlaceholder: LocalizedStringResource {
        r("create_movie_list_name_placeholder", "e.g., Horror Classics, Rom-Com Favorites")
    }

    /// Description (Optional)
    public static var createMovieListDescriptionLabel: LocalizedStringResource {
        r("create_movie_list_description_label", "Description (Optional)")
    }

    /// Describe what this list is for...
    public static var createMovieListDescriptionPlaceholder: LocalizedStringResource {
        r("create_movie_list_description_placeholder", "Describe what this list is for...")
    }

    /// movies
    public static var movieListsMoviesCount: LocalizedStringResource {
        r("movie_lists_movies_count", "movies")
    }

    /// Loading movies...
    public static var movieListDetailLoadingMovies: LocalizedStringResource {
        r("movie_list_detail_loading_movies", "Loading movies...")
    }

    /// Delete List
    public static var movieListDetailDeleteList: LocalizedStringResource {
        r("movie_list_detail_delete_list", "Delete List")
    }

    /// This will permanently delete "%@" and cannot be undone.
    public static func movieListDetailDeleteListMessage(_ a0: String) -> LocalizedStringResource {
        r("movie_list_detail_delete_list_message", "This will permanently delete \"\(a0)\" and cannot be undone.")
    }

    /// No Movies Yet
    public static var movieListDetailNoMovies: LocalizedStringResource {
        r("movie_list_detail_no_movies", "No Movies Yet")
    }

    /// Start building your %@ by adding some movies
    public static func movieListDetailNoMoviesSubtitle(_ a0: String) -> LocalizedStringResource {
        r("movie_list_detail_no_movies_subtitle", "Start building your \(a0) by adding some movies")
    }

    /// Add Movies
    public static var movieListDetailAddMovies: LocalizedStringResource {
        r("movie_list_detail_add_movies", "Add Movies")
    }

    /// Remove from List
    public static var movieListDetailRemoveFromList: LocalizedStringResource {
        r("movie_list_detail_remove_from_list", "Remove from List")
    }

    /// Remove Movie
    public static var movieListDetailRemoveMovie: LocalizedStringResource {
        r("movie_list_detail_remove_movie", "Remove Movie")
    }

    /// Remove
    public static var movieListDetailRemove: LocalizedStringResource {
        r("movie_list_detail_remove", "Remove")
    }

    /// Remove "%@" from this list?
    public static func movieListDetailRemoveMovieMessage(_ a0: String) -> LocalizedStringResource {
        r("movie_list_detail_remove_movie_message", "Remove \"\(a0)\" from this list?")
    }

    /// Movies you want to watch someday
    public static var movieListsWishlistDescriptionFull: LocalizedStringResource {
        r("movie_lists_wishlist_description_full", "Movies you want to watch someday")
    }

    /// Movies you've already watched
    public static var movieListsWatchedDescriptionFull: LocalizedStringResource {
        r("movie_lists_watched_description_full", "Movies you've already watched")
    }

    /// Added
    public static var movieSearchRowAdded: LocalizedStringResource {
        r("movie_search_row_added", "Added")
    }

    /// Search movies to add to your list...
    public static var searchHeaderPlaceholder: LocalizedStringResource {
        r("search_header_placeholder", "Search movies to add to your list...")
    }

    /// Add Movies
    public static var searchMoviesTitle: LocalizedStringResource {
        r("search_movies_title", "Add Movies")
    }

    /// Search
    public static var commonSearch: LocalizedStringResource {
        r("common_search", "Search")
    }

    /// Searching movies...
    public static var searchMoviesSearching: LocalizedStringResource {
        r("search_movies_searching", "Searching movies...")
    }

    /// Missing authentication.
    public static var recipeErrorMissingAuth: LocalizedStringResource {
        r("recipe_error_missing_auth", "Missing authentication.")
    }

    /// Failed to add recipe: %@
    public static func recipeErrorAddRecipe(_ a0: String) -> LocalizedStringResource {
        r("recipe_error_add_recipe", "Failed to add recipe: \(a0)")
    }

    /// Failed to delete recipe: %@
    public static func recipeErrorDeleteRecipe(_ a0: String) -> LocalizedStringResource {
        r("recipe_error_delete_recipe", "Failed to delete recipe: \(a0)")
    }

    /// Loading...
    public static var commonLoading: LocalizedStringResource {
        r("common_loading", "Loading...")
    }

    /// %d of %d completed
    public static func shoppingCategoryCompletedItems(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("shopping_category_completed_items", "\(a0) of \(a1) completed")
    }

    /// Sign In
    public static var authSignInTitle: LocalizedStringResource {
        r("auth_sign_in_title", "Sign In")
    }

    /// Create Account
    public static var authCreateAccountTitle: LocalizedStringResource {
        r("auth_create_account_title", "Create Account")
    }

    /// Password looks good!
    public static var authPasswordValid: LocalizedStringResource {
        r("auth_password_valid", "Password looks good!")
    }

    /// Password should be at least 8 characters
    public static var authPasswordTooShort: LocalizedStringResource {
        r("auth_password_too_short", "Password should be at least 8 characters")
    }

    /// Please enter password first
    public static var authConfirmPasswordEmpty: LocalizedStringResource {
        r("auth_confirm_password_empty", "Please enter password first")
    }

    /// Passwords match!
    public static var authPasswordsMatch: LocalizedStringResource {
        r("auth_passwords_match", "Passwords match!")
    }

    /// Passwords don't match
    public static var authPasswordsMismatch: LocalizedStringResource {
        r("auth_passwords_mismatch", "Passwords don't match")
    }

    /// Welcome to NestZone
    public static var authWelcomeTitle: LocalizedStringResource {
        r("auth_welcome_title", "Welcome to NestZone")
    }

    /// Sign in to continue ✨
    public static var authSignInSubtitle: LocalizedStringResource {
        r("auth_sign_in_subtitle", "Sign in to continue ✨")
    }

    /// Sign in with your Apple ID. NestZone never sees or stores a password.
    public static var authAppleExplainer: LocalizedStringResource {
        r("auth_apple_explainer", "Sign in with your Apple ID. NestZone never sees or stores a password.")
    }

    /// Create your account ✨
    public static var authCreateAccountSubtitle: LocalizedStringResource {
        r("auth_create_account_subtitle", "Create your account ✨")
    }

    /// Login
    public static var authLoginButton: LocalizedStringResource {
        r("auth_login_button", "Login")
    }

    /// Sign Up
    public static var authSignUpButton: LocalizedStringResource {
        r("auth_sign_up_button", "Sign Up")
    }

    /// Full Name
    public static var authFullNameLabel: LocalizedStringResource {
        r("auth_full_name_label", "Full Name")
    }

    /// Enter your full name
    public static var authFullNamePlaceholder: LocalizedStringResource {
        r("auth_full_name_placeholder", "Enter your full name")
    }

    /// Email
    public static var authEmailLabel: LocalizedStringResource {
        r("auth_email_label", "Email")
    }

    /// Enter your email
    public static var authEmailPlaceholder: LocalizedStringResource {
        r("auth_email_placeholder", "Enter your email")
    }

    /// Password
    public static var authPasswordLabel: LocalizedStringResource {
        r("auth_password_label", "Password")
    }

    /// Enter your password
    public static var authPasswordPlaceholder: LocalizedStringResource {
        r("auth_password_placeholder", "Enter your password")
    }

    /// Confirm Password
    public static var authConfirmPasswordLabel: LocalizedStringResource {
        r("auth_confirm_password_label", "Confirm Password")
    }

    /// Confirm your password
    public static var authConfirmPasswordPlaceholder: LocalizedStringResource {
        r("auth_confirm_password_placeholder", "Confirm your password")
    }

    /// Create Account
    public static var authCreateAccountButton: LocalizedStringResource {
        r("auth_create_account_button", "Create Account")
    }

    /// Let's set up your household
    public static var homeSetupSubtitle: LocalizedStringResource {
        r("home_setup_subtitle", "Let's set up your household")
    }

    /// Create New Home
    public static var homeSetupCreateHomeTitle: LocalizedStringResource {
        r("home_setup_create_home_title", "Create New Home")
    }

    /// Start fresh and invite family members
    public static var homeSetupCreateHomeSubtitle: LocalizedStringResource {
        r("home_setup_create_home_subtitle", "Start fresh and invite family members")
    }

    /// Join Existing Home
    public static var homeSetupJoinHomeTitle: LocalizedStringResource {
        r("home_setup_join_home_title", "Join Existing Home")
    }

    /// Use an invite code from a family member
    public static var homeSetupJoinHomeSubtitle: LocalizedStringResource {
        r("home_setup_join_home_subtitle", "Use an invite code from a family member")
    }

    /// Set up your shared living space
    public static var createHomeSubtitle: LocalizedStringResource {
        r("create_home_subtitle", "Set up your shared living space")
    }

    /// Home Name
    public static var createHomeNameLabel: LocalizedStringResource {
        r("create_home_name_label", "Home Name")
    }

    /// Enter home name
    public static var createHomeNamePlaceholder: LocalizedStringResource {
        r("create_home_name_placeholder", "Enter home name")
    }

    /// Address (Optional)
    public static var createHomeAddressLabel: LocalizedStringResource {
        r("create_home_address_label", "Address (Optional)")
    }

    /// Enter home address
    public static var createHomeAddressPlaceholder: LocalizedStringResource {
        r("create_home_address_placeholder", "Enter home address")
    }

    /// Create Home
    public static var createHomeButton: LocalizedStringResource {
        r("create_home_button", "Create Home")
    }

    /// Home Created!
    public static var createHomeSuccessMessage: LocalizedStringResource {
        r("create_home_success_message", "Home Created!")
    }

    /// Home name cannot be empty
    public static var homeManagementHomeNameEmpty: LocalizedStringResource {
        r("home_management_home_name_empty", "Home name cannot be empty")
    }

    /// Invite code cannot be empty
    public static var homeManagementInviteCodeEmpty: LocalizedStringResource {
        r("home_management_invite_code_empty", "Invite code cannot be empty")
    }

    /// Invalid invite code
    public static var homeManagementInvalidInviteCode: LocalizedStringResource {
        r("home_management_invalid_invite_code", "Invalid invite code")
    }

    /// You're already a member of this home
    public static var homeManagementAlreadyMember: LocalizedStringResource {
        r("home_management_already_member", "You're already a member of this home")
    }

    /// Invite Code
    public static var joinHomeInviteCodeLabel: LocalizedStringResource {
        r("join_home_invite_code_label", "Invite Code")
    }

    /// Enter invite code
    public static var joinHomeInviteCodePlaceholder: LocalizedStringResource {
        r("join_home_invite_code_placeholder", "Enter invite code")
    }

    /// Join Home
    public static var joinHomeButton: LocalizedStringResource {
        r("join_home_button", "Join Home")
    }

    /// Joined Home!
    public static var joinHomeSuccessMessage: LocalizedStringResource {
        r("join_home_success_message", "Joined Home!")
    }

    /// Let's Get Started
    public static var noHomesGetStartedTitle: LocalizedStringResource {
        r("no_homes_get_started_title", "Let's Get Started")
    }

    /// Select Your Home
    public static var homeSelectionTitle: LocalizedStringResource {
        r("home_selection_title", "Select Your Home")
    }

    /// Choose which home you want to manage
    public static var homeSelectionSubtitle: LocalizedStringResource {
        r("home_selection_subtitle", "Choose which home you want to manage")
    }

    /// Switch Home
    public static var homeSelectionSwitchTitle: LocalizedStringResource {
        r("home_selection_switch_title", "Switch Home")
    }

    /// Manage Home
    public static var manageHomesButton: LocalizedStringResource {
        r("manage_homes_button", "Manage Home")
    }

    /// Select a different home to manage
    public static var homeSelectionSwitchSubtitle: LocalizedStringResource {
        r("home_selection_switch_subtitle", "Select a different home to manage")
    }

    /// Join Another Home
    public static var joinAnotherHomeButton: LocalizedStringResource {
        r("join_another_home_button", "Join Another Home")
    }

    /// Done
    public static var commonDoneButton: LocalizedStringResource {
        r("common_done_button", "Done")
    }

    /// Your Name
    public static var profileNameTitle: LocalizedStringResource {
        r("profile_name_title", "Your Name")
    }

    /// Enter your name
    public static var profileNamePlaceholder: LocalizedStringResource {
        r("profile_name_placeholder", "Enter your name")
    }

    /// Apple only shares your name the first time you sign in, so you may need to set it here.
    public static var profileNameFootnote: LocalizedStringResource {
        r("profile_name_footnote", "Apple only shares your name the first time you sign in, so you may need to set it here.")
    }

    /// Add your name
    public static var profileNameAdd: LocalizedStringResource {
        r("profile_name_add", "Add your name")
    }

    /// Save
    public static var commonSave: LocalizedStringResource {
        r("common_save", "Save")
    }

    /// Basic
    public static var themeBasic: LocalizedStringResource {
        r("theme_basic", "Basic")
    }

    /// Cyberpunk
    public static var themeCyberpunk: LocalizedStringResource {
        r("theme_cyberpunk", "Cyberpunk")
    }

    /// RetroWave
    public static var themeRetrowave: LocalizedStringResource {
        r("theme_retrowave", "RetroWave")
    }

    /// Neon Night
    public static var themeNeonNight: LocalizedStringResource {
        r("theme_neon_night", "Neon Night")
    }

    /// Deep Ocean
    public static var themeDeepOcean: LocalizedStringResource {
        r("theme_deep_ocean", "Deep Ocean")
    }

    /// Leave this home?
    public static var homeLeaveConfirmTitle: LocalizedStringResource {
        r("home_leave_confirm_title", "Leave this home?")
    }

    /// Leave Home
    public static var homeLeaveConfirmAction: LocalizedStringResource {
        r("home_leave_confirm_action", "Leave Home")
    }

    /// You'll lose access to everything shared in %@.
    public static func homeLeaveConfirmMessage(_ a0: String) -> LocalizedStringResource {
        r("home_leave_confirm_message", "You'll lose access to everything shared in \(a0).")
    }

    /// Delete this home?
    public static var homeDeleteConfirmTitle: LocalizedStringResource {
        r("home_delete_confirm_title", "Delete this home?")
    }

    /// Delete Home
    public static var homeDeleteConfirmAction: LocalizedStringResource {
        r("home_delete_confirm_action", "Delete Home")
    }

    /// You're the last member of %@. Leaving deletes it and everything in it — tasks, notes, l...
    public static func homeDeleteConfirmMessage(_ a0: String) -> LocalizedStringResource {
        r("home_delete_confirm_message", "You're the last member of \(a0). Leaving deletes it and everything in it — tasks, notes, lists, recipes and messages. This can't be undone.")
    }

    /// Members
    public static var homeMembersLabel: LocalizedStringResource {
        r("home_members_label", "Members")
    }

    /// Invite code copied
    public static var homeInviteCodeCopied: LocalizedStringResource {
        r("home_invite_code_copied", "Invite code copied")
    }

    /// Try Again
    public static var commonRetry: LocalizedStringResource {
        r("common_retry", "Try Again")
    }

    /// Switch
    public static var homeSwitchAction: LocalizedStringResource {
        r("home_switch_action", "Switch")
    }

    /// Tasks
    public static var homeTasksTitle: LocalizedStringResource {
        r("home_tasks_title", "Tasks")
    }

    /// Nothing to do
    public static var homeTasksEmptyTitle: LocalizedStringResource {
        r("home_tasks_empty_title", "Nothing to do")
    }

    /// When someone adds a task it shows up here.
    public static var homeTasksEmptyMessage: LocalizedStringResource {
        r("home_tasks_empty_message", "When someone adds a task it shows up here.")
    }

    /// Low
    public static var tasksPriorityLow: LocalizedStringResource {
        r("tasks_priority_low", "Low")
    }

    /// Medium
    public static var tasksPriorityMedium: LocalizedStringResource {
        r("tasks_priority_medium", "Medium")
    }

    /// High
    public static var tasksPriorityHigh: LocalizedStringResource {
        r("tasks_priority_high", "High")
    }

    /// Toggle done
    public static var tasksToggleAction: LocalizedStringResource {
        r("tasks_toggle_action", "Toggle done")
    }

    /// To do
    public static var tasksFilterOpen: LocalizedStringResource {
        r("tasks_filter_open", "To do")
    }

    /// Done
    public static var tasksFilterDone: LocalizedStringResource {
        r("tasks_filter_done", "Done")
    }

    /// All
    public static var tasksFilterAll: LocalizedStringResource {
        r("tasks_filter_all", "All")
    }

    /// New task
    public static var tasksComposeTitle: LocalizedStringResource {
        r("tasks_compose_title", "New task")
    }

    /// What needs doing?
    public static var tasksTitleLabel: LocalizedStringResource {
        r("tasks_title_label", "What needs doing?")
    }

    /// Details
    public static var tasksDetailsLabel: LocalizedStringResource {
        r("tasks_details_label", "Details")
    }

    /// Assign to
    public static var tasksAssigneeLabel: LocalizedStringResource {
        r("tasks_assignee_label", "Assign to")
    }

    /// Anyone
    public static var tasksAssigneeNone: LocalizedStringResource {
        r("tasks_assignee_none", "Anyone")
    }

    /// Due date
    public static var tasksDueDateLabel: LocalizedStringResource {
        r("tasks_due_date_label", "Due date")
    }

    /// Priority
    public static var tasksPriorityLabel: LocalizedStringResource {
        r("tasks_priority_label", "Priority")
    }

    /// Type
    public static var tasksKindLabel: LocalizedStringResource {
        r("tasks_kind_label", "Type")
    }

    /// Tasks
    public static var tasksScreenTitle: LocalizedStringResource {
        r("tasks_screen_title", "Tasks")
    }

    /// Cleaning
    public static var tasksKindCleaning: LocalizedStringResource {
        r("tasks_kind_cleaning", "Cleaning")
    }

    /// Shopping
    public static var tasksKindShopping: LocalizedStringResource {
        r("tasks_kind_shopping", "Shopping")
    }

    /// Maintenance
    public static var tasksKindMaintenance: LocalizedStringResource {
        r("tasks_kind_maintenance", "Maintenance")
    }

    /// General
    public static var tasksKindGeneral: LocalizedStringResource {
        r("tasks_kind_general", "General")
    }

    /// See all
    public static var commonSeeAll: LocalizedStringResource {
        r("common_see_all", "See all")
    }

    /// Edit
    public static var commonEdit: LocalizedStringResource {
        r("common_edit", "Edit")
    }

    /// Remove
    public static var commonRemove: LocalizedStringResource {
        r("common_remove", "Remove")
    }

    /// You're offline
    public static var commonOfflineTitle: LocalizedStringResource {
        r("common_offline_title", "You're offline")
    }

    /// You'll need to sign in with Apple again to get back in.
    public static var settingsLogoutConfirmMessage: LocalizedStringResource {
        r("settings_logout_confirm_message", "You'll need to sign in with Apple again to get back in.")
    }

    /// Your name
    public static var settingsEditNameTitle: LocalizedStringResource {
        r("settings_edit_name_title", "Your name")
    }

    /// This is how the rest of your household sees you.
    public static var settingsEditNameMessage: LocalizedStringResource {
        r("settings_edit_name_message", "This is how the rest of your household sees you.")
    }

    /// Themes tint the app. Surfaces stay glass so they pick up what's behind them.
    public static var settingsAppearanceThemeFooter: LocalizedStringResource {
        r("settings_appearance_theme_footer", "Themes tint the app. Surfaces stay glass so they pick up what's behind them.")
    }

    /// Allow mature titles
    public static var settingsAdultTitlesTitle: LocalizedStringResource {
        r("settings_adult_titles_title", "Allow mature titles")
    }

    /// Includes adult results when browsing movies.
    public static var settingsAdultTitlesFooter: LocalizedStringResource {
        r("settings_adult_titles_footer", "Includes adult results when browsing movies.")
    }

    /// You
    public static var notesAuthorYou: LocalizedStringResource {
        r("notes_author_you", "You")
    }

    /// Member
    public static var notesAuthorMember: LocalizedStringResource {
        r("notes_author_member", "Member")
    }

    /// Unknown
    public static var notesAuthorUnknown: LocalizedStringResource {
        r("notes_author_unknown", "Unknown")
    }

    /// Delete this note?
    public static var notesDeleteConfirmTitle: LocalizedStringResource {
        r("notes_delete_confirm_title", "Delete this note?")
    }

    /// It disappears for everyone in the home.
    public static var notesDeleteConfirmMessage: LocalizedStringResource {
        r("notes_delete_confirm_message", "It disappears for everyone in the home.")
    }

    /// New note
    public static var notesComposeTitle: LocalizedStringResource {
        r("notes_compose_title", "New note")
    }

    /// Edit note
    public static var notesEditTitle: LocalizedStringResource {
        r("notes_edit_title", "Edit note")
    }

    /// What's on your mind?
    public static var notesComposePlaceholder: LocalizedStringResource {
        r("notes_compose_placeholder", "What's on your mind?")
    }

    /// Colour
    public static var notesColorLabel: LocalizedStringResource {
        r("notes_color_label", "Colour")
    }

    /// Search notes
    public static var notesSearchPlaceholder: LocalizedStringResource {
        r("notes_search_placeholder", "Search notes")
    }

    /// Coming soon
    public static var hubComingSoon: LocalizedStringResource {
        r("hub_coming_soon", "Coming soon")
    }

    /// Nothing on the list
    public static var shoppingEmptyTitle: LocalizedStringResource {
        r("shopping_empty_title", "Nothing on the list")
    }

    /// Add the first thing you need.
    public static var shoppingEmptyMessage: LocalizedStringResource {
        r("shopping_empty_message", "Add the first thing you need.")
    }

    /// Add an item
    public static var shoppingAddPlaceholder: LocalizedStringResource {
        r("shopping_add_placeholder", "Add an item")
    }

    /// Bought
    public static var shoppingPurchasedSection: LocalizedStringResource {
        r("shopping_purchased_section", "Bought")
    }

    /// Clear bought
    public static var shoppingClearPurchased: LocalizedStringResource {
        r("shopping_clear_purchased", "Clear bought")
    }

    /// Qty
    public static var shoppingQuantityLabel: LocalizedStringResource {
        r("shopping_quantity_label", "Qty")
    }

    /// Ingredients
    public static var recipesDetailIngredientsTitle: LocalizedStringResource {
        r("recipes_detail_ingredients_title", "Ingredients")
    }

    /// Steps
    public static var recipesDetailStepsTitle: LocalizedStringResource {
        r("recipes_detail_steps_title", "Steps")
    }

    /// Start cooking
    public static var recipesDetailStartCooking: LocalizedStringResource {
        r("recipes_detail_start_cooking", "Start cooking")
    }

    /// Start preparing
    public static var recipesDetailStartPreparing: LocalizedStringResource {
        r("recipes_detail_start_preparing", "Start preparing")
    }


    /// Remove all
    public static var shoppingRemoveAll: LocalizedStringResource {
        r("shopping_remove_all", "Remove all")
    }

    /// Remove %lld items?
    public static func shoppingClearGroupTitle(_ a0: Int) -> LocalizedStringResource {
        r("shopping_clear_group_title", "Remove \(a0) items?")
    }

    /// Everything under “%@” leaves the list, bought or not.
    public static func shoppingClearGroupMessage(_ a0: String) -> LocalizedStringResource {
        r("shopping_clear_group_message", "Everything under “\(a0)” leaves the list, bought or not.")
    }

// MARK: - Dinner

    /// How are you deciding?
    public static var dinnerRouteTitle: LocalizedStringResource {
        r("dinner_route_title", "How are you deciding?")
    }

    /// Set it now
    public static var dinnerRouteSet: LocalizedStringResource {
        r("dinner_route_set", "Set it now")
    }

    /// Decide for the household — no vote.
    public static var dinnerRouteSetSubtitle: LocalizedStringResource {
        r("dinner_route_set_subtitle", "Decide for the household — no vote.")
    }

    /// Ask everyone
    public static var dinnerRouteVote: LocalizedStringResource {
        r("dinner_route_vote", "Ask everyone")
    }

    /// Put a few options up and let the house pick.
    public static var dinnerRouteVoteSubtitle: LocalizedStringResource {
        r("dinner_route_vote_subtitle", "Put a few options up and let the house pick.")
    }

    /// Dinner round
    public static var dinnerRoundTitle: LocalizedStringResource {
        r("dinner_round_title", "Dinner round")
    }

    /// Pick what goes on the ballot
    public static var dinnerRoundPickCandidates: LocalizedStringResource {
        r("dinner_round_pick_candidates", "Pick what goes on the ballot")
    }

    /// Start the round
    public static var dinnerRoundStart: LocalizedStringResource {
        r("dinner_round_start", "Start the round")
    }

    /// %lld on the ballot
    public static func dinnerRoundSelected(_ a0: Int) -> LocalizedStringResource {
        r("dinner_round_selected", "\(a0) on the ballot")
    }

    /// Pick at least two
    public static var dinnerRoundNeedsTwo: LocalizedStringResource {
        r("dinner_round_needs_two", "Pick at least two")
    }

    /// Add
    public static var dinnerRoundAddCustom: LocalizedStringResource {
        r("dinner_round_add_custom", "Add")
    }

    /// A round is already running
    public static var dinnerRoundOpen: LocalizedStringResource {
        r("dinner_round_open", "A round is already running")
    }

    /// Open it to cast your vote.
    public static var dinnerRoundOpenHint: LocalizedStringResource {
        r("dinner_round_open_hint", "Open it to cast your vote.")
    }


    /// Something else
    public static var dinnerSourceCustom: LocalizedStringResource {
        r("dinner_source_custom", "Something else")
    }

    /// What are you making?
    public static var dinnerCustomLabel: LocalizedStringResource {
        r("dinner_custom_label", "What are you making?")
    }

    /// Leftovers, pasta, whatever's in the fridge
    public static var dinnerCustomPlaceholder: LocalizedStringResource {
        r("dinner_custom_placeholder", "Leftovers, pasta, whatever's in the fridge")
    }


    /// Your recipes
    public static var dinnerSourceSaved: LocalizedStringResource {
        r("dinner_source_saved", "Your recipes")
    }

    /// Explore
    public static var dinnerSourceExplore: LocalizedStringResource {
        r("dinner_source_explore", "Explore")
    }

    /// Dinner is already decided
    public static var dinnerAlreadyDecided: LocalizedStringResource {
        r("dinner_already_decided", "Dinner is already decided")
    }

    /// Choosing again replaces it.
    public static var dinnerAlreadyDecidedHint: LocalizedStringResource {
        r("dinner_already_decided_hint", "Choosing again replaces it.")
    }

    /// All
    public static var dinnerFilterAll: LocalizedStringResource {
        r("dinner_filter_all", "All")
    }


    /// Tonight
    public static var dinnerTonightTitle: LocalizedStringResource {
        r("dinner_tonight_title", "Tonight")
    }
    /// What's for dinner?
    public static var dinnerEmptyTitle: LocalizedStringResource {
        r("dinner_empty_title", "What's for dinner?")
    }
    /// Cook something, order in, or go out.
    public static var dinnerEmptySubtitle: LocalizedStringResource {
        r("dinner_empty_subtitle", "Cook something, order in, or go out.")
    }
    /// Decide dinner
    public static var dinnerDecideButton: LocalizedStringResource {
        r("dinner_decide_button", "Decide dinner")
    }
    /// Change
    public static var dinnerChangeButton: LocalizedStringResource {
        r("dinner_change_button", "Change")
    }
    /// Clear dinner
    public static var dinnerClearButton: LocalizedStringResource {
        r("dinner_clear_button", "Clear dinner")
    }
    /// Cook at home
    public static var dinnerKindCook: LocalizedStringResource {
        r("dinner_kind_cook", "Cook at home")
    }
    /// Order in
    public static var dinnerKindOrder: LocalizedStringResource {
        r("dinner_kind_order", "Order in")
    }
    /// Go out
    public static var dinnerKindOut: LocalizedStringResource {
        r("dinner_kind_out", "Go out")
    }
    /// Pick something from your recipes
    public static var dinnerKindCookSubtitle: LocalizedStringResource {
        r("dinner_kind_cook_subtitle", "Pick something from your recipes")
    }
    /// Pick a cuisine, and where from
    public static var dinnerKindOrderSubtitle: LocalizedStringResource {
        r("dinner_kind_order_subtitle", "Pick a cuisine, and where from")
    }
    /// Pick a cuisine, and where to
    public static var dinnerKindOutSubtitle: LocalizedStringResource {
        r("dinner_kind_out_subtitle", "Pick a cuisine, and where to")
    }
    /// Choose a cuisine
    public static var dinnerChooseCuisine: LocalizedStringResource {
        r("dinner_choose_cuisine", "Choose a cuisine")
    }
    /// Choose a recipe
    public static var dinnerChooseRecipe: LocalizedStringResource {
        r("dinner_choose_recipe", "Choose a recipe")
    }
    /// Where from
    public static var dinnerPlaceOrder: LocalizedStringResource {
        r("dinner_place_order", "Where from")
    }
    /// Where to
    public static var dinnerPlaceOut: LocalizedStringResource {
        r("dinner_place_out", "Where to")
    }
    /// Optional
    public static var dinnerPlacePlaceholder: LocalizedStringResource {
        r("dinner_place_placeholder", "Optional")
    }
    /// That's dinner
    public static var dinnerSetButton: LocalizedStringResource {
        r("dinner_set_button", "That's dinner")
    }
    /// No recipes saved yet
    public static var dinnerNoRecipes: LocalizedStringResource {
        r("dinner_no_recipes", "No recipes saved yet")
    }
    /// Ordering in
    public static var dinnerOrderingIn: LocalizedStringResource {
        r("dinner_ordering_in", "Ordering in")
    }
    /// Going out
    public static var dinnerGoingOut: LocalizedStringResource {
        r("dinner_going_out", "Going out")
    }
    /// Plan for tonight
    public static var recipesDetailPlanTonight: LocalizedStringResource {
        r("recipes_detail_plan_tonight", "Plan for tonight")
    }
    /// On tonight's menu
    public static var recipesDetailPlannedTonight: LocalizedStringResource {
        r("recipes_detail_planned_tonight", "On tonight's menu")
    }
    /// Turkish
    public static var cuisineTurkish: LocalizedStringResource {
        r("cuisine_turkish", "Turkish")
    }
    /// Italian
    public static var cuisineItalian: LocalizedStringResource {
        r("cuisine_italian", "Italian")
    }
    /// Chinese
    public static var cuisineChinese: LocalizedStringResource {
        r("cuisine_chinese", "Chinese")
    }
    /// Japanese
    public static var cuisineJapanese: LocalizedStringResource {
        r("cuisine_japanese", "Japanese")
    }
    /// Indian
    public static var cuisineIndian: LocalizedStringResource {
        r("cuisine_indian", "Indian")
    }
    /// Mexican
    public static var cuisineMexican: LocalizedStringResource {
        r("cuisine_mexican", "Mexican")
    }
    /// Thai
    public static var cuisineThai: LocalizedStringResource {
        r("cuisine_thai", "Thai")
    }
    /// Mediterranean
    public static var cuisineMediterranean: LocalizedStringResource {
        r("cuisine_mediterranean", "Mediterranean")
    }
    /// American
    public static var cuisineAmerican: LocalizedStringResource {
        r("cuisine_american", "American")
    }
    /// Korean
    public static var cuisineKorean: LocalizedStringResource {
        r("cuisine_korean", "Korean")
    }
    /// Seafood
    public static var cuisineSeafood: LocalizedStringResource {
        r("cuisine_seafood", "Seafood")
    }
    /// Something else
    public static var cuisineOther: LocalizedStringResource {
        r("cuisine_other", "Something else")
    }


    /// Add the missing %lld
    public static func recipesDetailAddMissing(_ a0: Int) -> LocalizedStringResource {
        r("recipes_detail_add_missing", "Add the missing \(a0)")
    }

    /// %1$lld of %2$lld already on your list
    public static func recipesDetailOnListCount(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("recipes_detail_on_list_count", "\(a0) of \(a1) already on your list")
    }

    /// Go to shopping list
    public static var recipesDetailGoToList: LocalizedStringResource {
        r("recipes_detail_go_to_list", "Go to shopping list")
    }

    /// %lld items added
    public static func recipesDetailAddedCount(_ a0: Int) -> LocalizedStringResource {
        r("recipes_detail_added_count", "\(a0) items added")
    }

    /// Everything is on the list
    public static var recipesDetailAllOnList: LocalizedStringResource {
        r("recipes_detail_all_on_list", "Everything is on the list")
    }

    /// Set it now
    public static var dinnerSetDirectly: LocalizedStringResource {
        r("dinner_set_directly", "Set it now")
    }

    /// Decide for the household — no vote.
    public static var dinnerSetDirectlyHint: LocalizedStringResource {
        r("dinner_set_directly_hint", "Decide for the household — no vote.")
    }

    /// Add to shopping list
    public static var recipesDetailAddToShopping: LocalizedStringResource {
        r("recipes_detail_add_to_shopping", "Add to shopping list")
    }

    /// Added to the list
    public static var recipesDetailAddedToShopping: LocalizedStringResource {
        r("recipes_detail_added_to_shopping", "Added to the list")
    }

    /// Already on the list
    public static var recipesDetailAlreadyOnList: LocalizedStringResource {
        r("recipes_detail_already_on_list", "Already on the list")
    }

    /// For %@
    public static func shoppingForRecipe(_ a0: String) -> LocalizedStringResource {
        r("shopping_for_recipe", "For \(a0)")
    }

    /// Servings
    public static var recipesNewRecipeServingsPicker: LocalizedStringResource {
        r("recipes_new_recipe_servings_picker", "Servings")
    }

    /// New recipe
    public static var recipesComposeTitle: LocalizedStringResource {
        r("recipes_compose_title", "New recipe")
    }

    /// Description
    public static var recipesComposeSummaryLabel: LocalizedStringResource {
        r("recipes_compose_summary_label", "Description")
    }

    /// Add ingredient
    public static var recipesComposeAddIngredient: LocalizedStringResource {
        r("recipes_compose_add_ingredient", "Add ingredient")
    }

    /// Add step
    public static var recipesComposeAddStep: LocalizedStringResource {
        r("recipes_compose_add_step", "Add step")
    }

    /// Tags
    public static var recipesComposeTagsLabel: LocalizedStringResource {
        r("recipes_compose_tags_label", "Tags")
    }

    /// Prep time
    public static var recipesNewRecipePrepTimePicker: LocalizedStringResource {
        r("recipes_new_recipe_prep_time_picker", "Prep time")
    }

    /// Cook time
    public static var recipesNewRecipeCookTimePicker: LocalizedStringResource {
        r("recipes_new_recipe_cook_time_picker", "Cook time")
    }

    /// Search movies
    public static var moviesSearchPlaceholder: LocalizedStringResource {
        r("movies_search_placeholder", "Search movies")
    }

    /// Add to list
    public static var moviesAddToList: LocalizedStringResource {
        r("movies_add_to_list", "Add to list")
    }

    /// On a list
    public static var moviesInList: LocalizedStringResource {
        r("movies_in_list", "On a list")
    }

    /// Nothing here yet
    public static var moviesEmptyListTitle: LocalizedStringResource {
        r("movies_empty_list_title", "Nothing here yet")
    }

    /// Search for a film and add it to this list.
    public static var moviesEmptyListMessage: LocalizedStringResource {
        r("movies_empty_list_message", "Search for a film and add it to this list.")
    }

    /// New list
    public static var moviesNewListTitle: LocalizedStringResource {
        r("movies_new_list_title", "New list")
    }

    /// List name
    public static var moviesListNameLabel: LocalizedStringResource {
        r("movies_list_name_label", "List name")
    }

    /// The list goes away. The films stay on any other list they're on.
    public static var moviesDeleteListMessage: LocalizedStringResource {
        r("movies_delete_list_message", "The list goes away. The films stay on any other list they're on.")
    }

    /// What to watch
    public static var movienightTitle: LocalizedStringResource {
        r("movienight_title", "What to watch")
    }

    /// Start a round
    public static var movienightStart: LocalizedStringResource {
        r("movienight_start", "Start a round")
    }

    /// Swipe right if you'd watch it, left if you wouldn't.
    public static var movienightSwipeHint: LocalizedStringResource {
        r("movienight_swipe_hint", "Swipe right if you'd watch it, left if you wouldn't.")
    }

    /// Waiting for the others…
    public static var movienightWaiting: LocalizedStringResource {
        r("movienight_waiting", "Waiting for the others…")
    }

    /// Everyone said yes
    public static var movienightMatchesTitle: LocalizedStringResource {
        r("movienight_matches_title", "Everyone said yes")
    }

    /// No match yet
    public static var movienightNoMatches: LocalizedStringResource {
        r("movienight_no_matches", "No match yet")
    }

    /// Keep swiping, or add more films to the round.
    public static var movienightNoMatchesMessage: LocalizedStringResource {
        r("movienight_no_matches_message", "Keep swiping, or add more films to the round.")
    }

    /// Pick a genre
    public static var movienightPickGenre: LocalizedStringResource {
        r("movienight_pick_genre", "Pick a genre")
    }

    /// End round
    public static var movienightClosePoll: LocalizedStringResource {
        r("movienight_close_poll", "End for everyone")
    }

    /// Ending the round closes it for the whole home. Anyone still swiping stops where they are.
    public static var movienightCloseMessage: LocalizedStringResource {
        r(
            "movienight_close_message",
            "Ending the round closes it for the whole home. Anyone still swiping stops where they are."
        )
    }

    /// Everyone has finished
    public static var movienightEveryoneDone: LocalizedStringResource {
        r("movienight_everyone_done", "Everyone has finished")
    }

    /// %1$lld of %2$lld have finished
    public static func movienightFinishedCount(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("movienight_finished_count", "\(a0) of \(a1) have finished")
    }

    /// Previous rounds
    public static var movienightPreviousRounds: LocalizedStringResource {
        r("movienight_previous_rounds", "Previous rounds")
    }

    /// Rounding up the films…
    public static var movienightBuildingDeck: LocalizedStringResource {
        r("movienight_building_deck", "Rounding up the films…")
    }

    /// %1$lld/%2$lld
    public static func movienightPosition(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("movienight_position", "\(a0)/\(a1)")
    }

    /// Film %1$lld of %2$lld
    public static func movienightPositionLabel(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("movienight_position_label", "Film \(a0) of \(a1)")
    }

    /// Undo
    public static var movienightUndo: LocalizedStringResource {
        r("movienight_undo", "Undo")
    }

    /// Pass
    public static var movienightPass: LocalizedStringResource {
        r("movienight_pass", "Pass")
    }

    /// Would watch
    public static var movienightWouldWatch: LocalizedStringResource {
        r("movienight_would_watch", "Would watch")
    }

    /// No one agreed — best was %1$lld of %2$lld
    public static func previousPollsClosest(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("previous_polls_closest", "No one agreed — best was \(a0) of \(a1)")
    }

    /// Nobody swiped right on anything
    public static var previousPollsNothing: LocalizedStringResource {
        r("previous_polls_nothing", "Nobody swiped right on anything")
    }

    /// Only %1$lld of %2$lld people voted
    public static func previousPollsTurnout(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("previous_polls_turnout", "Only \(a0) of \(a1) people voted")
    }

    /// Save to a list
    public static var moviesSaveToList: LocalizedStringResource {
        r("movies_save_to_list", "Save to a list")
    }

    /// Conversation
    public static var messagesConversationUntitled: LocalizedStringResource {
        r("messages_conversation_untitled", "Conversation")
    }

    /// Message
    public static var messagesComposePlaceholder: LocalizedStringResource {
        r("messages_compose_placeholder", "Message")
    }

    /// New conversation
    public static var messagesNewConversationTitle: LocalizedStringResource {
        r("messages_new_conversation_title", "New conversation")
    }

    /// Who's in it?
    public static var messagesPickPeople: LocalizedStringResource {
        r("messages_pick_people", "Who's in it?")
    }

    public static func messagesGroupDefaultTitle(_ a0: String) -> LocalizedStringResource {
        r("messages_group_default_title", "\(a0) Chat")
    }

    public static var messagesEditingBanner: LocalizedStringResource {
        r("messages_editing_banner", "Editing message")
    }

    public static var messagesRenameTitle: LocalizedStringResource {
        r("messages_rename_title", "Rename chat")
    }

    public static var messagesRenameMessage: LocalizedStringResource {
        r("messages_rename_message", "Leave it empty to go back to the default name.")
    }

    public static var messagesRenamePlaceholder: LocalizedStringResource {
        r("messages_rename_placeholder", "Chat name")
    }

    public static var messagesNobodyToMessage: LocalizedStringResource {
        r("messages_nobody_to_message", "You're the only one here. Invite someone from Settings and they'll show up in this list.")
    }

    /// Group name (optional)
    public static var messagesGroupNameOptional: LocalizedStringResource {
        r("messages_group_name_optional", "Group name (optional)")
    }

    /// Read
    public static var messagesReadBy: LocalizedStringResource {
        r("messages_read_by", "Read")
    }

    /// We'll catch up as soon as you're back.
    public static var commonOfflineMessage: LocalizedStringResource {
        r("common_offline_message", "We'll catch up as soon as you're back.")
    }

    /// %lld members
    public static func settingsMembersCount(_ a0: Int) -> LocalizedStringResource {
        r("settings_members_count", "\(a0) members")
    }

    /// %lld recipes found
    public static func recipesExploreFilterRecipeFoundCount(_ a0: Int) -> LocalizedStringResource {
        r("recipes_explore_filter_recipe_found_count", "\(a0) recipes found")
    }

    /// No matches
    public static var notesSearchEmptyTitle: LocalizedStringResource {
        r("notes_search_empty_title", "No matches")
    }

    /// Try a different word.
    public static var notesSearchEmptyMessage: LocalizedStringResource {
        r("notes_search_empty_message", "Try a different word.")
    }

    /// Touch and hold to edit
    public static var notesEditHint: LocalizedStringResource {
        r("notes_edit_hint", "Touch and hold to edit")
    }

    /// Preview
    public static var notesPreviewLabel: LocalizedStringResource {
        r("notes_preview_label", "Preview")
    }

    /// Your note will appear here…
    public static var notesPreviewPlaceholder: LocalizedStringResource {
        r("notes_preview_placeholder", "Your note will appear here…")
    }

    /// Now
    public static var notesPreviewNow: LocalizedStringResource {
        r("notes_preview_now", "Now")
    }

    /// Sunny Yellow
    public static var notesColorYellow: LocalizedStringResource {
        r("notes_color_yellow", "Sunny Yellow")
    }

    /// Vibrant Orange
    public static var notesColorOrange: LocalizedStringResource {
        r("notes_color_orange", "Vibrant Orange")
    }

    /// Sweet Pink
    public static var notesColorPink: LocalizedStringResource {
        r("notes_color_pink", "Sweet Pink")
    }

    /// Warm Red
    public static var notesColorRed: LocalizedStringResource {
        r("notes_color_red", "Warm Red")
    }

    /// Fresh Green
    public static var notesColorGreen: LocalizedStringResource {
        r("notes_color_green", "Fresh Green")
    }

    /// Ocean Blue
    public static var notesColorBlue: LocalizedStringResource {
        r("notes_color_blue", "Ocean Blue")
    }

    /// Royal Purple
    public static var notesColorPurple: LocalizedStringResource {
        r("notes_color_purple", "Royal Purple")
    }

    /// Timer
    public static var recipesTimerTitle: LocalizedStringResource {
        r("recipes_timer_title", "Timer")
    }

    /// Start timer
    public static var recipesTimerStart: LocalizedStringResource {
        r("recipes_timer_start", "Start timer")
    }

    /// Stop
    public static var recipesTimerStop: LocalizedStringResource {
        r("recipes_timer_stop", "Stop")
    }

    /// Time's up
    public static var recipesTimerDoneTitle: LocalizedStringResource {
        r("recipes_timer_done_title", "Time's up")
    }

    /// Your timer for this step has finished.
    public static var recipesTimerDoneMessage: LocalizedStringResource {
        r("recipes_timer_done_message", "Your timer for this step has finished.")
    }

    /// This step mentions %@. Start a timer?
    public static func recipesTimerSuggested(_ a0: String) -> LocalizedStringResource {
        r("recipes_timer_suggested", "This step mentions \(a0). Start a timer?")
    }

    /// Custom
    public static var recipesTimerCustom: LocalizedStringResource {
        r("recipes_timer_custom", "Custom")
    }

    /// %lld min
    public static func recipesTimerMinutes(_ a0: Int) -> LocalizedStringResource {
        r("recipes_timer_minutes", "\(a0) min")
    }

    /// About this film
    public static var moviesDetailTitle: LocalizedStringResource {
        r("movies_detail_title", "About this film")
    }

    /// Cast
    public static var moviesDetailCast: LocalizedStringResource {
        r("movies_detail_cast", "Cast")
    }

    /// Directed by
    public static var moviesDetailDirector: LocalizedStringResource {
        r("movies_detail_director", "Directed by")
    }

    /// Runtime
    public static var moviesDetailRuntime: LocalizedStringResource {
        r("movies_detail_runtime", "Runtime")
    }

    /// Rating
    public static var moviesDetailRating: LocalizedStringResource {
        r("movies_detail_rating", "Rating")
    }

    /// Search for a film to add
    public static var moviesSearchPrompt: LocalizedStringResource {
        r("movies_search_prompt", "Search for a film to add")
    }

    /// Previous rounds
    public static var movienightHistoryTitle: LocalizedStringResource {
        r("movienight_history_title", "Previous rounds")
    }

    /// Household activity
    public static var settingsNotificationsToggle: LocalizedStringResource {
        r("settings_notifications_toggle", "Household activity")
    }

    /// Get a notification when someone adds a task, a shopping item, a note, a recipe or a film, plans dinner, finishes a task or joins the home.
    public static var settingsNotificationsFooter: LocalizedStringResource {
        r("settings_notifications_footer", "Get a notification when someone adds a task, a shopping item, a note, a recipe or a film, plans dinner, finishes a task or joins the home.")
    }

    /// Notifications are off for NestZone. Turn them on in Settings.
    public static var settingsNotificationsDenied: LocalizedStringResource {
        r("settings_notifications_denied", "Notifications are off for NestZone. Turn them on in Settings.")
    }

    /// Open Settings
    public static var settingsNotificationsOpenSettings: LocalizedStringResource {
        r("settings_notifications_open_settings", "Open Settings")
    }

    /// Send a test notification
    public static var settingsNotificationsSendTest: LocalizedStringResource {
        r("settings_notifications_send_test", "Send a test notification")
    }

    /// This device
    public static var settingsNotificationsDevice: LocalizedStringResource {
        r("settings_notifications_device", "This device")
    }

    /// Not registered
    public static var settingsNotificationsNoDevice: LocalizedStringResource {
        r("settings_notifications_no_device", "Not registered")
    }

    // MARK: - Relative time

    /// Just now
    public static var timeJustNow: LocalizedStringResource {
        r("time_just_now", "Just now")
    }

    /// %lld min ago
    public static func timeMinutesAgo(_ a0: Int) -> LocalizedStringResource {
        r("time_minutes_ago", "\(a0) min ago")
    }

    /// %lld h ago
    public static func timeHoursAgo(_ a0: Int) -> LocalizedStringResource {
        r("time_hours_ago", "\(a0) h ago")
    }

    /// %lld d ago
    public static func timeDaysAgo(_ a0: Int) -> LocalizedStringResource {
        r("time_days_ago", "\(a0) d ago")
    }

    // MARK: - Notification permission prompt

    /// Keep up with the household?
    public static var notificationsPromptTitle: LocalizedStringResource {
        r("notifications_prompt_title", "Keep up with the household?")
    }

    /// Get a notification when someone adds a task, a shopping item, a note or plans dinner. You can change this any time in Settings.
    public static var notificationsPromptMessage: LocalizedStringResource {
        r("notifications_prompt_message", "Get a notification when someone adds a task, a shopping item, a note or plans dinner. You can change this any time in Settings.")
    }

    /// Turn on
    public static var notificationsPromptAllow: LocalizedStringResource {
        r("notifications_prompt_allow", "Turn on")
    }

    /// Not now
    public static var notificationsPromptNotNow: LocalizedStringResource {
        r("notifications_prompt_not_now", "Not now")
    }

    // MARK: - Bills & Finance
    //
    // The household ledger. Amounts themselves are never strings here — they
    // are formatted by `Money`, which knows the currency each figure was
    // written in — so every parameter below that looks like money arrives
    // already formatted.

    /// Overview
    public static var financeSectionOverview: LocalizedStringResource {
        r("finance_section_overview", "Overview")
    }

    /// Expenses
    public static var financeSectionLedger: LocalizedStringResource {
        r("finance_section_ledger", "Expenses")
    }

    /// Bills
    public static var financeSectionBills: LocalizedStringResource {
        r("finance_section_bills", "Bills")
    }

    /// Budgets
    public static var financeSectionBudgets: LocalizedStringResource {
        r("finance_section_budgets", "Budgets")
    }

    /// You
    public static var financeYou: LocalizedStringResource {
        r("finance_you", "You")
    }

    /// Someone
    public static var financeSomeone: LocalizedStringResource {
        r("finance_someone", "Someone")
    }

    /// You’re owed
    public static var financeYouAreOwed: LocalizedStringResource {
        r("finance_you_are_owed", "You’re owed")
    }

    /// You owe
    public static var financeYouOwe: LocalizedStringResource {
        r("finance_you_owe", "You owe")
    }

    /// All square
    public static var financeAllSquareTitle: LocalizedStringResource {
        r("finance_all_square_title", "All square")
    }

    /// Nobody owes anybody a thing.
    public static var financeAllSquareMessage: LocalizedStringResource {
        r("finance_all_square_message", "Nobody owes anybody a thing.")
    }

    /// You owe %@
    public static func financeYouOwePerson(_ a0: String) -> LocalizedStringResource {
        r("finance_you_owe_person", "You owe \(a0)")
    }

    /// %@ owes you
    public static func financePersonOwesYou(_ a0: String) -> LocalizedStringResource {
        r("finance_person_owes_you", "\(a0) owes you")
    }

    /// Settle up
    public static var financeSettleUp: LocalizedStringResource {
        r("finance_settle_up", "Settle up")
    }

    /// Spent this month
    public static var financeSpentThisMonth: LocalizedStringResource {
        r("finance_spent_this_month", "Spent this month")
    }

    /// Six months
    public static var financeTrendTitle: LocalizedStringResource {
        r("finance_trend_title", "Six months")
    }

    /// Up on last month
    public static var financeTrendUp: LocalizedStringResource {
        r("finance_trend_up", "Up on last month")
    }

    /// Down on last month
    public static var financeTrendDown: LocalizedStringResource {
        r("finance_trend_down", "Down on last month")
    }

    /// Where it went
    public static var financeCategoriesTitle: LocalizedStringResource {
        r("finance_categories_title", "Where it went")
    }

    /// This month
    public static var financeDonutCaption: LocalizedStringResource {
        r("finance_donut_caption", "This month")
    }

    /// Who’s up, who’s down
    public static var financeBalancesTitle: LocalizedStringResource {
        r("finance_balances_title", "Who’s up, who’s down")
    }

    /// Across everything, not just this month
    public static var financeBalancesSubtitle: LocalizedStringResource {
        r("finance_balances_subtitle", "Across everything, not just this month")
    }

    /// Paid this month
    public static var financePaidThisMonth: LocalizedStringResource {
        r("finance_paid_this_month", "Paid this month")
    }

    /// is owed %@
    public static func financeIsOwedAmount(_ a0: String) -> LocalizedStringResource {
        r("finance_is_owed_amount", "is owed \(a0)")
    }

    /// owes %@
    public static func financeOwesAmount(_ a0: String) -> LocalizedStringResource {
        r("finance_owes_amount", "owes \(a0)")
    }

    /// Needs paying
    public static var financeBillsDueTitle: LocalizedStringResource {
        r("finance_bills_due_title", "Needs paying")
    }

    /// Coming up
    public static var financeBillsUpcomingTitle: LocalizedStringResource {
        r("finance_bills_upcoming_title", "Coming up")
    }

    /// Committed each month
    public static var financeCommittedMonthly: LocalizedStringResource {
        r("finance_committed_monthly", "Committed each month")
    }

    /// Nothing due
    public static var financeNothingDue: LocalizedStringResource {
        r("finance_nothing_due", "Nothing due")
    }

    /// Due today
    public static var financeDueToday: LocalizedStringResource {
        r("finance_due_today", "Due today")
    }

    /// Mark paid
    public static var financeMarkPaid: LocalizedStringResource {
        r("finance_mark_paid", "Mark paid")
    }

    /// Pay %@ now
    public static func financePayNow(_ a0: String) -> LocalizedStringResource {
        r("finance_pay_now", "Pay \(a0) now")
    }

    /// Pay
    public static var financePayAction: LocalizedStringResource {
        r("finance_pay_action", "Pay")
    }

    /// Budgets
    public static var financeBudgetsTitle: LocalizedStringResource {
        r("finance_budgets_title", "Budgets")
    }

    /// %@ left
    public static func financeBudgetLeft(_ a0: String) -> LocalizedStringResource {
        r("finance_budget_left", "\(a0) left")
    }

    /// %@ over
    public static func financeBudgetOverBy(_ a0: String) -> LocalizedStringResource {
        r("finance_budget_over_by", "\(a0) over")
    }

    /// %@ of %@
    public static func financeBudgetSpentOf(_ a0: String, _ a1: String) -> LocalizedStringResource {
        r("finance_budget_spent_of", "\(a0) of \(a1)")
    }

    /// A monthly ceiling for this category.
    public static var financeBudgetHint: LocalizedStringResource {
        r("finance_budget_hint", "A monthly ceiling for this category.")
    }

    /// Add expense
    public static var financeAddExpense: LocalizedStringResource {
        r("finance_add_expense", "Add expense")
    }

    /// Add bill
    public static var financeAddBill: LocalizedStringResource {
        r("finance_add_bill", "Add bill")
    }

    /// Set a budget
    public static var financeAddBudget: LocalizedStringResource {
        r("finance_add_budget", "Set a budget")
    }

    /// Add the first one
    public static var financeAddFirstExpense: LocalizedStringResource {
        r("finance_add_first_expense", "Add the first one")
    }

    /// Edit expense
    public static var financeEditExpenseTitle: LocalizedStringResource {
        r("finance_edit_expense_title", "Edit expense")
    }

    /// Edit bill
    public static var financeEditBillTitle: LocalizedStringResource {
        r("finance_edit_bill_title", "Edit bill")
    }

    /// Edit budget
    public static var financeEditBudgetTitle: LocalizedStringResource {
        r("finance_edit_budget_title", "Edit budget")
    }

    /// Delete expense
    public static var financeDeleteExpense: LocalizedStringResource {
        r("finance_delete_expense", "Delete expense")
    }

    /// Delete bill
    public static var financeDeleteBill: LocalizedStringResource {
        r("finance_delete_bill", "Delete bill")
    }

    /// Remove budget
    public static var financeRemoveBudget: LocalizedStringResource {
        r("finance_remove_budget", "Remove budget")
    }

    /// Delete this bill?
    public static var financeDeleteBillTitle: LocalizedStringResource {
        r("finance_delete_bill_title", "Delete this bill?")
    }

    /// The schedule goes. Everything already paid stays in the ledger.
    public static var financeDeleteBillMessage: LocalizedStringResource {
        r("finance_delete_bill_message", "The schedule goes. Everything already paid stays in the ledger.")
    }

    /// Deleted “%@”
    public static func financeExpenseDeleted(_ a0: String) -> LocalizedStringResource {
        r("finance_expense_deleted", "Deleted “\(a0)”")
    }

    /// Amount
    public static var financeAmountLabel: LocalizedStringResource {
        r("finance_amount_label", "Amount")
    }

    /// What was it for?
    public static var financeTitlePlaceholder: LocalizedStringResource {
        r("finance_title_placeholder", "What was it for?")
    }

    /// Rent, power, internet…
    public static var financeBillTitlePlaceholder: LocalizedStringResource {
        r("finance_bill_title_placeholder", "Rent, power, internet…")
    }

    /// Add a note
    public static var financeNotePlaceholder: LocalizedStringResource {
        r("finance_note_placeholder", "Add a note")
    }

    /// Category
    public static var financeCategoryLabel: LocalizedStringResource {
        r("finance_category_label", "Category")
    }

    /// Paid by
    public static var financePaidByLabel: LocalizedStringResource {
        r("finance_paid_by_label", "Paid by")
    }

    /// Paid by %@
    public static func financePaidBy(_ a0: String) -> LocalizedStringResource {
        r("finance_paid_by", "Paid by \(a0)")
    }

    /// Date
    public static var financeDateLabel: LocalizedStringResource {
        r("finance_date_label", "Date")
    }

    /// Repeats
    public static var financeCycleLabel: LocalizedStringResource {
        r("finance_cycle_label", "Repeats")
    }

    /// Next due
    public static var financeDueDateLabel: LocalizedStringResource {
        r("finance_due_date_label", "Next due")
    }

    /// Whose job
    public static var financeResponsibleLabel: LocalizedStringResource {
        r("finance_responsible_label", "Whose job")
    }

    /// Nobody
    public static var financeNobody: LocalizedStringResource {
        r("finance_nobody", "Nobody")
    }

    /// Split with the house
    public static var financeAutoSplitLabel: LocalizedStringResource {
        r("finance_auto_split_label", "Split with the house")
    }

    /// Everyone pays a share
    public static var financeAutoSplitOn: LocalizedStringResource {
        r("finance_auto_split_on", "Everyone pays a share")
    }

    /// One person carries it
    public static var financeAutoSplitOff: LocalizedStringResource {
        r("finance_auto_split_off", "One person carries it")
    }

    /// Equally
    public static var financeSplitEqual: LocalizedStringResource {
        r("finance_split_equal", "Equally")
    }

    /// By shares
    public static var financeSplitShares: LocalizedStringResource {
        r("finance_split_shares", "By shares")
    }

    /// Exact
    public static var financeSplitExact: LocalizedStringResource {
        r("finance_split_exact", "Exact")
    }

    /// Split between
    public static var financeSplitBetween: LocalizedStringResource {
        r("finance_split_between", "Split between")
    }

    /// Everyone
    public static var financeEveryone: LocalizedStringResource {
        r("finance_everyone", "Everyone")
    }

    /// Only me
    public static var financeOnlyMe: LocalizedStringResource {
        r("finance_only_me", "Only me")
    }

    /// Two shares for a couple, one for a lodger.
    public static var financeSharesHint: LocalizedStringResource {
        r("finance_shares_hint", "Two shares for a couple, one for a lodger.")
    }

    /// Left to assign
    public static var financeExactRemaining: LocalizedStringResource {
        r("finance_exact_remaining", "Left to assign")
    }

    /// Full name
    public static var financeFullName: LocalizedStringResource {
        r("finance_full_name", "Full name")
    }

    /// Over by
    public static var financeExactOver: LocalizedStringResource {
        r("finance_exact_over", "Over by")
    }

    /// All assigned
    public static var financeExactBalanced: LocalizedStringResource {
        r("finance_exact_balanced", "All assigned")
    }

    /// The shares are %@ short of the total.
    public static func financeExactOff(_ a0: String) -> LocalizedStringResource {
        r("finance_exact_off", "The shares are \(a0) short of the total.")
    }

    /// The shares come to %@ more than the total.
    public static func financeExactOffOver(_ a0: String) -> LocalizedStringResource {
        r("finance_exact_off_over", "The shares come to \(a0) more than the total.")
    }

    /// That is as long as an amount can be.
    public static var financeAmountLimit: LocalizedStringResource {
        r("finance_amount_limit", "That is as long as an amount can be.")
    }

    /// Search expenses
    public static var financeSearchPlaceholder: LocalizedStringResource {
        r("finance_search_placeholder", "Search expenses")
    }

    /// Filtered total
    public static var financeFilteredTotal: LocalizedStringResource {
        r("finance_filtered_total", "Filtered total")
    }

    /// This month
    public static var financeMonthTotal: LocalizedStringResource {
        r("finance_month_total", "This month")
    }

    /// Today
    public static var financeToday: LocalizedStringResource {
        r("finance_today", "Today")
    }

    /// From a bill
    public static var financeFromBill: LocalizedStringResource {
        r("finance_from_bill", "From a bill")
    }

    /// You lent %@
    public static func financeYouLent(_ a0: String) -> LocalizedStringResource {
        r("finance_you_lent", "You lent \(a0)")
    }

    /// You owe %@
    public static func financeYouBorrowed(_ a0: String) -> LocalizedStringResource {
        r("finance_you_borrowed", "You owe \(a0)")
    }

    /// Previous month
    public static var financePreviousMonth: LocalizedStringResource {
        r("finance_previous_month", "Previous month")
    }

    /// Next month
    public static var financeNextMonth: LocalizedStringResource {
        r("finance_next_month", "Next month")
    }

    /// Back to this month
    public static var financeBackToThisMonth: LocalizedStringResource {
        r("finance_back_to_this_month", "Back to this month")
    }

    /// No money tracked yet
    public static var financeEmptyTitle: LocalizedStringResource {
        r("finance_empty_title", "No money tracked yet")
    }

    /// Add an expense and the household ledger starts here.
    public static var financeEmptyMessage: LocalizedStringResource {
        r("finance_empty_message", "Add an expense and the household ledger starts here.")
    }

    /// Nothing this month
    public static var financeNoExpensesTitle: LocalizedStringResource {
        r("finance_no_expenses_title", "Nothing this month")
    }

    /// Nothing has been spent in this month yet.
    public static var financeNoExpensesMessage: LocalizedStringResource {
        r("finance_no_expenses_message", "Nothing has been spent in this month yet.")
    }

    /// No matches
    public static var financeNoMatchesTitle: LocalizedStringResource {
        r("finance_no_matches_title", "No matches")
    }

    /// Try a different search, or clear the filter.
    public static var financeNoMatchesMessage: LocalizedStringResource {
        r("finance_no_matches_message", "Try a different search, or clear the filter.")
    }

    /// No bills yet
    public static var financeNoBillsTitle: LocalizedStringResource {
        r("finance_no_bills_title", "No bills yet")
    }

    /// Add the rent, the power, the subscription nobody admits to.
    public static var financeNoBillsMessage: LocalizedStringResource {
        r("finance_no_bills_message", "Add the rent, the power, the subscription nobody admits to.")
    }

    /// No budgets yet
    public static var financeNoBudgetsTitle: LocalizedStringResource {
        r("finance_no_budgets_title", "No budgets yet")
    }

    /// Set a monthly ceiling and watch it fill.
    public static var financeNoBudgetsMessage: LocalizedStringResource {
        r("finance_no_budgets_message", "Set a monthly ceiling and watch it fill.")
    }

    /// Suggested payments
    public static var financeSuggestedTitle: LocalizedStringResource {
        r("finance_suggested_title", "Suggested payments")
    }

    /// The fewest payments that clear everything
    public static var financeSuggestedSubtitle: LocalizedStringResource {
        r("finance_suggested_subtitle", "The fewest payments that clear everything")
    }

    /// %@ pays %@
    public static func financeTransferLine(_ a0: String, _ a1: String) -> LocalizedStringResource {
        r("finance_transfer_line", "\(a0) pays \(a1)")
    }

    /// From
    public static var financeFromLabel: LocalizedStringResource {
        r("finance_from_label", "From")
    }

    /// To
    public static var financeToLabel: LocalizedStringResource {
        r("finance_to_label", "To")
    }

    /// Swap direction
    public static var financeSwapDirection: LocalizedStringResource {
        r("finance_swap_direction", "Swap direction")
    }

    /// Record payment
    public static var financeRecordPayment: LocalizedStringResource {
        r("finance_record_payment", "Record payment")
    }

    /// Each of you pays
    public static var financeEachPays: LocalizedStringResource {
        r("finance_each_pays", "Each of you pays")
    }

    /// %@ more than usual
    public static func financeMoreThanUsual(_ a0: String) -> LocalizedStringResource {
        r("finance_more_than_usual", "\(a0) more than usual")
    }

    /// %@ less than usual
    public static func financeLessThanUsual(_ a0: String) -> LocalizedStringResource {
        r("finance_less_than_usual", "\(a0) less than usual")
    }

    /// A one-off is finished once it’s paid.
    public static var financePayOnceHint: LocalizedStringResource {
        r("finance_pay_once_hint", "A one-off is finished once it’s paid.")
    }

    /// Logs the expense and moves the bill to its next date.
    public static var financePayRecurringHint: LocalizedStringResource {
        r("finance_pay_recurring_hint", "Logs the expense and moves the bill to its next date.")
    }

    /// Give it a name first.
    public static var financeErrorTitle: LocalizedStringResource {
        r("finance_error_title", "Give it a name first.")
    }

    /// Enter an amount above zero.
    public static var financeErrorAmount: LocalizedStringResource {
        r("finance_error_amount", "Enter an amount above zero.")
    }

    /// Choose who this is split between.
    public static var financeErrorParticipants: LocalizedStringResource {
        r("finance_error_participants", "Choose who this is split between.")
    }

    /// Give at least one person a share.
    public static var financeErrorShares: LocalizedStringResource {
        r("finance_error_shares", "Give at least one person a share.")
    }

    /// The shares add up to %@, not %@.
    public static func financeErrorExactMismatch(_ a0: String, _ a1: String) -> LocalizedStringResource {
        r("finance_error_exact_mismatch", "The shares add up to \(a0), not \(a1).")
    }

    /// Groceries
    public static var financeCategoryGroceries: LocalizedStringResource {
        r("finance_category_groceries", "Groceries")
    }

    /// Utilities
    public static var financeCategoryUtilities: LocalizedStringResource {
        r("finance_category_utilities", "Utilities")
    }

    /// Rent
    public static var financeCategoryRent: LocalizedStringResource {
        r("finance_category_rent", "Rent")
    }

    /// Household
    public static var financeCategoryHousehold: LocalizedStringResource {
        r("finance_category_household", "Household")
    }

    /// Eating out
    public static var financeCategoryDining: LocalizedStringResource {
        r("finance_category_dining", "Eating out")
    }

    /// Transport
    public static var financeCategoryTransport: LocalizedStringResource {
        r("finance_category_transport", "Transport")
    }

    /// Health
    public static var financeCategoryHealth: LocalizedStringResource {
        r("finance_category_health", "Health")
    }

    /// Fun
    public static var financeCategoryEntertainment: LocalizedStringResource {
        r("finance_category_entertainment", "Fun")
    }

    /// Subscriptions
    public static var financeCategorySubscriptions: LocalizedStringResource {
        r("finance_category_subscriptions", "Subscriptions")
    }

    /// Other
    public static var financeCategoryOther: LocalizedStringResource {
        r("finance_category_other", "Other")
    }

    /// One-off
    public static var financeCycleOnce: LocalizedStringResource {
        r("finance_cycle_once", "One-off")
    }

    /// Weekly
    public static var financeCycleWeekly: LocalizedStringResource {
        r("finance_cycle_weekly", "Weekly")
    }

    /// Every two weeks
    public static var financeCycleBiweekly: LocalizedStringResource {
        r("finance_cycle_biweekly", "Every two weeks")
    }

    /// Monthly
    public static var financeCycleMonthly: LocalizedStringResource {
        r("finance_cycle_monthly", "Monthly")
    }

    /// Every three months
    public static var financeCycleQuarterly: LocalizedStringResource {
        r("finance_cycle_quarterly", "Every three months")
    }

    /// Yearly
    public static var financeCycleYearly: LocalizedStringResource {
        r("finance_cycle_yearly", "Yearly")
    }

    /// %d expenses
    public static func financeExpenseCount(_ a0: Int) -> LocalizedStringResource {
        r("finance_expense_count", "\(a0) expenses")
    }

    /// %d overdue
    public static func financeOverdueCount(_ a0: Int) -> LocalizedStringResource {
        r("finance_overdue_count", "\(a0) overdue")
    }

    /// %d due soon
    public static func financeDueSoonCount(_ a0: Int) -> LocalizedStringResource {
        r("finance_due_soon_count", "\(a0) due soon")
    }

    /// Due in %d days
    public static func financeDueIn(_ a0: Int) -> LocalizedStringResource {
        r("finance_due_in", "Due in \(a0) days")
    }

    /// %d days late
    public static func financeOverdueBy(_ a0: Int) -> LocalizedStringResource {
        r("finance_overdue_by", "\(a0) days late")
    }

    /// Currency
    public static var financeCurrencyLabel: LocalizedStringResource {
        r("finance_currency_label", "Currency")
    }

    /// Shares for %@
    public static func financeSharesFor(_ a0: String) -> LocalizedStringResource {
        r("finance_shares_for", "Shares for \(a0)")
    }

    /// Remind the house
    public static var financeRemindersLabel: LocalizedStringResource {
        r("finance_reminders_label", "Remind the house")
    }

    /// Up to three nudges before it is due.
    public static var financeRemindersHint: LocalizedStringResource {
        r("finance_reminders_hint", "Up to three nudges before it is due.")
    }

    /// On the day
    public static var financeReminderOnDay: LocalizedStringResource {
        r("finance_reminder_on_day", "On the day")
    }

    /// A week before
    public static var financeReminderWeekBefore: LocalizedStringResource {
        r("finance_reminder_week_before", "A week before")
    }

    /// No reminders
    public static var financeRemindersOff: LocalizedStringResource {
        r("finance_reminders_off", "No reminders")
    }

    /// %d days before
    public static func financeReminderDaysBefore(_ a0: Int) -> LocalizedStringResource {
        r("finance_reminder_days_before", "\(a0) days before")
    }

    /// %d reminders
    public static func financeReminderCount(_ a0: Int) -> LocalizedStringResource {
        r("finance_reminder_count", "\(a0) reminders")
    }

    // MARK: - Calendar & Events

    /// More
    public static var commonMore: LocalizedStringResource {
        r("common_more", "More")
    }

    /// For %@
    public static func shoppingForEvent(_ a0: String) -> LocalizedStringResource {
        r("shopping_for_event", "For \(a0)")
    }

    /// Month
    public static var calendarModeMonth: LocalizedStringResource {
        r("calendar_mode_month", "Month")
    }

    /// Week
    public static var calendarModeWeek: LocalizedStringResource {
        r("calendar_mode_week", "Week")
    }

    /// Agenda
    public static var calendarModeAgenda: LocalizedStringResource {
        r("calendar_mode_agenda", "Agenda")
    }

    /// Previous month
    public static var calendarPreviousMonth: LocalizedStringResource {
        r("calendar_previous_month", "Previous month")
    }

    /// Next month
    public static var calendarNextMonth: LocalizedStringResource {
        r("calendar_next_month", "Next month")
    }

    /// Jump to today
    public static var calendarJumpToToday: LocalizedStringResource {
        r("calendar_jump_to_today", "Jump to today")
    }

    /// Search events
    public static var calendarSearchPlaceholder: LocalizedStringResource {
        r("calendar_search_placeholder", "Search events")
    }

    /// Just mine
    public static var calendarOnlyMine: LocalizedStringResource {
        r("calendar_only_mine", "Just mine")
    }

    /// Today
    public static var calendarToday: LocalizedStringResource {
        r("calendar_today", "Today")
    }

    /// Tomorrow
    public static var calendarTomorrowLabel: LocalizedStringResource {
        r("calendar_tomorrow_label", "Tomorrow")
    }

    /// Yesterday
    public static var calendarYesterday: LocalizedStringResource {
        r("calendar_yesterday", "Yesterday")
    }

    /// All day
    public static var calendarAllDay: LocalizedStringResource {
        r("calendar_all_day", "All day")
    }

    /// Nothing on
    public static var calendarNothingOn: LocalizedStringResource {
        r("calendar_nothing_on", "Nothing on")
    }

    /// Nothing matches that
    public static var calendarNoMatches: LocalizedStringResource {
        r("calendar_no_matches", "Nothing matches that")
    }

    /// %lld scheduled
    public static func calendarEventCount(_ a0: Int) -> LocalizedStringResource {
        r("calendar_event_count", "\(a0) scheduled")
    }

    /// Next up
    public static var calendarNextUp: LocalizedStringResource {
        r("calendar_next_up", "Next up")
    }

    /// Happening now
    public static var calendarHappeningNow: LocalizedStringResource {
        r("calendar_happening_now", "Happening now")
    }

    /// Starting now
    public static var calendarStartingNow: LocalizedStringResource {
        r("calendar_starting_now", "Starting now")
    }

    /// Tomorrow
    public static var calendarTomorrow: LocalizedStringResource {
        r("calendar_tomorrow", "Tomorrow")
    }

    /// in %lld min
    public static func calendarInMinutes(_ a0: Int) -> LocalizedStringResource {
        r("calendar_in_minutes", "in \(a0) min")
    }

    /// in %lld h
    public static func calendarInHours(_ a0: Int) -> LocalizedStringResource {
        r("calendar_in_hours", "in \(a0) h")
    }

    /// in %lld days
    public static func calendarInDays(_ a0: Int) -> LocalizedStringResource {
        r("calendar_in_days", "in \(a0) days")
    }

    /// in %lld months
    public static func calendarInMonths(_ a0: Int) -> LocalizedStringResource {
        r("calendar_in_months", "in \(a0) months")
    }

    /// Nothing planned yet
    public static var calendarEmptyTitle: LocalizedStringResource {
        r("calendar_empty_title", "Nothing planned yet")
    }

    /// Add a dinner, a birthday, a concert — anything the house should know about.
    public static var calendarEmptyMessage: LocalizedStringResource {
        r("calendar_empty_message", "Add a dinner, a birthday, a concert — anything the house should know about.")
    }

    /// Add an event
    public static var calendarAddFirstEvent: LocalizedStringResource {
        r("calendar_add_first_event", "Add an event")
    }

    /// Deleted %@
    public static func calendarEventDeleted(_ a0: String) -> LocalizedStringResource {
        r("calendar_event_deleted", "Deleted \(a0)")
    }

    /// Someone
    public static var calendarSomeone: LocalizedStringResource {
        r("calendar_someone", "Someone")
    }

    /// Event
    public static var calendarKindGeneral: LocalizedStringResource {
        r("calendar_kind_general", "Event")
    }

    /// House party
    public static var calendarKindHouseParty: LocalizedStringResource {
        r("calendar_kind_house_party", "House party")
    }

    /// Dinner party
    public static var calendarKindDinnerParty: LocalizedStringResource {
        r("calendar_kind_dinner_party", "Dinner party")
    }

    /// Movie night
    public static var calendarKindMovieNight: LocalizedStringResource {
        r("calendar_kind_movie_night", "Movie night")
    }

    /// Game night
    public static var calendarKindGameNight: LocalizedStringResource {
        r("calendar_kind_game_night", "Game night")
    }

    /// Guests
    public static var calendarKindVisit: LocalizedStringResource {
        r("calendar_kind_visit", "Guests")
    }

    /// Chore
    public static var calendarKindChore: LocalizedStringResource {
        r("calendar_kind_chore", "Chore")
    }

    /// Restaurant
    public static var calendarKindDining: LocalizedStringResource {
        r("calendar_kind_dining", "Restaurant")
    }

    /// Concert
    public static var calendarKindConcert: LocalizedStringResource {
        r("calendar_kind_concert", "Concert")
    }

    /// Cinema
    public static var calendarKindCinema: LocalizedStringResource {
        r("calendar_kind_cinema", "Cinema")
    }

    /// Theatre
    public static var calendarKindTheatre: LocalizedStringResource {
        r("calendar_kind_theatre", "Theatre")
    }

    /// Sports
    public static var calendarKindSports: LocalizedStringResource {
        r("calendar_kind_sports", "Sports")
    }

    /// Picnic
    public static var calendarKindPicnic: LocalizedStringResource {
        r("calendar_kind_picnic", "Picnic")
    }

    /// Trip
    public static var calendarKindTrip: LocalizedStringResource {
        r("calendar_kind_trip", "Trip")
    }

    /// Birthday
    public static var calendarKindBirthday: LocalizedStringResource {
        r("calendar_kind_birthday", "Birthday")
    }

    /// Anniversary
    public static var calendarKindAnniversary: LocalizedStringResource {
        r("calendar_kind_anniversary", "Anniversary")
    }

    /// Holiday
    public static var calendarKindHoliday: LocalizedStringResource {
        r("calendar_kind_holiday", "Holiday")
    }

    /// Appointment
    public static var calendarKindAppointment: LocalizedStringResource {
        r("calendar_kind_appointment", "Appointment")
    }

    /// Deadline
    public static var calendarKindDeadline: LocalizedStringResource {
        r("calendar_kind_deadline", "Deadline")
    }

    /// At home
    public static var calendarGroupAtHome: LocalizedStringResource {
        r("calendar_group_at_home", "At home")
    }

    /// Going out
    public static var calendarGroupGoingOut: LocalizedStringResource {
        r("calendar_group_going_out", "Going out")
    }

    /// Occasions
    public static var calendarGroupOccasions: LocalizedStringResource {
        r("calendar_group_occasions", "Occasions")
    }

    /// Admin
    public static var calendarGroupAdmin: LocalizedStringResource {
        r("calendar_group_admin", "Admin")
    }

    /// Going
    public static var calendarRsvpGoing: LocalizedStringResource {
        r("calendar_rsvp_going", "Going")
    }

    /// Maybe
    public static var calendarRsvpMaybe: LocalizedStringResource {
        r("calendar_rsvp_maybe", "Maybe")
    }

    /// Can't
    public static var calendarRsvpDeclined: LocalizedStringResource {
        r("calendar_rsvp_declined", "Can't")
    }

    /// Are you coming?
    public static var calendarAreYouComing: LocalizedStringResource {
        r("calendar_are_you_coming", "Are you coming?")
    }

    /// Who's coming
    public static var calendarWhoIsComing: LocalizedStringResource {
        r("calendar_who_is_coming", "Who's coming")
    }

    /// No answer yet
    public static var calendarNoAnswer: LocalizedStringResource {
        r("calendar_no_answer", "No answer yet")
    }

    /// Everyone
    public static var calendarEveryone: LocalizedStringResource {
        r("calendar_everyone", "Everyone")
    }

    /// Clear
    public static var calendarClearAll: LocalizedStringResource {
        r("calendar_clear_all", "Clear")
    }

    /// New event
    public static var calendarAddEvent: LocalizedStringResource {
        r("calendar_add_event", "New event")
    }

    /// Edit event
    public static var calendarEditEvent: LocalizedStringResource {
        r("calendar_edit_event", "Edit event")
    }

    /// What's happening?
    public static var calendarTitlePlaceholder: LocalizedStringResource {
        r("calendar_title_placeholder", "What's happening?")
    }

    /// Notes
    public static var calendarNotesPlaceholder: LocalizedStringResource {
        r("calendar_notes_placeholder", "Notes")
    }

    /// Notes
    public static var calendarNotes: LocalizedStringResource {
        r("calendar_notes", "Notes")
    }

    /// Where?
    public static var calendarLocationPlaceholder: LocalizedStringResource {
        r("calendar_location_placeholder", "Where?")
    }

    /// All day
    public static var calendarAllDayToggle: LocalizedStringResource {
        r("calendar_all_day_toggle", "All day")
    }

    /// Starts
    public static var calendarStarts: LocalizedStringResource {
        r("calendar_starts", "Starts")
    }

    /// Ends
    public static var calendarEnds: LocalizedStringResource {
        r("calendar_ends", "Ends")
    }

    /// Repeats
    public static var calendarRepeats: LocalizedStringResource {
        r("calendar_repeats", "Repeats")
    }

    /// How often
    public static var calendarRepeatFrequency: LocalizedStringResource {
        r("calendar_repeat_frequency", "How often")
    }

    /// Every
    public static var calendarRepeatEvery: LocalizedStringResource {
        r("calendar_repeat_every", "Every")
    }

    /// Stops on a date
    public static var calendarRepeatEnds: LocalizedStringResource {
        r("calendar_repeat_ends", "Stops on a date")
    }

    /// Until
    public static var calendarRepeatUntil: LocalizedStringResource {
        r("calendar_repeat_until", "Until")
    }

    /// Doesn't repeat
    public static var calendarRepeatNever: LocalizedStringResource {
        r("calendar_repeat_never", "Doesn't repeat")
    }

    /// Every day
    public static var calendarRepeatDaily: LocalizedStringResource {
        r("calendar_repeat_daily", "Every day")
    }

    /// Every week
    public static var calendarRepeatWeekly: LocalizedStringResource {
        r("calendar_repeat_weekly", "Every week")
    }

    /// Every month
    public static var calendarRepeatMonthly: LocalizedStringResource {
        r("calendar_repeat_monthly", "Every month")
    }

    /// Every year
    public static var calendarRepeatYearly: LocalizedStringResource {
        r("calendar_repeat_yearly", "Every year")
    }

    /// Every %lld days
    public static func calendarRepeatEveryNDays(_ a0: Int) -> LocalizedStringResource {
        r("calendar_repeat_every_n_days", "Every \(a0) days")
    }

    /// Every %lld weeks
    public static func calendarRepeatEveryNWeeks(_ a0: Int) -> LocalizedStringResource {
        r("calendar_repeat_every_n_weeks", "Every \(a0) weeks")
    }

    /// Every %lld months
    public static func calendarRepeatEveryNMonths(_ a0: Int) -> LocalizedStringResource {
        r("calendar_repeat_every_n_months", "Every \(a0) months")
    }

    /// Every %lld years
    public static func calendarRepeatEveryNYears(_ a0: Int) -> LocalizedStringResource {
        r("calendar_repeat_every_n_years", "Every \(a0) years")
    }

    /// Daily
    public static var calendarFrequencyDaily: LocalizedStringResource {
        r("calendar_frequency_daily", "Daily")
    }

    /// Weekly
    public static var calendarFrequencyWeekly: LocalizedStringResource {
        r("calendar_frequency_weekly", "Weekly")
    }

    /// Monthly
    public static var calendarFrequencyMonthly: LocalizedStringResource {
        r("calendar_frequency_monthly", "Monthly")
    }

    /// Yearly
    public static var calendarFrequencyYearly: LocalizedStringResource {
        r("calendar_frequency_yearly", "Yearly")
    }

    /// Remind the house
    public static var calendarRemindMe: LocalizedStringResource {
        r("calendar_remind_me", "Remind the house")
    }

    /// At the time
    public static var calendarReminderAtTime: LocalizedStringResource {
        r("calendar_reminder_at_time", "At the time")
    }

    /// 10 min before
    public static var calendarReminderTenMinutes: LocalizedStringResource {
        r("calendar_reminder_ten_minutes", "10 min before")
    }

    /// 30 min before
    public static var calendarReminderThirtyMinutes: LocalizedStringResource {
        r("calendar_reminder_thirty_minutes", "30 min before")
    }

    /// 1 hour before
    public static var calendarReminderOneHour: LocalizedStringResource {
        r("calendar_reminder_one_hour", "1 hour before")
    }

    /// 2 hours before
    public static var calendarReminderTwoHours: LocalizedStringResource {
        r("calendar_reminder_two_hours", "2 hours before")
    }

    /// A day before
    public static var calendarReminderOneDay: LocalizedStringResource {
        r("calendar_reminder_one_day", "A day before")
    }

    /// 2 days before
    public static var calendarReminderTwoDays: LocalizedStringResource {
        r("calendar_reminder_two_days", "2 days before")
    }

    /// A week before
    public static var calendarReminderOneWeek: LocalizedStringResource {
        r("calendar_reminder_one_week", "A week before")
    }

    /// Three reminders is the most an event can have.
    public static var calendarReminderLimit: LocalizedStringResource {
        r("calendar_reminder_limit", "Three reminders is the most an event can have.")
    }

    /// The event ends before it starts.
    public static var calendarErrorEndsBeforeStart: LocalizedStringResource {
        r("calendar_error_ends_before_start", "The event ends before it starts.")
    }

    /// Budget
    public static var calendarPlanBudget: LocalizedStringResource {
        r("calendar_plan_budget", "Budget")
    }

    /// Shopping
    public static var calendarPlanShopping: LocalizedStringResource {
        r("calendar_plan_shopping", "Shopping")
    }

    /// Menu
    public static var calendarPlanMenu: LocalizedStringResource {
        r("calendar_plan_menu", "Menu")
    }

    /// Tickets
    public static var calendarPlanTickets: LocalizedStringResource {
        r("calendar_plan_tickets", "Tickets")
    }

    /// Add to the plan
    public static var calendarAddToPlan: LocalizedStringResource {
        r("calendar_add_to_plan", "Add to the plan")
    }

    /// Remove from the plan
    public static var calendarRemoveFromPlan: LocalizedStringResource {
        r("calendar_remove_from_plan", "Remove from the plan")
    }

    /// Anything you log against this event counts towards it.
    public static var calendarBudgetHint: LocalizedStringResource {
        r("calendar_budget_hint", "Anything you log against this event counts towards it.")
    }

    /// Link to the tickets or booking
    public static var calendarTicketsPlaceholder: LocalizedStringResource {
        r("calendar_tickets_placeholder", "Link to the tickets or booking")
    }

    /// Kept here so nobody has to scroll back through the chat for it.
    public static var calendarTicketsHint: LocalizedStringResource {
        r("calendar_tickets_hint", "Kept here so nobody has to scroll back through the chat for it.")
    }

    /// Nothing on the menu yet.
    public static var calendarMenuEmpty: LocalizedStringResource {
        r("calendar_menu_empty", "Nothing on the menu yet.")
    }

    /// Pick recipes
    public static var calendarPickRecipes: LocalizedStringResource {
        r("calendar_pick_recipes", "Pick recipes")
    }

    /// Edit the menu
    public static var calendarEditMenu: LocalizedStringResource {
        r("calendar_edit_menu", "Edit the menu")
    }

    /// Search recipes
    public static var calendarSearchRecipes: LocalizedStringResource {
        r("calendar_search_recipes", "Search recipes")
    }

    /// No recipes yet
    public static var calendarNoRecipes: LocalizedStringResource {
        r("calendar_no_recipes", "No recipes yet")
    }

    /// Save a recipe first and it'll show up here.
    public static var calendarNoRecipesMessage: LocalizedStringResource {
        r("calendar_no_recipes_message", "Save a recipe first and it'll show up here.")
    }

    /// %lld recipes · %lld ingredients
    public static func calendarMenuSummary(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("calendar_menu_summary", "\(a0) recipes · \(a1) ingredients")
    }

    /// %lld ingredients
    public static func calendarIngredientCount(_ a0: Int) -> LocalizedStringResource {
        r("calendar_ingredient_count", "\(a0) ingredients")
    }

    /// %lld min
    public static func calendarMinutes(_ a0: Int) -> LocalizedStringResource {
        r("calendar_minutes", "\(a0) min")
    }

    /// Serves %lld
    public static func calendarServes(_ a0: Int) -> LocalizedStringResource {
        r("calendar_serves", "Serves \(a0)")
    }

    /// Send it all to the shopping list
    public static var calendarStockUp: LocalizedStringResource {
        r("calendar_stock_up", "Send it all to the shopping list")
    }

    /// Top up the shopping list
    public static var calendarStockUpAgain: LocalizedStringResource {
        r("calendar_stock_up_again", "Top up the shopping list")
    }

    /// %lld added to the list
    public static func calendarItemsAdded(_ a0: Int) -> LocalizedStringResource {
        r("calendar_items_added", "\(a0) added to the list")
    }

    /// %lld added · %lld already listed
    public static func calendarItemsAddedSkipped(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("calendar_items_added_skipped", "\(a0) added · \(a1) already listed")
    }

    /// Everything's already on the list.
    public static var calendarAllAlreadyListed: LocalizedStringResource {
        r("calendar_all_already_listed", "Everything's already on the list.")
    }

    /// %lld of %lld bought
    public static func calendarBoughtOf(_ a0: Int, _ a1: Int) -> LocalizedStringResource {
        r("calendar_bought_of", "\(a0) of \(a1) bought")
    }

    /// Add something to buy
    public static var calendarAddItemPlaceholder: LocalizedStringResource {
        r("calendar_add_item_placeholder", "Add something to buy")
    }

    /// +%lld more items
    public static func calendarMoreItems(_ a0: Int) -> LocalizedStringResource {
        r("calendar_more_items", "+\(a0) more items")
    }

    /// +%lld more
    public static func calendarMoreExpenses(_ a0: Int) -> LocalizedStringResource {
        r("calendar_more_expenses", "+\(a0) more")
    }

    /// Log what it cost
    public static var calendarLogSpend: LocalizedStringResource {
        r("calendar_log_spend", "Log what it cost")
    }

    /// of %@
    public static func calendarOfBudget(_ a0: String) -> LocalizedStringResource {
        r("calendar_of_budget", "of \(a0)")
    }

    /// %@ over
    public static func calendarOverBudget(_ a0: String) -> LocalizedStringResource {
        r("calendar_over_budget", "\(a0) over")
    }

    /// %@ left
    public static func calendarLeftToSpend(_ a0: String) -> LocalizedStringResource {
        r("calendar_left_to_spend", "\(a0) left")
    }

    /// Some of this was paid in another currency and isn't in the total.
    public static var calendarMixedCurrencies: LocalizedStringResource {
        r("calendar_mixed_currencies", "Some of this was paid in another currency and isn't in the total.")
    }

    /// Plan it out
    public static var calendarPlanInvitation: LocalizedStringResource {
        r("calendar_plan_invitation", "Plan it out")
    }

    /// Give it a budget, a menu, a shopping list or a ticket link — the house can see all of it.
    public static var calendarPlanInvitationMessage: LocalizedStringResource {
        r("calendar_plan_invitation_message", "Give it a budget, a menu, a shopping list or a ticket link — the house can see all of it.")
    }

    /// This event repeats
    public static var calendarScopeEditTitle: LocalizedStringResource {
        r("calendar_scope_edit_title", "This event repeats")
    }

    /// Change just this one, or every one of them?
    public static var calendarScopeEditMessage: LocalizedStringResource {
        r("calendar_scope_edit_message", "Change just this one, or every one of them?")
    }

    /// This event repeats
    public static var calendarScopeDeleteTitle: LocalizedStringResource {
        r("calendar_scope_delete_title", "This event repeats")
    }

    /// Delete just this one, or every one of them?
    public static var calendarScopeDeleteMessage: LocalizedStringResource {
        r("calendar_scope_delete_message", "Delete just this one, or every one of them?")
    }

    /// Just this one
    public static var calendarScopeThisEvent: LocalizedStringResource {
        r("calendar_scope_this_event", "Just this one")
    }

    /// All of them
    public static var calendarScopeAllEvents: LocalizedStringResource {
        r("calendar_scope_all_events", "All of them")
    }

    /// Skip this one
    public static var calendarSkipThisOne: LocalizedStringResource {
        r("calendar_skip_this_one", "Skip this one")
    }

    /// Delete every one
    public static var calendarDeleteSeries: LocalizedStringResource {
        r("calendar_delete_series", "Delete every one")
    }

    /// Delete event
    public static var calendarDeleteEvent: LocalizedStringResource {
        r("calendar_delete_event", "Delete event")
    }

    /// Delete this event…
    public static var calendarDeleteEventRepeating: LocalizedStringResource {
        r("calendar_delete_event_repeating", "Delete this event…")
    }

    /// Your recipes
    public static var calendarYourRecipes: LocalizedStringResource {
        r("calendar_your_recipes", "Your recipes")
    }

    /// Explore
    public static var calendarExploreRecipes: LocalizedStringResource {
        r("calendar_explore_recipes", "Explore")
    }

    /// %lld will be saved to your recipes
    public static func calendarWillSaveToHome(_ a0: Int) -> LocalizedStringResource {
        r("calendar_will_save_to_home", "\(a0) will be saved to your recipes")
    }

    /// These land on the household's shopping list, tagged for this event.
    public static var calendarShoppingHint: LocalizedStringResource {
        r("calendar_shopping_hint", "These land on the household's shopping list, tagged for this event.")
    }

    /// Extras only — the menu's ingredients are one tap away once this is saved.
    public static var calendarShoppingHintWithMenu: LocalizedStringResource {
        r("calendar_shopping_hint_with_menu", "Extras only — the menu's ingredients are one tap away once this is saved.")
    }

    /// Nothing to buy yet
    public static var calendarNothingToBuyYet: LocalizedStringResource {
        r("calendar_nothing_to_buy_yet", "Nothing to buy yet")
    }

    /// Events
    public static var homeStatsEventsTitle: LocalizedStringResource {
        r("home_stats_events_title", "Events")
    }

    /// Now
    public static var calendarNowBadge: LocalizedStringResource {
        r("calendar_now_badge", "Now")
    }

    /// Up next
    public static var homeUpNextTitle: LocalizedStringResource {
        r("home_up_next_title", "Up next")
    }

    /// Make it dinner that day
    public static var calendarMakeItDinner: LocalizedStringResource {
        r("calendar_make_it_dinner", "Make it dinner that day")
    }

    /// This is dinner that day
    public static var calendarIsDinner: LocalizedStringResource {
        r("calendar_is_dinner", "This is dinner that day")
    }

    /// Make it an occasion
    public static var dinnerMakeItAnOccasion: LocalizedStringResource {
        r("dinner_make_it_an_occasion", "Make it an occasion")
    }

    /// Adds it to the calendar with a menu, so it can carry a shopping list and a budget.
    public static var dinnerMakeItAnOccasionHint: LocalizedStringResource {
        r("dinner_make_it_an_occasion_hint", "Adds it to the calendar with a menu, so it can carry a shopping list and a budget.")
    }

    /// Dinner
    public static var dinnerOccasionFallbackTitle: LocalizedStringResource {
        r("dinner_occasion_fallback_title", "Dinner")
    }

    /// Part of %@
    public static func homeTonightPartOf(_ a0: String) -> LocalizedStringResource {
        r("home_tonight_part_of", "Part of \(a0)")
    }

    /// Starts at
    public static var dinnerOccasionStarts: LocalizedStringResource {
        r("dinner_occasion_starts", "Starts at")
    }

    /// Make an evening of it
    public static var dinnerMakeAnEveningOfIt: LocalizedStringResource {
        r("dinner_make_an_evening_of_it", "Make an evening of it")
    }
}
