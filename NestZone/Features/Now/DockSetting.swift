import Foundation

/// What the dock above the tab bar is allowed to show.
public enum DockMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// The one live thing, by `DockItem`'s rules: what the bar has always done.
    case automatic
    /// One chosen thing (`DockThing`), whether or not it has anything to say.
    case always
    /// No live thing: the bar is just the way to add something.
    case addOnly
    /// No bar at all.
    case off

    public var id: String { rawValue }

    public init(from decoder: any Decoder) throws {
        let raw = try? decoder.singleValueContainer().decode(String.self)
        self = raw.flatMap(Self.init(rawValue:)) ?? .automatic
    }

    public var title: LocalizedStringResource {
        switch self {
        case .automatic: L10n.dockModeAutomatic
        case .always: L10n.dockModeAlways
        case .addOnly: L10n.dockModeAddOnly
        case .off: L10n.dockModeOff
        }
    }

    public var symbol: String {
        switch self {
        case .automatic: "wand.and.sparkles"
        case .always: "pin.fill"
        case .addOnly: "plus.circle"
        case .off: "rectangle.bottomthird.inset.filled"
        }
    }

    /// One line under the picker saying what the choice does.
    public var meaning: LocalizedStringResource {
        switch self {
        case .automatic: L10n.dockMeaningAutomatic
        case .always: L10n.dockMeaningAlways
        case .addOnly: L10n.dockMeaningAddOnly
        case .off: L10n.dockMeaningOff
        }
    }
}

/// The thing the dock keeps, in `DockMode.always`.
public enum DockThing: String, CaseIterable, Identifiable, Codable, Sendable {
    case dinner, event, movieRound

    public var id: String { rawValue }

    public init(from decoder: any Decoder) throws {
        let raw = try? decoder.singleValueContainer().decode(String.self)
        self = raw.flatMap(Self.init(rawValue:)) ?? .dinner
    }

    public var title: LocalizedStringResource {
        switch self {
        case .dinner: L10n.dockThingDinner
        case .event: L10n.dockThingEvent
        case .movieRound: L10n.dockThingMovieRound
        }
    }

    public var symbol: String {
        switch self {
        case .dinner: "fork.knife"
        case .event: "calendar"
        case .movieRound: "popcorn.fill"
        }
    }

    /// The calendar is Plus, so the dock cannot keep the next event for a
    /// house without it.
    public var needsPlus: Bool { self == .event }
}

public struct DockSetting: Codable, Equatable, Sendable {
    public var mode: DockMode = .automatic
    public var thing: DockThing = .dinner

    public init(mode: DockMode = .automatic, thing: DockThing = .dinner) {
        self.mode = mode
        self.thing = thing
    }

    /// What is drawn for a house that has, or has not, Plus: asking for the
    /// next event without it is the automatic dock, never an empty one.
    public func effective(isPro: Bool) -> DockSetting {
        if mode == .always, thing.needsPlus, !isPro { return DockSetting() }
        return self
    }
}

/// Every house's dock setting, by house id.
///
/// Kept on this phone, like Today's layout and the tab segments: a person's
/// dock is how *they* want their phone to look, and it is per house because a
/// dinner dock means nothing in a house that never plans meals. Not server
/// state, so no backend or older build is involved. A missing house is the
/// default, which is the automatic dock.
public struct DockSettings: Codable, Equatable, Sendable, RawRepresentable {
    var byHome: [String: DockSetting] = [:]

    public init() {}

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: DockSetting].self, from: data)
        else { return nil }
        byHome = decoded
    }

    public var rawValue: String {
        // Sorted, so an unchanged map is an unchanged string and app storage
        // does not announce a change that is not one.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(byHome)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    public subscript(home: HomeID) -> DockSetting {
        get { byHome[home.rawValue] ?? DockSetting() }
        set {
            if newValue == DockSetting() {
                byHome[home.rawValue] = nil
            } else {
                byHome[home.rawValue] = newValue
            }
        }
    }
}
