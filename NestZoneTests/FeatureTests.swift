import ComposableArchitecture
import Foundation
import Testing
@testable import NestZone

/// Reducer behaviour, driven through `TestStore` with stubbed clients.
@MainActor
@Suite("Home tab")
struct HomeFeatureTests {

    @Test("Ticking a task updates the row before the server answers")
    func optimisticToggle() async {
        let task = HouseTask(id: "t1", title: "Dishes")
        let confirmed = LockIsolated<[(TaskID, Bool)]>([])

        let store = TestStore(
            initialState: HomeFeature.State(homeID: "h1")
        ) {
            HomeFeature()
        } withDependencies: {
            $0.tasks.setCompleted = { id, done in
                confirmed.withValue { $0.append((id, done)) }
            }
        }

        await store.send(.tasksUpdated([task])) {
            $0.isLoading = false
            $0.tasks = [task]
        }

        await store.send(.taskToggled("t1")) {
            $0.tasks[id: "t1"]?.isCompleted = true
        }

        #expect(confirmed.value.count == 1)
        #expect(confirmed.value[0].1 == true)
    }

    @Test("A failed toggle is not rolled back by hand — the stream corrects it")
    func failedToggleShowsAlert() async {
        let task = HouseTask(id: "t1", title: "Dishes")
        let store = TestStore(
            initialState: HomeFeature.State(homeID: "h1")
        ) {
            HomeFeature()
        } withDependencies: {
            $0.tasks.setCompleted = { _, _ in throw AppError.offline }
        }

        await store.send(.tasksUpdated([task])) {
            $0.isLoading = false
            $0.tasks = [task]
        }
        await store.send(.taskToggled("t1")) {
            $0.tasks[id: "t1"]?.isCompleted = true
        }
        await store.receive(\.toggleFailed) {
            $0.alert = .failure(.offline)
        }
    }

    @Test("Cancellation never reaches the user as an alert")
    func cancellationIsSilent() async {
        let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
            HomeFeature()
        }
        await store.send(.loadFailed(.cancelled)) {
            $0.isLoading = false
        }
        #expect(store.state.alert == nil)
    }

    @Test("Only the five most recent tasks reach the summary")
    func recentTasksAreCapped() async {
        let tasks = (1...8).map {
            HouseTask(
                id: TaskID("t\($0)"),
                title: "Task \($0)",
                created: Timestamp(milliseconds: Double($0) * 1000)
            )
        }
        let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
            HomeFeature()
        }
        await store.send(.tasksUpdated(tasks)) {
            $0.isLoading = false
            $0.tasks = IdentifiedArray(uniqueElements: tasks)
        }
        #expect(store.state.recentTasks.count == 5)
        // Newest first.
        #expect(store.state.recentTasks.first?.id == TaskID("t8"))
    }
}

@MainActor
@Suite("Home selection")
struct HomeManagementTests {

    @Test("A single home is opened without asking")
    func singleHomeAutoSelects() async {
        let home = Home(id: "h1", name: "The Nest")
        let store = TestStore(initialState: HomeManagementFeature.State()) {
            HomeManagementFeature()
        }
        await store.send(.homesUpdated([home])) {
            $0.isLoading = false
            $0.homes = [home]
            $0.$selectedHomeIDRaw.withLock { $0 = "h1" }
        }
    }

    @Test("Several homes wait for a choice")
    func multipleHomesRequireAChoice() async {
        let homes = [Home(id: "h1", name: "A"), Home(id: "h2", name: "B")]
        let store = TestStore(initialState: HomeManagementFeature.State()) {
            HomeManagementFeature()
        }
        await store.send(.homesUpdated(homes)) {
            $0.isLoading = false
            $0.homes = IdentifiedArray(uniqueElements: homes)
        }
        #expect(store.state.$selectedHomeIDRaw.homeID == nil)
    }

    @Test("A selection pointing at a home you no longer belong to is dropped")
    func staleSelectionIsCleared() async {
        let state = HomeManagementFeature.State()
        state.$selectedHomeIDRaw.withLock { $0 = "gone" }

        let remaining = [Home(id: "h1", name: "A"), Home(id: "h2", name: "B")]
        let store = TestStore(initialState: state) { HomeManagementFeature() }

        await store.send(.homesUpdated(remaining)) {
            $0.isLoading = false
            $0.homes = IdentifiedArray(uniqueElements: remaining)
            $0.$selectedHomeIDRaw.withLock { $0 = nil }
        }
    }

