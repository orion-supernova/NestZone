import SwiftUI

/// An image loaded from the network, decoded once and cached.
///
/// Replaces `AsyncImage`, which the movie screens leaned on heavily.
/// `AsyncImage` re-downloads and re-decodes on every appearance — scrolling a
/// poster grid back and forth re-fetched every cell — and it decodes at full
/// resolution regardless of the frame it is drawn into. This downsamples to the
/// target size and keeps the decoded result, so a scroll back through a grid is
/// free. See `ImageLoader` for what "keeps" means at each layer.
public struct RemoteImage<Placeholder: View>: View {
    /// What a load is *for*. Changing either half means a different picture, so
    /// both belong in `task(id:)` — the size because a decoded image is cached
    /// per pixel size, and the URL for the obvious reason.
    private struct Request: Equatable {
        let url: URL?
        let pixels: CGSize
    }

    private let url: URL?
    private let targetSize: CGSize
    private let contentMode: ContentMode
    private let persistence: ImagePersistence
    private let placeholder: Placeholder

    /// The scene's scale, not `UIScreen.main.scale`. The old reading was a hop
    /// to the main actor from inside the loader on every single request, and it
    /// was the wrong screen's answer for anything on an external display.
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    public init(
        url: URL?,
        targetSize: CGSize,
        contentMode: ContentMode = .fill,
        persistence: ImagePersistence = .session,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.persistence = persistence
        self.placeholder = placeholder()
    }

    private var pixels: CGSize {
        CGSize(
            width: targetSize.width * displayScale,
            height: targetSize.height * displayScale
        )
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
        .task(id: Request(url: url, pixels: pixels)) { await load() }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }

        // Ask for what is already decoded first, and take it without
        // suspending. A picture the app has seen arrives in the same frame,
        // rather than blanking to the placeholder and fading back in.
        if let ready = await ImageLoader.shared.decoded(url, pixels: pixels) {
            image = ready
            return
        }

        // A *different* picture is on its way, so stop drawing the last one.
        //
        // This line is the fix for a real bug: the guard here used to read
        // `image == nil`, which meant a view whose URL changed — someone
        // replacing their avatar, a cell reused for another poster — never
        // loaded the new one and showed the old picture for the rest of its
        // life. Nothing reset it, because nothing was watching the URL.
        image = nil
        image = await ImageLoader.shared.image(
            for: url, pixels: pixels, persistence: persistence
        )
    }
}

extension RemoteImage where Placeholder == ImagePlaceholder {
    public init(
        url: URL?,
        targetSize: CGSize,
        contentMode: ContentMode = .fill,
        persistence: ImagePersistence = .session
    ) {
        self.init(
            url: url,
            targetSize: targetSize,
            contentMode: contentMode,
            persistence: persistence
        ) {
            ImagePlaceholder()
        }
    }
}

/// A shimmering block that holds the image's space while it loads, so a grid
/// never reflows as pictures arrive.
public struct ImagePlaceholder: View {
    @State private var shimmer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                // A never-ending sweep is exactly what Reduce Motion is for,
                // and it keeps a display link alive for as long as anything
                // is still loading.
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
            .accessibilityHidden(true)
    }
}
