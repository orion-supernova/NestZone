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
    @State private var showingPreviousPolls = false
    
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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("What to watch tonight")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            if viewModel.isInPoll {
                                Text("Swipe right for Yes, left for No")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Create polls and discover movies together")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        if viewModel.isInPoll {
                            // Winner Announcement (if there's a final winner)
                            if let winner = viewModel.finalWinner {
                                WinnerAnnouncementView(movie: winner)
                                    .transition(.scale.combined(with: .opacity))
                                    .padding(.horizontal, 20)
                            } else if viewModel.isLoadingPollMovies {
                                // Loading movies state
                                VStack(spacing: 20) {
                                    VStack(spacing: 16) {
                                        // Animated progress circle
                                        ZStack {
                                            Circle()
                                                .stroke(Color.purple.opacity(0.2), lineWidth: 8)
                                                .frame(width: 80, height: 80)
                                            
                                            Circle()
                                                .trim(from: 0, to: viewModel.loadingProgress)
                                                .stroke(
                                                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                                )
                                                .frame(width: 80, height: 80)
                                                .rotationEffect(.degrees(-90))
                                                .animation(.easeInOut(duration: 0.3), value: viewModel.loadingProgress)
                                            
                                            Text("\(Int(viewModel.loadingProgress * 100))%")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        VStack(spacing: 8) {
                                            Text("Loading Movies")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(.primary)
                                            
                                            Text("Fetching movie details for your poll...")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 520)
                                .padding(.horizontal, 20)
                            } else {
                                // Swipe Cards
                                SwipeDeckView(
                                    cardStack: viewModel.cardStack,
                                    onSwipeLeft: { viewModel.handleVote(for: $0, vote: false) },
                                    onSwipeRight: { viewModel.handleVote(for: $0, vote: true) },
                                    onTap: { viewModel.selectedMovieForDetail = $0; viewModel.showingMovieDetail = true },
                                    votingStats: viewModel.votingStats
                                )
                                .padding(.horizontal, 16)
                            }
                            
                            // Poll Action Buttons
                            HStack(spacing: 12) {
                                // End Poll Button
                                Button("End Poll") {
                                    Task { await viewModel.closePoll() }
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(Capsule())
                                
                                // Previous Polls Button (smaller)
                                Button {
                                    showingPreviousPolls = true
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.purple)
                                        .frame(width: 44, height: 44)
                                        .background(Circle().fill(.purple.opacity(0.15)))
                                }
                            }
                            .padding(.horizontal, 20)
                            
                        } else if viewModel.isCreatingPoll {
                            // Loading State
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .frame(width: 50, height: 50)
                                
                                Text("Creating your movie poll...")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("This may take a moment while we prepare your personalized movie selection")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                            
                        } else {
                            // Main Menu Buttons
                            VStack(spacing: 16) {
                                // Start Poll Button
                                Button("Start Movie Poll") {
                                    viewModel.showingGenrePicker = true
                                }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                // Previous Polls Button
                                Button {
                                    showingPreviousPolls = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Previous Polls")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundStyle(.purple)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.purple.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(.purple.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                if viewModel.showConfetti {
                    ConfettiView(isActive: $viewModel.showConfetti)
                        .ignoresSafeArea()
                        .allowsHitTesting(false) // Allow interaction with content below
                        .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                // Add Previous Polls button to toolbar when not in poll
                if !viewModel.isInPoll && !viewModel.isCreatingPoll {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingPreviousPolls = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16))
                        }
                    }
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
        .sheet(isPresented: $showingPreviousPolls) {
            PreviousPollsView()
        }
        .sheet(isPresented: $viewModel.showingMatchOptions) {
            MatchOptionsSheet(
                matches: viewModel.currentMatches,
                onContinue: {
                    viewModel.continuePoll()
                },
                onEndWithWinner: { winner in
                    Task { await viewModel.endPollWithWinner(winner) }
                },
                onEndCompletely: {
                    Task { await viewModel.endPollCompletely() }
                }
            )
        }
        .sheet(isPresented: $viewModel.showingPollSummary) {
            if let summary = viewModel.pollSummary {
                PollSummarySheet(summary: summary)
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

struct WinnerAnnouncementView: View {
    let movie: Movie
    
    var body: some View {
        VStack(spacing: 16) {
            Text("🎉 We have a winner! 🎉")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                )
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                if let url = movie.posterURL {
                    AsyncImage(url: url) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                VStack(spacing: 8) {
                    Text(movie.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    
                    if let year = movie.year {
                        Text("\(year)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    if !movie.genres.isEmpty {
                        Text(movie.genres.prefix(3).joined(separator: " • "))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            Text("This movie got the most votes from your house!")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    WhatToWatchView()
}