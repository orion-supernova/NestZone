import SwiftUI

// The house jar as a drawing: a glass jar with a cork, and what the house has
// piled at the bottom of it. Everything is code (`Canvas`), like the rest of
// Nestie's art, and everything that costs anything is made once: the pile is a
// fixed table of slots, so a balance only decides how many of them show, and
// nothing is laid out, sorted or random per frame.

/// What the jar holds, as the two numbers the drawing needs: how high the pile
/// stands and what share of it is Sparkles.
struct JarFill: Equatable {
    /// 0 is empty, 1 is the most the jar shows (a little into its neck).
    var level: Double
    /// Sparkles over Leaves and Sparkles together.
    var share: Double

    init(level: Double, share: Double) {
        self.level = level
        self.share = share
    }

    init(leaves: Int, sparkles: Int) {
        let l = Double(max(leaves, 0)), s = Double(max(sparkles, 0))
        self.init(level: Self.level(for: l + s), share: l + s > 0 ? s / (l + s) : 0.5)
    }

    /// A log curve, because a jar that is linear in coins is empty for the
    /// first week and overflowing in the second: about 40% full at 200,
    /// almost to the top at 5,000, and never past it. Nothing at 0, a first
    /// layer by about 20.
    static func level(for total: Double) -> Double {
        let scale = 30.0, top = 5_000.0
        let x = log(1 + total / scale) / log(1 + top / scale)
        return min(x, 1) * 0.94
    }

    func lerp(to other: JarFill, _ t: Double) -> JarFill {
        JarFill(level: level + (other.level - level) * t, share: share + (other.share - share) * t)
    }
}

/// One place in the pile. Fixed for every jar in the app.
struct JarSlot {
    /// Where it rests, as fractions of the jar's width and height.
    let x: Double, y: Double
    let rotation: Double
    let scale: Double
    /// Decides Leaf or Sparkle against the share, so the mix is the same
    /// wherever the jar is drawn and shifts one piece at a time.
    let pick: Double
    /// How high the pile must stand to include this slot: its height plus a
    /// little mound, so the surface is higher in the middle than at the glass.
    let key: Double
}

enum HouseJarArt {
    /// Width over height of the drawing.
    static let aspect: CGFloat = 0.8

    // Fractions of the jar's width and height, shared by the glass and the pile.
    private static let floorY = 0.90
    private static let topY = 0.24
    private static let shoulderY = 0.42
    private static let neckY = 0.27

    // MARK: The pile

    /// Every slot the jar could show, lowest first. About ninety.
    static let slots: [JarSlot] = {
        var rng = SplitMix(seed: 0x4E657374)
        let pitch = 0.088, rows = 11
        let rowStep = pitch * Double(aspect) * 0.86
        var out: [JarSlot] = []
        for row in 0..<rows {
            let y0 = floorY - 0.035 - Double(row) * rowStep
            let stagger = row.isMultiple(of: 2) ? 0.0 : 0.5
            for col in -6...6 {
                let x = 0.5 + (Double(col) + stagger) * pitch + (rng.next() - 0.5) * pitch * 0.5
                let y = y0 + (rng.next() - 0.5) * rowStep * 0.5
                let room = halfWidth(at: y) - pitch * 0.5
                guard abs(x - 0.5) <= room, y > topY else {
                    _ = (rng.next(), rng.next(), rng.next())
                    continue
                }
                let height = (floorY - 0.03 - y) / (floorY - 0.03 - topY)
                let across = abs(x - 0.5) / 0.4
                out.append(JarSlot(
                    x: x, y: y,
                    rotation: (rng.next() - 0.5) * 2.4,
                    scale: 0.88 + rng.next() * 0.3,
                    pick: rng.next(),
                    key: min(max(height, 0), 1) + 0.07 * across * across + (rng.next() - 0.5) * 0.02
                ))
                _ = rng.next()
            }
        }
        return out.sorted { $0.key < $1.key }
    }()

    /// How far the inside of the glass reaches from the middle at height `y`.
    private static func halfWidth(at y: Double) -> Double {
        let neck = 0.20, body = 0.40
        var half: Double
        if y <= neckY {
            half = neck
        } else if y >= shoulderY {
            half = body
        } else {
            let t = (y - neckY) / (shoulderY - neckY)
            half = neck + (body - neck) * (t * t * (3 - 2 * t))
        }
        // The rounded bottom corners.
        if y > floorY - 0.12 {
            let t = min((y - (floorY - 0.12)) / 0.12, 1)
            half -= 0.1 * t * t
        }
        return half
    }

    // MARK: Pieces

