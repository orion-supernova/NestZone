import SwiftUI

enum PollType: String, CaseIterable {
    case genre = "Genre"
    case actor = "Actor"
    case director = "Director"
    case year = "Year"
    case decade = "Decade"
    case nowPlaying = "Now Playing"
    case popular = "Popular"
    case topRated = "Top Rated"
    case upcoming = "Upcoming"
    
    var icon: String {
        switch self {
        case .genre: return "theatermasks.fill"
        case .actor: return "person.fill"
        case .director: return "person.badge.key.fill"
        case .year: return "calendar"
        case .decade: return "calendar.circle.fill"
        case .nowPlaying: return "play.rectangle.fill"
        case .popular: return "flame.fill"
        case .topRated: return "star.fill"
        case .upcoming: return "calendar.badge.plus"
        }
    }
    
    var localizedTitle: String {
        switch self {
        case .genre: return LocalizationManager.pollTypeGenre
        case .actor: return LocalizationManager.pollTypeActor
        case .director: return LocalizationManager.pollTypeDirector
        case .year: return LocalizationManager.pollTypeYear
        case .decade: return LocalizationManager.pollTypeDecade
        case .nowPlaying: return LocalizationManager.pollTypeNowPlaying
        case .popular: return LocalizationManager.pollTypePopular
        case .topRated: return LocalizationManager.pollTypeTopRated
        case .upcoming: return LocalizationManager.pollTypeUpcoming
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .genre: return LocalizationManager.pollTypeGenreDescription
        case .actor: return LocalizationManager.pollTypeActorDescription
        case .director: return LocalizationManager.pollTypeDirectorDescription
        case .year: return LocalizationManager.pollTypeYearDescription
        case .decade: return LocalizationManager.pollTypeDecadeDescription
        case .nowPlaying: return LocalizationManager.pollTypeNowPlayingDescription
        case .popular: return LocalizationManager.pollTypePopularDescription
        case .topRated: return LocalizationManager.pollTypeTopRatedDescription
        case .upcoming: return LocalizationManager.pollTypeUpcomingDescription
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .genre: return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .actor: return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .director: return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .year: return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .decade: return LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .nowPlaying: return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .popular: return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .topRated: return LinearGradient(colors: [.yellow, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .upcoming: return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct PollTypeSelectionSheet: View {
    let onPollTypeSelected: (PollType) -> Void // Remove includeAdult parameter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text(LocalizationManager.pollTypeSelectionTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(LocalizationManager.pollTypeSelectionSubtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Poll Type Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(PollType.allCases, id: \.self) { pollType in
                            PollTypeCard(
                                pollType: pollType
                            ) {
                                onPollTypeSelected(pollType)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 20))
                    }
                }
            }
        }
    }
}

struct PollTypeCard: View {
    let pollType: PollType
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: pollType.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(pollType.gradient)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Title and Description
                VStack(spacing: 6) {
                    Text(pollType.localizedTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text(pollType.localizedDescription)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(pollType.gradient, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }
    }
}