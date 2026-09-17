import SwiftUI

/// Where a profile photo should come from.
///
/// A sheet rather than a confirmation dialog, which is what this was. A dialog
/// is right for confirming one dangerous thing; this is a small menu of four
/// unlike actions — look, capture, choose, remove — and an action sheet renders
/// them as an undifferentiated stack of blue words that reads as a list of
/// warnings. Rows with their own icons say what each one does before it is read.
struct AvatarSourceSheet: View {
    let hasPhoto: Bool
    /// Records what was picked. It is deliberately *not* what acts on it —
    /// see the caller: every choice presents something, and presenting it from
    /// here would present it on top of this sheet.
    let choose: (AvatarSource) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    /// The camera row is offered only when there is a camera. On the simulator,
    /// and on a device whose camera is unavailable, presenting one shows a black
    /// rectangle with no way back.
    private var options: [AvatarSource] {
        var options: [AvatarSource] = []
        if hasPhoto { options.append(.view) }
        if CameraPicker.isAvailable { options.append(.camera) }
        options.append(.library)
        if hasPhoto { options.append(.remove) }
        return options
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.stackSpacing) {
                    ForEach(options) { option in
                        AvatarSourceRow(option: option, tint: theme.accent) {
                            choose(option)
                            dismiss()
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.avatarDialogTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: {
                        Text(L10n.commonCancel)
                    }
                }
            }
        }
        // Tall enough for four rows and short enough that the screen behind it
        // is still visible, which is what keeps it feeling like a menu over the
        // profile rather than a place you have navigated to.
        .presentationDetents([.height(Double(options.count) * 72 + 130)])
        .presentationDragIndicator(.visible)
    }
}
