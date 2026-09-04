import SwiftUI

/// The app's motion vocabulary.
///
/// One rule holds the whole system together: motion explains a change, it never
/// decorates. Every curve here settles in under a third of a second, so nothing
/// stands between a tap and the next thing the user wants to do.
public enum Motion {
    /// Default for anything that moves position or size.
    public static let spring = SwiftUI.Animation.spring(response: 0.34, dampingFraction: 0.82)
    /// For elements arriving on screen — slightly looser, reads as settling.
    public static let arrive = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.85)
    /// Acknowledging a press. Fast enough to feel like the finger caused it.
    public static let press = SwiftUI.Animation.spring(response: 0.18, dampingFraction: 0.7)
    /// Fades and cross-dissolves.
    public static let fade = SwiftUI.Animation.easeOut(duration: 0.2)
    /// Reserved for the one or two genuinely playful moments — a poll match, a
    /// completed streak. Overshoots on purpose.
    public static let celebrate = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.55)

    /// Delay for the nth element in a staggered sequence. Capped so a long list
    /// never leaves the last row waiting.
    public static func stagger(_ index: Int, step: Double = 0.045, cap: Double = 0.3) -> Double {
        min(Double(index) * step, cap)
    }
}

// MARK: - Entrance

private struct AppearModifier: ViewModifier {
    let index: Int
    let distance: CGFloat
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : distance)
            .onAppear {
                withAnimation(Motion.arrive.delay(Motion.stagger(index))) { shown = true }
            }
    }
}

extension View {
    /// Fades and lifts a view into place. `index` is its position in the
    /// sequence, so a stack arrives in order rather than all at once.
    ///
    /// Replaces the per-screen `animateFields` state that used to hang an
    /// `.opacity().offset().animation(delay:)` chain off every element.
    public func appear(_ index: Int = 0, distance: CGFloat = 10) -> some View {
        modifier(AppearModifier(index: index, distance: distance))
    }
}

// MARK: - Press feedback

/// Scales a control slightly while held, with a light haptic on the way down.
public struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    public init(scale: CGFloat = 0.97) { self.scale = scale }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in
                pressed   // fire on press, not on release
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    public static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Rejection

private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Three decaying passes, driven by the animation clock rather than by a
        // chain of dispatched blocks — so it stays in sync when the view is
        // re-rendered mid-shake, and cancels cleanly.
        let damping = 1 - progress
        let offset = sin(progress * .pi * 6) * 7 * damping
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

private struct ShakeModifier: ViewModifier {
    let trigger: Int
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(progress: progress))
            .onChange(of: trigger) { _, _ in
                progress = 0
                withAnimation(.easeOut(duration: 0.4)) { progress = 1 }
            }
    }
}

extension View {
    /// Shakes whenever `trigger` changes — for input the app is refusing.
    public func shake(on trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

// MARK: - Numbers

/// A number that rolls to its new value instead of snapping.
///
/// Used on the Home tab's stat tiles, where a count changing is the whole point
/// of the screen and an instant swap is easy to miss.
public struct AnimatedNumber: View, Animatable {
    private var value: Double
    private let format: IntegerFormatStyle<Int>

    public init(_ value: Int, format: IntegerFormatStyle<Int> = .number) {
        self.value = Double(value)
        self.format = format
    }

    // `nonisolated` because SwiftUI drives animatable data off the render
    // thread, while `View` conformance is main-actor isolated.
    public nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    public var body: some View {
        Text(Int(value.rounded()), format: format)
            .contentTransition(.numericText(value: value))
            .monospacedDigit()
    }
}

// MARK: - Attention

private struct PulseModifier: ViewModifier {
    let active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? 1.04 : 1)
            .animation(
                active ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default,
                value: on
            )
            .onChange(of: active, initial: true) { _, isActive in on = isActive }
    }
}

extension View {
    /// A slow breathing scale, for a single element that is genuinely waiting on
    /// the user. Never more than one on screen.
    public func pulse(_ active: Bool = true) -> some View {
        modifier(PulseModifier(active: active))
    }
}
