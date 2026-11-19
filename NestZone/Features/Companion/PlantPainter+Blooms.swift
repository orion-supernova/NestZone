import SwiftUI

// The blooms of the tuft and the cane (daisy, tulip, peony, rose), built the
// way the sunflower's head is: petals are cached unit shapes (`LeafShape`)
// moved into place and merged by ring, so a bloom is a handful of fills
// however many petals it has. The light is the sky's: the half of each petal
// that faces it is lighter, the other half a tone deeper, the lit edge of the
// big petals carries a strip of light, and a waxy bloom has a glint.
//
// A bloom is drawn at `at` in a frame turned by `turn` and squashed by
// `squash` (a flower seen a little from the side). `open` is 0 for a bud and
// 1 for a bloom all the way open; each ring of petals comes in at its own
// point on the way (`Ring.appears`), so a bud swells, a cup opens and the
// outer petals unfold last.
extension PlantPainter {
    struct Ring {
        var kind: LeafShape.Kind
        var count: Int
        /// Where the petals start, and how far they reach, as shares of the
        /// bloom's radius.
        var base: Double
        var reach: Double
        /// A petal's width as a share of its length.
        var wide: Double
        /// The openness at which the ring starts to show.
        var appears: Double
        /// Half a step, to stagger it against the ring behind.
        var twist = 0.0
        var bend = 0.0
        var jitter = 0.08
        /// Inner, middle and tip tones.
        var tones: [RGB]
        /// 0 a gradient only; 1 and the lit and shaded halves; 2 and a strip of
        /// light along the lit edge and the veins.
        var detail = 1
    }

    /// Petals in rings about the origin of `c`, the outer ring first.
    func rosette(_ c: GraphicsContext, rings: [Ring], radius R: Double, open: Double, light l: (x: Double, y: Double)) {
        guard let flower = plan.flower else { return }
        let deep = bloom(flower.deep), pale = bloom(flower.pale), mid = bloom(flower.mid)
        for (n, ring) in rings.enumerated() {
            let k = Ink.smooth((open - ring.appears) / 0.28)
            guard k > 0.03 else { continue }
            var petals = Path(), lit = Path(), shade = Path(), rim = Path(), creases = Path(), roll = Path(), fold = Path()
            let reach = R * ring.reach * k
            for i in 0..<ring.count {
                let a = (Double(i) + ring.twist) / Double(ring.count) * .pi * 2 + seed.between(i + 11 * n, -ring.jitter, ring.jitter)
                let len = reach * seed.between(i * 3 + n * 7 + 1, 1 - ring.jitter, 1 + ring.jitter)
                let wide = ring.wide * seed.between(i * 5 + n + 2, 0.9, 1.1)
                let shape = LeafShape.of(ring.kind, bend: ring.bend * seed.between(i * 7 + n * 3 + 4, -1, 1))
                let t = CGAffineTransform(translationX: cos(a) * R * ring.base * k, y: sin(a) * R * ring.base * k)
                    .rotated(by: a).scaledBy(x: len, y: len * wide)
                petals.addPath(shape.outline, transform: t)
                if ring.detail >= 1 {
                    let toward = -sin(a) * l.x + cos(a) * l.y
                    lit.addPath(toward >= 0 ? shape.sideA : shape.sideB, transform: t)
                    shade.addPath(toward >= 0 ? shape.sideB : shape.sideA, transform: t)
                    if ring.detail >= 2 {
                        rim.addPath(toward >= 0 ? shape.rimA : shape.rimB, transform: t)
                        creases.addPath(shape.veins, transform: t)
                        if ring.detail >= 3 {
                            roll.addPath(shape.rollA, transform: t)
                            roll.addPath(shape.rollB, transform: t)
                            fold.addPath(shape.foldA, transform: t)
                            fold.addPath(shape.foldB, transform: t)
                        }
                    }
                }
            }
            let tones = ring.tones.map { $0.color() }
            c.fill(petals, with: .radialGradient(Gradient(colors: tones), center: .zero, startRadius: R * ring.base * k * 0.5, endRadius: R * (ring.base + ring.reach) * k))
            if ring.detail >= 1 {
                // A rolled petal is shaded by its curl, not split down the middle.
                let soft = ring.detail >= 3 ? 0.4 : 1.0
                c.fill(shade, with: .color(deep.shifted(-10).color(0.3 * soft)))
                c.fill(lit, with: .color(pale.mix(glow, 0.3 * (1 - night)).color(0.3 * soft)))
            }
            if ring.detail >= 2 {
                c.fill(rim, with: .color(pale.mix(rimTone, 0.35).color(0.4 + 0.2 * dusk)))
                c.fill(creases, with: .color(deep.color(0.26)))
            }
            if ring.detail >= 3 {
                // A rolled margin: the lip turned back catches the light, and a
                // line of shade lies where it leaves the petal.
                c.fill(fold, with: .color(deep.shifted(-12).color(0.34)))
                c.fill(roll, with: .color(pale.mix(mid, 0.2).mix(rimTone, 0.2 * (1 - night)).color(0.72)))
            }
        }
    }

