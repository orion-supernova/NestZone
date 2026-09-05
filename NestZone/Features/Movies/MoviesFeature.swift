import ComposableArchitecture
import Foundation
import SwiftUI

/// The household's movie lists.
@Reducer
public struct MoviesFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var lists: IdentifiedArrayOf<MovieList> = []
        public var isLoading = true
        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID) { self.homeID = homeID }

        /// Wishlist and Watched come first and always exist conceptually; custom
        /// lists follow in creation order.
        public var presets: [MovieList] {
            lists.filter { $0.kind != .custom }
                .sorted { $0.kind == .wishlist && $1.kind != .wishlist }
        }

        public var customLists: [MovieList] {
            lists.filter { $0.kind == .custom }
                .sorted { Timestamp.newestFirst($1.created, $0.created) }
        }
    }

    @Reducer
    public enum Destination {
        case list(MovieListFeature)
        case createList(CreateMovieListFeature)
    }

    public enum Action {
        case task
        case listsUpdated([MovieList])
        case loadFailed(AppError)
        case listTapped(MovieList)
        case createListTapped
        case deleteListTapped(MovieListID)
        case writeFailed(AppError)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmDeleteList(MovieListID)
        }
    }

    private enum CancelID { case lists }

    @Dependency(\.movies) var movies

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [homeID = state.homeID] send in
                    for try await lists in movies.lists(homeID) {
                        await send(.listsUpdated(lists))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.lists, cancelInFlight: true)

            case let .listsUpdated(lists):
                let wasLoading = state.isLoading
                state.isLoading = false
                state.lists = IdentifiedArray(uniqueElements: lists)
                // A home with no built-in lists has nowhere to save a film —
                // not from here, and not from a poll's matches either. Homes
                // made in the window between the client dropping the seeding
                // and the server taking it over are in exactly that state, so
                // the first look at this screen repairs them. Only on the first
                // push: the subscription then reports the new lists, and
                // asking again on every push would be a write per update.
                guard wasLoading, state.presets.isEmpty else { return .none }
                return .run { [homeID = state.homeID] _ in
                    try await movies.ensurePresetLists(homeID)
                } catch: { _, _ in
                    // Nothing to say: the screen works without them, it just
                    // has no quick collections to offer.
                }

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .listTapped(list):
                state.destination = .list(
                    MovieListFeature.State(homeID: state.homeID, list: list)
                )
                return .none

            case .createListTapped:
                state.destination = .createList(
                    CreateMovieListFeature.State(homeID: state.homeID)
                )
                return .none

            case let .deleteListTapped(id):
                state.alert = .confirmDeleteList(id)
                return .none

            case let .alert(.presented(.confirmDeleteList(id))):
                return .run { send in
                    try await movies.removeList(id)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .destination(.presented(.createList(.finished))):
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

extension AlertState where Action == MoviesFeature.Action.Alert {
    static func confirmDeleteList(_ id: MovieListID) -> Self {
        AlertState {
            TextState(String(localized: L10n.commonDelete))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeleteList(id)) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.moviesDeleteListMessage))
        }
    }
}

