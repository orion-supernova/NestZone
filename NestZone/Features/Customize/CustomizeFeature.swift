import ComposableArchitecture
import Foundation

/// Choosing what Today shows, when, and in what order.
///
/// Opened from Settings and from the bottom of Today. It used to open by
/// itself the first time, as a welcome that asked a brand-new household to
/// arrange eight modules it had never seen; a household with nothing in it
/// yet now gets a short checklist on Today instead, and nothing here is
/// required before using the app. Nothing is written until Done, so backing
/// out changes nothing.
@Reducer
public struct CustomizeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var layout: TodayLayout
        /// The house the dock setting belongs to; nil draws no Dock section.
        public var homeID: HomeID?
        /// The dock's setting, held here until Done like the layout.
        public var dock = DockSetting()

        @Shared(.todayLayoutRaw) var layoutRaw: String
        @Shared(.dockSettings) var dockSettings: DockSettings
        @Shared(.pro) var pro: ProStatus

        public init(homeID: HomeID? = nil) {
            self.layout = .default
            self.homeID = homeID
            self.layout = TodayLayout(raw: layoutRaw)
            if let homeID { self.dock = dockSettings[homeID] }
        }
    }

    public enum Action: Equatable {
        case visibilityPicked(TodaySection, SectionVisibility)
        case sectionsMoved(from: IndexSet, to: Int)
        case dockModePicked(DockMode)
        case dockThingPicked(DockThing)
        case resetTapped
        case doneTapped
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case finished
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .visibilityPicked(section, visibility):
                state.layout.set(section, to: visibility)
                return .none

            case let .sectionsMoved(from, to):
                state.layout.order.move(fromOffsets: from, toOffset: to)
                return .none

            case let .dockModePicked(mode):
                state.dock.mode = mode
                return .none

            case let .dockThingPicked(thing):
                state.dock.thing = thing
                return .none

            case .resetTapped:
                state.layout = .default
                state.dock = DockSetting()
                return .none

            case .doneTapped:
                // Live: Today reads the same key, so saving rearranges it
                // without anything being sent to it.
                state.$layoutRaw.withLock { [raw = state.layout.raw] in $0 = raw }
                if let homeID = state.homeID {
                    state.$dockSettings.withLock { [dock = state.dock] in $0[homeID] = dock }
                }
                return .send(.delegate(.finished))

            case .cancelTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
