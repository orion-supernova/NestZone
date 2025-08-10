import SwiftUI

struct CardViewModel: Identifiable {
    let id = UUID()
    let movie: Movie
    let stackPosition: Int
    var isVisible: Bool = true
}

struct WhatToWatchView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = WhatToWatchViewModel()
    
    private var theme: ThemeColors {
        selectedTheme.colors(for: colorScheme)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                RadialGradient(
                    colors: [
                        theme.background,
                        Color.purple.opacity(0.05),
                        Color.blue.opacity(0.03)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        WhatToWatchHeader(theme: theme, isInPoll: viewModel.isInPoll)
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                        
                        if viewModel.isInPoll {
                            SwipeDeckView(
                                cardStack: viewModel.cardStack,
                                onSwipeLeft: { viewModel.handleVote(for: $0, vote: false) },
                                onSwipeRight: { viewModel.handleVote(for: $0, vote: true) },
                                onTap: { viewModel.selectedMovieForDetail = $0; viewModel.showingMovieDetail = true }
                            )
                            .padding(.horizontal, 20)
                            
                            if !viewModel.currentMatches.isEmpty {
                                MatchesSection(currentMatches: viewModel.currentMatches) { movie in
                                    Task { await viewModel.selectMatch(movie) }
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            PollControls(
                                hasVisibleCards: viewModel.cardStack.contains(where: { $0.isVisible }),
                                isCuratedPoll: viewModel.isCuratedPoll,
                                onExitPoll: { Task { await viewModel.closePoll() } },
                                onGetNewMovies: { Task { await viewModel.getNewMovies() } }
                            )
                            .padding(.horizontal, 24)
                        } else {
                            MovieHistorySection(
                                lastWatched: viewModel.lastWatched,
                                watched: viewModel.watched
                            )
                            .padding(.horizontal, 24)
                            
                            if !viewModel.previousPolls.isEmpty {
                                PreviousPollsSection(polls: viewModel.previousPolls) {
                                    viewModel.showingPreviousPolls = true
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            VStack(spacing: 20) {
                                QuickActionsSection(
                                    onGenrePicker: { viewModel.showingGenrePicker = true },
                                    onRandomMix: { Task { await viewModel.startRandomPoll() } }
                                )
                                
                                CustomListCreation(
                                    customList: $viewModel.customList,
                                    customListTitle: $viewModel.customListTitle,
                                    onAddMovies: { viewModel.showingSearch = true },
                                    onStartPoll: { Task { await viewModel.startCustomPoll() } },
                                    onClearList: { viewModel.clearCustomList() }
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: 80)
                    }
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !viewModel.watched.isEmpty {
                        Button("Clear History") {
                            viewModel.showingClearHistoryAlert = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .alert("Clear Movie History", isPresented: $viewModel.showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { viewModel.clearHistory() }
        } message: {
            Text("This will permanently delete all your watched movie history.")
        }
        .sheet(isPresented: $viewModel.showingSearch) {
            SearchMoviesSheet { movie in
                viewModel.addToCustomList(movie)
            }
        }
        .sheet(isPresented: $viewModel.showingGenrePicker) {
            GenrePickerSheet { genres in
                Task { await viewModel.startGenrePoll(genres) }
            }
        }
        .sheet(isPresented: $viewModel.showingMovieDetail) {
            if let movie = viewModel.selectedMovieForDetail {
                MovieDetailInfoSheet(movie: movie, originList: nil)
            }
        }
        .sheet(isPresented: $viewModel.showingPreviousPolls) {
            PreviousPollsSheet(polls: viewModel.previousPolls)
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