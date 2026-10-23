import ComposableArchitecture
import SwiftUI

/// The root view. One `switch` over `state.screen` — the whole navigation story
/// of the app is visible in ten lines.
public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.screen {
            case .launching:
                LaunchView()

            case .signedOut:
                AuthView(store: store.scope(state: \.auth, action: \.auth))
                    .transition(.opacity)

            case .offline:
                // A stored session that could not be exchanged. Showing the
                // sign-in screen here would be a lie — and signing in again is
                // not the fix.
                OfflineView { store.send(.retryRestoreTapped) }
                    .transition(.opacity)

            case .choosingHome:
                HomeManagementView(store: store.scope(state: \.homeGate, action: \.homeGate))
                    .transition(.opacity)

            case .main:
                if let main = store.scope(state: \.main, action: \.main) {
                    MainView(store: main).transition(.opacity)
                }
            }
        }
        .animation(Motion.fade, value: store.screen)
        .appTheme(store.theme)
        // Drives dates, numbers and system controls. `L10n` is pointed at the
        // same locale in the reducer.
        .environment(\.locale, store.language.locale)
        // Re-identify on a language change so text already on screen is rebuilt
        // rather than left in the old language.
        .id(store.language)
        .task { await store.send(.task).finish() }
    }
}

/// Shown when a saved session exists but the server could not be reached.
struct OfflineView: View {
    let retry: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Backdrop(tint: theme.accent)
            VStack(spacing: Metrics.sectionSpacing) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)

                VStack(spacing: 8) {
                    Text(L10n.commonOfflineTitle)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(L10n.commonOfflineMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                PrimaryButton(L10n.commonRetry, symbol: "arrow.clockwise", action: retry)
                    .padding(.horizontal, Metrics.screenPadding)
            }
            .padding(Metrics.screenPadding)
        }
    }
}

/// Shown only while the cached session is being restored. Deliberately quiet —
/// it is on screen for a few hundred milliseconds.
struct LaunchView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Backdrop(tint: theme.accent)
            Image(systemName: "house.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 96, height: 96)
                .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)
                .pulse()
        }
        .accessibilityLabel(Text(L10n.commonLoading))
    }
}

/// The tab bar.
///
/// `Tab(value:)` and `tabBarMinimizeBehavior` are iOS 26: the bar collapses out
/// of the way as you scroll and expands again on the way back, which is why the
/// content below no longer needs a hand-tuned bottom inset. The dock rides on
/// it as the bar's accessory, so it shrinks and returns with it.
struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab(value: MainFeature.Tab.today) {
                RouteStackView(store: store.scope(state: \.today, action: \.today)) {
                    HomeView(store: store.scope(state: \.homeTab, action: \.home)) { compact in
                        if CompanionFlag.isEnabled {
                            CompanionCard(store: store.scope(state: \.companion, action: \.companion), compact: compact)
                        }
                    }
                    .sessionToolbar(store)
                }
            } label: {
                Label { Text(L10n.tabBarHome) } icon: { Image(systemName: "sun.max.fill") }
            }
            .accessibilityIdentifier("HomeTab")

            groupTab(.lists, store.scope(state: \.lists, action: \.lists))
            groupTab(.plans, store.scope(state: \.plans, action: \.plans))
            groupTab(.house, store.scope(state: \.house, action: \.house))

            Tab(value: MainFeature.Tab.messages) {
                MessagesStack(store: store.scope(state: \.messages, action: \.messages)) {
                    MessagesView(store: store.scope(state: \.messages, action: \.messages))
                        .sessionToolbar(store)
                }
            } label: {
                Label {
                    Text(L10n.tabBarMessages)
                } icon: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
            }
            .badge(store.now.unreadMessages)
            .accessibilityIdentifier("MessagesTab")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .dock(isEnabled: showsDock) {
            NowDock(store: store.scope(state: \.now, action: \.now))
        }
        // One panel and one Settings sheet for the whole tab bar, whichever
        // tab's button asked for them.
        .inboxPanel(store.scope(state: \.inbox, action: \.inbox))
        .sheet(isPresented: Binding(
            get: { store.isSettingsPresented },
            set: { if !$0 { store.send(.settingsDismissed) } }
        )) {
            NavigationStack {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button { store.send(.settingsDismissed) } label: {
                                Text(L10n.commonDone)
                            }
                        }
                    }
            }
            // Over Settings when it was opened from there, so closing it
            // lands back where the person was.
            .customizeSheet(store, when: true)
        }
        // Over the tabs otherwise: Today's own link.
        .customizeSheet(store, when: false)
        .nowSheets(store.scope(state: \.now, action: \.now))
        .sheet(item: $store.scope(state: \.capture, action: \.capture)) {
            CaptureView(store: $0)
        }
        // Above the dock and the tab bar, clear of both.
        .overlay(alignment: .bottom) {
            if let outcome = store.captured {
                CapturedToast(outcome: outcome) { store.send(.capturedOpenTapped) }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, 132)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: store.captured)
        // The badge, for as long as this home is open. One subscription, and
        // the only one the inbox holds while the panel is shut — the feeds
        // themselves are opened by the panel's own `.task` and torn down with
        // it.
        .task { await store.send(.inbox(.task)).finish() }
        // The dock is on every tab, so what it reads is subscribed to here,
        // for the life of the tab bar rather than of any one tab.
        .task { await store.send(.now(.task)).finish() }
    }

    /// Whether the dock is drawn. It steps aside where the screen has a field
    /// of its own at the bottom — the shopping list's composer, and a chat —
    /// so there are never two text fields stacked over the tab bar. (Only on
    /// iOS 26.1 and later; 26.0 cannot hide an accessory once it is shown.)
    private var showsDock: Bool {
        switch store.selectedTab {
        case .lists:
            !(store.lists.path.isEmpty && store.lists.selected == .shopping)
        case .messages:
            store.messages.path.isEmpty
        case .today, .plans, .house:
            true
        }
    }

    /// Lists, Plans or House: a segment switch over whichever of the group's
    /// modules is chosen.
    private func groupTab(
        _ group: TabGroup,
        _ stack: StoreOf<RouteStack>
    ) -> some TabContent<MainFeature.Tab> {
        Tab(value: MainFeature.Tab(group)) {
            RouteStackView(store: stack) {
                SegmentedRoot(group: group, store: stack)
                    .sessionToolbar(store)
            }
        } label: {
            Label { Text(group.title) } icon: { Image(systemName: group.symbol) }
        }
        .accessibilityIdentifier("\(group.rawValue.capitalized)Tab")
    }
}

