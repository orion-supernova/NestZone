import ComposableArchitecture
import Foundation

/// One report in full, and the five things a moderator can do with it.
///
/// Every decision is a mutation the server checks again (`FORBIDDEN` for
/// anyone who is not a moderator, and for a report about oneself), so this
/// screen only decides what to offer. A decision that lands is answered by
/// popping back to the queue; a refusal that says this person is not a
/// moderator (any more) leaves the whole screen.
@Reducer
public struct ReportDetailFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public var row: ReportRow
        public var detail: ReportDetail?
        public var isLoading = true
        /// A decision is on its way: the buttons wait.
        public var isWorking = false
        @Presents public var confirm: ConfirmationDialogState<Action.Confirm>?
        @Presents public var alert: AlertState<Action.Alert>?

        public var id: ReportID { row.id }

        public init(row: ReportRow) {
            self.row = row
        }

        /// The server's copy once it has answered, the queue's until then.
        public var current: ReportRow { detail?.report ?? row }
        public var isOpen: Bool { current.status == .open }
    }

    public enum Action {
        case task
        case detailUpdated(ReportDetail?)
        case loadFailed(AppError)

        case dismissTapped
        case deleteTapped
        case removeTapped
        case suspendTapped
        case unsuspendTapped
        case decided(Decision)
        case decisionFailed(AppError)

        case confirm(PresentationAction<Confirm>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Confirm: Equatable {
            case delete, remove, suspend, unsuspend
        }

        public enum Alert: Equatable {}

        public enum Decision: Equatable, Sendable {
            case dismissed, deleted, removed, suspended, unsuspended
        }

        @CasePathable
        public enum Delegate: Equatable {
            /// The report was settled: the queue drops it and pops back.
            case settled(ReportID)
            /// The server says this person is not a moderator.
            case forbidden
        }
    }

    private enum CancelID { case detail }

    @Dependency(\.moderation) var moderation

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let id = state.row.id
                return .run { send in
                    for try await detail in moderation.detail(id) {
                        await send(.detailUpdated(detail))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.detail, cancelInFlight: true)

            case let .detailUpdated(detail):
                state.isLoading = false
                state.detail = detail
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                return refused(error, &state)

            case .dismissTapped:
                guard !state.isWorking else { return .none }
                return decide(&state, .dismissed) { try await moderation.dismiss($0) }

            case .deleteTapped:
                state.confirm = ConfirmationDialogState {
                    TextState(String(localized: L10n.moderationDeleteTitle))
                } actions: {
                    ButtonState(role: .destructive, action: .delete) {
                        TextState(String(localized: L10n.moderationDelete))
                    }
                    ButtonState(role: .cancel) { TextState(String(localized: L10n.commonCancel)) }
                } message: {
                    TextState(String(localized: L10n.moderationDeleteMessage))
                }
                return .none

            case .removeTapped:
                let person = state.current.targetUserName ?? String(localized: L10n.avatarSomeone)
                let home = state.current.homeName ?? ""
                state.confirm = ConfirmationDialogState {
                    TextState(String(localized: L10n.moderationRemoveTitle))
                } actions: {
                    ButtonState(role: .destructive, action: .remove) {
                        TextState(String(localized: L10n.moderationRemove))
                    }
                    ButtonState(role: .cancel) { TextState(String(localized: L10n.commonCancel)) }
                } message: {
                    TextState(String(localized: L10n.moderationRemoveMessage(person, home)))
                }
                return .none

            case .suspendTapped:
                state.confirm = ConfirmationDialogState {
                    TextState(String(localized: L10n.moderationSuspendTitle))
                } actions: {
                    ButtonState(role: .destructive, action: .suspend) {
                        TextState(String(localized: L10n.moderationSuspend))
                    }
                    ButtonState(role: .cancel) { TextState(String(localized: L10n.commonCancel)) }
                } message: {
                    TextState(String(localized: L10n.moderationSuspendMessage))
                }
                return .none

            case .unsuspendTapped:
                state.confirm = ConfirmationDialogState {
                    TextState(String(localized: L10n.moderationUnsuspendTitle))
                } actions: {
                    ButtonState(action: .unsuspend) {
                        TextState(String(localized: L10n.moderationUnsuspend))
                    }
                    ButtonState(role: .cancel) { TextState(String(localized: L10n.commonCancel)) }
                } message: {
                    TextState(String(localized: L10n.moderationUnsuspendMessage))
                }
                return .none

            case .confirm(.presented(.delete)):
                return decide(&state, .deleted) { try await moderation.deleteContent($0) }

            case .confirm(.presented(.remove)):
                return decide(&state, .removed) { try await moderation.removeFromHome($0) }

            case .confirm(.presented(.suspend)):
                return decide(&state, .suspended) { try await moderation.suspendChat($0) }

            case .confirm(.presented(.unsuspend)):
                guard let userID = state.current.targetUserID, !state.isWorking else { return .none }
                state.isWorking = true
                return .run { send in
                    try await moderation.unsuspendChat(userID)
                    await send(.decided(.unsuspended))
                } catch: { error, send in
                    await send(.decisionFailed(AppError(error)))
                }

            case let .decided(decision):
                state.isWorking = false
                // Lifting a suspension settles nothing: the report stays open
                // and the live detail redraws the button.
                guard decision != .unsuspended else { return .none }
                return .send(.delegate(.settled(state.row.id)))

            case let .decisionFailed(error):
                state.isWorking = false
                return refused(error, &state)

            case .confirm, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$confirm, action: \.confirm)
        .ifLet(\.$alert, action: \.alert)
    }

    /// Runs one of the report's mutations and says how it went.
    private func decide(
        _ state: inout State,
        _ decision: Action.Decision,
        _ run: @escaping @Sendable (ReportID) async throws -> Void
    ) -> Effect<Action> {
        guard !state.isWorking else { return .none }
        state.isWorking = true
        let id = state.row.id
        return .run { send in
            try await run(id)
            await send(.decided(decision))
        } catch: { error, send in
            await send(.decisionFailed(AppError(error)))
        }
    }

    /// `FORBIDDEN` ends the screen: this person is not a moderator, or the
    /// report is about them and the other moderator decides it. Anything else is
    /// told in words.
    private func refused(_ error: AppError, _ state: inout State) -> Effect<Action> {
        if case .refused(.forbidden) = error { return .send(.delegate(.forbidden)) }
        guard !error.isSilent else { return .none }
        state.alert = .failure(error)
        return .none
    }
}
