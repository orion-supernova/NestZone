import ComposableArchitecture
import Foundation

/// Settings → Calendar: what the person's own calendars get from the house.
///
/// Two things: copying house events into calendars the person chooses, and the
/// other way round, sharing some of the person's own calendars with this house.
///
/// Everything here is per device: the calendars are on this phone, and a second
/// phone of the same person chooses for itself. Sharing is also per house (what
/// is shown to a partner and to flatmates are different things), which is why
/// this page knows which house it was opened from. Both are Plus; a house
/// without it sees the controls locked and the paywall at the tap. Nothing is
/// shared until the person picks it: turning sharing on marks every calendar
/// as seen and not shared.
@Reducer
public struct CalendarSettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID

        @Shared(.calendarShareChoicesRaw) public var shareChoicesRaw: String
        @Shared(.calendarShareDefaultLevelRaw) public var shareDefaultLevelRaw: String
        @Shared(.calendarShareWeeks) public var shareWeeks: Int
        @Shared(.calendarCopyChoicesRaw) public var copyChoicesRaw: String
        @Shared(.calendarCopyMode) public var mode: CalendarCopyMode
        @Shared(.calendarCopyLastMode) public var lastMode: CalendarCopyMode
        @Shared(.calendarCopyTargetsRaw) public var targetsRaw: String
        @Shared(.calendarCopyReminders) public var copyReminders: Bool
        @Shared(.calendarLastSynced) public var lastSynced: Double
        @Shared(.calendarShareLastSynced) public var shareLastSynced: Double
        @Shared(.calendarSharePlanCount) public var planCount: Int
        @Shared(.calendarSyncActive) public var syncActive: Set<String>
        @Shared(.pro) public var pro: ProStatus

        public var access: DeviceCalendarAccess = .notDetermined
        public var calendars: [DeviceCalendar] = []
        /// The calendars grouped by account, built when they arrive.
        public var groups: [CalendarGroup] = []
        /// Copies this phone has made, to know whether turning off needs to ask.
        public var copyCount = 0
        /// Where the phone would put a new event; the first thing copying is
        /// pointed at when nothing was chosen.
        public var defaultCalendarID: String?

        /// The calendars sharing can offer: every one but birthdays, grouped by
        /// account.
        public var shareGroups: [CalendarGroup] = []
        /// What the server holds for this person in this house, for "Updated".
        public var shareRow: CalendarShareRow?
        /// The explainer was opened by the sharing switch, so its answer turns
        /// sharing on and not copying.
        public var isExplainingShare = false

        /// The house's people, to name their calendars.
        public var members: [User] = []
        /// Housemates who share calendars with this house, live.
        public var housemates: [HousemateShare] = []
        /// The housemate whose "Add to my calendar" opened the explainer.
        public var explainingOwner: String?

        /// Where a "Sync now" is: running while the passes have it, a tick
        /// for a moment after.
        public var syncPhase: SyncPhase = .idle
        /// Taps on "Sync now", so the haptic is the person's own and nothing a
        /// live push can also move.
        public var syncTaps = 0

        public enum SyncPhase: Equatable, Sendable { case idle, running, done }

        public var isExplaining = false
        /// The explainer was opened by "Allow calendar access" alone: its yes
        /// asks the system and switches nothing on.
        public var isExplainingAccess = false
        public var isConnecting = false
        /// "Remove the copies from your calendars?"
        @Presents public var dialog: ConfirmationDialogState<Action.Dialog>?

        public init(homeID: HomeID, members: [User] = []) {
            self.homeID = homeID
            self.members = members
        }

        /// "Housemates can add my calendar to theirs": this phone's answer, or
        /// the server's when this phone never gave one.
        public var allowCopy: Bool { shareChoices.house(homeID).allowCopy ?? shareRow?.allowCopy ?? false }

        public func name(of id: String) -> String? {
            members.first { $0.id.rawValue == id }?.displayName
        }

        public func isCopying(_ id: String) -> Bool {
            CalendarCopyChoices.decode(copyChoicesRaw).house(homeID).owners[id] != nil
        }

        /// Housemates who share, other than the person, with a name to show.
        public var copyRows: [(share: HousemateShare, name: String)] {
            housemates.compactMap { share in name(of: share.id).map { (share, $0) } }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        public var shareChoices: CalendarShareChoices { .decode(shareChoicesRaw) }
        public var isShareOn: Bool { shareChoices.house(homeID).isOn }
        public var shareDefaultLevel: CalendarShareLevel {
            CalendarShareLevel(rawValue: shareDefaultLevelRaw) ?? .busy
        }

        /// The level a calendar is at, or will be given.
        public func shareLevel(of key: String) -> CalendarShareLevel {
            shareChoices.house(homeID).level(of: key)
        }

        public var isOn: Bool { mode != .off }

        /// How many of the phone's calendars are shared, and how many could be.
        public var sharedCalendarCount: (shared: Int, total: Int) {
            let house = shareChoices.house(homeID)
            let all = shareGroups.flatMap(\.calendars)
            return (all.filter { house.level(of: $0.key).isShared }.count, all.count)
        }

        /// The calendar copies go into, said short: the first by name and how
        /// many more.
        public var intoSummary: String? {
            let chosen = calendars.filter { targets.contains($0.id) }
            guard let first = chosen.first else { return nil }
            return chosen.count > 1 ? "\(first.title) +\(chosen.count - 1)" : first.title
        }

        /// The latest of the passes, as a date; `nil` before any.
        public var lastSyncedDate: Date? {
            let latest = max(lastSynced, shareLastSynced)
            return latest > 0 ? Date(timeIntervalSince1970: latest) : nil
        }

        /// Something is set to move calendars, so syncing has a meaning.
        public var hasSomethingToSync: Bool { isShareOn || isOn || !copyOwnersEmpty }
        private var copyOwnersEmpty: Bool {
            CalendarCopyChoices.decode(copyChoicesRaw).house(homeID).owners.isEmpty
        }
        public var targets: Set<String> { Set(CalendarLists.calendars(targetsRaw)) }

        public struct CalendarGroup: Equatable, Identifiable, Sendable {
            public var account: String
            public var calendars: [DeviceCalendar]
            public var id: String { account }
        }
    }

    public enum Action: BindableAction {
        case task
        /// The phone's calendar database changed: an account was added, a
        /// calendar made or hidden, in this app or another.
        case storeChanged
        case reload
        case loaded(DeviceCalendarAccess, [DeviceCalendar], defaultID: String?, copies: Int, shareable: [DeviceCalendar])
        case shareToggled(Bool)
        case shareLevelSelected(String, CalendarShareLevel)
        case shareDefaultSelected(CalendarShareLevel)
        case shareWeeksSelected(Int)
        case shareRowUpdated(CalendarShareRow?)
        case allowCopyToggled(Bool)
        case housematesUpdated([HousemateShare])
        case housemateToggled(String, Bool)
        case housemateRemoved
        case copyToggled(Bool)
        case remindersToggled(Bool)
        case modeSelected(CalendarCopyMode)
        case targetToggled(String)
        /// The explainer's Continue: the system prompt may be shown now.
        case connectTapped
        case openSystemSettingsTapped
        /// The access card's button: the explainer, then the system prompt.
        case allowAccessTapped
        /// "Sync now": asks the tab bar's passes to run, and waits for them.
        case syncNowTapped
        case syncFinished
        case syncReset
        case copiesRemoved
        case binding(BindingAction<State>)
        case dialog(PresentationAction<Dialog>)
        case delegate(Delegate)

        public enum Dialog: Equatable {
            case removeCopies
            case keepCopies
            case removeHousemate(String)
        }

        public enum Delegate: Equatable {
            /// A setting that decides what is copied moved: the mirror syncs.
            case changed
            /// "Sync now": the sharing, copying and housemates' passes run
            /// once. Raised, never done here: the passes belong to the tab bar.
            case syncRequested
        }
    }

    private enum CancelID { case reload, sync }

    @Dependency(\.deviceCalendar) var deviceCalendar
    @Dependency(\.calendarMirror) var calendarMirror
    @Dependency(\.sharedCopy) var sharedCopy
    @Dependency(\.calendarShare) var calendarShare
    @Dependency(\.paywall) var paywall
    @Dependency(\.openURL) var openURL
    @Dependency(\.continuousClock) var clock

    public init() {}

    /// Everything on this page is a write to what the phone does for the house,
    /// and writing is Plus.
    static func writes(_ action: Action) -> Bool {
        switch action {
        case .syncNowTapped, .copyToggled(true), .modeSelected, .targetToggled, .connectTapped, .remindersToggled,
             .shareToggled(true), .allowCopyToggled(true), .housemateToggled(_, true): true
        // Off is never gated: stopping is always allowed.
        case let .shareLevelSelected(_, level): level.isShared
        default: false
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            if !state.pro.isPro, Self.writes(action) {
                return .run { _ in paywall.request(.calendar) }
            }
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    load(),
                    // So an account added in Settings while this page is open
                    // (the way a Google calendar gets here) shows up on return.
                    .run { send in
                        for await _ in deviceCalendar.changes() { await send(.storeChanged) }
                    },
                    .run { send in
                        await Backoff.retrying(clock: clock) { delivered in
                            for try await row in calendarShare.mine(homeID) {
                                delivered()
                                await send(.shareRowUpdated(row))
                            }
                        }
                    },
                    .run { send in
                        await Backoff.retrying(clock: clock) { delivered in
                            for try await rows in calendarShare.housemates(homeID) {
                                delivered()
                                await send(.housematesUpdated(rows))
                            }
                        }
                    }
                )

            // One change is often several notifications; read once they stop.
            case .storeChanged:
                return .run { send in
                    try await clock.sleep(for: .milliseconds(500))
                    await send(.reload)
                }
                .cancellable(id: CancelID.reload, cancelInFlight: true)

            case .reload:
                return load()

            case let .housematesUpdated(rows):
                state.housemates = rows
                // A housemate who changed their name is called by it in the
                // calendar's title at the next sync.
                let homeID = state.homeID
                let names = Dictionary(uniqueKeysWithValues: state.members.map { ($0.id.rawValue, $0.displayName) })
                let before = state.copyChoicesRaw
                state.$copyChoicesRaw.withLock { raw in
                    var choices = CalendarCopyChoices.decode(raw)
                    choices.update(homeID) { house in
                        for (id, owner) in house.owners {
                            if let name = names[id], name != owner.name { house.owners[id] = .init(name: name) }
                        }
                    }
                    let next = choices.raw
                    if next != raw { raw = next }
                }
                return before == state.copyChoicesRaw ? .none : .send(.delegate(.changed))

            case let .allowCopyToggled(isOn):
                let homeID = state.homeID
                state.$shareChoicesRaw.withLock { raw in
                    var choices = CalendarShareChoices.decode(raw)
                    choices.update(homeID) { $0.allowCopy = isOn }
                    raw = choices.raw
                }
                return .send(.delegate(.changed))

            case let .housemateToggled(id, true):
                guard let name = state.name(of: id) else { return .none }
                switch state.access {
                case .notDetermined:
                    state.explainingOwner = id
                    state.isExplainingShare = false
                    state.isExplaining = true
                    return .none
                case .granted:
                    let homeID = state.homeID
                    state.$copyChoicesRaw.withLock { raw in
                        var choices = CalendarCopyChoices.decode(raw)
                        choices.update(homeID) { $0.owners[id] = .init(name: name) }
                        raw = choices.raw
                    }
                    return .send(.delegate(.changed))
                case .writeOnly, .denied, .restricted:
                    return .none
                }

            case let .housemateToggled(id, false):
                guard state.isCopying(id), let name = state.name(of: id) else { return .none }
                state.dialog = .removeHousemate(id, name: name)
                return .none

            case .housemateRemoved:
                return .none

            case let .shareRowUpdated(row):
                state.shareRow = row
                return .none

            case let .loaded(access, calendars, defaultID, copies, shareable):
                state.access = access
                state.calendars = calendars
                state.groups = calendars.groupedByAccount().map {
                    State.CalendarGroup(account: $0.account, calendars: $0.calendars)
                }
                state.copyCount = copies
                state.defaultCalendarID = defaultID
                state.shareGroups = shareable.groupedByAccount().map {
                    State.CalendarGroup(account: $0.account, calendars: $0.calendars)
                }
                state.isConnecting = false
                if access == .granted {
                    // A calendar that turned up since sharing was set up gets
                    // the default for new ones, the same as the sync would
                    // give it.
                    let homeID = state.homeID
                    let level = state.shareDefaultLevel
                    let keys = shareable.map(\.key)
                    state.$shareChoicesRaw.withLock { raw in
                        var choices = CalendarShareChoices.decode(raw)
                        let before = choices
                        choices.adoptNew(homeID, keys: keys, defaultLevel: level)
                        if choices != before { raw = choices.raw }
                    }
                }
                // Calendars that have since gone drop out of the choice.
                let existing = Set(calendars.map(\.id))
                if access == .granted {
                    let kept = state.targets.intersection(existing)
                    if kept != state.targets {
                        state.$targetsRaw.withLock { $0 = CalendarLists.raw(calendars: kept.sorted()) }
                    }
                }
                return .none

            case .shareToggled(true):
                switch state.access {
                case .notDetermined:
                    state.isExplainingShare = true
                    state.isExplaining = true
                    return .none
                case .granted:
                    let homeID = state.homeID
                    let keys = state.shareGroups.flatMap { $0.calendars.map(\.key) }
                    state.$shareChoicesRaw.withLock { raw in
                        var choices = CalendarShareChoices.decode(raw)
                        choices.update(homeID) { house in
                            house.isOn = true
                            // What is on the phone now is seen and not shared;
                            // only calendars that come later get the default.
                            house.known.formUnion(keys)
                            house.stopAll = false
                        }
                        raw = choices.raw
                    }
                    return .send(.delegate(.changed))
                case .writeOnly, .denied, .restricted:
                    return .none
                }

            case .shareToggled(false):
                let homeID = state.homeID
                guard state.isShareOn else { return .none }
                // The server is told to forget by the share engine, from this
                // mark, and tries again until it has.
                state.$shareChoicesRaw.withLock { raw in
                    var choices = CalendarShareChoices.decode(raw)
                    choices.update(homeID) { house in
                        house.isOn = false
                        house.stopAll = true
                    }
                    raw = choices.raw
                }
                return .send(.delegate(.changed))

            case let .shareLevelSelected(key, level):
                let homeID = state.homeID
                state.$shareChoicesRaw.withLock { raw in
                    var choices = CalendarShareChoices.decode(raw)
                    choices.update(homeID) { house in
                        house.known.insert(key)
                        if level.isShared {
                            house.levels[key] = level
                            house.stopKeys.remove(key)
                        } else {
                            house.levels[key] = nil
                            house.stopKeys.insert(key)
                        }
                    }
                    raw = choices.raw
                }
                return .send(.delegate(.changed))

            case let .shareDefaultSelected(level):
                state.$shareDefaultLevelRaw.withLock { $0 = level.rawValue }
                return .none

            case let .shareWeeksSelected(weeks):
                guard [4, 8, 12].contains(weeks), weeks != state.shareWeeks else { return .none }
                state.$shareWeeks.withLock { $0 = weeks }
                return .send(.delegate(.changed))

            case .copyToggled(true):
                switch state.access {
                case .notDetermined:
                    state.isExplainingShare = false
                    state.isExplaining = true
                    return .none
                case .granted:
                    return turnOn(&state)
                case .writeOnly, .denied, .restricted:
                    // The Settings row says why and how to fix it.
                    return .none
                }

            case .copyToggled(false):
                guard state.isOn else { return .none }
                let current = state.mode
                state.$lastMode.withLock { $0 = current }
                state.$mode.withLock { $0 = .off }
                guard state.copyCount > 0 else { return .send(.delegate(.changed)) }
                state.dialog = .removeCopies
                return .send(.delegate(.changed))

            case let .modeSelected(mode):
                guard mode != .off, mode != state.mode else { return .none }
                state.$mode.withLock { $0 = mode }
                return .send(.delegate(.changed))

            case let .targetToggled(id):
                var targets = state.targets
                if !targets.insert(id).inserted { targets.remove(id) }
                state.$targetsRaw.withLock { $0 = CalendarLists.raw(calendars: targets.sorted()) }
                return .send(.delegate(.changed))

            case .allowAccessTapped:
                state.isExplainingShare = false
                state.explainingOwner = nil
                state.isExplainingAccess = true
                state.isExplaining = true
                return .none

            case .connectTapped:
                state.isExplaining = false
                state.isConnecting = true
                if state.isExplainingAccess {
                    state.isExplainingAccess = false
                    return request(then: .nothing)
                }
                let thenShare = state.isExplainingShare
                state.isExplainingShare = false
                let owner = state.explainingOwner
                state.explainingOwner = nil
                return request(then: owner.map { .owner($0) } ?? (thenShare ? .share : .copy))

            case .openSystemSettingsTapped:
                return .run { _ in
                    if let url = URL(string: "app-settings:") { await openURL(url) }
                }

            case .dialog(.presented(.removeCopies)):
                state.copyCount = 0
                return .run { send in
                    _ = await calendarMirror.removeAll(deviceCalendar, nil, false)
                    await send(.copiesRemoved)
                }

            case .dialog(.presented(.keepCopies)):
                return .none

            case let .dialog(.presented(.removeHousemate(id))):
                let homeID = state.homeID
                state.$copyChoicesRaw.withLock { raw in
                    var choices = CalendarCopyChoices.decode(raw)
                    choices.update(homeID) { $0.owners[id] = nil }
                    raw = choices.raw
                }
                return .merge(
                    .send(.delegate(.changed)),
                    .run { send in
                        _ = await sharedCopy.removeOwner(deviceCalendar, homeID, id)
                        await send(.housemateRemoved)
                    }
                )

            case .copiesRemoved:
                state.copyCount = 0
                return .none

            case .syncNowTapped:
                guard state.syncPhase != .running else { return .none }
                state.syncPhase = .running
                state.syncTaps += 1
                return .merge(
                    .send(.delegate(.syncRequested)),
                    .run { [active = state.$syncActive] send in
                        // The passes put themselves in `active` as they take
                        // the request; a beat for them to do so, then wait
                        // for them to leave. A phone that never answers does
                        // not hold the spinner past twenty seconds.
                        try await clock.sleep(for: .milliseconds(600))
                        var waited = 0
                        while !active.withLock({ $0.isEmpty }), waited < 40 {
                            try await clock.sleep(for: .milliseconds(500))
                            waited += 1
                        }
                        await send(.syncFinished)
                        try await clock.sleep(for: .seconds(2))
                        await send(.syncReset)
                    }
                    .cancellable(id: CancelID.sync, cancelInFlight: true)
                )

            case .syncFinished:
                state.syncPhase = .done
                return .none

            case .syncReset:
                state.syncPhase = .idle
                return .none

            case let .remindersToggled(isOn):
                state.$copyReminders.withLock { $0 = isOn }
                return .send(.delegate(.changed))

            case .binding, .dialog, .delegate:
                return .none
            }
        }
        .ifLet(\.$dialog, action: \.dialog)
    }

    /// The system prompt, after the explainer. Its answer turns copying on
    /// when it is a yes.
    private enum Then: Sendable {
        case copy, share, nothing
        case owner(String)
    }

    private func request(then: Then) -> Effect<Action> {
        .run { send in
            let access = (try? await deviceCalendar.requestAccess()) ?? deviceCalendar.access()
            await send(.loaded(
                access,
                access == .granted ? await deviceCalendar.calendars() : [],
                defaultID: access == .granted ? await deviceCalendar.defaultCalendarID() : nil,
                copies: await calendarMirror.copyCount(),
                shareable: access == .granted ? await deviceCalendar.shareableCalendars() : []
            ))
            if access == .granted {
                switch then {
                case .copy: await send(.copyToggled(true))
                case .share: await send(.shareToggled(true))
                case let .owner(id): await send(.housemateToggled(id, true))
                case .nothing: break
                }
            }
        }
    }

    private func load() -> Effect<Action> {
        .run { send in
            let access = deviceCalendar.access()
            let granted = access == .granted
            await send(.loaded(
                access,
                granted ? await deviceCalendar.calendars() : [],
                defaultID: granted ? await deviceCalendar.defaultCalendarID() : nil,
                copies: await calendarMirror.copyCount(),
                shareable: granted ? await deviceCalendar.shareableCalendars() : []
            ))
        }
    }

    /// First time on: the least surprising mode, "only the ones I add", into
    /// the phone's own default calendar when nothing was chosen yet.
    private func turnOn(_ state: inout State) -> Effect<Action> {
        let previous = state.lastMode == .off ? CalendarCopyMode.onlyMine : state.lastMode
        state.$mode.withLock { $0 = previous }
        if state.targets.isEmpty, let id = state.defaultCalendarID {
            state.$targetsRaw.withLock { $0 = id }
        }
        return .send(.delegate(.changed))
    }
}

