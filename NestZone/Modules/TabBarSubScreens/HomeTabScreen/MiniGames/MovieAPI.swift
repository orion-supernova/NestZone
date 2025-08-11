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
        // TMDb poster URLs need the base URL
        if poster.hasPrefix("http") {
            return URL(string: poster)
        } else {
            return URL(string: "https://image.tmdb.org/t/p/w500\(poster)")
        }
    }
}

struct MovieExtras: Codable, Hashable {
    var plot: String?
    var cast: [CastMember]
    var directors: [String]
    var writers: [String]
    var runtimeMinutes: Int?
    var rating: Double?
    var voteCount: Int?
    var budget: Int?
    var revenue: Int?
    var releaseDate: String?
    var originalLanguage: String?
    var productionCompanies: [String]
    var keywords: [String]
    var backdropPath: String?
    
    struct CastMember: Codable, Hashable {
        let name: String
        let character: String?
        let profilePath: String?
        
        var profileURL: URL? {
            guard let profilePath else { return nil }
            return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
        }
    }
    
    init(plot: String? = nil, cast: [CastMember] = [], directors: [String] = [], writers: [String] = [], runtimeMinutes: Int? = nil, rating: Double? = nil, voteCount: Int? = nil, budget: Int? = nil, revenue: Int? = nil, releaseDate: String? = nil, originalLanguage: String? = nil, productionCompanies: [String] = [], keywords: [String] = [], backdropPath: String? = nil) {
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
    
    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(backdropPath)")
    }
}

final class MovieAPI {
    static let shared = MovieAPI()
    private init() {}
    
    // TMDb API KEY
    private let apiKey = "1b4bd86ca9d5443c16277d701d971c04"
    private let baseURL = "https://api.themoviedb.org/3"
    
    // Thread-safe cache
    private let cacheQueue = DispatchQueue(label: "MovieAPI.cache", attributes: .concurrent)
    private var _cache: [String: Movie] = [:]
    
    private var cache: [String: Movie] {
        get {
            return cacheQueue.sync { _cache }
        }
        set {
            cacheQueue.async(flags: .barrier) { self._cache = newValue }
        }
    }
    
    // TMDb Genre IDs
    private let genreMap: [String: Int] = [
        "action": 28,
        "adventure": 12,
        "animation": 16,
        "comedy": 35,
        "crime": 80,
        "documentary": 99,
        "drama": 18,
        "family": 10751,
        "fantasy": 14,
        "history": 36,
        "horror": 27,
        "music": 10402,
        "mystery": 9648,
        "romance": 10749,
        "sci-fi": 878,
        "thriller": 53,
        "war": 10752,
        "western": 37
    ]
    
    // MARK: - Public API
    
    func searchMovies(query: String, includeAdult: Bool = false) async -> [Movie] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !q.isEmpty else {
            return await getPopularMovies(includeAdult: includeAdult)
        }
        
