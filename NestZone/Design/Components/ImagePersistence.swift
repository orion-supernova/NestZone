import Foundation

/// How long a downloaded image should outlive the screen that asked for it.
public enum ImagePersistence: Sendable {
    /// Memory, plus whatever `URLCache` decides to keep.
    ///
    /// Right for a browsing surface — a poster grid is thousands of images that
    /// somebody scrolls past once, and `URLCache`'s byte budget is what keeps
    /// that from becoming a permanent cost.
    case session

    /// Also written to disk at the size it is drawn, and read back from there
    /// before the network is touched.
    ///
    /// Right for the handful of pictures the app draws on nearly every screen.
    /// `.session` cannot promise this: `URLCache` stores what the *server* says
    /// is storable, so a face surviving a relaunch would otherwise hang on the
    /// `Cache-Control` header of a signed storage URL.
    case disk
}
