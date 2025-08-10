import SwiftUI

struct SearchResultsList: View {
    let results: [Movie]
    let addedMovies: Set<String>
    let onAddMovie: (Movie) -> Void
    let onSelectMovie: (Movie) -> Void
    
    var body: some View {
        List {
            ForEach(results) { movie in
                MovieSearchRow(
                    movie: movie,
                    isAdded: addedMovies.contains(movie.id),
                    onAdd: {
                        onAddMovie(movie)
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    },
                    onTap: { onSelectMovie(movie) }
                )
            }
        }
    }
}