import Foundation
import UIKit

/// Work the first screen would otherwise do for the first time, done on a
/// background thread while the launch screen waits for the session.
///
/// The first `Text` built from a `LocalizedStringResource` costs far more than
/// the ones after it: SwiftUI parses it as Markdown, and the first parse looks
/// up every attribute scope the runtime knows of (a protocol-conformance scan)
/// and loads the Markdown library. The tab bar's labels are the first such
/// text, so that cost used to land inside the frame that draws the tab bar, on
/// the main thread, with a person looking at it (about 200 ms of a 590 ms
/// frame in a Release build on the simulator). Those lookups are process-wide
/// caches and thread-safe, so doing one here, off the main thread, leaves the
/// real one with nothing to find.
enum LaunchWarmup {
    static func start() {
        // The Keychain question the launch decision asks (see the store).
        KeychainTokenStore.primeLaunchLookup()
        Task.detached(priority: .userInitiated) {
            // The same route SwiftUI takes for `Text(LocalizedStringResource)`:
            // the catalog's string, parsed as Markdown, then handed to UIKit.
            let text = AttributedString(
                localized: String.LocalizationValue("tab_bar_home"),
                bundle: .main,
                locale: L10n.locale
            )
            _ = try? NSAttributedString(text, including: \.uiKit)
        }
    }
}
