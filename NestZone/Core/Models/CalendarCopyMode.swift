import Foundation

/// Which house events are copied into the person's own calendars.
///
/// A per-device setting: the person's calendars are on this phone, and a second
/// phone of the same person chooses for itself.
public enum CalendarCopyMode: String, CaseIterable, Identifiable, Sendable {
    /// Nothing, except what the composer's "Also add to" asked for by name.
    case off
    /// What this person added.
    case onlyMine
    /// What they are in: invited, answered, or an event naming nobody, which is
    /// the whole house's. The same rule as the people filter for "Me".
    case involvingMe
    case everything

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .off: L10n.calendarCopyOff
        case .onlyMine: L10n.calendarCopyOnlyMine
        case .involvingMe: L10n.calendarCopyInvolvingMe
        case .everything: L10n.calendarCopyEverything
        }
    }

    /// The modes a person can pick once copying is on.
    public static let onModes: [CalendarCopyMode] = [.onlyMine, .involvingMe, .everything]

    /// Whether this mode would copy `occurrence` for `user`.
    public func wants(_ occurrence: EventOccurrence, user: UserID?) -> Bool {
        switch self {
        case .off: false
        case .everything: true
        case .onlyMine: user != nil && occurrence.createdBy == user
        case .involvingMe: occurrence.isMine(user)
        }
    }
}
