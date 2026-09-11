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

                GlassList {
                    ChoiceCard(
                        title: L10n.homeSetupCreateHomeTitle,
                        subtitle: L10n.homeSetupCreateHomeSubtitle,
                        symbol: "house.and.flag",
                        tint: theme.accent
                    ) { store.send(.createTapped) }
                    .appearInPlace(1)

                    ChoiceCard(
                        title: L10n.homeSetupJoinHomeTitle,
                        subtitle: L10n.homeSetupJoinHomeSubtitle,
                        symbol: "person.2.badge.key",
                        tint: theme.support
                    ) { store.send(.joinTapped) }
                    .appearInPlace(2)
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

                GlassList {
                    ForEach(Array(store.homes.enumerated()), id: \.element.id) { index, home in
                        HomeRow(
                            home: home,
                            onSelect: { store.send(.homeSelected(home.id)) },
                            onRemove: { store.send(.leaveTapped(home.id)) }
                        )
                        .appearInPlace(index + 1)
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
                    .foregroundStyle(Palette.accessory)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
    }
}

/// Two controls side by side rather than one: a `Button` inside another
/// `Button`'s label never receives taps, so the menu that leaves or deletes the
/// home has to sit next to the card's action, not inside it.
private struct HomeRow: View {
    let home: Home
    let onSelect: () -> Void
    let onRemove: () -> Void

    /// The last member out takes the home with them, so the menu says so.
    private var isSoleMember: Bool { home.members.count <= 1 }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)

            Menu {
                Button(role: .destructive, action: onRemove) {
                    Label {
                        Text(isSoleMember
                            ? L10n.homeDeleteConfirmAction
                            : L10n.homeLeaveConfirmAction)
                    } icon: {
                        Image(systemName: isSoleMember
                            ? "trash"
                            : "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }
        }
        .padding(Metrics.cardPadding)
        .glassCard(interactive: true)
    }
}