/// The root of a grouped tab: the chosen module's screen, under a switch that
/// names all of them.
///
/// The switch sits in a bar of its own under the navigation bar rather than in
/// the bar's title slot: every module brings its own buttons, and three names,
/// two of those buttons, the avatar and the bell do not fit across a phone.
/// The module's own title is taken out, because the switch already says which
/// module this is.
private struct SegmentedRoot: View {
    let group: TabGroup
    @Bindable var store: StoreOf<RouteStack>

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            if let selected = store.selected,
               let segment = store.scope(state: \.segments[id: selected], action: \.segments[id: selected]) {
                RouteView(store: segment.scope(state: \.screen, action: \.screen))
                    .id(selected)
                    .transition(.opacity)
            }
        }
        .animation(Motion.fade, value: store.selected)
        #if DEBUG
        .task {
            // `-segmentCycle 1` walks the tab's segments on its own, to watch
            // a switch frame by frame.
            guard UserDefaults.standard.bool(forKey: "segmentCycle") else { return }
            for module in group.modules.dropFirst() + group.modules {
                try? await Task.sleep(for: .seconds(1.5))
                store.send(.segmentPicked(module))
            }
        }
        #endif
        .toolbar(removing: .title)
        // Inline for every module, including the one that asks for a large
        // title: a large title is drawn in the content, not the toolbar, so
        // removing the toolbar's title leaves it standing over the switch.
        .navigationBarTitleDisplayMode(.inline)
        // A module's search is a button in the bar, not a field above the
        // switch: the names of the modules are what the top of a tab is for.
        .searchToolbarBehavior(.minimize)
        .safeAreaBar(edge: .top) {
            HStack(spacing: 10) {
                SegmentSwitch(
                    modules: group.modules,
                    selected: store.selected ?? group.defaultModule
                ) { store.send(.segmentPicked($0)) }

                Spacer(minLength: 0)

                // House → At a glance: the one thing at the root of a group
                // that is not a module of its own.
                if group == .house {
                    Button { store.send(.statsTapped) } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(L10n.hubStatsTitle))
                    .accessibilityIdentifier("HouseStatsButton")
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, 4)
        }
    }
}

/// The modules of a tab, as names along the top of it.
///
/// Type rather than a segmented control, on purpose. Several modules already
/// open on a segmented control of their own — Tasks' To do, Done and All, the
/// calendar's Month, Week and Agenda — and two of them stacked read as one
/// control that had grown a second row. Names set like a title say "where you
/// are"; the control under them says "what you are looking at".
private struct SegmentSwitch: View {
    let modules: [HubModule]
    let selected: HubModule
    let pick: (HubModule) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var underline
    /// How far the underline is drawn out while it travels — 1 at rest, about
    /// 30pt over its 18 at full stretch.
    @State private var stretch: CGFloat = 1

    private static let underlineWidth: CGFloat = 18
    private static let stretchedWidth: CGFloat = 30

