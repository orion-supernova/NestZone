import SwiftUI

struct SwipeDeckView: View {
    let cardStack: [CardViewModel]
    let onSwipeLeft: (CardViewModel) -> Void
    let onSwipeRight: (CardViewModel) -> Void
    let onTap: (Movie) -> Void
    
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
                PollCompleteView()
            }
        }
        .frame(height: 500)
    }
}

struct PollCompleteView: View {
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