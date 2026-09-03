import SwiftUI

struct ShimmerNoteCard: View {
    @State private var shimmerOffset: CGFloat = -200
    @State private var rotationDirection = Double.random(in: -6...6)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                    .frame(maxWidth: 120)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 16)
                    .frame(maxWidth: 100)
            }
            
            Spacer()
            
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 12)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 30, height: 10)
            }
        }
        .padding(16)
        .frame(width: 160, height: 160)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .rotationEffect(.degrees(rotationDirection))
        .shadow(
            color: .black.opacity(0.15),
            radius: 4,
            x: 1,
            y: 3
        )
    }
}
