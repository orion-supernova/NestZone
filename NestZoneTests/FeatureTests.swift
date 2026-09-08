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
            $0.loaded.insert(.tasks)
            $0.tasks = [task]
        }

        await store.send(.taskToggled("t1")) {
            $0.tasks[id: "t1"]?.isCompleted = true
        }

        #expect(confirmed.value.count == 1)
        #expect(confirmed.value[0].1 == true)
    }

    @Test("A failed toggle puts the checkbox back")
    func failedToggleRestoresTheCheckbox() async {
        let task = HouseTask(id: "t1", title: "Dishes")
        let store = TestStore(
            initialState: HomeFeature.State(homeID: "h1")
        ) {
            HomeFeature()
        } withDependencies: {
            $0.tasks.setCompleted = { _, _ in throw AppError.offline }
        }

        await store.send(.tasksUpdated([task])) {
            $0.loaded.insert(.tasks)
            $0.tasks = [task]
        }
        await store.send(.taskToggled("t1")) {
            $0.tasks[id: "t1"]?.isCompleted = true
        }
        // A refused write leaves the server unchanged, so no push is coming to
        // correct the checkbox — the reducer has to put it back itself, or the
        // row reads "done" over a task nobody did.
        await store.receive(\.toggleFailed) {
            $0.tasks[id: "t1"]?.isCompleted = false
            $0.alert = .failure(.offline)
        }
    }

    @Test("A dinner already decided can still become an occasion")
    func decidedDinnerCanBecomeAnOccasion() async {
        let recipe = Recipe(id: "r1", title: "Lasagne", ingredients: ["Pasta"], homeID: "h1")
        let day = MealDate.today
        let plan = MealPlan(id: "m1", homeID: "h1", kind: .cook, recipe: recipe, date: day)
        let planned = LockIsolated<[DinnerDecision]>([])

        let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
            HomeFeature()
        } withDependencies: {
            $0.meals.set = { decision in planned.withValue { $0.append(decision) } }
        }
        store.exhaustivity = .off

        await store.send(.mealsUpdated([plan]))
        await store.send(.membersUpdated([User(id: "u1", name: "Ada"), User(id: "u2", name: "Bea")]))

        await store.send(.makeOccasionTapped)
        // The composer, not a silent write: an occasion needs a time, and the
        // Dinner sheet's toggle only ever covered the case where somebody knew
        // in advance.
        guard let composer = store.state.occasion else {
            Issue.record("expected the event composer to open")
            return
        }
        #expect(composer.kind == .dinnerParty)
        #expect(composer.title == "Lasagne")
        // The dish arrives as the menu, which is what makes the shopping list
        // and the budget work on the other side.
        #expect(composer.recipeIDs == ["r1"])
        #expect(composer.sections.contains(.menu))
        #expect(composer.attendees == ["u1", "u2"])

        await store.send(.occasion(.presented(.delegate(.saved("e-new")))))
        await store.receive(\.occasionLinked)

        // The link is written second: the event exists, so the plan has
        // something to point at, and it keeps every field it already had.
        #expect(planned.value.count == 1)
        #expect(planned.value[0].eventID == "e-new")
        #expect(planned.value[0].recipeID == "r1")
        #expect(planned.value[0].date == day)
    }

    @Test("A meal already part of an occasion is not offered another")
    func linkedDinnerIsNotOfferedAgain() async {
        let plan = MealPlan(
            id: "m1",
            homeID: "h1",
            kind: .cook,
            title: "Lasagne",
            date: MealDate.today,
            event: MealPlan.LinkedEvent(id: "e1", title: "Birthday")
        )
        let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.mealsUpdated([plan]))
        await store.send(.makeOccasionTapped)
        #expect(store.state.occasion == nil)
    }

    @Test("The Home tab surfaces what is on now and what is next")
    func upcomingEventsReachTheHomeTab() async {
        let now = Date()
        let inProgress = EventOccurrence(
            eventID: "e1",
            title: "Dinner party",
            kind: .dinnerParty,
            startsAt: Timestamp(now.addingTimeInterval(-3600)),
            endsAt: Timestamp(now.addingTimeInterval(3600))
        )
        let soon = EventOccurrence(
            eventID: "e2",
            title: "Concert",
            kind: .concert,
            startsAt: Timestamp(now.addingTimeInterval(3 * 24 * 3600)),
            endsAt: Timestamp(now.addingTimeInterval(3 * 24 * 3600 + 7200))
        )
        let faraway = EventOccurrence(
            eventID: "e3",
            title: "Trip",
            kind: .trip,
            startsAt: Timestamp(now.addingTimeInterval(30 * 24 * 3600)),
            endsAt: Timestamp(now.addingTimeInterval(33 * 24 * 3600))
        )

        let store = TestStore(initialState: HomeFeature.State(homeID: "h1")) {
            HomeFeature()
        }

        await store.send(.upcomingEventsUpdated([inProgress, soon, faraway])) {
            $0.upcoming = [inProgress, soon, faraway]
        }

        // "3 events" is a figure; "the party is happening" is a fact, and only
        // one of them stops being true while you are looking at it.
        #expect(store.state.happeningNow?.id == inProgress.id)
        #expect(store.state.nextEvent?.id == soon.id)
        // The tile counts the week, not the whole agenda — a month-away trip is
        // not asking for anything today.
        #expect(store.state.eventsThisWeek == 2)

        // An identical push must not invalidate every view reading the card:
        // Convex re-publishes the whole query set on any change, so this lands
        // far more often than the calendar actually moves.
        await store.send(.upcomingEventsUpdated([inProgress, soon, faraway]))
    }

    @Test("Opening an event from the Home tab lands on the calendar, on its day")
    func openingAnEventSwitchesTabsAndPushes() async {
        let start = Date().addingTimeInterval(4 * 24 * 3600)
        let occurrence = EventOccurrence(
            eventID: "e1",
            title: "Concert",
            startsAt: Timestamp(start),
            endsAt: Timestamp(start.addingTimeInterval(7200))
        )
        let store = TestStore(
            initialState: MainFeature.State(homeID: "h1", user: User(id: "u1", name: "Ada"))
        ) {
            MainFeature()
        }
        store.exhaustivity = .off

        await store.send(.home(.delegate(.openEvent(occurrence))))
        // The calendar is a Hub module, so this is both a tab switch and a push.
        #expect(store.state.selectedTab == .hub)
        guard case .calendar(let calendar) = store.state.hub.path.last else {
            Issue.record("expected the calendar to be pushed")
            return
        }
        // Opened on the event's own day, so the grid behind the sheet is showing
        // what was tapped rather than today.
        #expect(calendar.selectedDay == CalendarDay(start))
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
            // Every section stops waiting, not just the one that failed.
            $0.loaded = [.stats, .tasks, .upcoming]
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
            $0.loaded.insert(.tasks)
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
            $0.$cachedHomes.withLock { $0 = [home] }
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
            $0.$cachedHomes.withLock { $0 = homes }
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
            $0.$cachedHomes.withLock { $0 = remaining }
            $0.$selectedHomeIDRaw.withLock { $0 = nil }
        }
    }

    @Test("A cached home list opens the gate without waiting for the network")
    func cachedHomesSeedTheGate() async {
        let home = Home(id: "h1", name: "The Nest")
        @Shared(.cachedHomes) var cachedHomes: [Home]
        $cachedHomes.withLock { $0 = [home] }

        // What the launch screen reads. `isLoading` staying true here is what
        // used to hold the splash up for a websocket connect, a token exchange
        // and a query round trip, on a device that already knew the answer.
        let state = HomeManagementFeature.State()
        #expect(state.homes == [home])
        #expect(state.isLoading == false)
    }

    @Test("With nothing cached the gate still waits, rather than claiming no homes")
    func emptyCacheStillLoads() async {
        let state = HomeManagementFeature.State()
        #expect(state.isLoading)
        // `isEmpty` is what draws "let's get started", and an unanswered
        // subscription must never look like an answer of "none".
        #expect(!state.isEmpty)
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
            $0.$cachedHomes.withLock { $0 = [home] }
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

    @Test("A refused tick goes back to how it was")
    func failedToggleRestoresTheTick() async {
        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.setPurchased = { _, _ in throw AppError.offline }
        }

        await store.send(.itemsUpdated([Self.milk])) {
            $0.isLoading = false
            $0.items = [Self.milk]
        }
        await store.send(.togglePurchased("s1")) {
            $0.items[id: "s1"]?.isPurchased = true
        }
        // Nothing changed on the server, so nothing is coming to undo this.
        await store.receive(\.toggleFailed) {
            $0.items[id: "s1"]?.isPurchased = false
        }
        await store.receive(\.writeFailed) {
            $0.alert = .failure(.offline)
        }
    }

    @Test("A refused add gives the typed words back")
    func failedAddRestoresTheDraft() async {
        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        } withDependencies: {
            $0.shopping.create = { _ in throw AppError.offline }
        }

        await store.send(.binding(.set(\.draft, "Oat milk"))) {
            $0.draft = "Oat milk"
        }
        await store.send(.addTapped) {
            $0.draft = ""
            $0.pendingAdds = 1
        }
        await store.receive(\.addFinished) {
            $0.pendingAdds = 0
        }
        // Losing what somebody typed is the one failure they cannot recover
        // from themselves.
        await store.receive(\.addFailed) {
            $0.draft = "Oat milk"
        }
        await store.receive(\.writeFailed) {
            $0.alert = .failure(.offline)
        }
    }

    @Test("A refused add does not shove itself over something newer")
    func failedAddKeepsWhatIsBeingTyped() async {
        let store = TestStore(initialState: ShoppingFeature.State(homeID: "h1")) {
            ShoppingFeature()
        }

        // Somebody who has already started the next item would rather keep it
        // than have the rejected one land on top of what they are typing.
        await store.send(.binding(.set(\.draft, "Bread"))) {
            $0.draft = "Bread"
        }
        await store.send(.addFailed("Oat milk", .offline))
        await store.receive(\.writeFailed) {
            $0.alert = .failure(.offline)
        }
        #expect(store.state.draft == "Bread")
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
            $0.lastSwipe = MovieNightFeature.State.Swipe(item: item, isYes: true)
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

    @Test("Undo takes the last swipe back, once")
    func undoReturnsTheCard() async {
        let retracted = LockIsolated<[String]>([])
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")
        let first = PollItem(id: "i1", externalID: "dune", label: "Dune")
        let second = PollItem(id: "i2", externalID: "arrival", label: "Arrival")
        state.deck = [first, second]

        let store = TestStore(initialState: state) {
            MovieNightFeature()
        } withDependencies: {
            $0.polls.vote = { _, _, _ in }
            $0.polls.unvote = { _, external in
                retracted.withValue { $0.append(external) }
            }
        }

        await store.send(.swiped(first, isYes: false)) {
            $0.swiped = ["dune"]
            $0.lastSwipe = MovieNightFeature.State.Swipe(item: first, isYes: false)
        }
        #expect(store.state.remaining.map(\.externalID) == ["arrival"])

        await store.send(.undoTapped) {
            $0.swiped = []
            $0.lastSwipe = nil
            $0.restoring = first
        }
        // Back on top, and the vote is gone from the server too.
        #expect(store.state.remaining.map(\.externalID) == ["dune", "arrival"])
        #expect(retracted.value == ["dune"])

        // One step only: the button has nothing left to undo.
        #expect(!store.state.canUndo)
        await store.send(.undoTapped)
    }

    @Test("A confirmed vote does not undo the undo")
    func restoredCardSurvivesADetailPush() async {
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")
        let item = PollItem(id: "i1", externalID: "dune", label: "Dune")
        state.deck = [item]
        state.restoring = item

        let store = TestStore(initialState: state) { MovieNightFeature() }

        // The push still carries the vote the retraction has not reached yet.
        let stale = PollDetail(
            poll: Poll(id: "p1"),
            items: [item],
            votes: [],
            myVotes: [PollVote(id: "v1", targetExternalID: "dune", isYes: false, userID: "u1")]
        )
        await store.send(.detailUpdated(stale)) {
            $0.isLoading = false
            $0.detail = stale
            // `unvotedItems` drops it; the marker puts it back.
            $0.deck = [item]
        }
        #expect(store.state.remaining.map(\.externalID) == ["dune"])

        // Once the retraction lands the marker is spent.
        let settled = PollDetail(poll: Poll(id: "p1"), items: [item], votes: [], myVotes: [])
        await store.send(.detailUpdated(settled)) {
            $0.detail = settled
            $0.deck = [item]
            $0.restoring = nil
        }
    }

    @Test("The counter measures the round, not what is left of it")
    func positionCountsTheWholeRound() async {
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")
        let items = (1...18).map { PollItem(id: "i\($0)", externalID: "m\($0)") }
        state.detail = PollDetail(poll: Poll(id: "p1"), items: items)
        state.deck = items

        #expect(state.roundSize == 18)
        #expect(state.position == 1)

        // Six answered: the seventh card is on top, and the total holds.
        state.swiped = Set(items.prefix(6).map(\.externalID))
        #expect(state.position == 7)
        #expect(state.roundSize == 18)

        // The deck shrinking as votes confirm must not shrink the total with it.
        state.deck = Array(items.dropFirst(6))
        state.swiped = []
        #expect(state.position == 7)
        #expect(state.roundSize == 18)
    }

    @Test("An open round with no cards yet is loading, not finished")
    func emptyDeckBeforeDetailIsNotTheEnd() async {
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")

        // The round is on the list stream; its candidates are not here yet.
        #expect(state.hasActivePoll)
        #expect(state.isAwaitingDeck)
        #expect(!state.isDeckFinished)

        // The detail lands with cards: a deck, still not the end.
        let item = PollItem(id: "i1", externalID: "dune")
        state.detail = PollDetail(poll: Poll(id: "p1"), items: [item])
        state.deck = [item]
        #expect(!state.isAwaitingDeck)
        #expect(!state.isDeckFinished)

        // Answered: now it is the end.
        state.swiped = ["dune"]
        #expect(state.isDeckFinished)
    }

    @Test("Finishing your own deck is waiting, not ending")
    func waitsForTheRestOfTheHouse() async {
        let dune = PollItem(id: "i1", externalID: "dune")
        let arrival = PollItem(id: "i2", externalID: "arrival")

        func vote(_ user: UserID, _ target: String) -> PollVote {
            PollVote(id: "\(user)-\(target)", targetExternalID: target, isYes: true, userID: user)
        }

        var state = MovieNightFeature.State(homeID: "h1", memberCount: 3, currentUserID: "u1")
        state.poll = Poll(id: "p1")
        // One person all the way through, another halfway.
        state.detail = PollDetail(
            poll: Poll(id: "p1"),
            items: [dune, arrival],
            votes: [vote("u1", "dune"), vote("u1", "arrival"), vote("u2", "dune")],
            myVotes: [vote("u1", "dune"), vote("u1", "arrival")]
        )
        state.deck = []

        #expect(state.isDeckFinished)
        // Half a deck is not a finished one.
        #expect(state.finishedCount == 1)
        #expect(!state.everyoneFinished)

        // The last two catch up.
        state.detail?.votes.append(contentsOf: [
            vote("u2", "arrival"), vote("u3", "dune"), vote("u3", "arrival"),
        ])
        #expect(state.finishedCount == 3)
        #expect(state.everyoneFinished)
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

    @Test("Holding a bubble opens its actions, and only its own")
    func bubbleActions() async {
        var state = chat()
        state.messages = [
            Message(id: "m1", senderID: "me", content: "mine", readBy: ["me"]),
            Message(id: "m2", senderID: "them", content: "theirs", readBy: ["them"]),
        ]

        let store = TestStore(initialState: state) { ChatFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.bubbleHeld("m1")) { $0.actionsFor = "m1" }
        // Holding it again puts the bar away rather than reopening it.
        await store.send(.bubbleHeld("m1")) { $0.actionsFor = nil }

        // Somebody else's message has nothing to offer.
        await store.send(.bubbleHeld("m2"))
        #expect(store.state.actionsFor == nil)

        // Acting on the bar closes it.
        await store.send(.bubbleHeld("m1")) { $0.actionsFor = "m1" }
        await store.send(.editTapped("m1"))
        #expect(store.state.actionsFor == nil)
        #expect(store.state.editing == MessageID("m1"))

        await store.send(.editCancelled)
        await store.send(.bubbleHeld("m1")) { $0.actionsFor = "m1" }
        await store.send(.actionsDismissed) { $0.actionsFor = nil }
    }

    @Test("Tapping the thread backs out of the editor as well as the bar")
    func backgroundTapClosesEverything() async {
        var state = chat()
        state.messages = [Message(id: "m1", senderID: "me", content: "mine", readBy: ["me"])]

        let store = TestStore(initialState: state) { ChatFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.bubbleHeld("m1")) { $0.actionsFor = "m1" }
        await store.send(.editTapped("m1"))
        #expect(store.state.isEditing)

        await store.send(.backgroundTapped)
        // The banner and its half-typed text go together; leaving the editor
        // running once the bar and the keyboard had gone read as stuck.
        #expect(!store.state.isEditing)
        #expect(store.state.draft.isEmpty)
        #expect(store.state.actionsFor == nil)

        // With nothing open it is just a keyboard dismissal, and must not
        // disturb a draft that was being written from scratch.
        await store.send(.binding(.set(\.draft, "half a thought")))
        await store.send(.backgroundTapped)
        #expect(store.state.draft == "half a thought")
    }

    @Test("A bar left open over a message that is gone closes itself")
    func actionsFollowTheirMessage() async {
        var state = chat()
        state.messages = [Message(id: "m1", senderID: "me", content: "mine", readBy: ["me"])]
        state.actionsFor = "m1"

        let store = TestStore(initialState: state) { ChatFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // Deleted from another device.
        await store.send(.messagesUpdated([]))
        #expect(store.state.actionsFor == nil)
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

@MainActor
@Suite("Finance")
struct FinanceTests {

    private static let ada = User(id: "u1", name: "Ada")
    private static let grace = User(id: "u2", name: "Grace")
    private static let members: IdentifiedArrayOf<User> = [ada, grace]

    private static func expense(
        _ id: ExpenseID,
        _ title: String,
        _ amount: Int = 1_000
    ) -> Expense {
        Expense(
            id: id,
            title: title,
            amount: amount,
            currency: "EUR",
            paidBy: "u1",
            splits: [
                ExpenseSplit(userID: "u1", amount: amount / 2),
                ExpenseSplit(userID: "u2", amount: amount / 2),
            ],
            spentAt: Timestamp(milliseconds: 1_756_000_000_000)
        )
    }

    private static func summary(
        _ month: CalendarMonth,
        adaNet: Int = 0
    ) -> FinanceSummary {
        FinanceSummary(
            year: month.year,
            month: month.month,
            currency: "EUR",
            monthTotal: 1_000,
            members: [
                MemberFinance(userID: "u1", name: "Ada", net: adaNet),
                MemberFinance(userID: "u2", name: "Grace", net: -adaNet),
            ],
            transfers: adaNet > 0
                ? [Transfer(from: "u2", to: "u1", amount: adaNet)]
                : []
        )
    }

    /// A store with every subscription the screen opens stubbed, because
    /// `.task` fans out to five of them and an unimplemented one is a failure
    /// rather than an empty stream.
    private static func financeStore(
        asked: LockIsolated<[CalendarMonth]> = LockIsolated([]),
        removed: LockIsolated<[ExpenseID]> = LockIsolated([]),
        paid: LockIsolated<[BillID]> = LockIsolated([]),
        expenses: LockIsolated<[CalendarMonth: [Expense]]> = LockIsolated([:]),
        clock: TestClock<Duration> = TestClock()
    ) -> TestStoreOf<FinanceFeature> {
        TestStore(
            initialState: FinanceFeature.State(homeID: "h1", currentUserID: "u1")
        ) {
            FinanceFeature()
        } withDependencies: {
            $0.finance.summary = { _, month, _ in
                asked.withValue { $0.append(month) }
                return AsyncThrowingStream { $0.yield(Self.summary(month)) }
            }
            $0.finance.expenses = { _, month in
                AsyncThrowingStream { $0.yield(expenses.value[month] ?? []) }
            }
            $0.finance.bills = { _ in AsyncThrowingStream { $0.yield([]) } }
            $0.finance.budgets = { _ in AsyncThrowingStream { $0.yield([]) } }
            $0.finance.removeExpense = { id in removed.withValue { $0.append(id) } }
            $0.finance.payBill = { id, _, _ in paid.withValue { $0.append(id) } }
            $0.homes.members = { _ in AsyncThrowingStream { $0.yield([Self.ada, Self.grace]) } }
            $0.continuousClock = clock
        }
    }

    /// A store whose subscriptions never yield, for the tests that are about
    /// the order updates arrive in. Racing a stub that answers on its own makes
    /// those assertions depend on scheduling rather than on the reducer.
    private static func silentStore() -> TestStoreOf<FinanceFeature> {
        TestStore(
            initialState: FinanceFeature.State(homeID: "h1", currentUserID: "u1")
        ) {
            FinanceFeature()
        } withDependencies: {
            $0.finance.summary = { _, _, _ in .never }
            $0.finance.expenses = { _, _ in .never }
            $0.finance.bills = { _ in .never }
            $0.finance.budgets = { _ in .never }
            $0.homes.members = { _ in .never }
        }
    }

    @Test("The screen opens on this month and asks the server for exactly that")
    func opensOnCurrentMonth() async {
        let asked = LockIsolated<[CalendarMonth]>([])
        let store = Self.financeStore(asked: asked)
        store.exhaustivity = .off

        #expect(store.state.month == .current)
        await store.send(.task)
        await store.receive(\.summaryUpdated)
        #expect(asked.value == [.current])
    }

    @Test("Changing month re-subscribes rather than filtering what it already has")
    func monthChangeResubscribes() async {
        let asked = LockIsolated<[CalendarMonth]>([])
        let store = Self.financeStore(asked: asked)
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.summaryUpdated)

        let previous = CalendarMonth.current.advanced(by: -1)
        await store.send(.monthStepped(by: -1)) {
            $0.month = previous
            // The figures on screen answer a different question now, and the
            // screen says so rather than showing September under August.
            $0.isLoading = true
        }
        await store.receive(\.summaryUpdated)
        #expect(asked.value == [.current, previous])
    }

    @Test("A household with nothing tracked keeps its empty state through a month step")
    func emptyStateSurvivesAMonthStep() async {
        let store = Self.financeStore()
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.summaryUpdated)
        // Nobody has ever paid anything, and there are no bills or budgets.
        #expect(store.state.isBlank)

        // `isBlank` used to be gated on `!isLoading`, so a month step inverted
        // it: the overview swapped the empty state for a full stack of redacted
        // cards for as long as the load took, then swapped it back. Two changes
        // of the whole screen to report nothing at all, on every tap of the
        // chevron. It must hold through the load and out the other side.
        await store.send(.monthStepped(by: -1))
        #expect(store.state.isLoading)
        #expect(store.state.isBlank)

        await store.receive(\.summaryUpdated)
        #expect(!store.state.isLoading)
        #expect(store.state.isBlank)
    }

    @Test("The scrubber will not run past this month")
    func refusesTheFuture() async {
        let asked = LockIsolated<[CalendarMonth]>([])
        let store = Self.financeStore(asked: asked)
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.summaryUpdated)

        // A ledger has no future: an empty October opened in September reads as
        // data loss, not as a month that has not happened.
        await store.send(.monthStepped(by: 1))
        #expect(store.state.month == .current)
        #expect(asked.value == [.current])
    }

    @Test("A swipe drops the expense at once but holds the write open for undo")
    func deleteIsHeldForUndo() async {
        let removed = LockIsolated<[ExpenseID]>([])
        let clock = TestClock()
        let store = Self.financeStore(removed: removed, clock: clock)
        let milk = Self.expense("e1", "Milk")
        let rent = Self.expense("e2", "Rent")

        await store.send(.expensesUpdated(.current, [milk, rent])) {
            $0.expenses = [milk, rent]
        }
        await store.send(.deleteExpenseTapped("e1")) {
            $0.expenses.remove(id: "e1")
            $0.hidden.insert("e1")
            $0.pendingDeletion = milk
        }
        #expect(removed.value.isEmpty)

        // The server still has the row, so a live push arriving mid-window must
        // not put it back.
        await store.send(.expensesUpdated(.current, [milk, rent]))
        #expect(store.state.expenses.ids == ["e2"])

        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowClosed) {
            $0.pendingDeletion = nil
        }
        #expect(removed.value == ["e1"])
    }

    @Test("Undo cancels the write rather than reversing it")
    func undoCancelsTheDelete() async {
        let removed = LockIsolated<[ExpenseID]>([])
        let clock = TestClock()
        let store = Self.financeStore(removed: removed, clock: clock)
        let milk = Self.expense("e1", "Milk")

        await store.send(.expensesUpdated(.current, [milk])) {
            $0.expenses = [milk]
        }
        await store.send(.deleteExpenseTapped("e1")) {
            $0.expenses.remove(id: "e1")
            $0.hidden.insert("e1")
            $0.pendingDeletion = milk
        }
        await store.send(.undoDeleteTapped) {
            $0.pendingDeletion = nil
            $0.hidden.remove("e1")
            $0.expenses.append(milk)
        }

        await clock.advance(by: .seconds(30))
        #expect(removed.value.isEmpty)
    }

    @Test("Reaching square is celebrated once, not on every push that follows")
    func celebratesSquaringUpOnce() async {
        let store = Self.financeStore()
        store.exhaustivity = .off

        let owing = Self.summary(.current, adaNet: 4_000)
        let square = Self.summary(.current, adaNet: 0)

        // Arriving already settled is not an event, so the first push is quiet.
        await store.send(.summaryUpdated(square))
        #expect(store.state.settledCelebration == 0)

        await store.send(.summaryUpdated(owing))
        #expect(store.state.settledCelebration == 0)

        await store.send(.summaryUpdated(square))
        #expect(store.state.settledCelebration == 1)

        // A household that is already square gets no confetti every time the
        // subscription pushes.
        await store.send(.summaryUpdated(square))
        #expect(store.state.settledCelebration == 1)
    }

    @Test("A cancellation never reaches the user as an alert")
    func silentFailure() async {
        let store = Self.financeStore()
        await store.send(.loadFailed(.cancelled)) {
            $0.isLoading = false
        }
        #expect(store.state.alert == nil)
    }

    @Test("Paying a fixed bill from the row writes it without a form")
    func quickPay() async {
        let paid = LockIsolated<[BillID]>([])
        let store = Self.financeStore(paid: paid)
        let bill = Bill(id: "b1", title: "Rent", amount: 90_000, currency: "EUR")

        await store.send(.billsUpdated([bill])) {
            $0.bills = [bill]
        }
        await store.send(.quickPayTapped("b1")) {
            $0.paying.insert("b1")
        }
        await store.receive(\.billPaid) {
            $0.paying.remove("b1")
        }
        #expect(paid.value == ["b1"])
    }

    @Test("A month's figures never appear under another month's heading")
    func monthSwitchNeverShowsTheOldMonthsFigures() async {
        let august = CalendarMonth.current.advanced(by: -1)
        let store = Self.silentStore()
        store.exhaustivity = .off

        await store.send(.summaryUpdated(Self.summary(.current))) {
            $0.isLoading = false
        }
        #expect(store.state.summary.monthTotal == 1_000)

        // Leaving a month takes its rows with it, and the screen says it is
        // waiting rather than presenting what it has as the new month's.
        await store.send(.expensesUpdated(.current, [Self.expense("e1", "Milk")]))
        #expect(store.state.expenses.count == 1)

        await store.send(.monthStepped(by: -1)) {
            $0.month = august
            $0.isLoading = true
            $0.expenses = []
        }

        // The expense list is the smaller query and usually answers first.
        // Answering must not call the screen loaded while every month-scoped
        // card still holds September's figures.
        await store.send(.expensesUpdated(august, []))
        #expect(store.state.isLoading)

        // A last push from the month just left is dropped rather than applied
        // to the month now on screen.
        await store.send(.expensesUpdated(.current, [Self.expense("e9", "Stale")]))
        #expect(store.state.expenses.isEmpty)
        await store.send(.summaryUpdated(Self.summary(.current)))
        #expect(store.state.isLoading)

        // Only the right month's summary settles it.
        await store.send(.summaryUpdated(Self.summary(august))) {
            $0.isLoading = false
        }
        #expect(store.state.summary.month == august.month)
    }

    @Test("Switching month drops a filter the new month cannot show")
    func monthSwitchClearsAnInvisibleFilter() async {
        let store = Self.silentStore()
        store.exhaustivity = .off

        await store.send(.categoryFilterTapped(.dining)) {
            $0.categoryFilter = .dining
        }
        // The chip row only offers categories present in the month on screen,
        // so a filter carried across would be invisible — and unclearable.
        await store.send(.monthStepped(by: -1)) {
            $0.month = CalendarMonth.current.advanced(by: -1)
            $0.isLoading = true
            $0.categoryFilter = nil
        }
    }

    @Test("Choosing another currency asks for another set of figures")
    func currencySwitchResubscribes() async {
        let asked = LockIsolated<[String?]>([])
        let store = TestStore(
            initialState: FinanceFeature.State(homeID: "h1", currentUserID: "u1")
        ) {
            FinanceFeature()
        } withDependencies: {
            $0.finance.summary = { _, month, currency in
                asked.withValue { $0.append(currency) }
                var summary = Self.summary(month)
                summary.currency = currency ?? "EUR"
                summary.currencies = ["EUR", "TRY"]
                return AsyncThrowingStream { $0.yield(summary) }
            }
            $0.finance.expenses = { _, _ in .never }
            $0.finance.bills = { _ in .never }
            $0.finance.budgets = { _ in .never }
            $0.homes.members = { _ in .never }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.summaryUpdated)
        #expect(store.state.currency == "EUR")
        #expect(store.state.hasSeveralCurrencies)

        // Nothing is converted: 500 lira and 20 euros are two sets of figures,
        // and asking for one is a different subscription.
        await store.send(.currencySelected("TRY")) {
            $0.selectedCurrency = "TRY"
            $0.isLoading = true
        }
        await store.receive(\.summaryUpdated)
        #expect(store.state.currency == "TRY")
        #expect(asked.value == [nil, "TRY"])
    }

    @Test("A summary for a currency that has been switched away from is dropped")
    func staleCurrencyIsIgnored() async {
        let store = Self.silentStore()
        store.exhaustivity = .off

        await store.send(.currencySelected("TRY")) {
            $0.selectedCurrency = "TRY"
            $0.isLoading = true
        }

        var euros = Self.summary(.current)
        euros.currency = "EUR"
        await store.send(.summaryUpdated(euros))
        #expect(store.state.isLoading)

        var lira = Self.summary(.current)
        lira.currency = "TRY"
        await store.send(.summaryUpdated(lira)) {
            $0.isLoading = false
        }
        #expect(store.state.currency == "TRY")
    }

    @Test("A ledger with two currencies never adds one to the other")
    func ledgerScopesToTheSelectedCurrency() async {
        let store = Self.silentStore()
        store.exhaustivity = .off

        var summary = Self.summary(.current)
        summary.currency = "EUR"
        summary.currencies = ["EUR", "TRY"]
        await store.send(.summaryUpdated(summary))

        let euros = Expense(
            id: "e1", title: "Coffee", amount: 500, currency: "EUR", paidBy: "u1"
        )
        let lira = Expense(
            id: "e2", title: "Kira", amount: 50_000, currency: "TRY", paidBy: "u1"
        )
        await store.send(.expensesUpdated(.current, [euros, lira]))

        // Only the selected currency's rows, so the running total under the
        // search field is a number that means something.
        #expect(store.state.filteredExpenses.map(\.id) == ["e1"])
        #expect(store.state.filteredTotal == 500)

        await store.send(.currencySelected("TRY")) { $0.selectedCurrency = "TRY" }
        var inLira = summary
        inLira.currency = "TRY"
        await store.send(.summaryUpdated(inLira))
        #expect(store.state.filteredExpenses.map(\.id) == ["e2"])
        #expect(store.state.filteredTotal == 50_000)
    }

    @Test("A household with one currency has nothing narrowed and no picker")
    func singleCurrencyHouseholdIsUnaffected() async {
        let store = Self.silentStore()
        store.exhaustivity = .off

        var summary = Self.summary(.current)
        summary.currency = "EUR"
        summary.currencies = ["EUR"]
        await store.send(.summaryUpdated(summary))
        await store.send(.expensesUpdated(.current, [
            Expense(id: "e1", title: "Coffee", amount: 500, currency: "EUR", paidBy: "u1"),
        ]))

        #expect(!store.state.hasSeveralCurrencies)
        #expect(store.state.filteredExpenses.count == 1)
    }

    @Test("Bill badges count every currency; the committed total counts one")
    func billCountersAreHonestAboutCurrency() async {
        let store = Self.silentStore()
        store.exhaustivity = .off

        var summary = Self.summary(.current)
        summary.currency = "EUR"
        summary.currencies = ["EUR", "TRY"]
        await store.send(.summaryUpdated(summary))

        let past = Timestamp(Date().addingTimeInterval(-3 * 86_400))
        let soon = Timestamp(Date().addingTimeInterval(2 * 86_400))
        await store.send(.billsUpdated([
            Bill(id: "b1", title: "Power", amount: 5_000, currency: "EUR",
                 cycle: .monthly, dueDate: past),
            Bill(id: "b2", title: "Kira", amount: 900_000, currency: "TRY",
                 cycle: .monthly, dueDate: soon),
        ]))

        // Every bill is on screen whatever it is written in, so the badges have
        // to count all of them or they contradict the list underneath.
        #expect(store.state.overdueCount == 1)
        #expect(store.state.dueSoonCount == 1)
        // The committed figure is a sum, so it is the one thing that is scoped.
        #expect(store.state.monthlyCommitted == 5_000)
    }

    @Test("Backfilling a past month dates the expense in that month, not today")
    func composerDatesIntoTheShownMonth() async {
        let store = Self.financeStore()
        store.exhaustivity = .off

        let august = CalendarMonth.current.advanced(by: -1)
        await store.send(.monthSelected(august))
        await store.send(.addExpenseTapped)

        guard case let .composeExpense(composer) = store.state.destination else {
            Issue.record("expected the expense composer")
            return
        }
        #expect(CalendarMonth(containing: composer.spentAt) == august)
    }
}

