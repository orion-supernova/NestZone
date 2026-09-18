import ComposableArchitecture
import Foundation

/// The changelog, from the author's side.
///
/// Reachable only from the Updates tab of the panel, only when the server says
/// this account may write it — and the server says so again on every mutation
/// underneath, because a hidden button is a UI decision and a permission is not.
///
/// Drafts are the reason this screen exists rather than a form on its own. A
/// release note is written before the release goes out and published when it
/// does; a panel that could only create live entries would mean writing them in
/// a text file somewhere and pasting them in at the worst possible moment.
@Reducer
public struct InboxAdminFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        /// Everything, drafts included, newest written first.
        public var updates: IdentifiedArrayOf<AppUpdate> = []
        public var isLoading = true
        /// Entries whose publish toggle is mid-flight, so the row can say so
        /// rather than leaving a tap looking like it did nothing.
        public var working: Set<AppUpdateID> = []

        /// Whose account this is.
        ///
        /// Shown at the bottom of the screen, and the reason it is carried at
        /// all: `ADMIN_USER_IDS` is the setting that makes administration work
        /// when the email allowlist cannot — Apple sends an address only on a
        /// first authorization and sends an alias when "Hide My Email" was used
        /// — and a setting nobody can find the value for is a setting nobody
        /// uses. See `backend/convex/lib/admin.ts`.
        public var currentUserID: UserID?

        @Presents public var composer: InboxComposerFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(currentUserID: UserID? = nil) {
            self.currentUserID = currentUserID
        }

        /// Drafts first: this is a desk, and the unfinished thing is the one
        /// that needs attention. Within each group, newest written first.
        public var drafts: [AppUpdate] { updates.filter(\.isDraft) }
        public var published: [AppUpdate] { updates.filter { !$0.isDraft } }
    }

    public enum Action {
        case task
        case updatesLoaded([AppUpdate])
        case loadFailed(AppError)

        case newTapped
        case editTapped(AppUpdate)
        case publishToggled(AppUpdate)
        case publishFinished(AppUpdateID)
        /// Carries what the entry looked like, so a refused write can put the
        /// row back: nothing changed on the server, so no push is coming.
        case publishFailed(AppUpdate, AppError)
        case deleteTapped(AppUpdate)

        case composer(PresentationAction<InboxComposerFeature.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmDelete(AppUpdateID)
        }
    }

    private enum CancelID { case updates }

    @Dependency(\.inbox) var inbox

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    for try await updates in inbox.allUpdates() {
                        await send(.updatesLoaded(updates))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.updates, cancelInFlight: true)

            case let .updatesLoaded(updates):
                state.isLoading = false
                var incoming = IdentifiedArray(uniqueElements: updates)
                // A row whose toggle is still in flight keeps the optimistic
                // value: the server has not agreed yet, and letting the live
                // push overwrite it would flip the switch back under the finger
                // that moved it.
                for id in state.working {
                    if let optimistic = state.updates[id: id] {
                        incoming[id: id] = optimistic
                    }
                }
                state.updates = incoming
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .newTapped:
                state.composer = InboxComposerFeature.State(draft: UpdateDraft())
                return .none

            case let .editTapped(update):
                state.composer = InboxComposerFeature.State(draft: UpdateDraft(editing: update))
                return .none

            case let .publishToggled(update):
                let shouldPublish = update.isDraft
                var optimistic = update
                // The date the server would stamp, so the row reads correctly
                // the instant it moves rather than a beat later.
                optimistic.publishedAt = shouldPublish
                    ? (update.publishedAt ?? Timestamp(.now))
                    : nil
                state.updates[id: update.id] = optimistic
                state.working.insert(update.id)

                return .run { send in
                    try await inbox.setUpdatePublished(update.id, shouldPublish)
                    await send(.publishFinished(update.id))
                } catch: { error, send in
                    await send(.publishFailed(update, AppError(error)))
                }

            case let .publishFinished(id):
                state.working.remove(id)
                return .none

            case let .publishFailed(previous, error):
                state.working.remove(previous.id)
                state.updates[id: previous.id] = previous
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .deleteTapped(update):
                // Named, and confirmed. A published note has been read by
                // people, and deleting it is the one thing here that cannot be
                // undone by pressing the same button again.
                state.alert = AlertState {
                    TextState(L10n.inboxAdminDeleteTitle)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete(update.id)) {
                        TextState(L10n.commonDelete)
                    }
                    ButtonState(role: .cancel) { TextState(L10n.commonCancel) }
                } message: {
                    TextState(L10n.inboxAdminDeleteMessage(update.title))
                }
                return .none

            case let .alert(.presented(.confirmDelete(id))):
                let previous = state.updates[id: id]
                state.updates.remove(id: id)
                return .run { send in
                    try await inbox.removeUpdate(id)
                } catch: { error, send in
                    if let previous {
                        await send(.publishFailed(previous, AppError(error)))
                    }
                }

            // A saved entry arrives back through the live subscription, so
            // there is nothing to do here but close the form.
            case .composer(.presented(.delegate(.saved))):
                state.composer = nil
                return .none

            case .composer, .alert:
                return .none
            }
        }
        .ifLet(\.$composer, action: \.composer) { InboxComposerFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - The form

/// Writing one release note.
///
/// One form for a new entry and an edit, because they are the same fields —
/// `draft.id` is the only difference, and two forms would have to be kept
/// identical by hand.
@Reducer
public struct InboxComposerFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let id = UUID()
        public var draft: UpdateDraft
        public var isSaving = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(draft: UpdateDraft) { self.draft = draft }

        public var isEditing: Bool { draft.id != nil }
        public var canSave: Bool { draft.isValid && !isSaving }
    }

    public enum Action: BindableAction {
        case highlightAdded
        case highlightRemoved(Int)
        case saveTapped(publish: Bool)
        case saved(AppUpdateID)
        case saveFailed(AppError)
        case cancelTapped

        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}
        public enum Delegate: Equatable {
            case saved(AppUpdateID)
        }
    }

    /// Matches the server's ceiling. Past a dozen bullets a release note is a
    /// document, and nobody reads it in a sheet.
    private static let highlightLimit = 12

    @Dependency(\.inbox) var inbox
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .highlightAdded:
                guard state.draft.highlights.count < Self.highlightLimit else { return .none }
                state.draft.highlights.append("")
                return .none

            case let .highlightRemoved(index):
                guard state.draft.highlights.indices.contains(index) else { return .none }
                state.draft.highlights.remove(at: index)
                return .none

            case let .saveTapped(publish):
                guard state.draft.isValid else { return .none }
                state.isSaving = true
                // Built before the effect rather than mutated inside it: a
                // captured `var` cannot cross into a sendable closure.
                let draft = state.draft.publishing(publish)
                return .run { send in
                    let id = try await inbox.saveUpdate(draft)
                    await send(.saved(id))
                } catch: { error, send in
                    await send(.saveFailed(AppError(error)))
                }

            case let .saved(id):
                state.isSaving = false
                return .send(.delegate(.saved(id)))

            case let .saveFailed(error):
                // The form stays exactly as it was. Losing what somebody typed
                // is the one failure they cannot recover from themselves.
                state.isSaving = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .cancelTapped:
                return .run { _ in await dismiss() }

            case .binding, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
