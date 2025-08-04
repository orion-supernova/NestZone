import SwiftUI

struct MessagesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            // Empty state for messages
            VStack(spacing: 16) {
                Image(systemName: "message.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("No Messages Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Messages between household members will appear here")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    RadialGradient(
                        colors: [
                            selectedTheme.colors(for: colorScheme).background,
                            Color.blue.opacity(0.05),
                            Color.cyan.opacity(0.03)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 500
                    )
                }
            )
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        MessagesView()
    }
}