@MainActor
@Suite("Expense composer")
struct ExpenseComposerTests {

    private static let members: IdentifiedArrayOf<User> = [
        User(id: "u1", name: "Ada"),
        User(id: "u2", name: "Grace"),
        User(id: "u3", name: "Alan"),
    ]

    private static func composer(
        editing: Expense? = nil,
        saved: LockIsolated<[NewExpense]> = LockIsolated([])
    ) -> TestStoreOf<ExpenseComposerFeature> {
        TestStore(
            initialState: ExpenseComposerFeature.State(
                homeID: "h1",
                members: members,
                currentUserID: "u1",
                currency: "EUR",
                editing: editing
            )
        ) {
            ExpenseComposerFeature()
        } withDependencies: {
            $0.finance.createExpense = { new in saved.withValue { $0.append(new) } }
            $0.finance.updateExpense = { _, new in saved.withValue { $0.append(new) } }
        }
    }

    @Test("A new expense starts split across the whole household, paid by you")
    func defaults() {
        let state = ExpenseComposerFeature.State(
            homeID: "h1",
            members: Self.members,
            currentUserID: "u2",
            currency: "EUR"
        )
        #expect(state.paidBy == "u2")
        #expect(state.participants == ["u1", "u2", "u3"])
        // The person entering it comes first, because they paid for it far more
        // often than not.
        #expect(state.orderedMembers.first?.id == "u2")
    }

