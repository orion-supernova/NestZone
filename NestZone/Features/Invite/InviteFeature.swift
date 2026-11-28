import ComposableArchitecture
import Foundation

/// "Invite someone": a QR code that changes every ten minutes, and a link to
/// send. Shown over Settings, by any member of the house.
///
/// The code is created when the sheet opens and replaced before it runs out,
/// when it is used up, and on a tap when somebody else's new code revoked it.
/// Nothing runs while the app is not active: the sheet then holds a code the
/// phone may find stale on return, which it checks before showing it again.
@Reducer
public struct InviteFeature: Sendable {
    /// What the share sheet is about to send.
    public struct ShareItem: Equatable, Identifiable, Sendable {
        public let id = UUID()
        public let text: String
    }

    @ObservableState
    public struct State: Equatable {
        public let homeID: HomeID
        public let homeName: String
        public var limit: InviteLimit = .one
        public var qr: HomeInvite?
        public var status: InviteStatus?
        /// A code is being made (the first one, or a replacement).
        public var isCreating = true
        /// One create at a time: a second ask while one is out is queued, and
        /// the one in flight is never cancelled (the server runs it either way,
        /// and its code would be left behind unrevoked).
        var createInFlight = false
        var createQueued = false
        public var errorMessage: String?
        /// Somebody else's new code revoked this one. Replaced on a tap, not
        /// on its own: two phones would otherwise revoke each other for ever.
        public var isRevoked = false
        public var isActive = true
        /// Someone just used the code: the card says so for a moment.
        public var showsJoined = false
        /// People who joined through codes shown in this sheet.
        public var joinedTotal = 0
        /// The person's own taps, for the haptic.
        public var picks = 0
        public var isMakingLink = false
        public var linkInvite: HomeInvite?
        public var share: ShareItem?

        public init(homeID: HomeID, homeName: String) {
            self.homeID = homeID
            self.homeName = homeName
        }
    }

    public enum Action: BindableAction {
        case task
        case sceneActiveChanged(Bool)
        case limitPicked(InviteLimit)
        case refreshTapped
        case created(HomeInvite)
        case createFailed(AppError)
        case statusUpdated(token: String, InviteStatus?)
        case refreshDue(token: String)
        case joinedNoticeExpired
        case shareLinkTapped
        case linkCreated(HomeInvite)
        case linkFailed(AppError)
        case binding(BindingAction<State>)
    }

    private enum CancelID { case create, status, timer, notice }

    /// A code is replaced this long before it expires, so one a person is
    /// about to scan never runs out under their camera.
    static let renewAhead: Duration = .seconds(8)
    /// What the card says "Joined" for, before a used-up code is replaced.
    static let joinedNotice: Duration = .milliseconds(1800)
    /// A link is for a few people at a time.
    static let linkUses = 5

    @Dependency(\.invite) var invite
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                guard state.qr == nil else { return .none }
                return create(&state)

            case let .sceneActiveChanged(active):
                state.isActive = active
                guard active else {
                    return .merge(.cancel(id: CancelID.status), .cancel(id: CancelID.timer))
                }
                guard let qr = state.qr else { return create(&state) }
                // Stale while the app was away: replaced, not shown.
                if qr.expiresAt.timeIntervalSince(now) < 10 { return create(&state) }
                return watch(qr, in: state.homeID)

            case let .limitPicked(limit):
                guard limit != state.limit else { return .none }
                state.limit = limit
                state.picks += 1
                return create(&state)

            case .refreshTapped:
                state.picks += 1
                return create(&state)

            case let .created(code):
                state.createInFlight = false
                // Asked again while this was out: it is already out of date
                // (and the next create revokes it on the server).
                if state.createQueued { return create(&state) }
                state.isCreating = false
                state.errorMessage = nil
                state.isRevoked = false
                state.qr = code
                state.status = nil
                return state.isActive ? watch(code, in: state.homeID) : .none

            case let .createFailed(error):
                state.createInFlight = false
                if state.createQueued { return create(&state) }
                state.isCreating = false
                guard !error.isSilent else { return .none }
                state.errorMessage = error.errorDescription
                return .none

