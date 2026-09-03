import Foundation
import ConvexMobile

@MainActor
final class MovieListsManager {
    static let shared = MovieListsManager()
    private init() {}

    enum MoviesError: LocalizedError {
        case noHome
        var errorDescription: String? { "No home selected" }
    }

    private func currentHomeId() throws -> String {
        guard let id = HomeSelectionManager.shared.selectedHomeId else { throw MoviesError.noHome }
        return id
    }

    // MARK: - Movie Lists

    func fetchMovieLists() async throws -> [MovieList] {
        let homeId = try currentHomeId()
        let lists: [MovieList] = try await Convex.once(
            "movies:listsByHome", args: ["homeId": homeId], as: [MovieList].self
        )
        return lists.sorted { ($0.created ?? 0) < ($1.created ?? 0) }
    }

    func createPresetList(type: MovieListType) async throws -> MovieList {
        let homeId = try currentHomeId()
        return try await Convex.client.mutation("movies:createList", with: [
            "homeId": homeId,
            "name": type.displayName,
            "description": getPresetDescription(for: type),
            "type": type.rawValue,
            "is_preset": true,
        ])
    }

    func createCustomList(name: String, description: String) async throws -> MovieList {
        let homeId = try currentHomeId()
        return try await Convex.client.mutation("movies:createList", with: [
            "homeId": homeId,
            "name": name,
            "description": description,
            "type": MovieListType.custom.rawValue,
            "is_preset": false,
        ])
    }

    func deleteList(listId: String) async throws {
        // Server removes the list and all its movies.
        try await Convex.run("movies:removeList", args: ["id": listId])
    }

    func addMovieToList(movie: Movie, listId: String) async throws {
        let homeId = try currentHomeId()
        // Skip if the movie is already in this list.
        if try await isMovieInList(imdbId: movie.id, listId: listId) { return }
        var args: [String: ConvexEncodable?] = [
            "homeId": homeId,
            "listId": listId,
            "imdb_id": movie.id,
            "title": movie.title,
            "genres": movie.genres.map { $0 as ConvexEncodable? },
        ]
        if let year = movie.year { args["year"] = Double(year) }
        if let poster = movie.poster { args["poster"] = poster }
        try await Convex.run("movies:addMovie", args: args)
    }

    func removeMovieFromList(movieId: String, listId: String) async throws {
        let listMovies = try await fetchMoviesForList(listId: listId)
        guard let record = listMovies.first(where: { $0.imdbId == movieId || $0.id == movieId }) else {
            return
        }
        try await Convex.run("movies:removeMovie", args: ["id": record.id])
    }

    // MARK: - Movies

    func fetchMoviesForList(listId: String) async throws -> [StoredMovie] {
        let movies: [StoredMovie] = try await Convex.once(
            "movies:moviesInList", args: ["listId": listId], as: [StoredMovie].self
        )
        return movies.sorted { ($0.created ?? 0) > ($1.created ?? 0) }
    }

    func fetchAllMoviesForHome() async throws -> [StoredMovie] {
        let homeId = try currentHomeId()
        return try await Convex.once("movies:byHome", args: ["homeId": homeId], as: [StoredMovie].self)
    }

    func getMovieCountForList(listId: String) async throws -> Int {
        try await fetchMoviesForList(listId: listId).count
    }

    func isMovieInList(imdbId: String, listId: String) async throws -> Bool {
        try await fetchMoviesForList(listId: listId).contains { $0.imdbId == imdbId }
    }

    func getListsForMovie(imdbId: String) async throws -> [String] {
        let homeId = try currentHomeId()
        let all: [StoredMovie] = try await Convex.once(
            "movies:byHome", args: ["homeId": homeId], as: [StoredMovie].self
        )
        return all.filter { $0.imdbId == imdbId }.compactMap { $0.listId }
    }

    func updateListDescription(listId: String, newDescription: String) async throws -> MovieList {
        try await Convex.client.mutation("movies:updateList", with: ["id": listId, "description": newDescription])
    }

    func updateListName(listId: String, newName: String) async throws -> MovieList {
        try await Convex.client.mutation("movies:updateList", with: ["id": listId, "name": newName])
    }

    func getPresetDescription(for type: MovieListType) -> String {
        switch type {
        case .wishlist: return LocalizationManager.movieListsWishlistDescriptionFull
        case .watched: return LocalizationManager.movieListsWatchedDescriptionFull
        case .custom: return ""
        }
    }
}
