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
                state.isLoading = false
                state.lists = IdentifiedArray(uniqueElements: lists)
                return .none

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
                state.detail = MovieInfoFeature.State(movie: stored.asMovie)
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

/// Everything TMDb knows about one film, fetched on demand.
@Reducer
public struct MovieInfoFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var movie: Movie
        public var extras: MovieExtras?
        public var isLoading = true

        public init(movie: Movie) { self.movie = movie }
    }

    public enum Action: Equatable {
        case task
        case loaded(MovieDetails)
        case failed(AppError)
    }

    @Dependency(\.catalog) var catalog

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                // One request: the server appends credits and keywords rather
                // than making the client ask three times.
                return .run { [id = state.movie.id] send in
                    await send(.loaded(try await catalog.details(id)))
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .loaded(details):
                state.isLoading = false
                state.movie = details.movie
                state.extras = details.extras
                return .none

            case .failed:
                // The poster and title are already on screen; detail is a bonus.
                state.isLoading = false
                return .none
            }
        }
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
