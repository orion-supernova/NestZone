import SwiftUI

struct MovieRow: View {
    let movie: Movie
    
    var body: some View {
        HStack(spacing: 12) {
            if let url = movie.posterURL {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 64)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    if let year = movie.year {
                        Text("\(year)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    if !movie.genres.isEmpty {
                        Text(movie.genres.prefix(2).joined(separator: " • "))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
}