/// One list, plus the search that fills it.
@Reducer
public struct MovieListFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var list: MovieList
        public var movies: IdentifiedArrayOf<StoredMovie> = []
        public var isLoading = true

        public var searchText = ""
        public var results: [Movie] = []
        public var isSearching = false
        /// TMDb ids already saved anywhere in the home, so search results can be
        /// marked without a query per row.
        public var savedIDs: Set<String> = []
        @Shared(.includeAdultTitles) public var includeAdultTitles: Bool

        /// Search lives behind an explicit "Add movies" button rather than an
        /// always-on search bar, so the list reads as a collection first.
        public var isSearchPresented = false
        @Presents public var detail: MovieInfoFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, list: MovieList) {
            self.homeID = homeID
            self.list = list
        }
    }

    public enum Action: BindableAction {
        case task
        case moviesUpdated([StoredMovie])
        case allMoviesUpdated([StoredMovie])
        case searchChanged(String)
        case searchResponse([Movie])
        case addTapped(Movie)
        case removeTapped(StoredMovieID)
        case addMoviesTapped
        case searchDismissed
        case movieTapped(StoredMovie)
        case failed(AppError)
        case binding(BindingAction<State>)
        case detail(PresentationAction<MovieInfoFeature.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case movies, all, search }

    @Dependency(\.movies) var moviesClient
    @Dependency(\.catalog) var catalog
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [listID = state.list.id] send in
                        for try await movies in moviesClient.moviesInList(listID) {
                            await send(.moviesUpdated(movies))
                        }
                    } catch: { error, send in
                        await send(.failed(AppError(error)))
                    }
                    .cancellable(id: CancelID.movies, cancelInFlight: true),

                    .run { [homeID = state.homeID] send in
                        for try await movies in moviesClient.allMovies(homeID) {
                            await send(.allMoviesUpdated(movies))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.all, cancelInFlight: true)
                )

            case let .moviesUpdated(movies):
                state.isLoading = false
                state.movies = IdentifiedArray(uniqueElements: movies)
                return .none

            case let .allMoviesUpdated(movies):
                state.savedIDs = Set(movies.map(\.imdbID))
                return .none

            case let .searchChanged(text):
                state.searchText = text
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard query.count >= 2 else {
                    state.results = []
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }
                state.isSearching = true
                return .run { [includeAdult = state.includeAdultTitles] send in
                    // Debounce: the old search fired a request per keystroke.
                    try await clock.sleep(for: .milliseconds(300))
                    let movies = try await catalog.discover(
                        .search(query, includeAdult: includeAdult)
                    )
                    await send(.searchResponse(movies))
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case let .searchResponse(movies):
                state.isSearching = false
                state.results = movies
                return .none

            case let .addTapped(movie):
                return .run { [homeID = state.homeID, listID = state.list.id] send in
                    try await moviesClient.addMovie(homeID, listID, movie)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .removeTapped(id):
                return .run { send in
                    try await moviesClient.removeMovie(id)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .addMoviesTapped:
                state.isSearchPresented = true
                return .none

            case .searchDismissed:
                state.isSearchPresented = false
                state.searchText = ""
                state.results = []
                return .cancel(id: CancelID.search)

            case let .movieTapped(stored):
                state.detail = MovieInfoFeature.State(
                    homeID: state.homeID, movie: stored.asMovie
                )
                return .none

            case let .failed(error):
                state.isSearching = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .detail, .alert:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) { MovieInfoFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}

/// Everything TMDb knows about one film — and where the household keeps it.
///
/// This is the one screen a movie can be reached from anywhere, so it is also
/// where a film gets filed. A poll's matches, the round history and the lists
/// themselves all present it, which is what connects "we agreed on this" to
/// "it's on our watchlist" without a separate search for a film the app was
/// already showing you.
@Reducer
public struct MovieInfoFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var movie: Movie
        public var extras: MovieExtras?
        public var isLoading = true
        /// The home's lists, live — so a list made on another device is
        /// offered here without reopening the sheet.
        public var lists: IdentifiedArrayOf<MovieList> = []
        /// Which lists already hold this film, and the row to delete to undo
        /// that. One `movies:byHome` subscription answers it for every list at
        /// once.
        public var savedIn: [MovieListID: StoredMovieID] = [:]
        /// Lists with a write in flight, so a chip cannot be double-tapped into
        /// two rows.
        public var busy: Set<MovieListID> = []
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, movie: Movie) {
            self.homeID = homeID
            self.movie = movie
        }

        /// Presets first — Wishlist, then Watched — and custom lists after, in
        /// the order the Movies screen shows them.
        public var orderedLists: [MovieList] {
            lists.filter { $0.kind == .wishlist }
                + lists.filter { $0.kind == .watched }
                + lists.filter { $0.kind == .custom }
                    .sorted { Timestamp.newestFirst($1.created, $0.created) }
        }

        public func isSaved(in list: MovieList) -> Bool { savedIn[list.id] != nil }
        public func isBusy(_ list: MovieList) -> Bool { busy.contains(list.id) }
    }

    public enum Action: Equatable {
        case task
        case loaded(MovieDetails)
        case failed(AppError)
        case listsUpdated([MovieList])
        case savedUpdated([StoredMovie])
        case listToggled(MovieList)
        case writeFinished(MovieListID)
        case writeFailed(MovieListID, AppError)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case lists, saved }

    @Dependency(\.catalog) var catalog
    @Dependency(\.movies) var movies

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    // One request: the server appends credits and keywords
                    // rather than making the client ask three times.
                    .run { [id = state.movie.id] send in
                        await send(.loaded(try await catalog.details(id)))
                    } catch: { error, send in
                        await send(.failed(AppError(error)))
                    },

                    .run { [homeID = state.homeID] send in
                        for try await lists in movies.lists(homeID) {
                            await send(.listsUpdated(lists))
                        }
                    } catch: { _, _ in
                        // No lists means no save chips, which is the same thing
                        // the screen shows before they arrive.
                    }
                    .cancellable(id: CancelID.lists, cancelInFlight: true),

                    .run { [homeID = state.homeID] send in
                        for try await saved in movies.allMovies(homeID) {
                            await send(.savedUpdated(saved))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.saved, cancelInFlight: true)
                )

            case let .loaded(details):
                state.isLoading = false
                state.movie = details.movie
                state.extras = details.extras
                return .none

            case .failed:
                // The poster and title are already on screen; detail is a bonus.
                state.isLoading = false
                return .none

            case let .listsUpdated(lists):
                state.lists = IdentifiedArray(uniqueElements: lists)
                return .none

            case let .savedUpdated(saved):
                // Only this film, keyed by the list it sits in.
                state.savedIn = Dictionary(
                    saved
                        .filter { $0.imdbID == state.movie.id }
                        .compactMap { row in row.listID.map { ($0, row.id) } },
                    // A list that somehow holds the film twice keeps the first
                    // row; removing that one lets the live push surface the
                    // other rather than silently doing nothing.
                    uniquingKeysWith: { first, _ in first }
                )
                return .none

            case let .listToggled(list):
                guard !state.isBusy(list) else { return .none }
                state.busy.insert(list.id)
                let stored = state.savedIn[list.id]
                return .run { [homeID = state.homeID, movie = state.movie] send in
                    if let stored {
                        try await movies.removeMovie(stored)
                    } else {
                        try await movies.addMovie(homeID, list.id, movie)
                    }
                    await send(.writeFinished(list.id))
                } catch: { error, send in
                    await send(.writeFailed(list.id, AppError(error)))
                }

            case let .writeFinished(id):
                // The `movies:byHome` subscription is what flips the chip; this
                // only releases the tap.
                state.busy.remove(id)
                return .none

            case let .writeFailed(id, error):
                state.busy.remove(id)
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

