import SwiftUI

/// The household's six counters, each a way into the screen it counts.
///
/// Drawn in two places: on Today, for somebody who set the counters to Always,
/// and on its own under House → At a glance, where it lives for everybody.
/// One view, so the two can never disagree about what a tile means.
/// One of the counters, as the thing a tap on it asks for.
public enum HouseStatTile: Equatable, Sendable {
    case tasks, shopping, notes, messages, issues, events
}

struct HouseStatsGrid: View {
    let stats: HomeStats
    let eventsThisWeek: Int
    let statsLoaded: Bool
    let eventsLoaded: Bool
    let open: (HouseStatTile) -> Void

    var body: some View {
        GlassGroup(spacing: 18) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: Metrics.stackSpacing)],
                spacing: Metrics.stackSpacing
            ) {
                // One task tile, not two. It used to carry "Tasks Done" — an
                // all-time total that only ever grows — beside "Issues", a
                // high-priority count that read 0 in any household that never
                // set priority. What is left is the one task number that moves
                // day to day.
                Group {
                    StatTile(
                        title: L10n.homeStatsTodoTitle,
                        value: stats.openTasks,
                        symbol: "checklist.unchecked",
                        tint: Palette.statTasks
                    ) { open(.tasks) }

                    StatTile(
                        title: L10n.homeStatsShoppingTitle,
                        value: stats.shoppingItems,
                        change: stats.shoppingChange,
                        symbol: "cart.fill",
                        tint: Palette.statShopping
                    ) { open(.shopping) }

                    StatTile(
                        title: L10n.homeStatsNotesTitle,
                        value: stats.notes,
                        change: stats.notesChange,
                        symbol: "note.text",
                        tint: Palette.statNotes
                    ) { open(.notes) }

                    StatTile(
                        title: L10n.homeStatsMessagesTitle,
                        value: stats.unreadMessages,
                        change: stats.messagesChange,
                        symbol: "bubble.left.and.bubble.right.fill",
                        tint: Palette.statMessages
                    ) { open(.messages) }

                    // What is still broken. Red when any of it is urgent or
                    // overdue — the one counter here where "3" and "3, one of
                    // them a leak" are different facts.
                    StatTile(
                        title: L10n.homeStatsIssuesTitle,
                        value: stats.openIssues,
                        change: stats.issuesChange,
                        symbol: "wrench.adjustable.fill",
                        tint: stats.urgentIssues > 0 ? Palette.danger : Palette.statIssues
                    ) { open(.issues) }
                }
                // The five counters that come off `stats:forHome`, so they wait
                // on it and on nothing else. A `Group` inside a grid flattens to
                // its children, so the modifier lands on each.
                .redacted(reason: statsLoaded ? [] : .placeholder)

                // Counted from the short agenda rather than added to the
                // server's summary — one capped query answers both, and a badge
                // that could disagree with the list under it is the failure
                // the Finance screen's bill counters were moved client-side to
                // avoid.
                StatTile(
                    title: L10n.homeStatsEventsTitle,
                    value: eventsThisWeek,
                    symbol: "calendar",
                    tint: Palette.statEvents
                ) { open(.events) }
                    .redacted(reason: eventsLoaded ? [] : .placeholder)
            }
        }
    }
}
