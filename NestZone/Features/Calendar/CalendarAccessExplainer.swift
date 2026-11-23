import SwiftUI

/// What NestZone will do with the person's calendars, said before the system
/// asks. Shown by whichever screen is about to ask (Settings, the composer) and
/// never at launch; its button is what leads to the system prompt.
struct CalendarAccessExplainer: View {
    let isWorking: Bool
    let onContinue: () -> Void
    let onNotNow: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.accentText)
                .padding(.top, 8)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(L10n.calendarAccessTitle)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(L10n.calendarAccessBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                PrimaryButton(L10n.calendarAccessContinue, isLoading: isWorking, action: onContinue)
                SecondaryButton(L10n.calendarAccessNotNow, action: onNotNow)
            }
        }
        .padding(Metrics.screenPadding)
        .frame(maxWidth: .infinity)
        .background(Backdrop(tint: theme.accent))
        .presentationDetents([.height(380), .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
    }
}
