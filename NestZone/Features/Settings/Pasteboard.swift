import ComposableArchitecture
import UIKit

/// Copying to the clipboard, behind a dependency so tests never touch the real
/// pasteboard.
@DependencyClient
public struct PasteboardClient: Sendable {
    public var copy: @Sendable (String) -> Void
}

extension PasteboardClient: DependencyKey {
    public static let liveValue = PasteboardClient(
        copy: { text in
            MainActor.assumeIsolated { UIPasteboard.general.string = text }
        }
    )

    public static let testValue = PasteboardClient()
}

extension DependencyValues {
    public var pasteboard: PasteboardClient {
        get { self[PasteboardClient.self] }
        set { self[PasteboardClient.self] = newValue }
    }
}