    @Test("Leaving as the last member warns that the home will be deleted")
    func lastMemberSeesDeleteWording() async {
        let home = Home(id: "h1", name: "The Nest", members: ["me"])
        let store = TestStore(initialState: HomeManagementFeature.State()) {
            HomeManagementFeature()
        }
        await store.send(.homesUpdated([home])) {
            $0.isLoading = false
            $0.homes = [home]
            $0.$selectedHomeIDRaw.withLock { $0 = "h1" }
        }
        await store.send(.leaveTapped("h1")) {
            $0.alert = .confirmLeave(home, isSoleMember: true, confirm: .confirmLeave("h1"))
        }
    }
}

@MainActor
@Suite("Manage homes")
struct ManageHomesTests {

    static let nest = Home(id: "h1", name: "The Nest", members: ["me", "you"])
    static let cabin = Home(id: "h2", name: "The Cabin", members: ["me"])

    @Test("Picking another home asks the parent to switch instead of clearing the selection")
    func switchingDelegatesUpwards() async {
        let store = TestStore(
            initialState: ManageHomesFeature.State(
                homes: [Self.nest, Self.cabin], currentHomeID: "h1"
            )
        ) {
            ManageHomesFeature()
        }

        await store.send(.homeTapped("h2"))
        await store.receive(\.delegate.switchRequested)
    }

    @Test("Tapping the home already open just closes the sheet")
    func tappingTheOpenHomeDismisses() async {
        let store = TestStore(
            initialState: ManageHomesFeature.State(homes: [Self.nest], currentHomeID: "h1")
        ) {
            ManageHomesFeature()
        }

        await store.send(.homeTapped("h1"))
        await store.receive(\.delegate.dismissRequested)
    }

    @Test("Leaving as the last member warns that the home will be deleted, then deletes it")
    func leavingAsksFirst() async {
        let left = LockIsolated<[HomeID]>([])
        let store = TestStore(
            initialState: ManageHomesFeature.State(
                homes: [Self.nest, Self.cabin], currentHomeID: "h1"
            )
        ) {
            ManageHomesFeature()
        } withDependencies: {
            $0.homes.leave = { id in left.withValue { $0.append(id) } }
        }

        await store.send(.leaveTapped("h2")) {
            $0.alert = .confirmLeave(Self.cabin, isSoleMember: true, confirm: .confirmLeave("h2"))
        }
        #expect(left.value.isEmpty)

        await store.send(.alert(.presented(.confirmLeave("h2")))) {
            $0.alert = nil
            $0.leavingID = "h2"
            $0.homes.remove(id: "h2")
        }
        await store.receive(\.leaveFinished) {
            $0.leavingID = nil
        }
        #expect(left.value == ["h2"])
    }
}

@MainActor
@Suite("Settings home management")
struct SettingsHomeTests {

    @Test("A single home still opens the manage sheet — it is the only way out of a home")
    func oneHomeStillManages() async {
        var state = SettingsFeature.State(homeID: "h1", home: ManageHomesTests.nest)
        state.applyHomes([ManageHomesTests.nest])

        let store = TestStore(initialState: state) { SettingsFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        #expect(store.state.hasMultipleHomes == false)
        await store.send(.manageHomesTapped) {
            $0.destination = .manageHomes(
                ManageHomesFeature.State(homes: [ManageHomesTests.nest], currentHomeID: "h1")
            )
        }
    }

    @Test("Switching closes the sheet and hands the new home to the app")
    func switchingBubblesUp() async {
        var state = SettingsFeature.State(homeID: "h1", home: ManageHomesTests.nest)
        state.applyHomes([ManageHomesTests.nest, ManageHomesTests.cabin])
        state.destination = .manageHomes(
            ManageHomesFeature.State(
                homes: [ManageHomesTests.nest, ManageHomesTests.cabin], currentHomeID: "h1"
            )
        )

        let store = TestStore(initialState: state) { SettingsFeature() }

        await store.send(.destination(.presented(.manageHomes(.delegate(.switchRequested("h2")))))) {
            $0.destination = nil
        }
        await store.receive(\.delegate.homeSwitched)
    }

    @Test("A live home-list update reaches the sheet while it is open")
    func homeListUpdatesReachTheSheet() {
        var state = SettingsFeature.State(homeID: "h1", home: ManageHomesTests.nest)
        state.applyHomes([ManageHomesTests.nest, ManageHomesTests.cabin])
        state.destination = .manageHomes(
            ManageHomesFeature.State(
                homes: [ManageHomesTests.nest, ManageHomesTests.cabin], currentHomeID: "h1"
            )
        )

        // The other home was left on another device.
        state.applyHomes([ManageHomesTests.nest])

        guard case let .manageHomes(manage) = state.destination else {
            Issue.record("the sheet should still be open")
            return
        }
        #expect(manage.homes.ids == ["h1"])
    }
}

@MainActor
@Suite("Recipe shopping")
struct RecipeShoppingTests {

