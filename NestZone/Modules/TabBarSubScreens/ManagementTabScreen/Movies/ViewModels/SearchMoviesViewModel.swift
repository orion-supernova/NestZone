import Foundation
import SwiftUI

@MainActor
class SearchMoviesViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Movie] = []
    @Published var isSearching = false
    @Published var selectedMovie: Movie?
    @Published var showingMovieDetail = false
    @Published var addedMovies: Set<String> = []
    
    func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        
        isSearching = true
        Task {
            let found = await MovieAPI.shared.searchMovies(query: q)
            await MainActor.run {
                self.results = found
                self.isSearching = false
                self.addedMovies.removeAll() // Reset added state for new search
            }
        }
    }
    
    func clearSearch() {
        query = ""
        results = []
    }
    
    func addMovie(_ movie: Movie) {
        addedMovies.insert(movie.id)
    }
    
    func selectMovie(_ movie: Movie) {
        selectedMovie = movie
        showingMovieDetail = true
    }
}