    /// A frame for a bloom: moved to `at`, turned, squashed; and the light in it.
    private func frame(_ c: GraphicsContext, at: CGPoint, turn: Double, squash: Double) -> (GraphicsContext, (x: Double, y: Double)) {
        var h = c
        h.translateBy(x: at.x, y: at.y)
        h.rotate(by: .radians(turn))
        h.scaleBy(x: 1, y: squash)
        // Squashed, the light's up and down is as squashed as the flower.
        let lx = L.x * cos(turn) + L.y * sin(turn), ly = -L.x * sin(turn) + L.y * cos(turn)
        return (h, (lx, ly / max(0.3, squash)))
    }

    // MARK: Daisy

    /// A daisy: a green cup of sepals, two rings of long white ray petals (the
    /// outer one blushing at the tip), and a golden disc of florets. A bud
    /// is the petals folded up in the green.
    func daisyBloom(_ c: GraphicsContext, at: CGPoint, radius R: Double, open: Double, turn: Double, squash: Double) {
        guard let flower = plan.flower else { return }
        let (h, l) = frame(c, at: at, turn: turn, squash: squash)
        let mid = bloom(flower.mid), pale = bloom(flower.pale), tint = bloom(flower.tint), gold = bloom(flower.heart), amber = bloom(flower.anther)
        if open < 0.3 {
            // Folded: white tips fanning out of a green cup.
            let k = 0.55 + 0.45 * open / 0.3
            var tips = Path(), cup = Path()
            for i in 0..<7 {
                let a = -Double.pi / 2 + (Double(i) / 6 - 0.5) * 1.1
                tips.leaf(0, 3, cos(a), sin(a), R * 1.0 * k, R * 0.2, 0.6)
            }
            for s in [-1.0, 0, 1] { cup.leaf(s * R * 0.2, 4, sin(s * 0.6), -cos(s * 0.6), R * 0.8 * k, R * 0.34, 0.1) }
            h.fill(tips, with: .linearGradient(Gradient(colors: [mid.color(), tint.mix(mid, 0.5).color()]), startPoint: CGPoint(x: 0, y: 3), endPoint: CGPoint(x: 0, y: -R * k)))
            h.fill(cup, with: .color(ramp[3].color()))
            return
        }
        var sepals = Path()
        for i in 0..<10 {
            let a = Double(i) / 10 * .pi * 2 + 0.2
            sepals.leaf(0, 0, cos(a), sin(a), R * 0.78, R * 0.18, 0)
        }
        h.fill(sepals, with: .color(ramp[2].color()))
        let rings = [
            Ring(kind: .ray, count: 17, base: 0.28, reach: 1.08, wide: 0.92, appears: 0.25, bend: 0.28 + 0.5 * wilt, jitter: 0.07,
                 tones: [pale.mix(gold, 0.25), mid, mid.mix(tint, 0.55)], detail: 2),
            Ring(kind: .ray, count: 15, base: 0.28, reach: 0.86, wide: 0.95, appears: 0.34, twist: 0.5, bend: 0.2 + 0.4 * wilt, jitter: 0.07,
                 tones: [mid.mix(gold, 0.2), pale, mid.mix(tint, 0.2)], detail: 1),
        ]
        rosette(h, rings: rings, radius: R, open: open, light: l)
        // The disc: a golden dome of florets, with a ring of orange.
        let dk = Ink.smooth((open - 0.3) / 0.3)
        var d = h
        d.scaleBy(x: R * 0.42 * dk, y: R * 0.42 * dk)
        d.fill(Path(ellipseIn: CGRect(x: -1.06, y: -1.06, width: 2.12, height: 2.12)),
               with: .radialGradient(Gradient(colors: [gold.shifted(8).color(), gold.color(), amber.color()]),
                                     center: CGPoint(x: l.x * -0.3, y: l.y * -0.3), startRadius: 0, endRadius: 1.2))
        d.fill(DiscArt.florets, with: .color(amber.shifted(-6).color(0.9)))
        d.fill(DiscArt.bodies, with: .color(amber.mix(gold, 0.3).color(0.85)))
        d.translateBy(x: l.x * 0.04, y: l.y * 0.04)
        d.fill(DiscArt.glints, with: .color(gold.shifted(14).color(0.8)))
    }

