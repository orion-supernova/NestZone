import SwiftUI

/// A short-lived bar offering to put back what was just removed.
///
/// The app has no trash and no restore endpoint on purpose: a destructive
/// action here is held for a few seconds on the device and only then sent, so
/// undo cancels the write rather than reversing it. That keeps recovery at the
/// one moment a person is actually looking at the row they lost.
public struct UndoToast: View {
    private let message: LocalizedStringResource
    private let action: () -> Void

    public init(_ message: LocalizedStringResource, action: @escaping () -> Void) {
        self.message = message
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button(action: action) {
                Text(L10n.commonUndo)
                    .font(.subheadline.weight(.semibold))
                    // The bar is narrow, so the label needs the room around it
                    // to reach a comfortable target.
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pressable)
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(L10n.commonUndo), action)
    }
}
