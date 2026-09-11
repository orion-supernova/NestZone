import ComposableArchitecture
import SwiftUI

/// House problems.
///
/// One screen with four faces. The order is deliberate: the board comes first
/// because "how is the house doing, and what should I look at" is the question
/// somebody opens this to answer — the list, the map and the history are the
/// evidence for it.
public struct IssuesView: View {
    @Bindable var store: StoreOf<IssuesFeature>

    @Environment(\.theme) private var theme
    @Namespace private var glass
    @Namespace private var sectionPill
    /// The row with its delete button showing, if any. Held here rather than in
    /// each row so opening one closes the last, as the system list does.
    @State private var revealedID: IssueID?
    @FocusState private var isSearchFocused: Bool

    public init(store: StoreOf<IssuesFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.sectionSpacing) {
                sectionPicker

                Group {
                    switch store.section {
                    case .board: board
                    case .list: list
                    case .rooms: rooms
                    case .history: history
                    }
                }
                // Each face is its own view, not four states of one.
                //
                // Without the id all four branches share an identity: SwiftUI
                // swaps the content in place, so the transition below never has
                // an insertion to run and none of the `appear` staggers inside
                // ever sees a second `onAppear`. It rebuilds the subtree on each
                // switch, which is the price of the effect and a fair one — the
                // switch is a deliberate tap and each face is a handful of cards.
                .id(store.section)
                // Faces cross-dissolve and lift rather than sliding: they are
                // four views of one house, not four places.
                .transition(.opacity.combined(with: .offset(y: 10)))
            }
            .padding(.bottom, Metrics.scrollBottomInset)
            .animation(Motion.spring, value: store.section)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.managementModuleMaintenanceTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.addTapped) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(L10n.issuesReport))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let pending = store.pendingDeletion {
                UndoToast(L10n.issuesDeleted(pending.title)) {
                    store.send(.undoDeleteTapped)
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // The house is entirely in order. The one thing on this screen worth
        // being smug about.
        .overlay { ConfettiBurst(trigger: store.allClearCelebration) }
        .animation(Motion.spring, value: store.pendingDeletion)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.compose, action: \.compose)) { store in
            IssueComposerSheet(store: store)
        }
        .navigationDestination(item: $store.scope(state: \.detail, action: \.detail)) { store in
            IssueDetailView(store: store)
        }
    }

    // MARK: - Chrome

    /// The four faces, as a sliding pill.
    ///
    /// Hand-rolled rather than a `.segmented` picker: the pill has to carry the
    /// theme accent and glide between slots, and a system segmented control on
    /// glass draws its own opaque track underneath the blur.
    private var sectionPicker: some View {
        HStack(spacing: 2) {
            ForEach(IssuesFeature.State.Section.allCases) { section in
                let isSelected = store.section == section
                Button { store.send(.sectionSelected(section)) } label: {
                    HStack(spacing: 5) {
                        // The icon you just chose acknowledges the tap; the one
                        // you left goes quiet without a fuss.
                        Image(systemName: section.symbol)
                            .font(.caption2.weight(.semibold))
                            .bounces(when: isSelected)
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(theme.accent)
                                .matchedGeometryEffect(id: "issueSection", in: sectionPill)
                        }
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.section)
    }

    // MARK: - Board

    @ViewBuilder
    private var board: some View {
        if store.isLoading && !store.hasLoaded {
            boardSkeleton
        } else if store.isBlank {
            EmptyStateView(
                title: L10n.issuesEmptyTitle,
                message: L10n.issuesEmptyMessage,
                symbol: "wrench.and.screwdriver",
                action: .init(title: L10n.issuesReportFirst) { store.send(.addTapped) },
                isCompact: true
            )
            .padding(.top, 24)
        } else {
            VStack(spacing: Metrics.sectionSpacing) {
                healthHero.appear(0)

                if !store.needsAttention.isEmpty {
                    attentionSection.appear(1)
                }
                if !store.goneQuiet.isEmpty {
                    quietSection.appear(2)
                }
                if !store.unassigned.isEmpty {
                    unassignedSection.appear(3)
                }
                if !store.summary.repeats.isEmpty {
                    repeatsCard.appear(4)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    private var boardSkeleton: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(.quaternary)
                .frame(height: 210)
            SkeletonList(rows: 3, height: 72)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .redacted(reason: .placeholder)
    }

    /// How the house is holding up. The reason this screen exists.
    private var healthHero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                HouseHealthRing(
                    health: store.summary.health,
                    openCount: store.summary.open
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.isAllClear
                        ? L10n.issuesAllClearTitle
                        : L10n.issuesOpenTitle(store.summary.open))
                        .font(.headline)
                        .contentTransition(.numericText())

                    Text(store.isAllClear
                        ? L10n.issuesAllClearMessage
                        : L10n.issuesOpenMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !store.isAllClear {
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            if store.summary.urgent > 0 {
                                Badge(
                                    String(localized: L10n.issuesUrgentCount(store.summary.urgent)),
                                    tint: Palette.danger,
                                    symbol: "exclamationmark.octagon.fill"
                                )
                            }
                            if store.summary.overdue > 0 {
                                Badge(
                                    String(localized: L10n.issuesOverdueCount(store.summary.overdue)),
                                    tint: Palette.warning,
                                    symbol: "clock.badge.exclamationmark.fill"
                                )
                            }
                            if store.summary.unassigned > 0 {
                                Badge(
                                    String(localized: L10n.issuesUnassignedCount(store.summary.unassigned)),
                                    tint: .secondary,
                                    symbol: "person.crop.circle.badge.questionmark"
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !store.summary.bySeverity.isEmpty {
                SeveritySplitBar(
                    counts: store.summary.bySeverity,
                    total: store.summary.open,
                    selection: Binding(
                        get: { store.severityFilter },
                        set: { severity in
                            // Picking a slice is picking a filter, and a filter
                            // only means something on the face that has a list.
                            store.send(.severityFilterTapped(severity))
                            if severity != nil { store.send(.sectionSelected(.list)) }
                        }
                    )
                )
            }

            if store.summary.fixedThisMonth > 0 {
                // The good news, and the only place on the board that carries
                // any. A screen that only ever counts what is wrong is a screen
                // a household stops opening.
                Label {
                    Text(L10n.issuesFixedThisMonth(store.summary.fixedThisMonth))
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard(tinted: (store.isAllClear ? Palette.success : theme.accent).opacity(0.12))
        .animation(Motion.spring, value: store.summary)
        .accessibilityElement(children: .contain)
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.issuesAttentionTitle,
                subtitle: L10n.issuesAttentionSubtitle,
                symbol: "exclamationmark.triangle.fill"
            ) {
                Button { store.send(.sectionSelected(.list)) } label: {
                    Text(L10n.commonSeeAll).font(.footnote.weight(.medium))
                }
            }
            rowStack(store.needsAttention)
        }
    }

    private var quietSection: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.issuesQuietTitle,
                subtitle: L10n.issuesQuietSubtitle,
                symbol: "zzz"
            )
            rowStack(Array(store.goneQuiet.prefix(3)))
        }
    }

    /// Problems with nobody's name on them.
    ///
    /// A rail of chips rather than full rows: the point is not to read them, it
    /// is to notice how many there are and put a name against one. Tapping goes
    /// straight to the problem, where the assignee picker is.
    private var unassignedSection: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.issuesUnassignedTitle,
                subtitle: L10n.issuesUnassignedSubtitle,
                symbol: "person.crop.circle.badge.questionmark"
            )
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.unassigned.prefix(8)) { issue in
                        Button { store.send(.issueTapped(issue.id)) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: issue.category.symbol)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(issue.severity.tint)
                                Text(issue.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pressable)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Where this house keeps going wrong.
    ///
    /// The one thing a list of problems cannot tell you by being read: that the
    /// kitchen plumbing has now been dealt with three times. Tapping filters the
    /// list to that room, which is the only useful next step.
    private var repeatsCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    L10n.issuesRepeatsTitle,
                    subtitle: L10n.issuesRepeatsSubtitle,
                    symbol: "arrow.triangle.2.circlepath"
                )

                VStack(spacing: 10) {
                    ForEach(store.summary.repeats) { entry in
                        Button {
                            store.send(.areaFilterTapped(entry.area))
                            store.send(.categoryFilterTapped(entry.category))
                            store.send(.statusFilterTapped(nil))
                            store.send(.sectionSelected(.list))
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: entry.area.symbol)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 30, height: 30)
                                    .background(theme.accent.opacity(0.14), in: .circle)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.area.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(entry.category.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 4)

                                Badge(
                                    String(localized: L10n.issuesRepeatsCount(entry.count)),
                                    tint: entry.count >= 3 ? Palette.warning : .secondary
                                )
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Palette.accessory)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        VStack(spacing: Metrics.stackSpacing) {
            searchField
            filterRow
            listTotal
        }
        .padding(.horizontal, Metrics.screenPadding)

        if store.isLoading && !store.hasLoaded {
            SkeletonList(rows: 6, height: 72)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, Metrics.stackSpacing)
        } else if store.filtered.isEmpty {
            EmptyStateView(
                title: store.isFiltering
                    ? L10n.issuesNoMatchesTitle
                    : L10n.issuesNothingOpenTitle,
                message: store.isFiltering
                    ? L10n.issuesNoMatchesMessage
                    : L10n.issuesNothingOpenMessage,
                symbol: store.isFiltering
                    ? "line.3.horizontal.decrease.circle"
                    : "checkmark.seal",
                action: store.isFiltering
                    ? .init(title: L10n.issuesClearFilters) { store.send(.filtersCleared) }
                    : .init(title: L10n.issuesReport) { store.send(.addTapped) },
                isCompact: true
            )
            .padding(.top, 24)
        } else {
            rowStack(store.filtered)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, Metrics.stackSpacing)
                .animation(Motion.spring, value: store.filtered)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(text: $store.search) {
                Text(L10n.issuesSearchPlaceholder)
            }
            .focused($isSearchFocused)
            .submitLabel(.search)
            .textInputAutocapitalization(.never)
            if !store.search.isEmpty {
                Button { store.send(.binding(.set(\.search, ""))) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.accessory)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(Text(L10n.commonCancel))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(Motion.fade, value: store.search.isEmpty)
    }

    /// The filters, on one scrolling rail.
    ///
    /// Sort lives here too rather than in the toolbar: it is the same act —
    /// "show me this list differently" — and splitting the two across the screen
    /// is how people stop finding either.
    private var filterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                sortMenu

                Chip(
                    String(localized: L10n.issuesFilterMine),
                    symbol: "person.fill",
                    isSelected: store.mineOnly
                ) { store.send(.mineToggled) }

                if store.statusFilter != nil || store.summary.closed > 0 {
                    statusMenu
                }

                ForEach(IssueSeverity.allCases.reversed()) { severity in
                    if store.summary.count(of: severity) > 0 || store.severityFilter == severity {
                        Chip(
                            String(localized: severity.title),
                            symbol: severity.symbol,
                            isSelected: store.severityFilter == severity
                        ) { store.send(.severityFilterTapped(severity)) }
                    }
                }

                ForEach(store.presentAreas) { area in
                    Chip(
                        String(localized: area.title),
                        symbol: area.symbol,
                        isSelected: store.areaFilter == area
                    ) { store.send(.areaFilterTapped(area)) }
                }

                ForEach(store.presentCategories) { category in
                    Chip(
                        String(localized: category.title),
                        symbol: category.symbol,
                        isSelected: store.categoryFilter == category
                    ) { store.send(.categoryFilterTapped(category)) }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(IssuesFeature.State.Sort.allCases) { sort in
                Button { store.send(.sortSelected(sort)) } label: {
                    Label {
                        Text(sort.title)
                    } icon: {
                        Image(systemName: store.sort == sort ? "checkmark" : sort.symbol)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                Text(store.sort.title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(Color.primary)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
        }
        .accessibilityLabel(Text(L10n.issuesSortLabel))
    }

    /// The one filter that reaches past the open problems.
    ///
    /// Separated from the rest because it changes what the list *is* rather than
    /// narrowing it: everything else filters what is outstanding, and this is
    /// how you go and look at something already settled without leaving the
    /// list you are in.
    private var statusMenu: some View {
        Menu {
            Button { store.send(.statusFilterTapped(nil)) } label: {
                Label {
                    Text(L10n.issuesFilterOpen)
                } icon: {
                    Image(systemName: store.statusFilter == nil ? "checkmark" : "tray.full")
                }
            }
            Divider()
            ForEach(IssueStatus.allCases) { status in
                Button { store.send(.statusFilterTapped(status)) } label: {
                    Label {
                        Text(status.title)
                    } icon: {
                        Image(systemName: store.statusFilter == status ? "checkmark" : status.symbol)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: store.statusFilter?.symbol ?? "tray.full")
                    .font(.caption.weight(.semibold))
                Text(store.statusFilter?.title ?? L10n.issuesFilterOpen)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(store.statusFilter == nil ? Color.primary : Color.white)
            .background {
                if let status = store.statusFilter {
                    Capsule().fill(status.tint)
                }
            }
            .glassEffect(store.statusFilter == nil ? .regular.interactive() : .identity, in: .capsule)
            .contentShape(.capsule)
        }
        .animation(Motion.spring, value: store.statusFilter)
        .accessibilityLabel(Text(L10n.issuesFilterStatusLabel))
    }

    /// What the list currently holds. Has to move when a filter is applied, or
    /// the filter looks like it did nothing.
    private var listTotal: some View {
        HStack {
            Text(store.isFiltering ? L10n.issuesFilteredCount : L10n.issuesShowingCount)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(store.filtered.count, format: .number)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            if store.isFiltering {
                Button { store.send(.filtersCleared) } label: {
                    Text(L10n.issuesClearFilters)
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .transition(.opacity)
            }
        }
        .animation(Motion.fade, value: store.isFiltering)
    }

    // MARK: - Rooms

    @ViewBuilder
    private var rooms: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            SectionHeader(
                L10n.issuesRoomsTitle,
                subtitle: L10n.issuesRoomsSubtitle,
                symbol: "map"
            )

            GlassGroup(spacing: 16) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: Metrics.stackSpacing)],
                    spacing: Metrics.stackSpacing
                ) {
                    ForEach(Array(store.roomOrder.enumerated()), id: \.element) { index, area in
                        RoomTile(
                            area: area,
                            count: store.state.count(in: area),
                            peak: store.busiestRoomCount,
                            isSelected: store.areaFilter == area
                        ) { store.send(.areaFilterTapped(area)) }
                        .appear(index)
                    }
                }
            }

            if let area = store.areaFilter {
                let inRoom = store.filtered
                VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                    SectionHeader(area.title, symbol: area.symbol) {
                        Button { store.send(.reportInRoomTapped(area)) } label: {
                            Label { Text(L10n.issuesReport) } icon: {
                                Image(systemName: "plus")
                            }
                            .font(.footnote.weight(.medium))
                        }
                    }
                    if inRoom.isEmpty {
                        Text(L10n.issuesRoomClear(String(localized: area.title)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        rowStack(inRoom)
                    }
                }
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.areaFilter)
    }

    // MARK: - History

    @ViewBuilder
    private var history: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            historyDigest

            if store.history.isEmpty {
                EmptyStateView(
                    title: L10n.issuesHistoryEmptyTitle,
                    message: L10n.issuesHistoryEmptyMessage,
                    symbol: "clock.arrow.circlepath",
                    isCompact: true
                )
                .padding(.top, 12)
            } else {
                VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                    SectionHeader(L10n.issuesHistoryTitle, symbol: "checkmark.seal")
                    GlassList {
                        ForEach(store.history) { issue in
                            SettledRow(
                                issue: issue,
                                resolvedByName: store.state.name(for: issue.resolvedBy),
                                glass: glass
                            ) { store.send(.issueTapped(issue.id)) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    /// What this house has actually cost, and how fast it gets sorted.
    private var historyDigest: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    L10n.issuesUpkeepTitle,
                    subtitle: L10n.issuesUpkeepSubtitle,
                    symbol: "chart.line.uptrend.xyaxis"
                )

                HStack(spacing: 12) {
                    digestFigure(
                        value: Text(store.summary.fixedThisMonth, format: .number),
                        label: L10n.issuesDigestFixedMonth,
                        tint: Palette.success
                    )
                    Divider().frame(height: 34).opacity(0.4)
                    digestFigure(
                        value: store.summary.medianFixDays.map { days in
                            Text(L10n.issuesDigestDays(days))
                        } ?? Text(verbatim: "—"),
                        label: L10n.issuesDigestTypicalFix,
                        tint: theme.accent
                    )
                    Divider().frame(height: 34).opacity(0.4)
                    digestFigure(
                        value: Text(Money.compactText(
                            store.summary.repairSpentYear,
                            currency: store.summary.repairCurrency ?? Money.deviceDefault
                        )),
                        label: L10n.issuesDigestSpentYear,
                        tint: Palette.warning
                    )
                }

                if store.summary.repairSpentMonth > 0 {
                    Text(L10n.issuesDigestSpentMonth(Money.text(
                        store.summary.repairSpentMonth,
                        currency: store.summary.repairCurrency ?? Money.deviceDefault
                    )))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func digestFigure(
        value: Text,
        label: LocalizedStringResource,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            value
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rows

    private func rowStack(_ issues: [HouseIssue]) -> some View {
        GlassList {
            ForEach(issues) { issue in
                IssueRow(
                    issue: issue,
                    assigneeName: issue.assignedTo.map { store.state.name(for: $0) },
                    isAffected: issue.isAffected(store.currentUserID),
                    revealedID: $revealedID,
                    glass: glass,
                    onTap: { store.send(.issueTapped(issue.id)) },
                    onMeToo: { store.send(.meTooTapped(issue.id)) },
                    onAdvance: { store.send(.advanceTapped(issue.id)) },
                    onDelete: { store.send(.deleteTapped(issue.id)) }
                )
            }
        }
    }
}

// MARK: - One problem

/// One thing that is wrong with the house.
///
/// Four facts, in the order they are wanted: how bad it is (the colour), what it
/// is, where it is and how long it has been like that. Everything else — the
/// parts still to buy, what it has cost, who has agreed — is a badge, because a
/// row that reads as a paragraph is a row nobody reads.
private struct IssueRow: View {
    let issue: HouseIssue
    /// `nil` when nobody has taken it on, which is itself worth showing.
    let assigneeName: String?
    let isAffected: Bool
    @Binding var revealedID: IssueID?
    let glass: Namespace.ID
    let onTap: () -> Void
    let onMeToo: () -> Void
    let onAdvance: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SwipeToDelete(
            isRevealed: Binding(
                get: { revealedID == issue.id },
                set: { revealedID = $0 ? issue.id : nil }
            ),
            onDelete: onDelete
        ) {
            // Not a `Button`: it sits in a ScrollView *and* inside a swipe
            // gesture, and a button holds the touch on the way down while it
            // decides what the press is going to be — so neither the scroll nor
            // the swipe could start under a finger that landed on a row. A
            // `TapGesture` fails the instant the finger moves.
            card
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, onTap)
                .contextMenu {
                    if let next = issue.status.next {
                        Button(action: onAdvance) {
                            Label {
                                Text(issue.status.advanceTitle)
                            } icon: {
                                Image(systemName: next.symbol)
                            }
                        }
                    }
                    Button(action: onMeToo) {
                        Label {
                            Text(isAffected ? L10n.issuesMeTooUndo : L10n.issuesMeTooAdd)
                        } icon: {
                            Image(systemName: isAffected ? "hand.raised.slash" : "hand.raised")
                        }
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label { Text(L10n.commonDelete) } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
        }
    }

    private var card: some View {
        HStack(spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(issue.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if issue.isUnderWarranty {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(Palette.success)
                            .accessibilityLabel(Text(L10n.issuesUnderWarranty))
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: issue.area.symbol)
                        .font(.system(size: 9))
                    Text(issue.area.title)
                    Text(verbatim: "·")
                    Text(issue.status.title)
                        .foregroundStyle(issue.status.tint)
                    if let assigneeName {
                        Text(verbatim: "·")
                        Text(assigneeName).lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if !badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badges, id: \.id) { badge in
                            HStack(spacing: 3) {
                                Image(systemName: badge.symbol)
                                    .font(.system(size: 8, weight: .bold))
                                Text(badge.text)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(badge.tint)
                        }
                    }
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 4)

            trailing
        }
        // No lean on this row: interactive glass tracks the finger from
        // touch-down, and this row's finger belongs to `SwipeToDelete`. The two
        // race for the same touch — sometimes the swipe wins, sometimes the
        // glass does, which is worse than either. Tap-only rows keep the lean
        // from `GlassListStyle.default`.
        .glassRow(interactive: false)
        .contentShape(.rect)
        .glassEffectID(issue.id.rawValue, in: glass)
        .accessibilityElement(children: .combine)
    }

    /// The photo when there is one, and the category on its severity colour
    /// when there is not. A picture of the actual leak identifies a row faster
    /// than any label, which is the entire argument for photos being here.
    private var leading: some View {
        ZStack {
            if let thumbnail = issue.thumbnailURL, let url = URL(string: thumbnail) {
                RemoteImage(url: url, targetSize: CGSize(width: 44, height: 44)) {
                    Rectangle().fill(issue.severity.tint.opacity(0.16))
                }
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 11, style: .continuous))
            } else {
                Image(systemName: issue.category.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(issue.severity.tint)
                    .frame(width: 44, height: 44)
                    .background(
                        issue.severity.tint.opacity(0.16),
                        in: .rect(cornerRadius: 11, style: .continuous)
                    )
            }
        }
        // Only a problem that has already gone wrong is allowed to move, and
        // the list shows at most a handful of them.
        .pulse(issue.severity.demandsAttention && issue.isOpen)
        .overlay(alignment: .topTrailing) {
            if issue.photoCount > 1 {
                Text(issue.photoCount, format: .number)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.55), in: .capsule)
                    .offset(x: 4, y: -4)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if issue.isOverdue, let days = issue.daysUntilDue() {
                Badge(
                    String(localized: L10n.issuesOverdueBy(-days)),
                    tint: Palette.danger,
                    symbol: "clock.badge.exclamationmark.fill"
                )
            } else if let days = issue.daysUntilDue(), issue.isOpen, days <= 7 {
                Badge(
                    String(localized: days == 0 ? L10n.issuesDueToday : L10n.issuesDueIn(days)),
                    tint: Palette.warning
                )
            } else if issue.isOpen, issue.ageDays > 0 {
                // Only once it has actually been standing a day. "0d old" on
                // something reported a minute ago reads as a broken counter.
                Text(L10n.issuesAgeDays(issue.ageDays))
                    .font(.caption2)
                    .foregroundStyle(issue.isStale ? Palette.warning : .secondary)
                    .monospacedDigit()
            }

            if issue.affectedCount > 1 {
                Label {
                    Text(issue.affectedCount, format: .number)
                } icon: {
                    Image(systemName: "hand.raised.fill")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isAffected ? Palette.warning : .secondary)
                .contentTransition(.numericText(value: Double(issue.affectedCount)))
            }
        }
    }

    private struct RowBadge {
        let id: String
        let symbol: String
        let text: String
        let tint: Color
    }

    /// The rollups the server computed, and only the ones that are asking for
    /// something. A row that always carries three badges is a row where none of
    /// them means anything.
    private var badges: [RowBadge] {
        var out: [RowBadge] = []
        if issue.partsOpen > 0 {
            out.append(RowBadge(
                id: "parts",
                symbol: "cart.fill",
                text: String(localized: L10n.issuesPartsPending(issue.partsOpen)),
                tint: Palette.statShopping
            ))
        }
        if issue.spent > 0, let currency = issue.spentCurrency {
            out.append(RowBadge(
                id: "spent",
                symbol: "creditcard.fill",
                text: Money.compactText(issue.spent, currency: currency),
                // The same indigo the cost row on the detail screen uses, so a
                // figure means the same thing in both places.
                tint: Palette.indigo
            ))
        }
        if issue.taskID != nil {
            out.append(RowBadge(
                id: "chore",
                symbol: "checklist",
                text: String(localized: L10n.issuesHasChore),
                tint: .secondary
            ))
        }
        if issue.eventID != nil {
            out.append(RowBadge(
                id: "visit",
                symbol: "calendar",
                text: String(localized: L10n.issuesHasVisit),
                tint: Palette.statEvents
            ))
        }
        return out
    }
}

/// One settled problem, on the History face.
///
/// The resolution is the whole point of the row: "what fixed it last time" is
/// the single most useful sentence in this module when the same thing goes
/// again, and a history that only recorded *that* it was fixed would throw it
/// away.
private struct SettledRow: View {
    let issue: HouseIssue
    let resolvedByName: String
    let glass: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.status.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(issue.status.tint)
                .frame(width: 34, height: 34)
                .background(issue.status.tint.opacity(0.16), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: issue.area.symbol).font(.system(size: 9))
                    Text(issue.area.title)
                    if let resolved = issue.resolvedAt {
                        Text(verbatim: "·")
                        Text(resolved.date, format: .dateTime.day().month(.abbreviated).year())
                    }
                    Text(verbatim: "·")
                    Text(resolvedByName).lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let resolution = issue.resolution, !resolution.isEmpty {
                    Text(resolution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 4)

            if issue.spent > 0, let currency = issue.spentCurrency {
                Text(Money.compactText(issue.spent, currency: currency))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .glassRow()
        .contentShape(.rect)
        .glassEffectID(issue.id.rawValue, in: glass)
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }
}
