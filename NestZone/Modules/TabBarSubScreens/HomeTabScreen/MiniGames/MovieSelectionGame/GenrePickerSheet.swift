import SwiftUI

struct GenrePickerSheet: View {
    let onPick: ([String], Bool) -> Void // Add includeAdult parameter
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGenres: Set<String> = []
    @State private var includeAdult = false // Add adult content toggle
    
    // Enhanced genre list with emojis and localized descriptions
    var genres: [(key: String, emoji: String, localizedName: String, localizedDescription: String)] {
        [
            ("Action", "🎬", LocalizationManager.genreAction, LocalizationManager.genreActionDescription),
            ("Adventure", "🗺️", LocalizationManager.genreAdventure, LocalizationManager.genreAdventureDescription),
            ("Comedy", "😂", LocalizationManager.genreComedy, LocalizationManager.genreComedyDescription),
            ("Drama", "🎭", LocalizationManager.genreDrama, LocalizationManager.genreDramaDescription),
            ("Fantasy", "🧙‍♂️", LocalizationManager.genreFantasy, LocalizationManager.genreFantasyDescription),
            ("Horror", "👻", LocalizationManager.genreHorror, LocalizationManager.genreHorrorDescription),
            ("Romance", "💕", LocalizationManager.genreRomance, LocalizationManager.genreRomanceDescription),
            ("Sci-Fi", "🚀", LocalizationManager.genreSciFi, LocalizationManager.genreSciFiDescription),
            ("Thriller", "😱", LocalizationManager.genreThriller, LocalizationManager.genreThrillerDescription),
            ("Animation", "🎨", LocalizationManager.genreAnimation, LocalizationManager.genreAnimationDescription)
        ]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(LocalizationManager.genreSelectionTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(LocalizationManager.genreSelectionSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Genre Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(genres, id: \.key) { genre in
                            GenreCard(
                                title: genre.localizedName,
                                emoji: genre.emoji,
                                description: genre.localizedDescription,
                                isSelected: selectedGenres.contains(genre.key)
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedGenres.contains(genre.key) {
                                        selectedGenres.remove(genre.key)
                                    } else {
                                        selectedGenres.insert(genre.key)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Selected Count, Adult Toggle & Action Button
                VStack(spacing: 16) {
                    if !selectedGenres.isEmpty {
                        HStack(spacing: 8) {
                            Text(LocalizationManager.genreSelectionSelected)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedGenres.sorted()), id: \.self) { genreKey in
                                        if let genre = genres.first(where: { $0.key == genreKey }) {
                                            HStack(spacing: 4) {
                                                Text(genre.emoji)
                                                    .font(.system(size: 12))
                                                Text(genre.localizedName)
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(.purple.opacity(0.15)))
                                            .foregroundStyle(.purple)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Adult Content Toggle
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizationManager.genreSelectionIncludeAdult)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    
                                    Text(LocalizationManager.genreSelectionIncludeAdultDescription)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $includeAdult)
                                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.purple.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        Button {
                            onPick(Array(selectedGenres), includeAdult)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text(LocalizationManager.genreSelectionCreatePoll)
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Text(LocalizationManager.genreSelectionSelectOneMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
                
                if !selectedGenres.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(LocalizationManager.genreSelectionClearAll) {
                            withAnimation {
                                selectedGenres.removeAll()
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

struct GenreCard: View {
    let title: String
    let emoji: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Emoji
                Text(emoji)
                    .font(.system(size: 32))
                
                // Title
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                // Description
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? 
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: isSelected ? .purple.opacity(0.3) : .black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                x: 0,
                y: isSelected ? 4 : 1
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}