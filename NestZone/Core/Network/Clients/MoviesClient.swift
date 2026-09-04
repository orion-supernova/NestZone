import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct MoviesClient: Sendable {
    public var lists: @Sendable (HomeID) -> AsyncThrowingStream<[MovieList], any Error> = { _ in .never }
    public var moviesInList: @Sendable (MovieListID) -> AsyncThrowingStream<[StoredMovie], any Error> = { _ in .never }
    /// Every saved movie in the home — used to mark "already on a list" in
    /// search results without one query per row.
    public var allMovies: @Sendable (HomeID) -> AsyncThrowingStream<[StoredMovie], any Error> = { _ in .never }
    public var createList: @Sendable (HomeID, String, String?, MovieList.Kind) async throws -> Void
    public var updateList: @Sendable (MovieListID, String, String?) async throws -> Void
    public var removeList: @Sendable (MovieListID) async throws -> Void
    public var addMovie: @Sendable (HomeID, MovieListID, Movie) async throws -> Void
    public var removeMovie: @Sendable (StoredMovieID) async throws -> Void
}

extension MoviesClient: DependencyKey {
    public static let liveValue = MoviesClient(
        lists: { homeID in
            ConvexConnection.shared.subscribe(
                to: "movies:listsByHome", args: ["homeId": homeID], as: [MovieList].self
            )
        },
        moviesInList: { listID in
            ConvexConnection.shared.subscribe(
                to: "movies:moviesInList", args: ["listId": listID], as: [StoredMovie].self
            )
        },
        allMovies: { homeID in
            ConvexConnection.shared.subscribe(
                to: "movies:byHome", args: ["homeId": homeID], as: [StoredMovie].self
            )
        },
        createList: { homeID, name, summary, kind in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.listNameEmpty",
                    defaultValue: "Name the list first."
                ))
            }
            var args: [String: ConvexEncodable?] = [
                "homeId": homeID, "name": trimmed, "type": kind.rawValue,
            ]
            if let summary, !summary.isEmpty { args["description"] = summary }
            try await ConvexConnection.shared.mutate("movies:createList", args: args)
        },
        updateList: { id, name, summary in
            var args: [String: ConvexEncodable?] = ["id": id, "name": name]
            if let summary { args["description"] = summary }
            try await ConvexConnection.shared.mutate("movies:updateList", args: args)
        },
        removeList: { id in
            try await ConvexConnection.shared.mutate("movies:removeList", args: ["id": id])
        },
        addMovie: { homeID, listID, movie in
            var args: [String: ConvexEncodable?] = [
                "homeId": homeID,
                "listId": listID,
                "imdb_id": movie.id,
                "title": movie.title,
                "genres": movie.genres.map { $0 as ConvexEncodable? },
            ]
            if let year = movie.year { args["year"] = year.convexNumber }
            if let poster = movie.poster { args["poster"] = poster }
            try await ConvexConnection.shared.mutate("movies:addMovie", args: args)
        },
        removeMovie: { id in
            try await ConvexConnection.shared.mutate("movies:removeMovie", args: ["id": id])
        }
    )

    public static let testValue = MoviesClient()
}

extension DependencyValues {
    public var movies: MoviesClient {
        get { self[MoviesClient.self] }
        set { self[MoviesClient.self] = newValue }
    }
}
