import ComposableArchitecture
import SwiftUI

/// What a housemate chose to show of one calendar item: who, when, and the
/// title and place if they shared that much. Nothing on it can be changed.
struct SharedItemSheet: View {
    @Bindable var store: StoreOf<SharedItemDetailFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    card.appear(0)
                    Text(L10n.calendarSharedReadOnly)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: tint))
            .navigationTitle(Text(L10n.calendarSharedSheetTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(L10n.commonClose) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) { store.send(.reportTapped) } label: {
                            Label { Text(L10n.calendarSharedReport) } icon: {
                                Image(systemName: "exclamationmark.bubble")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(Text(L10n.commonMore))
                }
            }
            .hostedSheet(item: $store.scope(state: \.report, action: \.report)) { store in
                ReportSheet(store: store)
            }
            .overlay(alignment: .bottom) {
                if let notice = store.notice {
                    ReportNoticeToast(notice: notice)
                        .padding(.bottom, 12)
                        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity).reduced(reduceMotion))
                }
            }
            .animation(Motion.spring, value: store.notice)
        }
        .presentationDetents([.medium, .large])
    }

    private var tint: Color { MemberTint.color(for: store.item.userID.rawValue) }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Avatar(
                    initials: store.member?.initials ?? User.initials(from: store.name),
                    seed: store.item.userID.rawValue,
                    size: 44,
                    viewable: false
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(heading)
                        .font(.headline)
                        .lineLimit(3)
                    Text(L10n.calendarSharedBy(store.name))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                row(symbol: store.item.isAllDay ? "sun.max" : "clock", text: when)
                if let location = store.item.location, !location.isEmpty {
                    row(symbol: "mappin.and.ellipse", text: location)
                }
                row(symbol: "calendar", text: store.item.calendarName)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tinted: tint.opacity(0.14))
    }

    private func row(symbol: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heading: String {
        store.item.shownTitle ?? String(localized: L10n.calendarSharedBusyIs(store.name))
    }

    /// "Saturday 24 October · 14:00 – 15:30", or the day and "All day".
    private var when: String {
        let item = store.item
        let date = item.start.formatted(
            Date.FormatStyle(date: .complete, time: .omitted).locale(L10n.locale)
        )
        return "\(date) · \(item.timeText)"
    }
}
