import SwiftUI

/// The search field under the navigation bar while a chat is being searched.
/// Filters what is loaded, on this phone; nothing goes to the server.
struct ChatSearchBar: View {
    @Binding var text: String
    let resultCount: Int
    let close: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondaryText)
            TextField(text: $text) { Text(L10n.chatSearchPlaceholder) }
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Text(resultCount, format: .number)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondaryText)
                    .accessibilityLabel(Text(L10n.chatSearchResults(resultCount)))
            }
            Button(action: close) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondaryText)
                    .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(L10n.chatSearchClose))
        }
        .padding(.leading, 14)
        .frame(minHeight: Metrics.minTapTarget)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 4)
        .onAppear { isFocused = true }
    }
}
