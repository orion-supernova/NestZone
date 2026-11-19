import SwiftUI

/// The house's jar, drawn as a glass jar with what is in it piled at the
/// bottom. Decorative: the numbers beside it are what VoiceOver reads.
///
/// The level follows the balance on a log curve (`JarFill.level`). When the
/// balance goes up the new pieces drop in from the neck and settle, with no
/// bounce — money doesn't — and the pile rises with `Motion.dataDraw`; when it
/// goes down the level lowers quietly. With Reduce Motion it just shows the new
/// state. Nothing runs while it is at rest: the drawing is one `Canvas`,
/// redrawn only while an animation is moving its single `clock`.
struct HouseJar: View {
    let leaves: Int
    let sparkles: Int
    var height: CGFloat = 96
    /// Whether a change of balance is played; off for a jar that only shows a
    /// figure, like "the jar after".
    var animates = true
    /// Seconds to wait before playing a rise, for the coins still in the air.
    var landingDelay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var from: JarFill
    @State private var to: JarFill
    /// Counts the changes; the clock runs from `epoch - 1` to `epoch`.
    @State private var epoch = 0
    @State private var clock = 0.0

    init(leaves: Int, sparkles: Int, height: CGFloat = 96, animates: Bool = true, landingDelay: Double = 0) {
        self.leaves = leaves
        self.sparkles = sparkles
        self.height = height
        self.animates = animates
        self.landingDelay = landingDelay
        let fill = JarFill(leaves: leaves, sparkles: sparkles)
        _from = State(initialValue: fill)
        _to = State(initialValue: fill)
    }

    var body: some View {
        JarCanvas(from: from, to: to, epoch: epoch, clock: clock)
            .equatable()
            .frame(width: height * HouseJarArt.aspect, height: height)
            .accessibilityHidden(true)
            .onChange(of: JarFill(leaves: leaves, sparkles: sparkles)) { _, new in
                from = to
                to = new
                epoch += 1
                let target = Double(epoch)
                guard animates, !reduceMotion else {
                    clock = target
                    return
                }
                let rising = new.level > from.level
                let animation = rising ? Motion.dataDraw.delay(landingDelay) : Motion.settle
                withAnimation(animation) { clock = target }
            }
    }
}

/// The jar's drawing, animated by its clock alone.
private struct JarCanvas: View, Animatable, Equatable {
    let from: JarFill
    let to: JarFill
    let epoch: Int
    var clock: Double

    nonisolated var animatableData: Double {
        get { clock }
        set { clock = newValue }
    }

    var body: some View {
        let progress = min(max(clock - Double(epoch - 1), 0), 1)
        Canvas { context, size in
            var context = context
            HouseJarArt.draw(&context, size: size, from: from, to: to, progress: progress)
        }
    }
}
