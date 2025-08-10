import SwiftUI

struct MovieHistorySection: View {
    let lastWatched: Movie?
    let watched: [Movie]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let last = lastWatched {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Last Watched")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                        Spacer()
                        Text("Local History")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.secondary.opacity(0.2)))
                    }
                    
                    MovieRow(movie: last)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("All Watched")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                    Spacer()
                    if !watched.isEmpty {
                        Text("Local History")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.secondary.opacity(0.2)))
                    }
                }
                
                if !watched.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(watched) { movie in
                            MovieRow(movie: movie)
                        }
                    }
                }
            }
        }
    }
}