    // MARK: Tulip

    /// The flames of a broken (Rembrandt) tulip in a tepal's own units: thin
    /// lenses from near the base up towards the tip, one down the middle and two
    /// either side that fall short, built once.
    static let tepalFlames: Path = {
        var p = Path()
        for (v, to, w) in [(0.0, 0.9, 0.05), (0.13, 0.7, 0.04), (-0.13, 0.7, 0.04), (0.24, 0.5, 0.03), (-0.24, 0.5, 0.03)] {
            p.lens(from: CGPoint(x: 0.12, y: v * 0.7), to: CGPoint(x: to, y: v * 0.45), width: w)
        }
        return p
    }()

    /// A tulip: a cup of six waxy tepals (the two behind, the three in front
    /// that overlap), deep at the base and flamed with yellow, closed in a bud
    /// and opening to show a dark heart and its stamens. The cup stands along
    /// the stem and `turn` nods it.
    func tulipBloom(_ c: GraphicsContext, at: CGPoint, size S: Double, open: Double, turn: Double) {
        guard let flower = plan.flower else { return }
        let (h, l) = frame(c, at: at, turn: turn, squash: 1)
        let deep = bloom(flower.deep), mid = bloom(flower.mid), pale = bloom(flower.pale), flame = bloom(flower.tint), heart = bloom(flower.heart, dim: 0.4)
        let k = (0.55 + 0.45 * Ink.smooth(open / 0.4)) * S
        let spread = 0.05 + 0.5 * Ink.smooth((open - 0.3) / 0.6)
        let len = 21 * k
        func tepal(_ lean: Double, _ dx: Double, _ scale: Double, bend: Double = 0) -> (path: Path, t: CGAffineTransform) {
            let t = CGAffineTransform(translationX: dx * k, y: 0).rotated(by: -.pi / 2 + lean).scaledBy(x: len * scale, y: len * scale * 0.62)
            var path = Path()
            path.addPath(LeafShape.of(.tepal, bend: bend).outline, transform: t)
            return (path, t)
        }
        // The two behind, a shade deeper.
        var back = Path()
        for s in [-1.0, 1] { back.addPath(tepal(s * (spread * 0.9 + 0.08), s * 1.5, 0.96, bend: s * -0.2 * open).path) }
        h.fill(back, with: .color(deep.shifted(-4).color()))
        // The dark heart and stamens, once it opens.
        let heartK = Ink.smooth((open - 0.45) / 0.3)
        if heartK > 0.02 {
            var stamens = Path(), anthers = Path()
            for i in 0..<6 {
                let a = -Double.pi / 2 + (Double(i) / 5 - 0.5) * (0.5 + spread)
                let tip = CGPoint(x: cos(a) * 12 * k, y: sin(a) * 12 * k)
                stamens.spike(from: CGPoint(x: 0, y: -1), to: tip, width: 0.8)
                anthers.addEllipse(in: CGRect(x: tip.x - 1, y: tip.y - 1.5, width: 2, height: 3))
            }
            h.fill(Path(ellipseIn: CGRect(x: -5 * k, y: -9 * k, width: 10 * k, height: 12 * k)), with: .color(heart.color(heartK)))
            h.fill(stamens, with: .color(bloom(0xCFC58A).color(0.8 * heartK)))
            h.fill(anthers, with: .color(bloom(flower.anther).color(heartK)))
        }
        // The three in front: left and right, then the middle one over them.
        var front = Path(), lit = Path(), shade = Path(), glints = Path(), veins = Path(), flames = Path()
        for (lean, dx, scale, bend) in [(-1.0, -2.2, 1.0, -0.22), (1.0, 2.2, 1.0, 0.22), (0.0, 0.0, 1.04, 0.0)] {
            let (path, t) = tepal(lean * (spread + 0.06), dx, scale, bend: bend * open)
            let shape = LeafShape.of(.tepal, bend: bend * open)
            front.addPath(path)
            let a = -Double.pi / 2 + lean * (spread + 0.06)
            let toward = -sin(a) * l.x + cos(a) * l.y
            lit.addPath(toward >= 0 ? shape.sideA : shape.sideB, transform: t)
            shade.addPath(toward >= 0 ? shape.sideB : shape.sideA, transform: t)
            if toward > -0.2 || lean == 0 { glints.addPath(toward >= 0 ? shape.glossA : shape.glossB, transform: t) }
            veins.addPath(shape.veins, transform: t)
            if flower.streak != 0 { flames.addPath(Self.tepalFlames, transform: t) }
        }
        h.fill(front, with: .linearGradient(
            Gradient(stops: [.init(color: flame.mix(mid, 0.2).color(), location: 0), .init(color: deep.color(), location: 0.22),
                             .init(color: mid.color(), location: 0.62), .init(color: mid.mix(pale, 0.35).color(), location: 1)]),
            startPoint: CGPoint(x: 0, y: 2), endPoint: CGPoint(x: 0, y: -len)))
        // A Rembrandt's flames: feathered streaks of the second colour running up each tepal.
        if flower.streak != 0 { h.fill(flames, with: .color(bloom(flower.streak).color(0.9))) }
        h.fill(shade, with: .color(deep.shifted(-10).color(0.3)))
        h.fill(lit, with: .color(pale.mix(glow, 0.3 * (1 - night)).color(0.3)))
        h.fill(veins, with: .color(deep.shifted(-6).color(0.22)))
        // Waxy: a long glint on the side that faces the light.
        h.fill(glints, with: .color(Color.white.opacity(0.46 * (1 - 0.4 * night))))
    }

