import SwiftUI

/// What the hold on a bubble opens: the six reactions, and the things that can
/// be done to the message, as glass pinned to the bubble it belongs to.
///
/// Hand-built rather than `.contextMenu`, for the reasons the thread's
/// `actionsFor` gives: the system menu takes half a second to appear and
/// previews the full-width row. The panel is drawn over the scroll view
/// (`ChatView.overlayPreferenceValue`), where it cannot be clipped.
struct MessageActionsPanel: View {
    /// The emoji this person has already chosen on the message.
    let mine: Set<String>
    let isPinned: Bool
    /// The author's: edit and delete. Everybody else's: report.
    let canModify: Bool
    let canReport: Bool
    let canCopy: Bool
    let react: (String) -> Void
    let reply: () -> Void
    let copy: () -> Void
    let togglePin: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let report: () -> Void

    @Environment(\.theme) private var theme

    static let width: CGFloat = 264

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                reactionBar
                actionList
            }
        }
        .frame(width: Self.width)
    }

    private var reactionBar: some View {
        HStack(spacing: 0) {
            ForEach(ReactionEmoji.all, id: \.self) { emoji in
                Button { react(emoji) } label: {
                    Text(emoji)
                        .font(.title3)
                        .frame(width: 40, height: Metrics.minTapTarget)
                        .background {
                            if mine.contains(emoji) {
                                Circle().fill(theme.accent).opacity(0.28)
                            }
                        }
                        .contentShape(.rect)
                }
                // The tap's own haptic is `ChatView`'s; the press adds none.
                .buttonStyle(.pressableQuiet)
                .accessibilityLabel(Text(mine.contains(emoji)
                    ? L10n.reactionPickerMine(emoji)
                    : L10n.reactionPickerAdd(emoji)))
            }
        }
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var actionList: some View {
        VStack(spacing: 0) {
            row(L10n.messagesReply, symbol: "arrowshape.turn.up.left", action: reply)
            if canCopy {
                divider
                row(L10n.messagesCopy, symbol: "doc.on.doc", action: copy)
            }
            divider
            row(
                isPinned ? L10n.messagesUnpin : L10n.messagesPin,
                symbol: isPinned ? "pin.slash" : "pin",
                action: togglePin
            )
            if canModify {
                divider
                row(L10n.commonEdit, symbol: "pencil", action: edit)
                divider
                row(L10n.commonDelete, symbol: "trash", tint: Palette.danger, action: delete)
            } else if canReport {
                divider
                row(L10n.messagesReport, symbol: "flag", tint: Palette.danger, action: report)
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private var divider: some View {
        Divider().padding(.leading, 44)
    }

    private func row(
        _ title: LocalizedStringResource,
        symbol: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline)
                    .frame(width: 20)
                Text(title).font(.subheadline)
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint ?? Color.primary)
            .padding(.horizontal, 14)
            // Full height, so a fingertip is choosing between rows and not
            // between a row and the edge of one.
            .frame(minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }
}