    @Test("The preview is the split the server will store, to the cent")
    func previewMatchesTheServersArithmetic() async {
        let store = Self.composer()
        store.exhaustivity = .off

        await store.send(.binding(.set(\.amountText, "10")))
        // 3.34 + 3.33 + 3.33 — the same largest-remainder division the server
        // runs, so the preview and the saved ledger cannot disagree.
        #expect(store.state.preview.map(\.amount) == [334, 333, 333])
        #expect(store.state.preview.reduce(0) { $0 + $1.amount } == 1_000)

        await store.send(.participantToggled("u3"))
        #expect(store.state.preview.map(\.amount) == [500, 500])
    }

    @Test("A split can never come down to nobody")
    func neverEmpties() async {
        let store = Self.composer()
        store.exhaustivity = .off

        await store.send(.onlyMeTapped)
        #expect(store.state.participants == ["u1"])
        // Refused rather than left with a save button that goes grey without
        // saying why.
        await store.send(.participantToggled("u1"))
        #expect(store.state.participants == ["u1"])
    }

    @Test("An exact split that does not add up is refused, and says by how much")
    func exactSplitMustBalance() async {
        let store = Self.composer()
        store.exhaustivity = .off

        await store.send(.binding(.set(\.title, "Lasagne")))
        await store.send(.binding(.set(\.amountText, "30")))
        await store.send(.binding(.set(\.mode, .exact)))
        // Seeded from the equal split, which already adds up.
        #expect(store.state.isBalanced)
        #expect(store.state.canSubmit)

        await store.send(.binding(.set(\.exact, ["u1": "5", "u2": "5", "u3": "5"])))
        #expect(store.state.exactRemainder == 1_500)
        #expect(!store.state.canSubmit)

        await store.send(.submitTapped)
        // A refusal has to be felt as well as read.
        #expect(store.state.shakes == 1)
        #expect(store.state.inlineError != nil)
    }

