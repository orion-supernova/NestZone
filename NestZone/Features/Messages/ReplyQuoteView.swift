import SwiftUI

/// The quote a reply carries inside its bubble: who said it and the start of
/// what they said. A tap asks the thread to scroll to the original; the thread
/// does nothing when it is not loaded.
struct ReplyQuoteView: View {
    let name: String
    let snippet: String
    let kind: Message.Kind?
    let isMine: Bool
    let tapped: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isMine ? Color.white : theme.accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Text(Self.plain(snippet: snippet, kind: kind))
                    .font(.caption2)
                    .lineLimit(2)
                    .opacity(0.85)
            }
            .multilineTextAlignment(.leading)
        }
        .foregroundStyle(isMine ? Color.white : Color.primary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        // A tap, not a `Button`: a hold on the quote still has to open the
        // bubble's own menu.
        .onTapGesture(perform: tapped)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(L10n.replyQuoteAccessibility(name, Self.plain(snippet: snippet, kind: kind))))
    }

    /// A picture has no words to quote; it says what it is, in the reader's
    /// language.
    static func plain(snippet: String, kind: Message.Kind?) -> String {
        if kind == .image, snippet.isEmpty { return String(localized: L10n.messagesPhoto) }
        return snippet
    }
}
