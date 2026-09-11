import SwiftUI

/// The shape of a merged-glass list, as one value.
///
/// Every list in the app was assembling this by hand — a `GlassGroup`, a
/// `VStack` with some spacing, and a row that padded itself and called
/// `glassCard`. Same four numbers each time, typed separately, and they had
/// drifted into two different looks: Shopping, Finance and Issues put their
/// rows 8pt apart and fuse into one slab, while Tasks, Movies, Contributions
/// and the rest used 12 and stayed separate cards. Nothing recorded that as a
/// decision; it was just which number got typed.
///
/// **The merge threshold is measured, not documented.** On iPhone 17 / iOS
/// 26.5, at a container spacing of 24: a 12pt gap stays separate, 11 stays
/// separate, 8 fuses, 2 fuses. At spacing 60 a 12pt gap fuses. So rows join
/// when the gap is roughly a third of the container spacing or less — not
/// merely less than it, which is what the old `glassMergeDistance` comment
/// implied. `GlassListLab` is where those numbers came from and where to check
/// any new pair — its "copy as GlassListStyle" button puts the tuned value on
/// the pasteboard, ready to paste over `.default` below.
public struct GlassListStyle: Equatable, Sendable {

    /// How far apart two glass shapes can be and still reach for each other.
    /// This is `GlassEffectContainer`'s spacing, not a gap you can see.
    public var containerSpacing: CGFloat

    /// The gap between rows — the number that actually decides whether the
    /// list reads as one slab or as separate cards.
    public var rowGap: CGFloat

    public var rowRadius: CGFloat
    public var rowPaddingH: CGFloat
    public var rowPaddingV: CGFloat

    /// Whether the row surface leans toward the finger.
    ///
    /// Leaning means *tracking* — the glass follows the touch for as long as it
    /// is down, which is one more claim on a touch a row in a `ScrollView` is
    /// already sharing with the vertical pan, and a row with `SwipeToDelete`
    /// with a horizontal drag as well. It is on because the feedback is worth
    /// it; if a swipe starts missing on some row, that row passes
    /// `glassRow(interactive: false)` and keeps the rest of the style.
    public var rowInteractive: Bool

    public init(
        containerSpacing: CGFloat,
        rowGap: CGFloat,
        rowRadius: CGFloat,
        rowPaddingH: CGFloat,
        rowPaddingV: CGFloat,
        rowInteractive: Bool
    ) {
        self.containerSpacing = containerSpacing
        self.rowGap = rowGap
        self.rowRadius = rowRadius
        self.rowPaddingH = rowPaddingH
        self.rowPaddingV = rowPaddingV
        self.rowInteractive = rowInteractive
    }

    /// The house list. **Change these five numbers and every list changes.**
    ///
    /// Tuned on `GlassListLab`, 2026-09-10: rows 8pt apart in a 15pt container,
    /// cornered at 32. That pair sits on the *separate* side of the measured
    /// threshold — 8 is more than 15 ÷ 3 — on purpose: at this radius the rows
    /// read as pills rather than as one slab, and the gap between them is the
    /// only thing keeping them legible as separate tasks. To fuse them instead,
    /// drop `rowGap` to 5 or raise `containerSpacing` past 24.
    ///
    /// A row much shorter than these (a bare title, no second line) will be a
    /// full capsule at radius 32. Worth a look on Contributions and Dinner,
    /// whose rows are the tightest in the app.
    public static let `default` = GlassListStyle(
        containerSpacing: 15,
        rowGap: 8,
        rowRadius: 32,
        rowPaddingH: Metrics.cardPadding,
        rowPaddingV: 10,
        rowInteractive: true
    )

    /// The old look: tighter corners, a wider gap. Kept as the fallback for a
    /// list whose items are unrelated enough that pills would oversell them,
    /// and as the one-edit way back if the house style turns out wrong on
    /// device.
    public static let cards = GlassListStyle(
        containerSpacing: 24,
        rowGap: Metrics.stackSpacing,
        rowRadius: Metrics.tightRadius,
        rowPaddingH: Metrics.cardPadding,
        rowPaddingV: 10,
        rowInteractive: false
    )

    /// A one-off, spelled as a difference from the house style rather than as
    /// a fresh set of five numbers: `.default.with(rowGap: 4)`.
    public func with(
        containerSpacing: CGFloat? = nil,
        rowGap: CGFloat? = nil,
        rowRadius: CGFloat? = nil,
        rowPaddingH: CGFloat? = nil,
        rowPaddingV: CGFloat? = nil,
        rowInteractive: Bool? = nil
    ) -> GlassListStyle {
        GlassListStyle(
            containerSpacing: containerSpacing ?? self.containerSpacing,
            rowGap: rowGap ?? self.rowGap,
            rowRadius: rowRadius ?? self.rowRadius,
            rowPaddingH: rowPaddingH ?? self.rowPaddingH,
            rowPaddingV: rowPaddingV ?? self.rowPaddingV,
            rowInteractive: rowInteractive ?? self.rowInteractive
        )
    }
}

extension EnvironmentValues {
    /// Read by `GlassList` and by `glassRow()`, so a row's padding and radius
    /// come from the same value as the gap above it and cannot fall out of step
    /// with it.
    @Entry public var glassListStyle: GlassListStyle = .default
}