    @Test("Weighted shares divide the money and still add up")
    func weightedShares() async {
        let store = Self.composer()
        store.exhaustivity = .off

        await store.send(.binding(.set(\.amountText, "10")))
        await store.send(.binding(.set(\.mode, .shares)))
        await store.send(.weightChanged("u1", 2))
        await store.send(.weightChanged("u3", 0))

        #expect(store.state.preview.map(\.userID) == ["u1", "u2"])
        #expect(store.state.preview.map(\.amount) == [667, 333])
        #expect(store.state.preview.reduce(0) { $0 + $1.amount } == 1_000)
    }

    @Test("Saving sends what the preview was showing")
    func savingSendsThePreview() async {
        let saved = LockIsolated<[NewExpense]>([])
        let store = Self.composer(saved: saved)
        store.exhaustivity = .off

        await store.send(.binding(.set(\.title, "Lasagne")))
        await store.send(.binding(.set(\.amountText, "12,50")))
        await store.send(.binding(.set(\.category, .dining)))
        await store.send(.submitTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate)

        #expect(saved.value.count == 1)
        let payload = saved.value[0]
        #expect(payload.amount == 1_250)
        #expect(payload.category == .dining)
        // A set: the participants travel in the order the sheet listed them —
        // the person entering it first, then everybody else by name — and the
        // server treats them as a set either way.
        #expect(Set(payload.participants) == ["u1", "u2", "u3"])
    }

    @Test("Reopening an expense restores the shares that were typed, not the amounts they became")
    func editingRestoresAuthoredWeights() {
        let expense = Expense(
            id: "e1",
            title: "Rent",
            amount: 90_000,
            currency: "EUR",
            paidBy: "u1",
            splits: [
                ExpenseSplit(userID: "u1", amount: 60_000),
                ExpenseSplit(userID: "u2", amount: 30_000),
            ],
            splitMode: .shares,
            weights: [
                ExpenseWeight(userID: "u1", weight: 2),
                ExpenseWeight(userID: "u2", weight: 1),
            ]
        )
        let state = ExpenseComposerFeature.State(
            homeID: "h1",
            members: Self.members,
            currentUserID: "u1",
            currency: "EUR",
            editing: expense
        )
        #expect(state.isEditing)
        #expect(state.mode == .shares)
        // Two shares and one, not 600 and 300 — otherwise editing the total
        // would silently turn a proportional split into an exact one.
        #expect(state.weights["u1"] == 2)
        #expect(state.weights["u2"] == 1)
        #expect(state.amountMinor == 90_000)
    }

