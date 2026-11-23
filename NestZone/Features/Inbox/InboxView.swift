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

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)

                VStack(spacing: 0) {
                    switcher
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.bottom, 12)

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
                    LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing, pinnedViews: []) {
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
            .padding(.bottom, 12)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .groupLabel()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    ActivityRow(
                        row: row,
                        isNew: store.state.isNew(row),
                        order: start + index,
                        action: { store.send(.rowTapped(row)) }
                    )
                    if index < section.rows.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .glassCard()
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
                SkeletonList(rows: 3, height: 140)
                    .padding(.horizontal, Metrics.screenPadding)
            } else if store.updateRows.isEmpty {
                EmptyStateView(
                    title: L10n.inboxEmptyUpdatesTitle,
                    message: L10n.inboxEmptyUpdatesMessage,
                    symbol: "sparkles"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Metrics.stackSpacing) {
                        ForEach(Array(store.updateRows.enumerated()), id: \.element.id) { index, update in
                            UpdateCard(update: update, isNew: store.state.isNew(update))
                                // Only the first screenful staggers: a lazy card
                                // appears when it is scrolled to, and one far down
                                // waiting out its capped delay read as the feed
                                // lagging behind the finger.
                                .appear(index < 8 ? index : 0)
                        }

                        Text(L10n.inboxVersionFooter(AppVersion.current.raw))
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, Metrics.screenPadding)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }
}

// MARK: - One thing that happened

/// A single line of a household's timeline.
///
/// Its own small view rather than a branch inside the list, so SwiftUI compares
/// one row's stored values instead of re-evaluating the whole section's body
/// when a single timestamp label ticks over.
///
/// Face first, then one sentence with the person in bold, then the module as a
/// glyph in its own tint beside the detail. Colour is the glyph's alone: the
/// words stay in the label colours, and "new" is a dot and a wash inside the
/// row, never something hung off its corner.
private struct ActivityRow: View {
    let row: HomeActivity
    let isNew: Bool
    /// Its place in the whole feed, for the wave "Mark all read" sends down it.
    let order: Int
    let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var actorName: String? {
        guard let actor = row.actor else { return nil }
        let name = StoreDemo.personaName(for: actor) ?? row.actorName
        return (name?.isEmpty == false) ? name : nil
    }

    /// "**Murat** finished Dishes". The name is dropped from the title when the
    /// server already wrote it there, so it is never said twice.
    private var sentence: Text {
        guard let name = actorName else { return Text(row.title).fontWeight(.semibold) }
        let rest = row.title.hasPrefix(name)
            ? String(row.title.dropFirst(name.count)).trimmingCharacters(in: .whitespaces)
            : row.title
        return Text(name).fontWeight(.bold) + Text(verbatim: " ") + Text(rest)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                face

                VStack(alignment: .leading, spacing: 3) {
                    sentence
                        .font(.subheadline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: row.category.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(row.category.tint)
                        Text(row.body.isEmpty ? String(localized: row.category.label) : row.body)
                            .font(.footnote)
                            .foregroundStyle(.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 5) {
                    RelativeTimeText(row.created)
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                    if isNew {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 8, height: 8)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            .accessibilityHidden(true)
                    }
                }

                if row.category.isRoutable {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isNew ? theme.accent.opacity(0.07) : .clear)
            // Read, one row after another rather than all at once, so marking
            // everything read looks like something swept down the list. The
            // stagger is capped, so a long feed is not still going a second
            // later; under Reduce Motion the rows fade together.
            .animation(
                reduceMotion
                    ? Motion.fade
                    : Motion.exit.delay(Motion.stagger(order, step: 0.03, cap: 0.3)),
                value: isNew
            )
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(!row.category.isRoutable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(row.category.isRoutable ? .isButton : [])
    }

    /// Who did it. The module's own glyph stands in when the app did it by
    /// itself (a nightly sweep finding an overdue bill).
    @ViewBuilder
    private var face: some View {
        if let actor = row.actor, let name = actorName {
            // `viewable: false`: this whole row is a control that goes
            // somewhere else, and a tappable face would swallow that tap.
            Avatar(initials: User.initials(from: name), seed: actor.rawValue, size: 36, viewable: false)
        } else {
            Image(systemName: row.category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.category.tint)
                .frame(width: 36, height: 36)
                .background(row.category.tint.opacity(0.16), in: .circle)
        }
    }
}

// MARK: - One release note

/// A changelog entry.
///
/// Full-width and deliberately unlike the timeline rows beside it. Top to
/// bottom: what kind of note it is, the headline, a few lines of the story
/// (with "More" when there is more), the bullets, and the version and date as
/// quiet meta. "Coming soon" and "New" are badges inside the card's own top
/// row, never on its edge.
private struct UpdateCard: View {
    let update: AppUpdate
    let isNew: Bool

    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    private var isComingSoon: Bool { update.availability() == .comingSoon }

    /// The words, in the language this app is set to — which is `L10n.locale`
    /// and not the device's, because the app has its own picker. English when
    /// that language was never written (`AppUpdate.text`).
    private var text: LocalizedUpdate { update.text() }

    /// A body of this size runs past three lines at the card's width; a shorter
    /// one has nothing to expand, so no button.
    private var isLong: Bool { text.body.count > 130 || text.body.contains("\n") }

    var body: some View {
        GlassCard(tint: isComingSoon ? Palette.amber.opacity(0.10) : nil) {
            VStack(alignment: .leading, spacing: 10) {
                header

                Text(text.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(text.body)
                        .font(.callout)
                        .foregroundStyle(.secondaryText)
                        .lineLimit(isExpanded ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)

                    if isLong {
                        Button {
                            withAnimation(Motion.spring) { isExpanded.toggle() }
                        } label: {
                            Text(isExpanded ? L10n.inboxShowLess : L10n.commonMore)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.accentText)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !text.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(text.highlights.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Circle()
                                    .fill(update.kind.tint)
                                    .frame(width: 6, height: 6)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                                Text(line)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                footer
            }
        }
    }

    /// The kind with its glyph on the left; on the right the one state that
    /// matters most, "Coming soon" ahead of "New" because a note this build
    /// cannot show yet is the thing to be clear about.
    private var header: some View {
        HStack(spacing: 8) {
            Badge(
                String(localized: update.kind.label),
                tint: update.kind.tint,
                symbol: update.kind.symbol
            )

            if update.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondaryText)
                    .accessibilityLabel(Text(L10n.inboxPinned))
            }

            Spacer(minLength: 4)

            if isComingSoon {
                Badge(
                    String(localized: L10n.inboxComingSoon),
                    tint: Palette.amber,
                    symbol: "clock"
                )
            } else if isNew {
                Badge(
                    String(localized: L10n.inboxNew),
                    tint: theme.highlight,
                    symbol: "sparkle"
                )
            }
        }
    }

    /// Version and date, quietly. A note for a version this build does not have
    /// says so in words: publishing happens when the work lands on the server,
    /// a build reaches a phone days later, and "coming soon" is the difference
    /// between a changelog and one that sends people hunting for a button that
    /// is not there.
    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 6) {
            if isComingSoon, let version = update.version {
                Image(systemName: "arrow.down.circle")
                    .font(.caption.weight(.semibold))
                Text(L10n.inboxArrivesIn(version, AppVersion.current.raw))
                    .font(.caption)
            } else {
                if let version = update.version, !version.isEmpty {
                    Text(L10n.inboxVersionChip(version))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Text(verbatim: "·")
                }
                RelativeTimeText(update.displayDate)
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondaryText)
        .padding(.top, 2)
    }
}
