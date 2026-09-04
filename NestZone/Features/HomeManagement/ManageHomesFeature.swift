import ComposableArchitecture
import Foundation

/// Managing the homes you belong to from inside the app: switch between them,
/// create or join another, leave one, or delete the last one.
///
/// This is the sheet the pre-TCA app opened from Settings. The rewrite replaced
/// it with a delegate that cleared the selected home and dropped the user back
/// on the full-screen gate, which cannot work for the common case of belonging
/// to exactly one home: the gate re-selects a lone home the moment its
/// subscription yields, so the screen bounced straight back and leaving or
/// deleting a home became unreachable.
///
/// The home list is not subscribed to here. `homes:listMine` has exactly one
/// subscription in the app, owned by `HomeManagementFeature`; `AppFeature`
/// copies each update down into `SettingsFeature`, which forwards it here.
@Reducer
public struct ManageHomesFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homes: IdentifiedArrayOf<Home>
        /// The home currently open, marked in the list and the one the
        /// bottom destructive row acts on.
        public var currentHomeID: HomeID
        /// Non-nil while `homes:leave` is in flight. A row's disabled state is
        /// not enough on its own — two taps in one frame both queue work before
        /// the first render.
        public var leavingID: HomeID?

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homes: IdentifiedArrayOf<Home> = [], currentHomeID: HomeID) {
            self.homes = homes
            self.currentHomeID = currentHomeID
        }

        public var currentHome: Home? { homes[id: currentHomeID] }

        /// The server cascades a home away when its last member leaves, so the
        /// copy has to say "delete" rather than "leave".
        public func isSoleMember(of home: Home) -> Bool { home.members.count <= 1 }
    }

    @Reducer
    public enum Destination {
        case create(CreateHomeFeature)
        case join(JoinHomeFeature)
    }

    public enum Action {
        case homeTapped(HomeID)
        case leaveTapped(HomeID)
        case leaveFinished
        case leaveFailed(AppError)
        case createTapped
        case joinTapped
        case doneTapped
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {
            case confirmLeave(HomeID)
        }

        @CasePathable
        public enum Delegate: Equatable {
            case switchRequested(HomeID)
            case dismissRequested
        }
    }

    @Dependency(\.homes) var homesClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .homeTapped(id):
                // Tapping the home already open just closes the sheet.
                guard id != state.currentHomeID else {
                    return .send(.delegate(.dismissRequested))
                }
                return .send(.delegate(.switchRequested(id)))

            case let .leaveTapped(id):
                guard state.leavingID == nil, let home = state.homes[id: id] else { return .none }
                state.alert = .confirmLeave(
                    home,
                    isSoleMember: state.isSoleMember(of: home),
                    confirm: .confirmLeave(id)
                )
                return .none

            case let .alert(.presented(.confirmLeave(id))):
                guard state.leavingID == nil else { return .none }
                state.leavingID = id
                // Optimistic, like every other write: the row goes now and the
                // live `homes:listMine` update confirms it. Leaving the home
                // that is open tears this sheet down with the tab container.
                state.homes.remove(id: id)
                return .run { send in
                    try await homesClient.leave(id)
                    await send(.leaveFinished)
                } catch: { error, send in
                    await send(.leaveFailed(AppError(error)))
                }

            case .leaveFinished:
                state.leavingID = nil
                return .none

            case let .leaveFailed(error):
                state.leavingID = nil
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .createTapped:
                state.destination = .create(CreateHomeFeature.State())
                return .none

            case .joinTapped:
                state.destination = .join(JoinHomeFeature.State())
                return .none

            case .doneTapped:
                return .send(.delegate(.dismissRequested))

            // The new home arrives on the live list, so the sheet only has to
            // close the form it was showing.
            case .destination(.presented(.create(.finished))),
                 .destination(.presented(.join(.finished))):
                state.destination = nil
                return .none

            case .destination, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension ManageHomesFeature.Destination.State: Equatable {}
