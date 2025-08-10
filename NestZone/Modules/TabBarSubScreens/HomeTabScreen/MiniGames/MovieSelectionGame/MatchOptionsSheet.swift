import SwiftUI

struct MatchOptionsSheet: View {
    let matches: [Movie]
    let onContinue: () -> Void
    let onEndWithWinner: (Movie) -> Void
    let onEndCompletely: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWinner: Movie?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("🎉 Matches Found! 🎉")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        )
                    
                    Text("These movies got positive votes from your house members")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Matches List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(matches) { movie in
                            MatchMovieRow(
                                movie: movie,
                                isSelected: selectedWinner?.id == movie.id
                            ) {
                                selectedWinner = movie
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Continue Poll Button
                    Button {
                        onContinue()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle")
                            Text("Continue Poll")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // End with Selected Winner
                    if let winner = selectedWinner {
                        Button {
                            onEndWithWinner(winner)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                Text("Choose \"\(winner.title)\" as Winner")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // End Poll Completely
                    Button {
                        onEndCompletely()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.checkered")
                            Text("End Poll & See All Results")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.orange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Poll Matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onContinue() // Same as continue
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MatchMovieRow: View {
    let movie: Movie
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Poster
                if let url = movie.posterURL {
                    AsyncImage(url: url) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 75)
                }
                
                // Movie Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let year = movie.year {
                        Text("\(year)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    if !movie.genres.isEmpty {
                        Text(movie.genres.prefix(2).joined(separator: " • "))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}