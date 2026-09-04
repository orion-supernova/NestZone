import ComposableArchitecture
import SwiftUI

public struct ShoppingView: View {
    @Bindable var store: StoreOf<ShoppingFeature>

    @Environment(\.theme) private var theme
    @FocusState private var isComposerFocused: Bool
    @Namespace private var glass

    public init(store: StoreOf<ShoppingFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.sectionSpacing) {
                if store.isLoading {
                    SkeletonList(rows: 5, height: 52)
                        .padding(.horizontal, Metrics.screenPadding)
                } else if store.items.isEmpty {
                    EmptyStateView(
                        title: L10n.shoppingEmptyTitle,
                        message: L10n.shoppingEmptyMessage,
                        symbol: "cart"
                    )
                    .padding(.top, 48)
                } else {
                    pendingSections
                    purchasedSection
                }
            }
            .padding(.bottom, 120)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(Text(L10n.managementModuleShoppingTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.purchased.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        store.send(.clearPurchasedTapped)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(Text(L10n.shoppingClearPurchased))
                }
            }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .animation(Motion.spring, value: store.items)
    }

    private var pendingSections: some View {
        ForEach(store.pendingByCategory, id: \.category) { group in
            VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                SectionHeader(group.category.title, symbol: group.category.symbol)
                    .padding(.horizontal, Metrics.screenPadding)

                GlassGroup {
                    VStack(spacing: 8) {
                        ForEach(group.items) { item in
                            ShoppingRow(
                                item: item,
                                onToggle: { store.send(.togglePurchased(item.id)) },
                                onDelete: { store.send(.deleteTapped(item.id)) }
                            )
                            .glassEffectID(item.id.rawValue, in: glass)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }

    @ViewBuilder
    private var purchasedSection: some View {
        if !store.purchased.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                SectionHeader(L10n.shoppingPurchasedSection, symbol: "checkmark.circle")
                    .padding(.horizontal, Metrics.screenPadding)

                GlassGroup {
                    VStack(spacing: 8) {
                        ForEach(store.purchased) { item in
                            ShoppingRow(
                                item: item,
                                onToggle: { store.send(.togglePurchased(item.id)) },
                                onDelete: { store.send(.deleteTapped(item.id)) }
                            )
                            .glassEffectID(item.id.rawValue, in: glass)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }

    /// Pinned to the bottom so adding several things in a row never requires
    /// scrolling back up or reopening a sheet.
    private var composer: some View {
        HStack(spacing: 10) {
            Menu {
                Picker(selection: $store.draftCategory) {
                    ForEach(ShoppingItem.Category.allCases, id: \.self) { category in
                        Label { Text(category.title) } icon: {
                            Image(systemName: category.symbol)
                        }
                        .tag(category)
                    }
                } label: { EmptyView() }
            } label: {
                Image(systemName: store.draftCategory.symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text(store.draftCategory.title))

            TextField(text: $store.draft) {
                Text(L10n.shoppingAddPlaceholder)
            }
            .focused($isComposerFocused)
            .submitLabel(.done)
            .onSubmit { store.send(.addTapped) }

            Button { store.send(.addTapped) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.pressable)
            .disabled(!store.canAdd)
            .opacity(store.canAdd ? 1 : 0.4)
            .animation(Motion.fade, value: store.canAdd)
            .accessibilityLabel(Text(L10n.commonAdd))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 8)
    }
}

private struct ShoppingRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPurchased ? Palette.success : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 32)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.success, trigger: item.isPurchased) { _, bought in bought }

            Text(item.name)
                .font(.subheadline)
                .strikethrough(item.isPurchased, color: .secondary)
                .foregroundStyle(item.isPurchased ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let quantity = item.quantity, quantity > 1 {
                Text(quantity, format: .number.precision(.fractionLength(0...1)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .animation(Motion.spring, value: item.isPurchased)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item.isPurchased ? [.isButton, .isSelected] : .isButton)
    }
}