    private static let recipe = Recipe(
        id: "r1", title: "Lasagne",
        ingredients: ["500g beef mince", "2 cloves garlic", "Pasta sheets"],
        homeID: "h1"
    )

    @Test("The screen counts what is already outstanding, not what is bought")
    func countsOnlyOutstanding() async {
        var state = RecipeDetailFeature.State(recipe: Self.recipe, homeID: "h1")
        let store = TestStore(initialState: state) { RecipeDetailFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.shoppingUpdated([
            ShoppingItem(id: "s1", name: "2 cloves garlic", homeID: "h1"),
            // Bought already, so it is not on the list any more in the sense
            // that matters — it needs buying again.
            ShoppingItem(id: "s2", name: "Pasta sheets", isPurchased: true, homeID: "h1"),
        ]))

        #expect(store.state.ingredientsOnList == 1)
        #expect(store.state.missingIngredients == ["500g beef mince", "Pasta sheets"])
        #expect(!store.state.isFullyOnList)

        state = store.state
        #expect(!state.isFullyOnList)
    }

    @Test("Only the missing lines are sent")
    func sendsOnlyWhatIsMissing() async {
        let sent = LockIsolated<[[String]]>([])
        let store = TestStore(
            initialState: RecipeDetailFeature.State(recipe: Self.recipe, homeID: "h1")
        ) {
            RecipeDetailFeature()
        } withDependencies: {
            $0.shopping.addFromRecipe = { batch in
                sent.withValue { $0.append(batch.names) }
                return batch.names.count
            }
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.shoppingUpdated([
            ShoppingItem(id: "s1", name: "  2 CLOVES GARLIC ", homeID: "h1")
        ]))
        await store.send(.addToShoppingTapped)
        await store.receive(\.addedToShopping)

        // Case and padding are folded the way the server folds them.
        #expect(sent.value == [["500g beef mince", "Pasta sheets"]])
    }

    @Test("A rejected write says so instead of looking like a dead button")
    func failureSurfaces() async {
        struct Boom: Error {}
        let store = TestStore(
            initialState: RecipeDetailFeature.State(recipe: Self.recipe, homeID: "h1")
        ) {
            RecipeDetailFeature()
        } withDependencies: {
            $0.shopping.addFromRecipe = { _ in throw Boom() }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.addToShoppingTapped)
        await store.receive(\.failed)
        #expect(store.state.alert != nil, "the failure has to reach the person")
        #expect(!store.state.isAddingToList)
    }
}

@MainActor
@Suite("Dinner")
struct DinnerTests {

    @Test("A candidate survives the round trip through a poll item's external id")
    func candidateRoundTrips() {
        let recipe = DinnerCandidate(Recipe(id: "r1", title: "Lasagne", homeID: "h1"))
        #expect(recipe.id == "recipe:r1")
        let back = DinnerCandidate(externalID: recipe.id, label: "Lasagne")
        #expect(back?.kind == .recipe)
        #expect(back?.value == "r1")

        // A typed meal can contain a colon; only the first one separates.
        let typed = DinnerCandidate(kind: .custom, value: "Pizza: the good place", label: "Pizza: the good place")
        let typedBack = DinnerCandidate(externalID: typed.id, label: typed.label)
        #expect(typedBack?.value == "Pizza: the good place")

        let cuisine = DinnerCandidate(Cuisine.thai)
        #expect(DinnerCandidate(externalID: cuisine.id, label: nil)?.value == "thai")
    }

    @Test("A winning candidate becomes the right kind of plan")
    func winnerBecomesAPlan() {
        let recipe = DinnerCandidate(Recipe(id: "r1", title: "Lasagne", homeID: "h1"))
        let cooked = recipe.decision(homeID: "h1", kind: .cook)
        #expect(cooked.kind == .cook)
        #expect(cooked.recipeID == "r1")

        // A cuisine cannot be cooked, so a cook round that lands on one is an
        // order rather than a plan pointing at nothing.
        let cuisine = DinnerCandidate(Cuisine.indian)
        #expect(cuisine.decision(homeID: "h1", kind: .cook).kind == .order)
        #expect(cuisine.decision(homeID: "h1", kind: .out).kind == .out)

        let typed = DinnerCandidate(kind: .custom, value: "Leftovers", label: "Leftovers")
        #expect(typed.decision(homeID: "h1", kind: .cook).title == "Leftovers")
        #expect(typed.decision(homeID: "h1", kind: .out).place == "Leftovers")
    }

