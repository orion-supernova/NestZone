import SwiftUI
import UIKit

/// The system share sheet, for what is only known once a tap has made it (an
/// invite link). `ShareLink` needs its item before it is drawn.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
