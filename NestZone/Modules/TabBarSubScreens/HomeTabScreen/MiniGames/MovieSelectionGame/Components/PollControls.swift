import SwiftUI

struct PollControls: View {
    let hasVisibleCards: Bool
    let isCuratedPoll: Bool
    let onExitPoll: () -> Void
    let onGetNewMovies: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Only show exit button if there are still cards to vote on
            if hasVisibleCards {
                Button(action: onExitPoll) {
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
            
            // Only show "Get New Movies" button if it's not a curated poll
            if !isCuratedPoll {
                Button(action: onGetNewMovies) {
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
    }
}