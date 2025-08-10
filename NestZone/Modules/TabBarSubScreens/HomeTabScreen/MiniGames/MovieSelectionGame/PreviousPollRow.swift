import SwiftUI

struct PreviousPollRow: View {
    let poll: Poll
    @State private var winner: Movie?
    
    var body: some View {
        HStack(spacing: 12) {
            if let winnerMovie = winner {
                if let url = winnerMovie.posterURL {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 44, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 64)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 64)
                    .overlay(
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 16))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(poll.title ?? "Movie Poll")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if let winner = winner {
                    Text("Winner: \(winner.title)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                } else {
                    Text("Loading winner...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                if let created = poll.created {
                    Text(formatDate(created))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        .onAppear {
            Task {
                if let winnerMovie = try? await PollsManager.shared.getPollWinner(pollId: poll.id) {
                    await MainActor.run {
                        self.winner = winnerMovie
                    }
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}