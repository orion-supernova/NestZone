import SwiftUI

struct MatchesSection: View {
    let currentMatches: [Movie]
    let onSelectMatch: (Movie) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular Choices")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                Spacer()
                Text("\(currentMatches.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.orange.opacity(0.2)))
            }
            
            Text("Movies getting positive votes from house members")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, -8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(currentMatches) { movie in
                        MatchMovieCard(movie: movie) {
                            onSelectMatch(movie)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct MatchMovieCard: View {
    let movie: Movie
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let url = movie.posterURL {
                    AsyncImage(url: url) { img in
                        img
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 120)
                }
                
                Text(movie.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    )
            )
        }
    }
}

#Preview {
    let sampleMovies = [
        Movie(id: "1", title: "The Matrix", year: 1999, poster: nil, genres: ["Action"]),
        Movie(id: "2", title: "Inception", year: 2010, poster: nil, genres: ["Thriller"]),
        Movie(id: "3", title: "The Dark Knight", year: 2008, poster: nil, genres: ["Action"])
    ]
    
    MatchesSection(
        currentMatches: sampleMovies,
        onSelectMatch: { movie in print("Selected: \(movie.title)") }
    )
    .padding()
}