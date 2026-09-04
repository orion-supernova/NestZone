import SwiftUI

/// Liquid Glass surfaces.
///
/// The app previously faked glass with `.ultraThinMaterial` under a
/// `Color.white.opacity(0.1)` overlay, a hairline stroke and a drop shadow —
/// four layers per card, none of them refracting anything. `glassEffect` is one
/// layer, is rendered by the system, and actually bends the content behind it.
///
/// House rules, because glass stops reading as glass when it is everywhere:
/// - Glass goes on things that *float*: controls, chips, bars, sheets, cards
///   over content. Never on a full-screen background — there is nothing behind
///   it to refract, and it costs a blur pass for nothing.
/// - Sibling glass shapes belong in a `GlassEffectContainer` so the system can
///   merge and morph them instead of compositing each one separately.
/// - Tint sparingly, and only with the theme accent.
extension View {

    /// The standard card surface: glass in a continuous rounded rectangle.
    public func glassCard(
        cornerRadius: CGFloat = Metrics.cardRadius,
        tinted: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            .regular.tint(tinted).interactive(interactive),
            in: .rect(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    /// A floating control — toolbar button, filter chip, FAB.
    public func glassControl(tinted: Color? = nil) -> some View {
        glassEffect(.regular.tint(tinted).interactive(), in: .capsule)
    }

    /// The lightest treatment, for glass sitting over busy imagery (a poster, a
    /// photo) where `.regular` would wash the picture out.
    public func glassOverlay(cornerRadius: CGFloat = Metrics.cardRadius) -> some View {
        glassEffect(.clear, in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Shared geometry, so corner radii and insets agree across features that no
/// longer share a file.
public enum Metrics {
    public static let cardRadius: CGFloat = 20
    public static let tightRadius: CGFloat = 14
    public static let screenPadding: CGFloat = 20
    public static let cardPadding: CGFloat = 16
    public static let stackSpacing: CGFloat = 12
    public static let sectionSpacing: CGFloat = 24
    /// Spacing at which sibling glass shapes start merging into one another.
    public static let glassMergeDistance: CGFloat = 24
    /// Apple's minimum comfortable hit target.
    public static let minTapTarget: CGFloat = 44
    /// Bottom padding for scrolling content under the floating Liquid Glass tab
    /// bar. The bar hovers over the content rather than sitting below it, so the
    /// last row needs room or it ends up behind the glass.
    public static let scrollBottomInset: CGFloat = 92
}

/// A card. The single surface primitive the whole app builds on.
public struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let tint: Color?
    private let content: Content

    public init(
        cornerRadius: CGFloat = Metrics.cardRadius,
        padding: CGFloat = Metrics.cardPadding,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: cornerRadius, tinted: tint)
    }
}

/// Groups sibling glass shapes so the system merges them as they approach and
/// morphs between them when they change. Wrap any row or grid of glass elements
/// in this — separately-composited glass is both slower and visually flatter.
public struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = Metrics.glassMergeDistance, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) { content }
    }
}