    // MARK: Peony

    /// A peony: a big ruffled bloom of broad petals in four rings, pale at the
    /// edge and deeper towards the heart, a crown of gold stamens once it is
    /// fully open; before that a round green bud with a pink slit, then a pink
    /// ball as the first rings loosen.
    func peonyBloom(_ c: GraphicsContext, at: CGPoint, radius R: Double, open: Double, turn: Double) {
        guard let flower = plan.flower else { return }
        let (h, l) = frame(c, at: at, turn: turn, squash: 0.84)
        let deep = bloom(flower.deep), mid = bloom(flower.mid), pale = bloom(flower.pale), tint = bloom(flower.tint)
        let stamens = bloom(flower.anther)
        // The bud: a green ball, its sepals, and the pink that shows through.
        if open < 0.2 {
            let k = (0.34 + 0.66 * open / 0.2) * R * 0.5
            h.fill(Path(ellipseIn: CGRect(x: -k, y: -k * 1.02, width: k * 2, height: k * 2.04)), with: .radialGradient(
                Gradient(colors: [ramp[4].mix(glow, 0.2 * (1 - night)).color(), ramp[3].color(), ramp[1].color()]),
                center: CGPoint(x: l.x * -k * 0.3, y: l.y * -k * 0.3), startRadius: 0, endRadius: k * 1.3))
            var slit = Path(), wrap = Path()
            slit.lens(from: CGPoint(x: -k * 0.5, y: -k * 0.5), to: CGPoint(x: k * 0.4, y: -k * 0.75), width: k * 0.5 * (open / 0.2 + 0.4))
            for s in [-1.0, 1] { wrap.leaf(s * k * 0.1, k * 0.9, s * 0.5, -1, k * 1.5, k * 0.5, 0.2) }
            h.fill(slit, with: .color(tint.mix(deep, 0.3).color(0.85)))
            h.fill(wrap, with: .color(ramp[2].color(0.9)))
            return
        }
        let rings = [
            Ring(kind: .petal, count: 9, base: 0.34, reach: 0.74, wide: 1.0, appears: 0.5, bend: 0.2, jitter: 0.09,
                 tones: [deep.mix(mid, 0.5), mid, pale.mix(mid, 0.3)], detail: 2),
            Ring(kind: .petal, count: 8, base: 0.26, reach: 0.62, wide: 0.98, appears: 0.38, twist: 0.5, bend: 0.26, jitter: 0.1,
                 tones: [deep.mix(tint, 0.2), deep.mix(mid, 0.6), mid.mix(pale, 0.2)], detail: 1),
            Ring(kind: .petal, count: 7, base: 0.18, reach: 0.48, wide: 0.95, appears: 0.28, bend: 0.3, jitter: 0.12,
                 tones: [deep.mix(tint, 0.4), deep.mix(mid, 0.4), mid], detail: 0),
            Ring(kind: .petal, count: 6, base: 0.08, reach: 0.34, wide: 0.9, appears: 0.2, twist: 0.4, bend: 0.34, jitter: 0.12,
                 tones: [tint.mix(deep, 0.4), deep, deep.mix(mid, 0.5)], detail: 0),
        ]
        rosette(h, rings: rings, radius: R, open: open, light: l)
        // The crown of stamens in the heart.
        let sk = Ink.smooth((open - 0.78) / 0.2)
        if sk > 0.02 {
            var filaments = Path(), anthers = Path()
            for i in 0..<30 {
                let a = Double(i) * 2.399963, r = R * 0.2 * sk * seed.between(i, 0.45, 1.0)
                let tip = CGPoint(x: cos(a) * r, y: sin(a) * r * 0.85 - R * 0.03 * sk)
                filaments.spike(from: .zero, to: tip, width: 0.9)
                anthers.addEllipse(in: CGRect(x: tip.x - 1.1, y: tip.y - 1.1, width: 2.2, height: 2.2))
            }
            h.fill(filaments, with: .color(stamens.shifted(-8).color(0.9)))
            h.fill(anthers, with: .color(stamens.shifted(6).color(sk)))
        }
    }

