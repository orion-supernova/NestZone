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
    @Published var currentMatches: [Movie] = []
    @Published var showingGenrePicker = false
    
    // MARK: - Private Properties
    private let polls = PollsManager.shared
    private var pollingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    func initialize() async {
        await checkForActivePoll()
    }
    
    func cleanup() {
        stopPolling()
    }
    
    // MARK: - Poll Management
    private func checkForActivePoll() async {
        do {
            if let poll = try await polls.getActivePoll(homeId: nil) {
                await joinExistingPoll(poll)
            }
        } catch {
            print("Failed to check for active poll: \(error)")
        }
    }
    
    func startGenrePoll(_ genres: [String]) async {
        var allResults: [Movie] = []
        
        // Get movies from selected genres
        for genre in genres {
            let results = await MovieAPI.shared.searchByGenre(genre: genre)
            for movie in results {
                if !allResults.contains(where: { $0.id == movie.id }) {
                    allResults.append(movie)
                }
            }
        }
        
        // Shuffle and take 20
        allResults = allResults.shuffled()
        let selectedMovies = Array(allResults.prefix(20))
        
        await startNewPoll(title: "Movie Poll", candidates: selectedMovies)
    }
    
    func closePoll() async {
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
        
        // Wait a bit for confetti, then close poll
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task { await self.closePollOnServer() }
        }
    }
    
    // MARK: - Private Helper Methods
    private func initializeCardStack(with candidates: [Movie]) {
        cardStack = candidates.enumerated().map { index, movie in
            CardViewModel(movie: movie, stackPosition: index)
        }
    }
    
    private func startNewPoll(title: String, candidates: [Movie]) async {
        do {
            let poll = try await polls.createPoll(homeId: nil, title: title, candidates: candidates, genre: nil)
            activePoll = poll
            initializeCardStack(with: candidates)
            isInPoll = true
            startPolling()
        } catch {
            print("Failed to create poll: \(error)")
            // Even if server fails, start local poll
            initializeCardStack(with: candidates)
            isInPoll = true
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
            initializeCardStack(with: movies)
            isInPoll = true
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
                }
                try? await polls.closePoll(pollId: pollId)
                
                // Wait for confetti then close
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    Task {
                        await MainActor.run {
                            self.isInPoll = false
                            self.activePoll = nil
                            self.currentMatches = []
                        }
                    }
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
        isInPoll = false
        showConfetti = false
    }
}