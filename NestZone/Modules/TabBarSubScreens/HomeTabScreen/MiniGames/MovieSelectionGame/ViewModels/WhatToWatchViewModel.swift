import Foundation
import SwiftUI

@MainActor
class WhatToWatchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isInPoll = false
    @Published var showConfetti = false
    @Published var candidates: [Movie] = []
    @Published var cardStack: [CardViewModel] = []
    @Published var customList: [Movie] = []
    @Published var lastWatched: Movie?
    @Published var watched: [Movie] = []
    @Published var customListTitle: String = ""
    @Published var selectedMovieForDetail: Movie?
    @Published var showingMovieDetail = false
    @Published var activePoll: Poll?
    @Published var currentMatches: [Movie] = []
    @Published var isCuratedPoll = false
    @Published var previousPolls: [Poll] = []
    @Published var showingPreviousPolls = false
    @Published var showingClearHistoryAlert = false
    @Published var showingGenrePicker = false
    @Published var showingSearch = false
    
    // MARK: - Private Properties
    private let polls = PollsManager.shared
    private var pollingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    func initialize() async {
        loadHistory()
        await loadPolls()
    }
    
    func cleanup() {
        stopPolling()
    }
    
    // MARK: - History Management
    private func loadHistory() {
        lastWatched = MovieHistoryManager.shared.lastWatched()
        watched = MovieHistoryManager.shared.allWatched()
    }
    
    func clearHistory() {
        MovieHistoryManager.shared.clearAll()
        lastWatched = nil
        watched = []
    }
    
    // MARK: - Poll Management
    private func loadPolls() async {
        do {
            if let poll = try await polls.getActivePoll(homeId: nil) {
                activePoll = poll
                await joinExistingPoll(poll)
            } else {
                let trending = await MovieAPI.shared.searchMovies(query: "popular")
                candidates = Array(trending.prefix(20))
                initializeCardStack()
            }
            
            let previousPollsData = try await polls.getPreviousPolls(homeId: nil, limit: 5)
            previousPolls = previousPollsData
        } catch {
            print("Failed to load polls: \(error)")
        }
    }
    
    func startGenrePoll(_ genres: [String]) async {
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
        await startNewPoll(title: "Watch: \(genreTitle)", candidates: Array(allResults.prefix(25)), isCurated: true)
    }
    
    func startRandomPoll() async {
        let popularQueries = ["Marvel", "Comedy", "Action", "Drama", "Thriller", "Animation"]
        let selectedQuery = popularQueries.randomElement() ?? "popular"
        let randoms = await MovieAPI.shared.searchMovies(query: selectedQuery)
        await startNewPoll(title: "Quick Poll - \(selectedQuery)", candidates: randoms, isCurated: false)
    }
    
    func startCustomPoll() async {
        let title = customListTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let pollTitle = title.isEmpty ? "Custom Movie List" : title
        await startNewPoll(title: pollTitle, candidates: customList, isCurated: true)
        clearCustomList()
    }
    
    func closePoll() async {
        await closePollOnServer()
    }
    
    func getNewMovies() async {
        guard let pollId = activePoll?.id else { return }
        
        let newMovies = await MovieAPI.shared.searchMovies(query: "movie")
        let moviesToAdd = Array(newMovies.prefix(15))
        
        let existingIds = Set(candidates.map { $0.id })
        let uniqueNewMovies = moviesToAdd.filter { !existingIds.contains($0.id) }
        
        if !uniqueNewMovies.isEmpty {
            candidates.append(contentsOf: uniqueNewMovies)
            
            let startPosition = cardStack.count
            let newCards = uniqueNewMovies.enumerated().map { index, movie in
                CardViewModel(movie: movie, stackPosition: startPosition + index)
            }
            cardStack.append(contentsOf: newCards)
            
            await addMoviesToPoll(pollId: pollId, movies: uniqueNewMovies)
        }
    }
    
    // MARK: - Custom List Management
    func addToCustomList(_ movie: Movie) {
        if !customList.contains(where: { $0.id == movie.id }) {
            customList.append(movie)
        }
    }
    
    func clearCustomList() {
        customList = []
        customListTitle = ""
    }
    
    // MARK: - Voting
    func handleVote(for cardViewModel: CardViewModel, vote: Bool) {
        print("🗳️ SWIPE: \(vote ? "RIGHT (YES)" : "LEFT (NO)") for \(cardViewModel.movie.title)")
        
        if let pollId = activePoll?.id {
            Task {
                do {
                    try await polls.submitVote(pollId: pollId, imdbId: cardViewModel.movie.id, vote: vote, userId: nil)
                    print("✅ Vote submitted successfully")
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
    
    func selectMatch(_ movie: Movie) async {
        showConfetti = true
        MovieHistoryManager.shared.addWatched(movie)
        loadHistory()
        await closePollOnServer()
    }
    
    // MARK: - Private Helper Methods
    private func initializeCardStack() {
        cardStack = candidates.enumerated().map { index, movie in
            CardViewModel(movie: movie, stackPosition: index)
        }
    }
    
    private func startNewPoll(title: String, candidates: [Movie], isCurated: Bool) async {
        do {
            let poll = try await polls.createPoll(homeId: nil, title: title, candidates: Array(candidates.prefix(25)), genre: nil)
            activePoll = poll
            self.candidates = Array(candidates.prefix(25))
            initializeCardStack()
            isInPoll = true
            self.isCuratedPoll = isCurated
            startPolling()
        } catch {
            print("Failed to create poll: \(error)")
            activePoll = nil
            self.candidates = Array(candidates.prefix(25))
            initializeCardStack()
            isInPoll = true
            self.isCuratedPoll = isCurated
        }
    }
    
    private func joinExistingPoll(_ poll: Poll) async {
        do {
            async let pollItemsTask = polls.fetchPollItems(pollId: poll.id)
            async let userVotesTask = polls.fetchUserVotes(pollId: poll.id)
            
            let pollItems = try await pollItemsTask
            let userVotes = try await userVotesTask
            
            let votedImdbIds = Set(userVotes.compactMap { $0.targetExternalId })
            let unvotedPollItems = pollItems.filter { !votedImdbIds.contains($0.externalId) }
            
            let movies: [Movie] = await withTaskGroup(of: Movie?.self) { group in
                for item in unvotedPollItems {
                    group.addTask { await MovieAPI.shared.getDetails(imdbID: item.externalId) }
                }
                var list: [Movie] = []
                for await m in group { if let m { list.append(m) } }
                return list
            }
            
            activePoll = poll
            candidates = movies
            initializeCardStack()
            isInPoll = true
            isCuratedPoll = false
            startPolling()
        } catch {
            print("Failed to join existing poll: \(error)")
            activePoll = nil
            isInPoll = false
        }
    }
    
    private func startPolling() {
        stopPolling()
        guard let pollId = activePoll?.id else { return }
        
        pollingTask = Task { [weak self, pollId] in
            guard let self = self else { return }
            var houseMemberCount = 2
            var lastVoteCount = 0
            
            do {
                houseMemberCount = try await self.polls.getHouseMemberCount(homeId: nil)
            } catch {
                print("Failed to get house member count: \(error)")
            }
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                
                do {
                    let votes = try await self.polls.fetchVotes(pollId: pollId)
                    
                    if votes.count != lastVoteCount {
                        lastVoteCount = votes.count
                        await self.processVotes(votes, houseMemberCount: houseMemberCount, pollId: pollId)
                    }
                } catch {
                    print("Polling error: \(error)")
                }
            }
            
            await MainActor.run { [weak self] in
                self?.showConfetti = false
                self?.currentMatches = []
            }
        }
    }
    
    private func processVotes(_ votes: [PollVote], houseMemberCount: Int, pollId: String) async {
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
            currentMatches = matchMovies.sorted { lhs, rhs in
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
                    loadHistory()
                }
                try? await polls.closePoll(pollId: pollId)
                await MainActor.run {
                    isInPoll = false
                    activePoll = nil
                    currentMatches = []
                }
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
        activePoll = nil
        currentMatches = []
        isCuratedPoll = false
        isInPoll = false
    }
    
    private func addMoviesToPoll(pollId: String, movies: [Movie]) async {
        let startOrder = candidates.count - movies.count
        
        for (index, movie) in movies.enumerated() {
            do {
                try await polls.addMovieToPoll(pollId: pollId, movie: movie, order: startOrder + index)
            } catch {
                print("Failed to add movie to poll: \(error)")
            }
        }
    }
}