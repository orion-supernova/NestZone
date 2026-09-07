import ComposableArchitecture
import Foundation
import Testing
import UserNotifications
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

    @Test("A newcomer is asked about notifications once, and only once")
    func notificationPromptIsAskedOnce() async {
        await withDependencies {
            // The flag is persisted, so an unisolated store would carry the
            // answer from whichever test ran first.
            $0.defaultAppStorage = .inMemory
        } operation: {
            let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
                HomeFeature()
            }

            await store.send(.notificationPromptReady) {
                $0.$hasAskedForNotifications.withLock { $0 = true }
                $0.alert = .enableNotifications
            }

            // The next visit to the tab must not raise it again. `.task` is not
            // driven here; the flag it reads is what stops the ask.
            #expect(store.state.hasAskedForNotifications)
        }
    }

    @Test("Granting permission on the Home tab tells the app to fetch a token")
    func grantingNotificationsBubblesUp() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
                HomeFeature()
            } withDependencies: {
                $0.push.requestAuthorization = { true }
            }

            await store.send(.notificationPromptReady) {
                $0.$hasAskedForNotifications.withLock { $0 = true }
                $0.alert = .enableNotifications
            }
            await store.send(.alert(.presented(.enableNotifications))) {
                $0.alert = nil
            }
            await store.receive(\.notificationAuthorizationAnswered)
            await store.receive(.delegate(.notificationsEnabled))
        }
    }

    @Test("A refused prompt bubbles nothing")
    func refusedNotificationsStaysPut() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
                HomeFeature()
            } withDependencies: {
                $0.push.requestAuthorization = { false }
            }

            await store.send(.notificationPromptReady) {
                $0.$hasAskedForNotifications.withLock { $0 = true }
                $0.alert = .enableNotifications
            }
            await store.send(.alert(.presented(.enableNotifications))) {
                $0.alert = nil
            }
            await store.receive(\.notificationAuthorizationAnswered)
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
@Suite("Contributions navigation")
struct ContributionsNavigationTests {

    @Test("The chart button in the Tasks header pushes the breakdown")
    func openingFromHome() async {
        let store = TestStore(
            initialState: MainFeature.State(
                homeID: "h1",
                home: Home(id: "h1", name: "The Nest", members: ["me", "you"]),
                user: User(id: "me", name: "Ada")
            )
        ) {
            MainFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.home(.delegate(.openContributions)))

        #expect(store.state.homePath.count == 1)
        guard case let .contributions(contributions) = store.state.homePath.first else {
            Issue.record("expected the contributions screen on the stack")
            return
        }
        // It opens knowing who is looking, so their own row can say "You".
        #expect(contributions.currentUserID == UserID("me"))
        #expect(contributions.homeID == HomeID("h1"))
    }
}

@MainActor
@Suite("Contributions screen")
struct ContributionsFeatureTests {

    private static func payload(
        window: ContributionWindow,
        adaCompleted: Int
    ) -> HomeContributions {
        HomeContributions(
            windowDays: window.days,
            totalCompleted: adaCompleted + 2,
            unattributed: 0,
            members: [
                MemberContribution(userID: "u1", name: "Ada", completed: adaCompleted),
                MemberContribution(userID: "u2", name: "Grace", completed: 2),
            ]
        )
    }

    @Test("The screen opens on the month and subscribes for it")
    func subscribesOnAppear() async {
        let asked = LockIsolated<[ContributionWindow]>([])
        let store = TestStore(
            initialState: ContributionsFeature.State(homeID: "h1", currentUserID: "u1")
        ) {
            ContributionsFeature()
        } withDependencies: {
            $0.stats.contributions = { _, window in
                asked.withValue { $0.append(window) }
                return AsyncThrowingStream { $0.yield(Self.payload(window: window, adaCompleted: 6)) }
            }
        }
        store.exhaustivity = .off

        #expect(store.state.window == .month)
        await store.send(.task)
        await store.receive(\.contributionsUpdated) {
            $0.isLoading = false
            $0.data = Self.payload(window: .month, adaCompleted: 6)
        }
        #expect(asked.value == [.month])
    }

    @Test("Switching the window re-subscribes rather than filtering what it has")
    func windowSwitchResubscribes() async {
        let asked = LockIsolated<[ContributionWindow]>([])
        let store = TestStore(
            initialState: ContributionsFeature.State(homeID: "h1")
        ) {
            ContributionsFeature()
        } withDependencies: {
            $0.stats.contributions = { _, window in
                asked.withValue { $0.append(window) }
                return AsyncThrowingStream { $0.yield(Self.payload(window: window, adaCompleted: 1)) }
            }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.contributionsUpdated)

        await store.send(.binding(.set(\.window, .week))) {
            $0.window = .week
            // The old numbers are for a different question; the screen says so
            // rather than showing a month's totals under a "Week" tab.
            $0.isLoading = true
        }
        await store.receive(\.contributionsUpdated) {
            $0.isLoading = false
            $0.data = Self.payload(window: .week, adaCompleted: 1)
        }
        #expect(asked.value == [.month, .week])
    }

