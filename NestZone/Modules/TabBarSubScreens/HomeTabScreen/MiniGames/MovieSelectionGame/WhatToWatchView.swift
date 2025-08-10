import SwiftUI

struct CardViewModel: Identifiable {
    let id = UUID()
    let movie: Movie
    let stackPosition: Int
    var isVisible: Bool = true
}

struct WhatToWatchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WhatToWatchViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.1),
                        Color.blue.opacity(0.05),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 8) {
                        Text("What to watch tonight")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        if viewModel.isInPoll {
                            Text("Swipe right for Yes, left for No")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Start a new movie poll")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    if viewModel.isInPoll {
                        // Swipe Cards
                        SwipeDeckView(
                            cardStack: viewModel.cardStack,
                            onSwipeLeft: { viewModel.handleVote(for: $0, vote: false) },
                            onSwipeRight: { viewModel.handleVote(for: $0, vote: true) },
                            onTap: { viewModel.selectedMovieForDetail = $0; viewModel.showingMovieDetail = true }
                        )
                        .padding(.horizontal, 20)
                        
                        // Current Matches
                        if !viewModel.currentMatches.isEmpty {
                            MatchesSection(currentMatches: viewModel.currentMatches) { movie in
                                Task { await viewModel.selectMatch(movie) }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Exit Poll Button
                        Button("Exit Poll") {
                            Task { await viewModel.closePoll() }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        
                    } else {
                        // Start Poll Button
                        Button("Start Movie Poll") {
                            viewModel.showingGenrePicker = true
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
                
                if viewModel.showConfetti {
                    ConfettiView(isActive: $viewModel.showConfetti)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingGenrePicker) {
            GenrePickerSheet { genres in
                Task { await viewModel.startGenrePoll(genres) }
            }
        }
        .sheet(isPresented: $viewModel.showingMovieDetail) {
            if let movie = viewModel.selectedMovieForDetail {
                SimpleMovieDetailSheet(movie: movie)
            }
        }
        .onAppear {
            Task { await viewModel.initialize() }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

#Preview {
    WhatToWatchView()
}