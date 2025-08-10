import SwiftUI

struct MovieListDetailView: View {
    let movieList: MovieList
    @ObservedObject var viewModel: MovieListsViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    private enum ActiveSheet: Identifiable {
        case addMovies
        case movieDetail(Movie)
        var id: String {
            switch self {
            case .addMovies: return "addMovies"
            case .movieDetail(let movie): return "detail_\(movie.id)"
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    @State private var showingDeleteAlert = false
    @State private var movies: [StoredMovie] = []
    @State private var isLoadingMovies = false
    
    private var theme: ThemeColors {
        selectedTheme.colors(for: colorScheme)
    }
    
    private var listColors: [Color] {
        switch movieList.type {
        case .wishlist: return [.red, .pink]
        case .watched: return [.green, .mint]
        case .custom: return [.purple, .pink]
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                RadialGradient(
                    colors: [
                        theme.background,
                        listColors[0].opacity(0.05),
                        listColors[1].opacity(0.03)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerView
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                        
                        if isLoadingMovies {
                            ProgressView("Loading movies...")
                                .padding()
                        } else if movies.isEmpty {
                            emptyStateView
                                .padding(.horizontal, 24)
                        } else {
                            moviesGrid
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(movieList.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(theme.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            activeSheet = .addMovies
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(LinearGradient(colors: listColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        
                        if movieList.type == .custom {
                            Menu {
                                Button("Delete List", role: .destructive) {
                                    showingDeleteAlert = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await loadMovies()
                }
            }
        }
        .fullScreenCover(item: $activeSheet) { route in
            switch route {
            case .addMovies:
                SearchMoviesForListSheet { movie in
                    Task {
                        await viewModel.addMovieToList(movie, listId: movieList.id)
                        await loadMovies()
                    }
                }
            case .movieDetail(let movie):
                MovieDetailInfoSheet(movie: movie)
            }
        }
        .alert("Delete List", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteCustomList(movieList)
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete \"\(movieList.name)\" and cannot be undone.")
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: listColors.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: getListIcon())
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: listColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(movies.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: listColors, startPoint: .leading, endPoint: .trailing))
                    
                    Text("movies")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(movieList.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.text, listColors[0]],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                if let description = movieList.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(LinearGradient(colors: listColors.map { $0.opacity(0.6) }, startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(spacing: 8) {
                Text("No Movies Yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Start building your \(movieList.name.lowercased()) by adding some movies")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                activeSheet = .addMovies
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Movies")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: listColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: listColors.map { $0.opacity(0.3) }, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
            )
        )
    }
    
    private var moviesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(minimum: 100), spacing: 16),
            GridItem(.flexible(minimum: 100), spacing: 16),
            GridItem(.flexible(minimum: 100), spacing: 16)
        ], spacing: 20) {
            ForEach(movies) { storedMovie in
                MovieCardView(storedMovie: storedMovie, listColors: listColors) {
                    activeSheet = .movieDetail(storedMovie.toMovie())
                } onRemove: {
                    Task {
                        await viewModel.removeMovieFromList(movieId: storedMovie.imdbId, listId: movieList.id)
                        await loadMovies()
                    }
                }
            }
        }
    }
    
    private func loadMovies() async {
        isLoadingMovies = true
        movies = await viewModel.getMoviesForList(movieList)
        isLoadingMovies = false
    }
    
    private func getListIcon() -> String {
        switch movieList.type {
        case .wishlist: return "heart.fill"
        case .watched: return "checkmark.seal.fill"
        case .custom: return "rectangle.stack.fill"
        }
    }
}

struct MovieCardView: View {
    let storedMovie: StoredMovie
    let listColors: [Color]
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var showingRemoveAlert = false
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    if let posterURL = storedMovie.poster, let url = URL(string: posterURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                        }
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.secondary)
                            )
                    }
                    
                    VStack(spacing: 4) {
                        Text(storedMovie.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        if let year = storedMovie.year {
                            Text("\(year)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .contextMenu {
                Button("Remove from List", role: .destructive) {
                    showingRemoveAlert = true
                }
            }
        }
        .alert("Remove Movie", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { onRemove() }
        } message: {
            Text("Remove \"\(storedMovie.title)\" from this list?")
        }
    }
}

#Preview {
    let sampleList = MovieList(
        id: "1",
        homeId: "home1",
        name: "Wishlist",
        description: "Movies I want to watch",
        type: .wishlist,
        isPreset: true,
        created: "",
        updated: ""
    )
    
    MovieListDetailView(movieList: sampleList, viewModel: MovieListsViewModel())
}