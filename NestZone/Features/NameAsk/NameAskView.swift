import ComposableArchitecture
import SwiftUI

/// Shown once, before the house, to an account that has no name.
struct NameAskView: View {
    @Bindable var store: StoreOf<NameAskFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Backdrop(tint: theme.accent)

            VStack(spacing: Metrics.sectionSpacing) {
                Spacer(minLength: 0)

                Text(L10n.nameAskTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                GlassTextField(
                    L10n.nameAskField,
                    text: $store.name,
                    symbol: "person",
                    error: store.inlineError.map { LocalizedStringResource(stringLiteral: $0) },
                    contentType: .name,
                    autofocus: true
                )
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .onSubmit { store.send(.continueTapped) }

                PrimaryButton(L10n.nameAskContinue) {
                    store.send(.continueTapped)
                }
                .disabled(!store.canContinue)

                Button { store.send(.laterTapped) } label: {
                    Text(L10n.nameAskLater)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondaryText)
                        .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .padding(Metrics.screenPadding)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.continues)
    }
}