    @Test("Slices are ordered like the leaderboard and carry the leftover")
    func slices() async {
        let data = HomeContributions(
            windowDays: 30,
            totalCompleted: 10,
            unattributed: 2,
            members: [
                MemberContribution(userID: "u2", name: "Grace", completed: 3),
                MemberContribution(userID: "u1", name: "Ada", completed: 5),
                MemberContribution(userID: "u3", name: "Idle", completed: 0),
            ]
        )
        let store = TestStore(initialState: ContributionsFeature.State(homeID: "h1")) {
            ContributionsFeature()
        }
        await store.send(.contributionsUpdated(data)) {
            $0.isLoading = false
            $0.data = data
        }

        // Busiest first, nobody with a zero share on the ring, and the
        // unattributed remainder last so the segments still fill the circle.
        #expect(store.state.data.slices.map(\.id) == ["u1", "u2", "unattributed"])
        #expect(store.state.data.slices.map(\.value) == [0.5, 0.3, 0.2])
        #expect(store.state.data.slices.last?.seed == nil)
    }

    @Test("A failure that is only a cancellation never becomes an alert")
    func silentFailure() async {
        let store = TestStore(initialState: ContributionsFeature.State(homeID: "h1")) {
            ContributionsFeature()
        }
        await store.send(.loadFailed(.cancelled)) {
            $0.isLoading = false
        }
        #expect(store.state.alert == nil)
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
            $0.shopping.removeMany = { ids in removed.withValue { $0.append(contentsOf: ids) } }
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
            $0.hidden.insert("s1")
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
            $0.hidden.insert("s1")
            $0.pendingDeletion = Self.milk
        }
        await store.send(.undoDeleteTapped) {
            $0.pendingDeletion = nil
            $0.hidden.remove("s1")
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
            $0.shopping.removeMany = { ids in removed.withValue { $0.append(contentsOf: ids) } }
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
            $0.shopping.removeMany = { ids in removed.withValue { $0.append(contentsOf: ids) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.itemsUpdated([pending, bought, other]))
        await store.send(.clearMealTapped("r1"))
        await store.send(.alert(.presented(.confirmClearMeal("r1"))))

        #expect(Set(removed.value) == ["s1", "s2"])
        #expect(store.state.items.ids == ["s3"])
    }

    @Test("A cleared group stays cleared while the writes are still in flight")
    func clearedGroupDoesNotFlickerBack() async {
        let removed = LockIsolated<[ShoppingItemID]>([])
        let loose = ShoppingItem(id: "s1", name: "Milk", category: .groceries, homeID: "h1")
        let alsoLoose = ShoppingItem(id: "s2", name: "Bread", category: .groceries, homeID: "h1")
        let cleaning = ShoppingItem(id: "s3", name: "Bleach", category: .cleaning, homeID: "h1")

        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.removeMany = { ids in removed.withValue { $0.append(contentsOf: ids) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.itemsUpdated([loose, alsoLoose, cleaning]))
        await store.send(.clearCategoryTapped(.groceries))
        await store.send(.alert(.presented(.confirmClearCategory(.groceries))))
        #expect(store.state.items.ids == ["s3"])

        // The write has not landed yet, so the server pushes the rows it still
        // has. This is what used to put the emptied aisle back on screen and
        // then drain it a row at a time.
        await store.send(.itemsUpdated([loose, alsoLoose, cleaning]))
        #expect(store.state.items.ids == ["s3"], "the group stays gone")

        // Once the deletes land, the mask has nothing left to hide.
        await store.send(.itemsUpdated([cleaning]))
        #expect(store.state.hidden.isEmpty)
    }

    @Test("A swipe whose write fails puts the row back")
    func failedSwipeRestoresTheRow() async {
        let clock = TestClock()
        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.remove = { _ in throw AppError.server("nope") }
            $0.continuousClock = clock
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.itemsUpdated([Self.milk, Self.eggs]))
        await store.send(.deleteTapped("s1"))
        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowClosed)
        await store.receive(\.deleteCommitFailed)

        #expect(store.state.items.ids.contains("s1"), "the row is back")
        #expect(store.state.hidden.isEmpty, "and no longer masked against the live push")
    }

    @Test("A group that fails to clear comes back rather than vanishing silently")
    func failedClearRestoresTheRows() async {
        let loose = ShoppingItem(id: "s1", name: "Milk", category: .groceries, homeID: "h1")

        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.removeMany = { _ in throw AppError.server("nope") }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.itemsUpdated([loose]))
        await store.send(.clearCategoryTapped(.groceries))
        await store.send(.alert(.presented(.confirmClearCategory(.groceries))))
        #expect(store.state.items.isEmpty)

        await store.receive(\.clearFailed)
        #expect(store.state.hidden.isEmpty, "the rows are no longer hidden")
        // And the next push puts them back, because nothing masks them now.
        await store.send(.itemsUpdated([loose]))
        #expect(store.state.items.ids == ["s1"])
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

        await store.send(.addTapped) {
            $0.draft = ""
            $0.pendingAdds = 1
        }
        await store.receive(\.addFinished) { $0.pendingAdds = 0 }
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

