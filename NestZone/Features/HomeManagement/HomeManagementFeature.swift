import ComposableArchitecture
import Foundation

/// The gate between signing in and using the app: create a home, join one with
/// an invite code, or pick which of several to open.
///
/// This replaces `HomeSelectionManager.shared` — a singleton that owned the
/// selected home, wrote it to `UserDefaults` itself, and announced changes by
/// posting `.homeDidChange` on `NotificationCenter`, which every view model
/// subscribed to and answered with a full refetch.
@Reducer
public struct HomeManagementFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        /// Homes the user belongs to, streamed from the server.
        public var homes: IdentifiedArrayOf<Home> = []
        public var isLoading = true
        @Shared(.selectedHomeIDRaw) public var selectedHomeIDRaw: String?
        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}

        /// True once we know the user has no home at all.
        public var isEmpty: Bool { !isLoading && homes.isEmpty }
    }

    @Reducer
    public enum Destination {
        case create(CreateHomeFeature)
        case join(JoinHomeFeature)
    }

    public enum Action: BindableAction {
        case task
        case homesUpdated([Home])
        case homesFailed(AppError)
        case createTapped
        case joinTapped
        case homeSelected(HomeID)
        case leaveTapped(HomeID)
        case leaveConfirmed(HomeID)
        case leaveFailed(AppError)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmLeave(HomeID)
        }
    }

    private enum CancelID { case homes }

    @Dependency(\.homes) var homesClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                // One live subscription for the whole app. Nothing else fetches
                // `homes:listMine`.
                // `cancelInFlight` matters: this is sent both by `AppFeature`
                // at sign-in and by the picker when it mounts, and without it
                // the app would hold two subscriptions to the same query.
                return .run { send in
                    for try await homes in homesClient.mine() {
                        await send(.homesUpdated(homes))
                    }
                } catch: { error, send in
                    await send(.homesFailed(AppError(error)))
                }
                .cancellable(id: CancelID.homes, cancelInFlight: true)

            case let .homesUpdated(homes):
                if state.isLoading { state.isLoading = false }
                // Convex re-publishes every live query in the app whenever the
                // query set changes, so this arrives unchanged several times
                // over any time a screen swaps a subscription. Comparing first
                // keeps a redundant push from invalidating the whole tree.
                let incoming = IdentifiedArray(uniqueElements: homes)
                if incoming != state.homes { state.homes = incoming }

                // Drop a stale selection — the home may have been left or
                // deleted on another device.
                if let current = state.$selectedHomeIDRaw.homeID,
                   !state.homes.ids.contains(current) {
                    state.$selectedHomeIDRaw.homeID = nil
                }
                // One home needs no picker.
                if state.$selectedHomeIDRaw.homeID == nil, homes.count == 1 {
                    state.$selectedHomeIDRaw.homeID = homes[0].id
                }
                return .none

            case let .homesFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .createTapped:
                state.destination = .create(CreateHomeFeature.State())
                return .none

            case .joinTapped:
                state.destination = .join(JoinHomeFeature.State())
                return .none

            case let .homeSelected(id):
                state.$selectedHomeIDRaw.homeID = id
                return .none

            case let .leaveTapped(id):
                guard let home = state.homes[id: id] else { return .none }
                // For the last member the server cascades the whole home away,
                // so the prompt has to say "delete", not "leave".
                state.alert = .confirmLeave(
                    home,
                    isSoleMember: home.members.count <= 1,
                    confirm: .confirmLeave(id)
                )
                return .none

            case let .alert(.presented(.confirmLeave(id))),
                 let .leaveConfirmed(id):
                return .run { send in
                    try await homesClient.leave(id)
                } catch: { error, send in
                    await send(.leaveFailed(AppError(error)))
                }

            case let .leaveFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // A successful create or join arrives as a new value on the live
            // `homes:listMine` stream, so the sheet only has to close.
            case .destination(.presented(.create(.finished))),
                 .destination(.presented(.join(.finished))):
                state.destination = nil
                return .none

            case .binding, .destination, .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState {
    /// Leaving is destructive and, for the last member, irreversible — so it
    /// always asks, and says which of the two is about to happen.
    ///
    /// Generic over the action it sends: the gate and the Settings sheet both
    /// offer this, and the wording is the part worth keeping in one place.
    static func confirmLeave(_ home: Home, isSoleMember: Bool, confirm: Action) -> Self {
        AlertState {
            TextState(String(localized: isSoleMember
                ? L10n.homeDeleteConfirmTitle
                : L10n.homeLeaveConfirmTitle))
        } actions: {
            ButtonState(role: .destructive, action: confirm) {
                TextState(String(localized: isSoleMember
                    ? L10n.homeDeleteConfirmAction
                    : L10n.homeLeaveConfirmAction))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: isSoleMember
                ? L10n.homeDeleteConfirmMessage(home.name)
                : L10n.homeLeaveConfirmMessage(home.name)))
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension HomeManagementFeature.Destination.State: Equatable {}