            case let .statusUpdated(token, status):
                // An answer about a code already replaced, arriving late.
                guard token == state.qr?.token, let status else { return .none }
                var effects: [Effect<Action>] = []
                let before = state.status?.uses ?? 0
                if status.uses > before {
                    state.joinedTotal += status.uses - before
                    state.showsJoined = true
                    effects.append(
                        .run { send in
                            try await clock.sleep(for: Self.joinedNotice)
                            await send(.joinedNoticeExpired)
                        }
                        .cancellable(id: CancelID.notice, cancelInFlight: true)
                    )
                }
                state.status = status
                if status.revoked {
                    state.isRevoked = true
                    effects.append(.cancel(id: CancelID.timer))
                } else if status.isUsedUp {
                    // Let "Joined" be seen, then the next person gets a code.
                    effects.append(
                        .run { send in
                            try await clock.sleep(for: Self.joinedNotice)
                            await send(.refreshDue(token: token))
                        }
                        .cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                }
                return .merge(effects)

            case let .refreshDue(token):
                guard token == state.qr?.token, state.isActive else { return .none }
                return create(&state)

            case .joinedNoticeExpired:
                state.showsJoined = false
                return .none

            case .shareLinkTapped:
                state.picks += 1
                if let link = state.linkInvite, link.expiresAt.timeIntervalSince(now) > 60 {
                    state.share = shareItem(link, home: state.homeName)
                    return .none
                }
                guard !state.isMakingLink else { return .none }
                state.isMakingLink = true
                return .run { [homeID = state.homeID] send in
                    await send(.linkCreated(try await invite.create(homeID, .link, Self.linkUses)))
                } catch: { error, send in
                    await send(.linkFailed(AppError(error)))
                }

            case let .linkCreated(link):
                state.isMakingLink = false
                state.linkInvite = link
                state.share = shareItem(link, home: state.homeName)
                return .none

            case let .linkFailed(error):
                state.isMakingLink = false
                guard !error.isSilent else { return .none }
                state.errorMessage = error.errorDescription
                return .none

            case .binding:
                return .none
            }
        }
    }

    private func shareItem(_ link: HomeInvite, home: String) -> ShareItem {
        ShareItem(text: String(localized: L10n.inviteShareMessage(home, link.url.absoluteString)))
    }

    /// A new code, which revokes the person's last one on the server. One at
    /// a time: a create asked for while another is out waits behind it.
    private func create(_ state: inout State) -> Effect<Action> {
        state.isCreating = true
        state.errorMessage = nil
        if state.createInFlight {
            state.createQueued = true
            return .none
        }
        state.createInFlight = true
        state.createQueued = false
        return .merge(
            .cancel(id: CancelID.status),
            .cancel(id: CancelID.timer),
            .run { [homeID = state.homeID, uses = state.limit.maxUses, invite] send in
                // Unstructured, so closing the sheet cannot cancel the request
                // halfway: the server makes the code either way, and a code
                // nobody will ever see is revoked here.
                let work = Task { try await invite.create(homeID, .qr, uses) }
                let code = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: {
                    Task {
                        if let orphan = try? await work.value {
                            try? await invite.revoke(homeID, orphan.token)
                        }
                    }
                }
                await send(.created(code))
            } catch: { error, send in
                await send(.createFailed(AppError(error)))
            }
        )
    }

    /// The code's live standing, and the moment to replace it.
    private func watch(_ code: HomeInvite, in homeID: HomeID) -> Effect<Action> {
        let wait = max(.zero, .seconds(code.expiresAt.timeIntervalSince(now)) - Self.renewAhead)
        return .merge(
            .run { [homeID, token = code.token] send in
                for try await status in invite.status(homeID, token) {
                    await send(.statusUpdated(token: token, status))
                }
            } catch: { _, _ in }
            .cancellable(id: CancelID.status, cancelInFlight: true),
            .run { [token = code.token] send in
                try await clock.sleep(for: wait)
                await send(.refreshDue(token: token))
            }
            .cancellable(id: CancelID.timer, cancelInFlight: true)
        )
    }
}
