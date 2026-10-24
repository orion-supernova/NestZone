import SwiftUI

// MARK: - The perched bird

extension CritterPainter {
    func perched(_ c: GraphicsContext) {
        let w = motion.weights
        var b = c
        // A sleepy one sits lower and rounder, a bright one stands tall.
        let sink = motion.by(3.5, 2.4, 1.2, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.025 * w.doze, y: 1 - 0.022 * sink)
        b.translateBy(x: -60, y: -108)

        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let accent = look.accent
        let bw = plan.bodyWidth

        // Feet: three round toes each.
        for s in [-1.0, 1] {
            for dx in [-3.6, 0, 3.6] { b.ellipse(60 + s * 10 + dx, 108, 2.6, 2, .color(accent.color())) }
            b.fill(Path(roundedRect: CGRect(x: 60 + s * 10 - 1.6, y: 101, width: 3.2, height: 7), cornerRadius: 1.6), with: .color(accent.shifted(-8).color()))
        }
        let g = CritterGeometry.bird(plan)
        // The body: an egg, lit by the sky, and the pale breast with its rows of chevrons.
        form(b, g.bodyFur[look.L.x > 0 ? 0 : 1], centre: CGPoint(x: 60, y: 80), radius: 32, light, coat, dark, highlight: 0.55)
        let breast = Path(ellipseIn: CGRect(x: 60 - 17.5, y: 66, width: 35, height: 43))
        b.fill(breast, with: .radialGradient(Gradient(colors: [look.lifted(belly, 0.3).color(), belly.color(), belly.shifted(-10, 3).color()]),
                                             center: CGPoint(x: 55, y: 78), startRadius: 0, endRadius: 28))
        b.stroke(g.chevrons, with: .color(mark.color(0.55)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))

        // The wings, folded at its sides: they lift when it is bright, hang when it is tired, and open a little on a hop.
        let flap = hop.flatMap { $0 < 0.66 ? abs(sin($0 / 0.22 * .pi)) * 0.55 : nil } ?? 0
        let lift = w.bright * 0.1
        let droop = 0.1 * slump + 0.12 * w.thirst
        for s in [-1.0, 1] {
            var wc = b
            wc.translateBy(x: 60 + s * 23, y: 64)
            wc.rotate(by: .radians(s * (droop - lift - flap)))
            let eL = CGPoint(x: look.L.x * s, y: look.L.y)
            var wing = Path()
            wing.leaf(0, 0, s * 0.16, 0.99, 42, 12.5, 0.35)
            form(wc, wing, centre: CGPoint(x: s * 2, y: 20), radius: 22, coat, dark, dark.shifted(-6), highlight: 0, core: 0.6, rim: true, L: eL)
            var feathers = Path()
            for (i, y) in [16.0, 26, 35].enumerated() {
                feathers.move(to: CGPoint(x: s * (2 + Double(i)) - 5, y: y))
                feathers.addQuadCurve(to: CGPoint(x: s * (2 + Double(i)) + 5, y: y + 1), control: CGPoint(x: s * (2 + Double(i)), y: y + 4))
            }
            wc.stroke(feathers, with: .color(light.color(0.5)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            wc.fill(Path(ellipseIn: CGRect(x: -4, y: 2, width: 5, height: 14)), with: .color(light.color(0.3)))
        }

        var h = b
        // The head turns toward the bowl when it wants something, tucks when it sleeps.
        h.translateBy(x: 60, y: 70)
        h.rotate(by: .radians(motion.by(0.16, -0.14, 0.01, 0.07) + (frame.reduceMotion ? 0 : 0.05 * sin(time / 3.4 * .pi * 2) * w.bright)))
        h.translateBy(x: -60, y: -70)
        h.translateBy(x: motion.by(0, -2, 0, 0), y: motion.by(5, 3, 0.6, -0.6))
        perchedHead(h, babyness: babyness)
    }

    /// The owl's head: tufts, a wide head, two pale discs with big eyes
    /// and the beak between them.
    func perchedHead(_ c: GraphicsContext, babyness: Double, drop: Double = 0) {
        var h = c
        // A hatchling's head sits low, in the shell.
        h.translateBy(x: 0, y: drop)
        let wt = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let accent = look.accent
        let L = look.L
        let w = 27 * plan.headWidth * (1 + babyness * 0.12)
        // Ear tufts: two feathers standing out from the top of the head, upright
        // when bright, flat and sideways when it wants something, down asleep.
        let twitchRight = Int(motion.time / 5.9) % 2 == 0
        let twitch = motion.beat(every: 5.9, lasting: 0.22, offset: 2.4) * motion.awake
        for s in [-1.0, 1] {
            var tuft = Path()
            let spread = 0.6 + 0.4 * slump + motion.by(0, 0.5, 0, -0.1) + ((s > 0) == twitchRight ? twitch * 0.3 : 0)
            let a = -Double.pi / 2 + s * spread
            tuft.leaf(60 + s * 17, 35, cos(a), sin(a), 15 * plan.earHeight, 5.4, 0.2)
            form(h, tuft, centre: CGPoint(x: 60 + s * 17, y: 28), radius: 10, light, coat, dark, highlight: 0.3, core: 0.6)
            var line = Path()
            line.move(to: CGPoint(x: 60 + s * 17, y: 34))
            line.addLine(to: CGPoint(x: 60 + s * 17 + cos(a) * 10, y: 35 + sin(a) * 10))
            h.stroke(line, with: .color(mark.color(0.6)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        let head = Path(ellipseIn: CGRect(x: 60 - w, y: 28, width: w * 2, height: 44))
        form(h, head, centre: CGPoint(x: 60, y: 50), radius: w * 1.1, light, coat, dark, highlight: 0.5)
        // The facial discs: pale, ringed, with the eyes in them.
        let open = Ink.clamp(1 - motion.by(1, 0, 0, 0))
        let gaze = CGPoint(x: -0.62 * wt.thirst, y: 0.7 * wt.thirst)
        for s in [-1.0, 1] {
            let centre = CGPoint(x: 60 + s * 11.5, y: 51)
            let disc = Path(ellipseIn: CGRect(x: centre.x - 13.5, y: centre.y - 14, width: 27, height: 28))
            h.fill(disc, with: .radialGradient(Gradient(colors: [look.lifted(belly, 0.35).color(), belly.color(), belly.shifted(-12, 4).color()]),
                                               center: CGPoint(x: centre.x + L.x * 4, y: centre.y + L.y * 4), startRadius: 0, endRadius: 17))
            h.stroke(disc, with: .color(mark.color(0.4)), lineWidth: 1.2)
            // The brow: a dark feather over each eye.
            var brow = Path()
            let ba = s > 0 ? -0.5 : -Double.pi + 0.5
            brow.leaf(60 + s * 3, 40, cos(ba), sin(ba), 15, 2.6, 0.2)
            h.fill(brow, with: .color(dark.color(0.5)))
            _ = open
            eye(h, at: centre, side: s, rx: 6.6 * plan.eyeSize, ry: 6.6 * plan.eyeSize, gaze: gaze, droop: motion.by(1, 0.0, 0.08, 0), lid: belly.shifted(-4))
        }
        // The beak: small, hooked, between the eyes, a little open when it wants water.
        var beak = Path.smooth([CGPoint(x: 56.6, y: 53.5), CGPoint(x: 60, y: 52.6), CGPoint(x: 63.4, y: 53.5), CGPoint(x: 60, y: 62)])
        beak.closeSubpath()
        h.fill(beak.offsetBy(dx: L.x * 0.5, dy: L.y * 0.5), with: .color(look.rim.color(look.rimAlpha * 0.7)))
        h.fill(beak, with: .linearGradient(Gradient(colors: [look.lifted(accent, 0.3).color(), accent.color(), accent.shifted(-14, 4).color()]),
                                           startPoint: CGPoint(x: 57, y: 53), endPoint: CGPoint(x: 62, y: 62)))
        h.fill(Path(ellipseIn: CGRect(x: 58, y: 54, width: 1.8, height: 3)), with: .color(Color.white.opacity(0.45)))
        let blush = Ink.lerp(0.18, 0.8, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.7 * wt.thirst)
        for s in [-1.0, 1] { h.circle(60 + s * 22, 61, 3, .color(look.tone(0xFF8FA3).color(blush))) }
        owlCap(h)
    }

    /// The nightcap on a dozing owl, on the head, between the tufts.
    private func owlCap(_ h: GraphicsContext) {
        guard frame.mood < 0.15 || frame.domeLift > 0, stage >= 3 else { return }
        var c = h
        c.translateBy(x: 60, y: 42)
        c.scaleBy(x: 1.15, y: 1.15)
        cap(c, motion.weights)
    }
}

/// The owl's body, furred from inside on its shadow side, and its breast
/// feathers: built once per plan.
struct BirdGeometry {
    let chevrons: Path
    let bodyFur: [Path]

    init(_ plan: CritterPlan) {
        var p = Path()
        for (row, y) in [74.0, 82, 90, 98].enumerated() {
            for x in stride(from: row.isMultiple(of: 2) ? -9.0 : -4.5, through: 9, by: 9) {
                p.move(to: CGPoint(x: 60 + x - 3.4, y: y - 2.4))
                p.addQuadCurve(to: CGPoint(x: 60 + x, y: y + 1.6), control: CGPoint(x: 60 + x - 2.4, y: y + 1.2))
                p.addQuadCurve(to: CGPoint(x: 60 + x + 3.4, y: y - 2.4), control: CGPoint(x: 60 + x + 2.4, y: y + 1.2))
            }
        }
        chevrons = p
        let bw = plan.bodyWidth, fur = plan.fur
        let body = Path(ellipseIn: CGRect(x: 60 - 28 * bw, y: 50, width: 56 * bw, height: 60))
        func furred(_ shadowRight: Double) -> Path {
            FurEdge.furry(body, seed: "bird-\(plan.key)-\(shadowRight)", gap: 6...11, height: (1.2 * fur)...(2.6 * fur), width: 3.6) { q in
                q.y > 102 ? 0 : 0.3 + 0.7 * Ink.smooth(((q.x - 60) * shadowRight) / 22)
            }
        }
        bodyFur = [furred(-1), furred(1)]
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var birds: [String: BirdGeometry] = [:]
    private static let birdLock = NSLock()

    static func bird(_ plan: CritterPlan) -> BirdGeometry {
        birdLock.lock(); defer { birdLock.unlock() }
        if let kept = birds[plan.key] { return kept }
        let made = BirdGeometry(plan)
        birds[plan.key] = made
        return made
    }
}
