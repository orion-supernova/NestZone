import SwiftUI

/// A housemate's calendar item, drawn so it cannot be taken for a house event.
///
/// A house event is a filled card with a coloured rail; this is an outline with
/// no fill, dashed, in the person's own tint, with their face where the rail
/// would be. It says "busy" when that is all they chose to show, and nothing
/// on it answers a tap but opening the read-only sheet.
public struct SharedItemRow: View {
    private let item: SharedBusyItem
    private let name: String
    private let initials: String
    private let showsDate: Bool
    private let action: () -> Void

    public init(
        item: SharedBusyItem,
        name: String,
        initials: String,
        showsDate: Bool = false,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.name = name
        self.initials = initials
        self.showsDate = showsDate
        self.action = action
    }

    public var body: some View {
        let tint = MemberTint.color(for: item.userID.rawValue)
        HStack(spacing: 10) {
            Avatar(initials: initials, seed: item.userID.rawValue, size: 24, viewable: false)

            VStack(alignment: .leading, spacing: 3) {
                if let title = item.shownTitle {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text(L10n.calendarSharedBusyLine(name))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(showsDate ? dateAndTime : item.timeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if item.shownTitle != nil {
                        Text("·").foregroundStyle(.tertiary)
                        Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if let location = item.location, !location.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Label {
                            Text(location).lineLimit(1)
                        } icon: {
                            Image(systemName: "mappin")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
        }
        .opacity(item.isPast ? 0.55 : 1)
        // Not a `Button`, for the reason `EventRow` is not: a button holds the
        // touch and a finger landing on one could not scroll the list.
        .contentShape(.rect)
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, action)
    }

    private var dateAndTime: String {
        let date = item.start.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
        )
        return item.isAllDay ? date : "\(date) · \(item.timeText)"
    }
}
