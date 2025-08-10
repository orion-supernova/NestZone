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
        let endpoint = "/api/collections/movie_lists/records?filter=\(encode(filterRaw))&sort=created"
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
        
        let filterRaw = "imdb_id = '\(movie.id)' && list_id = '\(listId)'"
        let checkEndpoint = "/api/collections/movies/records?filter=\(encode(filterRaw))&perPage=1"
        let checkResponse: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: checkEndpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        
        if checkResponse.items.isEmpty {
            let params: [String: Any] = [
                "imdb_id": movie.id,
                "title": movie.title,
                "year": movie.year ?? NSNull(),
                "poster": movie.poster ?? NSNull(),
                "genres": movie.genres,
                "home_id": homeId,
                "list_id": listId
            ]
            
            let _: StoredMovie = try await pocketBase.createRecord(in: "movies", data: params, responseType: StoredMovie.self)
            print("✅ Added \(movie.title) to list \(listId)")
        } else {
            print("ℹ️ Movie \(movie.title) already exists in list \(listId)")
        }
    }

    func removeMovieFromList(movieId: String, listId: String) async throws {
        // movieId here may be either a PB record id or an IMDb id. Try both.
        let filterRaw = "(id = '\(movieId)' || imdb_id = '\(movieId)') && list_id = '\(listId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encode(filterRaw))&perPage=1"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        
        if let record = response.items.first {
            try await pocketBase.deleteRecord(from: "movies", id: record.id)
            print("🗑️ Removed movie from list \(listId) (recordId: \(record.id), imdb: \(record.imdbId))")
        }
    }
    
    // MARK: - Movies
    
    func fetchMoviesForList(listId: String) async throws -> [StoredMovie] {
        let filterRaw = "list_id = '\(listId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encode(filterRaw))&sort=-created"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return response.items
    }
    
    func fetchAllMoviesForHome() async throws -> [StoredMovie] {
        let homeId = try await getCurrentHomeId()
        let filterRaw = "home_id = '\(homeId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encode(filterRaw))&sort=-created"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return response.items
    }
    
    func getMovieCountForList(listId: String) async throws -> Int {
        let filterRaw = "list_id = '\(listId)'"
        let endpoint = "/api/collections/movies/records?filter=\(encode(filterRaw))&perPage=1"
        let response: PBListResponse<StoredMovie> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<StoredMovie>.self)
        return response.totalItems ?? 0
    }
    
    private func getPresetDescription(for type: MovieListType) -> String {
        switch type {
        case .wishlist: return "Movies you want to watch someday"
        case .watched: return "Movies you've already watched"
        case .custom: return ""
        }
    }
}