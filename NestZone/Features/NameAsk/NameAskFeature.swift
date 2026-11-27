import ComposableArchitecture
import Foundation

/// The one question asked before the house: what should your housemates call
/// you?
///
/// Sign in with Apple hands over a name only on the very first authorization,
/// and only if the person left it in Apple's sheet, so an account can reach the
/// house without one and every housemate then reads it as "Someone". This asks
/// once. It saves nothing itself: `AppFeature` owns the signed-in user, so it
/// writes optimistically there, and puts the name back if the write fails.
@Reducer
public struct NameAskFeature: Sendable {
    /// Long enough for any real name, short enough to fit on one line of a
    /// housemate's screen.
    public static let nameLimit = 40

    @ObservableState
    public struct State: Equatable {
        public var name = ""
        public var inlineError: String?
        /// A tap on Continue, so the haptic is the person's own and never a
        /// live subscription's.
        public var continues = 0

        public init() {}

        public var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
        public var canContinue: Bool { !trimmed.isEmpty }
    }

    public enum Action: Equatable, BindableAction {
        case continueTapped
        case laterTapped
        case delegate(Delegate)
        case binding(BindingAction<State>)

        public enum Delegate: Equatable {
            case save(String)
            case later
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.name):
                if state.name.count > Self.nameLimit {
                    state.name = String(state.name.prefix(Self.nameLimit))
                }
                state.inlineError = nil
                return .none

            case .continueTapped:
                guard state.canContinue else { return .none }
                state.continues += 1
                state.inlineError = nil
                return .send(.delegate(.save(state.trimmed)))

            case .laterTapped:
                return .send(.delegate(.later))

            case .binding, .delegate:
                return .none
            }
        }
    }
}
