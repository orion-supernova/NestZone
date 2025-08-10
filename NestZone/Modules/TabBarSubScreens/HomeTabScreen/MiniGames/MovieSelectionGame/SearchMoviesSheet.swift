import SwiftUI

struct SearchMoviesSheet: View {
    var onAdd: (Movie) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Movie] = []
    @State private var isSearching = false
    @State private var selectedMovie: Movie?
    @State private var showingMovieDetail = false
    @State private var addedMovies: Set<String> = []
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search movies or paste IMDb ID (e.g. tt2250912)...", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onSubmit { search() }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                if isSearching {
                    ProgressView().padding()
                }
                
                List {
                    ForEach(results) { movie in
                        HStack(spacing: 12) {
                            if let url = movie.posterURL {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 36, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 36, height: 52)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(movie.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                if let year = movie.year {
                                    Text("\(year)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if addedMovies.contains(movie.id) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 16))
                                    Text("Added")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !addedMovies.contains(movie.id) {
                                selectedMovie = movie
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingMovieDetail = true
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !addedMovies.contains(movie.id) {
                                Button {
                                    addedMovies.insert(movie.id)
                                    onAdd(movie)
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                } label: {
                                    Label("Add to List", systemImage: "plus.circle.fill")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search Movies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Search") { search() }.font(.system(size: 14, weight: .bold))
                }
            }
            .sheet(isPresented: $showingMovieDetail) {
                selectedMovie = nil
            } content: {
                if let movie = selectedMovie {
                    MovieDetailSheet(movie: movie) { movieToAdd in
                        Task { @MainActor in
                            if !addedMovies.contains(movieToAdd.id) {
                                addedMovies.insert(movieToAdd.id)
                                onAdd(movieToAdd)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true
        Task {
            let found = await MovieAPI.shared.searchMovies(query: q)
            await MainActor.run {
                self.results = found
                self.isSearching = false
                self.addedMovies.removeAll()
            }
        }
    }
}