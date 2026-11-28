import ComposableArchitecture
import Foundation

/// The tour: a few short pages about what the app is for, then (the first
/// time) the way into a home.
///
/// One reducer and one view for both ways in. `.firstRun` is the person's
/// first launch with no home: it ends in the create and join sheets the
/// no-home screen already uses (`CreateHomeFeature`, `JoinHomeFeature`), and
/// says so to its parent, which owns what happens next. `.replay` is Settings'
/// "Take the tour": the same pages, no question and no way into a home, closed
/// by `delegate(.finished)`.
///
/// It never navigates and never writes the "seen" flag: `AppFeature` does,
/// when the person has a home, so a launch killed half way shows it again.
@Reducer
public struct OnboardingFeature: Sendable {
    public enum Mode: Equatable, Sendable { case firstRun, replay }

    public enum Page: Hashable, Sendable {
        case welcome, household, lists, plans, house, nestie
        /// First run's last page: create a home or join one.
        case start
        /// Replay's last page.
        case done
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var pages: [Page]
        public var index = 0
        var household: HouseholdKind?
        @Presents public var destination: Destination.State?

        public init(mode: Mode) {
            self.mode = mode
            switch mode {
            case .firstRun:
                pages = [.welcome, .household, .lists, .plans, .house, .nestie, .start]
            case .replay:
                // The question was answered once; asking again is a form.
                pages = [.welcome, .lists, .plans, .house, .nestie, .done]
            }
            @Shared(.householdKind) var stored
            household = HouseholdKind(rawValue: stored)
        }

        public var page: Page { pages[min(max(index, 0), pages.count - 1)] }
        public var isLast: Bool { index >= pages.count - 1 }
        /// The pages before the last one can be skipped past.
        public var canSkip: Bool { !isLast }
    }

    @Reducer
    public enum Destination {
        case create(CreateHomeFeature)
        case join(JoinHomeFeature)
    }

    public enum Action: BindableAction {
        case continueTapped
        case skipTapped
        case closeTapped
        case householdPicked(HouseholdKind)
        case createTapped
        case joinTapped
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
        case binding(BindingAction<State>)

        @CasePathable
        public enum Delegate: Equatable {
            /// Replay is over, by its last page, Skip or Close.
            case finished
            /// A home was created or joined from the last page, and its sheet
            /// has closed. The home itself arrives on `homes:listMine`.
            case homeReady
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .continueTapped:
                if state.isLast {
                    return state.mode == .replay ? .send(.delegate(.finished)) : .none
                }
                state.index += 1
                return .none

            case .skipTapped:
                // First run lands on the way into a home; a replay just ends.
                guard state.mode == .firstRun else { return .send(.delegate(.finished)) }
                state.index = state.pages.count - 1
                return .none

            case .closeTapped:
                return .send(.delegate(.finished))

            case let .householdPicked(kind):
                state.household = kind
                @Shared(.householdKind) var stored
                $stored.withLock { $0 = kind.rawValue }
                return .none

            case .createTapped:
                guard state.mode == .firstRun else { return .none }
                state.destination = .create(CreateHomeFeature.State())
                return .none

            case .joinTapped:
                guard state.mode == .firstRun else { return .none }
                state.destination = .join(JoinHomeFeature.State())
                return .none

            // The write is the live `homes:listMine` stream's to confirm; the
            // sheet only has to close, and the parent to know a home is there.
            case .destination(.presented(.create(.finished))),
                 .destination(.presented(.join(.finished))):
                state.destination = nil
                return .send(.delegate(.homeReady))

            case .destination, .delegate, .binding:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension OnboardingFeature.Destination.State: Equatable {}