    @Test("Deleting from the editor hands the row back to the screen's undo path")
    func deleteDelegatesRatherThanWriting() async {
        let store = Self.composer(editing: Expense(
            id: "e1", title: "Milk", amount: 500, paidBy: "u1"
        ))
        await store.send(.deleteTapped)
        await store.receive(\.delegate.deleteRequested)
    }
}

@MainActor
@Suite("Settling up")
struct SettleUpTests {

    private static let members: IdentifiedArrayOf<User> = [
        User(id: "u1", name: "Ada"),
        User(id: "u2", name: "Grace"),
        User(id: "u3", name: "Alan"),
    ]

    @Test("The sheet opens on the payment the viewer is actually part of")
    func preloadsTheViewersPayment() {
        let state = SettleUpFeature.State(
            homeID: "h1",
            currentUserID: "u3",
            currency: "EUR",
            members: Self.members,
            balances: [
                MemberFinance(userID: "u1", name: "Ada", net: 5_000),
                MemberFinance(userID: "u2", name: "Grace", net: -1_000),
                MemberFinance(userID: "u3", name: "Alan", net: -4_000),
            ],
            transfers: [
                Transfer(from: "u2", to: "u1", amount: 1_000),
                Transfer(from: "u3", to: "u1", amount: 4_000),
            ]
        )
        // Not the first suggestion — the first one involving *them*. People open
        // this screen to settle their own debt, not to referee somebody else's.
        #expect(state.from == "u3")
        #expect(state.to == "u1")
        #expect(state.amountMinor == 4_000)
        #expect(state.canSubmit)
        #expect(state.name(for: "u3") == "You")
    }

    @Test("Recording a payment writes it and marks that suggestion done")
    func recordingASuggestion() async {
        let recorded = LockIsolated<[NewSettlement]>([])
        let store = TestStore(
            initialState: SettleUpFeature.State(
                homeID: "h1",
                currentUserID: "u1",
                currency: "EUR",
                members: Self.members,
                balances: [
                    MemberFinance(userID: "u1", name: "Ada", net: 4_000),
                    MemberFinance(userID: "u2", name: "Grace", net: -4_000),
                ],
                transfers: [Transfer(from: "u2", to: "u1", amount: 4_000)]
            )
        ) {
            SettleUpFeature()
        } withDependencies: {
            $0.finance.settle = { payment in recorded.withValue { $0.append(payment) } }
        }
        store.exhaustivity = .off

        #expect(store.state.openTransfers.count == 1)
        await store.send(.recordTapped)
        await store.receive(\.recorded)
        await store.receive(\.delegate)

        #expect(recorded.value.count == 1)
        #expect(recorded.value[0].from == "u2")
        #expect(recorded.value[0].to == "u1")
        #expect(recorded.value[0].amount == 4_000)
        // The row cannot be tapped twice while the ledger catches up.
        #expect(store.state.openTransfers.isEmpty)
    }

    @Test("A payment needs two different people")
    func refusesAPaymentToYourself() {
        var state = SettleUpFeature.State(
            homeID: "h1",
            currentUserID: "u1",
            currency: "EUR",
            members: Self.members,
            balances: [],
            transfers: []
        )
        state.from = "u1"
        state.to = "u1"
        state.amountText = "40"
        #expect(!state.canSubmit)
        state.to = "u2"
        #expect(state.canSubmit)
    }
}

@MainActor
@Suite("Bill composer")
struct BillComposerTests {

    private static let members: IdentifiedArrayOf<User> = [User(id: "u1", name: "Ada")]

    private static func composer(
        editing: Bill? = nil,
        saved: LockIsolated<[NewBill]> = LockIsolated([])
    ) -> TestStoreOf<BillComposerFeature> {
        TestStore(
            initialState: BillComposerFeature.State(
                homeID: "h1",
                members: members,
                currency: "EUR",
                knownCurrencies: ["EUR", "TRY"],
                editing: editing
            )
        ) {
            BillComposerFeature()
        } withDependencies: {
            $0.finance.createBill = { new in saved.withValue { $0.append(new) } }
            $0.finance.updateBill = { _, new in saved.withValue { $0.append(new) } }
        }
    }

    @Test("A new bill is reminded about the day before, without anyone finding the setting")
    func remindersDefault() {
        let state = BillComposerFeature.State(
            homeID: "h1", members: Self.members, currency: "EUR"
        )
        #expect(state.reminders == [1])
        // And a bill that is due the moment it is created would open the screen
        // already overdue, so it defaults a month out.
        #expect(state.dueDate > Date())
    }

    @Test("At most three reminders, and the fourth is simply not offered")
    func remindersAreCapped() async {
        let store = Self.composer()
        store.exhaustivity = .off

        await store.send(.reminderToggled(7))
        await store.send(.reminderToggled(3))
        #expect(store.state.reminders == [1, 3, 7])
        #expect(!store.state.canAddReminder)

        // Silently refused rather than alerted: the chips that cannot be added
        // are already dim, so there is nothing to explain.
        await store.send(.reminderToggled(0))
        #expect(store.state.reminders == [1, 3, 7])

        await store.send(.reminderToggled(3))
        #expect(store.state.reminders == [1, 7])
        #expect(store.state.canAddReminder)
    }

    @Test("Saving carries the reminders and the bill's own currency")
    func savingCarriesRemindersAndCurrency() async {
        let saved = LockIsolated<[NewBill]>([])
        let store = Self.composer(saved: saved)
        store.exhaustivity = .off

        await store.send(.binding(.set(\.title, "Kira")))
        await store.send(.binding(.set(\.currency, "TRY")))
        await store.send(.binding(.set(\.amountText, "9000")))
        await store.send(.reminderToggled(3))
        await store.send(.submitTapped)
        await store.receive(\.saved)

        #expect(saved.value.count == 1)
        let payload = saved.value[0]
        #expect(payload.currency == "TRY")
        // TRY has two subunit digits, so 9000 lira is 900000 kuruş.
        #expect(payload.amount == 900_000)
        // Furthest-out nudge first, which is the order they will fire in.
        #expect(payload.reminders == [3, 1])
    }

    @Test("A yearly bill and the rent are comparable once said per month")
    func monthlyCostIsShown() async {
        let store = Self.composer()
        store.exhaustivity = .off

        await store.send(.binding(.set(\.amountText, "120")))
        await store.send(.binding(.set(\.cycle, .yearly)))
        #expect(store.state.monthlyCost == 1_000)
    }

    @Test("Deleting a bill is confirmed inside the sheet that offered it")
    func deleteConfirmsInPlace() async {
        let store = Self.composer(editing: Bill(
            id: "b1", title: "Power", amount: 5_000, currency: "EUR"
        ))
        store.exhaustivity = .off

        await store.send(.deleteTapped)
        #expect(store.state.alert != nil)
        await store.send(.alert(.presented(.confirmDelete)))
        await store.receive(\.delegate)
    }
}


// MARK: - Calendar & Events

@MainActor
@Suite("Calendar")
struct CalendarFeatureTests {

    /// One anchor for every fixture in this suite.
    ///
    /// Taken from the clock rather than from a fixed epoch, because the day
    /// buckets these tests assert on are the *reader's* days — a hard-coded
    /// 2025 timestamp is never `CalendarDay.today`, so every assertion about
    /// "today" would be about an empty day.
    static let now = Date()
    static var anchor: CalendarDay { CalendarDay(now) }

    /// Two events on one day, one of them a three-day trip that starts before it.
    static func sample(now: Date = CalendarFeatureTests.now) -> [EventOccurrence] {
        let day = Calendar.current.startOfDay(for: now)
        return [
            EventOccurrence(
                eventID: "e1",
                homeID: "h1",
                title: "Dinner party",
                kind: .dinnerParty,
                startsAt: Timestamp(day.addingTimeInterval(19 * 3600)),
                endsAt: Timestamp(day.addingTimeInterval(23 * 3600)),
                attendees: ["u1", "u2"]
            ),
            EventOccurrence(
                eventID: "e2",
                homeID: "h1",
                title: "Trip",
                kind: .trip,
                startsAt: Timestamp(day.addingTimeInterval(-24 * 3600)),
                endsAt: Timestamp(day.addingTimeInterval(48 * 3600)),
                isAllDay: true
            ),
        ]
    }

    private static func store(
        day: CalendarDay = .today,
        _ configure: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStore<CalendarFeature.State, CalendarFeature.Action> {
        TestStore(
            initialState: CalendarFeature.State(homeID: "h1", currentUserID: "u1", day: day)
        ) {
            CalendarFeature()
        } withDependencies: { configure(&$0) }
    }

    @Test("A multi-day event is indexed on every day it covers, not just its first")
    func multiDayIndexing() async {
        let store = Self.store()
        let events = Self.sample()
        let windowID = store.state.windowID

        await store.send(.occurrencesUpdated(windowID, events)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: events)
            $0.dayIndex = Self.index(for: events)
        }

        let today = Self.anchor
        // The trip started yesterday and runs into tomorrow: it belongs on all
        // three, or a household looking at Tuesday cannot see it is away.
        #expect(store.state.count(on: today.advanced(by: -1)) == 1)
        #expect(store.state.count(on: today) == 2)
        #expect(store.state.count(on: today.advanced(by: 1)) == 1)
        #expect(store.state.count(on: today.advanced(by: 2)) == 0)
    }

    @Test("Opening at an event presents its sheet, not just its day")
    func deepOpenPresentsTheSheet() async {
        let start = Date().addingTimeInterval(2 * 24 * 3600)
        let occurrence = EventOccurrence(
            eventID: "e1",
            title: "Concert",
            startsAt: Timestamp(start),
            endsAt: Timestamp(start.addingTimeInterval(7200))
        )
        let state = CalendarFeature.State(
            homeID: "h1",
            currentUserID: "u1",
            showing: occurrence
        )
        // Landing on the right day is not the same as opening the thing that was
        // tapped — stopping at the day makes the tap have to be repeated.
        #expect(state.selectedDay == CalendarDay(start))
        guard case .detail(let detail)? = state.destination else {
            Issue.record("expected the event sheet to be presented")
            return
        }
        #expect(detail.occurrence.id == occurrence.id)
    }