        return await searchMoviesFromTMDb(query: q, includeAdult: includeAdult)
    }
    
    func searchByGenre(genre: String, includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Searching by genre: \(genre), includeAdult: \(includeAdult)")
        
        guard let genreId = genreMap[genre.lowercased()] else {
            print("🎬 MovieAPI: Unknown genre \(genre), falling back to search")
            return await searchMovies(query: genre, includeAdult: includeAdult)
        }
        
        // Get multiple pages for better variety
        var allMovies: [Movie] = []
        let maxPages = 3
        
        for page in 1...maxPages {
            guard let url = URL(string: "\(baseURL)/discover/movie?api_key=\(apiKey)&with_genres=\(genreId)&page=\(page)&include_adult=\(includeAdult)&sort_by=popularity.desc") else {
                continue
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let movies = try decodeTMDbSearchResults(data: data)
                print("🎬 MovieAPI: Found \(movies.count) movies on page \(page)")
                
                for movie in movies {
                    if !allMovies.contains(where: { $0.id == movie.id }) {
                        allMovies.append(movie)
                    }
                }
                
                // Cache the movies
                for movie in movies {
                    cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
                }
                
            } catch {
                print("🎬 MovieAPI: Failed to fetch page \(page) for genre \(genre): \(error)")
            }
        }
        
        print("🎬 MovieAPI: Total unique movies found: \(allMovies.count)")
        let shuffled = Array(allMovies.shuffled().prefix(20))
        print("🎬 MovieAPI: Returning \(shuffled.count) movies")
        return shuffled
    }
    
    func searchByActor(actorName: String, includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Searching by actor: \(actorName)")
        
        // First, find the actor ID
        guard let actorId = await findPersonId(name: actorName) else {
            print("🎬 MovieAPI: Actor not found: \(actorName)")
            return []
        }
        
        // Then get movies with this actor
        return await getMoviesByPerson(personId: actorId, includeAdult: includeAdult)
    }
    
    func searchByDirector(directorName: String, includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Searching by director: \(directorName)")
        
        // First, find the director ID
        guard let directorId = await findPersonId(name: directorName) else {
            print("🎬 MovieAPI: Director not found: \(directorName)")
            return []
        }
        
        // Then get movies directed by this person
        return await getMoviesByDirector(directorId: directorId, includeAdult: includeAdult)
    }
    
    func searchByYear(year: Int, includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Searching by year: \(year)")
        
        var allMovies: [Movie] = []
        let maxPages = 3
        
        for page in 1...maxPages {
            guard let url = URL(string: "\(baseURL)/discover/movie?api_key=\(apiKey)&primary_release_year=\(year)&page=\(page)&include_adult=\(includeAdult)&sort_by=popularity.desc") else {
                continue
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let movies = try decodeTMDbSearchResults(data: data)
                
                for movie in movies {
                    if !allMovies.contains(where: { $0.id == movie.id }) {
                        allMovies.append(movie)
                    }
                }
                
                // Cache the movies
                for movie in movies {
                    cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
                }
                
            } catch {
                print("🎬 MovieAPI: Failed to fetch page \(page) for year \(year): \(error)")
            }
        }
        
        let shuffled = Array(allMovies.shuffled().prefix(20))
        print("🎬 MovieAPI: Returning \(shuffled.count) movies for year \(year)")
        return shuffled
    }
    
    func searchByDecade(decade: Int, includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Searching by decade: \(decade)s")
        
        let startYear = decade
        let endYear = decade + 9
        
        var allMovies: [Movie] = []
        let maxPages = 3
        
        for page in 1...maxPages {
            guard let url = URL(string: "\(baseURL)/discover/movie?api_key=\(apiKey)&primary_release_date.gte=\(startYear)-01-01&primary_release_date.lte=\(endYear)-12-31&page=\(page)&include_adult=\(includeAdult)&sort_by=popularity.desc") else {
                continue
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let movies = try decodeTMDbSearchResults(data: data)
                
                for movie in movies {
                    if !allMovies.contains(where: { $0.id == movie.id }) {
                        allMovies.append(movie)
                    }
                }
                
                // Cache the movies
                for movie in movies {
                    cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
                }
                
            } catch {
                print("🎬 MovieAPI: Failed to fetch page \(page) for decade \(decade)s: \(error)")
            }
        }
        
        let shuffled = Array(allMovies.shuffled().prefix(20))
        print("🎬 MovieAPI: Returning \(shuffled.count) movies for decade \(decade)s")
        return shuffled
    }
    
    // MARK: - TMDB Lists
    
    func getNowPlayingMovies(includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Getting now playing movies")
        return await getMoviesList(endpoint: "now_playing", includeAdult: includeAdult)
    }
    
    func getPopularMovies(includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Getting popular movies")
        return await getMoviesList(endpoint: "popular", includeAdult: includeAdult)
    }
    
    func getTopRatedMovies(includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Getting top rated movies")
        return await getMoviesList(endpoint: "top_rated", includeAdult: includeAdult)
    }
    
    func getUpcomingMovies(includeAdult: Bool = false) async -> [Movie] {
        print("🎬 MovieAPI: Getting upcoming movies")
        return await getMoviesList(endpoint: "upcoming", includeAdult: includeAdult)
    }
    
    private func getMoviesList(endpoint: String, includeAdult: Bool = false) async -> [Movie] {
        var allMovies: [Movie] = []
        let maxPages = 3
        
        for page in 1...maxPages {
            guard let url = URL(string: "\(baseURL)/movie/\(endpoint)?api_key=\(apiKey)&page=\(page)&include_adult=\(includeAdult)") else {
                continue
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let movies = try decodeTMDbSearchResults(data: data)
                print("🎬 MovieAPI: Found \(movies.count) \(endpoint) movies on page \(page)")
                
                for movie in movies {
                    if !allMovies.contains(where: { $0.id == movie.id }) {
                        allMovies.append(movie)
                    }
                }
                
                // Cache the movies
                for movie in movies {
                    cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
                }
                
            } catch {
                print("🎬 MovieAPI: Failed to fetch page \(page) for \(endpoint): \(error)")
            }
        }
        
        let shuffled = Array(allMovies.shuffled().prefix(20))
        print("🎬 MovieAPI: Returning \(shuffled.count) \(endpoint) movies")
        return shuffled
    }
    
    // MARK: - Helper Methods
    
    private func searchMoviesFromTMDb(query: String, includeAdult: Bool = false) async -> [Movie] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedQuery)&include_adult=\(includeAdult)") else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let movies = try decodeTMDbSearchResults(data: data)
            for movie in movies {
                cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
            }
            return movies
        } catch {
            print("TMDb search failed for '\(query)': \(error)")
            return []
        }
    }
    
    private func findPersonId(name: String) async -> Int? {
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/person?api_key=\(apiKey)&query=\(encodedName)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            struct PersonSearchResponse: Decodable {
                let results: [Person]
                
                struct Person: Decodable {
                    let id: Int
                    let name: String
                }
            }
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(PersonSearchResponse.self, from: data)
            return response.results.first?.id
        } catch {
            print("🎬 MovieAPI: Failed to find person \(name): \(error)")
            return nil
        }
    }
    
    private func getMoviesByPerson(personId: Int, includeAdult: Bool = false) async -> [Movie] {
        guard let url = URL(string: "\(baseURL)/discover/movie?api_key=\(apiKey)&with_cast=\(personId)&include_adult=\(includeAdult)&sort_by=popularity.desc") else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let movies = try decodeTMDbSearchResults(data: data)
            
            // Cache the movies
            for movie in movies {
                cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
            }
            
            let shuffled = Array(movies.shuffled().prefix(20))
            return shuffled
        } catch {
            print("🎬 MovieAPI: Failed to get movies for person \(personId): \(error)")
            return []
        }
    }
    
    private func getMoviesByDirector(directorId: Int, includeAdult: Bool = false) async -> [Movie] {
        guard let url = URL(string: "\(baseURL)/discover/movie?api_key=\(apiKey)&with_crew=\(directorId)&include_adult=\(includeAdult)&sort_by=popularity.desc") else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let movies = try decodeTMDbSearchResults(data: data)
            
            // Cache the movies
            for movie in movies {
                cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
            }
            
            let shuffled = Array(movies.shuffled().prefix(20))
            return shuffled
        } catch {
            print("🎬 MovieAPI: Failed to get movies for director \(directorId): \(error)")
            return []
        }
    }
    
    func getDetails(imdbID: String) async -> Movie? {
        print("🎬 MovieAPI: Getting details for ID: \(imdbID)")
        
        if let cached = cacheQueue.sync(execute: { _cache[imdbID] }) {
            print("🎬 MovieAPI: Found cached movie: \(cached.title)")
            return cached
        }
        
        // If it's a TMDb ID (numeric), use it directly
        if let tmdbId = Int(imdbID) {
            print("🎬 MovieAPI: Treating as TMDb ID: \(tmdbId)")
            return await getMovieDetails(tmdbId: tmdbId)
        }
        
        // If it's an IMDb ID (starts with tt), search for it
        if imdbID.hasPrefix("tt") {
            print("🎬 MovieAPI: Treating as IMDb ID: \(imdbID)")
            return await findMovieByImdbId(imdbID)
        }
        
        print("🎬 MovieAPI: Unknown ID format: \(imdbID)")
        return nil
    }
    
    private func getMovieDetails(tmdbId: Int) async -> Movie? {
        guard let url = URL(string: "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)&append_to_response=genres") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let movie = try decodeTMDbMovieDetails(data: data) {
                print("🎬 MovieAPI: Got TMDb details for \(movie.title) (ID: \(movie.id))")
                cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
                // IMPORTANT: Also cache with the original TMDb ID string format
                cacheQueue.async(flags: .barrier) { self._cache[String(tmdbId)] = movie }
                return movie
            }
        } catch {
            print("Failed to fetch details for TMDb ID \(tmdbId): \(error)")
        }
        return nil
    }
    
    private func findMovieByImdbId(_ imdbId: String) async -> Movie? {
        guard let url = URL(string: "\(baseURL)/find/\(imdbId)?api_key=\(apiKey)&external_source=imdb_id") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let movie = try decodeTMDbFindResults(data: data) {
                cacheQueue.async(flags: .barrier) { self._cache[movie.id] = movie }
                return movie
            }
        } catch {
            print("Failed to find movie by IMDb ID \(imdbId): \(error)")
        }
        return nil
    }
    
    func getExtras(imdbID: String) async -> MovieExtras? {
        // Convert ID to TMDb ID if needed
        let tmdbId: Int
        if let id = Int(imdbID) {
            tmdbId = id
        } else if imdbID.hasPrefix("tt") {
            // Find TMDb ID from IMDb ID first
            guard let movie = await findMovieByImdbId(imdbID), let id = Int(movie.id) else {
                return nil
            }
            tmdbId = id
        } else {
            return nil
        }
        
        guard let url = URL(string: "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)&append_to_response=credits,keywords") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try decodeTMDbExtras(data: data)
        } catch {
            print("Failed to fetch extras for TMDb ID \(tmdbId): \(error)")
            return nil
        }
    }
    
    // MARK: - Decoding Helpers
    
    private func decodeTMDbSearchResults(data: Data) throws -> [Movie] {
        struct TMDbSearchResponse: Decodable {
            let results: [TMDbMovie]
        }
        
        struct TMDbMovie: Decodable {
            let id: Int
            let title: String
            let release_date: String?
            let poster_path: String?
            let genre_ids: [Int]?
            let overview: String?
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(TMDbSearchResponse.self, from: data)
        
        return response.results.compactMap { tmdbMovie in
            let year: Int? = {
                if let releaseDate = tmdbMovie.release_date, !releaseDate.isEmpty {
                    return Int(releaseDate.prefix(4))
                }
                return nil
            }()
            
            // Convert genre IDs to genre names
            let genreNames = tmdbMovie.genre_ids?.compactMap { genreId in
                return genreMap.first(where: { $0.value == genreId })?.key.capitalized
            } ?? []
            
            return Movie(
                id: String(tmdbMovie.id),
                title: tmdbMovie.title,
                year: year,
                poster: tmdbMovie.poster_path,
                genres: genreNames
            )
        }
    }
    
    private func decodeTMDbMovieDetails(data: Data) throws -> Movie? {
        struct TMDbMovieDetails: Decodable {
            let id: Int
            let title: String
            let release_date: String?
            let poster_path: String?
            let genres: [TMDbGenre]?
            let overview: String?
            
            struct TMDbGenre: Decodable {
                let name: String
            }
        }
        
        let decoder = JSONDecoder()
        let movieDetails = try decoder.decode(TMDbMovieDetails.self, from: data)
        
        let year: Int? = {
            if let releaseDate = movieDetails.release_date, !releaseDate.isEmpty {
                return Int(releaseDate.prefix(4))
            }
            return nil
        }()
        
        let genreNames = movieDetails.genres?.map { $0.name } ?? []
        
        return Movie(
            id: String(movieDetails.id),
            title: movieDetails.title,
            year: year,
            poster: movieDetails.poster_path,
            genres: genreNames
        )
    }
    
    private func decodeTMDbFindResults(data: Data) throws -> Movie? {
        struct TMDbFindResponse: Decodable {
            let movie_results: [TMDbMovie]
            
            struct TMDbMovie: Decodable {
                let id: Int
                let title: String
                let release_date: String?
                let poster_path: String?
                let genre_ids: [Int]?
            }
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(TMDbFindResponse.self, from: data)
        
        guard let tmdbMovie = response.movie_results.first else {
            return nil
        }
        
        let year: Int? = {
            if let releaseDate = tmdbMovie.release_date, !releaseDate.isEmpty {
                return Int(releaseDate.prefix(4))
            }
            return nil
        }()
        
        let genreNames = tmdbMovie.genre_ids?.compactMap { genreId in
            return genreMap.first(where: { $0.value == genreId })?.key.capitalized
        } ?? []
        
        return Movie(
            id: String(tmdbMovie.id),
            title: tmdbMovie.title,
            year: year,
            poster: tmdbMovie.poster_path,
            genres: genreNames
        )
    }
    
    private func decodeTMDbExtras(data: Data) -> MovieExtras? {
        struct TMDbMovieExtras: Decodable {
            let overview: String?
            let runtime: Int?
            let vote_average: Double?
            let vote_count: Int?
            let budget: Int?
            let revenue: Int?
            let release_date: String?
            let original_language: String?
            let backdrop_path: String?
            let production_companies: [ProductionCompany]?
            let credits: Credits?
            let keywords: Keywords?
            
            struct ProductionCompany: Decodable {
                let name: String
            }
            
            struct Credits: Decodable {
                let cast: [Cast]?
                let crew: [Crew]?
                
                struct Cast: Decodable {
                    let name: String
                    let character: String?
                    let profile_path: String?
                }
                
                struct Crew: Decodable {
                    let name: String
                    let job: String
                }
            }
            
            struct Keywords: Decodable {
                let keywords: [Keyword]?
                
                struct Keyword: Decodable {
                    let name: String
                }
            }
        }
        
        do {
            let decoder = JSONDecoder()
            let details = try decoder.decode(TMDbMovieExtras.self, from: data)
            
            // Extract cast members
            let castMembers = details.credits?.cast?.prefix(20).map { castMember in
                MovieExtras.CastMember(
                    name: castMember.name,
                    character: castMember.character,
                    profilePath: castMember.profile_path
                )
            } ?? []
            
            // Extract directors
            let directors = details.credits?.crew?.filter { $0.job == "Director" }.map { $0.name } ?? []
            
            // Extract writers
            let writers = details.credits?.crew?.filter { crew in
                ["Writer", "Screenplay", "Story", "Author"].contains(crew.job)
            }.map { $0.name } ?? []
            
            // Extract production companies
            let companies = details.production_companies?.map { $0.name } ?? []
            
            // Extract keywords
            let keywordList = details.keywords?.keywords?.map { $0.name } ?? []
            
            return MovieExtras(
                plot: details.overview,
                cast: Array(castMembers),
                directors: directors,
                writers: writers,
                runtimeMinutes: details.runtime,
                rating: details.vote_average,
                voteCount: details.vote_count,
                budget: details.budget == 0 ? nil : details.budget,
                revenue: details.revenue == 0 ? nil : details.revenue,
                releaseDate: details.release_date,
                originalLanguage: details.original_language,
                productionCompanies: companies,
                keywords: keywordList,
                backdropPath: details.backdrop_path
            )
        } catch {
            print("Failed to decode TMDb extras: \(error)")
            return nil
        }
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