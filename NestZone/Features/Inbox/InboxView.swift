import ComposableArchitecture
import SwiftUI

// MARK: - The bell

/// The toolbar button, and the panel it opens.
///
/// One view rather than a button in one file and a sheet in another: the badge
/// and the panel read the same store and are the same feature, and separating
/// them would mean two call sites to keep in step.
public struct InboxBell: View {
    @Bindable var store: StoreOf<InboxFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<InboxFeature>) {
        self.store = store
    }

    public var body: some View {
        Button { store.send(.bellTapped) } label: {
            // The pip is an overlay rather than a sibling so the button's hit
            // target stays the bell's, and a count of three digits cannot push
            // the toolbar's layout around.
            Image(systemName: store.badge.hasUnread ? "bell.badge.fill" : "bell")
                .font(.body.weight(.semibold))
                // Two-colour so the badge half of the glyph carries the tint
                // and the bell stays legible against whatever is behind it.
                .symbolRenderingMode(store.badge.hasUnread ? .palette : .monochrome)
                .foregroundStyle(pipTint, Color.primary)
                // Rings when something arrives, and only then. `.bounce` fires
                // on a *change* of the trigger value, so a badge that stays at
                // three is still.
                .symbolEffect(.bounce, value: store.badge.total)
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .overlay(alignment: .topTrailing) {
                    if store.badge.hasUnread {
                        Text(store.badge.pipText)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(pipTint, in: .capsule)
                            .overlay(Capsule().strokeBorder(.background, lineWidth: 1.5))
                            .offset(x: 6, y: -4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .animation(Motion.spring, value: store.badge.total)
        .accessibilityLabel(Text(L10n.inboxOpenPanel))
        .accessibilityValue(
            store.badge.hasUnread
                ? Text(L10n.inboxUnreadCount(store.badge.total))
                : Text(L10n.inboxNothingNew)
        )
        .sheet(isPresented: $store.isOpen) {
            InboxPanel(store: store)
        }
    }

    /// What colour the pip is.
    ///
    /// The category of whatever is newest, so the bell says *what kind* of
    /// thing is waiting before it is opened — a red-orange for a house problem
    /// reads differently from a green for the shopping, and that is a free
    /// piece of information. Falls back to the theme accent when the only thing
    /// waiting is a release note, which belongs to the app rather than to any
    /// part of the house.
    private var pipTint: Color {
        store.badge.latestCategory?.tint ?? theme.accent
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
        .sheet(item: $store.scope(state: \.admin, action: \.admin)) {
            InboxAdminView(store: $0)
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
                store.send(.markAllReadTapped)
            } label: {
                Label { Text(L10n.inboxMarkAllRead) } icon: {
                    Image(systemName: "checkmark.circle")
                }
            }
            .disabled(!store.badge.hasUnread)

            if store.badge.isAdmin {
                Divider()
                Button {
                    store.send(.adminTapped)
                } label: {
                    Label { Text(L10n.inboxAdminOpen) } icon: {
                        Image(systemName: "hammer.fill")
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
    /// `Picker`: "3" beside House and "1" beside Updates is the answer to the
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

        return Button { store.send(.tabSelected(tab)) } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.symbol)
                    .font(.footnote.weight(.semibold))
                Text(tab.title)
                    .font(.subheadline.weight(.semibold))
                if count > 0 {
                    Text(count > store.badge.cap ? "\(store.badge.cap)+" : "\(count)")
                        .font(.caption2.weight(.bold))
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
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                if isSelected {
                    Capsule().fill(theme.accent)
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing, pinnedViews: []) {
                        ForEach(store.sections) { section in
                            daySection(section)
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
    private func daySection(_ section: ActivitySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    ActivityRow(
                        row: row,
                        isNew: store.state.isNew(row),
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
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
                                .appear(index)
                        }

                        Text(L10n.inboxVersionFooter(AppVersion.current.raw))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
private struct ActivityRow: View {
    let row: HomeActivity
    let isNew: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                glyph

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.title)
                            .font(.subheadline.weight(isNew ? .bold : .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        RelativeTimeText(row.created)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .layoutPriority(1)
                    }

                    if !row.body.isEmpty {
                        Text(row.body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if let name = row.actorName, !name.isEmpty, let actor = row.actor {
                        HStack(spacing: 5) {
                            // `viewable: false`: this whole row is a control
                            // that goes somewhere else, and a tappable face
                            // inside it would swallow the tap that matters.
                            Avatar(
                                initials: User.initials(from: name),
                                seed: actor.rawValue,
                                size: 16,
                                viewable: false
                            )
                            Text(name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 1)
                    }
                }

                if row.category.isRoutable {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                        .padding(.top, 3)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isNew ? theme.accent.opacity(0.07) : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(!row.category.isRoutable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(row.category.isRoutable ? .isButton : [])
    }

    /// The category's glyph, with the unread dot on it.
    ///
    /// The dot sits on the icon rather than in the margin because the icon is
    /// already where the eye lands going down a list, and a separate column for
    /// it would cost twelve points of width on every row to say something about
    /// three of them.
    private var glyph: some View {
        Image(systemName: row.category.symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(row.category.tint)
            .frame(width: 32, height: 32)
            .background(row.category.tint.opacity(0.16), in: .circle)
            .overlay(alignment: .topTrailing) {
                if isNew {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
    }
}

// MARK: - One release note

/// A changelog entry.
///
/// Full-width and deliberately unlike the timeline rows beside it: a version, a
/// kind, a headline, a paragraph and its bullets. Somebody should be able to
/// tell the two feeds apart from across the room.
private struct UpdateCard: View {
    let update: AppUpdate
    let isNew: Bool

    @Environment(\.theme) private var theme

    private var availability: UpdateAvailability { update.availability() }
    private var isComingSoon: Bool { availability == .comingSoon }

    var body: some View {
        GlassCard(tint: cardTint) {
            VStack(alignment: .leading, spacing: 10) {
                header

                Text(update.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(update.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !update.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(update.highlights.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(update.kind.tint)
                                Text(line)
                                    .font(.footnote)
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

    /// The very lightest tint, and only when there is something to say about
    /// the card as a whole. Glass stops reading as glass when everything is
    /// coloured.
    private var cardTint: Color? {
        isComingSoon ? Palette.amber.opacity(0.10) : nil
    }

    private var header: some View {
        HStack(spacing: 8) {
            Badge(
                String(localized: update.kind.label),
                tint: update.kind.tint,
                symbol: update.kind.symbol
            )

            if let version = update.version, !version.isEmpty {
                Text(L10n.inboxVersionChip(version))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Palette.inset, in: .capsule)
            }

            if update.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    /// The date, and — when it applies — the honest note that this build does
    /// not have the thing described above it.
    ///
    /// The whole reason release notes carry a version. Publishing happens when
    /// the work lands on the server; a build reaches a phone days later and some
    /// phones never take it. Saying "coming soon" is the difference between a
    /// changelog and a changelog that sends people hunting for a button that is
    /// not there.
    @ViewBuilder
    private var footer: some View {
        if isComingSoon, let version = update.version {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.caption2.weight(.semibold))
                Text(L10n.inboxArrivesIn(version, AppVersion.current.raw))
                    .font(.caption2)
            }
            .foregroundStyle(Palette.amber)
            .padding(.top, 2)
        } else {
            HStack(spacing: 6) {
                RelativeTimeText(update.displayDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
    }
}
