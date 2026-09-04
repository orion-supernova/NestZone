import SwiftUI

/// The colours a note can be written on.
///
/// Stored and read as a **name**, because that is what every note already in the
/// database holds (`"yellow"`, `"purple"`, …). `parse` also accepts a hex string
/// so nothing breaks if a value written by another client turns up.
///
/// The swatches are Post-it pastels rather than system colours: the text on a
/// sticky note is near-black, and `.red`/`.purple` at full saturation make that
/// unreadable.
public enum StickyColor: String, CaseIterable, Sendable, Identifiable {
    case yellow, orange, pink, red, green, blue, purple

    public var id: String { rawValue }

    public var paper: Color {
        switch self {
        case .yellow: Palette.paperYellow
        case .orange: Palette.paperOrange
        case .pink: Palette.paperPink
        case .red: Palette.paperRed
        case .green: Palette.paperGreen
        case .blue: Palette.paperBlue
        case .purple: Palette.paperPurple
        }
    }

    /// The value written to the server.
    public var storedValue: String { rawValue }

    /// Friendly name, the way the old composer labelled them — "Sunny Yellow"
    /// reads better in a picker than "yellow".
    public var displayName: LocalizedStringResource {
        switch self {
        case .yellow: L10n.notesColorYellow
        case .orange: L10n.notesColorOrange
        case .pink: L10n.notesColorPink
        case .red: L10n.notesColorRed
        case .green: L10n.notesColorGreen
        case .blue: L10n.notesColorBlue
        case .purple: L10n.notesColorPurple
        }
    }

    /// Accepts a legacy colour name, one of ours, or a hex string.
    public static func parse(_ raw: String?) -> StickyColor {
        guard let raw, !raw.isEmpty else { return .yellow }
        let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let named = StickyColor(rawValue: trimmed) { return named }
        // Hex from an intermediate build; map to the nearest swatch by name so
        // the note keeps a sensible colour instead of falling back to yellow.
        switch trimmed.replacingOccurrences(of: "#", with: "") {
        case "f59e0b": return .orange
        case "f43f5e": return .red
        case "8b5cf6": return .purple
        case "14b8a6": return .green
        case "3b82f6": return .blue
        case "64748b": return .blue
        default: return .yellow
        }
    }
}

extension Palette {
    // Paper tones — light enough to carry near-black text at any size.
    public static let paperYellow = Color(hex: "FDE68A")
    public static let paperOrange = Color(hex: "FDBA74")
    public static let paperPink = Color(hex: "FBCFE8")
    public static let paperRed = Color(hex: "FCA5A5")
    public static let paperGreen = Color(hex: "BBF7D0")
    public static let paperBlue = Color(hex: "BFDBFE")
    public static let paperPurple = Color(hex: "DDD6FE")
}

/// A note, drawn as a square of paper pinned to the board.
///
/// This is the one surface in the app that is deliberately **not** glass and
/// **does** carry a drop shadow: it is pretending to be a physical object, and
/// paper lying on a board casts a shadow. Everything else stays on the glass
/// rules in `Glass.swift`.
///
/// Tapping re-pins it — the tilt flips to the other side and picks a new angle,
/// with a press-down and a light haptic. It does nothing useful, and that is
/// the point.
public struct StickyNote<Footer: View>: View {
    private let text: String
    private let color: StickyColor
    /// Seeds the resting angle so a note keeps the same tilt across redraws and
    /// scrolls. `String.hashValue` is seeded per process, so it would reshuffle
    /// the whole board on every launch.
    private let seed: String
    private let footer: Footer

    @State private var tilt: Double
    @State private var isPressed = false
    @State private var flipCount = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        text: String,
        color: StickyColor,
        seed: String,
        @ViewBuilder footer: () -> Footer
    ) {
        self.text = text
        self.color = color
        self.seed = seed
        self.footer = footer()
        // Set here rather than in `onAppear`, so the note is already tilted on
        // its first frame instead of snapping into place after it lands.
        _tilt = State(initialValue: Self.restingAngle(for: seed))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            footer
        }
        .padding(14)
        .frame(height: 158)
        .frame(maxWidth: .infinity)
        .background(paper)
        // 2pt, not 20: paper corners are cut, not rounded.
        .clipShape(.rect(cornerRadius: 2))
        .rotationEffect(.degrees(tilt))
        .scaleEffect(isPressed ? 0.95 : 1)
        .shadow(color: .black.opacity(0.18), radius: 4, x: 1, y: 3)
        .contentShape(.rect)
        .onTapGesture { repin() }
        .sensoryFeedback(.impact(weight: .light), trigger: flipCount)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Colour, plus a soft sheen so it reads as a sheet rather than a swatch.
    private var paper: some View {
        ZStack {
            Rectangle().fill(color.paper)
            LinearGradient(
                colors: [.white.opacity(0.35), .clear, .black.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func repin() {
        guard !reduceMotion else {
            flipCount += 1
            return
        }
        // Flip to the other side of vertical and pick a fresh angle, so a
        // repeated tap keeps giving a visibly different result.
        let direction: Double = tilt >= 0 ? -1 : 1
        let angle = direction * Double.random(in: 1...5)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isPressed = true
            tilt = angle
        }
        flipCount += 1

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.12)) {
            isPressed = false
        }
    }

    /// Stable per-note angle in roughly -3…3 degrees.
    private static func restingAngle(for seed: String) -> Double {
        var hash: UInt64 = 5381
        for byte in seed.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return Double(hash % 61) / 10 - 3      // 0.0…6.0 → -3.0…3.0
    }
}

extension StickyNote where Footer == EmptyView {
    public init(text: String, color: StickyColor, seed: String) {
        self.init(text: text, color: color, seed: seed) { EmptyView() }
    }
}
