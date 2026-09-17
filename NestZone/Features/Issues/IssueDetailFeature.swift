import ComposableArchitecture
import Foundation

/// One house problem, and everything the household has done about it.
///
/// The screen opens on the row it was pushed from — the title, the room, how bad
/// it is — and fills in around it as `issues:detail` answers. That is not a
/// nicety: the list already holds every one of those facts, and a spinner over
/// a screen whose headline is already known reads as slower than it is.
///
/// Everything below the headline is one subscription. The timeline, the parts,
/// the receipts, the chore and the visit could each have been their own query;
/// rolled up they are computed from one server-side read, so the spend total
/// cannot disagree with the receipts under it and "2 of 5 bought" cannot
/// disagree with the list beside it. The same bargain `events:detail` makes.
@Reducer
public struct IssueDetailFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Identifiable {
        /// What the list knew when this was pushed. Replaced by the server's
        /// copy the moment one arrives, and used until then so the screen has a
        /// headline rather than a skeleton.
        public var issue: HouseIssue
        public var homeID: HomeID
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User> = []

        public var detail: IssueDetail?
        public var isLoading = true

        /// What is being typed into the timeline.
        public var draft = ""
        public var isPosting = false
        /// Photos on their way up. Held as a count rather than as the images:
        /// the bytes are already in flight and nothing on screen draws them
        /// until the server answers with a URL.
        public var uploading = 0
        /// Bumped when the problem is marked fixed. The one burst of confetti
        /// this screen allows itself.
        public var fixedCelebration = 0

        /// The little sheet that asks for a sentence before a status moves.
        public var statusNote: StatusNote?
        /// Parts being typed, on their way to the shopping list.
        public var partsDraft: PartsDraft?
        /// A visit being booked.
        public var visitDraft: VisitDraft?

        @Presents public var expense: ExpenseComposerFeature.State?
        @Presents public var edit: IssueComposerFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?
        @Presents public var confirm: ConfirmationDialogState<Action.Confirm>?

        public var id: IssueID { issue.id }

        public init(
            issue: HouseIssue,
            homeID: HomeID,
            currentUserID: UserID? = nil,
            members: IdentifiedArrayOf<User> = []
        ) {
            self.issue = issue
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.members = members
        }

        // MARK: Derived

        /// The server's copy once it exists, and the list's until then.
        public var current: HouseIssue { detail?.issue ?? issue }

        public var timeline: [IssueEntry] { detail?.timeline ?? [] }
        public var parts: [IssuePart] { detail?.parts ?? [] }
        public var expenses: [IssueExpense] { detail?.expenses ?? [] }
        public var previously: [IssuePrecedent] { detail?.previously ?? [] }

        /// What the money card is denominated in. The problem's own currency
        /// wins; with none set it is whatever its receipts were written in, and
        /// with neither it is this device's default — which is only ever used
        /// for an empty card that has no figure on it yet.
        public var currency: String {
            detail?.currency ?? current.currency ?? Money.deviceDefault
        }

        public var spent: Int { detail?.spent ?? 0 }

        public func name(for id: UserID?) -> String {
            guard let id else { return String(localized: L10n.issuesNobody) }
            if id == currentUserID { return String(localized: L10n.issuesYou) }
            return members[id: id]?.displayName ?? String(localized: L10n.issuesSomeone)
        }

        public func member(_ id: UserID?) -> User? {
            id.flatMap { members[id: $0] }
        }

        /// Whether this person has said it is happening to them too.
        public var isAffected: Bool { current.isAffected(currentUserID) }

        /// Somebody finished the chore but nobody has said whether it worked.
        /// The screen's one genuinely useful prompt — see `IssueDetail`.
        public var awaitsVerdict: Bool { detail?.awaitsVerdict ?? false }

        /// The statuses the overflow menu offers: everything except where the
        /// problem already is, and except the rung the big button already
        /// covers, so no control on screen duplicates another.
        public var otherStatuses: [IssueStatus] {
            IssueStatus.allCases.filter { $0 != current.status && $0 != current.status.next }
        }

