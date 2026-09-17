import SwiftUI

/// Up to two letters on the colour that stands for one person.
///
/// The colour comes from `MemberTint`, which derives it from the id — so the
/// same member is the same colour on every screen and across devices with
/// nothing to store, and their avatar matches their slice of the contributions
/// ring.
///
/// Its own type because it is the placeholder inside `Avatar` *and* the thing
/// drawn when there is no photo at all, which are the same picture and must not
/// drift into being two.
struct AvatarInitials: View {
    let initials: String
    let seed: String
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(MemberTint.gradient(for: seed))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    // Sized off the circle rather than off Dynamic Type, which
                    // is the one place in this app that is right: the circle is
                    // a fixed ornament beside text that does scale, and letters
                    // that grew independently of it would climb out of their
                    // own background. The name it sits next to carries the
                    // meaning, and scales.
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
