import SwiftUI

/// The one pinned message, slim, under the navigation bar. Glass, because it
/// floats over the thread. A tap goes to the message; the cross takes it down.
struct PinnedBar: View {
    let pin: PinnedMessage
    let senderName: String
    let goTo: () -> Void
    let unpin: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: goTo) {
                HStack(spacing: 10) {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(senderName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondaryText)
                            .lineLimit(1)
                        Text(ReplyQuoteView.plain(snippet: pin.snippet, kind: pin.kind))
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 14)
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(L10n.pinnedBarAccessibility(
                senderName, ReplyQuoteView.plain(snippet: pin.snippet, kind: pin.kind)
            )))

            Button(action: unpin) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondaryText)
                    .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(L10n.pinnedBarUnpin))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 4)
    }
}
