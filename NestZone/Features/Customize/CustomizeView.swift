import ComposableArchitecture
import SwiftUI

/// The Customize sheet: Today's sections, each Automatic, Always or Off.
///
/// A plain grouped list on purpose. It is a settings screen, it is opened
/// rarely, and it needs reordering — which `List` gives for free and a glass
/// stack does not.
public struct CustomizeView: View {
    @Bindable var store: StoreOf<CustomizeFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Automatic, Always or Off picked from a row's menu — counted here so the
    /// tick answers the pick and nothing else (Reset moves them all, silently).
    @State private var picks = 0

    public init(store: StoreOf<CustomizeFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            if store.homeID != nil { dockSection }
            todaySection
            Section {
                Button(role: .destructive) { store.send(.resetTapped) } label: {
                    Text(L10n.customizeReset)
                }
            }
        }
        .settingsRows()
        // Always reorderable: the handles are the point of the list, and an
        // Edit button to reveal them is one more thing to find.
        .environment(\.editMode, .constant(.active))
        .sensoryFeedback(.selection, trigger: picks)
        .navigationTitle(Text(L10n.customizeTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { store.send(.cancelTapped) } label: { Text(L10n.commonCancel) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.doneTapped) } label: { Text(L10n.commonDone) }
                    .accessibilityIdentifier("CustomizeDone")
            }
        }
    }

    /// The dock above the tab bar: what it shows, per house on this phone.
    private var dockSection: some View {
        Section {
            Picker(selection: Binding(
                get: { store.dock.mode },
                set: {
                    picks += 1
                    store.send(.dockModePicked($0), animation: Motion.spring)
                }
            )) {
                ForEach(DockMode.allCases) { mode in
                    Label { Text(mode.title) } icon: { Image(systemName: mode.symbol) }.tag(mode)
                }
            } label: {
                Label { Text(L10n.dockSettingLabel) } icon: { Image(systemName: "dock.rectangle") }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("Customize.dockMode")

            if store.dock.mode == .always {
                Picker(selection: Binding(
                    get: { store.dock.thing },
                    set: {
                        picks += 1
                        store.send(.dockThingPicked($0), animation: Motion.spring)
                    }
                )) {
                    ForEach(DockThing.allCases) { thing in
                        Label {
                            Text(thing.title)
                        } icon: {
                            Image(systemName: thing.needsPlus && !store.pro.isPro ? PlusStyle.lockedSymbol : thing.symbol)
                        }
                        .tag(thing)
                    }
                } label: {
                    Label { Text(L10n.dockThingLabel) } icon: { Image(systemName: store.dock.thing.symbol) }
                }
                .pickerStyle(.menu)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
                .accessibilityIdentifier("Customize.dockThing")
            }
        } header: {
            Text(L10n.dockSettingTitle)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.dock.mode.meaning)
                if store.dock.mode == .always, store.dock.thing.needsPlus, !store.pro.isPro {
                    Text(L10n.dockNeedsPlus)
                }
                Text(L10n.dockSettingFooter)
            }
        }
    }

    private var todaySection: some View {
        Section {
            ForEach(store.layout.order) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Picker(selection: Binding(
                        get: { store.layout.visibility(of: section) },
                        set: {
                            picks += 1
                            store.send(.visibilityPicked(section, $0), animation: Motion.spring)
                        }
                    )) {
                        ForEach(SectionVisibility.allCases) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    } label: {
                        Label { Text(section.title) } icon: { Image(systemName: section.symbol) }
                    }
                    .pickerStyle(.menu)

                    // Said under the row it belongs to, and only while it is
                    // the setting in force: "Automatic" means something
                    // different for every section.
                    if store.layout.visibility(of: section) == .automatic {
                        Text(section.automaticMeaning)
                            .font(.footnote)
                            .foregroundStyle(.secondaryText)
                            // Comes and goes with the setting, blurring in
                            // and out rather than popping.
                            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
                    }
                }
                .accessibilityIdentifier("Customize.\(section.rawValue)")
            }
            .onMove { store.send(.sectionsMoved(from: $0, to: $1)) }
        } header: {
            Text(L10n.customizeTodayTitle)
        } footer: {
            Text(L10n.customizeTodayFooter)
        }
    }
}