    @Test("Switching kind mid-flow drops what belonged to the old one")
    func switchingKindClearsTheAnswer() async {
        let store = TestStore(initialState: DinnerFeature.State(homeID: "h1")) {
            DinnerFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.routeChosen(.set))
        await store.send(.kindChosen(.cook))
        await store.send(.recipeChosen(Recipe(id: "r1", title: "Lasagne", homeID: "h1")))
        #expect(store.state.canSave)

        await store.send(.kindChosen(.order))
        #expect(store.state.selection == nil, "a recipe cannot be ordered in")
        #expect(!store.state.canSave)
    }

    @Test("A round needs at least two things to choose between")
    func roundNeedsTwo() async {
        let store = TestStore(initialState: DinnerFeature.State(homeID: "h1")) {
            DinnerFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.routeChosen(.vote))
        await store.send(.kindChosen(.cook))
        #expect(!store.state.canStartRound)

        await store.send(.ballotToggled(DinnerCandidate(Cuisine.thai)))
        #expect(!store.state.canStartRound, "one option is not a choice")

        await store.send(.ballotToggled(DinnerCandidate(Cuisine.indian)))
        #expect(store.state.canStartRound)

        // Tapping an option again takes it back off the ballot.
        await store.send(.ballotToggled(DinnerCandidate(Cuisine.indian)))
        #expect(store.state.ballot.count == 1)
    }

        @Test("A calendar day, not an instant — dinner belongs to the household's own date")
    func dateKeyIsLocal() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        // 9pm in Istanbul is still the previous day in UTC.
        let evening = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 4, hour: 21, minute: 30
        ))!
        #expect(MealDate.key(evening, calendar: calendar) == "2026-09-04")
    }

    @Test("Cooking needs a recipe; ordering in needs a cuisine")
    func saveRules() {
        var state = DinnerFeature.State(homeID: "h1")
        #expect(!state.canSave)

        state.kind = .cook
        #expect(!state.canSave)
        state.selectedCuisine = .italian
        #expect(!state.canSave, "a cuisine does not make a recipe")
        state.selection = Recipe(id: "r1", title: "Lasagne", homeID: "h1")
        #expect(state.canSave)

        state.kind = .order
        state.selectedCuisine = nil
        #expect(!state.canSave, "a recipe does not make a takeaway")
        state.selectedCuisine = .indian
        #expect(state.canSave)
    }

    @Test("An empty shelf opens on the catalogue instead")
    func emptyShelfFallsBackToExplore() async {
        let sample = Recipe(id: "x1", title: "Menemen", homeID: Recipe.exploreHomeID)
        let store = TestStore(initialState: DinnerFeature.State(homeID: "h1")) {
            DinnerFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.kindChosen(.cook))
        await store.send(.samplesLoaded([sample]))
        await store.send(.recipesUpdated([]))
        #expect(store.state.source == .explore)

        // And back to your own shelf once there is something on it.
        await store.send(.sourceChanged(.saved))
        #expect(store.state.source == .saved)
    }

    @Test("Filters narrow by tag, and only offer tags the candidates carry")
    func tagFiltersFollowTheCandidates() async {
        let dinner = Recipe(
            id: "x1", title: "Lasagne", tags: ["dinner", "comfort"],
            homeID: Recipe.exploreHomeID
        )
        let breakfast = Recipe(
            id: "x2", title: "Menemen", tags: ["breakfast"],
            homeID: Recipe.exploreHomeID
        )
        let store = TestStore(initialState: DinnerFeature.State(homeID: "h1")) {
            DinnerFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.samplesLoaded([dinner, breakfast]))
        await store.send(.sourceChanged(.explore))
        #expect(store.state.availableTags == ["breakfast", "dinner", "comfort"]
            .filter(store.state.availableTags.contains))
        #expect(!store.state.availableTags.contains("vegan"), "no candidate carries it")

        await store.send(.tagToggled("dinner"))
        #expect(store.state.matchingRecipes.map(\.id) == ["x1"])
    }

    @Test("A typed meal is an answer too, and never competes with a chosen recipe")
    func customMealIsAnAnswer() async {
        let store = TestStore(initialState: DinnerFeature.State(homeID: "h1")) {
            DinnerFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.kindChosen(.cook))
        await store.send(.recipeChosen(Recipe(id: "r1", title: "Lasagne", homeID: "h1")))
        #expect(store.state.canSave)

        // Switching to a typed name lets go of the recipe.
        await store.send(.sourceChanged(.custom))
        #expect(store.state.selection == nil)
        #expect(!store.state.canSave, "an empty field is not an answer")

        await store.send(.binding(.set(\.customTitle, "  Leftovers  ")))
        #expect(store.state.canSave)
        #expect(store.state.trimmedCustomTitle == "Leftovers")

        // And back the other way, the typed name is dropped.
        await store.send(.sourceChanged(.saved))
        #expect(store.state.customTitle.isEmpty)
    }

    @Test("Re-deciding opens on what was already chosen")
    func reopeningPrefills() {
        let plan = MealPlan(
            id: "m1", kind: .order, cuisine: .thai, place: "Bangkok Kitchen",
            date: MealDate.today
        )
        let state = DinnerFeature.State(homeID: "h1", existing: plan)
        #expect(state.selectedCuisine == .thai)
        #expect(state.place == "Bangkok Kitchen")

        // Prefilled, but landing on the kind picker rather than inside the kind
        // chosen last time — which left "order in" behind a Back button.
        #expect(state.kind == nil)
        #expect(state.prefilledKind == .order)

        // A typed meal reopens on its own tab rather than on an empty shelf.
        let typed = MealPlan(id: "m2", kind: .cook, title: "Leftovers", date: MealDate.today)
        let reopened = DinnerFeature.State(homeID: "h1", existing: typed)
        #expect(reopened.source == .custom)
        #expect(reopened.customTitle == "Leftovers")
    }

    @Test("Only today's plan is tonight's dinner")
    func tonightIsToday() {
        let today = MealPlan(id: "m1", kind: .out, cuisine: .turkish, date: MealDate.today)
        let tomorrow = MealPlan(id: "m2", kind: .cook, date: "2099-01-01")

        var state = HomeFeature.State(homeID: "h1")
        state.meals = [today, tomorrow]
        #expect(state.tonight?.id == "m1")

        state.meals = [tomorrow]
        #expect(state.tonight == nil)
    }
}

