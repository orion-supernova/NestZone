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
}
