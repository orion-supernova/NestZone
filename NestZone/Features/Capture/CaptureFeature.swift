import ComposableArchitecture
import Foundation

/// Add anything: one field, typed the way you would text a flatmate, and the
/// line goes to the right module.
///
/// The chip under the field is a guess, made three ways in a fixed order of
/// trust. The rules in `CaptureParser` run on every keystroke and, when they
/// are sure — "fix", "ödedi" with an amount, a comma list — they decide. When
/// they only lean, the on-device model gets a say, debounced so it is asked
/// about what somebody finished typing rather than every letter of it. When
/// neither has an opinion, the chip stays where this person last used it.
/// And the moment somebody taps a chip themselves, none of the three is
/// consulted again: a guess that keeps overriding the person is not help.
///
/// Three kinds are written straight from the sheet — shopping, chores, notes —
/// because a sentence carries everything they need. The other three open the
/// module's own composer, already filled in: a problem needs a room and a
/// severity, an event a guest list, an expense a split, and writing any of
/// those behind somebody's back would be a guess they then have to find and
/// undo.
@Reducer
public struct CaptureFeature: Sendable {
    @Reducer
    public enum Composer {
        case problem(IssueComposerFeature)
        case event(EventComposerFeature)
        case expense(ExpenseComposerFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User>
        /// The app's language, for the model's "do you speak this" check.
        public var locale: Locale
        /// What an amount typed with no currency is counted in — the currency
        /// the expense composer will open on, so the two cannot disagree.
        public var fallbackCurrency: String

        public var text: String
        /// The selected chip.
        public var kind: CaptureKind
        /// Whether the person picked the chip themselves. Once they have,
        /// neither the rules nor the model move it again.
        public var isKindLocked: Bool
        /// The rules' reading of `text`, refreshed on every keystroke.
        public var draft: CaptureDraft = .empty
        /// The model's last verdict, kept until a newer one arrives so the chip
        /// does not flick back to the rules' guess and forward again while the
        /// model is thinking about the next letter.
        public var modelKind: CaptureKind?
        public var isSaving = false

        /// The chip last used to add something, as the fallback when nothing
        /// in the line says otherwise. Per device, like every habit.
        @Shared(.captureLastKind) public var lastKind: String

        @Presents public var composer: Composer.State?
        @Presents public var alert: AlertState<Action.Alert>?

        /// - Parameters:
        ///   - kind: opens the sheet on a chip and holds it there — "+" on the
        ///     shopping list means shopping, whatever is typed.
        ///   - text: something to start from, read as soon as the sheet opens.
        public init(
            homeID: HomeID,
            currentUserID: UserID?,
            members: IdentifiedArrayOf<User>,
            kind: CaptureKind? = nil,
            text: String = "",
            locale: Locale = L10n.locale
        ) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.members = members
            self.locale = locale
            self.fallbackCurrency = CurrencyDefaults.preferred
            self.text = text
            self.isKindLocked = kind != nil
            // Read through a second handle: `self.lastKind` is an access on
            // `self`, and `self` is not whole yet.
            @Shared(.captureLastKind) var remembered: String
            self.kind = kind ?? CaptureKind(rawValue: remembered) ?? .shopping
        }

        /// Whether the Add button does anything.
        ///
        /// A chore or a note needs words once the date is taken out — "yarın"
        /// on its own is a day, not a job. The three composers take whatever
        /// there is and ask for the rest themselves.
        public var canAdd: Bool {
            guard !isSaving, !draft.isEmpty else { return false }
            switch kind {
            case .shopping: return !draft.items.isEmpty
            case .chore, .note: return !draft.title(for: kind).isEmpty
            case .problem, .event, .expense: return true
            }
        }

        /// Who a chore goes to, when the line names somebody in the house.
        public var assignee: User? { draft.member.flatMap { members[id: $0] } }

        /// Who paid, when the line says so.
        public var payer: User? { draft.payer.flatMap { members[id: $0] } }
    }

    public enum Action: BindableAction {
        /// The sheet appeared: read any starting text and warm the model up.
        case task
        case kindTapped(CaptureKind)
        case addTapped
        case cancelTapped
        /// The model's answer, tagged with the words it was asked about.
        case classified(String, CaptureKind?)
        case saved(CaptureOutcome)
        case saveFailed(AppError)
        case composer(PresentationAction<Composer.Action>)
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        @CasePathable
        public enum Delegate: Equatable {
            /// The sheet is done. `nil` is a cancel; anything else is what was
            /// added, for the "Added 3 to Shopping · Open" that follows.
            case finished(CaptureOutcome?)
        }
    }

    private enum CancelID { case model }

    /// Long enough to land after a word rather than a letter; short enough that
    /// the chip has moved by the time somebody looks down at it.
    static let modelDebounce: Duration = .milliseconds(400)

