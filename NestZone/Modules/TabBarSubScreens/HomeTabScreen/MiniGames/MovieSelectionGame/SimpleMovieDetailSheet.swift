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
                VStack(spacing: 0) {
                    // Hero Section with Backdrop
                    ZStack(alignment: .bottom) {
                        // Backdrop Image
                        if let backdropURL = extras?.backdropURL {
                            AsyncImage(url: backdropURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            .frame(height: 220)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        } else {
                            Rectangle()
                                .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 220)
                        }
                        
                        // Movie Info Overlay
                        HStack(alignment: .bottom, spacing: 16) {
                            // Poster
                            if let url = (detailedMovie ?? movie).posterURL {
                                AsyncImage(url: url) { img in
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(ProgressView().scaleEffect(0.8))
                                }
                                .frame(width: 100, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                            }
                            
                            // Title and Basic Info
                            VStack(alignment: .leading, spacing: 6) {
                                Text((detailedMovie ?? movie).title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black, radius: 2)
                                
                                HStack(spacing: 12) {
                                    if let year = (detailedMovie ?? movie).year {
                                        Text("\(year)")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    
                                    if let minutes = extras?.runtimeMinutes {
                                        Text(LocalizationManager.movieDetailsMinutes(minutes))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    
                                    if let rating = extras?.rating {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                                .font(.system(size: 12))
                                            Text(String(format: "%.1f", rating))
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                    }
                                }
                                
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    
                    VStack(spacing: 24) {
                        // Genres
                        let currentGenres = (detailedMovie ?? movie).genres
                        if !currentGenres.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(LocalizationManager.movieDetailsGenres)
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                
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
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Overview
                        if let plot = extras?.plot, !plot.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(LocalizationManager.movieDetailsOverview)
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                Text(plot)
                                    .font(.system(size: 15))
                                    .lineSpacing(2)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Statistics
                        if extras?.rating != nil || extras?.voteCount != nil || extras?.budget != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(LocalizationManager.movieDetailsStatistics)
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    if let rating = extras?.rating {
                                        StatCard(title: LocalizationManager.movieDetailsRating, value: String(format: "%.1f/10", rating), icon: "star.fill", color: .yellow)
                                    }
                                    
                                    if let voteCount = extras?.voteCount {
                                        StatCard(title: LocalizationManager.movieDetailsVotes, value: formatNumber(voteCount), icon: "person.2.fill", color: .blue)
                                    }
                                    
                                    if let budget = extras?.budget {
                                        StatCard(title: LocalizationManager.movieDetailsBudget, value: "$\(formatNumber(budget))", icon: "dollarsign.circle.fill", color: .green)
                                    }
                                    
                                    if let revenue = extras?.revenue {
                                        StatCard(title: LocalizationManager.movieDetailsRevenue, value: "$\(formatNumber(revenue))", icon: "chart.line.uptrend.xyaxis", color: .orange)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Cast
                        if let cast = extras?.cast, !cast.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(LocalizationManager.movieDetailsCast)
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(cast.prefix(10), id: \.name) { castMember in
                                            CastMemberCard(castMember: castMember)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Crew
                        if let directors = extras?.directors, !directors.isEmpty,
                           let writers = extras?.writers, !writers.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(LocalizationManager.movieDetailsCrew)
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if !directors.isEmpty {
                                        CrewSection(title: LocalizationManager.movieDetailsDirectors, names: directors)
                                    }
                                    
                                    if !writers.isEmpty {
                                        CrewSection(title: LocalizationManager.movieDetailsWriters, names: writers)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Production
                        if let companies = extras?.productionCompanies, !companies.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(LocalizationManager.movieDetailsProduction)
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                                    ForEach(companies.prefix(6), id: \.self) { company in
                                        Text(company)
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.2)))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Keywords
                        if let keywords = extras?.keywords, !keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(LocalizationManager.movieDetailsKeywords)
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                    ForEach(keywords.prefix(12), id: \.self) { keyword in
                                        Text(keyword)
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(.purple.opacity(0.15)))
                                            .foregroundStyle(.purple)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text(LocalizationManager.movieDetailsLoadingDetails)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(LocalizationManager.movieDetailsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizationManager.commonDone) { dismiss() }
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
    
    private func formatNumber(_ number: Int) -> String {
        let thousand = 1000.0
        let million = thousand * 1000
        let billion = million * 1000
        let num = Double(number)
        
        if num >= billion {
            return String(format: "%.1fB", num / billion)
        } else if num >= million {
            return String(format: "%.1fM", num / million)
        } else if num >= thousand {
            return String(format: "%.1fK", num / thousand)
        } else {
            return String(format: "%.0f", num)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
}

struct CastMemberCard: View {
    let castMember: MovieExtras.CastMember
    
    var body: some View {
        VStack(spacing: 8) {
            if let profileURL = castMember.profileURL {
                AsyncImage(url: profileURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    )
            }
            
            VStack(spacing: 2) {
                Text(castMember.name)
                    .font(.system(size: 12, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if let character = castMember.character {
                    Text(character)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .frame(width: 80)
    }
}

struct CrewSection: View {
    let title: String
    let names: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text(names.joined(separator: ", "))
                .font(.system(size: 15))
                .foregroundStyle(.primary)
        }
    }
}