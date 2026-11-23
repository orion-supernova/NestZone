import SwiftUI
import UIKit
import OSLog

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

/// Where each bubble is and what its menu is built from, so one interaction on
/// the thread's scroll view can answer "which message is under this finger".
/// A plain reference, never observed: scrolling and re-rendering write to it
/// and nothing redraws.
@MainActor
final class ChatMenuRegistry {
    typealias Preview = (CGSize, CGFloat, ColorScheme) -> UIImage?

    struct Entry {
        var frame: CGRect = .zero
        var model: MessageMenuModel?
        var preview: Preview?
    }

    private(set) var entries: [MessageID: Entry] = [:]

    func setFrame(_ id: MessageID, _ frame: CGRect) { entries[id, default: Entry()].frame = frame }

    func setMenu(_ id: MessageID, model: MessageMenuModel, preview: @escaping Preview) {
        entries[id, default: Entry()].model = model
        entries[id, default: Entry()].preview = preview
    }

    func remove(_ id: MessageID) { entries[id] = nil }

    /// The message with a menu whose bubble holds this window point.
    func message(at point: CGPoint) -> MessageID? {
        entries.first { $0.value.model != nil && $0.value.frame.contains(point) }?.key
    }
}

private struct ChatMenuRegistryKey: EnvironmentKey {
    static let defaultValue: ChatMenuRegistry? = nil
}

extension EnvironmentValues {
    var chatMenuRegistry: ChatMenuRegistry? {
        get { self[ChatMenuRegistryKey.self] }
        set { self[ChatMenuRegistryKey.self] = newValue }
    }
}

/// Installs the thread's one `UIContextMenuInteraction`.
///
/// SwiftUI's own content takes the touches over a bubble, so an interaction on
/// a view behind each bubble never heard a long press. This is a zero-weight
/// view inside the scroll content that finds the enclosing `UIScrollView` once
/// it is in a window and puts the interaction there: a recognizer on an
/// ancestor sees the touches of everything inside, beside SwiftUI's own, and
/// the system's long press does not hold back the scroll pan.
struct MessageMenuInteraction: UIViewRepresentable {
    let registry: ChatMenuRegistry

    func makeCoordinator() -> Coordinator { Coordinator(registry: registry) }

    func makeUIView(context: Context) -> Anchor {
        let view = Anchor()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: Anchor, context: Context) {}

    static func dismantleUIView(_ view: Anchor, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Anchor: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { coordinator?.install(from: self) }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        let registry: ChatMenuRegistry
        private weak var scrollView: UIScrollView?
        private var interaction: UIContextMenuInteraction?

        init(registry: ChatMenuRegistry) { self.registry = registry }

        func install(from anchor: UIView) {
            var view = anchor.superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            guard let found = view as? UIScrollView, found !== scrollView else { return }
            uninstall()
            let interaction = UIContextMenuInteraction(delegate: self)
            found.addInteraction(interaction)
            scrollView = found
            self.interaction = interaction
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "chatMenuSelfTest") { runSelfTest() }
            #endif
        }

        func uninstall() {
            if let interaction { scrollView?.removeInteraction(interaction) }
            interaction = nil
            scrollView = nil
        }

        // MARK: Which bubble

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            guard let scrollView else { return nil }
            let point = scrollView.convert(location, to: nil)
            guard let id = registry.message(at: point),
                  let model = registry.entries[id]?.model else { return nil }
            return UIContextMenuConfiguration(
                identifier: id.rawValue as NSString,
                previewProvider: nil
            ) { [weak self] _ in self?.menu(for: model) }
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
        ) -> UITargetedPreview? { targetedPreview(for: configuration) }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
        ) -> UITargetedPreview? { targetedPreview(for: configuration) }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willDisplayMenuFor configuration: UIContextMenuConfiguration,
            animator: UIContextMenuInteractionAnimating?
        ) {
            guard let window = scrollView?.window else { return }
            MenuBackdrop.shared.show(in: window, animator: animator)
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willEndFor configuration: UIContextMenuConfiguration,
            animator: UIContextMenuInteractionAnimating?
        ) {
            MenuBackdrop.shared.hide(animator: animator)
        }

        /// The bubble itself, as a still picture in its own rounded shape on no
        /// background, laid exactly over the bubble it was taken from.
        private func targetedPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
            guard let scrollView, let raw = configuration.identifier as? String,
                  let entry = registry.entries[MessageID(raw)], let render = entry.preview,
                  entry.frame.width > 0,
                  let image = render(
                    entry.frame.size,
                    scrollView.traitCollection.displayScale,
                    scrollView.traitCollection.userInterfaceStyle == .dark ? .dark : .light
                  ) else { return nil }
            let rect = scrollView.convert(entry.frame, from: nil)
            let picture = UIImageView(image: image)
            picture.frame = CGRect(origin: .zero, size: rect.size)
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(roundedRect: picture.bounds, cornerRadius: 18)
            let target = UIPreviewTarget(
                container: scrollView,
                center: CGPoint(x: rect.midX, y: rect.midY)
            )
            return UITargetedPreview(view: picture, parameters: parameters, target: target)
        }

        #if DEBUG
        /// `-chatMenuSelfTest 1`: a long press cannot be made in the simulator,
        /// so this asks the same lookup a long press would, at the newest
        /// bubble's centre, and logs the answer. Presents nothing.
        private func runSelfTest() {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(6))
                for _ in 0..<5 {
                    guard let self, let scrollView, let interaction else { return }
                    let newest = registry.entries
                        .filter { $0.value.model != nil && $0.value.frame.width > 0 }
                        .max { $0.value.frame.maxY < $1.value.frame.maxY }
                    if let newest {
                        let window = CGPoint(x: newest.value.frame.midX, y: newest.value.frame.midY)
                        let found = contextMenuInteraction(
                            interaction,
                            configurationForMenuAtLocation: scrollView.convert(window, from: nil)
                        )?.identifier as? String
                        Self.log.notice("chat menu self-test: \(found.map { "found \($0)" } ?? "none", privacy: .public) (newest \(newest.key.rawValue, privacy: .public), \(self.registry.entries.count) bubbles)")
                        return
                    }
                    try? await Task.sleep(for: .seconds(2))
                }
                Self.log.notice("chat menu self-test: none (no bubbles registered)")
            }
        }

        private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "ChatMenu")
        #endif

        // MARK: Menu

        private func menu(for model: MessageMenuModel) -> UIMenu {
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
