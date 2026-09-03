import Foundation

struct MovieList: Identifiable, Codable {
    let id: String
    let homeId: String?
    let name: String
    let description: String?
    let type: MovieListType
    let isPreset: Bool
    let created: Double?
    let updated: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, description, type, created, updated
        case homeId = "home_id"
        case isPreset = "is_preset"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        homeId = try c.decodeIfPresent(String.self, forKey: .homeId)
        name = (try c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        type = (try c.decodeIfPresent(MovieListType.self, forKey: .type)) ?? .custom
        isPreset = (try c.decodeIfPresent(Bool.self, forKey: .isPreset)) ?? false
        created = try c.decodeIfPresent(Double.self, forKey: .created)
        updated = try c.decodeIfPresent(Double.self, forKey: .updated)
    }

    // Memberwise init for previews / local construction.
    init(id: String, homeId: String?, name: String, description: String?,
         type: MovieListType, isPreset: Bool, created: Double? = nil, updated: Double? = nil) {
        self.id = id; self.homeId = homeId; self.name = name; self.description = description
        self.type = type; self.isPreset = isPreset; self.created = created; self.updated = updated
    }
}

enum MovieListType: String, Codable, CaseIterable {
    case wishlist = "wishlist"
    case watched = "watched"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .wishlist: return LocalizationManager.movieListsWishlistTitle
        case .watched: return LocalizationManager.movieListsWatchedTitle
        case .custom: return LocalizationManager.movieListsCustomLists
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
    let homeId: String?
    let listId: String?  // single relation
    let created: Double?
    let updated: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, year, poster, genres, created, updated
        case imdbId = "imdb_id"
        case homeId = "home_id"
        case listId = "list_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        imdbId = (try c.decodeIfPresent(String.self, forKey: .imdbId)) ?? ""
        title = (try c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        poster = try c.decodeIfPresent(String.self, forKey: .poster)
        genres = (try c.decodeIfPresent([String].self, forKey: .genres)) ?? []
        homeId = try c.decodeIfPresent(String.self, forKey: .homeId)
        listId = try c.decodeIfPresent(String.self, forKey: .listId)
        created = try c.decodeIfPresent(Double.self, forKey: .created)
        updated = try c.decodeIfPresent(Double.self, forKey: .updated)
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
        self.created = nil
        self.updated = nil
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