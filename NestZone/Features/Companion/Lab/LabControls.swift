#if DEBUG
import ComposableArchitecture
import SwiftUI

// The Lab is a developer's tool compiled into Debug builds only, so its
// labels are plain English (`Text(verbatim:)`) and are not in the String
// Catalog the shipped app carries.

extension StoreOf<CompanionFeature> {
    /// A change to the pretend house.
    func pretend(_ command: PretendCommand, animation: Animation? = nil) {
        send(.lab(.command(command)), animation: animation)
    }

    func lab(_ action: LabAction, animation: Animation? = nil) {
        send(.lab(action), animation: animation)
    }

    /// A control whose value is something the store holds and whose change is
    /// a Lab action.
    func labBinding<Value>(_ value: KeyPath<CompanionFeature.State, Value>, _ action: @escaping (Value) -> LabAction) -> Binding<Value> {
        Binding(get: { self.state[keyPath: value] }, set: { self.send(.lab(action($0))) })
    }
}

/// A row that does one thing.
struct LabButton: View {
    let title: String
    var symbol: String?
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            if let symbol {
                Label { Text(verbatim: title) } icon: { Image(systemName: symbol) }
            } else {
                Text(verbatim: title)
            }
        }
    }
}

/// A slider that follows the finger. While it is held it shows its own value
/// and reports every change; once let go it shows what the house says again,
/// so what a server did with the change is never fought over mid-drag.
struct LabSlider: View {
    let title: String
    /// What the house says it is.
    let value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let describe: (Double) -> String
    let change: (Double) -> Void

    @State private var held: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                Text(verbatim: describe(held ?? value)).monospacedDigit().foregroundStyle(.secondary)
            } label: {
                Text(verbatim: title)
            }
            slider
        }
    }

    @ViewBuilder
    private var slider: some View {
        let binding = Binding(get: { held ?? value }, set: { held = $0; change($0) })
        if let step {
            Slider(value: binding, in: range, step: step) { editing in if !editing { held = nil } }
        } else {
            Slider(value: binding, in: range) { editing in if !editing { held = nil } }
        }
    }
}

/// A section's quiet explanation.
struct LabNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
#endif
