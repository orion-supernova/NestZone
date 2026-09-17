import CryptoKit
import SwiftUI

/// Downsamples and caches remote images.
///
/// Three layers, and each one exists because the layer under it is not enough:
///
/// - an `NSCache` of decoded `UIImage`s, keyed by URL *and* pixel size, because
///   the same picture is drawn at thumbnail and hero size on different screens;
/// - `URLCache` for the compressed bytes, which survives launches;
/// - and, for callers that ask for it, the downsampled result on disk.
///
/// The third exists because the second is only a request. `URLCache` stores
/// what the *server* says is storable, so whether a face survives a relaunch
/// would otherwise depend on the `Cache-Control` header on a signed storage URL
/// — and an avatar is drawn on every screen in the app. `.disk` makes it
/// certain, and skips re-decoding the original on the way back in. Posters stay
/// on `.session`: a browsing surface with thousands of images is what `URLCache`
/// and its byte budget are for.
actor ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let memory = DecodedImageCache()
    private let store = ImageDiskCache()
    /// De-duplicates concurrent requests for the same image — a grid scrolling
    /// fast used to start the same download a dozen times.
    private var inFlight: [Key: Task<UIImage?, Never>] = [:]

    /// A URL at one drawn size. Two screens drawing the same avatar at 26 and
    /// 52 points are two entries, which is exactly why `AvatarPhoto.renderSize`
    /// rounds every avatar in the app onto two sizes instead of eight.
    private struct Key: Hashable {
        let url: URL
        let width: Int
        let height: Int

        init(url: URL, pixels: CGSize) {
            self.url = url
            width = Int(pixels.width.rounded())
            height = Int(pixels.height.rounded())
        }

        /// Stable across launches, which is what makes it usable as a filename.
        var identity: String { "\(width)x\(height)|\(url.absoluteString)" }
    }

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "nestzone.images"
        )
        session = URLSession(configuration: configuration)
    }

    /// An already-decoded image, or `nil`. Never touches the disk or the
    /// network.
    ///
    /// Separate from `image(for:)` so a view can answer "do I already have
    /// this?" without suspending. Swapping one avatar for another goes through
    /// here first, so a photo that is already in memory replaces the old one in
    /// the same frame rather than blanking to initials and fading back in.
    func decoded(_ url: URL, pixels: CGSize) -> UIImage? {
        memory.image(forKey: Key(url: url, pixels: pixels).identity)
    }

    func image(
        for url: URL,
        pixels: CGSize,
        persistence: ImagePersistence = .session
    ) async -> UIImage? {
        let key = Key(url: url, pixels: pixels)

        if let cached = memory.image(forKey: key.identity) { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> { [session, store] in
            if persistence == .disk, let image = await store.image(forKey: key.identity) {
                return image
            }
            do {
                let (data, _) = try await session.data(from: url)
                guard let image = Self.downsample(data, to: pixels) else { return nil }
                if persistence == .disk {
                    await store.save(image, forKey: key.identity)
                }
                return image
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result { memory.insert(result, forKey: key.identity) }
        return result
    }

    /// Files an image the app already has, as if it had just been downloaded.
    ///
    /// For the photo a user has this second chosen: the bytes are on the device
    /// already, and the only reason to fetch them back from storage would be
    /// that the cache was not told. Priming under the URL the server answered
    /// with means the subscription's push draws the new avatar immediately,
    /// with no request and no flicker through the initials.
    func prime(
        _ image: UIImage,
        for url: URL,
        pixels: CGSize,
        persistence: ImagePersistence = .session
    ) async {
        let key = Key(url: url, pixels: pixels)
        memory.insert(image, forKey: key.identity)
        if persistence == .disk {
            await store.save(image, forKey: key.identity)
        }
    }

    /// Decodes straight to the pixel size the layout needs. A 500-point-wide
    /// TMDb poster drawn into a 60-point cell used to keep ~1 MB of bitmap
    /// resident; this keeps ~15 KB.
    private static func downsample(_ data: Data, to pixels: CGSize) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(pixels.width, pixels.height),
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// `NSCache` wrapper. Separate type so the actor stays free of `@unchecked`.
private final class DecodedImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init() {
        // Roughly 60 downsampled posters. `NSCache` also evicts under memory
        // pressure on its own.
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: NSString(string: key))
    }

    func insert(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: NSString(string: key), cost: cost)
    }
}
