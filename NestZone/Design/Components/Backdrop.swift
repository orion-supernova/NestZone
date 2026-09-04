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

    public init(tint: Color) { self.tint = tint }

    public var body: some View {
        LinearGradient(
            colors: [tint.opacity(colorScheme == .dark ? 0.26 : 0.14), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}
