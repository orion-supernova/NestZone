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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                            .foregroundStyle(.secondaryText)
                        pillLayout {
                            ForEach(group.calendars) { calendar in
                                calendarPill(calendar)
                            }
                        }
                    }
                }

                Text(L10n.calendarAlsoAddFooter)
                    .font(.caption)
                    .foregroundStyle(.secondaryText)
            }
            // Reduce Motion keeps the tick (a glyph change) and drops the
            // pills' spring.
            .animation(reduceMotion ? nil : Motion.spring, value: store.alsoAdd)
        }
    }

    /// Pills wrap side by side; at accessibility sizes a calendar's name is
    /// wider than half the card, so each gets a line of its own.
    private var pillLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(FlowLayout(spacing: 8))
    }

    private func calendarPill(_ calendar: DeviceCalendar) -> some View {
        let isOn = store.alsoAdd.contains(calendar.id)
        return Button { store.send(.alsoAddToggled(calendar.id)) } label: {
            HStack(spacing: 6) {
                Circle().fill(calendar.color).frame(width: 10, height: 10)
                Text(calendar.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    .multilineTextAlignment(.leading)
                if typeSize.isAccessibilitySize { Spacer(minLength: 0) }
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
            // The pill stays as drawn; the finger gets the full 44 points.
            .frame(minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(verbatim: "\(calendar.accountTitle), \(calendar.title)"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var header: some View {
        Label {
            Text(L10n.calendarAlsoAddTitle)
        } icon: {
            Image(systemName: "calendar.badge.plus").foregroundStyle(.accentText)
        }
        .font(.subheadline.weight(.medium))
    }

    private var connectLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private var connect: some View {
        GlassCard {
            connectLayout {
                header
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Button { isExplaining = true } label: {
                    Text(L10n.calendarAlsoAddConnect)
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: Metrics.minTapTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accentText)
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
