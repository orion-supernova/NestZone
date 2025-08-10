import SwiftUI

struct SearchMoviesForListSheet: View {
    let currentList: MovieList?
    let onAdd: (Movie) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SearchMoviesViewModel()

    var body: some View {
        NavigationView {
            VStack {
                SearchHeader(
                    query: $viewModel.query,
                    onSearch: { viewModel.search() },
                    onClear: { viewModel.clearSearch() }
                )
                
                if viewModel.isSearching {
                    SearchLoadingView()
                } else {
                    SearchResultsList(
                        results: viewModel.results,
                        addedMovies: viewModel.addedMovies,
                        onAddMovie: { movie in
                            viewModel.addMovie(movie)
                            onAdd(movie)
                        },
                        onSelectMovie: { movie in
                            viewModel.selectMovie(movie)
                        }
                    )
                }
            }
            .navigationTitle("Add Movies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Search") { viewModel.search() }
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .fullScreenCover(item: $viewModel.selectedMovie) { movie in
                MovieDetailSheet(
                    movie: movie,
                    onAdd: { movieToAdd in
                        Task { @MainActor in
                            if !viewModel.addedMovies.contains(movieToAdd.id) {
                                viewModel.addMovie(movieToAdd)
                                onAdd(movieToAdd)
                            }
                        }
                    },
                    currentList: currentList
                )
            }
        }
    }
}

struct SearchLoadingView: View {
    var body: some View {
        ProgressView("Searching movies...")
            .padding()
    }
}

#Preview {
    SearchMoviesForListSheet(currentList: nil) { movie in
        print("Added movie: \(movie.title)")
    }
}