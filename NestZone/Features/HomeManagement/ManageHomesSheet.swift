import ComposableArchitecture
import SwiftUI

/// The one place a signed-in user can act on the homes they belong to: switch,
/// create, join, leave, delete.
///
/// A `Form` rather than the gate's glass cards — this is reached from Settings
/// and belongs to it visually, and a list row is what gives us swipe-to-leave
/// and the destructive footer for free.
struct ManageHomesSheet: View {
    @Bindable var store: StoreOf<ManageHomesFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                homesSection
                addSection
                leaveSection
            }
            .scrollContentBackground(.hidden)
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(store.homes.count > 1
                ? L10n.homeSelectionSwitchTitle
                : L10n.manageHomesButton))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.doneTapped) } label: {
                        Text(L10n.commonDoneButton)
                    }
                }
            }
            // A row that is already on its way out must not be tapped again.
            .disabled(store.leavingID != nil)
        }
        .sheet(item: $store.scope(state: \.destination?.create, action: \.destination.create)) {
            CreateHomeSheet(store: $0)
        }
        .sheet(item: $store.scope(state: \.destination?.join, action: \.destination.join)) {
            JoinHomeSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - The homes you belong to

    private var homesSection: some View {
        Section {
            ForEach(store.homes) { home in
                Button { store.send(.homeTapped(home.id)) } label: {
                    row(for: home)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.send(.leaveTapped(home.id))
                    } label: {
                        Label {
                            Text(destructiveTitle(for: home))
                        } icon: {
                            Image(systemName: destructiveSymbol(for: home))
                        }
                    }
                }
            }
        } header: {
            Text(L10n.homeSelectionTitle)
        } footer: {
            if store.homes.count > 1 {
                Text(L10n.homeSelectionSwitchSubtitle)
            }
        }
    }

    private func row(for home: Home) -> some View {
        LabeledContent {
            if home.id == store.currentHomeID {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(home.name)
                        .foregroundStyle(.primary)
                    Text(L10n.settingsMembersCount(home.members.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "house.fill")
            }
        }
    }

    // MARK: - Another home

    private var addSection: some View {
        Section {
            Button { store.send(.createTapped) } label: {
                Label { Text(L10n.homeSetupCreateHomeTitle) } icon: {
                    Image(systemName: "house.and.flag")
                }
            }
            Button { store.send(.joinTapped) } label: {
                Label { Text(L10n.joinAnotherHomeButton) } icon: {
                    Image(systemName: "person.2.badge.key")
                }
            }
        }
    }

    // MARK: - Leaving the home that is open

    /// Repeated from the swipe action on purpose: a swipe is not a discoverable
    /// way to offer the only exit from a household, least of all to someone who
    /// belongs to exactly one and sees a single row.
    @ViewBuilder
    private var leaveSection: some View {
        if let home = store.currentHome {
            Section {
                Button(role: .destructive) {
                    store.send(.leaveTapped(home.id))
                } label: {
                    Label {
                        Text(destructiveTitle(for: home))
                    } icon: {
                        Image(systemName: destructiveSymbol(for: home))
                    }
                }
            } footer: {
                Text(isSoleMember(home)
                    ? L10n.homeDeleteConfirmMessage(home.name)
                    : L10n.homeLeaveConfirmMessage(home.name))
            }
        }
    }

    /// The last member out takes the home with them, so the wording changes.
    /// A method on the view rather than the store: dynamic member lookup
    /// reaches properties, not functions.
    private func isSoleMember(_ home: Home) -> Bool { home.members.count <= 1 }

    private func destructiveTitle(for home: Home) -> LocalizedStringResource {
        isSoleMember(home) ? L10n.homeDeleteConfirmAction : L10n.homeLeaveConfirmAction
    }

    private func destructiveSymbol(for home: Home) -> String {
        isSoleMember(home) ? "trash" : "rectangle.portrait.and.arrow.right"
    }
}
