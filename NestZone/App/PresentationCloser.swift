import ComposableArchitecture
import UIKit

/// Closes whatever is presented over the tabs, at any depth.
///
/// A notification tap has to land on its destination, not under a sheet that
/// happened to be open: the event composer, Settings' sub-sheets, a chat's
/// photo sheet, the Sparkles store. Every sheet in the app is a SwiftUI
/// presentation bound to state (`sheet(item:)` on a TCA scope, or a Bool), so
/// dismissing the chain from the root hands each binding a `nil`/`false` the
/// way a swipe down does, and the owning feature gets its `.dismiss`.
struct PresentationCloser: Sendable {
    /// Whether anything is presented over the root right now.
    var isPresenting: @MainActor @Sendable () -> Bool
    /// Dismisses the whole chain from the root and returns when it has gone
    /// (or after a second, so a stuck transition cannot swallow the tap).
    /// Does nothing when a system picker or share sheet is in the chain:
    /// those own a hand-off (a picked photo, a shared file) that a forced
    /// dismissal would cut off mid-way.
    var dismissAll: @MainActor @Sendable () async -> Void
}

extension PresentationCloser: DependencyKey {
    static let liveValue = PresentationCloser(
        isPresenting: { root()?.presentedViewController != nil },
        dismissAll: {
            guard let root = root(), root.presentedViewController != nil else { return }
            var chain: [UIViewController] = []
            var next = root.presentedViewController
            while let controller = next { chain.append(controller); next = controller.presentedViewController }
            guard !chain.contains(where: isSystemHandOff) else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let once = Once(continuation)
                root.dismiss(animated: true) { once.finish() }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    once.finish()
                }
            }
        }
    )

    static let testValue = PresentationCloser(isPresenting: { false }, dismissAll: {})

    @MainActor
    private static func root() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    /// The camera, the photo picker, the share sheet, document and print
    /// pickers: out-of-process or mid-hand-off.
    private static func isSystemHandOff(_ controller: UIViewController) -> Bool {
        if controller is UIImagePickerController || controller is UIActivityViewController
            || controller is UIDocumentPickerViewController { return true }
        let name = String(describing: type(of: controller))
        return ["PHPicker", "PhotosPicker", "UIActivity", "ShareSheet", "UIDocumentPicker", "UIPrint"]
            .contains { name.contains($0) }
    }

    @MainActor
    private final class Once {
        private var continuation: CheckedContinuation<Void, Never>?
        init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
        func finish() {
            continuation?.resume()
            continuation = nil
        }
    }
}

extension DependencyValues {
    var presentationCloser: PresentationCloser {
        get { self[PresentationCloser.self] }
        set { self[PresentationCloser.self] = newValue }
    }
}
