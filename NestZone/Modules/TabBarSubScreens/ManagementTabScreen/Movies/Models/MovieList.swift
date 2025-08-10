import Foundation

struct MovieList: Identifiable, Codable {
    let id: String
    let homeId: String
    let name: String
    let description: String?
    let type: MovieListType
    let isPreset: Bool
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, type, created, updated
        case homeId = "home_id"
        case isPreset = "is_preset"
    }
}

enum MovieListType: String, Codable, CaseIterable {
    case wishlist = "wishlist"
    case watched = "watched"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .wishlist: return "Wishlist"
        case .watched: return "Watched"
        case .custom: return "Custom"
        }
    }
}

struct StoredMovie: Identifiable, Codable {
    let id: String
    let imdbId: String
    let title: String
    let year: Int?
    let poster: String?
    let genres: [String]
    let homeId: String
    let listId: String  // Back to single string relation
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, year, poster, genres, created, updated
        case imdbId = "imdb_id"
        case homeId = "home_id"
        case listId = "list_id"
    }
    
    init(from movie: Movie, homeId: String, listId: String) {
        self.id = ""
        self.imdbId = movie.id
        self.title = movie.title
        self.year = movie.year
        self.poster = movie.poster
        self.genres = movie.genres
        self.homeId = homeId
        self.listId = listId
        self.created = ""
        self.updated = ""
    }
    
    func toMovie() -> Movie {
        return Movie(
            id: self.imdbId,
            title: self.title,
            year: self.year,
            poster: self.poster,
            genres: self.genres
        )
    }
}