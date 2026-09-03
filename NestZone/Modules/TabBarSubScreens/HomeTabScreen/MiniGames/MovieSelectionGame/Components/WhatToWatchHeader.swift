import SwiftUI

struct WhatToWatchHeader: View {
    let theme: ThemeColors
    let isInPoll: Bool
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.whatToWatchTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.text, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(isInPoll ? LocalizationManager.whatToWatchInPollInstructions : LocalizationManager.whatToWatchNoInPollInstructions)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "film.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
    }
}

#Preview {
    WhatToWatchHeader(
        theme: AppTheme.basic.colors(for: .light),
        isInPoll: false
    )
    .padding()
}

#Preview("In Poll") {
    WhatToWatchHeader(
        theme: AppTheme.basic.colors(for: .light),
        isInPoll: true
    )
    .padding()
}