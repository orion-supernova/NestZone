import SwiftUI

struct PollSummarySheet: View {
    let summary: PollSummary
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("🏆 Poll Complete! 🏆")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                        
                        Text("Here's how your house voted")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Stats
                    HStack(spacing: 20) {
                        StatBox(
                            title: "Total Votes",
                            value: "\(summary.totalVotes)",
                            icon: "hand.thumbsup.fill",
                            color: .blue
                        )
                        
                        StatBox(
                            title: "Participants",
                            value: "\(summary.participants)",
                            icon: "person.2.fill",
                            color: .green
                        )
                        
                        StatBox(
                            title: "Matches",
                            value: "\(summary.matches.count)",
                            icon: "heart.fill",
                            color: .red
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Winner (if selected)
                    if let winner = summary.winner {
                        VStack(spacing: 16) {
                            Text("🥇 Winner")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            WinnerCard(movie: winner)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // All Matches
                    if !summary.matches.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("All Matches")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(summary.matches) { movie in
                                    SummaryMovieRow(movie: movie, isWinner: movie.id == summary.winner?.id)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Poll Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct WinnerCard: View {
    let movie: Movie
    
    var body: some View {
        HStack(spacing: 16) {
            if let url = movie.posterURL {
                AsyncImage(url: url) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                
                if let year = movie.year {
                    Text("\(year)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                
                if !movie.genres.isEmpty {
                    Text(movie.genres.prefix(3).joined(separator: " • "))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                )
        )
    }
}

struct SummaryMovieRow: View {
    let movie: Movie
    let isWinner: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let url = movie.posterURL {
                AsyncImage(url: url) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if let year = movie.year {
                    Text("\(year)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isWinner ? Color.yellow.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isWinner ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
        )
    }
}