extension View {
    /// Overrides the list style for a subtree — a screen, a section, one list.
    public func glassListStyle(_ style: GlassListStyle) -> some View {
        environment(\.glassListStyle, style)
    }
}

/// A stack of glass rows that merge as the style says they should.
///
/// Replaces the `GlassGroup { VStack(spacing:) { … } }` pair that every list
/// wrote out. Side padding stays at the call site: how far a list sits from the
/// edge of the screen is that screen's layout, not part of how its rows join.
public struct GlassList<Content: View>: View {
    @Environment(\.glassListStyle) private var inherited

    private let override: GlassListStyle?
    private let content: Content

    /// `style` is for the rare list that has to differ. Everything else takes
    /// the house style, or whatever a `glassListStyle(_:)` above it set.
    public init(style: GlassListStyle? = nil, @ViewBuilder content: () -> Content) {
        self.override = style
        self.content = content()
    }

    private var style: GlassListStyle { override ?? inherited }

    public var body: some View {
        GlassGroup(spacing: style.containerSpacing) {
            VStack(spacing: style.rowGap) { content }
                // The rows read the same value the gap came from, so a custom
                // style reaches the row surface without being passed down by
                // hand.
                .environment(\.glassListStyle, style)
        }
        // `GlassEffectContainer` builds its merge geometry from `spacing` when
        // the container is created and does not rebuild it when the value
        // shrinks: raising the spacing widens the region and shows up, lowering
        // it leaves the rows fused until something else invalidates the effect
        // graph. (Toggling a `glassEffectUnion` id does invalidate it, which is
        // why that looked like a workaround.) Re-identifying on the spacing
        // makes a decrease land like an increase.
        //
        // The cost is a rebuild of the list whenever the *spacing* changes. In
        // the app it never does — a style is a constant — so this is free
        // there, and it is the difference between a live bench and a dead one
        // in `GlassListLab`.
        .id(style.containerSpacing)
    }
}

extension View {
    /// The row surface: the style's padding, radius and lean, as glass.
    ///
    /// Replaces the `.padding(…).frame(maxWidth:).glassCard(cornerRadius:)`
    /// tail every row carried. `interactive` is `nil` by default, meaning "take
    /// the house answer" — pass `false` only for a row whose gesture is losing
    /// to the lean, and say which gesture in a comment when you do.
    public func glassRow(tinted: Color? = nil, interactive: Bool? = nil) -> some View {
        modifier(GlassRow(tint: tinted, interactive: interactive))
    }
}

/// A stable resting angle for a card, the way `StickyNote` pins a note: right
/// side up at a negative angle, and the same card keeps its angle across every
/// redraw and scroll.
///
/// Seeded by a string rather than by `String.hashValue`, which Swift seeds per
/// process — with that, every card would reshuffle on every launch.
///
/// **A `GlassEffectContainer` discards this.** It renders its shapes in its own
/// space and drops a child's transform, so a row inside `GlassList` draws
/// perfectly level whatever angle it is given — measured on the bench. Tilt
/// belongs to the `List`-based screens, whose rows have no container over them.
///
/// Where it does apply, the angle costs vertical room: `rotationEffect` turns
/// the drawing, not the slot, so a rotated row needs `width · sin(angle)` more
/// space than it has — about 6pt per degree at full width.
public func restingTilt(seed: String, spread: Double) -> Double {
    guard spread != 0 else { return 0 }
    var hash: UInt64 = 5381
    for byte in seed.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
    return Double(hash % 201) / 100 * spread - spread
}

/// A row in a real `List`, stripped of the List's chrome so the glass card is
/// the whole surface: clear background, no separator, and insets that put the
/// screen's padding at the sides and the style's row gap underneath.
///
/// **Any list whose rows swipe belongs in a `List`, not in `GlassList`.** The
/// native swipe only exists there, and every hand-built one loses the touch to
/// something — the scroll pan, an interactive glass surface leaning toward the
/// finger, a button deciding what a press is. `UISwipeActionsConfiguration` has
/// always handled the cases that kept coming back: a drag the scroll view
/// cancels, a row committed off the edge, a reveal that grows from nothing.
///
/// The cost is the merge. A `GlassEffectContainer` cannot span List cells, so
/// these rows are glass but never fuse. At the house gap nothing fuses anyway,
/// so today that costs nothing — if the style ever goes back to a fusing pair,
/// the swiping lists will be the ones that stay separate.
extension View {
    public func glassListRow(insets: EdgeInsets? = nil) -> some View {
        modifier(GlassListRow(insets: insets))
    }
}

private struct GlassListRow: ViewModifier {
    @Environment(\.glassListStyle) private var style

    let insets: EdgeInsets?

    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(insets ?? EdgeInsets(
                top: 0,
                leading: Metrics.screenPadding,
                bottom: style.rowGap,
                trailing: Metrics.screenPadding
            ))
    }
}

private struct GlassRow: ViewModifier {
    @Environment(\.glassListStyle) private var style

    let tint: Color?
    let interactive: Bool?

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, style.rowPaddingH)
            .padding(.vertical, style.rowPaddingV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(
                cornerRadius: style.rowRadius,
                tinted: tint,
                interactive: interactive ?? style.rowInteractive
            )
    }
}
