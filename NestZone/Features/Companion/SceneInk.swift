import SwiftUI

/// The small arithmetic every painter in the scene shares: seeded randomness,
/// easing curves, and colour from hue, saturation and lightness.
///
/// The scene is a renderer, not a layout: its colours are worked out every
/// frame from the species, the mood and the clock, which is what `Canvas` is
/// for. The fixed ones live in `SceneInk` below as constants, like `Palette`.
enum Ink {
    /// FNV-1a over the string's scalars — the prototype's `hash`, bit for bit,
    /// so a household id grows the same tree here as in the HTML demo.
    static func hash(_ text: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for scalar in text.unicodeScalars {
            h ^= scalar.value
            h = h &* 16_777_619
        }
        return h
    }

    /// The prototype's seeded generator (mulberry32), returning 0..<1.
    struct Random {
        private var a: UInt32
        init(seed: UInt32) { a = seed }
        init(_ text: String) { a = Ink.hash(text) }

        mutating func next() -> Double {
            a = a &+ 0x6D2B_79F5
            var t = (a ^ (a >> 15)) &* (1 | a)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4_294_967_296
        }

        mutating func between(_ low: Double, _ high: Double) -> Double { low + (high - low) * next() }
        mutating func pick<T>(_ options: [T]) -> T { options[min(Int(next() * Double(options.count)), options.count - 1)] }
    }

    static func clamp(_ x: Double, _ low: Double = 0, _ high: Double = 1) -> Double { min(high, max(low, x)) }
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    /// Fast out, slow in.
    static func ease(_ t: Double) -> Double { 1 - pow(1 - clamp(t), 3) }
    static func smooth(_ t: Double) -> Double { let t = clamp(t); return t * t * (3 - 2 * t) }
    /// Overshoots a little and settles: things popping into place.
    static func back(_ t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        let c = 1.9
        return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)
    }

    /// A spring that has been flicked and is settling: the squash after a
    /// chore lands, the wobble after a pet.
    static func settle(_ t: Double, amplitude: Double, frequency: Double = 9, damping: Double = 5) -> Double {
        guard t >= 0 else { return 0 }
        return amplitude * exp(-damping * t) * sin(frequency * t)
    }

    /// Colour from hue in degrees and saturation and lightness in percent,
    /// the way the prototype was written.
    static func hsl(_ h: Double, _ s: Double, _ l: Double, _ a: Double = 1) -> Color {
        let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        let sat = clamp(s / 100), light = clamp(l / 100)
        let q = light < 0.5 ? light * (1 + sat) : light + sat - light * sat
        let p = 2 * light - q
        func channel(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        return Color(.sRGB, red: channel(hue + 1 / 3), green: channel(hue), blue: channel(hue - 1 / 3), opacity: clamp(a))
    }

    static func color(_ hex: UInt32, _ alpha: Double = 1) -> Color {
        Color(.sRGB,
              red: Double((hex >> 16) & 0xFF) / 255,
              green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255,
              opacity: alpha)
    }
}

/// The scene's fixed colours.
enum SceneInk {
    static let daySkyTop = Color(hex: "B9C6F5")
    static let daySkyBottom = Color(hex: "EDE4FB")
    static let nightSkyTop = Color(hex: "2A1A4C")
    static let nightSkyBottom = Color(hex: "1A1030")
    static let shadow = Color(.sRGB, red: 0.03, green: 0.01, blue: 0.1, opacity: 0.35)
    static let bark = Color(hex: "6B4A2E")
    static let sun = Color(hex: "FFD98A")
    static let moon = Color(hex: "EEF0FF")
    static let water = Color(hex: "5FB8F5")
    static let sparkle = Color(hex: "FFE296")
    static let heart = Color(hex: "FF78AA")
    static let glass = Color(.sRGB, red: 0.86, green: 0.92, blue: 1, opacity: 0.12)
    static let glassEdge = Color(.sRGB, red: 0.92, green: 0.96, blue: 1, opacity: 0.45)
    static let snow = Color(.sRGB, red: 0.98, green: 0.99, blue: 1, opacity: 0.92)
    static let pumpkin = Color(hex: "E7781F")
    static let pumpkinDark = Color(hex: "D9661A")
    static let stem = Color(hex: "3F6B2A")
    static let candle = Color(hex: "FFD45A")
    static let flame = Color(hex: "FFB347")
    static let red = Color(hex: "E5484D")
    static let gold = Color(hex: "F5C443")
    static let blue = Color(hex: "4F8FF7")
    static let silver = Color(hex: "D8DDE8")
    static let green = Color(hex: "22C55E")
    static let pink = Color(hex: "FF9EC0")
    static let rugRed = Color(hex: "A8323A")
    static let rugCream = Color(hex: "F0DDB0")
    static let rugBlue = Color(hex: "2D4A80")
    static let can = Color(hex: "7FB3BF")
    static let lantern = Color(hex: "D9382F")
    static let paper = Color(hex: "FFF6E0")
    static let brass = Color(hex: "C9A24A")
    static let clay = Color(hex: "C26A3D")
    static let bat = Color(hex: "1E1226")
    static let batRim = Color(hex: "FFB070").opacity(0.55)
    static let glow = Color(hex: "FFB45A")
}

extension GraphicsContext {
    /// Fills an ellipse centred on a point.
    func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ shading: GraphicsContext.Shading) {
        fill(Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)), with: shading)
    }

    func circle(_ x: Double, _ y: Double, _ r: Double, _ shading: GraphicsContext.Shading) {
        ellipse(x, y, r, r, shading)
    }

    /// A soft round glow, transparent at its edge.
    func glow(_ x: Double, _ y: Double, _ radius: Double, _ color: Color) {
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color, color.opacity(0)]),
            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: radius
        ))
    }

    /// A four-pointed glint.
    func glint(_ x: Double, _ y: Double, _ r: Double, _ color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: y - r * 2.4))
        path.addQuadCurve(to: CGPoint(x: x + r * 2.4, y: y), control: CGPoint(x: x, y: y))
        path.addQuadCurve(to: CGPoint(x: x, y: y + r * 2.4), control: CGPoint(x: x, y: y))
        path.addQuadCurve(to: CGPoint(x: x - r * 2.4, y: y), control: CGPoint(x: x, y: y))
        path.addQuadCurve(to: CGPoint(x: x, y: y - r * 2.4), control: CGPoint(x: x, y: y))
        fill(path, with: .color(color))
    }

    /// A heart, point down, centred near its middle.
    func heart(_ x: Double, _ y: Double, _ size: Double, _ color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: y + size * 0.45))
        path.addCurve(to: CGPoint(x: x, y: y - size * 0.15),
                      control1: CGPoint(x: x - size * 0.9, y: y - size * 0.25),
                      control2: CGPoint(x: x - size * 0.4, y: y - size))
        path.addCurve(to: CGPoint(x: x, y: y + size * 0.45),
                      control1: CGPoint(x: x + size * 0.4, y: y - size),
                      control2: CGPoint(x: x + size * 0.9, y: y - size * 0.25))
        fill(path, with: .color(color))
    }

    /// A five-pointed star.
    func star(_ x: Double, _ y: Double, _ r: Double, _ color: Color) {
        var path = Path()
        for i in 0..<10 {
            let angle = -Double.pi / 2 + Double(i) * .pi / 5
            let radius = i.isMultiple(of: 2) ? r : r * 0.45
            let point = CGPoint(x: x + cos(angle) * radius, y: y + sin(angle) * radius)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        fill(path, with: .color(color))
    }
}
