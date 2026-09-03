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
    @Published var showingPollTypeSelection = false
    @Published var showingGenrePicker = false
    @Published var showingActorInput = false
    @Published var showingDirectorInput = false
    @Published var showingYearInput = false
    @Published var showingDecadeInput = false
    @Published var isCreatingPoll = false
    @Published var finalWinner: Movie?
    @Published var isLoadingPollMovies = false
    @Published var loadingProgress: Double = 0.0
    @Published var currentMatches: [Movie] = []
    @Published var showingMatchOptions = false
    @Published var showingPollSummary = false
    @Published var pollSummary: PollSummary?
    @Published var votingStats: VotingStats?
    @Published var includeAdultContent = false
    
    // MARK: - Private Properties
    private let polls = PollsManager.shared
    private var pollingTask: Task<Void, Never>?
    private var hasSelectedMatch = false
    private var voteCount = 0
    private let matchCheckInterval = 3
    private var homeChangeObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    init() {
        setupHomeChangeObserver()
    }
    
    deinit {
        pollingTask?.cancel()
        pollingTask = nil
        if let observer = homeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupHomeChangeObserver() {
        homeChangeObserver = NotificationCenter.default.addObserver(
            forName: .homeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleHomeChange()
            }
        }
    }
    
    private func handleHomeChange() async {
        print("🏠 WhatToWatch: Home changed, resetting poll state")
        
        // Close any active poll before switching homes
        await closePollOnServer()
        
        // Check for active poll in the new home
        await checkForActivePoll()
    }
    
    func initialize() async {
        print("🎬 WhatToWatch: Initializing...")
        
        // Check if we have a selected home
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: No home selected, clearing state")
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
            return
        }
        
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
        
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            print("⚠️ WhatToWatch: No home selected")
            return
        }
        
        do {
            if let poll = try await polls.getActivePoll(homeId: homeId) {
                print("🎬 WhatToWatch: Found active poll: \(poll.id)")
                print("🎬 WhatToWatch: Poll status: \(poll.status ?? "nil")")
                print("🎬 WhatToWatch: Poll title: \(poll.title ?? "nil")")
                
                if poll.status == "active" {
                    await joinExistingPoll(poll)
                } else {
                    print("⚠️ WhatToWatch: Poll status is not 'active' (\(poll.status ?? "nil")), ignoring it")
                    print("🎬 WhatToWatch: No valid active poll found")
                }
            } else {
                print("🎬 WhatToWatch: No active poll found")
                
                if let recentPoll = try await polls.getRecentPoll(homeId: homeId) {
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        var allResults: [Movie] = []
        
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
        
        await MainActor.run {
            showingActorInput = false
        }
    }
    
    func startDirectorPoll(_ directorName: String) async {
        print("🎬 WhatToWatch: Starting director poll for: \(directorName)")
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
        await MainActor.run {
            isCreatingPoll = true
        }
        
        let movies = await MovieAPI.shared.searchMovies(query: "", includeAdult: includeAdultContent)
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
        
        guard HomeSelectionManager.shared.selectedHomeId != nil else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
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
                    
                    if cardStack.filter({ $0.isVisible }).count <= 1 {
                        await updateVotingStats()
                    }
                    
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

    private func checkForMatchesForMovie(_ movieId: String) async {
        guard let pollId = activePoll?.id,
              let homeId = HomeSelectionManager.shared.selectedHomeId,
              !hasSelectedMatch else { return }
        
        do {
            let votes = try await polls.fetchVotes(pollId: pollId)
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: homeId)
            
            let allMatchIds = polls.getMatches(votes: votes, houseMemberCount: houseMemberCount)
            
            if allMatchIds.contains(movieId) {
                print("🏆 Movie \(movieId) is a match! Showing all \(allMatchIds.count) matches")
                
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
                    currentMatches = matches
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

    private func checkForMatches() async {
        guard let pollId = activePoll?.id,
              let homeId = HomeSelectionManager.shared.selectedHomeId,
              !hasSelectedMatch else { return }
        
        do {
            let votes = try await polls.fetchVotes(pollId: pollId)
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: homeId)
            
            let matchIds = polls.getMatches(votes: votes, houseMemberCount: houseMemberCount)
            
            if !matchIds.isEmpty {
                print("🏆 Found \(matchIds.count) matches: \(matchIds)")
                
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
        
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            print("⚠️ WhatToWatch: Cannot start poll without selected home")
            return
        }
        
        guard !candidates.isEmpty else {
            print("❌ Cannot create poll with no candidates")
            return
        }
        
        await MainActor.run {
            isLoadingPollMovies = true
            loadingProgress = 0.0
        }
        
        do {
            await MainActor.run {
                loadingProgress = 0.3
            }
            
            let poll = try await polls.createPoll(homeId: homeId, title: title, candidates: candidates, genre: nil)
            print("✅ Poll created successfully: \(poll.id)")
            
            await MainActor.run {
                loadingProgress = 1.0
                activePoll = poll
                isInPoll = true
                isLoadingPollMovies = false
                isCreatingPoll = false
            }
            
            initializeCardStack(with: candidates)
            
        } catch {
            print("❌ Failed to create poll: \(error)")
            print("🎬 Starting local poll as fallback")
            
            await MainActor.run {
                loadingProgress = 1.0
                isInPoll = true
                isLoadingPollMovies = false
                isCreatingPoll = false
            }
            
            initializeCardStack(with: candidates)
        }
    }
    
    private func joinExistingPoll(_ poll: Poll) async {
        print("🎬 WhatToWatch: Joining existing poll: \(poll.id)")
        print("🎬 WhatToWatch: Poll status verification: \(poll.status ?? "nil")")
        
        guard poll.status == "active" else {
            print("❌ WhatToWatch: Refusing to join non-active poll (status: \(poll.status ?? "nil"))")
            return
        }
        
        isLoadingPollMovies = true
        loadingProgress = 0.0
        
        do {
            let currentUserId = await getCurrentUserId()
            print("🎬 DEBUG: Current user ID: '\(currentUserId)'")
            
            async let pollItemsTask = polls.fetchPollItems(pollId: poll.id)
            async let userVotesTask = polls.fetchUserVotes(pollId: poll.id)
            
            let pollItems = try await pollItemsTask
            let userVotes = try await userVotesTask
            
            loadingProgress = 0.2
            
            print("🎬 WhatToWatch: Poll has \(pollItems.count) items")
            print("🎬 WhatToWatch: User has \(userVotes.count) votes")
            
            print("🎬 DEBUG: Poll items:")
            for item in pollItems {
                print("  - \(item.label ?? "Unknown") (ID: \(item.externalId))")
            }
            
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
            
            print("🎬 DEBUG: Unvoted items:")
            for item in unvotedPollItems {
                print("  - \(item.label ?? "Unknown") (ID: \(item.externalId))")
            }
            
            if unvotedPollItems.isEmpty {
                print("🎬 DEBUG: No unvoted items found!")
                print("🎬 DEBUG: This means either:")
                print("  1. User has voted on all items")
                print("  2. There's an ID mismatch between poll items and votes")
                print("  3. User ID is incorrect")
                
                let allVotes = try await polls.fetchVotes(pollId: poll.id)
                print("🎬 DEBUG: All votes in poll (\(allVotes.count) total):")
                for vote in allVotes {
                    print("  - User \(vote.userId): \(vote.targetExternalId ?? "nil") = \(vote.vote ? "YES" : "NO")")
                }
                
                print("🎬 DEBUG: Poll status: \(poll.status ?? "nil")")
                
                if userVotes.isEmpty {
                    print("🎬 DEBUG: User has no votes, forcing all items to be available")
                    
                    loadingProgress = 0.3
                    
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
                    
                    loadingProgress = 1.0
                    
                    activePoll = poll
                    initializeCardStack(with: movies)
                    isInPoll = true
                    isLoadingPollMovies = false
                    
                    await checkForMatches()
                    return
                }
            }
            
            loadingProgress = 0.3
            
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
            
            loadingProgress = 1.0
            
            activePoll = poll
            initializeCardStack(with: movies)
            isInPoll = true
            isLoadingPollMovies = false
            
            if unvotedPollItems.isEmpty && userVotes.count == pollItems.count {
                print("🎬 DEBUG: User has completed voting, updating voting stats")
                await updateVotingStats()
            }
            
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
        // Identity comes from the authenticated Convex session (`users:me`).
        let me: NZUser? = try? await Convex.once("users:me", as: NZUser?.self)
        return me?.id ?? ""
    }
    
    func continuePoll() {
        showingMatchOptions = false
        hasSelectedMatch = false
        currentMatches = []
        voteCount = 0
    }
    
    func endPollWithWinner(_ winner: Movie) async {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            print("⚠️ WhatToWatch: Cannot end poll without selected home")
            return
        }
        
        showingMatchOptions = false
        
        do {
            if let pollId = activePoll?.id {
                try await polls.closePoll(pollId: pollId)
            }
            
            let votes = try await polls.fetchVotes(pollId: activePoll?.id ?? "")
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: homeId)
            
            pollSummary = PollSummary(
                matches: currentMatches,
                winner: winner,
                totalVotes: votes.count,
                participants: houseMemberCount
            )
            
            finalWinner = winner
            showConfetti = true
            showingPollSummary = true
            
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
    
    func endPollCompletely() async {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            print("⚠️ WhatToWatch: Cannot end poll without selected home")
            return
        }
        
        do {
            if let pollId = activePoll?.id {
                try await polls.closePoll(pollId: pollId)
            }
            
            let votes = try await polls.fetchVotes(pollId: activePoll?.id ?? "")
            let houseMemberCount = try await polls.getHouseMemberCount(homeId: homeId)
            
            let winner = currentMatches.first
            
            pollSummary = PollSummary(
                matches: currentMatches,
                winner: winner,
                totalVotes: votes.count,
                participants: houseMemberCount
            )
            
            showingMatchOptions = false
            showingPollSummary = true
            
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
        votingStats = nil
        voteCount = 0
        print("🎬 WhatToWatch: Poll closed")
    }
    
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
            
            var userVoteCounts: [String: Int] = [:]
            for vote in allVotes {
                userVoteCounts[vote.userId, default: 0] += 1
            }
            
            print("🎬 DEBUG: updateVotingStats - User vote counts: \(userVoteCounts)")
            
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
    let userVotes: [String: Int]
    let totalItems: Int
    let houseMemberNames: [String: String]
}