import SwiftUI

// MARK: - The perched bird

/// What each of the owl's stages is made of. A hatchling is a bare, wet,
/// pinkish blob with its eyes sealed shut; an owlet a ball of grey down with
/// huge dark eyes and no tufts; a little one starts to show the pins of its
/// wing feathers and the nubs of its tufts; a brancher, which has left the
/// nest and clambers about the branches, is half down and half feather, its
/// wings too big for it and held out to balance, its tufts coming; the grown
/// owl is smooth and barred, with its facial disc ringed and its eyes gold.
/// `down` is how much of it is still down (0...1), `feathers` how many tips
/// of its feathers are in, `wingFeather` how far its wings have grown their
/// own.
struct OwlGrowth {
    var body: CGSize
    var head: Double, down: Double, feathers: Double
    var wing: Double, wingFeather: Double, spread: Double, quills: Int
    var tuft: Double, eye: Double, beak: Double, feet: Double
    var ring: Double, chevrons: Double, fuzz: Double, squash: Double

    static func of(_ stage: Int) -> OwlGrowth {
        switch stage {
        case ...2: OwlGrowth(body: CGSize(width: 1, height: 1), head: 1.0, down: 1, feathers: 0, wing: 0.4, wingFeather: 0, spread: 0, quills: 0,
                              tuft: 0, eye: 1, beak: 0.85, feet: 1.3, ring: 0, chevrons: 0, fuzz: 0, squash: 0.1)
        case 3: OwlGrowth(body: CGSize(width: 1.1, height: 0.86), head: 1.1, down: 1, feathers: 0, wing: 0.5, wingFeather: 0, spread: 0, quills: 0,
                          tuft: 0, eye: 1.4, beak: 0.8, feet: 1.25, ring: 0, chevrons: 0, fuzz: 0, squash: 0.05)
        case 4: OwlGrowth(body: CGSize(width: 1.06, height: 0.93), head: 1.05, down: 0.9, feathers: 0, wing: 0.7, wingFeather: 0.35, spread: 0.1, quills: 1,
                          tuft: 0.25, eye: 1.28, beak: 0.9, feet: 1.15, ring: 0.15, chevrons: 0, fuzz: 0, squash: 0.03)
        case 5: OwlGrowth(body: CGSize(width: 1, height: 0.98), head: 1.02, down: 0.45, feathers: 0.72, wing: 0.9, wingFeather: 0.85, spread: 0.34, quills: 2,
                          tuft: 0.65, eye: 1.12, beak: 0.96, feet: 1.05, ring: 0.55, chevrons: 0.5, fuzz: 1, squash: 0.01)
        default: OwlGrowth(body: CGSize(width: 0.97, height: 1.03), head: 1, down: 0, feathers: 1, wing: 1, wingFeather: 1, spread: 0, quills: 0,
                           tuft: 1, eye: 1, beak: 1, feet: 1, ring: 1, chevrons: 1, fuzz: 0, squash: 0)
        }
    }
}

extension CritterPainter {
    /// An owlet's down: the belly's colour dulled to a grey; on a hatchling,
    /// a little pink with the skin under it.
    private var owlDown: RGB {
        let base = look.belly.mix(look.tone(0xD8D6D2), 0.45)
        return stage <= 2 ? base.mix(look.tone(0xE3BDB4, dim: 0.6), 0.45) : base
    }

