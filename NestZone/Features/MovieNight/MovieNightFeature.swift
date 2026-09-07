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
        /// Every closed round for this home, newest first.
        public var history: [Poll] = []
        public var detail: PollDetail?
        public var isStarting = false
        public var isLoading = true

        /// Candidates the user has not swiped yet, richest first.
        public var deck: [PollItem] = []
        /// Locally-swiped ids, so a card leaves immediately rather than waiting
        /// for the server round trip.
        public var swiped: Set<String> = []
        /// The last card answered, kept so it can be taken back.
        ///
        /// One card deep on purpose. A swipe is the whole interaction and it is
        /// one flick away from the wrong answer, so the last one has to be
        /// recoverable — but a deck you can rewind through is a list, and the
        /// point of the round is to decide.
        public var lastSwipe: Swipe?
        /// A card taken back locally, held in the deck until the server drops
        /// the vote.
        ///
        /// The dual of `swiped`. Without it, a detail push still carrying the
        /// retracted vote recomputes `deck` from `unvotedItems` and takes the
        /// card straight back out — so an undo flickered the card in, out, and
        /// in again as the two round trips landed.
        public var restoring: PollItem?

        public struct Swipe: Equatable, Sendable {
            public var item: PollItem
            public var isYes: Bool

            public init(item: PollItem, isYes: Bool) {
                self.item = item
                self.isYes = isYes
            }
        }

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

        /// True once the caller has answered every candidate in the round.
        ///
        /// The detail has to have arrived first. Between a round appearing on
        /// the list stream and its candidates landing on the detail stream the
        /// deck is empty for a reason that has nothing to do with being
        /// finished, and reading that as "done" put the end-of-round screen —
        /// "No match yet", and a button to close the round — in front of a
        /// round nobody had seen a single card of yet.
        public var isDeckFinished: Bool {
            hasActivePoll && detail != nil && remaining.isEmpty
        }

        /// A round is open and its cards are still on their way.
        public var isAwaitingDeck: Bool { hasActivePoll && detail == nil }

        /// How many of the household have been through the whole deck.
        public var finishedCount: Int { detail?.finishedVoterCount ?? 0 }

        /// Whether the round is waiting on anybody. Until it isn't, the person
        /// who finished first has nothing to do but wait — which is what the
        /// end-of-deck screen has to say, because the only button on it closes
        /// the round for everybody.
        public var everyoneFinished: Bool {
            memberCount > 0 && finishedCount >= memberCount
        }

        /// Every candidate in the round, however anyone voted.
        ///
        /// Not `deck.count`: the deck holds what the caller has *left*, and it
        /// shrinks as the server confirms each vote. Counting the round with it
        /// gave a total that chased the position down the screen — "29 of 29
        /// left" one card after "30 of 30 left".
        public var roundSize: Int { max(detail?.items.count ?? 0, deck.count) }

        /// Which card is on top, counting from one.
        public var position: Int {
            guard roundSize > 0 else { return 0 }
            return min(roundSize - remaining.count + 1, roundSize)
        }

        public var canUndo: Bool { hasActivePoll && lastSwipe != nil }
    }

    @Reducer
    public enum Destination {
        case pickKind(PollKindFeature)
        case summary(PollSummaryFeature)
        case history(PollHistoryFeature)
        /// A film from the round, opened — from a card in the deck or from a
        /// match at the end. Everything the app knows about it, plus the
        /// household's lists to file it into.
        case movieInfo(MovieInfoFeature)
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
        case undoTapped
        case voteFailed(AppError)
        case movieTapped(PollItem)
        case summaryTapped
        case historyTapped
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
                // Only movie rounds. `polls:listByHome` carries dinner votes
                // too — they are the same machinery with a different `kind` —
                // so without this a household deciding what to eat made this
                // screen believe a film round was open, and listed those votes
                // among the previous rounds.
                let rounds = polls.filter { $0.kind == .movie }
                state.history = rounds
                    .filter { !$0.isOpen }
                    .sorted { Timestamp.newestFirst($0.created, $1.created) }
                let open = rounds.first(where: \.isOpen)
                let changed = open?.id != state.poll?.id
                state.poll = open

                guard let open else {
                    state.detail = nil
                    state.deck = []
                    state.swiped = []
                    state.lastSwipe = nil
                    state.restoring = nil
                    return .cancel(id: CancelID.detail)
                }
                guard changed else { return .none }

                state.swiped = []
                state.lastSwipe = nil
                state.restoring = nil
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

                if let restoring = state.restoring {
                    if confirmed.contains(restoring.externalID) {
                        // The retraction has not landed yet. Hold the card where
                        // the undo put it rather than letting this push undo the
                        // undo.
                        if !state.deck.contains(where: { $0.externalID == restoring.externalID }) {
                            state.deck.insert(restoring, at: 0)
                        }
                    } else {
                        state.restoring = nil
                    }
                }
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
                        .movie,
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
                state.lastSwipe = State.Swipe(item: item, isYes: isYes)
                // Answering the card that was just taken back settles it.
                state.restoring = nil
                return .run { send in
                    try await pollsClient.vote(pollID, item.externalID, isYes)
                } catch: { error, send in
                    await send(.voteFailed(AppError(error)))
                }

            case .undoTapped:
                guard let pollID = state.poll?.id, let last = state.lastSwipe else { return .none }
                // Spent: one step back, and the next one has to be earned by
                // another swipe.
                state.lastSwipe = nil
                state.swiped.remove(last.item.externalID)
                state.restoring = last.item
                // A vote the server has already confirmed took the card out of
                // the deck as well, so dropping the optimistic marker is not
                // enough to bring it back. It goes on top, which is where the
                // live subscription will put it too — its `order` is lower than
                // everything still unanswered.
                if !state.deck.contains(where: { $0.externalID == last.item.externalID }) {
                    state.deck.insert(last.item, at: 0)
                }
                return .run { [externalID = last.item.externalID] send in
                    try await pollsClient.unvote(pollID, externalID)
                } catch: { error, send in
                    await send(.voteFailed(AppError(error)))
                }

            case let .voteFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .movieTapped(item):
                state.destination = .movieInfo(MovieInfoFeature.State(
                    homeID: state.homeID, movie: item.asMovie
                ))
                return .none

            case .summaryTapped:
                guard let detail = state.detail else { return .none }
                state.destination = .summary(PollSummaryFeature.State(
                    homeID: state.homeID,
                    detail: detail,
                    memberCount: state.memberCount
                ))
                return .none

            case .historyTapped:
                state.destination = .history(PollHistoryFeature.State(
                    homeID: state.homeID,
                    polls: state.history,
                    memberCount: state.memberCount,
                    currentUserID: state.currentUserID
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
        } message: {
            // The alert had no message at all, so the one irreversible action
            // in the round asked for confirmation without saying what it did.
            TextState(String(localized: L10n.movienightCloseMessage))
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
        public var homeID: HomeID
        public var detail: PollDetail
        public var memberCount: Int
        @Presents public var movieInfo: MovieInfoFeature.State?

        public init(homeID: HomeID, detail: PollDetail, memberCount: Int) {
            self.homeID = homeID
            self.detail = detail
            self.memberCount = memberCount
        }

        public var scoreboard: [(item: PollItem, yes: Int)] { detail.scoreboard }
        public var matches: [PollItem] { detail.matches(memberCount: memberCount) }

        // Hand-written because `scoreboard` is a tuple array and cannot be
        // synthesised; the stored properties are what actually identify it.
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.homeID == rhs.homeID
                && lhs.detail == rhs.detail
                && lhs.memberCount == rhs.memberCount
                && lhs.movieInfo == rhs.movieInfo
        }
    }

    public enum Action: Equatable {
        case doneTapped
        case movieTapped(PollItem)
        case movieInfo(PresentationAction<MovieInfoFeature.Action>)
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .doneTapped:
                return .run { _ in await dismiss() }

            case let .movieTapped(item):
                state.movieInfo = MovieInfoFeature.State(
                    homeID: state.homeID, movie: item.asMovie
                )
                return .none

            case .movieInfo:
                return .none
            }
        }
        .ifLet(\.$movieInfo, action: \.movieInfo) { MovieInfoFeature() }
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


