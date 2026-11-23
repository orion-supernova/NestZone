import ComposableArchitecture
import SwiftUI

// MARK: - The bell

/// The toolbar button, and the panel it opens.
///
/// One view rather than a button in one file and a sheet in another: the badge
/// and the panel read the same store and are the same feature, and separating
/// them would mean two call sites to keep in step.
extension View {
    /// Presents the notification panel whenever a bell asks for it.
    ///
    /// Attached once, above the tabs, rather than by each bell: there is a
    /// bell on every tab, a `TabView` keeps tabs it has shown alive, and five
    /// sheets bound to one flag is four too many for SwiftUI to present.
    public func inboxPanel(_ store: StoreOf<InboxFeature>) -> some View {
        modifier(InboxPanelHost(store: store))
    }
}

private struct InboxPanelHost: ViewModifier {
    @Bindable var store: StoreOf<InboxFeature>

    func body(content: Content) -> some View {
        content.hostedSheet(isPresented: $store.isOpen) {
            InboxPanel(store: store)
        }
    }
}

public struct InboxBell: View {
    @Bindable var store: StoreOf<InboxFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped only when the count goes up — see `body`.
    @State private var rings = 0

    public init(store: StoreOf<InboxFeature>) {
        self.store = store
    }

    public var body: some View {
        Button { store.send(.bellTapped) } label: {
            Image(systemName: "bell")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.primary)
                // Rings when something arrives, and only then. It used to key
                // on the total itself, so reading things — the count going
                // *down* — rang it too, as if more had come.
                .symbolEffect(.wiggle.byLayer, options: .nonRepeating, value: rings)
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        // The system's own badge: iOS 26 draws it on the toolbar item, outside
        // its glass capsule. An overlay offset from the button's corner was cut
        // by that capsule.
        .badge(store.badge.hasUnread ? Text(store.badge.pipText) : nil)
        .animation(Motion.spring, value: store.badge.total)
        // Silent under Reduce Motion: the glyph and the pip still change, the
        // bell just does not swing.
        .onChange(of: store.badge.total) { old, new in
            if new > old, !reduceMotion { rings += 1 }
        }
        .accessibilityLabel(Text(L10n.inboxOpenPanel))
        .accessibilityValue(
            store.badge.hasUnread
                ? Text(L10n.inboxUnreadCount(store.badge.total))
                : Text(L10n.inboxNothingNew)
        )
    }

}

// MARK: - The panel

/// Two feeds behind one button.
///
/// The separation is the design, and it goes all the way down: two tables, two
/// queries, two watermarks — and here, two visual languages. The household's
/// side is a *timeline*, grouped by day, one line per thing somebody did, with
/// their face on it. The app's side is a *changelog*: full-width cards with a
/// version, a kind and a body you are meant to actually read. Nobody should
/// need the header to know which one they are looking at.
struct InboxPanel: View {
    @Bindable var store: StoreOf<InboxFeature>