    func perched(_ c: GraphicsContext) {
        let g = CritterGeometry.bird(plan), s = CritterGeometry.owlStages(plan)
        let k = OwlGrowth.of(stage)
        let w = motion.weights
        var b = c
        // A sleepy one sits lower and rounder, a bright one stands tall.
        let sink = motion.by(3.5, 2.4, 1.2, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.025 * w.doze, y: 1 - 0.022 * sink - k.squash)
        b.translateBy(x: -60, y: -108)

        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let accent = look.accent
        let down = owlDown
        let lit = look.L.x > 0 ? 0 : 1

        // Feet: three round toes each; an owlet's are big for it and pale.
        let toe = accent.mix(down, 0.5 * k.down)
        for sd in [-1.0, 1] {
            var f = b
            f.translateBy(x: 60 + sd * 10, y: 108)
            f.scaleBy(x: k.feet, y: k.feet)
            f.translateBy(x: -(60 + sd * 10), y: -108)
            for dx in [-3.6, 0, 3.6] { f.ellipse(60 + sd * 10 + dx, 108, 2.6, 2, .color(toe.color())) }
            f.fill(Path(roundedRect: CGRect(x: 60 + sd * 10 - 1.6, y: 101, width: 3.2, height: 7), cornerRadius: 1.6), with: .color(toe.shifted(-8).color()))
        }

        // The body: an egg, lit by the sky; its down or its feathers, and
        // the pale breast with its rows of chevrons once they are in.
        var bb = b
        bb.translateBy(x: 60, y: 108)
        bb.scaleBy(x: k.body.width, y: k.body.height)
        bb.translateBy(x: -60, y: -108)
        let bl = light.mix(look.lifted(down, 0.2), k.down), bm = coat.mix(down, k.down), bd = dark.mix(down.shifted(-16), k.down)
        form(bb, stage >= 5 ? g.bodyFur[lit] : s.downBody[lit], centre: CGPoint(x: 60, y: 80), radius: 32, bl, bm, bd, highlight: 0.55)
        if k.down > 0.02 { hairs(bb, s.downHairs, dark: bd.shifted(-6), light: look.lifted(bl, 0.3), alpha: 0.3 * k.down) }
        if k.down < 0.98 { hairs(bb, g.hairs, dark: mark, light: look.lifted(light, 0.25), alpha: 0.3 * (1 - k.down)) }
        feathers(bb, s.scallops, coverage: k.feathers, centre: CGPoint(x: 60, y: 80), radius: 32, light.mix(coat, 0.3), coat, dark)
        let breast = Path(ellipseIn: CGRect(x: 60 - 17.5, y: 66, width: 35, height: 43))
        let breastC = belly.mix(down, 0.7 * k.down)
        bb.fill(breast, with: .radialGradient(Gradient(colors: [look.lifted(breastC, 0.3).color(), breastC.color(), breastC.shifted(-10, 3).color()]),
                                              center: CGPoint(x: 55, y: 78), startRadius: 0, endRadius: 28))
        if k.chevrons > 0.02 { bb.stroke(g.chevrons, with: .color(mark.color(0.55 * k.chevrons)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)) }
        if k.fuzz > 0.02 { bb.fill(s.fuzz, with: .color(look.lifted(down, 0.15).color(0.85 * k.fuzz))) }

        // The wings, folded at its sides: they lift when it is bright, hang
        // when it is tired, and open a little on a hop. A little one's are
        // stubs of down with quills in them; a brancher's are held out,
        // clumsy, to balance on its branch.
        let flap = hop.flatMap { $0 < 0.66 ? abs(sin($0 / 0.22 * .pi)) * 0.55 : nil } ?? 0
        let lift = w.bright * 0.1
        let droop = 0.1 * slump + 0.12 * w.thirst
        let clumsy = frame.reduceMotion || k.spread < 0.05 ? 0 : max(w.bright, 0.3) * 0.09
        for sd in [-1.0, 1] {
            var wc = bb
            wc.translateBy(x: 60 + sd * 23, y: 64)
            let open = k.spread * (sd > 0 ? 1 : 0.55) + clumsy * sin(time * 9 + (sd > 0 ? 0 : 2.1))
            wc.rotate(by: .radians(sd * (droop - lift - flap - open)))
            wc.scaleBy(x: k.wing, y: k.wing)
            let eL = CGPoint(x: look.L.x * sd, y: look.L.y)
            var wing = Path()
            wing.leaf(0, 0, sd * 0.16, 0.99, 42, 12.5, 0.35)
            let fw = k.wingFeather
            form(wc, wing, centre: CGPoint(x: sd * 2, y: 20), radius: 22, coat.mix(down, 1 - fw), dark.mix(down.shifted(-8), 1 - fw), dark.shifted(-6).mix(down.shifted(-16), 1 - fw), highlight: 0, core: 0.6, rim: true, L: eL)
            hairs(wc, g.wingHairs[sd > 0 ? 1 : 0], dark: dark.shifted(-10), light: look.lifted(light, 0.2), alpha: 0.4 * fw)
            if k.down > 0.02 { hairs(wc, g.wingHairs[sd > 0 ? 1 : 0], dark: down.shifted(-18), light: look.lifted(down, 0.3), alpha: 0.35 * (1 - fw)) }
            var feathers = Path()
            for (i, y) in [16.0, 26, 35].enumerated() {
                feathers.move(to: CGPoint(x: sd * (2 + Double(i)) - 5, y: y))
                feathers.addQuadCurve(to: CGPoint(x: sd * (2 + Double(i)) + 5, y: y + 1), control: CGPoint(x: sd * (2 + Double(i)), y: y + 4))
            }
            wc.stroke(feathers, with: .color(light.color(0.5 * fw)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            wc.fill(Path(ellipseIn: CGRect(x: -4, y: 2, width: 5, height: 14)), with: .color(light.color(0.3 * fw)))
            if k.quills > 0 {
                let q = s.wingQuills[sd > 0 ? 1 : 0][k.quills - 1]
                wc.stroke(q.shafts, with: .color(dark.color(0.9)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                wc.fill(q.sheaths, with: .color(look.lifted(down, 0.3).color(0.95)))
            }
        }

        var h = b
        // The head turns toward the bowl when it wants something, tucks when it sleeps.
        let seat = (1 - k.body.height) * 38
        h.translateBy(x: 60, y: 70 + seat)
        h.rotate(by: .radians(motion.by(0.16, -0.14, 0.01, 0.07) + (frame.reduceMotion ? 0 : 0.05 * sin(time / 3.4 * .pi * 2) * w.bright)))
        h.translateBy(x: -60, y: -(70 + seat))
        h.translateBy(x: motion.by(0, -2, 0, 0), y: motion.by(5, 3, 0.6, -0.6) + seat)
        neckwear(b, at: CGPoint(x: 60, y: 73 + seat), span: 23 * k.body.width, size: 1.1)
        perchedHead(h, babyness: 1)
    }

    /// The owl's head: tufts, a wide head, two pale discs with big eyes
    /// and the beak between them. An owlet's is a ball of down with huge
    /// dark eyes in a darker mask and no tufts; the tufts and the ring round
    /// each disc come in with the feathers.
    func perchedHead(_ c: GraphicsContext, babyness: Double, drop: Double = 0) {
        let g = CritterGeometry.bird(plan), s = CritterGeometry.owlStages(plan)
        let k = OwlGrowth.of(stage)
        let hatch = stage <= 2
        var h = c
        h.translateBy(x: 0, y: drop)
        let wt = motion.weights
        let down = owlDown
        let coat = look.coat.mix(down, k.down), light = look.light.mix(look.lifted(down, 0.2), k.down), dark = look.dark.mix(down.shifted(-16), k.down)
        let belly = look.belly, mark = look.mark
        let accent = look.accent
        let L = look.L
        let lit = L.x > 0 ? 0 : 1
        let w = 27 * plan.headWidth * k.head
        h.translateBy(x: 60, y: 52)
        h.scaleBy(x: k.head, y: k.head)
        h.translateBy(x: -60, y: -52)
        // Ear tufts: two feathers standing out from the top of the head, upright
        // when bright, flat and sideways when it wants something, down asleep.
        if k.tuft > 0.05 {
            let twitchRight = Int(motion.time / 5.9) % 2 == 0
            let twitch = motion.beat(every: 5.9, lasting: 0.22, offset: 2.4) * motion.awake
            for sd in [-1.0, 1] {
                var tuft = Path()
                let spread = 0.6 + 0.4 * slump + motion.by(0, 0.5, 0, -0.1) + ((sd > 0) == twitchRight ? twitch * 0.3 : 0)
                let a = -Double.pi / 2 + sd * spread
                tuft.leaf(60 + sd * 17, 35, cos(a), sin(a), 18 * plan.earHeight * k.tuft, 6.4 * (0.55 + 0.45 * k.tuft), 0.2)
                form(h, tuft, centre: CGPoint(x: 60 + sd * 17, y: 28), radius: 10, light, coat, dark, highlight: 0.3, core: 0.6)
                var line = Path()
                line.move(to: CGPoint(x: 60 + sd * 17, y: 34))
                line.addLine(to: CGPoint(x: 60 + sd * 17 + cos(a) * 10 * k.tuft, y: 35 + sin(a) * 10 * k.tuft))
                h.stroke(line, with: .color(mark.color(0.6 * (1 - k.down))), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        }
        var hh = h
        hh.translateBy(x: 60, y: 50)
        hh.scaleBy(x: 1 + (hatch ? 0 : 0.06 * k.down), y: 1)
        hh.translateBy(x: -60, y: -50)
        form(hh, hatch ? s.hatchHead[lit] : stage >= 5 ? g.headFur[lit] : s.downHead[lit], centre: CGPoint(x: 60, y: 50), radius: w * 1.1, light, coat, dark, highlight: 0.5)
        if k.fuzz > 0.02 { hh.fill(s.headFuzz, with: .color(look.lifted(down, 0.15).color(0.85 * k.fuzz))) }
        // The facial discs: pale, ringed, with the eyes in them. An owlet's
        // is the colour of its down with a darker mask round the eye.
        let gaze = CGPoint(x: -0.62 * wt.thirst, y: 0.7 * wt.thirst)
        if k.ring > 0.05 { hairs(h, g.ruff, dark: mark, light: look.lifted(belly, 0.2), alpha: 0.24 * k.ring) }
        let face = belly.mix(down, 0.8 * k.down).mix(look.coat, 0.16 * k.down)
        for sd in [-1.0, 1] {
            let centre = CGPoint(x: 60 + sd * 11.5, y: 51)
            let disc = Path(ellipseIn: CGRect(x: centre.x - 13.5, y: centre.y - 14, width: 27, height: 28))
            h.fill(disc, with: .radialGradient(Gradient(colors: [look.lifted(face, 0.35).color(), face.color(), face.shifted(-12, 4).color()]),
                                               center: CGPoint(x: centre.x + L.x * 4, y: centre.y + L.y * 4), startRadius: 0, endRadius: 17))
            h.stroke(disc, with: .color(mark.color(0.18 + 0.3 * k.ring * (1 - k.down * 0.5))), lineWidth: 1.0)
            // The brow: a dark feather over each eye.
            var brow = Path()
            let ba = sd > 0 ? -0.5 : -Double.pi + 0.5
            brow.leaf(60 + sd * 3, 40, cos(ba), sin(ba), 14, 2.0, 0.2)
            h.fill(brow, with: .color(dark.color(0.22 * k.ring)))
            let droop = hatch ? motion.by(1, 0.8, 0.92, 0.5) : motion.by(1, 0.0, 0.08, 0)
            eye(h, at: centre, side: sd, rx: 6.6 * plan.eyeSize * k.eye, ry: 6.6 * plan.eyeSize * k.eye, gaze: gaze, droop: droop, lid: face.shifted(-4))
        }
        // The beak: small, hooked, between the eyes, a little open when it wants water.
        var beak = Path.smooth([CGPoint(x: 55.8, y: 53), CGPoint(x: 60, y: 51.8), CGPoint(x: 64.2, y: 53), CGPoint(x: 60, y: 63.6)])
        beak.closeSubpath()
        var bk = h
        bk.translateBy(x: 60, y: 52)
        bk.scaleBy(x: k.beak, y: k.beak)
        bk.translateBy(x: -60, y: -52)
        bk.fill(beak.offsetBy(dx: L.x * 0.5, dy: L.y * 0.5), with: .color(look.rim.color(look.rimAlpha * 0.7)))
        bk.fill(beak, with: .linearGradient(Gradient(colors: [look.lifted(accent, 0.3).color(), accent.color(), accent.shifted(-14, 4).color()]),
                                            startPoint: CGPoint(x: 57, y: 53), endPoint: CGPoint(x: 62, y: 62)))
        bk.fill(Path(ellipseIn: CGRect(x: 58, y: 54, width: 1.8, height: 3)), with: .color(Color.white.opacity(0.45)))
        // A hatchling calls with its beak wide when it is hungry or cold.
        let gape = hatch ? max(wt.bright * 0.6, wt.thirst * 0.9 * (frame.reduceMotion ? 0.7 : 0.55 + 0.45 * sin(time * 9))) : 0
        if gape > 0.08 { bk.fill(Path(ellipseIn: CGRect(x: 57.2, y: 58.4, width: 5.6, height: 1 + 4.4 * gape)), with: .color(Color(red: 0.32, green: 0.1, blue: 0.12, opacity: min(1, gape * 2.2)))) }
        // The egg tooth, which it hatched with.
        if stage <= 3 { bk.fill(Path(ellipseIn: CGRect(x: 58.8, y: 52.2, width: 2.4, height: 1.8)), with: .color(look.lifted(accent, 0.85).color(stage == 3 ? 0.5 : 0.95))) }
        let blush = Ink.lerp(0.18, 0.8, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.7 * wt.thirst)
        for sd in [-1.0, 1] { h.circle(60 + sd * 22, 61, 3, .color(look.tone(0xFF8FA3).color(blush))) }
        owlCap(h)
        // Between the tufts, on the crown.
        hat(h, foot: CGPoint(x: 60, y: 31), scale: 1.12)
    }

    /// The nightcap on a dozing owl, on the head, between the tufts.
    private func owlCap(_ h: GraphicsContext) {
        guard frame.mood < 0.15 || frame.domeLift > 0, stage >= 2 else { return }
        var c = h
        c.translateBy(x: 60, y: 42)
        c.scaleBy(x: 1.15, y: 1.15)
        cap(c, motion.weights)
    }

    // MARK: Hatchling

    /// Just out of the egg: a bare, wet, pinkish blob with a few strands of
    /// down in the lower half of its shell, the eyes sealed (an owl hatches
    /// blind and keeps them shut for days, so every mood but bright is
    /// asleep), the head too big to hold up, huge pale feet, a stub of a wing.
    /// Bright, it lifts its head, cracks its eyes and cheeps; thirsty, it is
    /// cold and trembles; dozing, the head sinks onto it.
    func owlHatchling(_ c: GraphicsContext) {
        let s = CritterGeometry.owlStages(plan)
        let w = motion.weights
        let lit = look.L.x > 0 ? 0 : 1
        let skin = look.tone(0xE3BDB4, dim: 0.6)
        let grey = owlDown
        hatchShell(c, front: false)
        var b = c
        let shiver = frame.reduceMotion ? 0 : sin(time * 38) * 0.5 * w.thirst
        b.translateBy(x: shiver, y: motion.by(2.2, 0.8, 0.3, -1.2))
        let toe = look.accent.mix(skin, 0.5)
        for (i, x) in [46.0, 74.0].enumerated() {
            for dx in [-3.4, 0, 3.4] { b.ellipse(x + dx + (i == 0 ? -4 : 4), 106, 2.9, 2.2, .color(toe.color())) }
        }
        form(b, s.hatchBody[lit], centre: OwlStages.hatchCentre, radius: 26, look.lifted(skin, 0.3), grey.mix(skin, 0.4), skin.shifted(-14), highlight: 0.45)
        hairs(b, s.hatchHairs, dark: grey.shifted(-20), light: look.lifted(grey, 0.5), alpha: 0.4)
        for (i, x) in [44.0, 78.0].enumerated() {
            var wc = b
            wc.translateBy(x: x, y: 92)
            wc.rotate(by: .radians((i == 0 ? 0.8 : -0.8) + (frame.reduceMotion ? 0 : sin(time * 12 + Double(i)) * 0.4 * w.bright) + shiver * 0.4))
            wc.scaleBy(x: 0.4, y: 0.4)
            var wing = Path()
            wing.leaf(0, 0, 0, 1, 42, 12.5, 0.35)
            form(wc, wing, centre: CGPoint(x: 0, y: 20), radius: 22, look.lifted(skin, 0.15), skin, skin.shifted(-12), highlight: 0, core: 0.5, rim: false)
        }
        var h = b
        let tilt = motion.by(0.5, -0.2, 0.13, -0.1) + (frame.reduceMotion ? 0 : sin(time / 2.3 * .pi * 2) * 0.03 * (w.content + w.bright))
        h.translateBy(x: motion.by(6, 0, 0, 0), y: 8 + motion.by(4, -1, 1, -4))
        h.translateBy(x: 60, y: 76)
        h.rotate(by: .radians(tilt))
        h.translateBy(x: -60, y: -76)
        h.translateBy(x: 60, y: 108)
        h.scaleBy(x: 0.9, y: 0.9)
        h.translateBy(x: -60, y: -108)
        perchedHead(h, babyness: 1)
        neckwear(b, at: CGPoint(x: 60, y: 86), span: 16, size: 0.9)
        hatchShell(c, front: true)
    }
}

/// The owl's body, furred from inside on its shadow side, and its breast
/// feathers: built once per plan.
struct BirdGeometry {
    let chevrons: Path
    let bodyFur: [Path]
    /// Painted feathers round the body, the head with its edge broken by
    /// feathers (shadow left [0] or right [1]), a stroke of down in each wing
    /// (left [0], right [1]) and the ruff round the two face discs.
    let hairs: Path
    let headFur: [Path]
    let wingHairs: [Path]
    let ruff: Path

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

        var r = Ink.Random("bird-hairs-\(plan.key)")
        var h = Path()
        for gy in stride(from: 54.0, through: 108, by: 5.0) {
            for gx in stride(from: 34.0, through: 86, by: 5.0) {
                let x = gx + r.between(-1.8, 1.8), y = gy + r.between(-1.8, 1.8)
                let dx = (x - 60) / (27 * bw), dy = (y - 80) / 29
                guard dx * dx + dy * dy < 0.9 else { continue }
                h.fur(x, y, atan2(y - 80, x - 60) + .pi / 2 + r.between(-0.25, 0.25), r.between(4.4, 6.4), 0.75)
            }
        }
        hairs = h

        let hw = 27 * plan.headWidth
        let head = Path(ellipseIn: CGRect(x: 60 - hw, y: 28, width: hw * 2, height: 44))
        func headFurred(_ shadowRight: Double) -> Path {
            FurEdge.furry(head, seed: "bird-head-\(plan.key)-\(shadowRight)", gap: 4.5...8, height: (0.9 * fur)...(1.8 * fur), width: 3.8) { q in
                let side = abs(q.x - 60) / hw
                let shade = 0.35 + 0.65 * Ink.smooth(((q.x - 60) * shadowRight) / 24)
                return (side > 0.5 || q.y > 62 ? 1 : 0.35) * shade
            }
        }
        headFur = [headFurred(-1), headFurred(1)]

        func wingLine(_ s: Double) -> Path {
            var p = Path()
            for (y, n) in [(9.0, 3), (16, 4), (23, 4), (30, 4), (36, 3)] {
                for i in 0..<n {
                    let x = s * (r.between(-1.0, 8.0) + Double(i) * 0.3 + (y - 9) * 0.1)
                    p.fur(x, y + r.between(-1.5, 1.5), .pi / 2 + s * 0.12 + r.between(-0.2, 0.2), r.between(5.2, 7.4), 0.85)
                }
            }
            return p
        }
        wingHairs = [wingLine(-1), wingLine(1)]

        // The ruff: short strokes round each face disc, away from the beak.
        var ru = Path()
        for s in [-1.0, 1] {
            let cx = 60 + s * 11.5, cy = 51.0
            for k in 0..<22 {
                let a = Double(k) / 22 * 2 * .pi
                // Not toward the other eye.
                if cos(a) * s < -0.6 { continue }
                ru.fur(cx + cos(a) * 12.8, cy + sin(a) * 13.2, a, r.between(2.2, 3.4), 0.5)
            }
        }
        ruff = ru
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
