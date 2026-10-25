import ComposableArchitecture
import SwiftUI

extension View {
    /// The Lab's badge over a card (Debug builds): the way into the Lab, and
    /// the standing reminder of which house is on screen. Nothing in a
    /// Release build.
    @ViewBuilder
    func labBadge(_ store: StoreOf<CompanionFeature>) -> some View {
        #if DEBUG
        overlay(alignment: .topTrailing) {
            LabChip(store: store).padding(6)
        }
        #else
        self
        #endif
    }
}

#if DEBUG
/// The Lab's constants: colours are built once, never in a `body`.
enum LabInk {
    /// The tint of everything that says "this is the pretend house".
    static let pretend = Palette.warning.opacity(0.6)
}

/// A button on the card, always there in a Debug build. "Lab" on the real
/// house (with how many things it pretends, when any), and "Pretend house" in
/// orange when the card is not the real one, so the owner can never take one
/// for the other.
struct LabChip: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        let pretend = store.isPretend
        let overrides = store.labLook.isActive
        Button { store.send(.labTapped) } label: {
            Label {
                Text(verbatim: pretend ? "Pretend house" : overrides ? "Lab · pretending" : "Lab")
                    .fixedSize()
            } icon: {
                Image(systemName: pretend ? "theatermasks.fill" : "flask.fill")
            }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .glassControl(tinted: pretend ? LabInk.pretend : nil)
            .frame(minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: pretend ? "Lab, pretend house is on" : "Lab"))
        .accessibilityIdentifier("LabChip")
    }
}
#endif