    @Environment(\.theme) private var theme
    @Namespace private var switcherGlass
    /// Your own taps on the switcher. The tick keys on these rather than on the
    /// tab, which the bell also sets when it opens the panel on the side with
    /// something new. The filters are `Chip`s, which tick on their own.
    @State private var selectionTaps = 0
    /// Your own taps on "Mark all read".
    @State private var markReadTaps = 0
    /// Stretches the person has opened. Held here, not in the rows, so a lazy
    /// stack recycling one off screen does not close it behind them.
    @State private var openRuns: Set<ActivityID> = []
    /// Versions the person has opened or closed against their default.
    @State private var versionOverrides: [String: Bool] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)

                VStack(spacing: 0) {
                    switcher
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.bottom, 8)

                    // Switched on the tab rather than paged, because the two
                    // sides have different scroll positions, different filters
                    // and different lengths — a `TabView` would carry one's
                    // offset into the other.
                    Group {
                        switch store.tab {
                        case .activity: activityFeed
                        case .updates: updateFeed
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(Motion.fade, value: store.tab)
            .sensoryFeedback(.selection, trigger: selectionTaps)
            .sensoryFeedback(.impact(weight: .light), trigger: markReadTaps)
            .navigationTitle(Text(L10n.inboxTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // `closeTapped` lowers `isOpen`, which is what the sheet
                    // is bound to — calling `dismiss()` as well would be a
                    // second dismissal racing the first.
                    Button { store.send(.closeTapped) } label: {
                        Text(L10n.commonClose)
                    }
                }
                ToolbarItem(placement: .primaryAction) { overflow }
            }
            .task { await store.send(.panelTask).finish() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .hostedSheet(item: $store.scope(state: \.admin, action: \.admin)) {
            InboxAdminView(store: $0)
        }
        .hostedSheet(item: $store.scope(state: \.reports, action: \.reports)) {
            ReportsView(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    /// Mark-all-read and the admin door, folded into one menu.
    ///
    /// A menu rather than two buttons because the admin entry exists for one
    /// account in the whole app, and a toolbar that reserves a slot for it
    /// leaves a hole on everybody else's screen.
    private var overflow: some View {
        Menu {
            Button {
                markReadTaps += 1
                store.send(.markAllReadTapped)
            } label: {
                Label { Text(L10n.inboxMarkAllRead) } icon: {
                    Image(systemName: "checkmark.circle")
                }
            }
            .disabled(!store.badge.hasUnread)

            if store.badge.isAdmin || store.isModerator {
                Divider()
            }
            if store.badge.isAdmin {
                Button {
                    store.send(.adminTapped)
                } label: {
                    Label { Text(L10n.inboxAdminOpen) } icon: {
                        Image(systemName: "hammer.fill")
                    }
                }
            }
            // Two people read what was reported out of somebody's chat. The
            // door exists for them and for nobody else.
            if store.isModerator {
                Button {
                    store.send(.reportsTapped)
                } label: {
                    Label { Text(L10n.moderationOpen) } icon: {
                        Image(systemName: "flag.fill")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accessoryStrong)
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .contentShape(.circle)
        }
        .accessibilityLabel(Text(L10n.commonMore))
    }

    // MARK: Switcher

    /// The two sides, as one control.
    ///
    /// Sibling glass in a `GlassGroup` so the system merges the two capsules
    /// rather than compositing them separately, and the selected one carries
    /// its own unread count — which is the whole reason this is not a plain
    /// `Picker`: "3" beside Activity and "1" beside Updates is the answer to the
    /// question that made somebody tap the bell.
    private var switcher: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(InboxFeature.State.Tab.allCases) { tab in
                    switcherButton(tab)
                }
            }
        }
    }

    private func switcherButton(_ tab: InboxFeature.State.Tab) -> some View {
        let isSelected = store.tab == tab
        let count = tab == .activity ? store.badge.activity : store.badge.updates

        return Button {
            if !isSelected { selectionTaps += 1 }
            store.send(.tabSelected(tab))
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.symbol)
                    .font(.footnote.weight(.semibold))
                Text(tab.title)
                    .font(.subheadline.weight(.semibold))
                if count > 0 {
                    Text(count > store.badge.cap ? "\(store.badge.cap)+" : "\(count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.white.opacity(0.28) : theme.accent.opacity(0.16),
                            in: .capsule
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
            .background {
                if isSelected {
                    Capsule().fill(theme.accentFill)
                        .matchedGeometryEffect(id: "inboxTab", in: switcherGlass)
                }
            }
            .glassEffect(isSelected ? .identity : .regular.interactive(), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .animation(Motion.spring, value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: The household's feed

    private var activityFeed: some View {
        VStack(spacing: 0) {
            filterBar

            if store.isLoadingActivity {
                SkeletonList(rows: 6, height: 68)
                    .padding(.horizontal, Metrics.screenPadding)
                Spacer(minLength: 0)
            } else if store.sections.isEmpty {
                emptyActivity
            } else {
                let starts = rowStarts(store.sections)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                        ForEach(Array(store.sections.enumerated()), id: \.element.id) { index, section in
                            daySection(section, startingAt: starts[index])
                        }
                        feedFooter
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, Metrics.screenPadding)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }

    /// The filters: what kind, and whether to hide what has been read.
    ///
    /// Only categories the household actually has get a chip. A filter
    /// guaranteed to come back empty is a filter that wastes a tap, and twelve
    /// of them would push the ones that matter off the right-hand edge.
    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Chip(
                    String(localized: L10n.inboxFilterUnread),
                    symbol: store.unreadOnly ? "largecircle.fill.circle" : "circle",
                    isSelected: store.unreadOnly
                ) {
                    store.send(.unreadOnlyToggled)
                }

                Divider().frame(height: 22)

                Chip(
                    String(localized: L10n.inboxFilterAll),
                    isSelected: store.category == nil
                ) {
                    store.send(.categorySelected(nil))
                }

                ForEach(store.categoryCounts.present, id: \.category) { entry in
                    Chip(
                        "\(String(localized: entry.category.label)) \(entry.count)",
                        symbol: entry.category.symbol,
                        isSelected: store.category == entry.category
                    ) {
                        store.send(.categorySelected(entry.category))
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    /// One day, as one card.
    ///
    /// A card per day rather than a card per row. Thirty glass surfaces is
    /// thirty blur passes for a list that reads perfectly well as a grouped
    /// one, and the day is the unit somebody is actually scanning for.
    private func daySection(_ section: ActivitySection, startingAt start: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .groupLabel()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                let starts = section.runs.reduce(into: [start]) { $0.append($0[$0.count - 1] + $1.rows.count) }
                ForEach(Array(section.runs.enumerated()), id: \.element.id) { index, run in
                    runView(run, startingAt: starts[index])
                    if index < section.runs.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            // Clipped so an unread wash stops at the card's corners.
            .clipShape(.rect(cornerRadius: Metrics.cardRadius, style: .continuous))
            .glassCard()
        }
    }

    /// A single row as it always was, or a stretch with its rows under it.
    @ViewBuilder
    private func runView(_ run: ActivityRun, startingAt start: Int) -> some View {
        if run.isMerged {
            let isOpen = openRuns.contains(run.id)
            VStack(spacing: 0) {
                ActivityRunHeader(
                    run: run,
                    isNew: run.rows.contains { store.state.isNew($0) },
                    isOpen: isOpen
                ) {
                    withAnimation(reduceMotion ? Motion.fade : Motion.spring) {
                        if isOpen { openRuns.remove(run.id) } else { openRuns.insert(run.id) }
                    }
                }

                if isOpen {
                    ForEach(Array(run.rows.enumerated()), id: \.element.id) { index, row in
                        Divider().padding(.leading, 60)
                        ActivityRow(
                            row: row,
                            isNew: store.state.isNew(row),
                            order: start + index,
                            inRun: true,
                            action: { store.send(.rowTapped(row)) }
                        )
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
            .clipped()
        } else {
            ActivityRow(
                row: run.first,
                isNew: store.state.isNew(run.first),
                order: start,
                action: { store.send(.rowTapped(run.first)) }
            )
        }
    }

    /// Where each day's rows begin in the feed as a whole, so a wave down the
    /// list keeps going across the day cards instead of restarting in each.
    private func rowStarts(_ sections: [ActivitySection]) -> [Int] {
        var starts: [Int] = []
        var running = 0
        for section in sections {
            starts.append(running)
            running += section.rows.count
        }
        return starts
    }

    /// The end of the list: more to load, or the reason there is not.
    @ViewBuilder
    private var feedFooter: some View {
        if store.hasMore && !store.unreadOnly {
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            }
            .frame(height: 44)
            // The trigger for the next page. `onAppear` on the footer rather
            // than on the last row, so the fetch starts as the bottom comes
            // into view instead of after it has been reached.
            .onAppear { store.send(.reachedEnd) }
        } else if store.unreadOnly {
            EmptyView()
        } else if !store.sections.isEmpty {
            Text(L10n.inboxRetentionNote(store.retentionDays))
                .font(.caption)
                .foregroundStyle(.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var emptyActivity: some View {
        if store.isFiltered {
            EmptyStateView(
                title: L10n.inboxEmptyFilteredTitle,
                message: L10n.inboxEmptyFilteredMessage,
                symbol: "line.3.horizontal.decrease.circle",
                action: .init(title: L10n.inboxClearFilters) {
                    if store.unreadOnly { store.send(.unreadOnlyToggled) }
                    store.send(.categorySelected(nil))
                }
            )
        } else {
            EmptyStateView(
                title: L10n.inboxEmptyActivityTitle,
                message: L10n.inboxEmptyActivityMessage,
                symbol: "house"
            )
        }
    }

    // MARK: The changelog

    private var updateFeed: some View {
        Group {
            if store.isLoadingUpdates {
                SkeletonList(rows: 4, height: 64)
                    .padding(.horizontal, Metrics.screenPadding)
            } else if store.updateRows.isEmpty {
                EmptyStateView(
                    title: L10n.inboxEmptyUpdatesTitle,
                    message: L10n.inboxEmptyUpdatesMessage,
                    symbol: "sparkles"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.pinnedUpdates) { update in
                            UpdateCard(update: update, isNew: store.state.isNew(update), showsVersion: true)
                        }

                        ForEach(Array(store.updateGroups.enumerated()), id: \.element.id) { index, group in
                            let isOpen = versionOverrides[group.id] ?? opensByDefault(group, at: index)
                            UpdateGroupView(
                                group: group,
                                seenAt: store.seenUpdatesAt,
                                isOpen: isOpen
                            ) {
                                withAnimation(reduceMotion ? Motion.fade : Motion.spring) {
                                    versionOverrides[group.id] = !isOpen
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, Metrics.screenPadding)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }

    /// Open without being asked: the newest shelf, anything this build is
    /// still waiting for, and the newest one it does have.
    private func opensByDefault(_ group: UpdateGroup, at index: Int) -> Bool {
        #if DEBUG
        // `-inboxOpenVersions N` opens the first N shelves and no others, to
        // look at the closed rows below them.
        if UserDefaults.standard.object(forKey: "inboxOpenVersions") != nil {
            return index < UserDefaults.standard.integer(forKey: "inboxOpenVersions")
        }
        #endif
        if group.isComingSoon || index == 0 { return true }
        let firstAvailable = store.updateGroups.firstIndex { !$0.isComingSoon }
        return index == firstAvailable
    }
}
