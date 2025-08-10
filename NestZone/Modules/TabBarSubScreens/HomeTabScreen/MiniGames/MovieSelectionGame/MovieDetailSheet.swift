import SwiftUI

struct MovieDetailSheet: View {
    let movie: Movie
    let onAdd: (Movie) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var detailedMovie: Movie?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Poster and basic info
                    HStack(alignment: .top, spacing: 16) {
                        if let url = (detailedMovie ?? movie).posterURL {
                            AsyncImage(url: url) { img in
                                img
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 180)
                                .overlay(
                                    Image(systemName: "film")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.secondary)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text((detailedMovie ?? movie).title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            if let year = (detailedMovie ?? movie).year {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.secondary)
                                    Text("\(year)")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if !(detailedMovie ?? movie).genres.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "theatermasks")
                                            .foregroundStyle(.secondary)
                                        Text("Genres")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                        ForEach((detailedMovie ?? movie).genres, id: \.self) { genre in
                                            Text(genre)
                                                .font(.system(size: 12, weight: .medium))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(.blue.opacity(0.2)))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // IMDb ID
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        Text("IMDb ID: \((detailedMovie ?? movie).id)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading details...")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAdd(detailedMovie ?? movie)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add to List")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                    }
                }
            }
            .onAppear {
                Task {
                    if let detailed = await fetchMovieDetails(imdbID: movie.id) {
                        await MainActor.run {
                            self.detailedMovie = detailed
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run {
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    private func fetchMovieDetails(imdbID: String) async -> Movie? {
        guard let url = URL(string: "https://imdb.iamidiotareyoutoo.com/search?tt=\(imdbID)") else { 
            return nil 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try decodeMovieDetails(imdbID: imdbID, data: data)
        } catch {
            print("Failed to fetch movie details for \(imdbID): \(error)")
            return nil
        }
    }
    
    private func decodeMovieDetails(imdbID: String, data: Data) throws -> Movie? {
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

struct MovieDetailInfoSheet: View {
    let movie: Movie
    @Environment(\.dismiss) private var dismiss
    @State private var detailedMovie: Movie?
    @State private var isLoading = true
    @State private var hasError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Large poster
                    if let url = (detailedMovie ?? movie).posterURL {
                        AsyncImage(url: url) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(1.5)
                                )
                        }
                        .frame(maxWidth: 200, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Rectangle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                            .aspectRatio(2/3, contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.7))
                            )
                    }
                    
                    // Movie details
                    VStack(spacing: 16) {
                        Text((detailedMovie ?? movie).title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        
                        if let year = (detailedMovie ?? movie).year {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.secondary)
                                Text("\(year)")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Show genres if available
                        let currentGenres = (detailedMovie ?? movie).genres
                        if !currentGenres.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "theatermasks")
                                        .foregroundStyle(.secondary)
                                    Text("Genres")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                    ForEach(currentGenres, id: \.self) { genre in
                                        Text(genre)
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(.blue.opacity(0.2)))
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                        
                        // IMDb ID
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                            Text("IMDb ID: \((detailedMovie ?? movie).id)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading additional details...")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if hasError {
                            Text("Could not load additional details")
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                print("🎬 Opening detail for movie: \(movie.title) (\(movie.id))")
                print("🎬 Current genres: \(movie.genres)")
                
                Task {
                    if let detailed = await fetchMovieDetails(imdbID: movie.id) {
                        print("✅ Got detailed movie: \(detailed.title), genres: \(detailed.genres)")
                        await MainActor.run {
                            self.detailedMovie = detailed
                            self.isLoading = false
                        }
                    } else {
                        print("❌ Failed to get movie details for \(movie.id)")
                        await MainActor.run {
                            self.isLoading = false
                            self.hasError = true
                        }
                    }
                }
            }
        }
    }
    
    private func fetchMovieDetails(imdbID: String) async -> Movie? {
        guard let url = URL(string: "https://imdb.iamidiotareyoutoo.com/search?tt=\(imdbID)") else { 
            return nil 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try decodeMovieDetails(imdbID: imdbID, data: data)
        } catch {
            print("Failed to fetch movie details for \(imdbID): \(error)")
            return nil
        }
    }
    
    private func decodeMovieDetails(imdbID: String, data: Data) throws -> Movie? {
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