import SwiftUI

struct GenrePickerSheet: View {
    let onPick: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGenres: Set<String> = []
    
    // Enhanced genre list with emojis and descriptions
    let genres = [
        ("Action", "🎬", "Explosions, fights, and thrills"),
        ("Adventure", "🗺️", "Epic journeys and quests"),
        ("Comedy", "😂", "Laughs and good times"),
        ("Drama", "🎭", "Emotional and compelling stories"),
        ("Fantasy", "🧙‍♂️", "Magic and mythical worlds"),
        ("Horror", "👻", "Scary and spine-chilling"),
        ("Romance", "💕", "Love stories and relationships"),
        ("Sci-Fi", "🚀", "Future tech and space adventures"),
        ("Thriller", "😱", "Suspense and edge-of-your-seat"),
        ("Animation", "🎨", "Animated movies and cartoons")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Your Movie Genres")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Select one or more genres for your movie poll")
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
                        ForEach(genres, id: \.0) { genre in
                            GenreCard(
                                title: genre.0,
                                emoji: genre.1,
                                description: genre.2,
                                isSelected: selectedGenres.contains(genre.0)
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedGenres.contains(genre.0) {
                                        selectedGenres.remove(genre.0)
                                    } else {
                                        selectedGenres.insert(genre.0)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Selected Count & Action Button
                VStack(spacing: 16) {
                    if !selectedGenres.isEmpty {
                        HStack(spacing: 8) {
                            Text("Selected:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedGenres.sorted()), id: \.self) { genre in
                                        HStack(spacing: 4) {
                                            Text(genres.first(where: { $0.0 == genre })?.1 ?? "")
                                                .font(.system(size: 12))
                                            Text(genre)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(.purple.opacity(0.15)))
                                        .foregroundStyle(.purple)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Button {
                            onPick(Array(selectedGenres))
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Create Movie Poll")
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
                        Text("Select at least one genre to continue")
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
                        Button("Clear All") {
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