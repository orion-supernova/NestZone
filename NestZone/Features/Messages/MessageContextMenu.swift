import SwiftUI
import UIKit

/// What a message's menu is built from. Read when the menu opens, so the
/// bubble can hand over a fresh one on every render at no cost.
struct MessageMenuModel {
    var myEmoji: Set<String>
    var canReply: Bool
    var canCopy: Bool
    var isPinned: Bool
    var canModify: Bool
    var senderName: String
    var handlers: MessageHandlers
}

/// The message menu, as a UIKit context-menu interaction.
///
/// SwiftUI's `contextMenu` says nothing when it opens or closes, and the
/// owner wants everything behind it blurred (`MenuBackdrop`). It is a
/// `.background` of the bubble, never an overlay, so the swipe, the tap and
/// the quote's button keep their touches: UIKit still delivers the long press
/// to the view behind, and SwiftUI's own hit test still favours what is drawn
/// above it.
struct MessageContextMenu: UIViewRepresentable {
    let model: MessageMenuModel
    /// The bubble as a still picture, at a size, scale and appearance.
    let preview: (CGSize, CGFloat, ColorScheme) -> UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(model: model, preview: preview) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))
        context.coordinator.host = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.model = model
        context.coordinator.preview = preview
    }

    @MainActor
    final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        var model: MessageMenuModel
        var preview: (CGSize, CGFloat, ColorScheme) -> UIImage?
        weak var host: UIView?

        init(model: MessageMenuModel, preview: @escaping (CGSize, CGFloat, ColorScheme) -> UIImage?) {
            self.model = model
            self.preview = preview
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                self?.menu()
            }
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
        ) -> UITargetedPreview? { targetedPreview() }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
        ) -> UITargetedPreview? { targetedPreview() }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willDisplayMenuFor configuration: UIContextMenuConfiguration,
            animator: UIContextMenuInteractionAnimating?
        ) {
            guard let window = host?.window else { return }
            MenuBackdrop.shared.show(in: window, animator: animator)
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willEndFor configuration: UIContextMenuConfiguration,
            animator: UIContextMenuInteractionAnimating?
        ) {
            MenuBackdrop.shared.hide(animator: animator)
        }

        /// The bubble itself, in its own rounded shape on no background, so the
        /// lift looks like the bubble coming off the thread.
        private func targetedPreview() -> UITargetedPreview? {
            guard let host, host.bounds.width > 0,
                  let image = preview(
                    host.bounds.size,
                    host.traitCollection.displayScale,
                    host.traitCollection.userInterfaceStyle == .dark ? .dark : .light
                  ) else { return nil }
            let picture = UIImageView(image: image)
            picture.frame = host.bounds
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(
                roundedRect: host.bounds, cornerRadius: 18
            )
            let target = UIPreviewTarget(
                container: host,
                center: CGPoint(x: host.bounds.midX, y: host.bounds.midY)
            )
            return UITargetedPreview(view: picture, parameters: parameters, target: target)
        }

        // MARK: Menu

        private func menu() -> UIMenu {
            let model = model
            let handlers = model.handlers

            let reactions = ReactionEmoji.all.map { emoji -> UIAction in
                let chosen = model.myEmoji.contains(emoji)
                let label = chosen ? L10n.reactionPickerMine(emoji) : L10n.reactionPickerAdd(emoji)
                return UIAction(
                    title: String(localized: label),
                    image: EmojiGlyph.image(emoji, chosen: chosen)
                ) { _ in handlers.react(emoji) }
            }
            let palette = UIMenu(title: "", options: [.displayInline, .displayAsPalette], children: reactions)

            var actions: [UIMenuElement] = []
            if model.canReply {
                actions.append(UIAction(
                    title: String(localized: L10n.messagesReply),
                    image: UIImage(systemName: "arrowshape.turn.up.left")
                ) { _ in handlers.reply() })
            }
            if model.canCopy {
                actions.append(UIAction(
                    title: String(localized: L10n.messagesCopy),
                    image: UIImage(systemName: "doc.on.doc")
                ) { _ in handlers.copy() })
            }
            actions.append(UIAction(
                title: String(localized: model.isPinned ? L10n.messagesUnpin : L10n.messagesPin),
                image: UIImage(systemName: model.isPinned ? "pin.slash" : "pin")
            ) { _ in handlers.togglePin() })

            let tail: [UIMenuElement]
            if model.canModify {
                tail = [
                    UIAction(
                        title: String(localized: L10n.commonEdit),
                        image: UIImage(systemName: "pencil")
                    ) { _ in handlers.edit() },
                    UIAction(
                        title: String(localized: L10n.commonDelete),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive
                    ) { _ in handlers.delete() },
                ]
            } else {
                tail = [
                    UIAction(
                        title: String(localized: L10n.messagesReport),
                        image: UIImage(systemName: "exclamationmark.bubble")
                    ) { _ in handlers.report() },
                    UIAction(
                        title: String(localized: L10n.messagesBlockSender(model.senderName)),
                        image: UIImage(systemName: "hand.raised"),
                        attributes: .destructive
                    ) { _ in handlers.blockSender() },
                ]
            }
            return UIMenu(children: [
                palette,
                UIMenu(title: "", options: .displayInline, children: actions),
                UIMenu(title: "", options: .displayInline, children: tail),
            ])
        }
    }
}