    @Test("An event opened by id waits for the window, then presents")
    func deepOpenByIDResolvesFromTheWindow() async {
        let events = Self.sample()
        let target = events[0]
        let store = TestStore(
            initialState: CalendarFeature.State(
                homeID: "h1",
                currentUserID: "u1",
                day: CalendarDay(target.start),
                openingEventID: target.eventID
            )
        ) {
            CalendarFeature()
        }
        store.exhaustivity = .off

        // Nothing to present yet — the caller had an id and a day, not an event.
        #expect(store.state.destination == nil)

        await store.send(.occurrencesUpdated(store.state.windowID, events))
        guard case .detail(let detail)? = store.state.destination else {
            Issue.record("expected the event sheet to be presented")
            return
        }
        #expect(detail.occurrence.eventID == target.eventID)
        // Cleared, so a later month cannot re-fire it.
        #expect(store.state.pendingOpenID == nil)
    }

    @Test("Membership reaching the screen reaches the sheet already open on it")
    func membersFlowIntoAnOpenSheet() async {
        let events = Self.sample()
        let store = TestStore(
            initialState: CalendarFeature.State(
                homeID: "h1",
                currentUserID: "u1",
                showing: events[0]
            )
        ) {
            CalendarFeature()
        }
        store.exhaustivity = .off

        // Presented before the membership subscription answered, so the roster
        // would otherwise read "Someone" for as long as the sheet stayed open.
        #expect(store.state.destination?.detail?.members.isEmpty == true)

        await store.send(.membersUpdated([User(id: "u1", name: "Ada"), User(id: "u2", name: "Bea")]))
        #expect(store.state.destination?.detail?.members.count == 2)
    }

    @Test("A push for a window that has been scrubbed past is ignored")
    func staleWindowIsDropped() async {
        let store = Self.store()
        // The payload carries no range of its own, so a late answer from the
        // month you just left would otherwise land under the one you are on.
        await store.send(.occurrencesUpdated("month-1999-1", Self.sample()))
    }

    @Test("Filtering rebuilds the day index rather than the event list")
    func filteringNarrowsTheGrid() async {
        let store = Self.store()
        let events = Self.sample()
        let windowID = store.state.windowID

        await store.send(.occurrencesUpdated(windowID, events)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: events)
            $0.dayIndex = Self.index(for: events)
        }

        await store.send(.kindFilterTapped(.trip)) {
            $0.kindFilter = .trip
            $0.dayIndex = Self.index(for: events.filter { $0.kind == .trip })
        }
        // The events themselves are untouched — the grid is drawn from the
        // index, so a filter costs one rebuild rather than a re-subscription.
        #expect(store.state.occurrences.count == 2)
        #expect(store.state.count(on: Self.anchor) == 1)

        await store.send(.kindFilterTapped(.trip)) {
            $0.kindFilter = nil
            $0.dayIndex = Self.index(for: events)
        }
    }

    @Test("An RSVP moves every occurrence of the series, not just the one tapped")
    func rsvpAppliesToTheWholeSeries() async {
        let answered = LockIsolated<[(EventID, RSVPStatus?)]>([])
        let store = Self.store {
            $0.events.rsvp = { id, status in
                answered.withValue { $0.append((id, status)) }
            }
        }
        let start = Date(timeIntervalSince1970: 1_757_000_000)
        let weekly = (0..<3).map { week in
            EventOccurrence(
                eventID: "e9",
                title: "Standup",
                startsAt: Timestamp(start.addingTimeInterval(Double(week) * 7 * 86_400)),
                endsAt: Timestamp(start.addingTimeInterval(Double(week) * 7 * 86_400 + 1800)),
                recurrence: Recurrence(frequency: .weekly)
            )
        }
        let windowID = store.state.windowID
        await store.send(.occurrencesUpdated(windowID, weekly)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: weekly)
            $0.dayIndex = Self.index(for: weekly)
        }

        await store.send(.rsvpTapped(weekly[0], .going)) {
            $0.rsvpInFlight = ["e9"]
            for id in $0.occurrences.ids {
                $0.occurrences[id: id]?.rsvps = [EventRSVP(userID: "u1", status: .going)]
            }
        }
        // Answering "every Tuesday" once is what people mean; leaving the other
        // two undecided would show the same person as going and not going.
        #expect(store.state.occurrences.allSatisfy { $0.rsvp(of: "u1") == .going })
        #expect(answered.value.count == 1)
        #expect(answered.value[0].1 == .going)
    }

    @Test("A refused RSVP puts the old answer back")
    func failedRSVPRollsBack() async {
        let store = Self.store {
            $0.events.rsvp = { _, _ in throw AppError.offline }
        }
        let events = Self.sample()
        let windowID = store.state.windowID
        await store.send(.occurrencesUpdated(windowID, events)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: events)
            $0.dayIndex = Self.index(for: events)
        }

        await store.send(.rsvpTapped(events[0], .going)) {
            $0.rsvpInFlight = ["e1"]
            $0.occurrences[id: events[0].id]?.rsvps = [EventRSVP(userID: "u1", status: .going)]
        }
        // A refused write changed nothing on the server, so no push is coming to
        // correct the button — the reducer has to put the old answer back itself.
        await store.receive(\.rsvpFailed) {
            $0.rsvpInFlight = []
            $0.occurrences[id: events[0].id]?.rsvps = []
        }
        await store.receive(\.writeFailed) {
            $0.alert = .failure(.offline)
        }
    }

    @Test("Deleting a series clears every occurrence of it on screen")
    func deletingASeriesClearsTheWindow() async {
        let clock = TestClock()
        let removed = LockIsolated<[(EventID, EventScope)]>([])
        let store = Self.store {
            $0.continuousClock = clock
            $0.events.remove = { id, scope, _ in
                removed.withValue { $0.append((id, scope)) }
            }
        }
        let start = Date(timeIntervalSince1970: 1_757_000_000)
        let weekly = (0..<3).map { week in
            EventOccurrence(
                eventID: "e9",
                title: "Standup",
                startsAt: Timestamp(start.addingTimeInterval(Double(week) * 7 * 86_400)),
                endsAt: Timestamp(start.addingTimeInterval(Double(week) * 7 * 86_400 + 1800)),
                recurrence: Recurrence(frequency: .weekly)
            )
        }
        let windowID = store.state.windowID
        await store.send(.occurrencesUpdated(windowID, weekly)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: weekly)
            $0.dayIndex = Self.index(for: weekly)
        }

        await store.send(.deleteTapped(weekly[0], .series)) {
            $0.hidden = Set(weekly.map(\.id))
            $0.occurrences = []
            $0.dayIndex = [:]
            $0.pendingDeletion = .init(occurrence: weekly[0], scope: .series)
        }
        // Nothing is sent while the undo window is open — undo cancels the
        // write rather than reversing it.
        #expect(removed.value.isEmpty)

        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowClosed) {
            $0.pendingDeletion = nil
        }
        #expect(removed.value.count == 1)
        #expect(removed.value[0].1 == .series)
    }

    @Test("Undo inside the window cancels the write instead of reversing it")
    func undoCancelsTheDelete() async {
        let clock = TestClock()
        let removed = LockIsolated(0)
        let store = Self.store {
            $0.continuousClock = clock
            $0.events.remove = { _, _, _ in removed.withValue { $0 += 1 } }
        }
        let events = Self.sample()
        let windowID = store.state.windowID
        await store.send(.occurrencesUpdated(windowID, events)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: events)
            $0.dayIndex = Self.index(for: events)
        }

        await store.send(.deleteTapped(events[0], .series)) {
            $0.hidden = [events[0].id]
            $0.occurrences.remove(id: events[0].id)
            $0.dayIndex = Self.index(for: [events[1]])
            $0.pendingDeletion = .init(occurrence: events[0], scope: .series)
        }
        // Restored in start order rather than appended at the end: the index is
        // rebuilt from `occurrences`, so an unsorted list would put the trip
        // after the dinner on the day they share.
        let restored = [events[1], events[0]]
        await store.send(.undoDeleteTapped) {
            $0.pendingDeletion = nil
            $0.hidden = []
            $0.occurrences = IdentifiedArray(uniqueElements: restored)
            $0.dayIndex = Self.index(for: restored)
        }
        await clock.advance(by: .seconds(10))
        #expect(removed.value == 0)
    }

    @Test("A live push cannot resurrect a row whose delete is still pending")
    func hiddenRowsSurviveAPush() async {
        let clock = TestClock()
        let store = Self.store {
            $0.continuousClock = clock
            $0.events.remove = { _, _, _ in }
        }
        let events = Self.sample()
        let windowID = store.state.windowID
        await store.send(.occurrencesUpdated(windowID, events)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: events)
            $0.dayIndex = Self.index(for: events)
        }
        await store.send(.deleteTapped(events[0], .series)) {
            $0.hidden = [events[0].id]
            $0.occurrences.remove(id: events[0].id)
            $0.dayIndex = Self.index(for: [events[1]])
            $0.pendingDeletion = .init(occurrence: events[0], scope: .series)
        }
        // The server still has the row, and Convex re-publishes a query set on
        // every change — without the mask the deleted event flickers back.
        await store.send(.occurrencesUpdated(windowID, events))
        #expect(store.state.occurrences.count == 1)

        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowClosed) { $0.pendingDeletion = nil }
    }

    @Test("Stepping into another month drops the events it was showing")
    func steppingAMonthClearsTheGrid() async {
        let store = Self.store {
            // Finished rather than `.never`: the reducer subscribes for the new
            // month, and an endless stream leaves that effect running past the
            // end of the test.
            $0.events.inRange = { _, _, _ in
                AsyncThrowingStream { $0.finish() }
            }
        }
        let events = Self.sample()
        let windowID = store.state.windowID
        await store.send(.occurrencesUpdated(windowID, events)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: events)
            $0.dayIndex = Self.index(for: events)
        }

        let next = store.state.month.advanced(by: 1)
        await store.send(.monthStepped(by: 1)) {
            $0.month = next
            $0.isLoading = true
            // Holding them would draw this month's dots under next month's grid
            // until the new list arrived.
            $0.occurrences = []
            $0.dayIndex = [:]
            $0.selectedDay = CalendarDay(year: next.year, month: next.month, day: 1)
        }
    }

    @Test("Month and week share a window, so switching between them re-subscribes to nothing")
    func modeSwitchKeepsTheWindow() async {
        let store = Self.store()
        let events = Self.sample()
        let windowID = store.state.windowID
        await store.send(.occurrencesUpdated(windowID, events)) {
            $0.isLoading = false
            $0.hasLoadedOnce = true
            $0.occurrences = IdentifiedArray(uniqueElements: events)
            $0.dayIndex = Self.index(for: events)
        }
        await store.send(.modeSelected(.week)) { $0.mode = .week }
        // Still loaded: a week is always inside the month grid, so nothing was
        // torn down and no skeleton went up.
        #expect(store.state.isLoading == false)
        #expect(store.state.occurrences.count == 2)
    }

    /// The same bucketing the reducer does, so a test asserts on the shape
    /// rather than restating the loop.
    static func index(for events: [EventOccurrence]) -> [CalendarDay: [EventOccurrence.ID]] {
        var index: [CalendarDay: [EventOccurrence.ID]] = [:]
        for event in events {
            for day in event.days() { index[day, default: []].append(event.id) }
        }
        return index
    }
}

