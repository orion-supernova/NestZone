import SwiftUI

/// What the picker button looks like: an avatar, a camera badge, and a spinner
/// while a change is in flight.
///
/// Its own view because it is the only part that redraws on a gesture, and
/// because `AvatarPickerButton` is otherwise all flow and no layout.
struct AvatarPickerFace: View {
    let initials: String
    let seed: String
    let photo: URL?
    /// A crop confirmed locally but not yet loadable from the server. Takes
    /// precedence over `photo`, which for that moment is still the old one.
    let pending: UIImage?
    let size: CGFloat
    let isBusy: Bool

    /// Sized off the circle, like the initials inside it, and floored so the
    /// badge is still a badge on a small avatar.
    private var badge: CGFloat { max(18, size * 0.34) }

    var body: some View {
        face
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay {
                // A ternary rather than an `if`, so the spinner's arrival does
                // not restructure the view and restart the circle beneath it.
                Palette.busyScrim
                    .opacity(isBusy ? 1 : 0)
                    .clipShape(.circle)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                            .opacity(isBusy ? 1 : 0)
                    }
                    .animation(Motion.fade, value: isBusy)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: badge * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: badge, height: badge)
                    .background(Palette.violet, in: .circle)
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
                    .opacity(isBusy ? 0 : 1)
                    .animation(Motion.fade, value: isBusy)
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var face: some View {
        if let pending {
            Image(uiImage: pending)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Avatar(initials: initials, seed: seed, size: size, source: .photo(photo))
        }
    }
}
