import SwiftUI

struct PreviousPollsSection: View {
    let polls: [Poll]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Previous Polls")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                Spacer()
                Button("View All", action: onViewAll)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            
            LazyVStack(spacing: 10) {
                ForEach(polls.prefix(3)) { poll in
                    PreviousPollRow(poll: poll)
                }
            }
        }
    }
}