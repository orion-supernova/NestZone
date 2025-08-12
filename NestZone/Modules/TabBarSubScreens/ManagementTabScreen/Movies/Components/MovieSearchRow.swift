import SwiftUI

struct MovieSearchRow: View {
    let movie: Movie
    let isAdded: Bool
    let onAdd: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            MoviePosterView(movie: movie, size: CGSize(width: 40, height: 60))
            
            MovieInfoView(movie: movie)
            
            Spacer()
            
            ActionButtonView(isAdded: isAdded, onAdd: onAdd)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isAdded {
                onTap()
            }
        }
    }
}

struct MoviePosterView: View {
    let movie: Movie
    let size: CGSize
    
    var body: some View {
        if let url = movie.posterURL {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: size.width, height: size.height)
                .overlay(
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                )
        }
    }
}

struct MovieInfoView: View {
    let movie: Movie
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(movie.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            if let year = movie.year {
                Text("\(year)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            if !movie.genres.isEmpty {
                Text(movie.genres.joined(separator: ", "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

struct ActionButtonView: View {
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        if isAdded {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
                Text("Added")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            }
        } else {
            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.purple)
            }
        }
    }
}

#Preview {
    let sampleMovie = Movie(
        id: "1",
        title: "The Matrix",
        year: 1999,
        poster: nil,
        genres: ["Action", "Sci-Fi"]
    )
    
    VStack(spacing: 16) {
        MovieSearchRow(
            movie: sampleMovie,
            isAdded: false,
            onAdd: { print("Added movie") },
            onTap: { print("Tapped movie") }
        )
        
        MovieSearchRow(
            movie: sampleMovie,
            isAdded: true,
            onAdd: { print("Added movie") },
            onTap: { print("Tapped movie") }
        )
    }
    .padding()
}