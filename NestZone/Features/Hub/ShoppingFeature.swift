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
        /// Swiped away, but not yet sent to the server. The row is already gone
        /// from `items`; if the undo window closes without a tap, this is what
        /// gets deleted for real. One at a time — a second swipe commits the
        /// first, the way a mail client does.
        public var pendingDeletion: ShoppingItem?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID) { self.homeID = homeID }

        /// Outstanding items, grouped by category and ordered so the aisles read
        /// in a stable order rather than by whatever the dictionary yields.
        public var pendingByCategory: [(category: ShoppingItem.Category, items: [ShoppingItem])] {
            let pending = items.filter { !$0.isPurchased }
            return ShoppingItem.Category.allCases.compactMap { category in
                let matching = pending
                    .filter { $0.category == category }
                    .sorted { Timestamp.newestFirst($0.created, $1.created) }
                return matching.isEmpty ? nil : (category, matching)
            }
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
            items
                .filter { !$0.isPurchased }
                .sorted { Timestamp.newestFirst($0.created, $1.created) }
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
        case screenLeft
        case clearPurchasedTapped
        case viewModeToggled(grouped: Bool)
        case categoryToggled(ShoppingItem.Category)
        case writeFailed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmClearPurchased
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
                // A row inside its undo window is gone as far as this screen is
                // concerned, but the server still has it — so the next live push
                // would otherwise put it straight back.
                if let pending = state.pendingDeletion {
                    incoming.remove(id: pending.id)
                }
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
                // slot it into the list when the server confirms.
                state.draft = ""
                return .run { send in
                    try await shopping.create(item)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case let .togglePurchased(id):
                guard let item = state.items[id: id] else { return .none }
                let newValue = !item.isPurchased
                state.items[id: id]?.isPurchased = newValue
                return .run { send in
                    try await shopping.setPurchased(id, newValue)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case let .deleteTapped(id):
                guard let item = state.items[id: id] else { return .none }
                // The row goes now — waiting for the server reads as a swipe
                // that did not take — but the write is held back until the undo
                // window closes, so undo cancels it rather than reversing it.
                state.items.remove(id: id)
                let superseded = state.pendingDeletion
                state.pendingDeletion = item

                return .merge(
                    // A second swipe ends the first one's window; that item was
                    // offered back and the offer was not taken.
                    superseded.map { commit($0.id) } ?? .none,

                    .run { send in
                        try await clock.sleep(for: Self.undoWindow)
                        await send(.deleteWindowClosed(item.id))
                    }
                    .cancellable(id: CancelID.undo, cancelInFlight: true)
                )

            case .undoDeleteTapped:
                guard let item = state.pendingDeletion else { return .none }
                state.pendingDeletion = nil
                // Nothing was ever sent, so this is the whole restore. The live
                // subscription still holds the item and will agree.
                state.items.append(item)
                return .cancel(id: CancelID.undo)

            case let .deleteWindowClosed(id):
                guard state.pendingDeletion?.id == id else { return .none }
                state.pendingDeletion = nil
                return commit(id)

            // Leaving the screen tears down the timer with it, which would drop
            // the delete on the floor and let the row reappear. Send it now and
            // give up the rest of the window.
            case .screenLeft:
                guard let item = state.pendingDeletion else { return .none }
                state.pendingDeletion = nil
                return .merge(.cancel(id: CancelID.undo), commit(item.id))

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

            case .clearPurchasedTapped:
                guard !state.purchased.isEmpty else { return .none }
                state.alert = .confirmClearPurchased()
                return .none

            case .alert(.presented(.confirmClearPurchased)):
                let ids = state.purchased.map(\.id)
                return .run { send in
                    // Concurrently, not one after another: clearing a full week's
                    // shop used to be a serial round trip per item.
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for id in ids {
                            group.addTask { try await shopping.remove(id) }
                        }
                        try await group.waitForAll()
                    }
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

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
    /// The write the swipe was always going to make, once nobody has undone it.
    private func commit(_ id: ShoppingItemID) -> Effect<Action> {
        .run { send in
            try await shopping.remove(id)
        } catch: { error, send in
            await send(.writeFailed(AppError(error)))
        }
    }
}

extension AlertState where Action == ShoppingFeature.Action.Alert {
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
