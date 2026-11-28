import SwiftUI
import VisionKit

/// The camera, reading an invite's QR code. A full screen cover from the join
/// sheet: it hands back the first code it sees and closes; whether the text is
/// one of ours is the join sheet's to decide.
///
/// VisionKit's scanner (not an AVFoundation session of our own): it draws the
/// highlight, handles focus and zoom, and asks for camera access itself on
/// first use. Where it cannot run (no support, or access refused) the screen
/// says so and points at the typed way in.
struct QRScannerScreen: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var found = 0
    /// The scanner could not start (access refused at the prompt, say).
    @State private var failed = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !DataScannerViewController.isSupported {
                message(L10n.joinScanUnavailable)
            } else if failed || !DataScannerViewController.isAvailable {
                VStack(spacing: 16) {
                    message(L10n.joinScanDenied)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Text(L10n.settingsNotificationsOpenSettings)
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .foregroundStyle(.white)
                }
            } else {
                ScannerRepresentable(onFailure: { failed = true }) { text in
                    found += 1
                    onScan(text)
                }
                .ignoresSafeArea()
                VStack {
                    Spacer()
                    Text(L10n.joinScanHint)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.55), in: .capsule)
                        .padding(.bottom, 40)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                    .background(.black.opacity(0.55), in: .circle)
            }
            .padding(16)
            .accessibilityLabel(Text(L10n.commonClose))
        }
        .sensoryFeedback(.success, trigger: found)
    }

    private func message(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(32)
    }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onFailure: () -> Void
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        do { try scanner.startScanning() } catch { onFailure() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var delivered = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !delivered else { return }
            for case let .barcode(code) in addedItems {
                guard let text = code.payloadStringValue else { continue }
                delivered = true
                onScan(text)
                return
            }
        }
    }
}