@MainActor
@Suite("Shopping list")
struct ShoppingTests {

    private static let milk = ShoppingItem(id: "s1", name: "Milk", homeID: "h1")
    private static let eggs = ShoppingItem(id: "s2", name: "Eggs", homeID: "h1")

    private static func listStore(
        _ removed: LockIsolated<[ShoppingItemID]>,
        _ clock: TestClock<Duration>
    ) -> TestStoreOf<ShoppingFeature> {
        TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.remove = { id in removed.withValue { $0.append(id) } }
            $0.continuousClock = clock
        }
    }

    @Test("A swipe drops the row at once but holds the write open for undo")
    func deleteIsHeldForUndo() async {
        let removed = LockIsolated<[ShoppingItemID]>([])
        let clock = TestClock()
        let store = Self.listStore(removed, clock)

        await store.send(.itemsUpdated([Self.milk, Self.eggs])) {
            $0.isLoading = false
            $0.items = [Self.milk, Self.eggs]
        }

        await store.send(.deleteTapped("s1")) {
            $0.items.remove(id: "s1")
            $0.pendingDeletion = Self.milk
        }
        #expect(removed.value.isEmpty)

        // The server still has the item, so a live push arriving mid-window
        // must not put the row back.
        await store.send(.itemsUpdated([Self.milk, Self.eggs]))
        #expect(store.state.items.ids == ["s2"])

        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowClosed) {
            $0.pendingDeletion = nil
        }
        #expect(removed.value == ["s1"])
    }

    @Test("Undo cancels the write rather than reversing it")
    func undoCancelsTheDelete() async {
        let removed = LockIsolated<[ShoppingItemID]>([])
        let clock = TestClock()
        let store = Self.listStore(removed, clock)

        await store.send(.itemsUpdated([Self.milk, Self.eggs])) {
            $0.isLoading = false
            $0.items = [Self.milk, Self.eggs]
        }
        await store.send(.deleteTapped("s1")) {
            $0.items.remove(id: "s1")
            $0.pendingDeletion = Self.milk
        }
        await store.send(.undoDeleteTapped) {
            $0.pendingDeletion = nil
            $0.items.append(Self.milk)
        }

        await clock.advance(by: .seconds(30))
        #expect(removed.value.isEmpty)
    }

    @Test("Popping the screen commits a delete still inside its undo window")
    func poppingCommitsThePendingDelete() async {
        let removed = LockIsolated<[ShoppingItemID]>([])
        var shopping = ShoppingFeature.State(homeID: "h1")
        shopping.pendingDeletion = Self.milk

        var hub = HubFeature.State(homeID: "h1")
        hub.path.append(.shopping(shopping))
        let id = hub.path.ids[0]

        let store = TestStore(initialState: hub) {
            HubFeature()
        } withDependencies: {
            $0.shopping.remove = { itemID in removed.withValue { $0.append(itemID) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // The screen cannot do this itself: `onDisappear` runs after the pop,
        // when the element the action addresses is already gone.
        await store.send(.path(.popFrom(id: id)))
        #expect(removed.value == ["s1"])
    }

    @Test("Ingredients from a recipe are shopped under the meal, not scattered by aisle")
    func recipeItemsGroupUnderTheirMeal() async {
        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        }
        let loose = ShoppingItem(id: "s1", name: "Milk", category: .groceries, homeID: "h1")
        let garlic = ShoppingItem(
            id: "s2", name: "2 cloves garlic", category: .groceries,
            homeID: "h1", recipeID: "r1", recipeTitle: "Lasagne"
        )
        let beef = ShoppingItem(
            id: "s3", name: "500g beef mince", category: .groceries,
            homeID: "h1", recipeID: "r1", recipeTitle: "Lasagne"
        )

        await store.send(.itemsUpdated([loose, garlic, beef])) {
            $0.isLoading = false
            $0.items = [loose, garlic, beef]
        }

        let meals = store.state.mealGroups
        #expect(meals.count == 1)
        #expect(meals.first?.title == "Lasagne")
        #expect(meals.first?.items.count == 2)

        // And an item belongs to exactly one place on the screen.
        #expect(store.state.pendingFlat.map(\.id) == ["s1"])
        #expect(store.state.pendingByCategory.flatMap(\.items).map(\.id) == ["s1"])
    }

    @Test("Clearing an aisle leaves a meal's ingredients alone")
    func clearingACategorySparesMeals() async {
        let removed = LockIsolated<[ShoppingItemID]>([])
        let loose = ShoppingItem(id: "s1", name: "Milk", category: .groceries, homeID: "h1")
        let alsoLoose = ShoppingItem(id: "s2", name: "Bread", category: .groceries, homeID: "h1")
        let forMeal = ShoppingItem(
            id: "s3", name: "Pasta sheets", category: .groceries,
            homeID: "h1", recipeID: "r1", recipeTitle: "Lasagne"
        )
        let cleaning = ShoppingItem(id: "s4", name: "Bleach", category: .cleaning, homeID: "h1")

        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.remove = { id in removed.withValue { $0.append(id) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.itemsUpdated([loose, alsoLoose, forMeal, cleaning]))
        await store.send(.clearCategoryTapped(.groceries))
        #expect(store.state.alert != nil, "a bulk delete asks first")
        #expect(removed.value.isEmpty)

        await store.send(.alert(.presented(.confirmClearCategory(.groceries))))
        #expect(Set(removed.value) == ["s1", "s2"])
        #expect(store.state.items.ids.contains("s3"), "the meal keeps its ingredient")
        #expect(store.state.items.ids.contains("s4"))
    }

    @Test("Clearing a meal takes the whole meal, bought or not")
    func clearingAMealTakesEverything() async {
        let removed = LockIsolated<[ShoppingItemID]>([])
        let pending = ShoppingItem(
            id: "s1", name: "Pasta sheets", homeID: "h1",
            recipeID: "r1", recipeTitle: "Lasagne"
        )
        let bought = ShoppingItem(
            id: "s2", name: "Beef mince", isPurchased: true, homeID: "h1",
            recipeID: "r1", recipeTitle: "Lasagne"
        )
        let other = ShoppingItem(id: "s3", name: "Milk", homeID: "h1")

        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.remove = { id in removed.withValue { $0.append(id) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.itemsUpdated([pending, bought, other]))
        await store.send(.clearMealTapped("r1"))
        await store.send(.alert(.presented(.confirmClearMeal("r1"))))

        #expect(Set(removed.value) == ["s1", "s2"])
        #expect(store.state.items.ids == ["s3"])
    }

    @Test("A meal folds away like an aisle does")
    func mealsCollapse() async {
        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.mealToggled("r1"))
        #expect(store.state.isCollapsed(meal: "r1"))
        await store.send(.mealToggled("r1"))
        #expect(!store.state.isCollapsed(meal: "r1"))
    }

    @Test("Adding clears the field immediately so the next item can be typed")
    func addClearsDraft() async {
        let created = LockIsolated<[String]>([])
        var state = ShoppingFeature.State(homeID: "h1")
        state.draft = "Milk"

        let store = TestStore(initialState: state) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.create = { item in created.withValue { $0.append(item.name) } }
        }

        await store.send(.addTapped) { $0.draft = "" }
        #expect(created.value == ["Milk"])
    }

    @Test("A blank draft does nothing")
    func blankDraftIsIgnored() async {
        var state = ShoppingFeature.State(homeID: "h1")
        state.draft = "   "
        let store = TestStore(initialState: state) { ShoppingFeature() }
        await store.send(.addTapped)
    }

    @Test("Pending items group by category in aisle order")
    func groupingOrder() async {
        let items = [
            ShoppingItem(id: "1", name: "Bleach", category: .cleaning),
            ShoppingItem(id: "2", name: "Milk", category: .groceries),
            ShoppingItem(id: "3", name: "Bought", isPurchased: true, category: .groceries),
        ]
        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        }
        await store.send(.itemsUpdated(items)) {
            $0.isLoading = false
            $0.items = IdentifiedArray(uniqueElements: items)
        }
        // Declaration order of `Category`, not dictionary order.
        #expect(store.state.pendingByCategory.map(\.category) == [.groceries, .cleaning])
        #expect(store.state.purchased.count == 1)
    }
}

