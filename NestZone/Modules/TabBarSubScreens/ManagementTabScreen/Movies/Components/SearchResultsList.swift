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

#Preview {
    let sampleMovies = [
        Movie(id: "1", title: "The Matrix", year: 1999, poster: nil, genres: ["Action", "Sci-Fi"]),
        Movie(id: "2", title: "Inception", year: 2010, poster: nil, genres: ["Action", "Thriller"]),
        Movie(id: "3", title: "The Dark Knight", year: 2008, poster: nil, genres: ["Action", "Crime"])
    ]
    
    SearchResultsList(
        results: sampleMovies,
        addedMovies: Set(["2"]),
        onAddMovie: { movie in print("Added: \(movie.title)") },
        onSelectMovie: { movie in print("Selected: \(movie.title)") }
    )
}