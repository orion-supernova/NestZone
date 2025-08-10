import Foundation
import SwiftUI

struct Movie: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let year: Int?
    let poster: String?
    let genres: [String]
    
    var posterURL: URL? {
        guard let poster else { return nil }
        return URL(string: poster)
    }
}

final class MovieAPI {
    static let shared = MovieAPI()
    private init() {}
    
    // Thread-safe cache and catalog with actors or locks
    private let cacheQueue = DispatchQueue(label: "MovieAPI.cache", attributes: .concurrent)
    private var _cache: [String: Movie] = [:]
    private var _catalog: [Movie] = []
    private var _catalogLoaded = false
    
    private var cache: [String: Movie] {
        get {
            return cacheQueue.sync { _cache }
        }
        set {
            cacheQueue.async(flags: .barrier) { self._cache = newValue }
        }
    }
    
    private var catalog: [Movie] {
        get {
            return cacheQueue.sync { _catalog }
        }
        set {
            cacheQueue.async(flags: .barrier) { self._catalog = newValue }
        }
    }
    
    private var catalogLoaded: Bool {
        get {
            return cacheQueue.sync { _catalogLoaded }
        }
        set {
            cacheQueue.async(flags: .barrier) { self._catalogLoaded = newValue }
        }
    }
    
    // Expanded curated IMDb IDs for better search results
    private let curatedIDs: [String] = [
        // Marvel/Superhero
        "tt4154796", "tt0848228", "tt3501632", "tt1825683", "tt2250912", "tt10872600", "tt4154756", "tt6320628", "tt4154664", "tt2395427",
        // Classic/Popular
        "tt0111161", "tt0068646", "tt0071562", "tt0468569", "tt0050083", "tt0108052", "tt0167260", "tt0110912", "tt0060196", "tt0120737",
        // Sci-Fi
        "tt0133093", "tt0137523", "tt0816692", "tt1375666", "tt0109830", "tt0120815", "tt0121765", "tt0121766", "tt0086190", "tt0078748",
        // Action/Thriller
        "tt0120586", "tt0114369", "tt0088763", "tt0317248", "tt0993846", "tt1345836", "tt0405094", "tt0372784", "tt0482571", "tt1853728",
        // Comedy/Drama
        "tt6751668", "tt1049413", "tt0407887", "tt7286456", "tt4158110", "tt0892769", "tt0325980", "tt0338013", "tt0268978", "tt0162222",
        // Spider-Man specifically (since you searched for it)
        "tt0145487", "tt0316654", "tt0413300", "tt0948470", "tt1872181", "tt2250912", "tt6320628", "tt10872600",
        // Eternal Sunshine and Charlie Kaufman
        "tt0338013", "tt0405159", "tt1101592", "tt2872718",
        // More variety
        "tt0169547", "tt0172495", "tt0253474", "tt0364569", "tt0477348", "tt0758758", "tt1130884", "tt1392190", "tt1675434", "tt1877830"
    ]
    
    // MARK: - Public API
    
    func searchMovies(query: String) async -> [Movie] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if q.isEmpty {
            return await searchMoviesFromAPI(query: "popular")
        }
        
        let lower = q.lowercased()
        if lower == "popular" || lower == "top" {
            let popularQueries = ["Spider-Man", "Avengers", "Batman", "Star Wars", "Marvel", "Harry Potter"]
            let randomQuery = popularQueries.randomElement() ?? "popular"
            if let suggestion = await searchMoviesViaIMDBSuggestion(query: randomQuery), !suggestion.isEmpty {
                return suggestion
            }
            return await searchMoviesFromAPI(query: randomQuery)
        }
        