@MainActor
@Suite("Notes")
struct NotesTests {

    @Test("Author names are resolved once, in a single batch")
    func authorsResolvedInOneCall() async {
        let calls = LockIsolated<[[UserID]]>([])
        let notes = [
            Note(id: "n1", body: "One", createdBy: "u1"),
            Note(id: "n2", body: "Two", createdBy: "u2"),
            Note(id: "n3", body: "Three", createdBy: "u1"),
        ]

        let store = TestStore(initialState: NotesFeature.State(homeID: "h1")) {
            NotesFeature()
        } withDependencies: {
            $0.users.byIDs = { ids in
                calls.withValue { $0.append(ids.sorted { $0.rawValue < $1.rawValue }) }
                return ids.map { User(id: $0, name: "Name \($0.rawValue)") }
            }
        }

        await store.send(.notesUpdated(notes)) {
            $0.isLoading = false
            $0.notes = IdentifiedArray(uniqueElements: notes)
        }
        await store.receive(\.authorsResolved) {
            $0.authors = ["u1": "Name u1", "u2": "Name u2"]
        }

        // Two distinct authors across three notes → one request for two ids.
        #expect(calls.value.count == 1)
        #expect(calls.value[0] == [UserID("u1"), UserID("u2")])

        // A further push with no new authors must not refetch.
        await store.send(.notesUpdated(notes))
        #expect(calls.value.count == 1)
    }

