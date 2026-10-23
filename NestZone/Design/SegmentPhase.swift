import SwiftUI

/// Where a module's screen stands among its tab's segments.
///
/// A grouped tab keeps every segment it has shown alive, so the screens that
/// are not on show are still there, drawn at no opacity. This is what they are
/// told, so that what only makes sense in front of a person — a bar button, a
/// search field, an entrance, a breathing pulse — can wait for them.
///
/// Set per segment by `SegmentedRoot`, so a switch changes the value of the two
/// screens it concerns and invalidates only the views that read it there.
/// Never read it in a screen's own `body`: it changes three times in a switch,
/// and a large body re-run for each is the cost this exists to avoid. The
/// modifiers that need it (`segmentTask`, `segmentToolbar`, `appear` ...) read
/// it in a body of their own, a few lines long.
///
/// An environment value is inherited by everything under the view that sets
/// it, and that includes a sheet or a `navigationDestination(item:)` declared
/// inside a segment. Those must never take the segment's phase — a sheet
/// opened from a segment keeps its own toolbar, search and entrances whatever
/// the segment behind it is doing — so every reader goes through
/// `LivePhase`, which answers `onScreen` for anything presented.
///
/// Only the segment chosen can become `onScreen`, but it does so a few frames
/// after the tap: `SegmentedRoot` stages a switch (see there). In those frames
/// the page being left is still `onScreen` and the one arriving is `leaving`.
/// An entrance only plays on the way *into* `onScreen`, so it can only play on
/// the page that arrived; what must not outlast the tap at all asks
/// `segmentChosen`, which moves with it.
///
/// What is deliberately not gated: an alert. A write that failed after its
/// segment was switched away from presents over the segment now showing, and
/// that is right — its copy names what did not stick, and the person needs to
/// hear it promptly more than they need to hear it on the right tab.
public enum SegmentPhase: Sendable {
    /// The segment being shown.
    case onScreen
    /// The one just switched away from, while it fades out. It still looks as
    /// it did, so its entrances are left alone until it has gone.
    case leaving
    /// Gone and invisible. Entrances are put back to their start here, behind
    /// the opacity, so they have somewhere to play from when it returns.
    case away
}

extension EnvironmentValues {
    @Entry public var segmentPhase: SegmentPhase = .onScreen
    /// Whether the segment is the one chosen, at the tap rather than a few
    /// frames after it as `segmentPhase` is. Read only by `segmentTask`, so
    /// that work which must stop the moment a segment is left does, and the
    /// rows' entrances do not hear of the tap twice.
    @Entry public var segmentChosen: Bool = true
}

/// A reader of `segmentPhase` that presented content cannot be fooled by.
///
/// `isPresented` is true in a sheet or a pushed destination and false at the
/// root of a tab, so a presented view is `onScreen` whatever segment it was
/// opened from.
@propertyWrapper
public struct LivePhase: DynamicProperty {
    @Environment(\.segmentPhase) private var inherited
    @Environment(\.isPresented) private var isPresented

    public init() {}

    @Environment(\.segmentChosen) private var chosen

    public var wrappedValue: SegmentPhase { isPresented ? .onScreen : inherited }

    /// `onScreen` and chosen: in front of a person, and not on its way out.
    public var isLive: Bool { isPresented || (inherited == .onScreen && chosen) }

    public var projectedValue: LivePhase { self }
}
