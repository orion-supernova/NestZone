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
/// content below no longer needs a hand-tuned bottom inset.
struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab(value: MainFeature.Tab.home) {
                NavigationStack(
                    path: $store.scope(state: \.homePath, action: \.homePath)
                ) {
                    HomeView(store: store.scope(state: \.homeTab, action: \.home))
                } destination: { store in
                    switch store.case {
                    case let .tasks(store): TasksView(store: store)
                    case let .contributions(store): ContributionsView(store: store)
                    case let .movieNight(store): MovieNightView(store: store)
                    case let .recipeDetail(store): RecipeDetailView(store: store)
                    }
                }
            } label: {
                tabLabel(.home)
            }
            .accessibilityIdentifier("HomeTab")

            Tab(value: MainFeature.Tab.hub) {
                HubView(store: store.scope(state: \.hub, action: \.hub))
            } label: {
                tabLabel(.hub)
            }
            .accessibilityIdentifier("HubTab")

            Tab(value: MainFeature.Tab.notes) {
                NavigationStack {
                    NotesView(store: store.scope(state: \.notes, action: \.notes))
                }
            } label: {
                tabLabel(.notes)
            }
            .accessibilityIdentifier("NotesTab")

            // `MessagesView` brings its own `NavigationStack` — it pushes chat
            // threads onto a `StackState` of its own, so unlike Notes it must
            // not be wrapped in a second one.
            Tab(value: MainFeature.Tab.messages) {
                MessagesView(store: store.scope(state: \.messages, action: \.messages))
            } label: {
                tabLabel(.messages)
            }
            .accessibilityIdentifier("MessagesTab")

            Tab(value: MainFeature.Tab.settings) {
                NavigationStack {
                    SettingsView(store: store.scope(state: \.settings, action: \.settings))
                }
            } label: {
                tabLabel(.settings)
            }
            .accessibilityIdentifier("SettingsTab")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private func tabLabel(_ tab: MainFeature.Tab) -> some View {
        Label { Text(tab.title) } icon: { Image(systemName: tab.symbol) }
    }
}