    @Test("Only the author can edit their note")
    func editPermission() {
        var state = NotesFeature.State(homeID: "h1", currentUserID: "me")
        let mine = Note(id: "n1", body: "x", createdBy: "me")
        let theirs = Note(id: "n2", body: "y", createdBy: "them")
        let orphan = Note(id: "n3", body: "z")
        state.notes = [mine, theirs, orphan]

        #expect(state.canEdit(mine))
        #expect(!state.canEdit(theirs))
        #expect(!state.canEdit(orphan))
    }

    @Test("Search filters by body text")
    func search() {
        var state = NotesFeature.State(homeID: "h1")
        state.notes = [
            Note(id: "n1", body: "Buy milk"),
            Note(id: "n2", body: "Call the plumber"),
        ]
        state.searchText = "MILK"
        #expect(state.visibleNotes.map(\.id) == [NoteID("n1")])
    }
}

@MainActor
@Suite("Movie night")
struct MovieNightTests {

    @Test("Each round type maps to one catalogue request")
    func kindMapsToQuery() {
        var state = PollKindFeature.State()

        state.kind = .popular
        #expect(state.query.kind == .popular)

        state.kind = .genre
        state.genre = .horror
        #expect(state.query.kind == .genre)
        #expect(state.query.query == "horror")

        state.kind = .year
        state.year = 1999
        #expect(state.query.year == 1999)

        state.kind = .actor
        state.personName = "Toni Collette"
        #expect(state.query.query == "Toni Collette")
    }

    @Test("Person rounds need a name before they can start")
    func personRoundsNeedInput() {
        var state = PollKindFeature.State()
        state.kind = .actor
        #expect(!state.canStart)
        state.personName = "Toni Collette"
        #expect(state.canStart)
        // Curated rounds need nothing.
        state.kind = .popular
        #expect(state.canStart)
    }

    @Test("A swipe removes the card before the vote is confirmed")
    func swipeIsOptimistic() async {
        let votes = LockIsolated<[(String, Bool)]>([])
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")
        let item = PollItem(id: "i1", externalID: "dune", label: "Dune")
        state.deck = [item]

        let store = TestStore(initialState: state) {
            MovieNightFeature()
        } withDependencies: {
            $0.polls.vote = { _, external, yes in
                votes.withValue { $0.append((external, yes)) }
            }
        }

        await store.send(.swiped(item, isYes: true)) {
            $0.swiped = ["dune"]
        }
        #expect(store.state.remaining.isEmpty)
        #expect(votes.value.count == 1)
        #expect(votes.value[0] == ("dune", true))
    }

