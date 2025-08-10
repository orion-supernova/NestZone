import SwiftUI

struct SimpleMovieDetailSheet: View {
    let movie: Movie
    
    @Environment(\.dismiss) private var dismiss
    @State private var detailedMovie: Movie?
    @State private var extras: MovieExtras?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Poster
                    if let url = (detailedMovie ?? movie).posterURL {
                        AsyncImage(url: url) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(ProgressView().scaleEffect(1.2))
                        }
                        .frame(maxWidth: 220, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Rectangle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                            .aspectRatio(2/3, contentMode: .fit)
                            .frame(maxWidth: 220, maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.7))
                            )
                    }
                    
                    // Title and Year
                    VStack(spacing: 8) {
                        Text((detailedMovie ?? movie).title)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        if let year = (detailedMovie ?? movie).year {
                            Text("\(year)")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        
                        if let minutes = extras?.runtimeMinutes {
                            Text("\(minutes) min")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Genres
                    let currentGenres = (detailedMovie ?? movie).genres
                    if !currentGenres.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(currentGenres, id: \.self) { genre in
                                Text(genre)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.blue.opacity(0.2)))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Overview
                    if isLoading {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Loading details...")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    } else if let plot = extras?.plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.system(size: 18, weight: .bold))
                            Text(plot)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Cast
                    if let cast = extras?.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cast")
                                .font(.system(size: 18, weight: .bold))
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(cast.prefix(12), id: \.self) { name in
                                        Text(name)
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(.purple.opacity(0.15)))
                                            .foregroundStyle(.purple)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    async let det = MovieAPI.shared.getDetails(imdbID: movie.id)
                    async let ext = MovieAPI.shared.getExtras(imdbID: movie.id)
                    let d = await det
                    let e = await ext
                    await MainActor.run {
                        self.detailedMovie = d ?? movie
                        self.extras = e
                        self.isLoading = false
                    }
                }
            }
        }
    }
}