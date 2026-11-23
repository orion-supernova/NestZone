import ComposableArchitecture
import Foundation

/// Settings → Calendar: what the person's own calendars get from the house.
///
/// Today that is one thing, copying house events into calendars the person
/// chooses. The page is a form of sections so the next one (sharing the
/// person's calendars with the house) is one more `Section` under these.
///
/// Everything here is per device: the calendars are on this phone, and a second
/// phone of the same person chooses for itself. Copying is Plus; a house
/// without it sees the controls locked and the paywall at the tap.
@Reducer
public struct CalendarSettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        @Shared(.calendarCopyMode) public var mode: CalendarCopyMode
        @Shared(.calendarCopyTargetsRaw) public var targetsRaw: String
        @Shared(.calendarCopyReminders) public var copyReminders: Bool
        @Shared(.calendarLastSynced) public var lastSynced: Double
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

        public var isExplaining = false
        public var isConnecting = false
        /// "Remove the copies from your calendars?"
        @Presents public var dialog: ConfirmationDialogState<Action.Dialog>?

        public init() {}

        public var isOn: Bool { mode != .off }
        public var targets: Set<String> { Set(CalendarLists.calendars(targetsRaw)) }

        public struct CalendarGroup: Equatable, Identifiable, Sendable {
            public var account: String
            public var calendars: [DeviceCalendar]
            public var id: String { account }
        }
    }

    public enum Action: BindableAction {
        case task
        case loaded(DeviceCalendarAccess, [DeviceCalendar], defaultID: String?, copies: Int)
        case copyToggled(Bool)
        case remindersToggled(Bool)
        case modeSelected(CalendarCopyMode)
        case targetToggled(String)
        /// The explainer's Continue: the system prompt may be shown now.
        case connectTapped
        case openSystemSettingsTapped
        case copiesRemoved
        case binding(BindingAction<State>)
        case dialog(PresentationAction<Dialog>)
        case delegate(Delegate)

        public enum Dialog: Equatable {
            case removeCopies
            case keepCopies
        }

        public enum Delegate: Equatable {
            /// A setting that decides what is copied moved: the mirror syncs.
            case changed
        }
    }

    @Dependency(\.deviceCalendar) var deviceCalendar
    @Dependency(\.calendarMirror) var calendarMirror
    @Dependency(\.paywall) var paywall
    @Dependency(\.openURL) var openURL

    public init() {}

    /// Everything on this page is a write to what the phone does for the house,
    /// and writing is Plus.
    static func writes(_ action: Action) -> Bool {
        switch action {
        case .copyToggled(true), .modeSelected, .targetToggled, .connectTapped, .remindersToggled: true
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
                return load()

            case let .loaded(access, calendars, defaultID, copies):
                state.access = access
                state.calendars = calendars
                state.groups = calendars.groupedByAccount().map {
                    State.CalendarGroup(account: $0.account, calendars: $0.calendars)
                }
                state.copyCount = copies
                state.defaultCalendarID = defaultID
                state.isConnecting = false
                // Calendars that have since gone drop out of the choice.
                let existing = Set(calendars.map(\.id))
                if access == .granted {
                    let kept = state.targets.intersection(existing)
                    if kept != state.targets {
                        state.$targetsRaw.withLock { $0 = CalendarLists.raw(calendars: kept.sorted()) }
                    }
                }
                return .none

            case .copyToggled(true):
                switch state.access {
                case .notDetermined:
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

            case .connectTapped:
                state.isExplaining = false
                state.isConnecting = true
                return request()

            case .openSystemSettingsTapped:
                return .run { _ in
                    if let url = URL(string: "app-settings:") { await openURL(url) }
                }

            case .dialog(.presented(.removeCopies)):
                state.copyCount = 0
                return .run { send in
                    _ = await calendarMirror.removeAll(deviceCalendar)
                    await send(.copiesRemoved)
                }

            case .dialog(.presented(.keepCopies)):
                return .none

            case .copiesRemoved:
                state.copyCount = 0
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
    private func request() -> Effect<Action> {
        .run { send in
            let access = (try? await deviceCalendar.requestAccess()) ?? deviceCalendar.access()
            await send(.loaded(
                access,
                access == .granted ? await deviceCalendar.calendars() : [],
                defaultID: access == .granted ? await deviceCalendar.defaultCalendarID() : nil,
                copies: await calendarMirror.copyCount()
            ))
            if access == .granted { await send(.copyToggled(true)) }
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
                copies: await calendarMirror.copyCount()
            ))
        }
    }

    /// First time on: the least surprising mode, "only the ones I add", into
    /// the phone's own default calendar when nothing was chosen yet.
    private func turnOn(_ state: inout State) -> Effect<Action> {
        state.$mode.withLock { $0 = .onlyMine }
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
