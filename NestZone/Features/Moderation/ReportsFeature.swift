import ComposableArchitecture
import Foundation

/// The moderators' queue: open reports, newest first, and the detail of each.
///
/// Reached from the bell's menu, for the accounts the server says are
/// moderators (`moderation:amModerator`, live). The newest page is a live
/// subscription, so a report filed while the screen is open arrives at the
/// top; older pages are one-shot reads, because a report that has been settled
/// cannot come back.
@Reducer
public struct ReportsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        /// The live newest page.
        public var first: [ReportRow] = []
        /// Pages read further back.
        public var older: [ReportRow] = []
        /// Settled here and not yet gone from the push, so they do not blink
        /// back onto the list.
        public var settled: Set<ReportID> = []
        public var isLoading = true
        public var isLoadingMore = false
        public var hasMore = false
        var cursor: String?
        public var path = StackState<Path.State>()
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}

        /// Newest first.
        public var rows: [ReportRow] {
            let known = Set(first.map(\.id))
            return (first + older.filter { !known.contains($0.id) })
                .filter { !settled.contains($0.id) }
        }
    }

    @Reducer
    public enum Path {
        case detail(ReportDetailFeature)
    }

    public enum Action {
        case task
        case pageUpdated(ReportPage)
        case loadFailed(AppError)
        case reachedEnd
        case olderLoaded(ReportPage)
        case olderFailed(AppError)
        case rowTapped(ReportRow)
        case path(StackActionOf<Path>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        @CasePathable
        public enum Delegate: Equatable {
            /// Not a moderator after all: the whole screen goes.
            case forbidden
        }
    }

    private enum CancelID { case queue }

    @Dependency(\.moderation) var moderation

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    for try await page in moderation.queue() {
                        await send(.pageUpdated(page))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.queue, cancelInFlight: true)

            case let .pageUpdated(page):
                state.isLoading = false
                state.first = page.rows
                // The live page owns the cursor until an older one has been
                // read, after which the cursor is that page's.
                if state.older.isEmpty {
                    state.cursor = page.cursor
                    state.hasMore = !page.isDone && page.cursor != nil
                }
                // Gone from the push means gone for good.
                state.settled.formIntersection(page.rows.map(\.id) + state.older.map(\.id))
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                if case .refused(.forbidden) = error { return .send(.delegate(.forbidden)) }
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .reachedEnd:
                guard state.hasMore, !state.isLoadingMore, let cursor = state.cursor else {
                    return .none
                }
                state.isLoadingMore = true
                return .run { send in
                    await send(.olderLoaded(try await moderation.olderQueue(cursor)))
                } catch: { error, send in
                    await send(.olderFailed(AppError(error)))
                }

            case let .olderLoaded(page):
                state.isLoadingMore = false
                let known = Set(state.first.map(\.id) + state.older.map(\.id))
                state.older += page.rows.filter { !known.contains($0.id) }
                state.cursor = page.cursor
                state.hasMore = !page.isDone && page.cursor != nil
                return .none

            case let .olderFailed(error):
                state.isLoadingMore = false
                if case .refused(.forbidden) = error { return .send(.delegate(.forbidden)) }
                // Quiet: the rows on screen are unaffected, and scrolling to
                // the end asks again.
                return .none

            case let .rowTapped(row):
                state.path.append(.detail(ReportDetailFeature.State(row: row)))
                return .none

            case let .path(.element(id: _, action: .detail(.delegate(.settled(reportID))))):
                state.settled.insert(reportID)
                state.path.removeAll()
                return .none

            case .path(.element(id: _, action: .detail(.delegate(.forbidden)))):
                return .send(.delegate(.forbidden))

            case .path, .alert, .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension ReportsFeature.Path.State: Equatable {}
