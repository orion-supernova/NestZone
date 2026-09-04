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
    }

    public enum Action: BindableAction {
        case task
        case itemsUpdated([ShoppingItem])
        case loadFailed(AppError)
        case addTapped
        case togglePurchased(ShoppingItemID)
        case deleteTapped(ShoppingItemID)
        case clearPurchasedTapped
        case writeFailed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmClearPurchased
        }
    }

    private enum CancelID { case items }

    @Dependency(\.shopping) var shopping

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
                state.items = IdentifiedArray(uniqueElements: items)
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
                return .run { send in
                    try await shopping.remove(id)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

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