    var body: some View {
        HStack(spacing: 18) {
            ForEach(modules) { module in
                let isSelected = module == selected
                Button { pick(module) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                            // The name just chosen lands a touch small and
                            // springs up to size. Every name hears the change;
                            // only the chosen one moves.
                            .keyframeAnimator(
                                initialValue: CGFloat(1),
                                trigger: reduceMotion ? nil : selected
                            ) { name, scale in
                                name.scaleEffect(isSelected ? scale : 1, anchor: .bottomLeading)
                            } keyframes: { _ in
                                MoveKeyframe(0.96)
                                SpringKeyframe(1, duration: 0.32, spring: Spring(duration: 0.32, bounce: 0.4))
                            }
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(theme.accent)
                                    // Inside the matched frame, so it stretches
                                    // about its own centre as it slides rather
                                    // than being thrown wider off course.
                                    .scaleEffect(x: stretch, y: 1)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .frame(width: Self.underlineWidth, height: 3)
                    }
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("Segment.\(module.rawValue)")
            }
        }
        .animation(Motion.spring, value: selected)
        .onChange(of: selected) { _, _ in
            // Under Reduce Motion the underline only moves; it does not also
            // stretch.
            guard !reduceMotion else { return }
            // Drawn out as it leaves, gathered back in as it lands — the way
            // a drop of ink travels.
            withAnimation(.easeOut(duration: 0.14)) {
                stretch = Self.stretchedWidth / Self.underlineWidth
            } completion: {
                withAnimation(Motion.release) { stretch = 1 }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// A tab's navigation stack.
///
/// `root` draws the bottom of it: Today's summary, the conversation list, or a
/// grouped tab's segments.
struct RouteStackView<Root: View>: View {
    @Bindable var store: StoreOf<RouteStack>
    let root: () -> Root

    init(store: StoreOf<RouteStack>, @ViewBuilder root: @escaping () -> Root) {
        self.store = store
        self.root = root
    }

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            root()
        } destination: { store in
            RouteView(store: store)
        }
    }
}

extension View {
    /// Presents Customize from whichever layer is on top.
    ///
    /// Two attachment points for one piece of state — the tab bar, and the
    /// Settings sheet — because a sheet can only be presented by the view on
    /// top, and Settings may or may not be up when Customize is asked for.
    /// Each binding is live only while its layer is the top one.
    func customizeSheet(_ store: StoreOf<MainFeature>, when overSettings: Bool) -> some View {
        sheet(item: Binding(
            get: {
                store.isSettingsPresented == overSettings
                    ? store.scope(state: \.customize, action: \.customize.presented)
                    : nil
            },
            set: { if $0 == nil { store.send(.customize(.dismiss)) } }
        )) { customize in
            NavigationStack {
                CustomizeView(store: customize)
            }
        }
    }

    /// The dock, as the tab bar's accessory.
    ///
    /// `isEnabled` is iOS 26.1: on 26.0 an accessory, once given, is always
    /// drawn, so the dock simply stays — the app's floor is still 26.0 and a
    /// phone on it loses nothing but the step aside.
    @ViewBuilder
    func dock(isEnabled: Bool, @ViewBuilder content: () -> some View) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: isEnabled, content: content)
        } else {
            tabViewBottomAccessory(content: content)
        }
    }

    /// The sheets the dock and the dinner card open, over the whole tab bar.
    func nowSheets(_ store: StoreOf<NowFeature>) -> some View {
        modifier(NowSheets(store: store))
    }

    /// The avatar and the bell, on the root screen of every tab.
    ///
    /// Every tab rather than Today alone: the bell used to vanish the moment
    /// anybody left the Home tab, and Settings — now behind the avatar — has
    /// to be one tap away from wherever somebody is.
    func sessionToolbar(_ store: StoreOf<MainFeature>) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { store.send(.settingsButtonTapped) } label: {
                    if let user = store.user {
                        Avatar(user: user, size: 30, viewable: false)
                    } else {
                        Image(systemName: "person.crop.circle")
                    }
                }
                .accessibilityLabel(Text(L10n.settingsScreenTitle))
                .accessibilityIdentifier("SettingsButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                InboxBell(store: store.scope(state: \.inbox, action: \.inbox))
            }
        }
    }
}

/// The dinner decision and the occasion composer, presented over the tab bar
/// so the dock, Today and Meals all open the same sheet.
private struct NowSheets: ViewModifier {
    @Bindable var store: StoreOf<NowFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(state: \.dinner, action: \.dinner)) {
                DinnerSheet(store: $0)
            }
            .sheet(item: $store.scope(state: \.occasion, action: \.occasion)) {
                EventComposerSheet(store: $0)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
    }
}

/// "Added 3 to Shopping · Open" — what Add anything just did, and the way to
/// go and see it. Not an undo: everything it writes has a delete one tap away
/// in the module it went to, and that is where the person can check it.
private struct CapturedToast: View {
    let outcome: CaptureOutcome
    let open: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// One per line filed while the toast is up — the first as it arrives, and
    /// again if another lands before it has gone.
    @State private var filed = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: outcome.kind.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(outcome.kind.tint)
                // The module's glyph hops as the line lands in it. Still under
                // Reduce Motion, where the haptic says it alone.
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? 0 : filed)
            Text(outcome.message)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: open) {
                Text(L10n.commonOpen)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("CapturedOpen")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
        // Only ever shown for this person's own Add, so the haptic is theirs.
        .sensoryFeedback(.success, trigger: filed)
        .onAppear { filed += 1 }
        .onChange(of: outcome) { _, _ in filed += 1 }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(L10n.commonOpen), open)
    }
}
