import SwiftUI

/// Whose face this is, and the way out.
///
/// Floats over the photo on glass rather than sitting in a bar above it: the
/// picture is the point, and a chrome bar would take a strip of it on every
/// screen to hold two things that only need to be findable.
struct AvatarViewerBar: View {
    let name: String
    let close: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: close) {
                Label {
                    Text(L10n.commonClose)
                } icon: {
                    Image(systemName: "xmark")
                }
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .background(Palette.viewerControl, in: .circle)
            // Icon-only on screen, never to VoiceOver — `Label` keeps the words
            // and `.iconOnly` only stops them being drawn.
            .accessibilityLabel(Text(L10n.commonClose))
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 10)
        .glassOverlay(cornerRadius: 22)
        .padding(.horizontal, Metrics.screenPadding)
    }
}
