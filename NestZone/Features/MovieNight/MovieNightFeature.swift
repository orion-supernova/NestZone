import ComposableArchitecture
import Foundation
import SwiftUI

/// "What should we watch tonight?" — a shared swipe round.
///
/// Everyone in the home gets the same deck of candidates and swipes through it.
/// A film that every member swiped right on becomes a match.
///
/// The old implementation had nine near-identical `startXPoll` methods (genre,
/// actor, director, year, decade, now-playing, popular, top-rated, upcoming)
/// that differed only in which TMDb endpoint they hit, and it declared a
/// `pollingTask` for live updates that was never actually started — so a vote
/// cast on another device never appeared until the screen was reopened. One
/// live `polls:detail` subscription replaces all of it.
@Reducer
public struct MovieNightFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var memberCount: Int
        public var currentUserID: UserID?

        public var poll: Poll?
        public var detail: PollDetail?
        public var isStarting = false
        public var isLoading = true

        /// Candidates the user has not swiped yet, richest first.
        public var deck: [PollItem] = []
        /// Locally-swiped ids, so a card leaves immediately rather than waiting
        /// for the server round trip.
        public var swiped: Set<String> = []

        @Shared(.includeAdultTitles) public var includeAdultTitles: Bool

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, memberCount: Int, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.memberCount = memberCount
            self.currentUserID = currentUserID
        }

        public var matches: [PollItem] {
            detail?.matches(memberCount: memberCount) ?? []
        }

        public var hasActivePoll: Bool { poll?.isOpen == true }

        /// Closing a round is owner-only server-side, so only offer it to the
        /// person who started it.
        public var canEndRound: Bool { poll?.isOwned(by: currentUserID) == true }

        public var remaining: [PollItem] {
            deck.filter { !swiped.contains($0.externalID) }
        }

        public var isDeckFinished: Bool { hasActivePoll && remaining.isEmpty }
    }

    @Reducer
    public enum Destination {
        case pickKind(PollKindFeature)
        case summary(PollSummaryFeature)
    }

    public enum Action {
        case task
        case pollsUpdated([Poll])
        case detailUpdated(PollDetail)
        case loadFailed(AppError)
        case startTapped
        case kindChosen(CatalogQuery, title: String)
        case pollCreated(PollID)
        case startFailed(AppError)
        case swiped(PollItem, isYes: Bool)
        case voteFailed(AppError)
        case summaryTapped
        case endRoundTapped
        case roundEnded
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmEndRound
        }
    }

    private enum CancelID { case polls, detail }

    @Dependency(\.polls) var pollsClient
    @Dependency(\.catalog) var catalog

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [homeID = state.homeID] send in
                    for try await polls in pollsClient.byHome(homeID) {
                        await send(.pollsUpdated(polls))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.polls, cancelInFlight: true)

            case let .pollsUpdated(polls):
                state.isLoading = false
                let open = polls.first(where: \.isOpen)
                let changed = open?.id != state.poll?.id
                state.poll = open

                guard let open else {
                    state.detail = nil
                    state.deck = []
                    state.swiped = []
                    return .cancel(id: CancelID.detail)
                }
                guard changed else { return .none }

                state.swiped = []
                // Subscribing to the detail is what makes the round shared: a
                // teammate's vote lands here without anyone refreshing.
                return .run { send in
                    for try await detail in pollsClient.detail(open.id) {
                        await send(.detailUpdated(detail))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.detail, cancelInFlight: true)

            case let .detailUpdated(detail):
                state.isLoading = false
                state.detail = detail
                state.deck = detail.unvotedItems
                // Anything the server has recorded a vote for no longer needs
                // the local optimistic marker.
                let confirmed = Set(detail.myVotes.map(\.targetExternalID))
                state.swiped.subtract(confirmed)
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .startTapped:
                state.destination = .pickKind(PollKindFeature.State())
                return .none

            case let .kindChosen(query, title):
                state.destination = nil
                state.isStarting = true
                return .run { [homeID = state.homeID, includeAdult = state.includeAdultTitles] send in
                    var request = query
                    request.includeAdult = includeAdult
                    let movies = try await catalog.discover(request)
                    guard !movies.isEmpty else {
                        throw AppError.server(String(
                            localized: "movienight.noCandidates",
                            defaultValue: "Couldn't find any films for that. Try another option."
                        ))
                    }
                    let id = try await pollsClient.create(
                        homeID,
                        title,
                        query.query,
                        movies.prefix(30).map(PollCandidate.init)
                    )
                    await send(.pollCreated(id))
                } catch: { error, send in
                    await send(.startFailed(AppError(error)))
                }

            case .pollCreated:
                state.isStarting = false
                // The new poll arrives on the `polls:listByHome` stream, which
                // then opens the detail subscription.
                return .none

            case let .startFailed(error):
                state.isStarting = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .swiped(item, isYes):
                guard let pollID = state.poll?.id else { return .none }
                state.swiped.insert(item.externalID)
                return .run { send in
                    try await pollsClient.vote(pollID, item.externalID, isYes)
                } catch: { error, send in
                    await send(.voteFailed(AppError(error)))
                }

            case let .voteFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .summaryTapped:
                guard let detail = state.detail else { return .none }
                state.destination = .summary(PollSummaryFeature.State(
                    detail: detail,
                    memberCount: state.memberCount
                ))
                return .none

            case .endRoundTapped:
                state.alert = .confirmEndRound()
                return .none

            case .alert(.presented(.confirmEndRound)):
                guard let pollID = state.poll?.id else { return .none }
                return .run { send in
                    try await pollsClient.close(pollID)
                    await send(.roundEnded)
                } catch: { error, send in
                    await send(.voteFailed(AppError(error)))
                }

            case .roundEnded:
                state.destination = nil
                return .none

            case .destination, .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == MovieNightFeature.Action.Alert {
    static func confirmEndRound() -> Self {
        AlertState {
            TextState(String(localized: L10n.movienightClosePoll))
        } actions: {
            ButtonState(role: .destructive, action: .confirmEndRound) {
                TextState(String(localized: L10n.movienightClosePoll))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        }
    }
}

/// Choosing what the round is about.
@Reducer
public struct PollKindFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var kind: Kind = .popular
        public var genre = MovieGenre.allCases[0]
        public var personName = ""
        public var year = Calendar.current.component(.year, from: Date())
        public var decade = 2020

        public init() {}

        public enum Kind: String, CaseIterable, Hashable, Sendable {
            case popular, topRated, nowPlaying, upcoming
            case genre, actor, director, year, decade

            public var title: LocalizedStringResource {
                switch self {
                case .popular: L10n.pollTypePopular
                case .topRated: L10n.pollTypeTopRated
                case .nowPlaying: L10n.pollTypeNowPlaying
                case .upcoming: L10n.pollTypeUpcoming
                case .genre: L10n.pollTypeGenre
                case .actor: L10n.pollTypeActor
                case .director: L10n.pollTypeDirector
                case .year: L10n.pollTypeYear
                case .decade: L10n.pollTypeDecade
                }
            }

            public var symbol: String {
                switch self {
                case .popular: "flame.fill"
                case .topRated: "star.fill"
                case .nowPlaying: "play.rectangle.fill"
                case .upcoming: "calendar.badge.clock"
                case .genre: "theatermasks.fill"
                case .actor: "person.fill"
                case .director: "megaphone.fill"
                case .year: "calendar"
                case .decade: "clock.arrow.circlepath"
                }
            }

            /// Whether the choice needs another input before it can run.
            public var needsInput: Bool {
                switch self {
                case .genre, .actor, .director, .year, .decade: true
                case .popular, .topRated, .nowPlaying, .upcoming: false
                }
            }
        }

        /// The catalogue request this choice maps to. One place, instead of nine
        /// near-identical methods.
        public var query: CatalogQuery {
            switch kind {
            case .popular: CatalogQuery(kind: .popular)
            case .topRated: CatalogQuery(kind: .topRated)
            case .nowPlaying: CatalogQuery(kind: .nowPlaying)
            case .upcoming: CatalogQuery(kind: .upcoming)
            case .genre: CatalogQuery(kind: .genre, query: genre.rawValue)
            case .actor: CatalogQuery(kind: .actor, query: personName)
            case .director: CatalogQuery(kind: .director, query: personName)
            case .year: CatalogQuery(kind: .year, year: year)
            case .decade: CatalogQuery(kind: .decade, year: decade)
            }
        }

        public var title: String {
            switch kind {
            case .genre: genre.title
            case .actor, .director: personName
            case .year: String(year)
            case .decade: "\(decade)s"
            case .popular, .topRated, .nowPlaying, .upcoming:
                String(localized: kind.title)
            }
        }

        public var canStart: Bool {
            switch kind {
            case .actor, .director:
                !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            default:
                true
            }
        }
    }

    public enum Action: Equatable, BindableAction {
        case startTapped
        case confirmed(CatalogQuery, title: String)
        case binding(BindingAction<State>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .startTapped:
                guard state.canStart else { return .none }
                return .send(.confirmed(state.query, title: state.title))

            case .confirmed, .binding:
                return .none
            }
        }
    }
}