@Reducer
public struct CreateMovieListFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var name = ""
        public var summary = ""
        public var isSubmitting = false
        public var inlineError: String?

        public init(homeID: HomeID) { self.homeID = homeID }

        public var canSubmit: Bool {
            !isSubmitting && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: Equatable, BindableAction {
        case submitTapped
        case failed(AppError)
        case finished
        case binding(BindingAction<State>)
    }

    @Dependency(\.movies) var movies

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
                    homeID = state.homeID, name = state.name, summary = state.summary
                ] send in
                    try await movies.createList(
                        homeID, name, summary.isEmpty ? nil : summary, .custom
                    )
                    await send(.finished)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

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

extension MovieList.Kind {
    public var title: LocalizedStringResource {
        switch self {
        case .wishlist: L10n.movieListsWishlistTitle
        case .watched: L10n.movieListsWatchedTitle
        case .custom: L10n.movieListsCustomLists
        }
    }

    /// The line under the name on a built-in list. `.custom` has none — a list
    /// a person made carries whatever description they wrote.
    public var subtitle: LocalizedStringResource {
        switch self {
        case .wishlist: L10n.movieListsWishlistSubtitle
        case .watched: L10n.movieListsWatchedSubtitle
        case .custom: L10n.movieListsCustomLists
        }
    }

    public var symbol: String {
        switch self {
        case .wishlist: "bookmark.fill"
        case .watched: "checkmark.seal.fill"
        case .custom: "list.star"
        }
    }

    public var tint: Color {
        switch self {
        case .wishlist: Palette.violet
        case .watched: Palette.success
        case .custom: Palette.cyan
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension MoviesFeature.Destination.State: Equatable {}