    @Test("Tapping a card in the deck opens the film without answering for it")
    func cardOpensDetails() async {
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")
        let item = PollItem(id: "i1", externalID: "dune", label: "Dune")
        state.deck = [item]

        let store = TestStore(initialState: state) { MovieNightFeature() }

        await store.send(.movieTapped(item)) {
            $0.destination = .movieInfo(
                MovieInfoFeature.State(homeID: "h1", movie: item.asMovie)
            )
        }
        // Opening a card is not a vote: it stays in the deck, unswiped.
        #expect(store.state.swiped.isEmpty)
        #expect(store.state.remaining.count == 1)
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

@MainActor
@Suite("Saved recipes")
struct SavedRecipeTests {

    private static func copy(_ id: RecipeID, _ title: String, at millis: Double) -> Recipe {
        Recipe(id: id, title: title, homeID: "h1", created: Timestamp(milliseconds: millis))
    }

    @Test("Copies of the same dish collapse to the one that was saved first")
    func duplicatesCollapse() async {
        let store = TestStore(initialState: RecipesFeature.State(homeID: "h1")) {
            RecipesFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // What "plan it for tonight" and "add to my recipes" used to leave
        // behind: the same bundled recipe, inserted twice. Casing and stray
        // whitespace are the same dish too.
        await store.send(.savedUpdated([
            Self.copy("r1", "Lasagne", at: 100),
            Self.copy("r2", " lasagne ", at: 200),
            Self.copy("r3", "Soup", at: 300),
        ]))

        #expect(store.state.saved.ids == ["r1", "r3"], "the original survives")
        #expect(store.state.copies(of: "r1") == ["r1", "r2"])
        #expect(store.state.copies(of: "r3") == ["r3"])
    }

    @Test("Deleting a row deletes every copy behind it")
    func deleteTakesEveryCopy() async {
        let removed = LockIsolated<[RecipeID]>([])
        let store = TestStore(initialState: RecipesFeature.State(homeID: "h1")) {
            RecipesFeature()
        } withDependencies: {
            $0.recipes.removeMany = { ids in removed.withValue { $0.append(contentsOf: ids) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.savedUpdated([
            Self.copy("r1", "Lasagne", at: 100),
            Self.copy("r2", "Lasagne", at: 200),
        ]))
        await store.send(.deleteTapped("r1"))
        #expect(store.state.alert != nil, "a delete asks first")

        await store.send(.alert(.presented(.confirmDelete("r1"))))
        #expect(removed.value == ["r1", "r2"], "the twin goes too, or it takes the row's place")
        #expect(store.state.saved.isEmpty, "the row goes now, not when the server answers")

        // The server still has both until the write lands.
        await store.send(.savedUpdated([
            Self.copy("r1", "Lasagne", at: 100),
            Self.copy("r2", "Lasagne", at: 200),
        ]))
        #expect(store.state.saved.isEmpty, "the shelf does not flicker the row back")
    }

    @Test("A delete that fails puts the recipe back")
    func failedDeleteRestoresTheRow() async {
        let store = TestStore(initialState: RecipesFeature.State(homeID: "h1")) {
            RecipesFeature()
        } withDependencies: {
            $0.recipes.removeMany = { _ in throw AppError.server("nope") }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.savedUpdated([Self.copy("r1", "Lasagne", at: 100)]))
        // Through the confirmation, not around it: a presented action with no
        // presented alert is not a thing the app can send.
        await store.send(.deleteTapped("r1"))
        await store.send(.alert(.presented(.confirmDelete("r1"))))
        #expect(store.state.saved.isEmpty)

        await store.receive(\.deleteFailed)
        #expect(store.state.saved.ids == ["r1"], "rebuilt from what the server last sent")
    }

    @Test("Opening a recipe carries its copies, so deleting from inside takes them all")
    func detailKnowsItsCopies() async {
        let store = TestStore(initialState: RecipesFeature.State(homeID: "h1")) {
            RecipesFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let original = Self.copy("r1", "Lasagne", at: 100)
        await store.send(.savedUpdated([original, Self.copy("r2", "Lasagne", at: 200)]))
        await store.send(.recipeTapped(original))

        #expect(store.state.destination?.detail?.duplicateIDs == ["r1", "r2"])
    }

    @Test("Explore waits for the bundled catalogue instead of claiming it is empty")
    func exploreShowsNoFalseEmptyState() async {
        var state = RecipesFeature.State(homeID: "h1")
        state.tab = .explore
        let store = TestStore(initialState: state) { RecipesFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        #expect(store.state.isWaiting, "the catalogue has not been read off disk yet")

        await store.send(.samplesLoaded([Self.copy("s1", "Menemen", at: 1)]))
        #expect(!store.state.isWaiting, "and now it can say the shelf is empty, or show it")
    }
}

@MainActor
@Suite("Hub navigation")
struct HubNavigationTests {

    private static func hubWithRecipesOpen() -> HubFeature.State {
        var state = HubFeature.State(homeID: "h1")
        state.path.append(.recipes(RecipesFeature.State(homeID: "h1")))
        return state
    }

    @Test("Going to the list from a recipe unwinds the stack before pushing")
    func recipeHandoffUnwindsFirst() async {
        let clock = TestClock()
        let state = Self.hubWithRecipesOpen()
        let id = state.path.ids[0]

        let store = TestStore(initialState: state) { HubFeature() } withDependencies: {
            $0.continuousClock = clock
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.path(.element(id: id, action: .recipes(.delegate(.openShoppingList)))))
        // Popping and pushing together is what left the recipe on screen while
        // the state said "shopping", so nothing may be pushed yet.
        #expect(store.state.path.isEmpty)

        await clock.advance(by: .milliseconds(350))
        await store.receive(\.showShoppingList)
        #expect(store.state.path.count == 1)
        guard case .shopping = store.state.path.first else {
            Issue.record("expected the shopping list on the stack")
            return
        }
    }

    @Test("Tapping another module mid-unwind wins over the deferred push")
    func handoffDoesNotYankYouBack() async {
        let clock = TestClock()
        let state = Self.hubWithRecipesOpen()
        let id = state.path.ids[0]

        let store = TestStore(initialState: state) { HubFeature() } withDependencies: {
            $0.continuousClock = clock
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.path(.element(id: id, action: .recipes(.delegate(.openShoppingList)))))
        await store.send(.moduleTapped(.movies))

        await clock.advance(by: .milliseconds(350))
        await store.receive(\.showShoppingList)
        #expect(store.state.path.count == 1)
        guard case .movies = store.state.path.first else {
            Issue.record("the person went to Movies; the list must not pull them away")
            return
        }
    }
}

@MainActor
@Suite("Saving a film from a round")
struct MovieHandoffTests {

    private static let dune = PollItem(
        id: "i1", externalID: "438631", label: "Dune", thumbnailURL: "/dune.jpg"
    )
    private static let wishlist = MovieList(id: "l1", name: "Wishlist", kind: .wishlist)
    private static let watched = MovieList(id: "l2", name: "Watched", kind: .watched)

    @Test("A poll candidate carries enough to open it as a film")
    func candidateBecomesAMovie() {
        let movie = Self.dune.asMovie
        // The TMDb id is the whole point — `catalog:details` fills in the rest.
        #expect(movie.id == "438631")
        #expect(movie.title == "Dune")
        #expect(movie.poster == "/dune.jpg")
    }

    @Test("A film already on a list shows as saved there and nowhere else")
    func membershipComesFromTheLiveList() async {
        let store = TestStore(
            initialState: MovieInfoFeature.State(homeID: "h1", movie: Self.dune.asMovie)
        ) { MovieInfoFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.listsUpdated([Self.wishlist, Self.watched]))
        await store.send(.savedUpdated([
            StoredMovie(id: "s1", imdbID: "438631", title: "Dune", homeID: "h1", listID: "l1"),
            // Another film on the other list must not tick this one.
            StoredMovie(id: "s2", imdbID: "999", title: "Barbie", homeID: "h1", listID: "l2"),
        ]))

        #expect(store.state.isSaved(in: Self.wishlist))
        #expect(!store.state.isSaved(in: Self.watched))
    }

    @Test("A chip files the film, and files it once")
    func chipSavesAndUnsaves() async {
        let added = LockIsolated<[MovieListID]>([])
        let removed = LockIsolated<[StoredMovieID]>([])

        let store = TestStore(
            initialState: MovieInfoFeature.State(homeID: "h1", movie: Self.dune.asMovie)
        ) { MovieInfoFeature() } withDependencies: {
            $0.movies.addMovie = { _, listID, _ in added.withValue { $0.append(listID) } }
            $0.movies.removeMovie = { id in removed.withValue { $0.append(id) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.listsUpdated([Self.wishlist]))
        await store.send(.listToggled(Self.wishlist))
        #expect(store.state.isBusy(Self.wishlist), "a second tap must not add it twice")
        await store.receive(\.writeFinished)
        #expect(added.value == ["l1"])
        #expect(!store.state.isBusy(Self.wishlist))

        // Once the subscription confirms it, the same chip takes it back off.
        await store.send(.savedUpdated([
            StoredMovie(id: "s1", imdbID: "438631", title: "Dune", homeID: "h1", listID: "l1"),
        ]))
        await store.send(.listToggled(Self.wishlist))
        await store.receive(\.writeFinished)
        #expect(removed.value == ["s1"])
    }

    @Test("Presets come before custom lists")
    func listOrder() async {
        let custom = MovieList(id: "l3", name: "Date night", kind: .custom)
        let store = TestStore(
            initialState: MovieInfoFeature.State(homeID: "h1", movie: Self.dune.asMovie)
        ) { MovieInfoFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.listsUpdated([custom, Self.watched, Self.wishlist]))
        #expect(store.state.orderedLists.map(\.id) == ["l1", "l2", "l3"])
    }

    @Test("A dinner vote is not a previous movie round")
    func dinnerRoundsStayOutOfMovieNight() async {
        let store = TestStore(
            initialState: MovieNightFeature.State(homeID: "h1", memberCount: 2)
        ) { MovieNightFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // Same machinery, different `kind`. Without the filter an open dinner
        // vote made this screen believe a film round was running.
        await store.send(.pollsUpdated([
            Poll(id: "p1", kind: .recipe, status: .active),
            Poll(id: "p2", kind: .movie, status: .closed),
            Poll(id: "p3", kind: .recipe, status: .closed),
        ]))

        #expect(!store.state.hasActivePoll)
        #expect(store.state.history.map(\.id) == ["p2"])
    }
}

@MainActor
@Suite("Built-in movie lists")
struct PresetListTests {

    @Test("A built-in list is named from its kind, not from the stored text")
    func presetsLocaliseFromKind() {
        // The row's `name` is whatever language the app was in when it was
        // written; `kind` is the key that survives a language change.
        let wishlist = MovieList(id: "l1", name: "Wishlist", kind: .wishlist, isPreset: true)
        #expect(wishlist.displayName == String(localized: L10n.movieListsWishlistTitle))

        let watched = MovieList(id: "l2", name: "Watched", kind: .watched, isPreset: true)
        #expect(watched.displayName == String(localized: L10n.movieListsWatchedTitle))
    }

    @Test("A list someone named themselves keeps its name")
    func customListsKeepTheirName() {
        let custom = MovieList(id: "l3", name: "Date night", summary: "For Fridays", kind: .custom)
        #expect(custom.displayName == "Date night")
        #expect(custom.displaySummary == "For Fridays")
        // And an empty description stays absent rather than becoming a label.
        let bare = MovieList(id: "l4", name: "Later", summary: "", kind: .custom)
        #expect(bare.displaySummary == nil)
    }

    @Test("A home with no built-in lists repairs itself on first look")
    func emptyHomeGetsItsPresets() async {
        let asked = LockIsolated<[HomeID]>([])
        let store = TestStore(initialState: MoviesFeature.State(homeID: "h1")) {
            MoviesFeature()
        } withDependencies: {
            $0.movies.ensurePresetLists = { id in asked.withValue { $0.append(id) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.listsUpdated([]))
        #expect(asked.value == ["h1"])
    }

    @Test("A home that already has them is left alone")
    func seededHomeIsNotTouched() async {
        let asked = LockIsolated<[HomeID]>([])
        let store = TestStore(initialState: MoviesFeature.State(homeID: "h1")) {
            MoviesFeature()
        } withDependencies: {
            $0.movies.ensurePresetLists = { id in asked.withValue { $0.append(id) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.listsUpdated([
            MovieList(id: "l1", name: "Wishlist", kind: .wishlist, isPreset: true),
            MovieList(id: "l2", name: "Watched", kind: .watched, isPreset: true),
        ]))
        #expect(asked.value.isEmpty)

        // And a later push must not turn into a write per update.
        await store.send(.listsUpdated([]))
        #expect(asked.value.isEmpty, "only the first look repairs; the rest just render")
    }
}

/// The phrasing behind every "3 min ago" label.
///
/// Seconds are deliberately absent: two notes written in the same breath used
/// to read "1 second ago" and "0 seconds ago" side by side, and then stay that
/// way for the rest of the session.
@Suite("Relative time")
struct RelativeTimeTests {

    /// `Text` has no readable content, so the phrasing is checked through the
    /// same resolved strings the view renders.
    private func phrase(_ secondsAgo: TimeInterval) -> String {
        let now = Date(timeIntervalSince1970: 1_757_000_000)
        let then = now.addingTimeInterval(-secondsAgo)
        let seconds = now.timeIntervalSince(then)

        if seconds < 60 { return String(localized: L10n.timeJustNow) }
        let minutes = Int(seconds) / 60
        if minutes < 60 { return String(localized: L10n.timeMinutesAgo(minutes)) }
        let hours = minutes / 60
        if hours < 24 { return String(localized: L10n.timeHoursAgo(hours)) }
        let days = hours / 24
        if days < 7 { return String(localized: L10n.timeDaysAgo(days)) }
        return then.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
        )
    }

    @Test("Anything under a minute is just now, seconds and all")
    func secondsAreNeverSpelledOut() {
        for age in [0.0, 1, 2, 30, 59] {
            #expect(phrase(age) == String(localized: L10n.timeJustNow))
        }
    }

    @Test("A clock that disagrees with the server does not produce the future")
    func futureTimestampsReadAsJustNow() {
        #expect(phrase(-2) == String(localized: L10n.timeJustNow))
    }

    @Test("Minutes, then hours, then days")
    func coarsensAsItAges() {
        #expect(phrase(60) == "1 min ago")
        #expect(phrase(119) == "1 min ago")
        #expect(phrase(120) == "2 min ago")
        #expect(phrase(59 * 60) == "59 min ago")
        #expect(phrase(60 * 60) == "1 h ago")
        #expect(phrase(23 * 3600) == "23 h ago")
        #expect(phrase(24 * 3600) == "1 d ago")
        #expect(phrase(6 * 24 * 3600) == "6 d ago")
    }

    @Test("Past a week the date itself is the more useful answer")
    func oldRowsShowADate() {
        let weekOld = phrase(7 * 24 * 3600)
        #expect(!weekOld.hasSuffix("ago"))
    }
}

// MARK: - Messages

@MainActor
@Suite("Messages")
struct MessagesTests {

    private func chat(
        _ conversation: Conversation = Conversation(id: "c1", participants: ["me", "them"]),
        me: UserID? = "me",
        draft: String = ""
    ) -> ChatFeature.State {
        var state = ChatFeature.State(
            conversation: conversation,
            title: "Them",
            currentUserID: me,
            members: [User(id: "me", name: "Me"), User(id: "them", name: "Them")]
        )
        state.draft = draft
        return state
    }

    @Test("A sent message is on screen before the server has heard of it")
    func sendIsOptimistic() async {
        let store = TestStore(initialState: chat(draft: "hello")) { ChatFeature() } withDependencies: {
            $0.messages.send = { _, _ in "m1" }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sendTapped) {
            $0.draft = ""
            $0.pendingSeq = 1
            $0.pending = [.init(id: "pending:1", content: "hello", senderID: "me")]
        }
        // The bubble is in the thread immediately, ahead of any subscription push.
        #expect(store.state.ordered.map(\.content) == ["hello"])
        #expect(store.state.isPending(store.state.ordered[0]))

        await store.receive(\.sendSucceeded)
        // Still shown — it is retired by its echo, not by the reply.
        #expect(store.state.pending.count == 1)
        #expect(store.state.pending[0].serverID == MessageID("m1"))

        await store.send(.messagesUpdated([
            Message(id: "m1", senderID: "me", content: "hello", readBy: ["me"])
        ]))
        #expect(store.state.pending.isEmpty)
        #expect(store.state.ordered.map(\.id) == [MessageID("m1")])
    }

    @Test("An echo that beats the reply does not leave the message on screen twice")
    func echoBeatsTheReply() async {
        // The mutation is held open so the subscription genuinely wins the race:
        // Convex commits the write before it answers the caller, so the push can
        // and does arrive first.
        let reply = AsyncStream<Void>.makeStream()
        let store = TestStore(initialState: chat(draft: "hi")) { ChatFeature() } withDependencies: {
            $0.messages.send = { _, _ in
                for await _ in reply.stream { break }
                return "m1"
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sendTapped)
        await store.send(.messagesUpdated([
            Message(id: "m1", senderID: "me", content: "hi", readBy: ["me"])
        ]))
        // The optimistic bubble has no server id yet, so the push cannot retire
        // it — this is the moment the message was on screen twice.
        #expect(store.state.ordered.count == 2)

        reply.continuation.finish()
        await store.receive(\.sendSucceeded)

        #expect(store.state.pending.isEmpty)
        #expect(store.state.ordered.count == 1)
    }

    @Test("A failed send keeps the text, and can be retried")
    func failedSendKeepsTheText() async {
        let attempts = LockIsolated(0)
        let store = TestStore(initialState: chat(draft: "important")) { ChatFeature() } withDependencies: {
            $0.messages.send = { _, _ in
                let n = attempts.withValue { $0 += 1; return $0 }
                if n == 1 { throw AppError.server("nope") }
                return "m1"
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sendTapped)
        await store.receive(\.sendFailed)

        // Not swallowed with the cleared draft: the words are still on screen.
        #expect(store.state.ordered.map(\.content) == ["important"])
        #expect(store.state.hasFailed(store.state.ordered[0]))

        await store.send(.retryTapped("pending:1"))
        await store.receive(\.sendSucceeded)
        #expect(!store.state.hasFailed(store.state.ordered[0]))
        #expect(attempts.value == 2)
    }

    @Test("Read receipts are sent for unread messages only")
    func readReceiptsDoNotLoop() async {
        let marked = LockIsolated(0)
        let store = TestStore(initialState: chat()) { ChatFeature() } withDependencies: {
            $0.messages.markRead = { _ in marked.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let unread = Message(id: "m1", senderID: "them", content: "yo", readBy: ["them"])
        await store.send(.messagesUpdated([unread]))
        await store.finish()
        #expect(marked.value == 1)

        // markRead writes, the write pushes the subscription, and the push must
        // not answer with another markRead.
        var read = unread
        read.readBy = ["them", "me"]
        await store.send(.messagesUpdated([read]))
        await store.finish()
        #expect(marked.value == 1)

        // My own messages were never unread to begin with.
        await store.send(.messagesUpdated([
            read, Message(id: "m2", senderID: "me", content: "hey", readBy: ["me"]),
        ]))
        await store.finish()
        #expect(marked.value == 1)
    }

    @Test("Bubbles read oldest first, with anything in flight last")
    func threadOrder() {
        var state = chat()
        state.messages = [
            Message(id: "m2", senderID: "me", content: "second", created: .init(milliseconds: 200)),
            Message(id: "m1", senderID: "them", content: "first", created: .init(milliseconds: 100)),
        ]
        state.pending = [.init(id: "pending:1", content: "third", senderID: "me")]
        #expect(state.ordered.map(\.content) == ["first", "second", "third"])

        let thread = state.ordered
        #expect(state.startsGroup(at: 0, in: thread))
        #expect(state.startsGroup(at: 1, in: thread))   // them -> me
        #expect(!state.startsGroup(at: 2, in: thread))  // me -> me
    }

    @Test("Creating a conversation opens it, without waiting for the subscription")
    func createOpensTheThread() async {
        let made = Conversation(id: "c9", participants: ["me", "them"], isGroupChat: false)
        var state = MessagesFeature.State(homeID: "h1", currentUserID: "me")
        state.members = [User(id: "me", name: "Me"), User(id: "them", name: "Them")]
        state.destination = .compose(NewConversationFeature.State(
            homeID: "h1", currentUserID: "me", members: state.members
        ))

        let store = TestStore(initialState: state) { MessagesFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.destination(.presented(.compose(.finished(made))))) {
            $0.destination = nil
            $0.conversations = [made]
        }
        #expect(store.state.path.count == 1)
        guard case let .chat(chat) = store.state.path[0] else {
            Issue.record("expected the new conversation to be pushed")
            return
        }
        #expect(chat.conversation.id == ConversationID("c9"))
        #expect(chat.title == "Them")
    }

    @Test("Members arriving late reach the thread that is already open")
    func membersReachOpenChats() async {
        var state = MessagesFeature.State(homeID: "h1", currentUserID: "me")
        let conversation = Conversation(id: "c1", participants: ["me", "them"])
        // Opened before `homes:members` had yielded — the title falls back.
        state.path.append(.chat(ChatFeature.State(
            conversation: conversation,
            title: state.title(for: conversation),
            currentUserID: "me",
            members: []
        )))

        let store = TestStore(initialState: state) { MessagesFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.membersUpdated([User(id: "me", name: "Me"), User(id: "them", name: "Them")]))

        guard case let .chat(chat) = store.state.path[0] else {
            Issue.record("expected a chat on the stack")
            return
        }
        #expect(chat.members.count == 2)
        #expect(chat.title == "Them")
        #expect(chat.senderName(for: Message(id: "m1", senderID: "them", content: "x")) == "Them")
    }

    @Test("Your bubbles are on the right, theirs on the left")
    func bubbleSides() {
        var state = chat()
        let mine = Message(id: "m1", senderID: "me", content: "mine")
        let theirs = Message(id: "m2", senderID: "them", content: "theirs")
        state.messages = [mine, theirs]
        #expect(state.isMine(mine))
        #expect(!state.isMine(theirs))

        // A bubble still in flight is yours by construction: deciding on
        // senderID alone put your own message on the left until the session
        // had propagated.
        var noSession = chat(me: nil)
        noSession.pending = [.init(id: "pending:1", content: "sending", senderID: "")]
        #expect(noSession.isMine(noSession.ordered[0]))
        #expect(!noSession.isMine(theirs))
    }

    @Test("An untitled group is named after the house, not its roster")
    func groupTitleIsTheHouse() {
        var state = MessagesFeature.State(homeID: "h1", currentUserID: "me")
        state.homeName = "Walhalla"
        state.members = [
            User(id: "me", name: "Me"),
            User(id: "a", name: "Ada"),
            User(id: "b", name: "Grace"),
        ]

        let group = Conversation(
            id: "c1", participants: ["me", "a", "b"], isGroupChat: true
        )
        #expect(state.title(for: group) == "Walhalla Chat")

        // A 1:1 is still named after the person — short, and the useful answer.
        let direct = Conversation(id: "c2", participants: ["me", "a"])
        #expect(state.title(for: direct) == "Ada")

        // A name the household chose always wins.
        var named = group
        named.title = "Kitchen"
        #expect(state.title(for: named) == "Kitchen")

        // No home name yet: a generic fallback, never an empty title.
        state.homeName = nil
        #expect(!state.title(for: group).isEmpty)
        #expect(state.title(for: group) != " Chat")
    }

    @Test("Editing rewrites the bubble, and puts it back if the server refuses")
    func editThroughTheComposer() async {
        let saved = LockIsolated<[String]>([])
        var state = chat()
        state.messages = [Message(id: "m1", senderID: "me", content: "helo", readBy: ["me"])]

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            $0.messages.edit = { _, text in saved.withValue { $0.append(text) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.editTapped("m1"))
        // The composer is loaded with the message, not left empty.
        #expect(store.state.draft == "helo")
        #expect(store.state.isEditing)

        await store.send(.binding(.set(\.draft, "hello")))
        await store.send(.sendTapped)
        await store.finish()

        #expect(saved.value == ["hello"])
        #expect(store.state.messages[id: MessageID("m1")]?.content == "hello")
        #expect(!store.state.isEditing)
        #expect(store.state.draft.isEmpty)
        // An edit is not a new message.
        #expect(store.state.pending.isEmpty)
        #expect(store.state.ordered.count == 1)
    }

    @Test("A rejected edit restores the original text")
    func failedEditRestores() async {
        var state = chat()
        state.messages = [Message(id: "m1", senderID: "me", content: "original", readBy: ["me"])]

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            $0.messages.edit = { _, _ in throw AppError.server("no") }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.editTapped("m1"))
        await store.send(.binding(.set(\.draft, "rewritten")))
        await store.send(.sendTapped)
        #expect(store.state.messages[id: MessageID("m1")]?.content == "rewritten")

        await store.receive(\.editFailed, timeout: .seconds(5))
        #expect(store.state.messages[id: MessageID("m1")]?.content == "original")
        #expect(store.state.alert != nil)
    }

    @Test("A deleted message goes at once, and comes back if the delete fails")
    func deleteIsOptimistic() async {
        let outcome = LockIsolated(true)
        var state = chat()
        state.messages = [
            Message(id: "m1", senderID: "me", content: "one", readBy: ["me"]),
            Message(id: "m2", senderID: "me", content: "two", readBy: ["me"]),
        ]

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            $0.messages.delete = { _ in
                if !outcome.value { throw AppError.server("no") }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.deleteTapped("m1"))
        #expect(store.state.ordered.map(\.id) == [MessageID("m2")])
        await store.finish()

        // A push that still carries the row must not blink it back on screen.
        await store.send(.messagesUpdated(Array(state.messages)))
        #expect(store.state.ordered.map(\.id) == [MessageID("m2")])

        // Once the server has really dropped it, the hold is released.
        await store.send(.messagesUpdated([state.messages[1]]))
        #expect(store.state.deleting.isEmpty)

        // A failed delete has no push coming to undo it, so it restores itself.
        outcome.setValue(false)
        await store.send(.deleteTapped("m2"))
        #expect(store.state.ordered.isEmpty)
        await store.receive(\.deleteFailed, timeout: .seconds(5))
        #expect(store.state.ordered.map(\.id) == [MessageID("m2")])
    }

    @Test("Only your own delivered messages offer edit and delete")
    func whatCanBeModified() {
        var state = chat()
        let mine = Message(id: "m1", senderID: "me", content: "mine")
        let theirs = Message(id: "m2", senderID: "them", content: "theirs")
        state.messages = [mine, theirs]
        state.pending = [.init(id: "pending:1", content: "in flight", senderID: "me")]

        #expect(state.canModify(mine))
        #expect(!state.canModify(theirs))
        // Nothing to edit or delete about a message the server has not stored.
        #expect(!state.canModify(state.pending[0].message))
    }

    @Test("Renaming a thread reaches the list it was opened from")
    func renameReachesTheList() async {
        let renamed = Conversation(
            id: "c1", participants: ["me", "them"], isGroupChat: true, title: "Kitchen"
        )
        var state = MessagesFeature.State(homeID: "h1", currentUserID: "me")
        state.homeName = "Walhalla"
        state.conversations = [Conversation(id: "c1", participants: ["me", "them"], isGroupChat: true)]
        state.path.append(.chat(ChatFeature.State(
            conversation: state.conversations[0],
            title: "Walhalla Chat",
            currentUserID: "me",
            members: []
        )))

        let store = TestStore(initialState: state) { MessagesFeature() } withDependencies: {
            $0.messages.rename = { _, _ in renamed }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.path(.element(id: 0, action: .chat(.renameTapped))))
        guard case let .chat(seeded) = store.state.path[0] else {
            Issue.record("expected a chat on the stack")
            return
        }
        // Seeded with what is on screen, so renaming is an edit, not a retype.
        #expect(seeded.renameDraft == "Walhalla Chat")
        #expect(seeded.isRenaming)

        await store.send(.path(.element(id: 0, action: .chat(.binding(.set(\.renameDraft, "Kitchen"))))))
        await store.send(.path(.element(id: 0, action: .chat(.renameSubmitted))))
        // Generous timeouts: these ride on a real effect, and the default is
        // short enough to flake when the whole suite is running at once.
        await store.receive(\.path[id: 0].chat.renameFinished, timeout: .seconds(5))
        await store.receive(\.path[id: 0].chat.delegate.renamed, timeout: .seconds(5))

        #expect(store.state.conversations[id: ConversationID("c1")]?.title == "Kitchen")
        guard case let .chat(after) = store.state.path[0] else { return }
        #expect(after.title == "Kitchen")
        #expect(!after.isRenaming)
    }

    @Test("Renaming to the name already on screen is not a write")
    func renamingToTheDefaultIsANoOp() async {
        let calls = LockIsolated(0)
        var state = chat()
        state.title = "Walhalla Chat"   // the default, not a stored title

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            $0.messages.rename = { _, _ in
                calls.withValue { $0 += 1 }
                return Conversation(id: "c1")
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.renameTapped)
        await store.send(.renameSubmitted)
        await store.finish()
        // Accepting the prefilled default must not pin it as a real title.
        #expect(calls.value == 0)
    }

    @Test("You are never in your own participant picker")
    func pickerExcludesYou() {
        let state = NewConversationFeature.State(
            homeID: "h1",
            currentUserID: "me",
            members: [User(id: "me", name: "Me"), User(id: "them", name: "Them")]
        )
        #expect(state.selectableMembers.map(\.id) == [UserID("them")])
        #expect(!state.hasNobodyToMessage)
        #expect(!state.canSubmit)

        let alone = NewConversationFeature.State(
            homeID: "h1", currentUserID: "me", members: [User(id: "me", name: "Me")]
        )
        #expect(alone.hasNobodyToMessage)
    }

    @Test("Two people is a chat; three is a group")
    func groupThreshold() async {
        let sent = LockIsolated<[(HomeID, [UserID], String?, Bool)]>([])
        let store = TestStore(
            initialState: NewConversationFeature.State(
                homeID: "h1",
                currentUserID: "me",
                members: [
                    User(id: "me", name: "Me"),
                    User(id: "a", name: "A"),
                    User(id: "b", name: "B"),
                ]
            )
        ) { NewConversationFeature() } withDependencies: {
            $0.messages.createConversation = { home, participants, title, isGroup in
                sent.withValue { $0.append((home, participants, title, isGroup)) }
                return Conversation(id: "c1", participants: participants, isGroupChat: isGroup)
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.memberToggled("a"))
        #expect(!store.state.isGroup)
        await store.send(.memberToggled("b"))
        #expect(store.state.isGroup)

        await store.send(.submitTapped)
        await store.receive(\.finished)
        // Not left stuck mid-submit for a parent that keeps the state around.
        #expect(!store.state.isSubmitting)

        let call = sent.value[0]
        #expect(call.1 == [UserID("a"), UserID("b"), UserID("me")])
        #expect(call.2 == nil)      // a blank group name is not sent
        #expect(call.3)
    }
}