        /// Whether there is anything at all in the plan yet. Until there is, the
        /// card shows three invitations rather than three empty rows.
        public var hasPlan: Bool {
            detail?.task != nil || detail?.event != nil
                || (detail?.partsTotal ?? 0) > 0 || !(detail?.expenses.isEmpty ?? true)
        }

        public var canPost: Bool {
            !isPosting && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// Every member, the viewer first — the person reading a repair takes it
        /// on more often than not.
        public var assigneeOptions: [User] {
            members.sorted { lhs, rhs in
                if lhs.id == currentUserID { return true }
                if rhs.id == currentUserID { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    == .orderedAscending
            }
        }

        /// A `tel:` link for the vendor, when the number is dialable.
        public var callURL: URL? {
            guard let phone = current.vendorPhone?.filter({ "+0123456789".contains($0) }),
                  phone.count >= 5 else { return nil }
            return URL(string: "tel://\(phone)")
        }

        public var vendorWebURL: URL? {
            guard let raw = current.vendorURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            let prefixed = raw.contains("://") ? raw : "https://\(raw)"
            return URL(string: prefixed)
        }
    }

    /// A sentence the status move is asking for.
    ///
    /// Two of the seven moves genuinely want one — "what fixed it" is the most
    /// useful line on the screen the next time the same thing goes, and "what
    /// is it waiting for" is the whole content of being blocked. The other five
    /// go straight through: a form in front of every tap is how a status stops
    /// being kept up to date.
    public struct StatusNote: Equatable, Identifiable, Sendable {
        public var status: IssueStatus
        public var text: String

        public var id: String { status.rawValue }

        public init(status: IssueStatus, text: String = "") {
            self.status = status
            self.text = text
        }

        /// Whether this move is worth interrupting for.
        public static func isWanted(for status: IssueStatus) -> Bool {
            status == .fixed || status == .blocked || status == .wontFix
        }

        public var prompt: LocalizedStringResource {
            switch status {
            case .fixed: L10n.issuesResolutionPrompt
            case .blocked: L10n.issuesBlockedPrompt
            default: L10n.issuesStatusNotePrompt
            }
        }

        public var placeholder: LocalizedStringResource {
            switch status {
            case .fixed: L10n.issuesResolutionPlaceholder
            case .blocked: L10n.issuesBlockedPlaceholder
            default: L10n.issuesStatusNotePlaceholder
            }
        }
    }

    /// Parts on their way to the shopping list, one per line.
    ///
    /// A plain text box rather than a row editor: what somebody has in their
    /// head at this moment is "washer, PTFE tape, new trap", and making them
    /// press "+" three times to say it is the reason the parts never get added.
    public struct PartsDraft: Equatable, Identifiable, Sendable {
        public var text: String = ""
        public var id: String { "parts" }

        public init(text: String = "") { self.text = text }

        /// One part per line, blank lines dropped. The server skips anything
        /// already on the household's list, so a duplicate costs nothing.
        public var names: [String] {
            text
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        public var isReady: Bool { !names.isEmpty }
    }

    /// A repair visit being booked into the household's calendar.
    public struct VisitDraft: Equatable, Identifiable, Sendable {
        public var startsAt: Date
        public var durationMinutes: Int
        public var title: String
        public var location: String
        /// Whole minutes before to nudge the household.
        public var reminder: Int

        public var id: String { "visit" }

        /// The offsets a repair visit is actually worth: the evening before, the
        /// morning of, an hour out, or nothing.
        public static let reminderChoices = [0, 60, 240, 1440]
        /// How long a tradesperson is usually in the house for.
        public static let durationChoices = [30, 60, 120, 240]

        public init(
            startsAt: Date,
            durationMinutes: Int = 60,
            title: String = "",
            location: String = "",
            reminder: Int = 60
        ) {
            self.startsAt = startsAt
            self.durationMinutes = durationMinutes
            self.title = title
            self.location = location
            self.reminder = reminder
        }

        public var endsAt: Date {
            startsAt.addingTimeInterval(Double(durationMinutes) * 60)
        }

        public var booking: VisitBooking {
            VisitBooking(
                startsAt: startsAt,
                endsAt: endsAt,
                title: title,
                location: location,
                // Zero means "no reminder", not "at the moment it starts": a
                // notification that fires as the doorbell goes is not a
                // reminder, and the picker says "None" for it.
                reminders: reminder > 0 ? [reminder] : []
            )
        }
    }

    public enum Action: BindableAction {
        case task
        case detailUpdated(IssueDetail?)
        case loadFailed(AppError)

        case statusTapped(IssueStatus)
        case statusNoteConfirmed
        case statusNoteDismissed
        case statusCommitted(IssueStatus)

        case meTooTapped
        case meTooFailed([UserID], AppError)
        case assignTapped(UserID?)
        case assignFailed(UserID?, AppError)

        case postTapped
        case posted
        case deleteEntryTapped(IssueEntryID)

        case makeChoreTapped
        case addPartsTapped
        case partsConfirmed
        case partsAdded(StockUpResult)
        case scheduleVisitTapped
        case visitConfirmed
        case visitBooked(EventID)
        case logCostTapped

        /// The picker handed over some images. Encoded and uploaded one at a
        /// time, then attached in a single write.
        case photosPicked([Data])
        case photosAttached
        case removePhotoTapped(String)

        case openEventTapped
        case openShoppingListTapped
        case editTapped
        case deleteTapped

        case writeFailed(AppError)

        case binding(BindingAction<State>)
        case expense(PresentationAction<ExpenseComposerFeature.Action>)
        case edit(PresentationAction<IssueComposerFeature.Action>)
        case alert(PresentationAction<Alert>)
        case confirm(PresentationAction<Confirm>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        public enum Confirm: Equatable {
            case delete
        }

        public enum Delegate: Equatable {
            /// Hands the delete back to the list, which already has an undoable
            /// path for it.
            case deleteRequested(IssueID)
            case openEvent(EventID, CalendarDay)
            case openShoppingList
        }
    }

    private enum CancelID { case detail }

    @Dependency(\.issues) var issuesClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                let id = state.issue.id
                return .run { send in
                    for try await detail in issuesClient.detail(id) {
                        await send(.detailUpdated(detail))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.detail, cancelInFlight: true)

            case let .detailUpdated(detail):
                state.isLoading = false
                // Deleted from another phone while this screen was open. There
                // is nothing left to show, and a screen full of stale detail
                // with no row behind it is worse than leaving.
                guard let detail else { return .run { _ in await dismiss() } }
                guard detail != state.detail else { return .none }
                state.detail = detail
                // The headline follows the server's copy, so an edit made on
                // another phone lands here too.
                state.issue = detail.issue
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // MARK: The status

            case let .statusTapped(status):
                guard status != state.current.status else { return .none }
                // Two of the seven moves are worth a sentence; the rest go
                // straight through. See `StatusNote`.
                guard !StatusNote.isWanted(for: status) else {
                    state.statusNote = StatusNote(status: status)
                    return .none
                }
                return commitStatus(&state, status, note: nil)

            case .statusNoteConfirmed:
                guard let note = state.statusNote else { return .none }
                state.statusNote = nil
                return commitStatus(&state, note.status, note: note.text)

            case .statusNoteDismissed:
                state.statusNote = nil
                return .none

            case let .statusCommitted(previous):
                // The optimistic move did not take. Put the old status back —
                // nothing happened on the server, so no push is coming to
                // correct it.
                state.issue.status = previous
                return .none

            // MARK: Agreeing and assigning

            case .meTooTapped:
                guard let me = state.currentUserID else { return .none }
                let previous = state.current.meToo
                var updated = previous
                if updated.contains(me) {
                    updated.removeAll { $0 == me }
                } else {
                    updated.append(me)
                }
                state.issue.meToo = updated
                state.detail?.issue.meToo = updated
                let id = state.issue.id
                return .run { _ in
                    _ = try await issuesClient.toggleMeToo(id)
                } catch: { error, send in
                    await send(.meTooFailed(previous, AppError(error)))
                }

            case let .meTooFailed(previous, error):
                state.issue.meToo = previous
                state.detail?.issue.meToo = previous
                return .send(.writeFailed(error))

            case let .assignTapped(userID):
                let previous = state.current.assignedTo
                guard userID != previous else { return .none }
                state.issue.assignedTo = userID
                state.detail?.issue.assignedTo = userID
                let id = state.issue.id
                return .run { _ in
                    try await issuesClient.assign(id, userID)
                } catch: { error, send in
                    await send(.assignFailed(previous, AppError(error)))
                }

            case let .assignFailed(previous, error):
                state.issue.assignedTo = previous
                state.detail?.issue.assignedTo = previous
                return .send(.writeFailed(error))

            // MARK: The timeline

            case .postTapped:
                guard state.canPost else { return .none }
                let id = state.issue.id
                let body = state.draft
                state.isPosting = true
                // Cleared now rather than on success. The field emptying is the
                // acknowledgement, and a comment that reappears in the box for
                // half a second reads as having failed. The failure handler puts
                // the text back, which is the rollback this write owes.
                state.draft = ""
                return .run { send in
                    try await issuesClient.comment(id, body)
                    await send(.posted)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                    // The words are the person's, and nothing else remembers
                    // them.
                    await send(.binding(.set(\.draft, body)))
                    await send(.posted)
                }

            case .posted:
                state.isPosting = false
                return .none

            case let .deleteEntryTapped(entryID):
                // No undo window here, unlike a deleted problem: this is the
                // person's own sentence, taken back a second after they wrote
                // it, and the live subscription puts it back if the write fails.
                return .run { _ in
                    try await issuesClient.removeComment(entryID)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            // MARK: The plan

            case .makeChoreTapped:
                let id = state.issue.id
                let assignee = state.current.assignedTo
                let due = state.current.dueBy?.date
                return .run { _ in
                    try await issuesClient.makeChore(id, assignee, due)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case .addPartsTapped:
                state.partsDraft = PartsDraft()
                return .none

            case .partsConfirmed:
                guard let draft = state.partsDraft, draft.isReady else { return .none }
                state.partsDraft = nil
                let id = state.issue.id
                let names = draft.names
                return .run { send in
                    let result = try await issuesClient.addParts(id, names)
                    await send(.partsAdded(result))
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case let .partsAdded(result):
                // Everything asked for was already on the list. Worth saying:
                // the alternative is a button that looks like it did nothing.
                guard result.added == 0, result.skipped > 0 else { return .none }
                state.alert = AlertState {
                    TextState(String(localized: L10n.issuesPartsAlreadyTitle))
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState(String(localized: L10n.commonOkButton))
                    }
                } message: {
                    TextState(String(localized: L10n.issuesPartsAlreadyMessage(result.skipped)))
                }
                return .none

            case .scheduleVisitTapped:
                // Reopened on the visit already booked, when there is one that
                // has not happened yet: the second tap on this control is
                // nearly always "they're coming Thursday now", and a sheet that
                // starts blank makes somebody retype what it already knows.
                // The server moves that visit rather than booking a second one.
                if let existing = state.detail?.event, !existing.hasHappened {
                    let minutes = Int(
                        existing.endsAt.date.timeIntervalSince(existing.startsAt.date) / 60
                    )
                    state.visitDraft = VisitDraft(
                        startsAt: existing.startsAt.date,
                        durationMinutes: VisitDraft.durationChoices
                            .min { abs($0 - minutes) < abs($1 - minutes) } ?? 60,
                        title: existing.title,
                        location: existing.location ?? ""
                    )
                    return .none
                }
                // Otherwise tomorrow morning: a tradesperson is rarely coming in
                // the next hour, and a picker that opens on "now" is a picker
                // everybody has to scroll.
                let calendar = Calendar.current
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                let start = calendar.date(
                    bySettingHour: 10, minute: 0, second: 0, of: tomorrow
                ) ?? tomorrow
                state.visitDraft = VisitDraft(
                    startsAt: start,
                    title: state.current.vendorName ?? "",
                    location: ""
                )
                return .none

            case .visitConfirmed:
                guard let draft = state.visitDraft else { return .none }
                state.visitDraft = nil
                let id = state.issue.id
                let booking = draft.booking
                return .run { send in
                    let eventID = try await issuesClient.scheduleVisit(id, booking)
                    await send(.visitBooked(eventID))
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case .visitBooked:
                // Nothing to do: the live subscription brings the visit in, and
                // yanking the household into the calendar the instant it is
                // booked takes them away from the screen they were working on.
                return .none

            case .logCostTapped:
                let issue = state.current
                state.expense = ExpenseComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    currency: state.currency,
                    issueID: issue.id,
                    // Pre-filled rather than placeheld, so it is saved if nobody
                    // edits it — and still entirely replaceable.
                    suggestedTitle: issue.expenseTitle,
                    // What kind of spend a repair is, said once here rather than
                    // corrected on every receipt.
                    defaultCategory: issue.category.spendCategory
                )
                return .none

            // MARK: Photos

            case let .photosPicked(images):
                guard !images.isEmpty else { return .none }
                let id = state.issue.id
                state.uploading += images.count
                return .run { send in
                    // Encoded off the main actor, one at a time: re-drawing a
                    // twelve-megapixel photo is tens of milliseconds and holding
                    // several decoded bitmaps at once is how a phone with a full
                    // camera roll runs out of memory mid-report.
                    var stored: [IssuePhotoIDs] = []
                    for image in images {
                        guard let encoded = IssuePhoto.encode(image) else { continue }
                        stored.append(try await issuesClient.uploadPhoto(encoded))
                    }
                    try await issuesClient.attachPhotos(id, stored)
                    await send(.photosAttached)
                } catch: { error, send in
                    await send(.photosAttached)
                    await send(.writeFailed(AppError(error)))
                }

            case .photosAttached:
                state.uploading = 0
                return .none

            case let .removePhotoTapped(storageID):
                let id = state.issue.id
                return .run { _ in
                    try await issuesClient.removePhoto(id, storageID)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            // MARK: Leaving

            case .openEventTapped:
                guard let event = state.detail?.event else { return .none }
                return .send(.delegate(.openEvent(event.id, event.day)))

            case .openShoppingListTapped:
                return .send(.delegate(.openShoppingList))

            case .editTapped:
                state.edit = IssueComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    editing: state.current
                )
                return .none

            case .deleteTapped:
                state.confirm = ConfirmationDialogState {
                    TextState(String(localized: L10n.issuesDeleteTitle))
                } actions: {
                    ButtonState(role: .destructive, action: .delete) {
                        TextState(String(localized: L10n.commonDelete))
                    }
                    ButtonState(role: .cancel) {
                        TextState(String(localized: L10n.commonCancel))
                    }
                } message: {
                    TextState(String(localized: L10n.issuesDeleteMessage))
                }
                return .none

            case .confirm(.presented(.delete)):
                let id = state.issue.id
                // Handed back to the list rather than written here: the list
                // owns the undo window, and a delete that is undoable from one
                // screen and final from another is an undo nobody trusts.
                return .run { send in
                    await send(.delegate(.deleteRequested(id)))
                }

            case .edit(.presented(.delegate(.saved))):
                state.edit = nil
                return .none

            case .expense(.presented(.delegate(.saved))):
                state.expense = nil
                return .none

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .expense, .edit, .alert, .confirm, .delegate:
                return .none
            }
        }
        .ifLet(\.$expense, action: \.expense) { ExpenseComposerFeature() }
        .ifLet(\.$edit, action: \.edit) { IssueComposerFeature() }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$confirm, action: \.confirm)
    }

    /// Moves the problem, optimistically, and owns putting it back.
    private func commitStatus(
        _ state: inout State,
        _ status: IssueStatus,
        note: String?
    ) -> Effect<Action> {
        let previous = state.current.status
        // Fixed, having not been a moment ago. Fired here rather than when the
        // server confirms, because the optimistic write below has already moved
        // the status — by the time the push lands there is no transition left
        // for it to notice. It is also simply the right moment: the burst
        // belongs to the tap.
        if status == .fixed, previous.isOpen {
            state.fixedCelebration += 1
        }
        state.issue.status = status
        state.detail?.issue.status = status
        let id = state.issue.id
        return .run { _ in
            try await issuesClient.setStatus(id, status, note)
        } catch: { error, send in
            await send(.statusCommitted(previous))
            await send(.writeFailed(AppError(error)))
        }
    }
}
