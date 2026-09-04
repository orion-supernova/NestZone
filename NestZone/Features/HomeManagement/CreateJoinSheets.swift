import ComposableArchitecture
import SwiftUI

/// The two sheets share a shape: one field, one button, an inline error that
/// shakes, and a success checkmark before dismissal.
private struct FormSheet<Field: View>: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let symbol: String
    let submitTitle: LocalizedStringResource
    let successTitle: LocalizedStringResource
    let isSubmitting: Bool
    let didSucceed: Bool
    let canSubmit: Bool
    let shakeCount: Int
    let onSubmit: () -> Void
    @ViewBuilder let field: Field

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)

                if didSucceed {
                    success
                } else {
                    form
                }
            }
            .animation(Motion.spring, value: didSucceed)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: {
                        Text(L10n.commonCancel)
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationBackground(.regularMaterial)
    }

    private var form: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(theme.accent)
                    .frame(width: 64, height: 64)
                    .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .appear(0)

            field
                .shake(on: shakeCount)
                .appear(1)

            PrimaryButton(submitTitle, isLoading: isSubmitting, action: onSubmit)
                .disabled(!canSubmit)
                .appear(2)

            Spacer(minLength: 0)
        }
        .padding(Metrics.screenPadding)
    }

    private var success: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.success)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text(successTitle).font(.headline)
        }
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}

struct CreateHomeSheet: View {
    @Bindable var store: StoreOf<CreateHomeFeature>

    var body: some View {
        FormSheet(
            title: L10n.homeSetupCreateHomeTitle,
            subtitle: L10n.createHomeSubtitle,
            symbol: "house.and.flag",
            submitTitle: L10n.createHomeButton,
            successTitle: L10n.createHomeSuccessMessage,
            isSubmitting: store.isSubmitting,
            didSucceed: store.didSucceed,
            canSubmit: store.canSubmit,
            shakeCount: store.shakeCount,
            onSubmit: { store.send(.submitTapped) }
        ) {
            GlassTextField(
                L10n.createHomeNameLabel,
                text: $store.name,
                symbol: "house",
                error: store.inlineError.map { LocalizedStringResource(stringLiteral: $0) }
            )
            .textInputAutocapitalization(.words)
            .submitLabel(.go)
            .onSubmit { store.send(.submitTapped) }
        }
    }
}

struct JoinHomeSheet: View {
    @Bindable var store: StoreOf<JoinHomeFeature>

    var body: some View {
        FormSheet(
            title: L10n.homeSetupJoinHomeTitle,
            subtitle: L10n.homeSetupJoinHomeSubtitle,
            symbol: "person.2.badge.key",
            submitTitle: L10n.joinHomeButton,
            successTitle: L10n.joinHomeSuccessMessage,
            isSubmitting: store.isSubmitting,
            didSucceed: store.didSucceed,
            canSubmit: store.canSubmit,
            shakeCount: store.shakeCount,
            onSubmit: { store.send(.submitTapped) }
        ) {
            GlassTextField(
                L10n.joinHomeInviteCodeLabel,
                text: $store.code,
                symbol: "key",
                error: store.inlineError.map { LocalizedStringResource(stringLiteral: $0) }
            )
            // Invite codes are case-insensitive on the server and always
            // uppercase in the UI, so autocorrect only gets in the way.
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit { store.send(.submitTapped) }
        }
    }
}