@MainActor
@Suite("Event composer")
struct EventComposerTests {

    private static let members: IdentifiedArrayOf<User> = [
        User(id: "u1", name: "Ada"),
        User(id: "u2", name: "Bea"),
    ]

    @Test("A new event invites the whole house and opens on the kind's own defaults")
    func defaultsFollowTheKind() async {
        let store = TestStore(
            initialState: EventComposerFeature.State(
                homeID: "h1",
                members: Self.members,
                currentUserID: "u1",
                day: .today
            )
        ) {
            EventComposerFeature()
        } withDependencies: {
            // A kind that suggests a menu opens the recipe subscription, and the
            // bundled Explore list with it.
            $0.recipes.byHome = { _ in AsyncThrowingStream { $0.finish() } }
            $0.recipes.samples = { [] }
        }
        store.exhaustivity = .off

        #expect(store.state.attendees == ["u1", "u2"])

        await store.send(.kindSelected(.dinnerParty))
        // A dinner party is a menu, a shop and a bill; the composer opens with
        // all three rather than making somebody find them.
        #expect(store.state.sections.contains(.menu))
        #expect(store.state.sections.contains(.shopping))
        #expect(store.state.sections.contains(.budget))
        #expect(store.state.endsAt.timeIntervalSince(store.state.startsAt) == 4 * 3600)

        await store.send(.kindSelected(.birthday))
        // A birthday that does not repeat yearly is a mistake nobody notices
        // until next year.
        #expect(store.state.repeats)
        #expect(store.state.frequency == .yearly)
        #expect(store.state.isAllDay)
    }

    @Test("A fourth reminder is refused rather than silently dropped")
    func remindersAreCappedOutLoud() async {
        let store = TestStore(
            initialState: EventComposerFeature.State(
                homeID: "h1",
                members: Self.members,
                currentUserID: "u1",
                day: .today
            )
        ) {
            EventComposerFeature()
        }
        store.exhaustivity = .off

        await store.send(.reminderToggled(.oneDay))
        await store.send(.reminderToggled(.thirtyMinutes))
        #expect(store.state.reminders.count == 3)

        await store.send(.reminderToggled(.oneWeek))
        // A control that just stops responding reads as broken.
        #expect(store.state.reminders.count == 3)
        #expect(store.state.inlineError != nil)
        #expect(store.state.shakes == 1)
    }

    @Test("Removing a plan section clears what it was holding")
    func removingASectionClearsIt() async {
        let store = TestStore(
            initialState: EventComposerFeature.State(
                homeID: "h1",
                members: Self.members,
                currentUserID: "u1",
                day: .today
            )
        ) {
            EventComposerFeature()
        }
        store.exhaustivity = .off

        await store.send(.sectionAdded(.budget))
        await store.send(.binding(.set(\.budgetText, "120")))
        #expect(store.state.budgetMinor == 12_000)

        await store.send(.sectionRemoved(.budget))
        // A budget left behind would be saved by a sheet that no longer shows it.
        #expect(store.state.budgetText.isEmpty)
        #expect(!store.state.sections.contains(.budget))
    }

    @Test("Shopping typed into the composer is written once the event has an id")
    func draftedShoppingIsSentAfterTheEvent() async {
        let created = LockIsolated<[NewEvent]>([])
        let added = LockIsolated<[(EventID, [String])]>([])
        let store = TestStore(
            initialState: EventComposerFeature.State(
                homeID: "h1",
                members: Self.members,
                currentUserID: "u1",
                day: .today
            )
        ) {
            EventComposerFeature()
        } withDependencies: {
            $0.events.create = { new in
                created.withValue { $0.append(new) }
                return "e-new"
            }
            $0.events.addItems = { id, names, _ in
                added.withValue { $0.append((id, names)) }
                return StockUpResult(added: names.count, skipped: 0)
            }
            $0.recipes.byHome = { _ in AsyncThrowingStream { $0.finish() } }
            $0.recipes.samples = { [] }
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.title, "Game night")))
        await store.send(.kindSelected(.gameNight))
        // A movie or game night gets no menu by default, but wanting to cook for
        // one is ordinary — every section is addable by hand.
        await store.send(.sectionAdded(.menu))
        #expect(store.state.sections.contains(.menu))

        await store.send(.binding(.set(\.newItem, "Ice")))
        await store.send(.itemDrafted) { $0.shoppingDraft = ["Ice"]; $0.newItem = "" }
        await store.send(.binding(.set(\.newItem, "ice")))
        // Typing it twice on the way to remembering you already typed it must
        // not put it on the list twice.
        await store.send(.itemDrafted)
        #expect(store.state.shoppingDraft == ["Ice"])

        await store.send(.binding(.set(\.newItem, "Crisps")))
        await store.send(.itemDrafted)
        #expect(store.state.shoppingDraft == ["Ice", "Crisps"])

        await store.send(.submitTapped)
        await store.receive(\.savedAs)

        #expect(created.value.count == 1)
        // A shopping item is a link *to* an event, so the event has to exist
        // first — which is why `create` hands its id back.
        #expect(added.value.count == 1)
        #expect(added.value[0].0 == "e-new")
        #expect(added.value[0].1 == ["Ice", "Crisps"])
    }

    @Test("Removing the shopping section drops what was drafted into it")
    func removingShoppingDropsTheDraft() async {
        let added = LockIsolated(0)
        let store = TestStore(
            initialState: EventComposerFeature.State(
                homeID: "h1",
                members: Self.members,
                currentUserID: "u1",
                day: .today
            )
        ) {
            EventComposerFeature()
        } withDependencies: {
            $0.events.create = { _ in "e-new" }
            $0.events.addItems = { _, _, _ in
                added.withValue { $0 += 1 }
                return StockUpResult()
            }
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.title, "Dentist")))
        await store.send(.sectionAdded(.shopping))
        await store.send(.binding(.set(\.newItem, "Floss")))
        await store.send(.itemDrafted)
        await store.send(.sectionRemoved(.shopping))
        #expect(store.state.shoppingDraft.isEmpty)

        await store.send(.submitTapped)
        await store.receive(\.savedAs)
        // A draft left behind would be written by a sheet that no longer shows it.
        #expect(added.value == 0)
    }

    @Test("Choosing an Explore recipe copies it onto the household's shelf first")
    func exploreRecipesAreAdoptedBeforeUse() async {
        let sample = Recipe(
            id: "sample-lasagne",
            title: "Lasagne",
            ingredients: ["Pasta", "Mince"],
            homeID: Recipe.exploreHomeID
        )
        let saved = Recipe(id: "r-saved", title: "Soup", ingredients: ["Stock"], homeID: "h1")
        let adopted = LockIsolated<[NewRecipe]>([])

        let store = TestStore(
            initialState: EventComposerFeature.State(
                homeID: "h1",
                members: Self.members,
                currentUserID: "u1",
                day: .today
            )
        ) {
            EventComposerFeature()
        } withDependencies: {
            $0.recipes.byHome = { _ in .never }
            $0.recipes.samples = { [sample] }
            $0.recipes.adopt = { new in
                adopted.withValue { $0.append(new) }
                return Recipe(
                    id: "r-adopted",
                    title: new.title,
                    ingredients: new.ingredients,
                    homeID: "h1"
                )
            }
        }
        store.exhaustivity = .off

        await store.send(.sectionAdded(.menu))
        await store.send(.recipesUpdated([saved]))
        await store.send(.samplesLoaded([sample]))
        await store.send(.pickRecipesTapped)
        #expect(store.state.picker?.samples.count == 1)

        await store.send(.picker(.presented(.delegate(.chose([saved, sample])))))
        await store.receive(\.recipesAdopted)

        // A bundled recipe has no id in this home, so an event cannot point at
        // it until a copy exists here.
        #expect(adopted.value.count == 1)
        #expect(adopted.value[0].title == "Lasagne")
        #expect(store.state.recipeIDs == ["r-saved", "r-adopted"])
        // Held locally as well, so the chip has a title before the subscription
        // catches up.
        #expect(store.state.recipes[id: "r-adopted"] != nil)
    }

    @Test("A sample the home already has is not offered twice")
    func alreadyAdoptedSamplesAreHidden() {
        let saved = Recipe(id: "r1", title: "Lasagne", homeID: "h1")
        let sample = Recipe(id: "s1", title: "lasagne", homeID: Recipe.exploreHomeID)
        let picker = RecipePickerFeature.State(
            recipes: [saved],
            samples: [sample],
            selected: []
        )
        // Otherwise the same dish sits on screen twice under two ids, and
        // picking the wrong one silently adds a second copy to the shelf.
        #expect(picker.samples.isEmpty)
        #expect(picker.filtered.count == 1)
    }

    @Test("Editing one occurrence of a series writes it as its own one-off")
    func editingOneOccurrenceDetachesIt() async {
        let start = Date(timeIntervalSince1970: 1_757_000_000)
        let occurrence = EventOccurrence(
            eventID: "e1",
            title: "Standup",
            startsAt: Timestamp(start),
            endsAt: Timestamp(start.addingTimeInterval(1800)),
            recurrence: Recurrence(frequency: .weekly)
        )
        let written = LockIsolated<[(EventID, EventScope, Date?, EventEdit)]>([])
        let store = TestStore(
            initialState: EventComposerFeature.State(
                homeID: "h1",
                members: Self.members,
                currentUserID: "u1",
                day: CalendarDay(start),
                editing: occurrence
            )
        ) {
            EventComposerFeature()
        } withDependencies: {
            $0.events.update = { id, scope, at, edit in
                written.withValue { $0.append((id, scope, at, edit)) }
                // An occurrence-scope edit detaches that date as its own event,
                // so the server answers with the id it actually wrote — which is
                // what anything attached afterwards has to point at.
                return scope == .occurrence ? "e1-detached" : id
            }
        }
        store.exhaustivity = .off

        await store.send(.submitTapped)
        // A repeating event has to say which of it an edit means, and the answer
        // changes what is written rather than just what is confirmed.
        #expect(store.state.scopeDialog != nil)

        await store.send(.scopeDialog(.presented(.saveThisOne)))
        await store.receive(\.saved)

        #expect(written.value.count == 1)
        let (_, scope, at, edit) = written.value[0]
        #expect(scope == .occurrence)
        #expect(at == start)
        // The detached copy is one date now, by definition.
        #expect(edit.recurrence == .some(nil))
    }
}

