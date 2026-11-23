import SwiftUI

/// Bar items and search for a screen that may be one of several kept alive
/// under the same navigation bar.
///
/// The bar belongs to the stack, not to a screen, so every kept segment's
/// items would stand in it at once. These put a screen's items and search
/// there only while it is the segment on show.
extension View {
    /// `toolbar`, for a module's root screen: its items are in the bar only
    /// while it is the segment on screen.
    public func segmentToolbar<Items: ToolbarContent>(
        @ToolbarContentBuilder _ items: () -> Items
    ) -> some View {
        modifier(SegmentToolbar(items: items()))
    }

    /// `searchable`, for a module's root screen: the field is in the bar only
    /// while it is the segment on screen.
    public func segmentSearchable(text: Binding<String>, prompt: Text) -> some View {
        modifier(SegmentSearchable(text: text, prompt: prompt))
    }

    /// `task(id:)`, for work that only makes sense in front of a person: it
    /// runs while the segment is on screen, is cancelled the moment it is not,
    /// and starts again on return. The phase is read here, in a modifier of
    /// its own, so the screen's `body` does not depend on it.
    public func segmentTask<ID: Equatable>(
        id: ID,
        _ action: @escaping @MainActor @Sendable () async -> Void
    ) -> some View {
        modifier(SegmentTask(id: id, action: action))
    }

    /// Lets go of a field's focus when the screen is switched away from, so a
    /// keyboard is not left up over a segment that is no longer showing.
    public func segmentFocus(_ focus: FocusState<Bool>.Binding) -> some View {
        modifier(SegmentFocus(focus: focus))
    }
}

private struct SegmentToolbar<Items: ToolbarContent>: ViewModifier {
    let items: Items
    @LivePhase private var phase

    func body(content: Content) -> some View {
        content.toolbar {
            if phase == .onScreen { items }
        }
    }
}

private struct SegmentSearchable: ViewModifier {
    @Binding var text: String
    let prompt: Text
    @LivePhase private var phase

    // In a background rather than around the screen: a modifier that wrapped
    // the screen in an `if` would rebuild it, state and subscriptions and
    // scroll position, every time the search came and went.
    func body(content: Content) -> some View {
        content
            .background {
                if phase == .onScreen {
                    Color.clear.searchable(text: $text, prompt: prompt)
                }
            }
            // The system puts a minimised search at the far right, past the
            // bell. Placed by hand it takes its turn among the screen's own
            // items (this modifier comes before the screen's `segmentToolbar`),
            // so the bell is the last thing in the bar.
            .toolbar {
                if phase == .onScreen {
                    DefaultToolbarItem(kind: .search, placement: .topBarTrailing)
                }
            }
    }
}

private struct SegmentFocus: ViewModifier {
    var focus: FocusState<Bool>.Binding
    @LivePhase private var phase

    func body(content: Content) -> some View {
        content.onChange(of: phase) { _, phase in
            if phase != .onScreen { focus.wrappedValue = false }
        }
    }
}

private struct SegmentTask<ID: Equatable>: ViewModifier {
    let id: ID
    let action: @MainActor @Sendable () async -> Void
    @LivePhase private var phase

    private struct Key: Equatable {
        let id: ID
        let isOnScreen: Bool
    }

    func body(content: Content) -> some View {
        // `isLive` rather than the phase: the phase lags a tap by a few frames,
        // and a stamp must not outlive it.
        let isOnScreen = $phase.isLive
        content.task(id: Key(id: id, isOnScreen: isOnScreen)) {
            guard isOnScreen else { return }
            await action()
        }
    }
}

// MARK: - At a glance

/// How a House screen opens At a glance without knowing where it is shown.
///
/// The tab sets it for every segment it holds; a screen draws its own button
/// and asks (`HouseStatsButton`), so the counters are an ordinary bar item
/// beside the screen's other tools rather than a control in the switch.
private struct OpenHouseStatsKey: EnvironmentKey {
    static let defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    var openHouseStats: @MainActor () -> Void {
        get { self[OpenHouseStatsKey.self] }
        set { self[OpenHouseStatsKey.self] = newValue }
    }
}

/// House → At a glance, for a House screen's bar. Neutral, like every tool in
/// the bar; the add beside it is the one accent item.
struct HouseStatsButton: View {
    @Environment(\.openHouseStats) private var open

    var body: some View {
        Button(action: open) {
            Image(systemName: "chart.bar.fill")
        }
        .tint(.primary)
        .accessibilityLabel(Text(L10n.hubStatsTitle))
        .accessibilityIdentifier("HouseStatsButton")
    }
}
