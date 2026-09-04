import ComposableArchitecture
import Foundation
import ConvexMobile

/// The movie catalogue, reached through the `catalog:*` Convex actions.
///
/// The app used to call api.themoviedb.org directly with the TMDb key compiled
/// into the binary as a string literal. The key now lives in the Convex
/// deployment environment, so it is not shipped to devices at all. Multi-page
/// browses are also fetched in parallel server-side instead of three sequential
/// round trips from the phone.
@DependencyClient
public struct CatalogClient: Sendable {
    public var discover: @Sendable (CatalogQuery) async throws -> [Movie] = { _ in [] }
    /// Base fields plus everything the detail sheet shows, in one request.
    public var details: @Sendable (String) async throws -> MovieDetails
}

public struct CatalogQuery: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case search, genre, year, decade, actor, director
        case popular, topRated, nowPlaying, upcoming
    }

    public var kind: Kind
    public var query: String?
    public var year: Int?
    public var includeAdult: Bool

    public init(kind: Kind, query: String? = nil, year: Int? = nil, includeAdult: Bool = false) {
        self.kind = kind
        self.query = query
        self.year = year
        self.includeAdult = includeAdult
    }

    public static func search(_ text: String, includeAdult: Bool = false) -> Self {
        .init(kind: .search, query: text, includeAdult: includeAdult)
    }

    public static func genre(_ name: String, includeAdult: Bool = false) -> Self {
        .init(kind: .genre, query: name, includeAdult: includeAdult)
    }
}

public struct MovieDetails: Decodable, Equatable, Sendable {
    public var movie: Movie
    public var extras: MovieExtras
}

extension CatalogClient: DependencyKey {
    public static let liveValue = CatalogClient(
        discover: { request in
            var args: [String: ConvexEncodable?] = [
                "kind": request.kind.rawValue,
                "includeAdult": request.includeAdult,
            ]
            if let query = request.query { args["query"] = query }
            if let year = request.year { args["year"] = year.convexNumber }
            return try await ConvexConnection.shared.act(
                "catalog:discover", args: args, as: [Movie].self
            )
        },
        details: { tmdbID in
            try await ConvexConnection.shared.act(
                "catalog:details", args: ["tmdbId": tmdbID], as: MovieDetails.self
            )
        }
    )

    public static let testValue = CatalogClient()
}

extension DependencyValues {
    public var catalog: CatalogClient {
        get { self[CatalogClient.self] }
        set { self[CatalogClient.self] = newValue }
    }
}