        if let suggestion = await searchMoviesViaIMDBSuggestion(query: q), !suggestion.isEmpty {
            return suggestion
        }
        return await searchMoviesFromAPI(query: q)
    }
    
    private func searchMoviesViaIMDBSuggestion(query: String) async -> [Movie]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let first = query.first?.lowercased() else {
            return nil
        }
        let urlStr = "https://v2.sg.media-imdb.com/suggestion/\(first)/\(encoded).json"
        guard let url = URL(string: urlStr) else { return nil }
        
        struct SuggestResponse: Decodable {
            struct Item: Decodable {
                let id: String?
                let l: String?
                let y: Int?
                let i: ImageData?
                
                struct ImageData: Decodable {
                    let imageUrl: String?
                    let width: Int?
                    let height: Int?
                }
            }
            let d: [Item]?
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SuggestResponse.self, from: data)
            let items = decoded.d ?? []
            let movies: [Movie] = items.compactMap { item in
                guard let id = item.id, id.hasPrefix("tt"), let title = item.l else { return nil }
                let poster = item.i?.imageUrl
                let year = item.y
                return Movie(id: id, title: title, year: year, poster: poster, genres: [])
            }
            for m in movies {
                cacheQueue.async(flags: .barrier) { self._cache[m.id] = m }
            }
            return movies
        } catch {
            print("IMDb suggestion search failed for '\(query)': \(error)")
            return nil
        }
    }
    
    private func searchMoviesFromAPI(query: String) async -> [Movie] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://imdb.iamidiotareyoutoo.com/search?q=\(encodedQuery)") else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let movies = try decodeSearchResults(data: data)
            for movie in movies {
                cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
            }
            return movies
        } catch {
            print("API search failed for '\(query)': \(error)")
            return []
        }
    }
    
    func getDetails(imdbID: String) async -> Movie? {
        if let cached = cacheQueue.sync(execute: { _cache[imdbID] }) {
            return cached
        }
        
        guard let url = URL(string: "https://imdb.iamidiotareyoutoo.com/search?tt=\(imdbID)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let movie = try decodeIMDBDetails(imdbID: imdbID, data: data) {
                cacheQueue.async(flags: .barrier) { self._cache[imdbID] = movie }
                return movie
            }
        } catch {
            print("Failed to fetch details for \(imdbID): \(error)")
        }
        return nil
    }
    
    func searchByGenre(genre: String) async -> [Movie] {
        // Try API search first with genre-specific queries
        let genreQueries: [String: [String]] = [
            "action": ["action", "marvel", "batman", "fast furious"],
            "adventure": ["adventure", "indiana jones", "pirates caribbean"],
            "comedy": ["comedy", "funny", "laugh", "adam sandler"],
            "drama": ["drama", "oscar", "best picture"],
            "fantasy": ["fantasy", "lord rings", "harry potter"],
            "horror": ["horror", "scary", "halloween", "nightmare"],
            "romance": ["romance", "love", "romantic", "rom com"],
            "sci-fi": ["sci-fi", "star wars", "star trek", "blade runner"],
            "thriller": ["thriller", "suspense", "psychological"],
            "animation": ["animation", "disney", "pixar", "cartoon"]
        ]
        
        let g = genre.lowercased()
        let queries = genreQueries[g] ?? [genre]
        let selectedQuery = queries.randomElement() ?? genre
        
        let apiResults = await searchMoviesFromAPI(query: selectedQuery)
        
        // Filter by genre if possible
        let genreFiltered = apiResults.filter { movie in
            movie.genres.map { $0.lowercased() }.contains(where: { $0.contains(g) })
        }
        
        if !genreFiltered.isEmpty {
            return Array(genreFiltered.shuffled().prefix(20))
        }
        
        // Return API results even if not perfectly genre-matched
        if !apiResults.isEmpty {
            return Array(apiResults.shuffled().prefix(20))
        }
        
        // Return empty array if no API results
        return []
    }
    
    // MARK: - Helpers
    
    private func ensureCatalogLoaded() async {
        if catalogLoaded { return }
        
        // Build catalog from curated IDs only (network), not static hardcoded items
        let loaded = await withTaskGroup(of: Movie?.self) { group in
            for id in curatedIDs {
                group.addTask { await self.getDetails(imdbID: id) }
            }
            var movies: [Movie] = []
            for await movie in group {
                if let movie = movie, !movies.contains(where: { $0.id == movie.id }) {
                    movies.append(movie)
                }
            }
            return movies
        }
        
        cacheQueue.async(flags: .barrier) {
            self._catalog = loaded
            self._catalogLoaded = true
        }
    }
    
    private func extractIMDBId(from text: String) -> String? {
        let pattern = #"tt\d{7,}"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
    
    private func decodeSearchResults(data: Data) throws -> [Movie] {
        struct SearchResult: Decodable {
            let imdbId: String?
            let name: String?
            let image: String?
            let datePublished: String?
            let genre: [String]?
        }
        
        let decoder = JSONDecoder()
        
        // Try to decode as array first
        if let results = try? decoder.decode([SearchResult].self, from: data) {
            return results.compactMap { result in
                guard let imdbId = result.imdbId, let name = result.name else { return nil }
                
                let year: Int? = {
                    if let date = result.datePublished, let y = Int(date.prefix(4)) { return y }
                    return nil
                }()
                
                return Movie(
                    id: imdbId,
                    title: name,
                    year: year,
                    poster: result.image,
                    genres: result.genre ?? []
                )
            }
        }
        
        // Try to decode as single result
        if let result = try? decoder.decode(SearchResult.self, from: data) {
            guard let imdbId = result.imdbId, let name = result.name else { return [] }
            
            let year: Int? = {
                if let date = result.datePublished, let y = Int(date.prefix(4)) { return y }
                return nil
            }()
            
            return [Movie(
                id: imdbId,
                title: name,
                year: year,
                poster: result.image,
                genres: result.genre ?? []
            )]
        }
        
        // Try to decode as dictionary with results key
        struct SearchResponse: Decodable {
            let results: [SearchResult]?
            let Search: [SearchResult]?  // Some APIs use uppercase
        }
        
        if let response = try? decoder.decode(SearchResponse.self, from: data) {
            let results = response.results ?? response.Search ?? []
            return results.compactMap { result in
                guard let imdbId = result.imdbId, let name = result.name else { return nil }
                
                let year: Int? = {
                    if let date = result.datePublished, let y = Int(date.prefix(4)) { return y }
                    return nil
                }()
                
                return Movie(
                    id: imdbId,
                    title: name,
                    year: year,
                    poster: result.image,
                    genres: result.genre ?? []
                )
            }
        }
        
        // If all fails, return empty array
        print("Failed to decode search results, data: \(String(data: data, encoding: .utf8) ?? "invalid")")
        return []
    }
    
    private func decodeIMDBDetails(imdbID: String, data: Data) throws -> Movie? {
        struct IMDBShort: Decodable {
            let name: String?
            let image: String?
            let datePublished: String?
            let genre: [String]?
        }
        struct IMDBRoot: Decodable {
            let imdbId: String?
            let short: IMDBShort?
        }
        
        let decoder = JSONDecoder()
        let root = try decoder.decode(IMDBRoot.self, from: data)
        let short = root.short
        let title = short?.name ?? "Unknown"
        let poster = short?.image
        let year: Int? = {
            if let date = short?.datePublished, let y = Int(date.prefix(4)) { return y }
            return nil
        }()
        let genres = short?.genre ?? []
        return Movie(id: imdbID, title: title, year: year, poster: poster, genres: genres)
    }
}

final class MovieHistoryManager {
    static let shared = MovieHistoryManager()
    private init() { load() }
    
    private let key = "watchedMovies"
    private var watched: [Movie] = []
    
    func addWatched(_ movie: Movie) {
        if let idx = watched.firstIndex(where: { $0.id == movie.id }) {
            watched.remove(at: idx)
        }
        watched.insert(movie, at: 0)
        save()
    }
    
    func lastWatched() -> Movie? {
        return watched.first
    }
    
    func allWatched() -> [Movie] {
        return watched
    }
    
    func clearAll() {
        watched.removeAll()
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(watched) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([Movie].self, from: data) {
            watched = list
        }
    }
}