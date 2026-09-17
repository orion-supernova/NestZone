import CoreGraphics
import Foundation

/// How hard to squeeze a picture, and how far it may be squeezed.
///
/// A plan rather than a quality constant, because quality does not *predict* a
/// size — it is a knob on an encoder, and the same 0.85 that gives 90 KB for a
/// plain background gives half a megabyte for a face in front of foliage. A
/// household that never looks at a picture again still downloads whatever it
/// produced, on every device, forever. The budget is the only way to say how
/// large a picture may actually be.
public struct PhotoCompressionPlan: Sendable {
    /// The ceiling. `PhotoCompressor` walks quality and then size until the
    /// result is under it.
    public let byteBudget: Int

    /// Quality steps, best first.
    ///
    /// None of these go near zero: past about a third, a photograph gains
    /// blocking around exactly the detail somebody took the picture for, and
    /// the honest answer to "still too big" is fewer pixels, not worse ones —
    /// which is what `edgeLadder` is.
    public let qualitySteps: [CGFloat]

    /// Longest-edge limits, largest first. The first is the size a picture
    /// keeps when quality alone is enough, which for a photograph it nearly
    /// always is.
    public let edgeLadder: [CGFloat]

    /// Whether HEIC may be written.
    ///
    /// It is around half the bytes of JPEG at a quality nobody can tell apart,
    /// so this is most of the saving where it is allowed. It is not allowed
    /// everywhere: a picture whose storage URL might be opened outside this app
    /// has to be in a format every viewer can decode, and HEIC is not that.
    public let allowsHEIC: Bool

    public init(
        byteBudget: Int,
        qualitySteps: [CGFloat],
        edgeLadder: [CGFloat],
        allowsHEIC: Bool
    ) {
        self.byteBudget = byteBudget
        self.qualitySteps = qualitySteps
        self.edgeLadder = edgeLadder
        self.allowsHEIC = allowsHEIC
    }
}
