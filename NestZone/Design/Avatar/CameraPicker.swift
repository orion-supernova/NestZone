import SwiftUI
import UIKit

/// The system camera, for taking a profile photo on the spot.
///
/// The one piece of UIKit in this module, because there is no SwiftUI camera:
/// `PhotosPicker` reads the library and nothing more. `UIImagePickerController`
/// is the supported way to capture a still without building a whole
/// `AVCaptureSession`, a preview layer and an orientation story of our own —
/// which is a camera app, not a profile screen.
///
/// Nothing is written to the library. The capture goes straight into the crop
/// editor, so the app never needs permission to add photos, only to use the
/// camera (`NSCameraUsageDescription`).
struct CameraPicker: UIViewControllerRepresentable {
    let onCaptured: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    /// False on the simulator and on any device with no usable camera, which is
    /// why the sheet asks before it offers the row.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraDevice = .front
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCaptured: onCaptured, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        private let onCaptured: (Data) -> Void
        private let dismiss: () -> Void

        init(onCaptured: @escaping (Data) -> Void, dismiss: @escaping () -> Void) {
            self.onCaptured = onCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { dismiss() }
            guard let image = info[.originalImage] as? UIImage else { return }
            // Barely compressed: this is the *source* for the crop, and the one
            // that reaches the server is re-encoded from it. Compressing twice
            // is where a photo starts to look like a photo of a photo.
            guard let data = image.jpegData(compressionQuality: 0.95) else { return }
            onCaptured(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