    // MARK: Rose

    /// A rose: a spiral of satin petals in rings, the outer ones with a rolled,
    /// lighter edge, the heart deep and wound; or a pointed bud wrapped in its
    /// sepals, then a half-open cup.
    func roseBloom(_ c: GraphicsContext, at: CGPoint, radius R: Double, open: Double, turn: Double) {
        guard let flower = plan.flower else { return }
        let (h, l) = frame(c, at: at, turn: turn, squash: 0.86)
        let deep = bloom(flower.deep), mid = bloom(flower.mid), pale = bloom(flower.pale), heart = bloom(flower.heart)
        if open < 0.38 {
            // A bud: three petals wrapped round each other, sepals under and over.
            let k = (0.55 + 0.45 * open / 0.38) * R
            let shape = LeafShape.of(.tepal)
            var wrapA = Path(), wrapB = Path(), glints = Path()
            for (i, lean) in [-0.2, 0.2, 0.0].enumerated() {
                let t = CGAffineTransform(translationX: lean * 8, y: 0).rotated(by: -.pi / 2 + lean * (0.3 + open)).scaledBy(x: k * 1.55, y: k * 0.92)
                if i < 2 { wrapA.addPath(shape.outline, transform: t) } else {
                    wrapB.addPath(shape.outline, transform: t)
                    glints.addPath(L.x >= 0 ? shape.glossA : shape.glossB, transform: t)
                }
            }
            var sepals = Path()
            for s in [-1.0, 1] { sepals.leaf(s * 1.5, 1, s * 0.9, -0.5, k * 1.1, k * 0.2, 0) }
            sepals.leaf(0, 1, 0, -1, k * 0.8, k * 0.18, 0)
            h.fill(wrapA, with: .color(deep.color()))
            h.fill(wrapB, with: .linearGradient(Gradient(colors: [deep.color(), mid.color(), mid.mix(pale, 0.3).color()]),
                                                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: -k * 1.5)))
            h.fill(glints, with: .color(Color.white.opacity(0.32)))
            h.fill(sepals, with: .color(ramp[2].color()))
            return
        }
        // Sepals under a bloom, once it spreads over them.
        let spreadK = Ink.smooth((open - 0.5) / 0.2)
        if spreadK > 0.02 {
            var sepals = Path()
            for i in 0..<5 {
                let a = Double(i) / 5 * .pi * 2 + 0.3
                sepals.leaf(0, 0, cos(a), sin(a), R * 0.95 * spreadK, R * 0.14, 0)
            }
            h.fill(sepals, with: .color(ramp[2].color()))
        }
        // Seen from a little above: the outer petals reflex, spreading wide with
        // their edges rolled back; a bowl of upright ones; the cup, dark where
        // it is deep; and tight petals wound round the heart.
        let rings = [
            Ring(kind: .rose, count: 5, base: 0.3, reach: 1.0, wide: 1.12, appears: 0.55, bend: 0.55, jitter: 0.06,
                 tones: [deep.mix(mid, 0.45), mid, mid.mix(pale, 0.5)], detail: 3),
            Ring(kind: .rose, count: 5, base: 0.16, reach: 0.84, wide: 1.06, appears: 0.42, twist: 0.5, bend: 0.34, jitter: 0.07,
                 tones: [deep, deep.mix(mid, 0.55), mid.mix(pale, 0.2)], detail: 3),
        ]
        rosette(h, rings: rings, radius: R, open: open, light: l)
        let wk = Ink.smooth((open - 0.34) / 0.4)
        // The cup: the dark of looking down into it.
        h.fill(Path(ellipseIn: CGRect(x: -R * 0.7 * wk, y: -R * 0.72 * wk, width: R * 1.4 * wk, height: R * 1.3 * wk)), with: .radialGradient(
            Gradient(colors: [heart.shifted(-12).color(0.95), deep.shifted(-6).color(0.8), deep.color(0)]),
            center: CGPoint(x: 0, y: -R * 0.06 * wk), startRadius: R * 0.1 * wk, endRadius: R * 0.7 * wk))
        // The wound heart: petals wrapped round one another, each a disc whose
        // lit edge shows as a crescent where the next one starts.
        let tones = [mid.mix(pale, 0.2), mid, mid.mix(deep, 0.4), deep.mix(mid, 0.3), deep, heart]
        for i in 0..<5 {
            let t = Double(i)
            let a = 0.6 + t * 2.4
            let r = R * (0.62 - 0.105 * t) * wk
            guard r > 0.8 else { continue }
            let c = CGPoint(x: cos(a) * R * 0.07 * (1 - 0.15 * t), y: sin(a) * R * 0.05 - R * 0.06 - R * 0.015 * t)
            var disc = Path(), body = Path()
            disc.oval(c.x, c.y, r, r * 0.9)
            let back = CGPoint(x: -l.x * r * 0.13, y: -l.y * r * 0.13)
            body.oval(c.x + back.x, c.y + back.y, r * 0.93, r * 0.84)
            h.fill(disc, with: .color(pale.mix(mid, 0.3 + 0.1 * t).mix(rimTone, 0.15 * (1 - night)).color(0.9)))
            let top = tones[i], low = tones[min(5, i + 1)]
            h.fill(body, with: .linearGradient(Gradient(colors: [top.color(), low.color()]),
                                               startPoint: CGPoint(x: c.x + l.x * r, y: c.y + l.y * r), endPoint: CGPoint(x: c.x - l.x * r, y: c.y - l.y * r)))
        }
    }
}
