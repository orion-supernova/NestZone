import ComposableArchitecture
import Foundation

/// The shared shopping list.
@Reducer
public struct ShoppingFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var items: IdentifiedArrayOf<ShoppingItem> = []
        public var isLoading = true
        public var draft = ""
        public var draftCategory: ShoppingItem.Category = .groceries
        @Shared(.shoppingGrouped) public var isGrouped: Bool
        /// Categories the user has collapsed. Not persisted — a collapse is a
        /// "get this out of my way for now", not a preference.
        public var collapsed: Set<ShoppingItem.Category> = []
        /// Meals the user has folded away. Same reasoning as `collapsed`: a
        /// fifteen-ingredient recipe pushes the rest of the shop off screen.
        public var collapsedMeals: Set<RecipeID> = []
        /// Swiped away, but not yet sent to the server. The row is already gone
        /// from `items`; if the undo window closes without a tap, this is what
        /// gets deleted for real. One at a time — a second swipe commits the
        /// first, the way a mail client does.
        public var pendingDeletion: ShoppingItem?
        /// Rows this screen is pretending are gone: one sitting out its undo
        /// window, or a whole group whose deletes are still in flight.
        ///
        /// The server still has every one of them until its write lands, so
        /// without this mask each live push puts them straight back — which is
        /// exactly why clearing an aisle or a meal used to make the group
        /// reappear and then vanish a row at a time. Self-clearing: once the
        /// server stops sending a row, it no longer needs hiding.
        public var hidden: Set<ShoppingItemID> = []
        /// Groups whose clear is still in flight, so the header can say so
        /// rather than leaving a destructive action looking like a no-op if the
        /// network is slow.
        public var clearing: Set<ClearTarget> = []
        /// Items typed into the composer and not yet confirmed by the server.
        /// They have no id until then, so they cannot be shown as rows — but
        /// the send button can say the work is happening.
        public var pendingAdds = 0
        @Presents public var alert: AlertState<Action.Alert>?

        /// Which group a clear is working on. Nothing but an identity for the
        /// busy indicator.
        public enum ClearTarget: Hashable, Sendable {
            case category(ShoppingItem.Category)
            case meal(RecipeID)
            case purchased
        }

        public func isClearing(_ target: ClearTarget) -> Bool { clearing.contains(target) }

        public init(homeID: HomeID) { self.homeID = homeID }

        /// Outstanding items, grouped by category and ordered so the aisles read
        /// in a stable order rather than by whatever the dictionary yields.
        public var pendingByCategory: [(category: ShoppingItem.Category, items: [ShoppingItem])] {
            let pending = unsourced
            return ShoppingItem.Category.allCases.compactMap { category in
                let matching = pending
                    .filter { $0.category == category }
                    .sorted { Timestamp.newestFirst($0.created, $1.created) }
                return matching.isEmpty ? nil : (category, matching)
            }
        }

        /// Outstanding items that came from a recipe, gathered under it.
        ///
        /// Grouped by id but titled from the item, so a meal still reads
        /// correctly after its recipe has been deleted. Newest meal first —
        /// what you are shopping for now is what you just added.
        public var mealGroups: [(recipeID: RecipeID, title: String, items: [ShoppingItem])] {
            let sourced = items.filter { !$0.isPurchased && $0.recipeID != nil }
            let byRecipe = Dictionary(grouping: sourced) { $0.recipeID! }
            return byRecipe
                .map { id, group in
                    (
                        recipeID: id,
                        title: group.first?.recipeTitle ?? "",
                        items: group.sorted { Timestamp.newestFirst($0.created, $1.created) }
                    )
                }
                .sorted { lhs, rhs in
                    Timestamp.newestFirst(lhs.items.first?.created, rhs.items.first?.created)
                }
        }

        /// Everything a meal group does not already cover, so an item appears
        /// under its recipe or under its aisle — never twice.
        private var unsourced: [ShoppingItem] {
            items.filter { !$0.isPurchased && $0.recipeID == nil }
        }

        public var purchased: [ShoppingItem] {
            items
                .filter(\.isPurchased)
                .sorted { Timestamp.newestFirst($0.updated, $1.updated) }
        }

        public var canAdd: Bool {
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// Everything outstanding, newest first — the flat view.
        public var pendingFlat: [ShoppingItem] {
            unsourced.sorted { Timestamp.newestFirst($0.created, $1.created) }
        }

        public var totalCount: Int { items.count }
        public var doneCount: Int { items.filter(\.isPurchased).count }
        public var leftCount: Int { totalCount - doneCount }

        /// How far through the shop you are, for the header ring.
        public var progress: Double {
            guard totalCount > 0 else { return 0 }
            return Double(doneCount) / Double(totalCount)
        }

        public func isCollapsed(_ category: ShoppingItem.Category) -> Bool {
            collapsed.contains(category)
        }

        public func isCollapsed(meal recipeID: RecipeID) -> Bool {
            collapsedMeals.contains(recipeID)
        }

        /// Counts across the whole meal, bought or not, so a folded row still
        /// says how far through it you are.
        public func doneCount(inMeal recipeID: RecipeID) -> Int {
            items.filter { $0.recipeID == recipeID && $0.isPurchased }.count
        }

        public func totalCount(inMeal recipeID: RecipeID) -> Int {
            items.filter { $0.recipeID == recipeID }.count
        }

        public func doneCount(in category: ShoppingItem.Category) -> Int {
            items.filter { $0.category == category && $0.isPurchased }.count
        }

        public func totalCount(in category: ShoppingItem.Category) -> Int {
            items.filter { $0.category == category }.count
        }
    }

    public enum Action: BindableAction {
        case task
        case itemsUpdated([ShoppingItem])
        case loadFailed(AppError)
        case addTapped
        case togglePurchased(ShoppingItemID)
        case deleteTapped(ShoppingItemID)
        case undoDeleteTapped
        case deleteWindowClosed(ShoppingItemID)
        case clearPurchasedTapped
        case clearCategoryTapped(ShoppingItem.Category)
        case clearMealTapped(RecipeID)
        case deleteCommitFailed(ShoppingItem, AppError)
        case clearFinished(State.ClearTarget)
        case clearFailed(State.ClearTarget, [ShoppingItemID], AppError)
        case addFinished
        case addFailed(String, AppError)
        case toggleFailed(ShoppingItemID, wasPurchased: Bool, AppError)
        case viewModeToggled(grouped: Bool)
        case categoryToggled(ShoppingItem.Category)
        case mealToggled(RecipeID)
        case writeFailed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmClearPurchased
            case confirmClearCategory(ShoppingItem.Category)
            case confirmClearMeal(RecipeID)
        }
    }

    private enum CancelID { case items, undo }

    /// How long a swipe stays undoable. Long enough to notice the mistake,
    /// short enough that leaving the screen rarely cuts it short.
    private static let undoWindow: Duration = .seconds(5)

    @Dependency(\.shopping) var shopping
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return .run { [homeID = state.homeID] send in
                    for try await items in shopping.byHome(homeID) {
                        await send(.itemsUpdated(items))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.items, cancelInFlight: true)

            case let .itemsUpdated(items):
                state.isLoading = false
                var incoming = IdentifiedArray(uniqueElements: items)
                // Anything the server has already dropped no longer needs
                // hiding; keeping it would leak the mask across a re-add.
                state.hidden.formIntersection(incoming.ids)
                // A row inside its undo window, or one whose group delete has
                // not landed yet, is gone as far as this screen is concerned —
                // but the server still has it, so the next live push would
                // otherwise put it straight back.
                for id in state.hidden { incoming.remove(id: id) }
                state.items = incoming
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .addTapped:
                guard state.canAdd else { return .none }
                let item = NewShoppingItem(
                    name: state.draft,
                    category: state.draftCategory,
                    homeID: state.homeID
                )
                // Clear the field straight away so the next item can be typed
                // while this one is still in flight — the live subscription will
                // slot it into the list when the server confirms. If it does not,
                // the words come back: a rejected write leaves nothing on the
                // server to push, and losing what somebody typed is the one
                // failure they cannot recover from themselves.
                let typed = state.draft
                state.draft = ""
                state.pendingAdds += 1
                return .run { send in
                    try await shopping.create(item)
                    await send(.addFinished)
                } catch: { error, send in
                    await send(.addFinished)
                    await send(.addFailed(typed, AppError(error)))
                }

            case .addFinished:
                state.pendingAdds = max(0, state.pendingAdds - 1)
                return .none

            case let .togglePurchased(id):
                guard let item = state.items[id: id] else { return .none }
                let newValue = !item.isPurchased
                // Optimistic, and undone by hand if the write is refused —
                // there is no server-side change for a subscription to correct
                // this with.
                state.items[id: id]?.isPurchased = newValue
                return .run { send in
                    try await shopping.setPurchased(id, newValue)
                } catch: { error, send in
                    await send(.toggleFailed(id, wasPurchased: item.isPurchased, AppError(error)))
                }

            case let .deleteTapped(id):
                guard let item = state.items[id: id] else { return .none }
                // The row goes now — waiting for the server reads as a swipe
                // that did not take — but the write is held back until the undo
                // window closes, so undo cancels it rather than reversing it.
                state.items.remove(id: id)
                state.hidden.insert(id)
                let superseded = state.pendingDeletion
                state.pendingDeletion = item

                return .merge(
                    // A second swipe ends the first one's window; that item was
                    // offered back and the offer was not taken.
                    superseded.map { commit($0) } ?? .none,

                    .run { send in
                        try await clock.sleep(for: Self.undoWindow)
                        await send(.deleteWindowClosed(item.id))
                    }
                    .cancellable(id: CancelID.undo, cancelInFlight: true)
                )

            case .undoDeleteTapped:
                guard let item = state.pendingDeletion else { return .none }
                state.pendingDeletion = nil
                state.hidden.remove(item.id)
                // Nothing was ever sent, so this is the whole restore. The live
                // subscription still holds the item and will agree.
                state.items.append(item)
                return .cancel(id: CancelID.undo)

            case let .deleteWindowClosed(id):
                guard let item = state.pendingDeletion, item.id == id else { return .none }
                state.pendingDeletion = nil
                return commit(item)

            case let .deleteCommitFailed(item, error):
                // The write never happened, and the mask would otherwise keep
                // hiding a row the server still has — a delete that quietly did
                // not delete, until the screen was reopened.
                state.hidden.remove(item.id)
                state.items.append(item)
                return .send(.writeFailed(error))

            case let .viewModeToggled(grouped):
                state.$isGrouped.withLock { $0 = grouped }
                return .none

            case let .categoryToggled(category):
                if state.collapsed.contains(category) {
                    state.collapsed.remove(category)
                } else {
                    state.collapsed.insert(category)
                }
                return .none

            case let .mealToggled(recipeID):
                if state.collapsedMeals.contains(recipeID) {
                    state.collapsedMeals.remove(recipeID)
                } else {
                    state.collapsedMeals.insert(recipeID)
                }
                return .none

            case .clearPurchasedTapped:
                guard !state.purchased.isEmpty else { return .none }
                state.alert = .confirmClearPurchased()
                return .none

            case let .clearCategoryTapped(category):
                let items = state.items.filter { $0.category == category && $0.recipeID == nil }
                guard !items.isEmpty else { return .none }
                state.alert = .confirmClearGroup(
                    name: String(localized: category.title),
                    count: items.count,
                    action: .confirmClearCategory(category)
                )
                return .none

            case let .clearMealTapped(recipeID):
                let items = state.items.filter { $0.recipeID == recipeID }
                guard let name = items.first?.recipeTitle, !items.isEmpty else { return .none }
                state.alert = .confirmClearGroup(
                    name: name,
                    count: items.count,
                    action: .confirmClearMeal(recipeID)
                )
                return .none

            case let .alert(.presented(.confirmClearCategory(category))):
                // An aisle heading only ever covers items that came from no
                // recipe; a meal's ingredients belong to the meal.
                return clear(&state, target: .category(category)) {
                    $0.category == category && $0.recipeID == nil
                }

            case let .alert(.presented(.confirmClearMeal(recipeID))):
                return clear(&state, target: .meal(recipeID)) { $0.recipeID == recipeID }

            case .alert(.presented(.confirmClearPurchased)):
                return clear(&state, target: .purchased, where: \.isPurchased)

            case let .clearFinished(target):
                state.clearing.remove(target)
                return .none

            case let .clearFailed(target, ids, error):
                state.clearing.remove(target)
                // The write never happened, so the rows are still there. Stop
                // hiding them rather than leaving the group silently missing
                // until the screen is reopened.
                for id in ids { state.hidden.remove(id) }
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .addFailed(typed, error):
                // Only if the box is still empty. Somebody who has already
                // started the next item would rather keep it than have the
                // rejected one shoved back over the top.
                if state.draft.isEmpty { state.draft = typed }
                return .send(.writeFailed(error))

            case let .toggleFailed(id, wasPurchased, error):
                state.items[id: id]?.isPurchased = wasPurchased
                return .send(.writeFailed(error))

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension ShoppingFeature {
    /// Clears a whole group in one go.
    ///
    /// The rows go immediately and stay hidden until the write lands. Before,
    /// this fired one `shopping:remove` per row: each landed separately, each
    /// pushed its own `listByHome` update, and every one of those pushes put the
    /// not-yet-deleted survivors back on screen — so an emptied aisle flickered
    /// back and then drained a row at a time. It is one mutation now, so the
    /// group is gone in one frame and comes back only if the write actually
    /// failed.
    private func clear(
        _ state: inout State,
        target: State.ClearTarget,
        where matches: (ShoppingItem) -> Bool
    ) -> Effect<Action> {
        let ids = state.items.filter(matches).map(\.id)
        guard !ids.isEmpty else { return .none }
        for id in ids {
            state.items.remove(id: id)
            state.hidden.insert(id)
        }
        state.clearing.insert(target)
        return .run { send in
            try await shopping.removeMany(ids)
            await send(.clearFinished(target))
        } catch: { error, send in
            await send(.clearFailed(target, ids, AppError(error)))
        }
    }

    /// The write the swipe was always going to make, once nobody has undone it.
    ///
    /// Takes the whole item rather than its id so a failure can put the row
    /// back: the screen dropped it optimistically and nothing else remembers it.
    private func commit(_ item: ShoppingItem) -> Effect<Action> {
        .run { _ in
            try await shopping.remove(item.id)
        } catch: { error, send in
            await send(.deleteCommitFailed(item, AppError(error)))
        }
    }
}

extension AlertState where Action == ShoppingFeature.Action.Alert {
    /// Emptying a whole aisle or a whole meal. It says how many and from what,
    /// because "remove all" on a folded group is otherwise a leap of faith.
    static func confirmClearGroup(name: String, count: Int, action: Action) -> Self {
        AlertState {
            TextState(String(localized: L10n.shoppingClearGroupTitle(count)))
        } actions: {
            ButtonState(role: .destructive, action: action) {
                TextState(String(localized: L10n.shoppingRemoveAll))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.shoppingClearGroupMessage(name)))
        }
    }

    static func confirmClearPurchased() -> Self {
        AlertState {
            TextState(String(localized: L10n.shoppingClearPurchased))
        } actions: {
            ButtonState(role: .destructive, action: .confirmClearPurchased) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        }
    }
}

extension ShoppingItem.Category {
    public var title: LocalizedStringResource {
        switch self {
        case .groceries: L10n.shoppingCategoryGroceries
        case .household: L10n.shoppingCategoryHousehold
        case .cleaning: L10n.shoppingCategoryCleaning
        case .other: L10n.shoppingCategoryOther
        }
    }

    public var symbol: String {
        switch self {
        case .groceries: "carrot.fill"
        case .household: "house.fill"
        case .cleaning: "bubbles.and.sparkles.fill"
        case .other: "shippingbox.fill"
        }
    }
}