/// Rounds that have finished, and what won them.
///
/// The old app had this as "Previous Polls" and it went missing in the rewrite.
/// Winners are resolved lazily, one live `polls:detail` subscription at a time,
/// rather than the old version's loop that fetched every poll's detail up front
/// before the list could render.
@Reducer
public struct PollHistoryFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var polls: [Poll]
        public var memberCount: Int
        public var currentUserID: UserID?
        /// pollID → how the round actually ended, once resolved. Nil means it
        /// has not been read yet, which is a different thing from a round that
        /// ended in no agreement — the sheet used to show the same spinner for
        /// both.
        public var outcomes: [PollID: PollOutcome] = [:]
        public var expanded: PollID?
        @Presents public var movieInfo: MovieInfoFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            homeID: HomeID,
            polls: [Poll],
            memberCount: Int,
            currentUserID: UserID?
        ) {
            self.homeID = homeID
            self.polls = polls
            self.memberCount = memberCount
            self.currentUserID = currentUserID
        }

        public func canDelete(_ poll: Poll) -> Bool { poll.isOwned(by: currentUserID) }
    }

    public enum Action {
        case pollTapped(PollID)
        case detailLoaded(PollID, PollDetail)
        case deleteTapped(PollID)
        case deleteConfirmed(PollID)
        case movieTapped(PollItem)
        case movieInfo(PresentationAction<MovieInfoFeature.Action>)
        case failed(AppError)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmDelete(PollID)
        }
    }

    private enum CancelID: Hashable { case detail(PollID) }

    @Dependency(\.polls) var polls

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .pollTapped(id):
                // Collapse if it was already open.
                guard state.expanded != id else {
                    state.expanded = nil
                    return .none
                }
                state.expanded = id
                // Only read a closed round's result the first time it is opened.
                guard state.outcomes[id] == nil else { return .none }
                return .run { send in
                    for try await detail in polls.detail(id) {
                        await send(.detailLoaded(id, detail))
                        break   // history is settled; one value is enough
                    }
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }
                .cancellable(id: CancelID.detail(id), cancelInFlight: true)

            case let .detailLoaded(id, detail):
                state.outcomes[id] = detail.outcome(memberCount: state.memberCount)
                return .none

            case let .deleteTapped(id):
                state.alert = .confirmDeletePoll(id)
                return .none

            case let .movieTapped(item):
                state.movieInfo = MovieInfoFeature.State(
                    homeID: state.homeID, movie: item.asMovie
                )
                return .none

            case .movieInfo:
                return .none

            case let .alert(.presented(.confirmDelete(id))), let .deleteConfirmed(id):
                state.polls.removeAll { $0.id == id }
                state.outcomes[id] = nil
                return .run { send in
                    try await polls.remove(id)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .failed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$movieInfo, action: \.movieInfo) { MovieInfoFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == PollHistoryFeature.Action.Alert {
    static func confirmDeletePoll(_ id: PollID) -> Self {
        AlertState {
            TextState(String(localized: L10n.previousPollsDeleteAlert))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete(id)) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.previousPollsDeleteMessage))
        }
    }
}
