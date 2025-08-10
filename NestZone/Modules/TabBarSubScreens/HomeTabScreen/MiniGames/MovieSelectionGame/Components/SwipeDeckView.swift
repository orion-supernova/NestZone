import SwiftUI

struct SwipeDeckView: View {
    let cardStack: [CardViewModel]
    let onSwipeLeft: (CardViewModel) -> Void
    let onSwipeRight: (CardViewModel) -> Void
    let onTap: (Movie) -> Void
    let votingStats: VotingStats? // NEW: Voting statistics
    
    var body: some View {
        ZStack {
            if !cardStack.isEmpty && cardStack.contains(where: { $0.isVisible }) {
                ForEach(cardStack.filter { $0.isVisible }.prefix(3)) { cardViewModel in
                    let displayIndex = cardStack.filter { $0.isVisible }.firstIndex(where: { $0.id == cardViewModel.id }) ?? 0
                    
                    SwipeCard(
                        movie: cardViewModel.movie,
                        onSwipeLeft: { onSwipeLeft(cardViewModel) },
                        onSwipeRight: { onSwipeRight(cardViewModel) },
                        onTap: { onTap(cardViewModel.movie) }
                    )
                    .offset(y: CGFloat(displayIndex) * 8)
                    .scaleEffect(1.0 - CGFloat(displayIndex) * 0.02)
                    .allowsHitTesting(displayIndex == 0)
                    .zIndex(Double(3 - displayIndex))
                }
            } else {
                PollCompleteView(votingStats: votingStats)
            }
        }
        .frame(height: 520)
    }
}

struct PollCompleteView: View {
    let votingStats: VotingStats?
    
    var body: some View {
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
            
            // Voting Statistics
            if let stats = votingStats {
                VStack(spacing: 12) {
                    Text("Voting Progress")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(Array(stats.userVotes.keys.sorted()), id: \.self) { userId in
                            let voteCount = stats.userVotes[userId] ?? 0
                            let userName = stats.houseMemberNames[userId] ?? "Unknown User"
                            let progress = Double(voteCount) / Double(stats.totalItems)
                            
                            HStack(spacing: 12) {
                                Text(userName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .frame(width: 80, alignment: .leading)
                                
                                VStack(spacing: 4) {
                                    HStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: CGFloat(progress * 120), height: 8)
                                        
                                        if progress < 1.0 {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: CGFloat((1.0 - progress) * 120), height: 8)
                                        }
                                    }
                                    .frame(width: 120, alignment: .leading)
                                }
                                
                                Text("\(voteCount)/\(stats.totalItems)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                Text("Waiting for voting statistics...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 480)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: [.green.opacity(0.3), .mint.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
            )
        )
    }
}