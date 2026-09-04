import ComposableArchitecture
import Foundation

/// The shared noticeboard.
@Reducer
public struct NotesFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        public var notes: IdentifiedArrayOf<Note> = []
        /// Author names, resolved in one batch rather than one lookup per note.
        public var authors: [UserID: String] = [:]
        public var isLoading = true
        public var searchText = ""

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        /// Newest first, filtered by the search field.
        public var visibleNotes: [Note] {
            let sorted = notes.sorted { Timestamp.newestFirst($0.created, $1.created) }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return sorted }
            return sorted.filter { $0.body.localizedCaseInsensitiveContains(query) }
        }

        /// Only the author may edit or delete.
        public func canEdit(_ note: Note) -> Bool {
            guard let currentUserID, let author = note.createdBy else { return false }
            return author == currentUserID
        }

        public func authorName(for note: Note) -> String {
            guard let author = note.createdBy else {
                return String(localized: L10n.notesAuthorUnknown)
            }
            if author == currentUserID { return String(localized: L10n.notesAuthorYou) }
            return authors[author] ?? String(localized: L10n.notesAuthorMember)
        }
    }

    @Reducer
    public enum Destination {
        case compose(ComposeNoteFeature)
    }

    public enum Action: BindableAction {
        case task
        case notesUpdated([Note])
        case authorsResolved([User])
        case loadFailed(AppError)
        case composeTapped
        case editTapped(NoteID)
        case deleteTapped(NoteID)
        case deleteFailed(AppError)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmDelete(NoteID)
        }
    }

    private enum CancelID { case notes }

    @Dependency(\.notes) var notesClient
    @Dependency(\.users) var usersClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return .run { [homeID = state.homeID] send in
                    for try await notes in notesClient.byHome(homeID) {
                        await send(.notesUpdated(notes))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.notes, cancelInFlight: true)

            case let .notesUpdated(notes):
                state.isLoading = false
                state.notes = IdentifiedArray(uniqueElements: notes)

                // Resolve only the authors we don't already know, and in one
                // call. The old screen re-fetched the whole author set after
                // every create, update and delete.
                let known = Set(state.authors.keys)
                let missing = Set(notes.compactMap(\.createdBy)).subtracting(known)
                guard !missing.isEmpty else { return .none }
                return .run { send in
                    let users = try await usersClient.byIDs(Array(missing))
                    await send(.authorsResolved(users))
                } catch: { _, _ in
                    // Names are a nicety; the notes still read fine without them.
                }

            case let .authorsResolved(users):
                for user in users { state.authors[user.id] = user.displayName }
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .composeTapped:
                state.destination = .compose(
                    ComposeNoteFeature.State(homeID: state.homeID)
                )
                return .none

            case let .editTapped(id):
                guard let note = state.notes[id: id], state.canEdit(note) else { return .none }
                state.destination = .compose(
                    ComposeNoteFeature.State(homeID: state.homeID, editing: note)
                )
                return .none

            case let .deleteTapped(id):
                state.alert = .confirmDeleteNote(id)
                return .none

            case let .alert(.presented(.confirmDelete(id))):
                return .run { send in
                    try await notesClient.remove(id)
                } catch: { error, send in
                    await send(.deleteFailed(AppError(error)))
                }

            case let .deleteFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .destination(.presented(.compose(.finished))):
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

extension AlertState where Action == NotesFeature.Action.Alert {
    static func confirmDeleteNote(_ id: NoteID) -> Self {
        AlertState {
            TextState(String(localized: L10n.notesDeleteConfirmTitle))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete(id)) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.notesDeleteConfirmMessage))
        }
    }
}

/// Writing or editing a note.
@Reducer
public struct ComposeNoteFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var editing: Note?
        public var body_ = ""
        public var color: String
        public var isSubmitting = false
        public var inlineError: String?

        public init(homeID: HomeID, editing: Note? = nil) {
            self.homeID = homeID
            self.editing = editing
            self.body_ = editing?.body ?? ""
            self.color = editing?.color ?? StickyColor.yellow.storedValue
        }

        public var isEditing: Bool { editing != nil }

        public var canSubmit: Bool {
            !isSubmitting && !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: Equatable, BindableAction {
        case submitTapped
        case colorSelected(String)
        case failed(AppError)
        case finished
        case binding(BindingAction<State>)
    }

    @Dependency(\.notes) var notes

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                return .run { [
                    editing = state.editing,
                    text = state.body_,
                    color = state.color,
                    homeID = state.homeID
                ] send in
                    if let editing {
                        try await notes.update(editing.id, text, color)
                    } else {
                        try await notes.create(text, color, homeID)
                    }
                    await send(.finished)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .colorSelected(hex):
                state.color = hex
                return .none

            case let .failed(error):
                state.isSubmitting = false
                state.inlineError = error.errorDescription
                return .none

            case .finished, .binding:
                return .none
            }
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension NotesFeature.Destination.State: Equatable {}
