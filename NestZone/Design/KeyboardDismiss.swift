import SwiftUI
import UIKit

/// Ends editing on a tap anywhere outside the field being edited.
///
/// One recogniser on the window rather than an `.onTapGesture` on every screen
/// that happens to contain a field. The keyboard can come up on any of them —
/// an amount, a title, a search box, a message — and putting it away by tapping
/// the page is something people expect everywhere, not something each view
/// should have to remember to offer.
///
/// It is deliberately invisible to everything else on screen:
///
/// - `cancelsTouchesInView` stays `false`, so the tap still reaches whatever is
///   under it. Dismissing the keyboard is a side effect of the tap, not a
///   replacement for it — tapping a button while typing should press the button
///   *and* close the keyboard.
/// - It recognises simultaneously with every other gesture, so it does not
///   compete with the ledger's swipe, a scroll, or a long press.
/// - It ignores taps that land on another text field, because that tap is a
///   request to move the cursor. Without this, going from one field to the next
///   would close the keyboard and immediately reopen it.
@MainActor
final class KeyboardDismisser: NSObject {
    static let shared = KeyboardDismisser()

    private var isInstalled = false

    /// Idempotent, and a no-op until there is a window to attach to.
    func install() {
        guard !isInstalled else { return }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else { return }

        let tap = UITapGestureRecognizer(target: self, action: #selector(endEditing))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        isInstalled = true
    }

    @objc private func endEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension KeyboardDismisser: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        // A tap that lands in another field is a request to put the cursor
        // there, and closing the keyboard under it would be wrong twice: the
        // field would take focus again a moment later and the keyboard would
        // slide back up, having flashed away for no reason.
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }
}
