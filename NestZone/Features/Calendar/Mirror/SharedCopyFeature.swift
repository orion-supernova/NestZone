import ComposableArchitecture
import Foundation
import UIKit

/// Keeps the housemates' calendars the person switched on ("Add to my
/// calendar", Settings → Calendar) current in their own calendar app, for as
/// long as the tab bar is up.
///
/// App-wide for the same reason as `CalendarMirrorFeature`: Calendar being
/// closed must not stop a copy following its owner. It opens
/// `calendarShare:inRange` for the next four months only while at least one
/// switch is on and the house has Plus, hands each answer to
/// `SharedCopyClient`, and syncs again when the phone's calendar database
/// changes (a calendar deleted by hand is found there), when the app returns
/// to the foreground and when a setting moves. The answer carries each owner's
/// `allow_copy`, so consent withdrawn on their phone takes the copies out here
/// at the next answer. A house that loses Plus stops updating; what is on the
/// phone stays.
@Reducer
public struct SharedCopyFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        var items: [SharedBusyItem] = []
        var window: Date?
        var answeredAt: Date = .distantPast
        var previousKeys: Set<String>?
        var following: Following?

        struct Following: Equatable {
            var homeID: HomeID
            var day: Date
            var hasAccess: Bool
        }

        @Shared(.calendarCopyChoicesRaw) var choicesRaw: String
        @Shared(.pro) var pro: ProStatus

        public init(homeID: HomeID) {
            self.homeID = homeID
        }

        var owners: [String: CalendarCopyChoices.Owner] {
            CalendarCopyChoices.decode(choicesRaw).house(homeID).owners
        }
    }

    public enum Action {
        case task
        case settingsChanged
        case becameActive
        case itemsUpdated([SharedBusyItem], from: Date)
        case calendarStoreChanged
        case syncDue
        case synced(SharedCopySummary)
    }

    private enum CancelID { case items, store, sync }

    /// How far ahead copies reach. The server holds at most 120 days of a
    /// sharer's calendar.
    static let horizon: TimeInterval = 120 * 86_400

    @Dependency(\.calendarShare) var calendarShare
    @Dependency(\.deviceCalendar) var deviceCalendar
    @Dependency(\.sharedCopy) var sharedCopy
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    start(&state, restart: true),
                    .run { send in
                        for await _ in deviceCalendar.changes() { await send(.calendarStoreChanged) }
                    }
                    .cancellable(id: CancelID.store, cancelInFlight: true)
                )

            case .settingsChanged:
                return start(&state, restart: false)

            case .becameActive:
                return start(&state, restart: false, resync: false)

            case let .itemsUpdated(items, from):
                // Only a whole, non-empty answer can say an item was seen to
                // go; an empty one is a doubt (a share that has not loaded).
                state.previousKeys = state.window != nil
                    && !state.items.isEmpty
                    && state.items.count < SharedCopyRequest.answerLimit
                    ? Set(SharedCopyPlanner.keys(state.items, home: state.homeID.rawValue).map(\.1))
                    : nil
                state.answeredAt = now
                state.items = items
                state.window = from
                return .send(.syncDue)

            case .calendarStoreChanged:
                guard state.window != nil else { return .none }
                return .run { send in
                    try await clock.sleep(for: .seconds(1))
                    await send(.syncDue)
                }
                .cancellable(id: CancelID.sync, cancelInFlight: true)

            case .syncDue:
                guard state.pro.isLoaded, state.pro.isPro, let window = state.window else { return .none }
                let request = SharedCopyRequest(
                    homeID: state.homeID,
                    owners: Dictionary(
                        uniqueKeysWithValues: state.owners.map { id, owner in
                            (id, SharedCopyOwner(name: owner.name, colorHex: Self.hex(forOwner: id)))
                        }
                    ),
                    items: state.items,
                    windowStart: window,
                    now: now,
                    answeredAt: state.answeredAt,
                    previousKeys: state.previousKeys
                )
                return .run { send in
                    let summary = try await sharedCopy.sync(request, deviceCalendar)
                    await send(.synced(summary))
                } catch: { _, _ in }

            case let .synced(summary):
                guard !summary.dismissedOwners.isEmpty else { return .none }
                // The person deleted the calendar in the Calendar app: that is
                // the switch going off, and nothing is made again.
                let homeID = state.homeID
                let gone = summary.dismissedOwners
                state.$choicesRaw.withLock { raw in
                    var choices = CalendarCopyChoices.decode(raw)
                    choices.update(homeID) { house in
                        for id in gone { house.owners[id] = nil }
                    }
                    raw = choices.raw
                }
                return start(&state, restart: false, resync: false)
            }
        }
    }

    /// The housemate's tint (`MemberTint`) as `#RRGGBB`, for a calendar's colour.
    static func hex(forOwner id: String) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(hue: CGFloat(MemberTint.hue(for: id)), saturation: 0.62, brightness: 0.82, alpha: 1)
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    /// Opens the read while there is a switch on and Plus, closes it otherwise.
    /// A read already open for the same house and day is left alone.
    private func start(_ state: inout State, restart: Bool, resync: Bool = true) -> Effect<Action> {
        let homeID = state.homeID
        guard state.pro.isLoaded, state.pro.isPro, !state.owners.isEmpty else {
            state.following = nil
            return .cancel(id: CancelID.items)
        }
        let from = Calendar.current.startOfDay(for: now).addingTimeInterval(-86_400)
        let following = State.Following(
            homeID: homeID, day: from, hasAccess: deviceCalendar.access() == .granted
        )
        if !restart, state.following == following {
            return resync && state.window != nil ? .send(.syncDue) : .none
        }
        state.following = following
        guard following.hasAccess else { return .cancel(id: CancelID.items) }
        let to = from.addingTimeInterval(Self.horizon)
        return .run { send in
            await Backoff.retrying(clock: clock) { delivered in
                for try await items in calendarShare.inRange(homeID, from, to) {
                    delivered()
                    await send(.itemsUpdated(items, from: from))
                }
            }
        }
        .cancellable(id: CancelID.items, cancelInFlight: true)
    }
}
