import ComposableArchitecture
import SwiftUI

/// "Also add to": the person's own calendars this event is copied into, under
/// the time. Drawn only for a house with Plus (copying is Plus), once the phone
/// has said yes to calendar access, or while it has not yet been asked, when it
/// offers to connect after the explainer.
struct EventAlsoAddCard: View {
    @Bindable var store: StoreOf<EventComposerFeature>

    @Shared(.pro) private var pro: ProStatus
    @Environment(\.theme) private var theme
    @State private var isExplaining = false

    var body: some View {
        Group {
            if pro.isPro {
                switch store.calendarAccess {
                case .granted where !store.deviceCalendars.isEmpty:
                    chooser
                case .notDetermined:
                    connect
                default:
                    EmptyView()
                }
            }
        }
    }

    private var chooser: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                ForEach(store.deviceCalendars.groupedByAccount(), id: \.account) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.account)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(group.calendars) { calendar in
                                calendarPill(calendar)
                            }
                        }
                    }
                }

                Text(L10n.calendarAlsoAddFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .animation(Motion.spring, value: store.alsoAdd)
        }
    }

    private func calendarPill(_ calendar: DeviceCalendar) -> some View {
        let isOn = store.alsoAdd.contains(calendar.id)
        return Button { store.send(.alsoAddToggled(calendar.id)) } label: {
            HStack(spacing: 6) {
                Circle().fill(calendar.color).frame(width: 10, height: 10)
                Text(calendar.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(isOn ? theme.accent : Palette.accessory)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isOn ? theme.accent.opacity(0.14) : Color.clear, in: .capsule)
            .overlay {
                if !isOn { Capsule().strokeBorder(.quaternary, lineWidth: 1) }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(verbatim: "\(calendar.accountTitle), \(calendar.title)"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var header: some View {
        Label {
            Text(L10n.calendarAlsoAddTitle)
        } icon: {
            Image(systemName: "calendar.badge.plus").foregroundStyle(theme.accent)
        }
        .font(.subheadline.weight(.medium))
    }

    private var connect: some View {
        GlassCard {
            HStack(spacing: 12) {
                header
                Spacer(minLength: 8)
                Button { isExplaining = true } label: {
                    Text(L10n.calendarAlsoAddConnect)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
        }
        .hostedSheet(isPresented: $isExplaining) {
            CalendarAccessExplainer(
                isWorking: store.isConnectingCalendars,
                onContinue: {
                    store.send(.connectCalendarsTapped)
                    isExplaining = false
                },
                onNotNow: { isExplaining = false }
            )
        }
    }
}
