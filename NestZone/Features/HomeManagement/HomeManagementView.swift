import ComposableArchitecture
import SwiftUI

/// Shown whenever there is no home open: either the user has none yet, or they
/// belong to several and haven't picked one.
public struct HomeManagementView: View {
    @Bindable var store: StoreOf<HomeManagementFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<HomeManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    LoadingView()
                } else if store.homes.isEmpty {
                    onboarding
                } else {
                    picker
                }
            }
            .animation(Motion.spring, value: store.isLoading)
            .animation(Motion.spring, value: store.homes.count)
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(store.homes.isEmpty
                ? L10n.noHomesGetStartedTitle
                : L10n.homeSelectionTitle))
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.destination?.create, action: \.destination.create)) {
            CreateHomeSheet(store: $0)
        }
        .sheet(item: $store.scope(state: \.destination?.join, action: \.destination.join)) {
            JoinHomeSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - No homes yet

    private var onboarding: some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                Text(L10n.homeSetupSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .appear(0)

                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        ChoiceCard(
                            title: L10n.homeSetupCreateHomeTitle,
                            subtitle: L10n.homeSetupCreateHomeSubtitle,
                            symbol: "house.badge.plus",
                            tint: theme.accent
                        ) { store.send(.createTapped) }
                        .appear(1)

                        ChoiceCard(
                            title: L10n.homeSetupJoinHomeTitle,
                            subtitle: L10n.homeSetupJoinHomeSubtitle,
                            symbol: "person.2.badge.key",
                            tint: theme.support
                        ) { store.send(.joinTapped) }
                        .appear(2)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
            .padding(.vertical, Metrics.sectionSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Choosing between homes

    private var picker: some View {
        ScrollView {
            VStack(spacing: Metrics.stackSpacing) {
                Text(L10n.homeSelectionSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.screenPadding)
                    .appear(0)

                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        ForEach(Array(store.homes.enumerated()), id: \.element.id) { index, home in
                            HomeRow(home: home) { store.send(.homeSelected(home.id)) }
                                .appear(index + 1)
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)

                SecondaryButton(L10n.joinAnotherHomeButton, symbol: "person.2.badge.key") {
                    store.send(.joinTapped)
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 8)
                .appear(store.homes.count + 1)
            }
            .padding(.vertical, Metrics.stackSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// A large tappable option — "create a home" / "join a home".
private struct ChoiceCard: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
    }
}

private struct HomeRow: View {
    let home: Home
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "house.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(.tint.opacity(0.14), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(home.name).font(.headline)
                    Text(L10n.settingsMembersCount(home.members.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
    }
}
