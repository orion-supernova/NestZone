import ComposableArchitecture
import SwiftUI

/// Past events: a year of what the household did, and what it came to.
struct EventHistorySheet: View {
    @Bindable var store: StoreOf<EventHistoryFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    if store.isLoading {
                        SkeletonList(rows: 5, height: 64)
                    } else if store.state.rows.isEmpty {
                        EmptyStateView(
                            title: L10n.calendarHistoryEmptyTitle,
                            message: L10n.calendarHistoryEmptyMessage,
                            symbol: "clock.arrow.circlepath",
                            isCompact: true
                        )
                    } else {
                        summaryCard.appear(0)
                        VStack(spacing: 8) {
                            ForEach(Array(store.state.rows.enumerated()), id: \.element.id) { index, row in
                                historyRow(row).appear(index + 1)
                            }
                        }
                    }
                }
                .padding(Metrics.screenPadding)
                .padding(.bottom, 20)
            }
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.calendarHistoryTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(L10n.commonClose) }
                }
            }
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.scope(state: \.detail, action: \.detail)) { store in
                EventDetailSheet(store: store)
            }
            .animation(Motion.spring, value: store.history)
        }
    }

    // MARK: Summary

    /// Three figures for the year: how many, how much, and how the budgets held.
    private var summaryCard: some View {
        let history = store.history ?? .empty
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.calendarHistoryWindow(history.days / 30))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 10) {
                    figure(
                        symbol: "calendar",
                        tint: theme.accent,
                        value: history.held.formatted(),
                        title: L10n.calendarHistoryHeld
                    )
                    figure(
                        symbol: "creditcard.fill",
                        tint: Palette.indigo,
                        value: history.primarySpend.map {
                            Money.compactText($0.amount, currency: $0.currency)
                        } ?? "–",
                        title: L10n.calendarRecapSpent
                    )
                    if history.budgeted > 0 {
                        figure(
                            symbol: "gauge.with.dots.needle.67percent",
                            tint: history.overBudget > 0 ? Palette.danger : Palette.success,
                            value: "\(history.overBudget)/\(history.budgeted)",
                            title: L10n.calendarHistoryOverBudget
                        )
                    }
                }
                if history.spent.count > 1 {
                    // Sums are per currency, and one of them is the headline.
                    // The rest are named rather than quietly left out.
                    Text(L10n.calendarHistoryAlsoSpent(
                        history.spent.dropFirst()
                            .map { Money.compactText($0.amount, currency: $0.currency) }
                            .joined(separator: ", ")
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func figure(
        symbol: String,
        tint: Color,
        value: String,
        title: LocalizedStringResource
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Rows

    private func historyRow(_ row: EventHistory.Row) -> some View {
        let occurrence = row.occurrence
        return Button { store.send(.rowTapped(row.id)) } label: {
            HStack(spacing: 12) {
                Image(systemName: occurrence.kind.symbol)
                    .font(.callout)
                    .foregroundStyle(occurrence.kind.tint)
                    .frame(width: 38, height: 38)
                    .background(
                        occurrence.kind.tint.opacity(0.16),
                        in: .rect(cornerRadius: 11, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(occurrence.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle(for: row))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    if row.spent > 0, let currency = row.currency {
                        Text(Money.text(row.spent, currency: currency))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(row.isOverBudget ? Palette.danger : .primary)
                    }
                    if row.going > 0 {
                        Label {
                            Text(row.going.formatted())
                        } icon: {
                            Image(systemName: "person.2.fill")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius)
    }

    /// When it was, and — for a series — how many times.
    private func subtitle(for row: EventHistory.Row) -> String {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
        let day = row.occurrence.start.formatted(style)
        guard row.times > 1 else { return day }
        return String(localized: L10n.calendarHistoryTimes(row.times, day))
    }
}
