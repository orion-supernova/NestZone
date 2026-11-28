import ComposableArchitecture
import Foundation

/// The last step of a first run: one real item on the house's real shopping
/// list, so the app has done something before the person has done anything
/// else.
///
/// A small card over the tabs, opened by `MainFeature` once the Plus paywall
/// has closed. It writes through the shopping client every other add goes
/// through and never touches `ShoppingFeature`; going to look at the list is
/// a delegate, which the tab bar answers like any other cross-link.
@Reducer
public struct FirstWinFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var text = ""
        /// What was added, once it has been: the card turns into "Your house
        /// is ready".
        public var added: String?
        /// Cleared on every add and set again on a refusal.
        public var inlineError: String?
        /// Each add is one burst and one haptic.
        public var celebrations = 0

        public init(homeID: HomeID) {
            self.homeID = homeID
        }

        public var canAdd: Bool {
            added == nil && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: BindableAction, Equatable {
        case suggestionTapped(String)
        case addTapped
        /// The write was refused: the card is asking again, with the words
        /// still in the field.
        case addFailed(String, AppError)
        case laterTapped
        case openListTapped
        case doneTapped
        case delegate(Delegate)
        case binding(BindingAction<State>)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
            case openShopping
        }
    }

    @Dependency(\.shopping) var shopping

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .suggestionTapped(name):
                state.text = name
                return add(&state)

            case .addTapped:
                return add(&state)

            case let .addFailed(typed, error):
                // A rejected write left nothing on the server to push, so the
                // card takes its own optimism back: the words return and the
                // reason is said.
                state.added = nil
                state.text = typed
                state.inlineError = error.errorDescription
                return .none

            case .laterTapped, .doneTapped:
                return .send(.delegate(.finished))

            case .openListTapped:
                return .send(.delegate(.openShopping))

            case .delegate, .binding:
                return .none
            }
        }
    }

    /// Optimistic: the card celebrates at once and the list confirms through
    /// its own live subscription.
    private func add(_ state: inout State) -> Effect<Action> {
        let name = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.canAdd else { return .none }
        state.added = name
        state.text = ""
        state.inlineError = nil
        state.celebrations += 1
        let item = NewShoppingItem(name: name, category: .groceries, homeID: state.homeID)
        return .run { _ in
            try await shopping.create(item)
        } catch: { error, send in
            await send(.addFailed(name, AppError(error)))
        }
    }
}
