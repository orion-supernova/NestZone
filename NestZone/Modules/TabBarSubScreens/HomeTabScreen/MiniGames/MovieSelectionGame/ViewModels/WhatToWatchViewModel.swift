import Foundation
import SwiftUI

@MainActor
class WhatToWatchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isInPoll = false
    @Published var showConfetti = false
    @Published var cardStack: [CardViewModel] = []
    @Published var selectedMovieForDetail: Movie?
    @Published var showingMovieDetail = false
    @Published var activePoll: Poll?
    @Published var showingPollTypeSelection = false // NEW: Show poll type selection
    @Published var showingGenrePicker = false
    @Published var showingActorInput = false // NEW: Show actor input
    @Published var showingDirectorInput = false // NEW: Show director input
    @Published var showingYearInput = false // NEW: Show year input
    @Published var showingDecadeInput = false // NEW: Show decade input
    @Published var isCreatingPoll = false
    @Published var finalWinner: Movie? // Track final winner
    @Published var isLoadingPollMovies = false // Loading indicator for movie details
    @Published var loadingProgress: Double = 0.0 // Progress indicator (0.0 to 1.0)
    @Published var currentMatches: [Movie] = [] // NEW: Current matches found
    @Published var showingMatchOptions = false // NEW: Show continue/end options
    @Published var showingPollSummary = false // NEW: Show final poll summary
    @Published var pollSummary: PollSummary? // Summary data
    @Published var votingStats: VotingStats? // NEW: Current voting statistics
    @Published var includeAdultContent = false // NEW: Adult content toggle
    
    // MARK: - Private Properties
    private let polls = PollsManager.shared
    private var pollingTask: Task<Void, Never>?
    private var hasSelectedMatch = false // Prevent multiple match selections
    private var voteCount = 0 // Track votes to optimize match checking
    private let matchCheckInterval = 3 // Check for matches every N votes
    
    // MARK: - Initialization
    func initialize() async {
        print("🎬 WhatToWatch: Initializing...")
        
        // Reset any previous state first
        await MainActor.run {
            isInPoll = false
            activePoll = nil
            finalWinner = nil
            currentMatches = []
            showingMatchOptions = false
            showingPollSummary = false
            pollSummary = nil
            votingStats = nil
            hasSelectedMatch = false
            voteCount = 0
        }
        
        await checkForActivePoll()
    }
    
    func cleanup() {
        print("🎬 WhatToWatch: Cleaning up...")
        stopPolling()
    }
    
    // MARK: - Poll Management
    private func checkForActivePoll() async {
        print("🎬 WhatToWatch: Checking for active poll...")
        do {
            // First check for active polls
            if let poll = try await polls.getActivePoll(homeId: nil) {
                print("🎬 WhatToWatch: Found active poll: \(poll.id)")
                print("🎬 WhatToWatch: Poll status: \(poll.status ?? "nil")")
                print("🎬 WhatToWatch: Poll title: \(poll.title ?? "nil")")
                
                // Double-check that the poll is actually active
                if poll.status == "active" {
                    await joinExistingPoll(poll)
                } else {
                    print("⚠️ WhatToWatch: Poll status is not 'active' (\(poll.status ?? "nil")), ignoring it")
                    print("🎬 WhatToWatch: No valid active poll found")
                }
            } else {
                print("🎬 WhatToWatch: No active poll found")
                
                // DEBUG: Also check for any recent polls to understand what's happening
                if let recentPoll = try await polls.getRecentPoll(homeId: nil) {
                    print("🔍 DEBUG: Found recent poll: \(recentPoll.id)")
                    print("🔍 DEBUG: Recent poll status: \(recentPoll.status ?? "nil")")
                    print("🔍 DEBUG: Recent poll title: \(recentPoll.title ?? "nil")")
                } else {
                    print("🔍 DEBUG: No recent polls found at all")
                }
            }
        } catch {
            print("🎬 WhatToWatch: Failed to check for active poll: \(error)")
        }
    }
    
    // MARK: - Poll Type Selection
    func handlePollTypeSelection(_ pollType: PollType) {
        switch pollType {
        case .genre:
            showingGenrePicker = true
        case .actor:
            showingActorInput = true
        case .director:
            showingDirectorInput = true
        case .year:
            showingYearInput = true
        case .decade:
            showingDecadeInput = true
        case .nowPlaying:
            Task { await startNowPlayingPoll() }
        case .popular:
            Task { await startPopularPoll() }
        case .topRated:
            Task { await startTopRatedPoll() }
        case .upcoming:
            Task { await startUpcomingPoll() }
        }
    }
    
    // MARK: - Poll Creation Methods
    func startGenrePoll(_ genres: [String], includeAdult: Bool) async {
        print("🎬 WhatToWatch: Starting genre poll with genres: \(genres), includeAdult: \(includeAdult)")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        var allResults: [Movie] = []
        
        // Get movies from selected genres
        for genre in genres {
            print("🎬 WhatToWatch: Searching for genre: \(genre)")
            let results = await MovieAPI.shared.searchByGenre(genre: genre, includeAdult: includeAdult)
            print("🎬 WhatToWatch: Found \(results.count) movies for genre \(genre)")
            for movie in results {
                if !allResults.contains(where: { $0.id == movie.id }) {
                    allResults.append(movie)
                }
            }
        }
        
        // Shuffle and take 20
        allResults = allResults.shuffled()
        let selectedMovies = Array(allResults.prefix(20))
        print("🎬 WhatToWatch: Final movie selection: \(selectedMovies.count) movies")
        
        for movie in selectedMovies {
            print("🎬 - \(movie.title) (\(movie.id))")
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleGenre(genres.joined(separator: ", ")), candidates: selectedMovies)
        
        await MainActor.run {
            showingGenrePicker = false
        }
    }
    
    func startActorPoll(_ actorName: String) async {
        print("🎬 WhatToWatch: Starting actor poll for: \(actorName)")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.searchByActor(actorName: actorName, includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) movies for actor \(actorName)")
        
        guard !movies.isEmpty else {
            print("❌ No movies found for actor: \(actorName)")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleActor(actorName), candidates: movies)
        
        // Dismiss the actor input sheet
        await MainActor.run {
            showingActorInput = false
        }
    }
    
    func startDirectorPoll(_ directorName: String) async {
        print("🎬 WhatToWatch: Starting director poll for: \(directorName)")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.searchByDirector(directorName: directorName, includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) movies for director \(directorName)")
        
        guard !movies.isEmpty else {
            print("❌ No movies found for director: \(directorName)")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleDirector(directorName), candidates: movies)
        
        await MainActor.run {
            showingDirectorInput = false
        }
    }
    
    func startYearPoll(_ year: Int) async {
        print("🎬 WhatToWatch: Starting year poll for: \(year)")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.searchByYear(year: year, includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) movies for year \(year)")
        
        guard !movies.isEmpty else {
            print("❌ No movies found for year: \(year)")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleYear(year), candidates: movies)
        
        await MainActor.run {
            showingYearInput = false
        }
    }
    
    func startDecadePoll(_ decade: Int) async {
        print("🎬 WhatToWatch: Starting decade poll for: \(decade)s")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.searchByDecade(decade: decade, includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) movies for decade \(decade)s")
        
        guard !movies.isEmpty else {
            print("❌ No movies found for decade: \(decade)s")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleDecade(decade), candidates: movies)
        
        await MainActor.run {
            showingDecadeInput = false
        }
    }
    
    func startMixedPoll() async {
        print("🎬 WhatToWatch: Starting mixed poll")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.searchMovies(query: "", includeAdult: includeAdultContent) // Gets popular movies
        print("🎬 WhatToWatch: Found \(movies.count) popular movies")
        
        guard !movies.isEmpty else {
            print("❌ No popular movies found")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        let selectedMovies = Array(movies.shuffled().prefix(20))
        await startNewPoll(title: LocalizationManager.pollTitleMixed, candidates: selectedMovies)
    }
    
    func startNowPlayingPoll() async {
        print("🎬 WhatToWatch: Starting now playing poll")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.getNowPlayingMovies(includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) now playing movies")
        
        guard !movies.isEmpty else {
            print("❌ No now playing movies found")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleNowPlaying, candidates: movies)
    }
    
    func startPopularPoll() async {
        print("🎬 WhatToWatch: Starting popular poll")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.getPopularMovies(includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) popular movies")
        
        guard !movies.isEmpty else {
            print("❌ No popular movies found")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitlePopular, candidates: movies)
    }
    
    func startTopRatedPoll() async {
        print("🎬 WhatToWatch: Starting top rated poll")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.getTopRatedMovies(includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) top rated movies")
        
        guard !movies.isEmpty else {
            print("❌ No top rated movies found")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleTopRated, candidates: movies)
    }
    
    func startUpcomingPoll() async {
        print("🎬 WhatToWatch: Starting upcoming poll")
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.getUpcomingMovies(includeAdult: includeAdultContent)
        print("🎬 WhatToWatch: Found \(movies.count) upcoming movies")
        
        guard !movies.isEmpty else {
            print("❌ No upcoming movies found")
            await MainActor.run {
                isCreatingPoll = false
            }
            return
        }
        
        await startNewPoll(title: LocalizationManager.pollTitleUpcoming, candidates: movies)
    }
    
    func closePoll() async {
        print("🎬 WhatToWatch: Closing poll...")
        await closePollOnServer()
    }
    
    // MARK: - Voting
    func handleVote(for cardViewModel: CardViewModel, vote: Bool) {
        print("🗳️ SWIPE: \(vote ? "RIGHT (YES)" : "LEFT (NO)") for \(cardViewModel.movie.title)")
        
        if let pollId = activePoll?.id {
            Task {
                do {
                    try await polls.submitVote(pollId: pollId, imdbId: cardViewModel.movie.id, vote: vote, userId: nil)
                    print("✅ Vote submitted successfully")
                    
                    // Update voting stats when poll is complete
                    if cardStack.filter({ $0.isVisible }).count <= 1 {
                        await updateVotingStats()
                    }
                    
                    // Check for matches immediately if this was a YES vote, or if all cards are done
                    if vote == true {
                        await checkForMatchesForMovie(cardViewModel.movie.id)
                    } else if cardStack.filter({ $0.isVisible }).count <= 1 {
                        await checkForMatches()
                    }
                } catch {
                    print("❌ Vote submission failed: \(error)")
                }
            }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let index = cardStack.firstIndex(where: { $0.id == cardViewModel.id }) {
                cardStack[index].isVisible = false
            }
        }
    }

    // NEW: Check if a specific movie is a match
    private func checkForMatchesForMovie(_ movieId: String) async {
        guard let pollId = activePoll?.id, !hasSelectedMatch else { return }
        
        do {
            let votes = try await polls.fetchVotes(pollId: pollId)
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: nil)
            
            let allMatchIds = polls.getMatches(votes: votes, houseMemberCount: houseMemberCount)
            
            // Only show matches if the swiped movie is actually a match
            if allMatchIds.contains(movieId) {
                print("🏆 Movie \(movieId) is a match! Showing all \(allMatchIds.count) matches")
                
                // Fetch movie details for ALL matches (not just the swiped one)
                let matches: [Movie] = await withTaskGroup(of: Movie?.self) { group in
                    for matchId in allMatchIds {
                        group.addTask { 
                            await MovieAPI.shared.getDetails(imdbID: matchId)
                        }
                    }
                    var list: [Movie] = []
                    for await movie in group {
                        if let movie = movie {
                            list.append(movie)
                        }
                    }
                    return list
                }
                
                await MainActor.run {
                    currentMatches = matches // Show ALL matches
                    showingMatchOptions = true
                    hasSelectedMatch = true
                }
            } else {
                print("📊 Movie \(movieId) got a YES vote but is not yet a match")
            }
        } catch {
            print("❌ Failed to check for matches for movie: \(error)")
        }
    }

    // UPDATED: Keep original method for final poll completion
    private func checkForMatches() async {
        guard let pollId = activePoll?.id, !hasSelectedMatch else { return }
        
        do {
            let votes = try await polls.fetchVotes(pollId: pollId)
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: nil)
            
            let matchIds = polls.getMatches(votes: votes, houseMemberCount: houseMemberCount)
            
            if !matchIds.isEmpty {
                print("🏆 Found \(matchIds.count) matches: \(matchIds)")
                
                // Fetch movie details for all matches
                let matches: [Movie] = await withTaskGroup(of: Movie?.self) { group in
                    for matchId in matchIds {
                        group.addTask { 
                            await MovieAPI.shared.getDetails(imdbID: matchId)
                        }
                    }
                    var list: [Movie] = []
                    for await movie in group {
                        if let movie = movie {
                            list.append(movie)
                        }
                    }
                    return list
                }
                
                await MainActor.run {
                    currentMatches = matches
                    showingMatchOptions = true
                    hasSelectedMatch = true
                }
            }
        } catch {
            print("❌ Failed to check for matches: \(error)")
        }
    }
    
    // MARK: - Private Helper Methods
    private func initializeCardStack(with candidates: [Movie]) {
        print("🎬 WhatToWatch: Initializing card stack with \(candidates.count) movies")
        cardStack = candidates.enumerated().map { index, movie in
            CardViewModel(movie: movie, stackPosition: index)
        }
        print("🎬 WhatToWatch: Card stack created with \(cardStack.count) cards")
    }
    
    private func startNewPoll(title: String, candidates: [Movie]) async {
        print("🎬 WhatToWatch: Starting new poll with \(candidates.count) candidates")
        
        guard !candidates.isEmpty else {
            print("❌ Cannot create poll with no candidates")
            return
        }
        
        // Start loading on main actor
        await MainActor.run {
            isLoadingPollMovies = true
            loadingProgress = 0.0
        }
        
        do {
            await MainActor.run {
                loadingProgress = 0.3 // 30% for creating poll
            }
            
            let poll = try await polls.createPoll(homeId: nil, title: title, candidates: candidates, genre: nil)
            print("✅ Poll created successfully: \(poll.id)")
            
            await MainActor.run {
                loadingProgress = 1.0 // 100% complete
                activePoll = poll
                isInPoll = true
                isLoadingPollMovies = false
                isCreatingPoll = false // Explicitly set this to false
            }
            
            // Initialize card stack after setting state
            initializeCardStack(with: candidates)
            
        } catch {
            print("❌ Failed to create poll: \(error)")
            // Even if server fails, start local poll
            print("🎬 Starting local poll as fallback")
            
            await MainActor.run {
                loadingProgress = 1.0 // 100% complete
                isInPoll = true
                isLoadingPollMovies = false
                isCreatingPoll = false // Explicitly set this to false
            }
            
            initializeCardStack(with: candidates)
        }
    }
    
    private func joinExistingPoll(_ poll: Poll) async {
        print("🎬 WhatToWatch: Joining existing poll: \(poll.id)")
        print("🎬 WhatToWatch: Poll status verification: \(poll.status ?? "nil")")
        
        // Double-check poll status before joining
        guard poll.status == "active" else {
            print("❌ WhatToWatch: Refusing to join non-active poll (status: \(poll.status ?? "nil"))")
            return
        }
        
        // Start loading
        isLoadingPollMovies = true
        loadingProgress = 0.0
        
        do {
            // DEBUG: Check current user ID
            let currentUserId = await getCurrentUserId()
            print("🎬 DEBUG: Current user ID: '\(currentUserId)'")
            
            async let pollItemsTask = polls.fetchPollItems(pollId: poll.id)
            async let userVotesTask = polls.fetchUserVotes(pollId: poll.id)
            
            let pollItems = try await pollItemsTask
            let userVotes = try await userVotesTask
            
            loadingProgress = 0.2 // 20% progress after fetching poll data
            
            print("🎬 WhatToWatch: Poll has \(pollItems.count) items")
            print("🎬 WhatToWatch: User has \(userVotes.count) votes")
            
            // DEBUG: Print all poll items
            print("🎬 DEBUG: Poll items:")
            for item in pollItems {
                print("  - \(item.label ?? "Unknown") (ID: \(item.externalId))")
            }
            
            // DEBUG: Print all user votes
            print("🎬 DEBUG: User votes:")
            for vote in userVotes {
                print("  - \(vote.targetExternalId ?? "nil") = \(vote.vote ? "YES" : "NO") (userID: \(vote.userId))")
            }
            
            let votedImdbIds = Set(userVotes.compactMap { $0.targetExternalId })
            print("🎬 DEBUG: Voted IDs set: \(votedImdbIds)")
            print("🎬 DEBUG: Voted IDs count: \(votedImdbIds.count)")
            
            let unvotedPollItems = pollItems.filter { pollItem in
                let hasVoted = votedImdbIds.contains(pollItem.externalId)
                print("🎬 DEBUG: Item \(pollItem.externalId) (\(pollItem.label ?? "Unknown")) - hasVoted: \(hasVoted)")
                return !hasVoted
            }
            
            print("🎬 WhatToWatch: User has \(unvotedPollItems.count) unvoted items")
            
            // DEBUG: Print unvoted items
            print("🎬 DEBUG: Unvoted items:")
            for item in unvotedPollItems {
                print("  - \(item.label ?? "Unknown") (ID: \(item.externalId))")
            }
            
            // ENHANCED DEBUG: If we have no unvoted items, let's investigate further
            if unvotedPollItems.isEmpty {
                print("🎬 DEBUG: No unvoted items found!")
                print("🎬 DEBUG: This means either:")
                print("  1. User has voted on all items")
                print("  2. There's an ID mismatch between poll items and votes")
                print("  3. User ID is incorrect")
                
                // Let's fetch ALL votes for this poll to debug
                let allVotes = try await polls.fetchVotes(pollId: poll.id)
                print("🎬 DEBUG: All votes in poll (\(allVotes.count) total):")
                for vote in allVotes {
                    print("  - User \(vote.userId): \(vote.targetExternalId ?? "nil") = \(vote.vote ? "YES" : "NO")")
                }
                
                // Check if the poll status is causing issues
                print("🎬 DEBUG: Poll status: \(poll.status ?? "nil")")
                
                // FORCE RESET: If this user truly has no votes, show all items anyway
                if userVotes.isEmpty {
                    print("🎬 DEBUG: User has no votes, forcing all items to be available")
                    
                    loadingProgress = 0.3 // 30% progress before fetching movie details
                    
                    let movies: [Movie] = await withTaskGroup(of: (Int, Movie?).self) { group in
                        for (index, item) in pollItems.enumerated() {
                            group.addTask { 
                                print("🎬 DEBUG: Fetching details for ID: \(item.externalId)")
                                let movie = await MovieAPI.shared.getDetails(imdbID: item.externalId)
                                return (index, movie)
                            }
                        }
                        var list: [Movie] = []
                        var completed = 0
                        for await (index, movie) in group { 
                            completed += 1
                            
                            // Update progress: 30% to 90% for movie fetching
                            await MainActor.run {
                                loadingProgress = 0.3 + (Double(completed) / Double(pollItems.count)) * 0.6
                            }
                            
                            if let movie = movie { 
                                list.append(movie)
                                print("🎬 DEBUG: Successfully got movie: \(movie.title) (ID: \(movie.id))")
                            } else {
                                print("🎬 DEBUG: Failed to get movie details")
                            }
                        }
                        return list
                    }
                    
                    print("🎬 WhatToWatch: Retrieved \(movies.count) movie details (forced reset)")
                    
                    loadingProgress = 1.0 // 100% complete
                    
                    activePoll = poll
                    initializeCardStack(with: movies)
                    isInPoll = true
                    isLoadingPollMovies = false
                    
                    // Check if there's already a final match
                    await checkForMatches()
                    return
                }
            }
            
            loadingProgress = 0.3 // 30% progress before fetching movie details
            
            let movies: [Movie] = await withTaskGroup(of: (Int, Movie?).self) { group in
                for (index, item) in unvotedPollItems.enumerated() {
                    group.addTask { 
                        print("🎬 DEBUG: Fetching details for ID: \(item.externalId)")
                        let movie = await MovieAPI.shared.getDetails(imdbID: item.externalId)
                        return (index, movie)
                    }
                }
                var list: [Movie] = []
                var completed = 0
                for await (index, movie) in group { 
                    completed += 1
                    
                    // Update progress: 30% to 90% for movie fetching  
                    await MainActor.run {
                        loadingProgress = 0.3 + (Double(completed) / Double(max(1, unvotedPollItems.count))) * 0.6
                    }
                    
                    if let movie = movie { 
                        list.append(movie)
                        print("🎬 DEBUG: Successfully got movie: \(movie.title) (ID: \(movie.id))")
                    } else {
                        print("🎬 DEBUG: Failed to get movie details")
                    }
                }
                return list
            }
            
            print("🎬 WhatToWatch: Retrieved \(movies.count) movie details")
            
            loadingProgress = 1.0 // 100% complete
            
            activePoll = poll
            initializeCardStack(with: movies)
            isInPoll = true
            isLoadingPollMovies = false
            
            // NEW: If user has completed voting, update voting stats AFTER setting activePoll
            if unvotedPollItems.isEmpty && userVotes.count == pollItems.count {
                print("🎬 DEBUG: User has completed voting, updating voting stats")
                await updateVotingStats()
            }
            
            // Check if there's already a final match
            await checkForMatches()
        } catch {
            print("❌ Failed to join existing poll: \(error)")
            activePoll = nil
            isInPoll = false
            isLoadingPollMovies = false
            loadingProgress = 0.0
        }
    }
    
    private func getCurrentUserId() async -> String {
        // Use the same logic as PollsManager
        guard let token = await PocketBaseManager.shared.getAuthToken() else {
            return "NO_TOKEN"
        }
        
        let components = token.split(separator: ".")
        guard components.count >= 2 else {
            return "INVALID_TOKEN"
        }
        
        let payloadString = String(components[1])
        let paddingLength = 4 - payloadString.count % 4
        let paddedPayload = payloadString + String(repeating: "=", count: paddingLength % 4)
        
        guard let payloadData = Data(base64Encoded: paddedPayload),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let userId = payloadJSON["id"] as? String else {
            return "PARSE_FAILED"
        }
        
        return userId
    }
    
    // NEW: Continue poll (dismiss match notification)
    func continuePoll() {
        showingMatchOptions = false
        hasSelectedMatch = false
        currentMatches = []
        voteCount = 0 // Reset vote count when continuing
    }
    
    // NEW: End poll with winner
    func endPollWithWinner(_ winner: Movie) async {
        showingMatchOptions = false
        
        do {
            // Close the poll on server
            if let pollId = activePoll?.id {
                try await polls.closePoll(pollId: pollId)
            }
            
            // Create summary
            let votes = try await polls.fetchVotes(pollId: activePoll?.id ?? "")
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: nil)
            
            pollSummary = PollSummary(
                matches: currentMatches,
                winner: winner,
                totalVotes: votes.count,
                participants: houseMemberCount
            )
            
            finalWinner = winner
            showConfetti = true
            showingPollSummary = true
            
            // Reset poll state after showing summary
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task {
                    await MainActor.run {
                        self.isInPoll = false
                        self.activePoll = nil
                        self.hasSelectedMatch = false
                        self.currentMatches = []
                    }
                }
            }
        } catch {
            print("❌ Failed to end poll: \(error)")
        }
    }
    
    // NEW: End poll completely (show all matches summary)
    func endPollCompletely() async {
        do {
            // Close the poll on server
            if let pollId = activePoll?.id {
                try await polls.closePoll(pollId: pollId)
            }
            
            // Create summary with all matches
            let votes = try await polls.fetchVotes(pollId: activePoll?.id ?? "")
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: nil)
            
            // Determine the top winner from matches
            let winner = currentMatches.first // Or implement more sophisticated winner selection
            
            pollSummary = PollSummary(
                matches: currentMatches,
                winner: winner,
                totalVotes: votes.count,
                participants: houseMemberCount
            )
            
            showingMatchOptions = false
            showingPollSummary = true
            
            // Reset poll state after showing summary
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task {
                    await MainActor.run {
                        self.isInPoll = false
                        self.activePoll = nil
                        self.hasSelectedMatch = false
                        self.currentMatches = []
                    }
                }
            }
        } catch {
            print("❌ Failed to end poll completely: \(error)")
        }
    }
    
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        print("🎬 WhatToWatch: Stopped polling")
    }
    
    private func closePollOnServer() async {
        stopPolling()
        if let pollId = activePoll?.id {
            print("🎬 WhatToWatch: Closing poll on server: \(pollId)")
            try? await polls.closePoll(pollId: pollId)
        }
        activePoll = nil
        isInPoll = false
        showConfetti = false
        hasSelectedMatch = false
        finalWinner = nil
        currentMatches = []
        showingMatchOptions = false
        showingPollSummary = false
        pollSummary = nil
        votingStats = nil // NEW: Clear voting stats
        voteCount = 0 // NEW: Reset vote count
        print("🎬 WhatToWatch: Poll closed")
    }
    
    // NEW: Update voting statistics
    private func updateVotingStats() async {
        guard let pollId = activePoll?.id else { 
            print("🎬 DEBUG: updateVotingStats - No active poll")
            return 
        }
        
        print("🎬 DEBUG: updateVotingStats - Starting update for poll: \(pollId)")
        
        do {
            let allVotes = try await polls.fetchVotes(pollId: pollId)
            let pollItems = try await polls.fetchPollItems(pollId: pollId)
            
            print("🎬 DEBUG: updateVotingStats - Got \(allVotes.count) votes and \(pollItems.count) items")
            
            // Count votes per user
            var userVoteCounts: [String: Int] = [:]
            for vote in allVotes {
                userVoteCounts[vote.userId, default: 0] += 1
            }
            
            print("🎬 DEBUG: updateVotingStats - User vote counts: \(userVoteCounts)")
            
            // Fetch actual user names from users table
            var userNames: [String: String] = [:]
            let userIds = Array(userVoteCounts.keys)
            
            do {
                let users = try await polls.fetchUsers(userIds: userIds)
                for user in users {
                    userNames[user.id] = user.name
                }
                print("🎬 DEBUG: updateVotingStats - Fetched \(users.count) user names")
            } catch {
                print("❌ Failed to fetch user names: \(error)")
                // Fallback to shortened IDs if fetching names fails
                for userId in userIds {
                    let shortId = String(userId.suffix(6))
                    userNames[userId] = "User \(shortId)"
                }
            }
            
            let stats = VotingStats(
                userVotes: userVoteCounts,
                totalItems: pollItems.count,
                houseMemberNames: userNames
            )
            
            await MainActor.run {
                votingStats = stats
                print("🎬 DEBUG: updateVotingStats - Updated voting stats: \(stats)")
            }
        } catch {
            print("❌ Failed to update voting stats: \(error)")
        }
    }
}

// MARK: - Data Structures
struct PollSummary {
    let matches: [Movie]
    let winner: Movie?
    let totalVotes: Int
    let participants: Int
}

struct VotingStats {
    let userVotes: [String: Int] // userId -> vote count
    let totalItems: Int
    let houseMemberNames: [String: String] // userId -> display name
}