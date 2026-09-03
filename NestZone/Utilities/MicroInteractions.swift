//
//  MicroInteractions.swift
//  NestZone
//
//  Small, reusable motion primitives.
//
//  The house style is restraint: short springs, small distances, no glows or
//  light bloom. Motion is there to explain what changed — an element arriving,
//  a control acknowledging a press, a field rejecting input — and never to
//  decorate. Every animation here is under a third of a second so nothing ever
//  stands between the user and the next tap.
//
//  These also replace a repeated boilerplate: screens used to carry an
//  `animateFields` @State and hang
//  `.opacity(...).offset(...).animation(.spring(...).delay(0.4), value:)` off
//  every single element. `.appear(step:)` owns that.
//

import SwiftUI

// MARK: - Press feedback

/// Scales a control down slightly while held, with a light haptic on press.
/// The spring is snappy on the way down and softer on release, which reads as
/// physical rather than sluggish.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(
                .spring(response: configuration.isPressed ? 0.18 : 0.32, dampingFraction: 0.7),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in
                pressed   // fire on press, not on release
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Staggered entrance

/// Fades and lifts a view into place, offset by `step` so a stack of elements
/// arrives in sequence instead of all at once.
private struct AppearModifier: ViewModifier {
    let step: Int
    let distance: CGFloat
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : distance)
            .onAppear {
                withAnimation(
                    .spring(response: 0.45, dampingFraction: 0.85)
                    .delay(Double(step) * 0.06)
                ) { shown = true }
            }
    }
}

extension View {
    /// Staggered entrance. `step` is the element's position in the sequence.
    func appear(step: Int = 0, distance: CGFloat = 12) -> some View {
        modifier(AppearModifier(step: step, distance: distance))
    }
}

// MARK: - Rejection

/// Short horizontal shake, for input the app is refusing.
private struct ShakeModifier: ViewModifier {
    let trigger: Int
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                guard trigger > 0 else { return }
                // Three decaying passes; the whole thing lasts ~0.25s.
                let steps: [(CGFloat, Double)] = [(-7, 0), (6, 0.06), (-4, 0.12), (0, 0.18)]
                for (value, delay) in steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                            offset = value
                        }
                    }
                }
            }
    }
}

extension View {
    /// Shakes whenever `trigger` increments.
    func shake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

// MARK: - Surfaces

/// A calm card surface: hairline border, barely-there shadow, no glow.
struct SoftCard: ViewModifier {
    var background: Color
    var border: Color
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

extension View {
    func softCard(background: Color, border: Color, cornerRadius: CGFloat = 16) -> some View {
        modifier(SoftCard(background: background, border: border, cornerRadius: cornerRadius))
    }
}
