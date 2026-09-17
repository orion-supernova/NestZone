import CryptoKit
import SwiftUI

/// Downsampled images, on disk, at the size they are drawn.
///
/// Deliberately not a second `URLCache`. What is stored here is the *result* —
/// already downsampled, already upright — so a cold launch draws a household's
/// faces without decoding a single original, and without asking the network
/// whether it still has them. That is the whole point: an avatar appears beside
/// a name on nearly every screen in the app, and it should be there before the
/// first frame, on a train, with no signal.
///
/// Its own actor rather than part of `ImageLoader` so that a file read never
/// stalls the in-flight bookkeeping. `ImageLoader` suspends on these calls and
/// is free to answer other screens while one of them is waiting on the disk.
actor ImageDiskCache {
    /// Small enough to be unremarkable next to a photo library, large enough
    /// for every face, board thumbnail and problem photograph a household will
    /// look at twice.
    ///
    /// Raised when house-problem photos joined avatars in here: a face is about
    /// 20 KB on disk and a board thumbnail a few, but the detail screen's strip
    /// caches at the size it draws, and a household that photographs everything
    /// would otherwise start evicting the avatars it draws on every screen.
    private static let budget = 64 * 1024 * 1024
    /// Re-encoded at the size it is drawn, so this is a thumbnail's worth of
    /// JPEG rather than an original's.
    private static let quality: CGFloat = 0.85

    private let directory: URL
    private let manager = FileManager.default
    /// The trim is a directory walk, so it happens once per launch, after the
    /// first write — never on the path that is trying to draw something.
    private var hasTrimmed = false

    init(name: String = "nestzone.thumbnails") {
        directory = URL.cachesDirectory.appending(path: name, directoryHint: .isDirectory)
    }

    func image(forKey key: String) -> UIImage? {
        let file = location(for: key)
        guard let data = try? Data(contentsOf: file) else { return nil }
        // Touched on every hit so the trim below can tell a face somebody sees
        // daily from one seen once. Best-effort: a cache that cannot record an
        // access still works, it just forgets less cleverly.
        try? manager.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path)
        return UIImage(data: data)
    }

    func save(_ image: UIImage, forKey key: String) {
        guard let data = image.jpegData(compressionQuality: Self.quality) else { return }
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            // Atomic: a write interrupted by the app being killed would
            // otherwise leave a truncated file that decodes to a broken image
            // and is never retried, because something *is* cached.
            try data.write(to: location(for: key), options: .atomic)
        } catch {
            // A cache that cannot write is a cache that misses. Nothing to say
            // to the user about it, and nothing to stop drawing over it.
            return
        }
        guard !hasTrimmed else { return }
        hasTrimmed = true
        trim()
    }

    /// Hashed, because the key holds a URL: it is longer than a filename may
    /// be, and full of characters a path cannot carry.
    private func location(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: name + ".jpg", directoryHint: .notDirectory)
    }

    /// Drops the least recently used files until the folder is inside budget.
    private func trim() {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        ) else { return }

        let entries = files.compactMap { url -> (url: URL, date: Date, size: Int)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let date = values.contentModificationDate,
                  let size = values.fileSize
            else { return nil }
            return (url, date, size)
        }

        var total = entries.reduce(0) { $0 + $1.size }
        guard total > Self.budget else { return }
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            guard total > Self.budget else { return }
            try? manager.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}
