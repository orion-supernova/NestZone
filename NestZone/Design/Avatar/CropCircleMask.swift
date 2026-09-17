import SwiftUI

/// The circle, cut out of a dimmed square.
///
/// Drawn as a hole rather than as a ring over the photo, because the two are
/// not the same promise: a ring says "here is a circle", a hole says "this is
/// what you will get and that is what you are losing". Someone deciding where
/// their own face sits needs the second one.
struct CropCircleMask: View {
    var body: some View {
        Rectangle()
            .fill(Palette.cropScrim)
            .overlay {
                Circle().blendMode(.destinationOut)
            }
            // Confines the blend to this pair. Without it `.destinationOut`
            // punches through everything already drawn beneath, taking the
            // photo and the sheet's background with it.
            .compositingGroup()
            .overlay {
                Circle().strokeBorder(Palette.cropRing, lineWidth: 1)
            }
            // The gesture belongs to the photo underneath.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
