import ComposableArchitecture
import SwiftUI

/// The days this house celebrates, from every calendar: what is coming up
/// first, then every day by family, each a switch. A suggestion from the
/// region to start from, and a search and a filter row for the other forty.
struct HolidaysView: View {
    let store: StoreOf<CompanionFeature>

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title3) private var badge = 38

    @State private var board: HolidayBoard
    @State private var query = ""
    @State private var filter = Filter.all

    private enum Filter: Hashable {
        case all, celebrating
        case family(Holiday.Family)
    }

    init(store: StoreOf<CompanionFeature>) {
        self.store = store
        _board = State(initialValue: .make(clock: store.clock, region: store.placeRegion))
        #if DEBUG || MEASURE
        // `-holidaysSearch diwali`, `-holidaysFilter celebrating|muslim`, for screenshots.
        let defaults = UserDefaults.standard
        if let text = defaults.string(forKey: "holidaysSearch") { _query = State(initialValue: text) }
        if let name = defaults.string(forKey: "holidaysFilter") {
            if name == "celebrating" { _filter = State(initialValue: .celebrating) }
            else if let family = Holiday.Family(rawValue: name) { _filter = State(initialValue: .family(family)) }
        }
        #endif
    }

    var body: some View {
        let on = store.celebrated
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let sections = visibleSections(on: on)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !searching { comingUp(on: on) }
                filters(on: on)
                if sections.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 24)
                } else {
                    ForEach(sections, id: \.family) { section in
                        familySection(section.family, entries: section.entries, on: on, searching: searching)
                    }
                }
                if !searching, !on.isEmpty { suggestion }
            }
            .padding(.vertical, 12)
        }
        .background(Backdrop(tint: theme.accent))
        .tint(theme.accent)
        .searchable(text: $query, prompt: Text(L10n.holidaysSearchPrompt))
        .navigationTitle(Text(L10n.holidaysTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(L10n.commonDone) }
            }
        }
        // The next dates move with the day, the region and the language, and
        // with nothing else: the board is not rebuilt for a toggle.
        .onChange(of: HolidayBoard.key(clock: store.clock, region: store.placeRegion)) { _, key in
            if key != board.key { board = .make(clock: store.clock, region: store.placeRegion) }
        }
    }

    // MARK: - Coming up

    @ViewBuilder
    private func comingUp(on: Set<Holiday.ID>) -> some View {
        let soon = board.upcoming(among: on, limit: 5)
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.holidaysComingUp)
                .groupLabel()
                .oneLineUnlessAccessibility()
                .padding(.horizontal, Metrics.screenPadding)
            if soon.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.holidaysNoneCelebrated)
                        .font(.subheadline)
                        .foregroundStyle(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    SecondaryButton(L10n.holidaysSuggested, symbol: "sparkles") { store.send(.holidaysReset) }
                }
                .padding(Metrics.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                .padding(.horizontal, Metrics.screenPadding)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassGroup(spacing: 0) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(soon) { entry in soonCard(entry) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .contentMargins(.horizontal, Metrics.screenPadding, for: .scrollContent)
                .scrollClipDisabled()
            }
        }
    }

    private func soonCard(_ entry: HolidayBoard.Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            emoji(entry.holiday.symbol)
            Text(entry.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2, reservesSpace: !typeSize.isAccessibilitySize)
                .multilineTextAlignment(.leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.underway ? String(localized: L10n.holidayNow) : entry.relativeCapitalized)
                    .font(.caption.weight(.semibold))
                if !entry.underway {
                    Text(entry.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                }
            }
            .lineLimit(1)
        }
        .padding(12)
        .frame(width: typeSize.isAccessibilitySize ? 220 : 148, alignment: .leading)
        .glassCard(cornerRadius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(entry.title), \(entry.underway ? String(localized: L10n.holidayNow) : "\(entry.relative), \(entry.dateText)")"))
    }

    // MARK: - Filters

    private func filters(on: Set<Holiday.ID>) -> some View {
        let families = Holiday.Family.allCases.filter { family in board.entries.contains { $0.holiday.family == family } }
        return ScrollView(.horizontal, showsIndicators: false) {
            GlassGroup(spacing: 0) {
                HStack(spacing: 8) {
                    Chip(String(localized: L10n.holidaysFilterAll), isSelected: filter == .all) { filter = .all }
                    Chip("\(String(localized: L10n.holidaysFilterCelebrating)) \(on.count)", isSelected: filter == .celebrating) { filter = .celebrating }
                    ForEach(families) { family in
                        Chip(String(localized: family.title), isSelected: filter == .family(family)) { filter = .family(family) }
                    }
                }
            }
            // Room for the glass to breathe, so a chip is never cut off.
            .padding(.vertical, 6)
        }
        .contentMargins(.horizontal, Metrics.screenPadding, for: .scrollContent)
        .scrollClipDisabled()
    }

    // MARK: - Families

    private struct FamilyGroup {
        let family: Holiday.Family
        let entries: [HolidayBoard.Entry]
    }

    private func visibleSections(on: Set<Holiday.ID>) -> [FamilyGroup] {
        let needle = HolidayBoard.fold(query.trimmingCharacters(in: .whitespaces))
        var result: [FamilyGroup] = []
        for family in Holiday.Family.allCases {
            if case let .family(chosen) = filter, chosen != family { continue }
            var entries = board.entries(in: family)
            if filter == .celebrating { entries = entries.filter { on.contains($0.id) } }
            if !needle.isEmpty { entries = entries.filter { $0.searchKey.contains(needle) } }
            if !entries.isEmpty { result.append(FamilyGroup(family: family, entries: entries)) }
        }
        return result
    }

    private func familySection(_ family: Holiday.Family, entries: [HolidayBoard.Entry], on: Set<Holiday.ID>, searching: Bool) -> some View {
        let all = board.entries(in: family)
        let allOn = all.allSatisfy { on.contains($0.id) }
        return VStack(alignment: .leading, spacing: 6) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 8))) {
                Text(family.title)
                    .groupLabel()
                    .oneLineUnlessAccessibility()
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                if !searching {
                    Button { store.send(.holidaysSetFamily(family, on: !allOn)) } label: {
                        Text(allOn ? L10n.holidaysTurnAllOff : L10n.holidaysTurnAllOn)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .oneLineUnlessAccessibility()
                            .frame(minHeight: Metrics.minTapTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    row(entry, on: on.contains(entry.id))
                    if entry.id != entries.last?.id { Divider().padding(.leading, badge + 26) }
                }
            }
            .glassCard()
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    private func row(_ entry: HolidayBoard.Entry, on: Bool) -> some View {
        let detail = entry.underway
            ? String(localized: L10n.holidayNow)
            : entry.days == nil ? "" : "\(entry.dateText) · \(entry.relative)"
        return Toggle(isOn: Binding(
            get: { on },
            set: { _ in store.send(.holidayToggled(entry.id)) }
        )) {
            HStack(spacing: 12) {
                emoji(entry.holiday.symbol)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .font(.body)
                        .oneLineUnlessAccessibility()
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                            .oneLineUnlessAccessibility()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: Metrics.minTapTarget)
        .accessibilityLabel(Text(verbatim: detail.isEmpty ? entry.title : "\(entry.title), \(detail)"))
    }

    // MARK: - Pieces

    /// The emoji in a soft circle of the theme's accent; read as the day's
    /// name, never as its own description.
    private func emoji(_ symbol: String) -> some View {
        Text(verbatim: symbol)
            .font(.title3)
            .frame(width: badge, height: badge)
            .background(.tint.opacity(0.14), in: .circle)
            .accessibilityHidden(true)
    }

    private var suggestion: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.holidaysHint)
                .font(.footnote)
                .foregroundStyle(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(L10n.holidaysSuggested, symbol: "sparkles") { store.send(.holidaysReset) }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .padding(.horizontal, Metrics.screenPadding)
    }
}
