import Foundation

final class MovieListsManager: @unchecked Sendable {
    static let shared = MovieListsManager()
    private init() {}
    
    private let pocketBase = PocketBaseManager.shared
    
    private struct PBListResponse<T: Codable>: Codable {
        let page: Int?
        let perPage: Int?
        let totalItems: Int?
        let items: [T]
    }
    
    private struct HomeLite: Codable {
        let id: String
    }
    
    private func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
    
    private func encodeFilter(_ filter: String) -> String {
        // Use standard URL encoding for the entire filter
        return filter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filter
    }
    
    private func getCurrentHomeId() async throws -> String {
        // Get the first home for the user
        let endpoint = "/api/collections/homes/records?perPage=1"
        let response: PBListResponse<HomeLite> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<HomeLite>.self)
        guard let homeId = response.items.first?.id else {
            throw PocketBaseManager.PocketBaseError.notFound
        }
        return homeId
    }
    
    // MARK: - Movie Lists
    
    func fetchMovieLists() async throws -> [MovieList] {
        let homeId = try await getCurrentHomeId()
        let filterRaw = "home_id = '\(homeId)'"
        let endpoint = "/api/collections/movie_lists/records?filter=\(encodeFilter(filterRaw))&sort=created"
        let response: PBListResponse<MovieList> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<MovieList>.self)
        return response.items
    }
    
    func createPresetList(type: MovieListType) async throws -> MovieList {
        let homeId = try await getCurrentHomeId()
        
        let params: [String: Any] = [
            "home_id": homeId,
            "name": type.displayName,
            "description": getPresetDescription(for: type),
            "type": type.rawValue,
            "is_preset": true
        ]
        
        return try await pocketBase.createRecord(in: "movie_lists", data: params, responseType: MovieList.self)
    }
    
    func createCustomList(name: String, description: String) async throws -> MovieList {
        let homeId = try await getCurrentHomeId()
        
        let params: [String: Any] = [
            "home_id": homeId,
            "name": name,
            "description": description,
            "type": MovieListType.custom.rawValue,
            "is_preset": false
        ]
        
        return try await pocketBase.createRecord(in: "movie_lists", data: params, responseType: MovieList.self)
    }
    
    func deleteList(listId: String) async throws {
        // First delete all movies in this list
        try await deleteAllMoviesInList(listId: listId)
        
        // Then delete the list itself
        try await pocketBase.deleteRecord(from: "movie_lists", id: listId)
    }
    
    private func deleteAllMoviesInList(listId: String) async throws {
        let movies = try await fetchMoviesForList(listId: listId)
        for movie in movies {
            try await pocketBase.deleteRecord(from: "movies", id: movie.id)
        }
    }
    
    func addMovieToList(movie: Movie, listId: String) async throws {
        let homeId = try await getCurrentHomeId()
        
        // Check if movie already exists in this specific list
        let filterRaw = "imdb_id = '\(movie.id)' && list_id = '\(listId)'"
        let checkEndpoint = "/api/collections/movies/records?filter=\(encodeFilter(filterRaw))&perPage=1"
        let checkResponse: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: checkEndpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        
        if checkResponse.items.isEmpty {
            // Movie doesn't exist in this list, create new record
            let params: [String: Any] = [
                "imdb_id": movie.id,
                "title": movie.title,
                "year": movie.year ?? NSNull(),
                "poster": movie.poster ?? NSNull(),
                "genres": movie.genres,
                "home_id": homeId,
                "list_id": listId  // Single relation
            ]
            
            let _: StoredMovie = try await pocketBase.createRecord(in: "movies", data: params, responseType: StoredMovie.self)
            print("✅ Added \(movie.title) to list \(listId)")
        } else {
            print("ℹ️ Movie \(movie.title) already exists in list \(listId)")
        }
    }

    func removeMovieFromList(movieId: String, listId: String) async throws {
        // First get all movies for this specific list
        let listMovies = try await fetchMoviesForList(listId: listId)
        
        // Find the movie in this list by IMDb ID or record ID
        guard let recordToDelete = listMovies.first(where: { 
            $0.imdbId == movieId || $0.id == movieId 
        }) else {
            print("⚠️ Movie with id \(movieId) not found in list \(listId)")
            return
        }
        
        // Delete the found record
        try await pocketBase.deleteRecord(from: "movies", id: recordToDelete.id)
        print("🗑️ Removed movie from list \(listId) (recordId: \(recordToDelete.id), imdb: \(recordToDelete.imdbId))")
    }
    
    // MARK: - Movies
    
    func fetchMoviesForList(listId: String) async throws -> [StoredMovie] {
        let filterRaw = "list_id = '\(listId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encodeFilter(filterRaw))&sort=-created"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return response.items
    }
    
    func fetchAllMoviesForHome() async throws -> [StoredMovie] {
        let homeId = try await getCurrentHomeId()
        let filterRaw = "home_id = '\(homeId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encodeFilter(filterRaw))&sort=-created"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return response.items
    }
    
    func getMovieCountForList(listId: String) async throws -> Int {
        let filterRaw = "list_id = '\(listId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encodeFilter(filterRaw))&perPage=1"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return response.totalItems ?? 0
    }
    
    func isMovieInList(imdbId: String, listId: String) async throws -> Bool {
        let filterRaw = "imdb_id = '\(imdbId)' && list_id = '\(listId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encodeFilter(filterRaw))&perPage=1"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return !response.items.isEmpty
    }
    
    func getListsForMovie(imdbId: String) async throws -> [String] {
        let homeId = try await getCurrentHomeId()
        let filterRaw = "imdb_id = '\(imdbId)' && home_id = '\(homeId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encodeFilter(filterRaw))"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return response.items.map { $0.listId }
    }

    func updateListDescription(listId: String, newDescription: String) async throws -> MovieList {
        let params: [String: Any] = [
            "description": newDescription
        ]
        return try await pocketBase.updateRecord(in: "movie_lists", id: listId, data: params, responseType: MovieList.self)
    }

    func updateListName(listId: String, newName: String) async throws -> MovieList {
        let params: [String: Any] = [
            "name": newName
        ]
        return try await pocketBase.updateRecord(in: "movie_lists", id: listId, data: params, responseType: MovieList.self)
    }

    func getPresetDescription(for type: MovieListType) -> String {
        switch type {
        case .wishlist: return LocalizationManager.movieListsWishlistDescriptionFull
        case .watched: return LocalizationManager.movieListsWatchedDescriptionFull
        case .custom: return ""
        }
    }
}