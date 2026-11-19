import UIKit

/// The blur behind an open message menu: a strong material and a dark wash
/// over the whole window, nav bar, bars and composer included, so only the
/// lifted bubble and the menu read.
///
/// It is a view of the window, not SwiftUI state: the menu's own window sits
/// above it, so it never takes a touch meant to dismiss the menu, and opening
/// one re-renders nothing in the thread. It rides the interaction's animator,
/// so it fades with the system's lift (and under Reduce Motion, the system's
/// own softened version of that); it is an alpha and nothing else, so there
/// is no travel to take out.
@MainActor
final class MenuBackdrop {
    static let shared = MenuBackdrop()

    private static let scrim = UIColor(Palette.menuScrim)
    private var blur: UIVisualEffectView?

    func show(in window: UIWindow, animator: UIContextMenuInteractionAnimating?) {
        let view: UIVisualEffectView
        if let existing = blur {
            view = existing
        } else {
            view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            view.isUserInteractionEnabled = false
            view.alpha = 0
            let wash = UIView()
            wash.backgroundColor = Self.scrim
            wash.frame = view.contentView.bounds
            wash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.contentView.addSubview(wash)
            blur = view
        }
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        fade(view, to: 1, animator: animator)
    }

    func hide(animator: UIContextMenuInteractionAnimating?) {
        guard let view = blur else { return }
        fade(view, to: 0, animator: animator) { [weak self, weak view] in
            // A menu opened again before this one finished leaves it up.
            if view?.alpha == 0 { view?.removeFromSuperview() }
            if view?.superview == nil { self?.blur = nil }
        }
    }

    private func fade(
        _ view: UIView,
        to alpha: CGFloat,
        animator: UIContextMenuInteractionAnimating?,
        completion: (() -> Void)? = nil
    ) {
        if let animator {
            animator.addAnimations { view.alpha = alpha }
            animator.addCompletion { completion?() }
        } else {
            UIView.animate(withDuration: 0.2) { view.alpha = alpha } completion: { _ in completion?() }
        }
    }
}
