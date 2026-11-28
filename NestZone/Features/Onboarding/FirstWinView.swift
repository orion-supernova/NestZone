import ComposableArchitecture
import SwiftUI

/// "Let's add your first shopping item": a field and three things most houses
/// run out of, then "Your house is ready". A sheet that is small on purpose:
/// the app is right behind it.
struct FirstWinView: View {
    @Bindable var store: StoreOf<FirstWinFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let suggestions: [LocalizedStringResource] = [
        L10n.firstWinMilk, L10n.firstWinBread, L10n.firstWinToiletPaper,
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)
                if let added = store.added {
                    ready(added)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                } else {
                    asking
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? Motion.fade : Motion.spring, value: store.added)
            .overlay { ConfettiBurst(trigger: store.celebrations) }
            .sensoryFeedback(.success, trigger: store.celebrations)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if store.added == nil {
                        Button { store.send(.laterTapped) } label: { Text(L10n.firstWinLater) }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(430), .large])
        .presentationBackground(.regularMaterial)
    }

    // MARK: Asking

    private var asking: some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                VStack(spacing: 10) {
                    Image(systemName: "cart.fill")
                        .font(.title)
                        .foregroundStyle(.accentText)
                        .frame(width: 64, height: 64)
                        .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)
                        .accessibilityHidden(true)
                    Text(L10n.firstWinTitle)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.firstWinText)
                        .font(.subheadline)
                        .foregroundStyle(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .appear(0)

                GlassTextField(
                    L10n.firstWinField,
                    text: $store.text,
                    symbol: "cart",
                    error: store.inlineError.map { LocalizedStringResource(stringLiteral: $0) }
                )
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .onSubmit { store.send(.addTapped) }
                .appear(1)

                FlowLayout(spacing: 8) {
                    ForEach(Self.suggestions.indices, id: \.self) { index in
                        let name = String(localized: Self.suggestions[index])
                        Chip(name) { store.send(.suggestionTapped(name)) }
                    }
                }
                .frame(maxWidth: .infinity)
                .appear(2)

                PrimaryButton(L10n.firstWinAdd) { store.send(.addTapped) }
                    .disabled(!store.canAdd)
                    .accessibilityIdentifier("FirstWinAdd")
                    .appear(3)
            }
            .padding(Metrics.screenPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Ready

    private func ready(_ item: String) -> some View {
        VStack(spacing: Metrics.sectionSpacing) {
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.success)
                    .bounces()
                    .accessibilityHidden(true)
                Text(L10n.firstWinReadyTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.firstWinReadyText(item))
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                PrimaryButton(L10n.firstWinOpenList, symbol: "cart") { store.send(.openListTapped) }
                SecondaryButton(L10n.commonDone) { store.send(.doneTapped) }
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.screenPadding)
    }
}
