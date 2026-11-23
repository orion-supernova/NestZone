import SwiftUI

/// One soft wash behind glass.
///
/// Glass has to have something to refract, and a flat system background gives it
/// nothing. This is deliberately the *only* backdrop in the app: screens used to
/// each hand-roll their own stack of gradients and blurred circles, which drifted
/// apart visually and cost a full-screen blur per frame.
public struct Backdrop: View {
    private let tint: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(tint: Color) { self.tint = tint }

    public var body: some View {
        LinearGradient(
            // The theme's character, quieter than it was (0.26 and 0.14): the
            // top of every screen is where the first card sits, and a strong
            // wash there is the surface the smallest text has to be read on.
            // Text roles are checked against this value (readability.html).
            // With Reduce Transparency on, no wash at all: a flat ground is what
            // the person asked for, and it is the surface the roles were solved on.
            colors: [reduceTransparency ? .clear : tint.opacity(colorScheme == .dark ? 0.20 : 0.11), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}
