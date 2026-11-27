import ComposableArchitecture
import Foundation

/// One item from a housemate's own calendar, read-only.
///
/// Nothing here can change it, answer it or plan around it: it is not a house
/// event. What there is to do is report it, which is never a Plus feature (it
/// is how somebody gets words they did not want to see out of their house); the
/// item is hidden from the reporter at once, here and by the server's own read.
@Reducer
public struct SharedItemDetailFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var item: SharedBusyItem
        /// Whose it is, for the face; `nil` for somebody who has since left.
        public var member: User?
        public var name: String
        /// The signed-in person's own item: it says so, and there is nothing to
        /// report (nobody reports themselves).
        public var isMine: Bool
        @Presents public var report: ReportFeature.State?
        public var notice: ReportNotice?

        public init(item: SharedBusyItem, member: User?, name: String, isMine: Bool = false) {
            self.item = item
            self.member = member
            self.name = name
            self.isMine = isMine
        }
    }

    public enum Action {
        case reportTapped
        case report(PresentationAction<ReportFeature.Action>)
        case noticeExpired
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Reported: the calendar hides it from the screen behind.
            case reported(String)
            /// The thanks has been said; close the sheet.
            case finished
        }
    }

    private enum CancelID { case notice }

    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .reportTapped:
                state.report = ReportFeature.State(
                    subject: ReportSubject(kind: .calendarItem, targetID: state.item.id),
                    preview: state.item.shownTitle
                )
                return .none

            case let .report(.presented(.delegate(.reported(outcome)))):
                state.report = nil
                state.notice = ReportNotice(outcome)
                return .merge(
                    .send(.delegate(.reported(state.item.id))),
                    .run { send in
                        try await clock.sleep(for: ReportNotice.linger)
                        await send(.noticeExpired)
                    }
                    .cancellable(id: CancelID.notice, cancelInFlight: true)
                )

            case .noticeExpired:
                state.notice = nil
                return .send(.delegate(.finished))

            case .report, .delegate:
                return .none
            }
        }
        .ifLet(\.$report, action: \.report) { ReportFeature() }
    }
}
