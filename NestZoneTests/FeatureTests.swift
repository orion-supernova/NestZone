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
            $0.alert = .confirmLeave(home, isSoleMember: true)
        }
    }
}

@MainActor
@Suite("Shopping list")
struct ShoppingTests {

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

    @Test("Closing a poll clears the deck and cancels the detail subscription")
    func closedPollResets() async {
        var state = MovieNightFeature.State(homeID: "h1", memberCount: 2)
        state.poll = Poll(id: "p1")
        state.deck = [PollItem(id: "i1", externalID: "dune")]
        state.swiped = ["dune"]

        let store = TestStore(initialState: state) { MovieNightFeature() }

        await store.send(.pollsUpdated([Poll(id: "p1", status: .closed)])) {
            $0.isLoading = false
            $0.poll = nil
            $0.detail = nil
            $0.deck = []
            $0.swiped = []
        }
    }
}
