import ComposableArchitecture
import Foundation

/// The small sheet that files a report: what is wrong, and optionally a word
/// about it.
///
/// One feature for the three things that can be reported (a message, a problem
/// photo, a face), so the reasons, the wording and the answers are the same
/// everywhere. It files the report and says what the server answered; hiding
/// the thing on screen and saying thanks belong to whoever presented it, which
/// is the one that knows what is on screen.
@Reducer
public struct ReportFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var subject: ReportSubject
        /// What is being reported, for the sheet to show a line of — the
        /// message's words, or nothing for a picture.
        public var preview: String?
        public var reason: ReportReason?
        public var note = ""
        public var isSubmitting = false
        /// What went wrong, in words, kept in the sheet so a retry is a tap.
        public var error: String?

        public init(subject: ReportSubject, preview: String? = nil) {
            self.subject = subject
            self.preview = preview
        }

        public var canSubmit: Bool { reason != nil && !isSubmitting }
    }

    public enum Action: BindableAction, Equatable {
        case reasonSelected(ReportReason)
        case submitTapped
        case failed(AppError)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// The server took it (or already had it, or was past its daily
            /// limit — the thing is hidden from this person in all three).
            case reported(ReportOutcome)
        }
    }

    @Dependency(\.moderation) var moderation

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .reasonSelected(reason):
                state.reason = reason
                return .none

            case .submitTapped:
                guard state.canSubmit, let reason = state.reason else { return .none }
                state.isSubmitting = true
                state.error = nil
                return .run { [subject = state.subject, note = state.note] send in
                    let outcome = try await moderation.report(subject, reason, note)
                    await send(.delegate(.reported(outcome)))
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .failed(error):
                state.isSubmitting = false
                // A report that was cancelled (the sheet went away) says nothing.
                state.error = error.errorDescription
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}

/// Said quietly, for a few seconds, after a report: not an alert, because
/// nothing needs answering.
public enum ReportNotice: Equatable, Sendable {
    case thanks
    case limited
    /// A quote or a pin pointed at a message older than what is loaded.
    case notLoaded

    public init(_ outcome: ReportOutcome) {
        self = outcome == .limited ? .limited : .thanks
    }

    public var copy: LocalizedStringResource {
        switch self {
        case .thanks: L10n.reportThanks
        case .limited: L10n.reportLimited
        case .notLoaded: L10n.chatMessageNotLoaded
        }
    }

    public var symbol: String {
        switch self {
        case .thanks, .limited: "checkmark.shield.fill"
        case .notLoaded: "clock.arrow.circlepath"
        }
    }

    /// How long it stays up.
    public static let linger: Duration = .seconds(4)
}
