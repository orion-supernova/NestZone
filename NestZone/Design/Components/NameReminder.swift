import SwiftUI

/// One quiet line for an account with no name: how housemates see it, and the
/// way to fix that. Today draws it at the top; Settings draws the same words
/// under the avatar.
struct NameReminderRow: View {
    let addName: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.accessory)
                .accessibilityHidden(true)
            Text(L10n.nameReminderLine)
                .font(.footnote)
                .foregroundStyle(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: addName) {
                Text(L10n.profileNameAdd)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.accentText)
                    .multilineTextAlignment(.trailing)
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