    /// A four-point star with its sides drawn in, one unit from the middle to a point.
    static let sparkle: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -1))
        p.addQuadCurve(to: CGPoint(x: 1, y: 0), control: CGPoint(x: 0.14, y: -0.14))
        p.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: 0.14, y: 0.14))
        p.addQuadCurve(to: CGPoint(x: -1, y: 0), control: CGPoint(x: -0.14, y: 0.14))
        p.addQuadCurve(to: CGPoint(x: 0, y: -1), control: CGPoint(x: -0.14, y: -0.14))
        return p
    }()

    /// A leaf pointing up, tip to stem one unit each way.
    static let leaf: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 1))
        p.addQuadCurve(to: CGPoint(x: 0, y: -1), control: CGPoint(x: 1.05, y: 0.05))
        p.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: -1.05, y: 0.05))
        return p
    }()

    private static let midrib: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.9))
        p.addLine(to: CGPoint(x: 0, y: -0.45))
        return p
    }()

    // MARK: Glass

    /// The jar's outline, or the inside of its glass with `inset`.
    static func glass(in size: CGSize, inset: Double = 0) -> Path {
        let w = size.width, h = size.height
        let left = 0.05 + inset, right = 0.95 - inset
        let nl = 0.25 + inset, nr = 0.75 - inset
        let bottom = floorY - inset * 0.9
        let rx = 0.14, ry = 0.075
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * w, y: y * h) }
        var p = Path()
        p.move(to: pt(nl, 0.19))
        p.addLine(to: pt(nl, neckY))
        p.addCurve(to: pt(left, shoulderY), control1: pt(nl, 0.35), control2: pt(left, 0.33))
        p.addLine(to: pt(left, bottom - ry))
        p.addQuadCurve(to: pt(left + rx, bottom), control: pt(left, bottom))
        p.addLine(to: pt(right - rx, bottom))
        p.addQuadCurve(to: pt(right, bottom - ry), control: pt(right, bottom))
        p.addLine(to: pt(right, shoulderY))
        p.addCurve(to: pt(nr, neckY), control1: pt(right, 0.33), control2: pt(nr, 0.35))
        p.addLine(to: pt(nr, 0.19))
        p.closeSubpath()
        return p
    }

    // MARK: Ink

    private enum Ink {
        static let glass = Gradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.05), Color.white.opacity(0.14)])
        static let body = Color.primary.opacity(0.05)
        static let edge = Color.primary.opacity(0.32)
        static let inner = Color.white.opacity(0.38)
        static let shine = Gradient(colors: [Color.white.opacity(0.62), Color.white.opacity(0.06)])
        static let faint = Color.white.opacity(0.28)
        static let shadow = Color.black.opacity(0.07)
        static let outline = Color.black.opacity(0.14)
        static let rib = Color.white.opacity(0.5)
        static let corkLight = Color(hex: "D9AA78")
        static let corkDark = Color(hex: "A97B4E")
        static let cork = Gradient(colors: [corkLight, corkDark])
        static let groove = Color.black.opacity(0.14)
        static let corkShine = Color.white.opacity(0.35)
    }

    // MARK: Drawing

    /// One frame of the jar. `progress` runs 0 to 1 from `from` to `to`; the
    /// pieces that `to` adds fall in from the neck, the ones `from` had stay
    /// put until the level takes them.
    static func draw(_ context: inout GraphicsContext, size: CGSize, from: JarFill, to: JarFill, progress: Double) {
        let w = size.width, h = size.height
        let now = from.lerp(to: to, progress)

        // Where it stands: three flat ellipses, soft enough.
        for (grow, shade) in [(1.0, 1.0), (0.78, 1.0), (0.56, 1.0)] as [(Double, Double)] {
            let rect = CGRect(x: w * (0.5 - 0.42 * grow), y: h * (0.915 - 0.03 * grow), width: w * 0.84 * grow, height: h * 0.06 * grow)
            context.fill(Path(ellipseIn: rect), with: .color(Ink.shadow.opacity(shade)))
        }

        let outline = glass(in: size)
        let line = max(w * 0.022, 0.8)

        // The glass, over a faint body so it shows on a pale screen too.
        context.fill(outline, with: .color(Ink.body))
        context.fill(outline, with: .linearGradient(Ink.glass, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: 0)))

        // The pile, inside the glass.
        let inside = glass(in: size, inset: 0.035)
        context.drawLayer { layer in
            layer.clip(to: inside)
            drawPile(&layer, size: size, from: from, to: to, now: now, progress: progress)
        }

        // Light on the front of the glass.
        let streak = Path(roundedRect: CGRect(x: w * 0.115, y: h * 0.44, width: w * 0.05, height: h * 0.36), cornerRadius: w * 0.025)
        context.fill(streak, with: .linearGradient(Ink.shine, startPoint: CGPoint(x: 0, y: h * 0.44), endPoint: CGPoint(x: 0, y: h * 0.8)))
        context.fill(Path(ellipseIn: CGRect(x: w * 0.115, y: h * 0.38, width: w * 0.05, height: w * 0.05)), with: .color(Ink.inner))
        context.fill(Path(roundedRect: CGRect(x: w * 0.285, y: h * 0.21, width: w * 0.03, height: h * 0.12), cornerRadius: w * 0.015), with: .color(Ink.faint))
        context.fill(Path(roundedRect: CGRect(x: w * 0.855, y: h * 0.5, width: w * 0.03, height: h * 0.22), cornerRadius: w * 0.015), with: .color(Ink.faint.opacity(0.6)))

        context.stroke(inside, with: .color(Ink.inner.opacity(0.5)), lineWidth: line * 0.6)
        context.stroke(outline, with: .color(Ink.edge), lineWidth: line)

        // The lip of the glass and the cork.
        let lip = Path(roundedRect: CGRect(x: w * 0.2, y: h * 0.135, width: w * 0.6, height: h * 0.06), cornerRadius: h * 0.03)
        context.fill(lip, with: .color(Ink.body))
        context.fill(lip, with: .linearGradient(Ink.glass, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: 0)))
        context.stroke(lip, with: .color(Ink.edge), lineWidth: line)

        let cork = Path(roundedRect: CGRect(x: w * 0.24, y: h * 0.02, width: w * 0.52, height: h * 0.14), cornerRadius: h * 0.035)
        context.fill(cork, with: .linearGradient(Ink.cork, startPoint: CGPoint(x: 0, y: h * 0.02), endPoint: CGPoint(x: 0, y: h * 0.16)))
        context.stroke(cork, with: .color(Ink.groove), lineWidth: line * 0.7)
        for y in [0.07, 0.115] {
            var groove = Path()
            groove.move(to: CGPoint(x: w * 0.27, y: h * y))
            groove.addLine(to: CGPoint(x: w * 0.73, y: h * y))
            context.stroke(groove, with: .color(Ink.groove), lineWidth: line * 0.5)
        }
        context.fill(Path(roundedRect: CGRect(x: w * 0.28, y: h * 0.032, width: w * 0.2, height: h * 0.018), cornerRadius: h * 0.009), with: .color(Ink.corkShine))
    }

    private static func drawPile(_ context: inout GraphicsContext, size: CGSize, from: JarFill, to: JarFill, now: JarFill, progress: Double) {
        let w = size.width, h = size.height
        // A piece is a little larger than its pitch, so the pile reads as a
        // pile; on a small jar the pieces grow, or they are only dust.
        let piece = w * 0.062 * (w < 44 ? 1.5 : 1)
        let outlined = w >= 44
        let rise = to.level - from.level
        let rises = rise > 0.0001
        let sparkleShading = GraphicsContext.Shading.color(Palette.sparkle)
        let leafShading = GraphicsContext.Shading.color(Palette.leaf)
        let top = 0.2

        for slot in slots {
            var y = slot.y
            var opacity = 1.0
            if rises, slot.key > from.level {
                // New: it falls in, the lower ones first.
                guard slot.key <= to.level else { continue }
                let order = (slot.key - from.level) / rise
                let local = min(max((progress - order * 0.45) / 0.55, 0), 1)
                guard local > 0 else { continue }
                y = top + (slot.y - top) * local
                opacity = min(local * 4, 1)
            } else {
                guard slot.key <= now.level else { continue }
            }
            let isSparkle = slot.pick < now.share
            var layer = context
            layer.opacity = opacity
            layer.translateBy(x: w * slot.x, y: h * y)
            layer.rotate(by: .radians(slot.rotation))
            let radius = piece * slot.scale
            layer.scaleBy(x: radius * (isSparkle ? 1.25 : 0.8), y: radius * (isSparkle ? 1.25 : 1.2))
            if isSparkle {
                layer.fill(sparkle, with: sparkleShading)
                if outlined { layer.stroke(sparkle, with: .color(Ink.outline), lineWidth: 0.4 / max(radius, 1)) }
            } else {
                layer.fill(leaf, with: leafShading)
                if outlined {
                    layer.stroke(leaf, with: .color(Ink.outline), lineWidth: 0.4 / max(radius, 1))
                    layer.stroke(midrib, with: .color(Ink.rib), lineWidth: 0.5 / max(radius, 1))
                }
            }
        }
    }
}

/// A small, fixed-seed generator, so the pile is the same on every launch.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}