    @Test("Closing a poll clears the deck and moves the round into history")
    func closedPollResets() async {
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")
        state.deck = [PollItem(id: "i1", externalID: "dune")]
        state.swiped = ["dune"]

        let store = TestStore(initialState: state) { MovieNightFeature() }
        let closed = Poll(id: "p1", status: .closed)

        await store.send(.pollsUpdated([closed])) {
            $0.isLoading = false
            $0.poll = nil
            $0.detail = nil
            $0.deck = []
            $0.swiped = []
            // A finished round is still worth showing under "Previous rounds".
            $0.history = [closed]
        }
    }

    @Test("History is closed rounds only, newest first")
    func historyOrdering() async {
        let older = Poll(id: "p1", status: .closed, created: Timestamp(milliseconds: 1000))
        let newer = Poll(id: "p2", status: .closed, created: Timestamp(milliseconds: 2000))
        let live = Poll(id: "p3", status: .active, created: Timestamp(milliseconds: 3000))

        let store = TestStore(
            initialState: MovieNightFeature.State(homeID: "h1", memberCount: 2)
        ) {
            MovieNightFeature()
        } withDependencies: {
            // Finishes immediately rather than `.never`: an open poll makes the
            // reducer subscribe to its detail, and `TestStore` requires every
            // effect it starts to complete before the test ends.
            $0.polls.detail = { _ in
                AsyncThrowingStream { $0.finish() }
            }
        }

        await store.send(.pollsUpdated([older, live, newer])) {
            $0.isLoading = false
            $0.history = [newer, older]
            $0.poll = live
        }
        #expect(store.state.hasActivePoll)
    }
}


@MainActor
@Suite("Session restore")
struct SessionRestoreTests {

    /// Convex Auth rotates the refresh token on every exchange, so a restore
    /// that fails mid-flight can strand a perfectly good session. Treating that
    /// as a sign-out is the bug these cover.
    @Test("A network failure shows the offline screen, not the sign-in screen")
    func transientFailureIsNotASignOut() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.auth.restoreSession = { .transientFailure }
        }

        await store.send(.sessionRestoreFinished(.transientFailure)) {
            $0.isRestoringSession = false
            $0.restoreFailedOffline = true
        }
        await store.send(.authStatusChanged(.unauthenticated)) {
            $0.status = .unauthenticated
        }
        #expect(store.state.screen == .offline)
    }

    @Test("No stored session really does mean signed out")
    func noSessionShowsSignIn() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }

        await store.send(.sessionRestoreFinished(.noSession)) {
            $0.isRestoringSession = false
        }
        await store.send(.authStatusChanged(.unauthenticated)) {
            $0.status = .unauthenticated
        }
        #expect(store.state.screen == .signedOut)
    }

    @Test("Retrying from the offline screen goes back through the restore")
    func retryReattempts() async {
        let attempts = LockIsolated(0)
        var state = AppFeature.State()
        state.isRestoringSession = false
        state.restoreFailedOffline = true

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.auth.restoreSession = {
                attempts.withValue { $0 += 1 }
                return .restored
            }
        }

        await store.send(.retryRestoreTapped) {
            $0.isRestoringSession = true
            $0.restoreFailedOffline = false
        }
        await store.receive(\.sessionRestoreFinished) {
            $0.isRestoringSession = false
            $0.restoreFailedOffline = false
        }
        #expect(attempts.value == 1)
    }

    @Test("A restored session clears the offline state")
    func restoredClearsOffline() async {
        var state = AppFeature.State()
        state.restoreFailedOffline = true
        let store = TestStore(initialState: state) { AppFeature() }

        await store.send(.sessionRestoreFinished(.restored)) {
            $0.isRestoringSession = false
            $0.restoreFailedOffline = false
        }
    }
}

@MainActor
@Suite("Sign out")
struct SignOutTests {

    @Test("Signing out hands the push token over so the device stops receiving")
    func signOutUnregistersDevice() async {
        let handed = LockIsolated<[String?]>([])
        var state = SettingsFeature.State(homeID: "h1")
        state.pushToken = "abc123"

        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.auth.signOut = { token in handed.withValue { $0.append(token) } }
        }

        await store.send(.signOutConfirmed)
        #expect(handed.value == ["abc123"])
    }

    @Test("A device with no push token still signs out cleanly")
    func signOutWithoutToken() async {
        let handed = LockIsolated<[String?]>([])
        let store = TestStore(initialState: SettingsFeature.State(homeID: "h1")) {
            SettingsFeature()
        } withDependencies: {
            $0.auth.signOut = { token in handed.withValue { $0.append(token) } }
        }

        await store.send(.signOutConfirmed)
        #expect(handed.value == [String?.none])
    }
}