    @Dependency(\.shopping) var shopping
    @Dependency(\.tasks) var tasks
    @Dependency(\.notes) var notes
    @Dependency(\.captureClassifier) var classifier
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                reparse(&state)
                let locale = state.locale
                return .merge(
                    .run { _ in
                        guard classifier.isAvailable(locale) else { return }
                        await classifier.prewarm(locale)
                    },
                    askModel(state)
                )

            case .binding(\.text):
                reparse(&state)
                return askModel(state)

            case let .kindTapped(kind):
                state.kind = kind
                state.isKindLocked = true
                return .cancel(id: CancelID.model)

            case let .classified(text, kind):
                // An answer about words that are no longer in the field is an
                // answer to a question nobody is asking any more.
                guard text == state.draft.text, !state.isKindLocked else { return .none }
                state.modelKind = kind
                state.kind = Self.suggestedKind(state)
                return .none

            case .addTapped:
                return add(&state)

            case .cancelTapped:
                return .merge(
                    .cancel(id: CancelID.model),
                    .send(.delegate(.finished(nil)))
                )

            case let .saved(outcome):
                state.isSaving = false
                state.$lastKind.withLock { $0 = outcome.kind.rawValue }
                return .merge(
                    .cancel(id: CancelID.model),
                    .send(.delegate(.finished(outcome)))
                )

            case let .saveFailed(error):
                // Nothing on screen was changed ahead of the server, so there is
                // nothing to put back: the sheet is still open, the words are
                // still in the field, and Add is one tap away again.
                state.isSaving = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // The composers save on their own; their saving is the sheet's
            // finishing.
            case .composer(.presented(.problem(.delegate(.saved)))):
                state.composer = nil
                return .send(.saved(CaptureOutcome(kind: .problem, count: 1)))

            case .composer(.presented(.event(.delegate(.saved)))):
                state.composer = nil
                return .send(.saved(CaptureOutcome(kind: .event, count: 1)))

            case .composer(.presented(.expense(.delegate(.saved)))):
                state.composer = nil
                return .send(.saved(CaptureOutcome(kind: .expense, count: 1)))

