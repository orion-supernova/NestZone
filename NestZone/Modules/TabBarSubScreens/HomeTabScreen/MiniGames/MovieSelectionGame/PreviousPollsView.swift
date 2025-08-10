import SwiftUI

struct PreviousPollsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previousPolls: [Poll] = []
    @State private var isLoading = true
    @State private var pollWinners: [String: Movie] = [:]  // pollId -> winner movie
    @State private var showingDeleteError = false // Error handling
    @State private var deleteErrorMessage = "" // Error message
    @State private var deletingPollIds: Set<String> = [] // NEW: Track which polls are being deleted
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading previous polls...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if previousPolls.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        VStack(spacing: 8) {
                            Text("No Previous Polls")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text("Your completed movie polls will appear here")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(previousPolls) { poll in
                            PollHistoryCard(
                                poll: poll,
                                winner: pollWinners[poll.id],
                                onDelete: {
                                    Task {
                                        await deletePoll(poll)
                                    }
                                },
                                isDeleting: deletingPollIds.contains(poll.id) // NEW: Pass loading state
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await loadPreviousPolls()
                    }
                }
            }
            .navigationTitle("Previous Polls")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadPreviousPolls()
            }
        }
        .alert("Delete Error", isPresented: $showingDeleteError) {
            Button("OK") { }
        } message: {
            Text(deleteErrorMessage)
        }
    }
    
    private func loadPreviousPolls() async {
        do {
            let polls = try await PollsManager.shared.getPreviousPolls(limit: 20)
            
            // Load winners for each poll
            var winners: [String: Movie] = [:]
            for poll in polls {
                if let winner = try? await PollsManager.shared.getPollWinner(pollId: poll.id) {
                    winners[poll.id] = winner
                }
            }
            
            await MainActor.run {
                self.previousPolls = polls
                self.pollWinners = winners
                self.isLoading = false
            }
        } catch {
            print("Failed to load previous polls: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func deletePoll(_ poll: Poll) async {
        // Add to deleting set to show loading
        await MainActor.run {
            deletingPollIds.insert(poll.id)
        }
        
        do {
            // Delete from server (cascade will handle related records)
            try await PollsManager.shared.deletePoll(pollId: poll.id)
            print("✅ Poll deleted from server: \(poll.id)")
            
            // Remove from local list
            await MainActor.run {
                if let index = previousPolls.firstIndex(where: { $0.id == poll.id }) {
                    withAnimation {
                        previousPolls.remove(at: index)
                        pollWinners.removeValue(forKey: poll.id)
                    }
                }
                deletingPollIds.remove(poll.id)
            }
        } catch {
            print("❌ Failed to delete poll from server: \(error)")
            
            await MainActor.run {
                deletingPollIds.remove(poll.id)
                deleteErrorMessage = "Failed to delete poll: \(error.localizedDescription)"
                showingDeleteError = true
            }
        }
    }
}

struct PollHistoryCard: View {
    let poll: Poll
    let winner: Movie?
    let onDelete: () -> Void
    let isDeleting: Bool // NEW: Loading state
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Winner Poster
                if let winner = winner, let posterURL = winner.posterURL {
                    AsyncImage(url: posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.gray)
                            )
                    }
                    .frame(width: 60, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.purple.opacity(0.3), .pink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 90)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.7))
                        )
                }
                
                // Poll Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(poll.title ?? "Movie Poll")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // Delete Button with Loading State
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 32, height: 32)
                        } else {
                            Button {
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                                    .padding(8)
                                    .background(Circle().fill(.red.opacity(0.1)))
                            }
                            .disabled(isDeleting)
                        }
                    }
                    
                    if let winner = winner {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.yellow)
                                Text("Winner:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(winner.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            
                            if let year = winner.year {
                                Text("\(year)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("No winner determined")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    
                    // Date
                    if let created = poll.created {
                        Text(formatDate(created))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 1)
                )
        )
        .opacity(isDeleting ? 0.6 : 1.0) // Dim while deleting
        .scaleEffect(isDeleting ? 0.98 : 1.0) // Slightly shrink while deleting
        .animation(.easeInOut(duration: 0.2), value: isDeleting)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .alert("Delete Poll", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this poll? This action cannot be undone.")
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}