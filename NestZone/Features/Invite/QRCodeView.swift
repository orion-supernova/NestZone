import CoreImage.CIFilterBuiltins
import SwiftUI

/// A QR code, drawn crisp at any size on a white card so it scans in dark
/// mode too (a code is dark modules on a light ground, whatever the theme).
///
/// The modules are rendered once at one pixel each and scaled up with no
/// interpolation, so an edge is never blurred; the image is made off the
/// main thread and only when the text changes.
struct QRCodeView: View {
    let text: String

    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                Color.clear.aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(22)
        .background(.white, in: .rect(cornerRadius: 24))
        .task(id: text) {
            image = await Self.render(text)
        }
    }

    /// Medium error correction: a link's worth of data, and a code that
    /// survives a thumb or a reflection.
    private static func render(_ text: String) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(text.utf8)
            filter.correctionLevel = "M"
            guard let output = filter.outputImage else { return nil }
            return CIContext().createCGImage(output, from: output.extent)
        }.value
    }
}
