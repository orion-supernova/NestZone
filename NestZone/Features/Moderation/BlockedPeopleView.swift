import ComposableArchitecture
import SwiftUI

/// Settings → Privacy → Blocked people.
struct BlockedPeopleView: View {
    @Bindable var store: StoreOf<BlockedPeopleFeature>

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var unblocks = 0

    var body: some View {
        NavigationStack {
            Group {
                if store.people.isEmpty {
                    EmptyStateView(
                        title: L10n.blockedPeopleEmptyTitle,
                        message: L10n.blockedPeopleEmptyMessage,
                        symbol: "hand.raised"
                    )
                } else {
                    Form {
                        Section {
                            ForEach(store.people) { person in
                                HStack(spacing: 12) {
                                    Avatar(
                                        initials: person.initials,
                                        seed: person.id.rawValue,
                                        size: 34,
                                        source: .photo(person.avatarURL),
                                        viewable: false
                                    )
                                    Text(person.displayName)
                                    Spacer(minLength: 0)
                                    Button {
                                        unblocks += 1
                                        store.send(.unblockTapped(person), animation: Motion.spring)
                                    } label: {
                                        Text(L10n.chatUnblock)
                                            .font(.subheadline.weight(.medium))
                                    }
                                    // The tap's own haptic is below.
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(Text(L10n.blockedPeopleUnblockAccessibility(person.displayName)))
                                }
                            }
                        } footer: {
                            Text(L10n.blockedPeopleFooter)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .settingsRows()
                }
            }
            .background(Backdrop(tint: theme.accent))
            .sensoryFeedback(.impact(weight: .light), trigger: unblocks)
            .navigationTitle(Text(L10n.blockedPeopleTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(L10n.commonDone) }
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }
}