extension ConfirmationDialogState where Action == CalendarSettingsFeature.Action.Dialog {
    static var removeCopies: Self {
        ConfirmationDialogState {
            TextState(String(localized: L10n.calendarCopyRemoveTitle))
        } actions: {
            ButtonState(role: .destructive, action: .removeCopies) {
                TextState(String(localized: L10n.calendarCopyRemove))
            }
            ButtonState(role: .cancel, action: .keepCopies) {
                TextState(String(localized: L10n.calendarCopyKeep))
            }
        } message: {
            TextState(String(localized: L10n.calendarCopyRemoveMessage))
        }
    }
}

extension ConfirmationDialogState where Action == CalendarSettingsFeature.Action.Dialog {
    static func removeHousemate(_ id: String, name: String) -> Self {
        ConfirmationDialogState {
            TextState(String(localized: L10n.calendarSharedCopyRemoveTitle(name)))
        } actions: {
            ButtonState(role: .destructive, action: .removeHousemate(id)) {
                TextState(String(localized: L10n.calendarSharedCopyRemove))
            }
            ButtonState(role: .cancel, action: .keepCopies) {
                TextState(String(localized: L10n.calendarCopyKeep))
            }
        } message: {
            TextState(String(localized: L10n.calendarSharedCopyRemoveMessage))
        }
    }
}
