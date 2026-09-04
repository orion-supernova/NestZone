import SwiftUI
import os

/// An image loaded from the network, decoded once and cached in memory.
///
/// Replaces `AsyncImage`, which the movie screens leaned on heavily. `AsyncImage`
/// re-downloads and re-decodes on every appearance — scrolling a poster grid
/// back and forth re-fetched every cell — and it decodes at full resolution
/// regardless of the frame it is drawn into. This downsamples to the target size
/// and keeps the decoded result, so a scroll back through a grid is free.
public struct RemoteImage<Placeholder: View>: View {
    private let url: URL?
    private let targetSize: CGSize
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    public init(
        url: URL?,
        targetSize: CGSize,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .animation(Motion.fade, value: image == nil)
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url, image == nil else { return }
        isLoading = true
        defer { isLoading = false }
        image = await ImageLoader.shared.image(for: url, targetSize: targetSize)
    }
}

extension RemoteImage where Placeholder == ImagePlaceholder {
    public init(url: URL?, targetSize: CGSize, contentMode: ContentMode = .fill) {
        self.init(url: url, targetSize: targetSize, contentMode: contentMode) {
            ImagePlaceholder()
        }
    }
}

/// A shimmering block that holds the image's space while it loads, so a grid
/// never reflows as pictures arrive.
public struct ImagePlaceholder: View {
    @State private var shimmer = false

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .scaleEffect(x: 0.4, anchor: .leading)
                .offset(x: shimmer ? 400 : -200)
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Downsamples and caches remote images.
///
/// Two layers: `URLCache` for the compressed bytes (survives launches) and an
/// `NSCache` of already-decoded `UIImage`s keyed by URL *and* target size, since
/// the same poster is drawn at thumbnail and hero size in different screens.
actor ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let decoded = DecodedImageCache()
    /// De-duplicates concurrent requests for the same image — a grid scrolling
    /// fast used to start the same download a dozen times.
    private var inFlight: [Key: Task<UIImage?, Never>] = [:]

    private struct Key: Hashable {
        let url: URL
        let width: Int
        let height: Int
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

    func image(for url: URL, targetSize: CGSize) async -> UIImage? {
        let scale = await MainActor.run { UIScreen.main.scale }
        let pixels = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        let key = Key(url: url, width: Int(pixels.width), height: Int(pixels.height))

        if let cached = decoded.image(forKey: key) { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> { [session] in
            do {
                let (data, _) = try await session.data(from: url)
                return Self.downsample(data, to: pixels)
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result { decoded.insert(result, forKey: key) }
        return result
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

    func image(forKey key: some Hashable) -> UIImage? {
        cache.object(forKey: NSString(string: String(describing: key)))
    }

    func insert(_ image: UIImage, forKey key: some Hashable) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: NSString(string: String(describing: key)), cost: cost)
    }
}
