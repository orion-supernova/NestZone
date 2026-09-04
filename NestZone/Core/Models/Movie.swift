import Foundation

/// A movie as it comes back from the catalogue (TMDb, proxied through Convex).
public struct Movie: Codable, Identifiable, Hashable, Sendable {
    /// TMDb id, as a string.
    public let id: String
    public var title: String
    public var year: Int?
    /// Either a bare TMDb path (`/abc.jpg`) or an absolute URL.
    public var poster: String?
    public var genres: [String]

    public init(id: String, title: String, year: Int? = nil, poster: String? = nil, genres: [String] = []) {
        self.id = id
        self.title = title
        self.year = year
        self.poster = poster
        self.genres = genres
    }
}

extension Movie {
    public func posterURL(width: TMDbImageWidth = .w500) -> URL? {
        TMDbImageWidth.url(for: poster, width: width)
    }
}

/// The poster/backdrop sizes TMDb serves. Picking the smallest one that covers
/// the layout is the single cheapest network win in the movie screens — the app
/// used to request `w500` posters for 60-point thumbnails.
public enum TMDbImageWidth: String, Sendable {
    case w92, w185, w342, w500, w780, original

    static func url(for path: String?, width: TMDbImageWidth) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "https://image.tmdb.org/t/p/\(width.rawValue)\(path)")
    }
}

/// Everything the detail sheet shows beyond the poster grid. Fetched lazily,
/// because it costs an extra request per movie.
public struct MovieExtras: Codable, Hashable, Sendable {
    public var plot: String?
    public var cast: [CastMember]
    public var directors: [String]
    public var writers: [String]
    public var runtimeMinutes: Int?
    public var rating: Double?
    public var voteCount: Int?
    public var budget: Int?
    public var revenue: Int?
    public var releaseDate: String?
    public var originalLanguage: String?
    public var productionCompanies: [String]
    public var keywords: [String]
    public var backdropPath: String?

    public struct CastMember: Codable, Hashable, Sendable, Identifiable {
        public let name: String
        public let character: String?
        public let profilePath: String?

        public var id: String { name + (character ?? "") }
        public var profileURL: URL? { TMDbImageWidth.url(for: profilePath, width: .w185) }

        public init(name: String, character: String? = nil, profilePath: String? = nil) {
            self.name = name
            self.character = character
            self.profilePath = profilePath
        }
    }

    public var backdropURL: URL? { TMDbImageWidth.url(for: backdropPath, width: .w780) }

    public init(
        plot: String? = nil,
        cast: [CastMember] = [],
        directors: [String] = [],
        writers: [String] = [],
        runtimeMinutes: Int? = nil,
        rating: Double? = nil,
        voteCount: Int? = nil,
        budget: Int? = nil,
        revenue: Int? = nil,
        releaseDate: String? = nil,
        originalLanguage: String? = nil,
        productionCompanies: [String] = [],
        keywords: [String] = [],
        backdropPath: String? = nil
    ) {
        self.plot = plot
        self.cast = cast
        self.directors = directors
        self.writers = writers
        self.runtimeMinutes = runtimeMinutes
        self.rating = rating
        self.voteCount = voteCount
        self.budget = budget
        self.revenue = revenue
        self.releaseDate = releaseDate
        self.originalLanguage = originalLanguage
        self.productionCompanies = productionCompanies
        self.keywords = keywords
        self.backdropPath = backdropPath
    }
}

/// One of the home's saved lists (wishlist / watched / a custom one).
public struct MovieList: Codable, Identifiable, Hashable, Sendable {
    public let id: MovieListID
    public var homeID: HomeID?
    public var name: String
    public var summary: String?
    public var kind: Kind
    public var isPreset: Bool
    public var created: Timestamp?
    public var updated: Timestamp?

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case wishlist, watched, custom
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case summary = "description"
        case kind = "type"
        case created, updated
        case homeID = "home_id"
        case isPreset = "is_preset"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(MovieListID.self, forKey: .id)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        kind = c.decodeLenient(Kind.self, forKey: .kind, default: .custom)
        isPreset = try c.decodeIfPresent(Bool.self, forKey: .isPreset) ?? false
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: MovieListID,
        homeID: HomeID? = nil,
        name: String,
        summary: String? = nil,
        kind: Kind = .custom,
        isPreset: Bool = false,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.homeID = homeID
        self.name = name
        self.summary = summary
        self.kind = kind
        self.isPreset = isPreset
        self.created = created
        self.updated = updated
    }
}

/// A movie saved into one of the home's lists.
public struct StoredMovie: Codable, Identifiable, Hashable, Sendable {
    public let id: StoredMovieID
    public var imdbID: String
    public var title: String
    public var year: Int?
    public var poster: String?
    public var genres: [String]
    public var homeID: HomeID?
    public var listID: MovieListID?
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, year, poster, genres, created, updated
        case imdbID = "imdb_id"
        case homeID = "home_id"
        case listID = "list_id"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(StoredMovieID.self, forKey: .id)
        imdbID = try c.decodeIfPresent(String.self, forKey: .imdbID) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        poster = try c.decodeIfPresent(String.self, forKey: .poster)
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        listID = try c.decodeIfPresent(MovieListID.self, forKey: .listID)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: StoredMovieID,
        imdbID: String,
        title: String,
        year: Int? = nil,
        poster: String? = nil,
        genres: [String] = [],
        homeID: HomeID? = nil,
        listID: MovieListID? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.imdbID = imdbID
        self.title = title
        self.year = year
        self.poster = poster
        self.genres = genres
        self.homeID = homeID
        self.listID = listID
        self.created = created
        self.updated = updated
    }

    public func posterURL(width: TMDbImageWidth = .w342) -> URL? {
        TMDbImageWidth.url(for: poster, width: width)
    }

    /// The catalogue movie this row stands for.
    public var asMovie: Movie {
        Movie(id: imdbID, title: title, year: year, poster: poster, genres: genres)
    }
}
