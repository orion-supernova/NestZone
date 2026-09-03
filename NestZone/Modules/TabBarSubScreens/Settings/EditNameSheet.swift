//
//  EditNameSheet.swift
//  NestZone
//
//  Lets the user set their display name.
//
//  Needed because Sign in with Apple hands over a name only on the FIRST
//  authorization for an app. Every subsequent sign-in omits it, so anyone who
//  had already authorized NestZone arrives with no name at all and previously
//  had no way to provide one.
//

import SwiftUI

struct EditNameSheet: View {
    @EnvironmentObject private var authManager: ConvexAuthManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme

    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var errorShakeCount = 0
    @FocusState private var isFieldFocused: Bool

    private var theme: ThemeColors { selectedTheme.colors(for: colorScheme) }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmed.isEmpty && trimmed != (authManager.currentUser?.name ?? "") && !isSaving
    }

    init(currentName: String?) {
        _name = State(initialValue: currentName ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField(LocalizationManager.profileNamePlaceholder, text: $name)
                    .font(.system(size: 17, weight: .medium))
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFieldFocused)
                    .onSubmit { if canSave { save() } }
                    .padding(16)
                    .softCard(
                        background: theme.cardBackground,
                        border: theme.textSecondary.opacity(0.15)
                    )
                    .shake(trigger: errorShakeCount)
                    .appear(step: 0)

                Text(LocalizationManager.profileNameFootnote)
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appear(step: 1)

                Spacer()
            }
            .padding(20)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(LocalizationManager.profileNameTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizationManager.commonCancel) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(LocalizationManager.commonSave) { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .alert(
                LocalizationManager.commonErrorTitle,
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(LocalizationManager.commonOkButton) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear { isFieldFocused = true }
    }

    private func save() {
        // Re-entrancy guard: `isSaving` also disables the control, but a second
        // tap in the same frame would otherwise queue a second Task before the
        // flag is published.
        guard !isSaving else { return }
        isSaving = true
        Task {
            do {
                try await authManager.updateDisplayName(trimmed)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                errorShakeCount += 1
            }
            isSaving = false
        }
    }
}