            case .composer, .alert, .binding, .delegate:
                return .none
            }
        }
        .ifLet(\.$composer, action: \.composer)
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: Reading

    private func reparse(_ state: inout State) {
        state.draft = CaptureParser.parse(
            state.text,
            members: Array(state.members),
            now: now,
            locale: state.locale,
            calendar: calendar,
            fallbackCurrency: state.fallbackCurrency
        )
        if state.draft.isEmpty { state.modelKind = nil }
        if !state.isKindLocked { state.kind = Self.suggestedKind(state) }
    }

    /// Rules when they are sure, then the model, then the rules' lean, then
    /// habit.
    static func suggestedKind(_ state: State) -> CaptureKind {
        let draft = state.draft
        if draft.confidence == .strong, let kind = draft.kind { return kind }
        if let model = state.modelKind { return model }
        if let kind = draft.kind { return kind }
        return CaptureKind(rawValue: state.lastKind) ?? .shopping
    }

    /// Asks the model about the current words, if it is worth asking: there is
    /// a model, the chip is still the app's to move, and the rules are not
    /// already sure.
    private func askModel(_ state: State) -> Effect<Action> {
        guard !state.isKindLocked,
              !state.draft.isEmpty,
              state.draft.confidence != .strong,
              classifier.isAvailable(state.locale)
        else { return .cancel(id: CancelID.model) }

        let text = state.draft.text
        let locale = state.locale
        return .run { send in
            try await clock.sleep(for: Self.modelDebounce)
            let kind = try await classifier.classify(text, locale)
            await send(.classified(text, kind))
        } catch: { _, _ in
            // A model that fails has no opinion, and the rules already gave
            // theirs. Nothing to tell anybody.
        }
        .cancellable(id: CancelID.model, cancelInFlight: true)
    }

    // MARK: Writing

    private func add(_ state: inout State) -> Effect<Action> {
        guard state.canAdd else { return .none }
        let draft = state.draft
        let homeID = state.homeID

        switch state.kind {
        case .shopping:
            state.isSaving = true
            let names = draft.items
            return .run { send in
                let added = try await shopping.createMany(homeID, names)
                await send(.saved(CaptureOutcome(
                    kind: .shopping,
                    count: added.count,
                    alreadyListed: max(0, names.count - added.count)
                )))
            } catch: { error, send in
                await send(.saveFailed(AppError(error)))
            }

        case .chore:
            state.isSaving = true
            let task = NewTask(
                title: draft.title(for: .chore),
                homeID: homeID,
                assignedTo: state.assignee?.id,
                dueDate: dueDate(draft.date)
            )
            return .run { send in
                try await tasks.create(task)
                await send(.saved(CaptureOutcome(kind: .chore, count: 1)))
            } catch: { error, send in
                await send(.saveFailed(AppError(error)))
            }

        case .note:
            state.isSaving = true
            let body = draft.title(for: .note)
            return .run { send in
                // The colour a note composed on the Notes screen starts on.
                try await notes.create(body, StickyColor.yellow.storedValue, homeID)
                await send(.saved(CaptureOutcome(kind: .note, count: 1)))
            } catch: { error, send in
                await send(.saveFailed(AppError(error)))
            }

        case .problem, .event, .expense:
            state.composer = composer(for: state.kind, state)
            return .cancel(id: CancelID.model)
        }
    }

    /// "By tomorrow" means by the end of tomorrow. A day said without a time is
    /// due at its last minute, so the chore is not overdue by lunchtime on the
    /// day it was meant for.
    private func dueDate(_ date: CaptureDate?) -> Date? {
        guard let date else { return nil }
        guard !date.hasTime else { return date.date }
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date.date) ?? date.date
    }

    /// The composer for `kind`, filled in with what the line said.
    private func composer(for kind: CaptureKind, _ state: State) -> Composer.State? {
        let draft = state.draft
        switch kind {
        case .problem:
            var issue = IssueComposerFeature.State(
                homeID: state.homeID,
                members: state.members,
                currentUserID: state.currentUserID,
                area: draft.issueArea
            )
            issue.title = draft.title(for: .problem)
            return .problem(issue)

        case .event:
            let start = eventStart(draft)
            return .event(EventComposerFeature.State(
                homeID: state.homeID,
                members: state.members,
                currentUserID: state.currentUserID,
                day: CalendarDay(start, calendar: calendar),
                seed: EventComposerFeature.State.Seed(
                    kind: draft.eventKind ?? .general,
                    title: draft.title(for: .event),
                    startsAt: start
                )
            ))

        case .expense:
            let currency = draft.amount?.currency ?? state.fallbackCurrency
            let title = draft.title(for: .expense)
            var expense = ExpenseComposerFeature.State(
                homeID: state.homeID,
                members: state.members,
                currentUserID: state.currentUserID,
                currency: currency,
                knownCurrencies: Self.knownCurrencies(leading: currency),
                defaultDate: now,
                suggestedTitle: title.isEmpty ? nil : title
            )
            if let amount = draft.amount {
                expense.amountText = Money.editableText(amount.minorUnits, currency: currency)
            }
            // Only a payer the line actually named. The composer's own default
            // — whoever is typing — is right far more often than any guess.
            if let payer = state.payer {
                expense.paidBy = payer.id
            }
            return .expense(expense)

        case .shopping, .chore, .note:
            return nil
        }
    }

    /// When the event starts.
    ///
    /// A time that was said is used as said. A day without a time opens on the
    /// calendar's own default for that day — except the evening kinds, which
    /// open at seven: a dinner on Friday at nine in the morning is a time the
    /// person would only have to change.
    private func eventStart(_ draft: CaptureDraft) -> Date {
        guard let date = draft.date else {
            return EventComposerFeature.State.defaultStart(on: CalendarDay(now, calendar: calendar), now: now)
        }
        if date.hasTime { return date.date }
        if let kind = draft.eventKind, Self.eveningKinds.contains(kind) {
            return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date.date) ?? date.date
        }
        return EventComposerFeature.State.defaultStart(on: CalendarDay(date.date, calendar: calendar), now: now)
    }

    static let eveningKinds: Set<EventKind> = [
        .dinnerParty, .houseParty, .movieNight, .gameNight, .birthday,
    ]

    /// The picker's shortlist: the expense's own currency first, then what
    /// this person has picked lately.
    static func knownCurrencies(leading currency: String) -> [String] {
        var codes = [currency]
        for code in CurrencyDefaults.recent where !codes.contains(code) {
            codes.append(code)
        }
        return codes
    }
}

extension CaptureFeature.Composer.State: Equatable {}

/// What Add anything did, for the confirmation the caller shows.
public struct CaptureOutcome: Equatable, Sendable {
    public var kind: CaptureKind
    /// How many things were written: items for shopping, one otherwise.
    public var count: Int
    /// Shopping only: items left out because they were already on the list
    /// and not yet bought. Can make `count` zero — "Already on the list" is
    /// then the honest thing to say, not "Added 0".
    public var alreadyListed: Int

    public init(kind: CaptureKind, count: Int, alreadyListed: Int = 0) {
        self.kind = kind
        self.count = count
        self.alreadyListed = alreadyListed
    }
}

extension SharedKey where Self == AppStorageKey<String>.Default {
    /// The chip last used to add something in Add anything, as a
    /// `CaptureKind` raw value. Empty until the first add.
    ///
    /// Declared here rather than in `AppSettings.swift` because nothing else
    /// reads it.
    public static var captureLastKind: Self {
        Self[.appStorage("appCaptureLastKind"), default: ""]
    }
}