@MainActor
@Suite("Event plan")
struct EventPlanTests {

    private static let occurrence = EventOccurrence(
        eventID: "e1",
        homeID: "h1",
        title: "House party",
        kind: .houseParty,
        startsAt: Timestamp(Date(timeIntervalSince1970: 1_757_000_000)),
        endsAt: Timestamp(Date(timeIntervalSince1970: 1_757_014_400)),
        budget: 15_000,
        currency: "EUR",
        recipeIDs: ["r1"]
    )

    @Test("Ticking an item off moves the counter, not just the row")
    func tickingAnItemMovesTheTotal() async {
        let item = EventPlan.LinkedItem(id: "s1", name: "Ice")
        let plan = EventPlan(
            eventID: "e1",
            currency: "EUR",
            budget: 15_000,
            spent: 4_000,
            shopping: [item, EventPlan.LinkedItem(id: "s2", name: "Candles")],
            shoppingTotal: 2,
            shoppingPurchased: 0
        )
        let store = TestStore(
            initialState: EventDetailFeature.State(
                occurrence: Self.occurrence,
                members: [],
                currentUserID: "u1"
            )
        ) {
            EventDetailFeature()
        } withDependencies: {
            $0.shopping.setPurchased = { _, _ in }
        }
        store.exhaustivity = .off

        await store.send(.planUpdated(plan))
        await store.send(.itemToggled("s1", true))
        // The plan arrives pre-totalled, so an optimistic tick has to move the
        // ring as well as the row or "0 of 2" sits over a list showing one.
        #expect(store.state.plan?.shoppingPurchased == 1)
        #expect(store.state.plan?.shopping.first?.isPurchased == true)
    }

    @Test("A budget reads as spent against, and over")
    func budgetArithmetic() {
        var plan = EventPlan(eventID: "e1", currency: "EUR", budget: 10_000, spent: 4_000)
        #expect(plan.remaining == 6_000)
        #expect(!plan.isOverBudget)
        #expect(plan.budgetProgress == 0.4)

        plan.spent = 12_500
        #expect(plan.remaining == -2_500)
        #expect(plan.isOverBudget)
        // Clamped rather than overflowing the arc; the number beside the ring is
        // what says by how much.
        #expect(plan.budgetProgress == 1)
    }

    @Test("Logging a spend from an event carries the link, and the event's date")
    func expenseComposerCarriesTheLink() async {
        let store = TestStore(
            initialState: EventDetailFeature.State(
                occurrence: Self.occurrence,
                members: [User(id: "u1", name: "Ada")],
                currentUserID: "u1"
            )
        ) {
            EventDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.addExpenseTapped)
        let composer = store.state.expense
        #expect(composer?.eventID == "e1")
        // An expense logged the morning after a party belongs to the party.
        #expect(composer?.spentAt == Self.occurrence.start)
        #expect(composer?.title == "House party")
        #expect(composer?.payload.eventID == "e1")
    }
}

@MainActor
@Suite("Dinner as an occasion")
struct DinnerOccasionTests {

    @Test("Making a dinner an occasion writes the event first, then links the plan to it")
    func occasionCreatesAnEventAndLinksIt() async {
        let recipe = Recipe(id: "r1", title: "Lasagne", ingredients: ["Pasta"], homeID: "h1")
        let created = LockIsolated<[NewEvent]>([])
        let planned = LockIsolated<[DinnerDecision]>([])

        let store = TestStore(
            initialState: DinnerFeature.State(homeID: "h1", date: "2026-09-12", memberCount: 2)
        ) {
            DinnerFeature()
        } withDependencies: {
            $0.events.create = { new in
                created.withValue { $0.append(new) }
                return "e-new"
            }
            $0.meals.set = { decision in
                planned.withValue { $0.append(decision) }
            }
        }
        store.exhaustivity = .off

        await store.send(.recipesUpdated([recipe]))
        await store.send(.kindChosen(.cook))
        await store.send(.recipeChosen(recipe))
        await store.send(.occasionToggled)
        #expect(store.state.makeItAnOccasion)
        // Seeded on the evening of the day being planned, not on whatever day
        // the sheet was opened.
        #expect(store.state.occasionStart == MealDate.eveningOf("2026-09-12"))

        // A household that eats at nine should not have to fix it afterwards.
        let nine = MealDate.at(
            Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!,
            on: "2026-09-12"
        )
        await store.send(.binding(.set(\.occasionStart, nine)))

        await store.send(.saveTapped)
        await store.receive(\.saved)

        // The event first, so the meal plan has something to point at — the
        // other order would leave a plan referring to nothing.
        #expect(created.value.count == 1)
        #expect(created.value[0].kind == .dinnerParty)
        // The dish is the menu, which is what makes the shopping list and the
        // budget work on the calendar side.
        #expect(created.value[0].recipeIDs == ["r1"])
        #expect(created.value[0].startsAt == nine)

        #expect(planned.value.count == 1)
        #expect(planned.value[0].eventID == "e-new")
        #expect(planned.value[0].recipeID == "r1")
    }

    @Test("An ordinary dinner stays out of the calendar")
    func plainDinnerCreatesNoEvent() async {
        let recipe = Recipe(id: "r1", title: "Pasta", homeID: "h1")
        let created = LockIsolated(0)
        let store = TestStore(
            initialState: DinnerFeature.State(homeID: "h1", date: "2026-09-12", memberCount: 2)
        ) {
            DinnerFeature()
        } withDependencies: {
            $0.events.create = { _ in created.withValue { $0 += 1 }; return "e" }
            $0.meals.set = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.recipesUpdated([recipe]))
        await store.send(.kindChosen(.cook))
        await store.send(.recipeChosen(recipe))
        await store.send(.saveTapped)
        await store.receive(\.saved)

        // Most dinners are a decision, not an occasion; a calendar full of
        // "Tuesday: pasta" is one nobody reads.
        #expect(created.value == 0)
    }

    @Test("An event with a menu can become that day's dinner")
    func eventBecomesDinner() async {
        let start = Date().addingTimeInterval(3 * 24 * 3600)
        let occurrence = EventOccurrence(
            eventID: "e1",
            homeID: "h1",
            title: "House party",
            kind: .houseParty,
            startsAt: Timestamp(start),
            endsAt: Timestamp(start.addingTimeInterval(4 * 3600)),
            recipeIDs: ["r1"]
        )
        let planned = LockIsolated<[DinnerDecision]>([])
        let store = TestStore(
            initialState: EventDetailFeature.State(
                occurrence: occurrence,
                members: [],
                currentUserID: "u1"
            )
        ) {
            EventDetailFeature()
        } withDependencies: {
            $0.meals.set = { decision in planned.withValue { $0.append(decision) } }
        }
        store.exhaustivity = .off

        #expect(store.state.canPlanDinner)
        await store.send(.planAsDinnerTapped)
        await store.receive(\.dinnerPlanned)

        #expect(planned.value.count == 1)
        #expect(planned.value[0].eventID == "e1")
        #expect(planned.value[0].date == MealDate.key(start))
        #expect(store.state.didPlanDinner)
    }

    @Test("A trip is not offered as dinner")
    func multiDayEventsCannotBeDinner() {
        let start = Date()
        let trip = EventOccurrence(
            eventID: "e2",
            title: "Trip",
            kind: .trip,
            startsAt: Timestamp(start),
            endsAt: Timestamp(start.addingTimeInterval(3 * 24 * 3600)),
            recipeIDs: ["r1"]
        )
        let state = EventDetailFeature.State(occurrence: trip, members: [], currentUserID: "u1")
        // A meal plan is one row per home per *day*, so a three-day event has no
        // single dinner to be — offering it would silently pick one.
        #expect(!state.canPlanDinner)
    }
}

@MainActor
@Suite("Hub module counts")
struct HubCountsTests {

    @Test("A tile that has not answered is pending, not zero")
    func countsStartPending() async {
        let state = HubFeature.State(homeID: "h1")
        // Every count reads 0 before anything arrives, which is also what an
        // empty household reads. The tiles have to be able to tell those apart
        // or the Hub opens stating, as fact, that there is nothing anywhere.
        #expect(state.shoppingCount == 0)
        #expect(state.loaded.isEmpty)
    }

    @Test("Each subscription settles its own tile and leaves the rest waiting")
    func countsSettleIndependently() async {
        let store = TestStore(initialState: HubFeature.State(homeID: "h1")) {
            HubFeature()
        }

        await store.send(.countsUpdated(recipes: 4)) {
            $0.recipeCount = 4
            $0.loaded.insert(.recipes)
        }
        // The other four have said nothing, so they are still pending rather
        // than reporting the zero they were initialised with.
        #expect(!store.state.loaded.contains(.shopping))
        #expect(!store.state.loaded.contains(.billsDue))

        await store.send(.countsUpdated(shopping: 0)) {
            $0.loaded.insert(.shopping)
        }
        // Zero is an answer. Having arrived, the tile stops waiting and shows it.
        #expect(store.state.loaded.contains(.shopping))
        #expect(store.state.shoppingCount == 0)
    }
}
