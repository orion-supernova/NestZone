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
    
    @State private var isInPoll = false
    @State private var showConfetti = false
    @State private var candidates: [Movie] = []
    @State private var cardStack: [CardViewModel] = []
    @State private var topIndex: Int = 0
    @State private var showingGenrePicker = false
    @State private var showingSearch = false
    @State private var customList: [Movie] = []
    @State private var lastWatched: Movie?
    @State private var watched: [Movie] = []
    @State private var customListTitle: String = ""
    @State private var selectedMovieForDetail: Movie?
    @State private var showingMovieDetail = false
    
    @State private var activePoll: Poll?
    @State private var pollingTask: Task<Void, Never>?
    @State private var currentMatches: [Movie] = []
    @State private var showingMatches = false
    
    @State private var previousPolls: [Poll] = []
    @State private var showingPreviousPolls = false
    @State private var showingClearHistoryAlert = false
    
    private let polls = PollsManager.shared
    private let requiredYesVotes = 2
    
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
                        header
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                        
                        if isInPoll {
                            swipeDeck
                                .padding(.horizontal, 20)
                            
                            if !currentMatches.isEmpty {
                                matchesSection
                                    .padding(.horizontal, 24)
                            }
                            
                            pollControls
                                .padding(.horizontal, 24)
                        } else {
                            historySection
                                .padding(.horizontal, 24)
                            
                            if !previousPolls.isEmpty {
                                previousPollsSection
                                    .padding(.horizontal, 24)
                            }
                            
                            actionsSection
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
                
                if showConfetti {
                    ConfettiView(isActive: $showConfetti)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if !watched.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear History") {
                            showingClearHistoryAlert = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .alert("Clear Movie History", isPresented: $showingClearHistoryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    MovieHistoryManager.shared.clearAll()
                    lastWatched = nil
                    watched = []
                }
            } message: {
                Text("This will permanently delete all your watched movie history.")
            }
            .sheet(isPresented: $showingSearch) {
                SearchMoviesSheet { movie in
                    Task { @MainActor in
                        if !customList.contains(where: { $0.id == movie.id }) {
                            customList.append(movie)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGenrePicker) {
                GenrePickerSheet { genres in
                    Task {
                        let genreTitle = genres.count == 1 ? genres.first! : "\(genres.count) Genres"
                        var allResults: [Movie] = []
                        
                        for genre in genres {
                            let results = await MovieAPI.shared.searchByGenre(genre: genre)
                            for movie in results {
                                if !allResults.contains(where: { $0.id == movie.id }) {
                                    allResults.append(movie)
                                }
                            }
                        }
                        
                        allResults = allResults.shuffled()
                        await startNewPoll(title: "Watch: \(genreTitle)", candidates: Array(allResults.prefix(25)))
                    }
                }
            }
            .sheet(isPresented: $showingMovieDetail) {
                if let movie = selectedMovieForDetail {
                    MovieDetailInfoSheet(movie: movie)
                }
            }
        }
        .onAppear {
            lastWatched = MovieHistoryManager.shared.lastWatched()
            watched = MovieHistoryManager.shared.allWatched()
            
            Task {
                do {
                    if let poll = try await polls.getActivePoll(homeId: nil) {
                        await MainActor.run {
                            self.activePoll = poll
                        }
                        await joinExistingPoll(poll)
                    } else {
                        let trending = await MovieAPI.shared.searchMovies(query: "popular")
                        await MainActor.run {
                            self.candidates = Array(trending.prefix(20))
                            self.initializeCardStack()
                        }
                    }
                } catch {
                    print("Failed to fetch active poll: \(error)")
                }
                
                do {
                    let previousPollsData = try await polls.getPreviousPolls(homeId: nil, limit: 5)
                    await MainActor.run {
                        self.previousPolls = previousPollsData
                    }
                } catch {
                    print("Failed to fetch previous polls: \(error)")
                }
            }
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What to watch tonight")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.text, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(isInPoll ? "Swipe right for Yes, left for No" : "Start a poll or browse your watch history")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "film.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
    }
    
    private var swipeDeck: some View {
        ZStack {
            if !cardStack.isEmpty && cardStack.contains(where: { $0.isVisible }) {
                ForEach(cardStack.filter { $0.isVisible }.prefix(3)) { cardViewModel in
                    let stackIndex = cardStack.firstIndex(where: { $0.id == cardViewModel.id }) ?? 0
                    let displayIndex = cardStack.filter { $0.isVisible }.firstIndex(where: { $0.id == cardViewModel.id }) ?? 0
                    
                    SwipeCard(
                        movie: cardViewModel.movie,
                        onSwipeLeft: { handleVote(for: cardViewModel, vote: false) },
                        onSwipeRight: { handleVote(for: cardViewModel, vote: true) },
                        onTap: { 
                            selectedMovieForDetail = cardViewModel.movie
                            showingMovieDetail = true
                        }
                    )
                    .offset(y: CGFloat(displayIndex) * 8)
                    .scaleEffect(1.0 - CGFloat(displayIndex) * 0.02)
                    .allowsHitTesting(displayIndex == 0)
                    .zIndex(Double(3 - displayIndex))
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    VStack(spacing: 8) {
                        Text("Poll Complete!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text("All movies have been reviewed")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Check the matches above or wait for others to finish voting")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient(colors: [.green.opacity(0.3), .mint.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    )
                )
            }
        }
        .frame(height: 500)
    }
    
    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular Choices")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                Spacer()
                Text("\(currentMatches.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.orange.opacity(0.2)))
            }
            
            Text("Movies getting positive votes from house members")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, -8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(currentMatches) { movie in
                        Button {
                            Task {
                                await MainActor.run {
                                    showConfetti = true
                                    MovieHistoryManager.shared.addWatched(movie)
                                    lastWatched = MovieHistoryManager.shared.lastWatched()
                                    watched = MovieHistoryManager.shared.allWatched()
                                }
                                await closePollOnServer()
                            }
                        } label: {
                            VStack(spacing: 8) {
                                if let url = movie.posterURL {
                                    AsyncImage(url: url) { img in
                                        img
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 80, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 80, height: 120)
                                }
                                
                                Text(movie.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var pollControls: some View {
        HStack(spacing: 12) {
            // Only show exit button if there are still cards to vote on
            if cardStack.contains(where: { $0.isVisible }) {
                Button {
                    Task { await closePollOnServer() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                        Text("Exit Poll")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [.red.opacity(0.8), .pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    guard let pollId = activePoll?.id else { return }
                    
                    // Get new movies
                    let newMovies = await MovieAPI.shared.searchMovies(query: "movie")
                    let moviesToAdd = Array(newMovies.prefix(15)) // Limit new movies to avoid too many
                    
                    // Filter out movies that are already in candidates
                    let existingIds = Set(candidates.map { $0.id })
                    let uniqueNewMovies = moviesToAdd.filter { !existingIds.contains($0.id) }
                    
                    if !uniqueNewMovies.isEmpty {
                        await MainActor.run {
                            // Add new movies to existing candidates
                            self.candidates.append(contentsOf: uniqueNewMovies)
                            
                            // Add new cards to the stack with proper positions
                            let startPosition = self.cardStack.count
                            let newCards = uniqueNewMovies.enumerated().map { index, movie in
                                CardViewModel(movie: movie, stackPosition: startPosition + index)
                            }
                            self.cardStack.append(contentsOf: newCards)
                        }
                        
                        // Add new poll items to PocketBase
                        await addMoviesToPoll(pollId: pollId, movies: uniqueNewMovies)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Get New Movies")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Capsule())
            }
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let last = lastWatched {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Last Watched")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                        Spacer()
                        Text("Local History")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.secondary.opacity(0.2)))
                    }
                    
                    MovieRow(movie: last)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("All Watched")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                    Spacer()
                    if !watched.isEmpty {
                        Text("Local History")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.secondary.opacity(0.2)))
                    }
                }
                
                if !watched.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(watched) { movie in
                            MovieRow(movie: movie)
                        }
                    }
                }
            }
        }
    }
    
    private var previousPollsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Previous Polls")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                Spacer()
                Button {
                    showingPreviousPolls = true
                } label: {
                    Text("View All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            
            LazyVStack(spacing: 10) {
                ForEach(previousPolls.prefix(3)) { poll in
                    PreviousPollRow(poll: poll)
                }
            }
        }
        .sheet(isPresented: $showingPreviousPolls) {
            PreviousPollsSheet(polls: previousPolls)
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Quick Actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Start")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                
                HStack(spacing: 12) {
                    Button {
                        showingGenrePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("By Genre")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        Task {
                            let popularQueries = ["Marvel", "Comedy", "Action", "Drama", "Thriller", "Animation"]
                            let selectedQuery = popularQueries.randomElement() ?? "popular"
                            let randoms = await MovieAPI.shared.searchMovies(query: selectedQuery)
                            await startNewPoll(title: "Quick Poll - \(selectedQuery)", candidates: randoms)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "dice")
                            Text("Random Mix")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            // Custom List Creation
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Create Custom List")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                    
                    Spacer()
                    
                    if !customList.isEmpty {
                        Text("\(customList.count) movies")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.green.opacity(0.2)))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title Field
                    TextField("Enter list title (e.g., Friday Night Picks)", text: $customListTitle)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                                )
                        )
                    
                    // Search & Actions
                    HStack(spacing: 10) {
                        Button {
                            showingSearch = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.magnifyingglass")
                                Text("Add Movies")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        if !customList.isEmpty {
                            Button {
                                Task {
                                    let title = customListTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let pollTitle = title.isEmpty ? "Custom Movie List" : title
                                    await startNewPoll(title: pollTitle, candidates: customList)
                                    await MainActor.run {
                                        customList = []
                                        customListTitle = ""
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Start Poll")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            Button {
                                customList.removeAll()
                                customListTitle = ""
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .padding(10)
                                    .background(Circle().fill(.red.opacity(0.1)))
                            }
                        }
                    }
                    
                    // Movie List Preview
                    if !customList.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected Movies:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(customList) { movie in
                                        VStack(spacing: 6) {
                                            if let url = movie.posterURL {
                                                AsyncImage(url: url) { img in
                                                    img
                                                        .resizable()
                                                        .scaledToFill()
                                                } placeholder: {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.gray.opacity(0.2))
                                                }
                                                .frame(width: 50, height: 75)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 50, height: 75)
                                            }
                                            
                                            Text(movie.title)
                                                .font(.system(size: 10, weight: .medium))
                                                .lineLimit(2)
                                                .frame(width: 50)
                                                .multilineTextAlignment(.center)
                                        }
                                        .onTapGesture {
                                            if let index = customList.firstIndex(where: { $0.id == movie.id }) {
                                                customList.remove(at: index)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.green.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Poll Lifecycle
    
    private func joinExistingPoll(_ poll: Poll) async {
        do {
            // Get poll items and user's existing votes in parallel
            async let pollItemsTask = polls.fetchPollItems(pollId: poll.id)
            async let userVotesTask = polls.fetchUserVotes(pollId: poll.id)
            
            let pollItems = try await pollItemsTask
            let userVotes = try await userVotesTask
            
            // Get set of IMDB IDs that user has already voted on
            let votedImdbIds = Set(userVotes.compactMap { $0.targetExternalId })
            print("👤 User has already voted on \(votedImdbIds.count) movies: \(Array(votedImdbIds))")
            
            // Filter out poll items that user has already voted on
            let unvotedPollItems = pollItems.filter { !votedImdbIds.contains($0.externalId) }
            print("📊 Showing \(unvotedPollItems.count) unvoted movies out of \(pollItems.count) total")
            
            let movies: [Movie] = await withTaskGroup(of: Movie?.self) { group in
                for item in unvotedPollItems {
                    group.addTask { await MovieAPI.shared.getDetails(imdbID: item.externalId) }
                }
                var list: [Movie] = []
                for await m in group { if let m { list.append(m) } }
                return list
            }
            
            await MainActor.run {
                activePoll = poll
                candidates = movies
                initializeCardStack()
                topIndex = 0
                isInPoll = true
            }
            startPolling()
        } catch {
            print("Failed to join existing poll: \(error)")
            await MainActor.run {
                activePoll = nil
                isInPoll = false
            }
        }
    }
    
    private func startNewPoll(title: String, candidates: [Movie]) async {
        do {
            let poll = try await polls.createPoll(homeId: nil, title: title, candidates: Array(candidates.prefix(25)), genre: nil)
            await MainActor.run {
                self.activePoll = poll
                self.candidates = Array(candidates.prefix(25))
                self.initializeCardStack()
                self.topIndex = 0
                self.isInPoll = true
            }
            startPolling()
        } catch {
            print("Failed to create poll: \(error)")
            await MainActor.run {
                self.activePoll = nil
                self.candidates = Array(candidates.prefix(25))
                self.initializeCardStack()
                self.topIndex = 0
                self.isInPoll = true
            }
        }
    }
    
    private func startPolling() {
        stopPolling()
        guard let pollId = activePoll?.id else { return }
        pollingTask = Task { [pollId] in
            var houseMemberCount = 2
            var lastVoteCount = 0
            
            do {
                houseMemberCount = try await polls.getHouseMemberCount(homeId: nil)
            } catch {
                print("Failed to get house member count, using default: \(error)")
            }
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second interval
                do {
                    let votes = try await polls.fetchVotes(pollId: pollId)
                    
                    // Only process if there are new votes
                    if votes.count != lastVoteCount {
                        print("📊 Processing \\(votes.count) votes (was \\(lastVoteCount))")
                        lastVoteCount = votes.count
                        
                        let counts = polls.voteCounts(for: votes)
                        
                        let potentialMatches = counts.filter { $0.value.yes > 0 && $0.value.yes >= $0.value.no }
                        let matchMovies: [Movie] = await withTaskGroup(of: Movie?.self) { group in
                            for (imdbId, _) in potentialMatches {
                                group.addTask { await MovieAPI.shared.getDetails(imdbID: imdbId) }
                            }
                            var results: [Movie] = []
                            for await movie in group {
                                if let movie = movie { results.append(movie) }
                            }
                            return results
                        }
                        
                        await MainActor.run {
                            self.currentMatches = matchMovies.sorted { lhs, rhs in
                                let lhsVotes = counts[lhs.id]?.yes ?? 0
                                let rhsVotes = counts[rhs.id]?.yes ?? 0
                                return lhsVotes > rhsVotes
                            }
                        }
                        
                        let finalMatchIds = polls.getMatches(votes: votes, houseMemberCount: houseMemberCount)
                        if let finalMatchId = finalMatchIds.first {
                            if let movie = await MovieAPI.shared.getDetails(imdbID: finalMatchId) {
                                await MainActor.run {
                                    showConfetti = true
                                    MovieHistoryManager.shared.addWatched(movie)
                                    lastWatched = MovieHistoryManager.shared.lastWatched()
                                    watched = MovieHistoryManager.shared.allWatched()
                                }
                                try? await polls.closePoll(pollId: pollId)
                                await MainActor.run {
                                    isInPoll = false
                                    activePoll = nil
                                    currentMatches = []
                                }
                                break
                            }
                        }
                    } else {
                        print("📊 No new votes, skipping processing (\\(votes.count) votes)")
                    }
                } catch {
                    print("Polling error: \(error)")
                }
            }
            await MainActor.run { 
                showConfetti = false
                currentMatches = []
            }
        }
    }
    
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func closePollOnServer() async {
        stopPolling()
        if let pollId = activePoll?.id {
            try? await polls.closePoll(pollId: pollId)
        }
        await MainActor.run {
            activePoll = nil
            currentMatches = []
            endPollLocally()
        }
    }
    
    private func endPollLocally() {
        isInPoll = false
        topIndex = 0
    }
    
    private func handleVote(for cardViewModel: CardViewModel, vote: Bool) {
        print("🗳️ SWIPE: \(vote ? "RIGHT (YES)" : "LEFT (NO)") for \(cardViewModel.movie.title) (\(cardViewModel.movie.id))")
        
        if let pollId = activePoll?.id {
            print("🗳️ Poll ID: \(pollId)")
            Task { 
                do {
                    try await polls.submitVote(pollId: pollId, imdbId: cardViewModel.movie.id, vote: vote, userId: nil)
                    print("✅ Vote submitted successfully")
                } catch {
                    print("❌ Vote submission failed: \(error)")
                }
            }
        } else {
            print("❌ No active poll - vote not submitted")
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Mark the card as not visible instead of using topIndex
            if let index = cardStack.firstIndex(where: { $0.id == cardViewModel.id }) {
                cardStack[index].isVisible = false
            }
        }
    }
    
    private func initializeCardStack() {
        cardStack = candidates.enumerated().map { index, movie in
            CardViewModel(movie: movie, stackPosition: index)
        }
    }
    
    private func addMoviesToPoll(pollId: String, movies: [Movie]) async {
        let startOrder = candidates.count - movies.count // Get the starting order number
        
        for (index, movie) in movies.enumerated() {
            do {
                try await polls.addMovieToPoll(pollId: pollId, movie: movie, order: startOrder + index)
                print("✅ Added movie to poll: \(movie.title)")
            } catch {
                print("❌ Failed to add movie to poll \(movie.title): \(error)")
            }
        }
    }
}

#Preview {
    WhatToWatchView()
}