/// How the round went.
@Reducer
public struct PollSummaryFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var detail: PollDetail
        public var memberCount: Int

        public init(detail: PollDetail, memberCount: Int) {
            self.detail = detail
            self.memberCount = memberCount
        }

        public var scoreboard: [(item: PollItem, yes: Int)] { detail.scoreboard }
        public var matches: [PollItem] { detail.matches(memberCount: memberCount) }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.detail == rhs.detail && lhs.memberCount == rhs.memberCount
        }
    }

    public enum Action: Equatable {
        case doneTapped
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .doneTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}

/// The genres the backend recognises, matching `convex/catalog.ts`.
public enum MovieGenre: String, CaseIterable, Hashable, Sendable, Identifiable {
    case action, adventure, animation, comedy, crime, documentary, drama
    case family, fantasy, history, horror, music, mystery, romance
    case sciFi = "sci-fi"
    case thriller, war, western

    public var id: String { rawValue }

    public var title: String { rawValue.capitalized }

    public var symbol: String {
        switch self {
        case .action: "flame"
        case .adventure: "map"
        case .animation: "sparkles"
        case .comedy: "face.smiling"
        case .crime: "handcuffs"
        case .documentary: "book"
        case .drama: "theatermasks"
        case .family: "figure.2.and.child.holdinghands"
        case .fantasy: "wand.and.stars"
        case .history: "building.columns"
        case .horror: "moon.stars"
        case .music: "music.note"
        case .mystery: "magnifyingglass"
        case .romance: "heart"
        case .sciFi: "atom"
        case .thriller: "bolt"
        case .war: "shield"
        case .western: "hat.cap"
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension MovieNightFeature.Destination.State: Equatable {}
