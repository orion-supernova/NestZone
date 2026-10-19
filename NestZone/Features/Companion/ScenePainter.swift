import SwiftUI

/// Everything one frame of the scene needs to know.
struct SceneFrame {
    /// Seconds, for sway and twinkle. Frozen under Reduce Motion.
    var time: Double
    /// 1 at noon, 0 at night, from the clock.
    var day: Double
    var hour: Double
    /// The mood as drawn: it eases from one mood to the next rather than
    /// jumping, which is what makes waking up visible.
    var mood: Double
    /// Growth as drawn, eased the same way.
    var progress: Double
    var wind = 0.6
    var reduceMotion: Bool
    /// The squash and stretch after something lands.
    var bounce = 0.0
    /// The sway after a pet.
    var wobble = 0.0
    /// What is out in the scene right now — only what is available today.
    var layout: SceneLayout
    /// Colours for strings of flags, by the holiday that brought them.
    var southern: Bool
    /// 0…1 while the glass dome lifts off a dozing companion.
    var domeLift = 0.0

    static func dayness(_ hour: Double) -> Double {
        Ink.clamp((cos((hour - 13) / 24 * .pi * 2) + 0.4) / 1.1)
    }
}

/// The scene is drawn in a fixed space 360 points tall, as wide as the card
/// needs, with the soil's surface at `soil` and the floor at `floor`; the
/// view scales it to fit. Fixed coordinates are what let a spot be the same
/// place on every phone.
enum SceneSpace {
    static let height = 360.0
    static let soil = 282.0
    static let floor = 346.0
    static let floorOffset = 94.0
}

struct ScenePainter {
    let frame: SceneFrame
    let width: Double
    let seed: Ink.Random
    private var center: Double { width / 2 }
    private var day: Double { frame.day }
    private var time: Double { frame.reduceMotion ? 0 : frame.time }

    init(frame: SceneFrame, width: Double, seed: String) {
        self.frame = frame
        self.width = width
        self.seed = Ink.Random(seed + "-scene")
    }

    // MARK: Sky

    func sky(_ context: GraphicsContext) {
        let rect = CGRect(x: 0, y: 0, width: width, height: SceneSpace.height)
        // Day and night are two gradients, crossfaded by the clock.
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [SceneInk.nightSkyTop, SceneInk.nightSkyBottom]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: SceneSpace.height)))
        var dayLayer = context
        dayLayer.opacity = day
        dayLayer.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [SceneInk.daySkyTop, SceneInk.daySkyBottom]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: SceneSpace.height)))
        context.glow(center, SceneSpace.height * 0.45, SceneSpace.height * 0.8,
                     Ink.hsl(Ink.lerp(250, 45, day), 70, 75, 0.12 + 0.1 * day))

        let layout = frame.layout
        if layout.sky == DecorItem.dusk.rawValue {
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Ink.color(0xFF8C5A, 0.32), Ink.color(0xFF5A8C, 0.12), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: SceneSpace.height)))
        }
        if layout.sky == DecorItem.fullMoon.rawValue {
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Ink.color(0xFF7828, 0.22), Ink.color(0x782AA0, 0.18), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: SceneSpace.height)))
        }
        // Stars, after dark.
        var r = seed
        for _ in 0..<22 {
            let x = r.next() * width, y = 12 + r.next() * SceneSpace.height * 0.3
            let size = r.between(0.6, 1.6), rate = r.between(0.6, 2), phase = r.next() * 6
            let a = (1 - day) * (0.35 + 0.65 * abs(sin(time * rate + phase)))
            if a > 0.02 { context.circle(x, y, size, .color(Color.white.opacity(a))) }
        }
        sunAndMoon(context)
        if layout.sky == DecorItem.fireworks.rawValue { fireworks(context) }
        // A quiet house: the light goes flat and a cloud sits over the sun.
        let gloom = Ink.clamp((0.5 - frame.mood) / 0.5)
        if gloom > 0 {
            context.fill(Path(rect), with: .color(Ink.color(0x201E30, gloom * 0.5)))
            let (x, y) = sunPosition
            for (dx, dy, rr) in [(-14.0, 4.0, 13.0), (0, -4, 16), (16, 3, 12), (30, 6, 9)] {
                context.circle(x + dx - 6, y + dy + 6, rr, .color(Ink.color(0x9696AA, gloom * 0.55)))
            }
        }
    }

    private var isDaytime: Bool { frame.hour >= 6 && frame.hour < 20 }

    private var sunPosition: (Double, Double) {
        let f = isDaytime ? (frame.hour - 6) / 14 : (frame.hour + 4).truncatingRemainder(dividingBy: 24) / 10
        return (width * (0.12 + 0.76 * f), 62 - sin(f * .pi) * 38)
    }

    private func sunAndMoon(_ context: GraphicsContext) {
        let (x, y) = sunPosition
        let sky = frame.layout.sky
        let big = !isDaytime && (sky == DecorItem.fullMoon.rawValue || sky == DecorItem.harvestMoon.rawValue)
        let radius = isDaytime ? 13.0 : big ? 19 : 11
        let moonColor = sky == DecorItem.fullMoon.rawValue ? Ink.color(0xFFB347) : sky == DecorItem.harvestMoon.rawValue ? Ink.color(0xFFE08A) : SceneInk.moon
        context.glow(x, y, radius * 4, isDaytime ? Ink.color(0xFFD68C, 0.5) : big ? moonColor.opacity(0.45) : Ink.color(0xC8D2FF, 0.35))
        if isDaytime || big {
            context.circle(x, y, radius, .color(isDaytime ? SceneInk.sun : moonColor))
        } else {
            // A crescent: the moon with a bite taken out.
            var c = context
            c.clip(to: Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)))
            var crescent = Path(CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            crescent.addEllipse(in: CGRect(x: x + radius * 0.5 - radius * 0.85, y: y - radius * 0.3 - radius * 0.85, width: radius * 1.7, height: radius * 1.7))
            c.fill(crescent, with: .color(moonColor), style: FillStyle(eoFill: true))
        }
    }

    /// Bursts that bloom and fade, staggered, after dark — and gently by day.
    private func fireworks(_ context: GraphicsContext) {
        var r = seed
        let colors: [UInt32] = [0xFFD45A, 0xFF6B9A, 0x8BD3FF, 0xA7F3D0, 0xC4A7FF]
        for i in 0..<4 {
            let period = 2.6 + Double(i) * 0.4
            let t = (time + Double(i) * 0.9).truncatingRemainder(dividingBy: period) / period
            let x = width * r.between(0.15, 0.85), y = r.between(40, 120)
            let color = Ink.color(colors[i % colors.count])
            let k = frame.reduceMotion ? 0.7 : Ink.ease(t / 0.6)
            let fade = frame.reduceMotion ? 0.8 : 1 - Ink.smooth((t - 0.4) / 0.6)
            let alpha = fade * (0.5 + 0.5 * (1 - day))
            for ray in 0..<12 {
                let a = Double(ray) / 12 * .pi * 2
                let len = 26 * k
                context.circle(x + cos(a) * len, y + sin(a) * len + 6 * t * t, 1.8, .color(color.opacity(alpha)))
                context.circle(x + cos(a) * len * 0.6, y + sin(a) * len * 0.6, 1.1, .color(color.opacity(alpha * 0.7)))
            }
        }
    }

    // MARK: Ground

    func rug(_ context: GraphicsContext) {
        guard frame.layout.ground == DecorItem.kilim.rawValue else { return }
        let y = SceneSpace.soil + 68
        var c = context
        c.clip(to: Path(ellipseIn: CGRect(x: center - 92, y: y - 14, width: 184, height: 28)))
        c.fill(Path(CGRect(x: center - 92, y: y - 14, width: 184, height: 28)), with: .color(SceneInk.rugRed))
        var zig = Path()
        for x in stride(from: -92.0, through: 92, by: 10) {
            let point = CGPoint(x: center + x, y: y + (Int(x / 10).isMultiple(of: 2) ? 5 : -5))
            x == -92 ? zig.move(to: point) : zig.addLine(to: point)
        }
        c.stroke(zig, with: .color(SceneInk.rugCream), lineWidth: 2)
        c.stroke(Path(ellipseIn: CGRect(x: center - 84, y: y - 10, width: 168, height: 20)), with: .color(SceneInk.rugBlue), lineWidth: 3)
    }

    /// The pot, its band and the soil. The soil is dark and moist when cared
    /// for, pale and cracked when it has not been.
    func pot(_ context: GraphicsContext, model: PlantModel) {
        let bx = center, by = SceneSpace.soil, mood = frame.mood
        let skin: PlantModel.HSL = switch frame.layout.pot {
        case DecorItem.terracotta.rawValue?: .init(18, 58, 50)
        case DecorItem.glazedPot.rawValue?: .init(212, 58, 46)
        case DecorItem.goldPot.rawValue?: .init(44, 78, 54)
        default: model.params.pot
        }
        func tint(_ h: Double, _ s: Double, _ l: Double, _ a: Double = 1) -> Color {
            PlantPainter(model: model, frame: frame, pose: .init(segments: [])).tint(h, s, l, a)
        }
        context.ellipse(bx, by + 66, 62, 9, .color(SceneInk.shadow))
        var body = Path()
        body.move(to: CGPoint(x: bx - 48, y: by + 6))
        body.addLine(to: CGPoint(x: bx + 48, y: by + 6))
        body.addQuadCurve(to: CGPoint(x: bx + 34, y: by + 64), control: CGPoint(x: bx + 44, y: by + 50))
        body.addLine(to: CGPoint(x: bx - 34, y: by + 64))
        body.addQuadCurve(to: CGPoint(x: bx - 48, y: by + 6), control: CGPoint(x: bx - 44, y: by + 50))
        context.fill(body, with: .linearGradient(
            Gradient(colors: [tint(skin.h, skin.s, skin.l + 8), tint(skin.h, skin.s, skin.l), tint(skin.h, skin.s, skin.l - 15)]),
            startPoint: CGPoint(x: bx - 48, y: 0), endPoint: CGPoint(x: bx + 48, y: 0)))
        // The band that makes the pot this house's own.
        let band = tint(skin.h, skin.s * 0.7, skin.l + 22, 0.55)
        switch model.params.band {
        case 0:
            for i in -3...3 { context.circle(bx + Double(i) * 12, by + 32, 2.4, .color(band)) }
        case 1:
            var wave = Path()
            for x in stride(from: -42.0, through: 42, by: 2) {
                let point = CGPoint(x: bx + x, y: by + 32 + sin(x / 5) * 3)
                x == -42 ? wave.move(to: point) : wave.addLine(to: point)
            }
            context.stroke(wave, with: .color(band), lineWidth: 2.5)
        default:
            var lines = Path()
            lines.move(to: CGPoint(x: bx - 43, y: by + 28)); lines.addLine(to: CGPoint(x: bx + 43, y: by + 28))
            lines.move(to: CGPoint(x: bx - 42, y: by + 36)); lines.addLine(to: CGPoint(x: bx + 42, y: by + 36))
            context.stroke(lines, with: .color(band), lineWidth: 2.5)
        }
        context.fill(Path(roundedRect: CGRect(x: bx - 54, y: by - 6, width: 108, height: 15), cornerRadius: 7),
                     with: .color(tint(skin.h, skin.s, skin.l + 5)))
        context.fill(Path(CGRect(x: bx - 46, y: by - 4, width: 44, height: 2.5)), with: .color(tint(skin.h, skin.s, skin.l + 20, 0.5)))
        if frame.layout.pot == DecorItem.goldPot.rawValue {
            var shine = context
            shine.translateBy(x: bx - 30, y: by + 24)
            shine.rotate(by: .radians(-0.15))
            shine.ellipse(0, 0, 4, 16, .color(Ink.color(0xFFFADC, 0.55)))
        }
        context.ellipse(bx, by - 1, 46, 5.5, .color(tint(Ink.lerp(32, 24, mood), Ink.lerp(30, 32, mood), Ink.lerp(34, 17, mood))))
        if mood < 0.45 {
            var cracks = Path()
            for (x0, dir) in [(-30.0, 1.0), (-6, -1), (18, 1)] {
                cracks.move(to: CGPoint(x: bx + x0, y: by - 3))
                cracks.addLine(to: CGPoint(x: bx + x0 + 5 * dir, y: by - 0.5))
                cracks.addLine(to: CGPoint(x: bx + x0 + 2 * dir, y: by + 2.5))
            }
            context.stroke(cracks, with: .color(tint(26, 30, 20, Ink.clamp((0.45 - mood) * 3))), lineWidth: 1)
        }
        if frame.layout.weather == DecorItem.snowfall.rawValue {
            context.fill(Path(roundedRect: CGRect(x: bx - 55, y: by - 9, width: 110, height: 7), cornerRadius: 4), with: .color(SceneInk.snow))
            for i in -4...4 { context.circle(bx + Double(i) * 12, by - 6, 3.5 + (i.isMultiple(of: 2) ? 0 : 1), .color(SceneInk.snow)) }
        }
    }

    /// Leaves the plant let go, on the soil and the floor, more the longer the
    /// house is quiet. They go as the plant wakes.
    func fallenLeaves(_ context: GraphicsContext, model: PlantModel) {
        let wilt = PlantModel.wilt(frame.mood)
        let count = Int((Ink.clamp((wilt - 0.15) / 0.85) * Double(model.ground.count)).rounded())
        for leaf in model.ground.prefix(count) {
            var c = context
            c.translateBy(x: center + leaf.x, y: SceneSpace.soil + leaf.y)
            c.rotate(by: .radians(leaf.rotation))
            c.scaleBy(x: 1.4, y: 0.75)
            var shape = Path()
            shape.move(to: CGPoint(x: -5, y: 0))
            shape.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 0, y: -4))
            shape.addQuadCurve(to: CGPoint(x: -5, y: 0), control: CGPoint(x: 0, y: 4))
            c.fill(shape, with: .color(Ink.hsl(leaf.hue, 48, leaf.light)))
        }
    }

    // MARK: Above

    func above(_ context: GraphicsContext) {
        guard let raw = frame.layout.above, let decor = Decor(rawValue: raw) else { return }
        switch decor {
        case let .flags(holiday):
            garland(context, style: .flags, colors: (Holiday.with(holiday)?.colors ?? []).map { Ink.color($0) })
        case .item(.bunting):
            garland(context, style: .flags, colors: [Ink.color(0xFFD27A), Ink.color(0x8BD3FF), Ink.color(0xFF9EC0), Ink.color(0xA7F3D0)])
        case .item(.heartGarland):
            garland(context, style: .hearts, colors: [Ink.color(0xFF6B9A), Ink.color(0xFF9EC0), Ink.color(0xE8476F)])
        case .item(.spookyBunting):
            garland(context, style: .flags, colors: [Ink.color(0xF08A28), Ink.color(0x2B2238), Ink.color(0x8B5CF6)])
        case .item(.papelPicado):
            garland(context, style: .papel, colors: [Ink.color(0xFF4FA3), Ink.color(0xFFB000), Ink.color(0x00B4D8), Ink.color(0x7CC300), Ink.color(0x9B5DE5)])
        case .item(.shamrocks):
            garland(context, style: .shamrocks, colors: [Ink.color(0x22A55B), Ink.color(0x16803F)])
        case .item(.crescentGarland):
            garland(context, style: .crescents, colors: [Ink.color(0xFFD45A), Ink.color(0xF5E6B0)])
        case .item(.redLanterns):
            garland(context, style: .lanterns, colors: [Ink.color(0xD9382F), Ink.color(0xE84A2F)])
        case .item(.kites):
            kites(context)
        case .item(.bats):
            bats(context)
        default:
            break
        }
    }

    enum GarlandStyle { case flags, hearts, papel, shamrocks, crescents, lanterns }

    private func garland(_ context: GraphicsContext, style: GarlandStyle, colors: [Color]) {
        guard !colors.isEmpty else { return }
        let y0 = 20.0, sag = 16.0
        var string = Path()
        string.move(to: CGPoint(x: 10, y: y0))
        string.addQuadCurve(to: CGPoint(x: width - 10, y: y0), control: CGPoint(x: center, y: y0 + sag * 2))
        context.stroke(string, with: .color(Color.white.opacity(0.55)), lineWidth: 1.2)
        let count = max(7, Int(width / 42))
        for i in 1..<count {
            let t = Double(i) / Double(count)
            let x = Ink.lerp(10, width - 10, t)
            let y = (1 - t) * (1 - t) * y0 + 2 * (1 - t) * t * (y0 + sag * 2) + t * t * y0
            var c = context
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(frame.reduceMotion ? 0 : sin(time * 2 + Double(i)) * 0.08))
            let color = colors[i % colors.count]
            switch style {
            case .flags:
                var flag = Path()
                flag.move(to: CGPoint(x: -7, y: 0)); flag.addLine(to: CGPoint(x: 7, y: 0)); flag.addLine(to: CGPoint(x: 0, y: 13))
                flag.closeSubpath()
                c.fill(flag, with: .color(color))
            case .hearts:
                c.heart(0, 5, 9, color)
            case .papel:
                // Cut paper: a rectangle with a scalloped edge and holes.
                c.fill(Path(CGRect(x: -8, y: 0, width: 16, height: 14)), with: .color(color))
                for k in 0..<4 { c.circle(-6 + Double(k) * 4, 14, 2, .color(color)) }
                c.circle(0, 6, 2.2, .color(Color.white.opacity(0.35)))
            case .shamrocks:
                for k in 0..<3 {
                    let a = -Double.pi / 2 + Double(k) * .pi * 2 / 3
                    c.circle(cos(a) * 3.6, 7 + sin(a) * 3.6, 3.4, .color(color))
                }
                c.fill(Path(CGRect(x: -0.6, y: 8, width: 1.2, height: 6)), with: .color(color))
            case .crescents:
                if i.isMultiple(of: 2) {
                    c.star(0, 8, 5, color)
                } else {
                    var moon = Path(ellipseIn: CGRect(x: -6, y: 2, width: 12, height: 12))
                    moon.addEllipse(in: CGRect(x: -2, y: 0, width: 12, height: 12))
                    c.fill(moon, with: .color(color), style: FillStyle(eoFill: true))
                }
            case .lanterns:
                c.fill(Path(CGRect(x: -0.5, y: 0, width: 1, height: 4)), with: .color(Ink.color(0x5A3A1A)))
                c.ellipse(0, 11, 7, 8, .color(color))
                c.fill(Path(CGRect(x: -4, y: 3, width: 8, height: 2)), with: .color(SceneInk.gold))
                c.fill(Path(CGRect(x: -4, y: 18, width: 8, height: 2)), with: .color(SceneInk.gold))
                if day < 0.6 { c.glow(0, 11, 14, Ink.color(0xFFB45A, 0.35 * (1 - day))) }
            }
        }
    }

    private func bats(_ context: GraphicsContext) {
        let ink = SceneInk.bat.opacity(0.75 + 0.2 * day)
        for i in 0..<3 {
            let d = Double(i)
            let x = width * (0.22 + 0.28 * d) + (frame.reduceMotion ? 0 : sin(time * 0.6 + d * 2) * 22)
            let y = 34 + d * 9 + (frame.reduceMotion ? 0 : cos(time * 0.9 + d) * 7)
            let flap = frame.reduceMotion ? 0.6 : 0.35 + 0.65 * abs(sin(time * 11 + d * 1.7))
            var c = context
            c.translateBy(x: x, y: y)
            var bat = Path(ellipseIn: CGRect(x: -3, y: -4, width: 6, height: 8))
            for side in [-1.0, 1] {
                bat.move(to: CGPoint(x: 0, y: -1))
                bat.addQuadCurve(to: CGPoint(x: side * 14, y: -3 * flap), control: CGPoint(x: side * 7, y: -9 * flap))
                bat.addQuadCurve(to: CGPoint(x: side * 8, y: 2), control: CGPoint(x: side * 10, y: 1))
                bat.addQuadCurve(to: CGPoint(x: 0, y: 2), control: CGPoint(x: side * 5, y: 0))
            }
            // A moonlit rim, or a black bat vanishes into a night sky.
            c.stroke(bat, with: .color(SceneInk.batRim.opacity(1 - day * 0.7)), lineWidth: 2.2)
            c.fill(bat, with: .color(ink))
        }
    }

    private func kites(_ context: GraphicsContext) {
        let colors: [UInt32] = [0xF97316, 0xEC4899, 0x22C55E]
        for i in 0..<3 {
            let d = Double(i)
            let x = width * (0.2 + 0.3 * d) + (frame.reduceMotion ? 0 : sin(time * 0.8 + d) * 8)
            let y = 34 + (i == 1 ? -10 : 6) + (frame.reduceMotion ? 0 : cos(time * 1.1 + d * 2) * 5)
            var c = context
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(0.4 * sin(time * 0.7 + d)))
            var kite = Path()
            kite.move(to: CGPoint(x: 0, y: -12)); kite.addLine(to: CGPoint(x: 9, y: 0))
            kite.addLine(to: CGPoint(x: 0, y: 14)); kite.addLine(to: CGPoint(x: -9, y: 0)); kite.closeSubpath()
            c.fill(kite, with: .color(Ink.color(colors[i])))
            var spar = Path()
            spar.move(to: CGPoint(x: 0, y: -12)); spar.addLine(to: CGPoint(x: 0, y: 14))
            spar.move(to: CGPoint(x: -9, y: 0)); spar.addLine(to: CGPoint(x: 9, y: 0))
            c.stroke(spar, with: .color(Color.white.opacity(0.6)), lineWidth: 0.8)
            var tail = Path()
            tail.move(to: CGPoint(x: 0, y: 14))
            tail.addCurve(to: CGPoint(x: 4, y: 40), control1: CGPoint(x: 8, y: 22), control2: CGPoint(x: -6, y: 30))
            c.stroke(tail, with: .color(Color.white.opacity(0.5)), lineWidth: 0.8)
        }
    }

    // MARK: On the tree

    /// Lights, baubles, a star and wish notes, hung on the tree's own tips —
    /// drawn in the tree's coordinates, after it.
    func treeDecor(_ context: GraphicsContext, model: PlantModel, pose: PlantModel.Pose) {
        guard frame.progress > 0.25 else { return }
        let tips = model.tips(pose)
        for raw in frame.layout.tree {
            switch DecorItem(rawValue: raw) {
            case .fairyLights?: fairyLights(context, model: model, pose: pose, tips: tips)
            case .ornaments?: ornaments(context, model: model, pose: pose, tips: tips)
            case .treeStar?: topStar(context, pose: pose)
            case .wishNotes?: wishNotes(context, model: model, pose: pose)
            default: break
            }
        }
    }

    private func fairyLights(_ context: GraphicsContext, model: PlantModel, pose: PlantModel.Pose, tips: [Int]) {
        let points = tips.compactMap { pose.segments[$0] }.map { CGPoint(x: $0.x1, y: $0.y1) }.sorted { $0.x < $1.x }
            .enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
        guard points.count >= 3 else { return }
        var wire = Path()
        wire.move(to: CGPoint(x: points[0].x, y: points[0].y + 4))
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            wire.addQuadCurve(to: CGPoint(x: b.x, y: b.y + 4), control: CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + 10))
        }
        context.stroke(wire, with: .color(Ink.color(0x3C3228, 0.7)), lineWidth: 0.8)
        let night = 1 - day
        let hues = [45.0, 20, 320, 190]
        for (i, point) in points.enumerated() {
            let twinkle = frame.reduceMotion ? 1 : 0.6 + 0.4 * abs(sin(time * 2.2 + Double(i) * 1.3))
            let hue = hues[i % hues.count]
            if night > 0.15 { context.glow(point.x, point.y + 5, 9, Ink.hsl(hue, 100, 70, 0.55 * night * twinkle)) }
            context.ellipse(point.x, point.y + 5, 1.8, 2.6, .color(Ink.hsl(hue, 100, 62 + 20 * twinkle * night)))
        }
    }

    private func ornaments(_ context: GraphicsContext, model: PlantModel, pose: PlantModel.Pose, tips: [Int]) {
        let colors = [SceneInk.red, SceneInk.gold, SceneInk.blue, SceneInk.silver]
        for i in tips where model.branches[i].ornament <= 0.55 {
            guard let s = pose.segments[i] else { continue }
            var thread = Path()
            thread.move(to: CGPoint(x: s.x1, y: s.y1)); thread.addLine(to: CGPoint(x: s.x1, y: s.y1 + 4))
            context.stroke(thread, with: .color(Ink.color(0xE6DCC8, 0.7)), lineWidth: 0.6)
            context.circle(s.x1, s.y1 + 7, 3.6, .color(colors[model.branches[i].ornamentColor % colors.count]))
            context.circle(s.x1 - 1.2, s.y1 + 5.8, 1, .color(Color.white.opacity(0.7)))
        }
    }

    private func topStar(_ context: GraphicsContext, pose: PlantModel.Pose) {
        guard let top = pose.segments.compactMap({ $0 }).min(by: { $0.y1 < $1.y1 }) else { return }
        let x = top.x1, y = top.y1 - 9
        let twinkle = frame.reduceMotion ? 1 : 0.85 + 0.15 * sin(time * 3)
        context.glow(x, y, 22, Ink.color(0xFFDC78, 0.5 * twinkle))
        context.star(x, y, 8, SceneInk.candle)
    }

    private func wishNotes(_ context: GraphicsContext, model: PlantModel, pose: PlantModel.Pose) {
        let papers: [UInt32] = [0xFFF6E0, 0xFFE0EC, 0xE0F0FF, 0xE8FFE0]
        var n = 0
        for (i, branch) in model.branches.enumerated() where branch.depth >= 2 && branch.depth <= 4 && branch.ornament <= 0.42 {
            guard let s = pose.segments[i] else { continue }
            let at = PlantModel.point(s, 0.7)
            var c = context
            c.translateBy(x: at.x, y: at.y)
            c.rotate(by: .radians(frame.reduceMotion ? 0 : sin(time * 1.8 + branch.phase) * 0.18))
            var thread = Path()
            thread.move(to: .zero); thread.addLine(to: CGPoint(x: 0, y: 5))
            c.stroke(thread, with: .color(Ink.color(0xC8283C, 0.85)), lineWidth: 1)
            c.fill(Path(CGRect(x: -4, y: 5, width: 8, height: 11)), with: .color(Ink.color(papers[n % papers.count])))
            var lines = Path()
            lines.move(to: CGPoint(x: -2.4, y: 8.5)); lines.addLine(to: CGPoint(x: 2.4, y: 8.5))
            lines.move(to: CGPoint(x: -2.4, y: 11)); lines.addLine(to: CGPoint(x: 2, y: 11))
            c.stroke(lines, with: .color(Ink.color(0x5A463C, 0.45)), lineWidth: 0.6)
            n += 1
        }
    }

    // MARK: Floor

    func floor(_ context: GraphicsContext) {
        for (raw, x) in [(frame.layout.left, center - SceneSpace.floorOffset), (frame.layout.right, center + SceneSpace.floorOffset)] {
            guard let raw, let item = DecorItem(rawValue: raw) else { continue }
            floorItem(context, item, x: x, y: SceneSpace.floor)
        }
    }

    func floorItem(_ context: GraphicsContext, _ item: DecorItem, x: Double, y: Double) {
        let night = 1 - day
        let flicker = frame.reduceMotion ? 1 : 0.85 + 0.15 * sin(time * 13) * sin(time * 7.3)
        func shadow(_ w: Double) { context.ellipse(x, y + 1, w, 4, .color(SceneInk.shadow)) }
        switch item {
        case .pumpkin:
            if night > 0.2 { context.glow(x, y - 14, 46, SceneInk.glow.opacity(0.35 * night * flicker)) }
            shadow(24)
            for (dx, rx, color) in [(-11.0, 12.0, SceneInk.pumpkinDark), (11, 12, SceneInk.pumpkinDark), (0, 14, SceneInk.pumpkin)] {
                context.ellipse(x + dx, y - 15, rx, 15, .color(color))
            }
            context.fill(Path(roundedRect: CGRect(x: x - 2, y: y - 34, width: 4, height: 7), cornerRadius: 2), with: .color(SceneInk.stem))
            let face = Ink.color(0xFFD25A, 0.6 + 0.4 * max(night, 0.3))
            var eyes = Path()
            eyes.move(to: CGPoint(x: x - 10, y: y - 20)); eyes.addLine(to: CGPoint(x: x - 5, y: y - 20)); eyes.addLine(to: CGPoint(x: x - 7.5, y: y - 25))
            eyes.move(to: CGPoint(x: x + 5, y: y - 20)); eyes.addLine(to: CGPoint(x: x + 10, y: y - 20)); eyes.addLine(to: CGPoint(x: x + 7.5, y: y - 25))
            context.fill(eyes, with: .color(face))
            var mouth = Path()
            mouth.move(to: CGPoint(x: x - 10, y: y - 12))
            for i in 0...5 { mouth.addLine(to: CGPoint(x: x - 10 + Double(i) * 4, y: y - 12 + (i.isMultiple(of: 2) ? 0 : 3))) }
            mouth.addLine(to: CGPoint(x: x + 10, y: y - 9))
            mouth.addQuadCurve(to: CGPoint(x: x - 10, y: y - 9), control: CGPoint(x: x, y: y - 4))
            context.fill(mouth, with: .color(face))
        case .paperLantern, .ramadanLantern:
            let isFanous = item == .ramadanLantern
            var c = context
            c.translateBy(x: x, y: y - 26)
            c.rotate(by: .radians(frame.reduceMotion ? 0 : sin(time * 1.4) * 0.024))
            if night > 0.15 { c.glow(0, 0, 48, Ink.color(isFanous ? 0xFFC864 : 0xFF965A, 0.42 * night)) }
            c.fill(Path(CGRect(x: -10, y: 21, width: 20, height: 5)), with: .color(Ink.color(0x463220)))
            if isFanous {
                // A fanous: brass frame, coloured glass, a dome and a ring.
                var dome = Path()
                dome.move(to: CGPoint(x: -10, y: -14)); dome.addQuadCurve(to: CGPoint(x: 10, y: -14), control: CGPoint(x: 0, y: -30))
                c.fill(dome, with: .color(SceneInk.brass))
                c.stroke(Path(ellipseIn: CGRect(x: -3, y: -33, width: 6, height: 6)), with: .color(SceneInk.brass), lineWidth: 1.5)
                c.fill(Path(roundedRect: CGRect(x: -11, y: -14, width: 22, height: 34), cornerRadius: 3), with: .color(SceneInk.brass))
                for (k, hex) in [(0, UInt32(0x2E7D9A)), (1, 0xC0392B), (2, 0x2E7D9A)] as [(Int, UInt32)] {
                    c.fill(Path(CGRect(x: -9 + Double(k) * 6.4, y: -11, width: 5, height: 28)), with: .color(Ink.color(hex, 0.75)))
                }
                c.ellipse(0, 3, 3, 6, .color(Ink.color(0xFFE6A0, 0.4 + 0.5 * night * flicker)))
            } else {
                c.ellipse(0, 0, 15, 18, .color(SceneInk.lantern))
                for dx in [-8.0, 0, 8] {
                    c.stroke(Path(ellipseIn: CGRect(x: -abs(dx) - 0.5, y: -18, width: abs(dx) * 2 + 1, height: 36)),
                             with: .color(Ink.color(0x9A2A20, 0.7)), lineWidth: 1)
                }
                c.fill(Path(CGRect(x: -7, y: -21, width: 14, height: 4)), with: .color(Ink.color(0x6B4A1F)))
                c.fill(Path(CGRect(x: -7, y: 17, width: 14, height: 4)), with: .color(Ink.color(0x6B4A1F)))
                c.ellipse(-3, -3, 5, 8, .color(Ink.color(0xFFDC96, 0.25 + 0.5 * night)))
            }
        case .giftBox:
            shadow(22)
            context.fill(Path(CGRect(x: x - 17, y: y - 26, width: 34, height: 26)), with: .color(Ink.color(0xC4304A)))
            context.fill(Path(CGRect(x: x - 19, y: y - 31, width: 38, height: 8)), with: .color(Ink.color(0xDA4A62)))
            context.fill(Path(CGRect(x: x - 3, y: y - 31, width: 6, height: 31)), with: .color(SceneInk.gold))
            var c = context
            c.translateBy(x: x - 7, y: y - 35); c.rotate(by: .radians(-0.5)); c.ellipse(0, 0, 7, 4, .color(SceneInk.gold))
            var d = context
            d.translateBy(x: x + 7, y: y - 35); d.rotate(by: .radians(0.5)); d.ellipse(0, 0, 7, 4, .color(SceneInk.gold))
        case .wateringCan:
            shadow(22)
            context.fill(Path(roundedRect: CGRect(x: x - 14, y: y - 24, width: 26, height: 24), cornerRadius: 5), with: .color(SceneInk.can))
            var spout = Path()
            spout.move(to: CGPoint(x: x + 10, y: y - 16)); spout.addLine(to: CGPoint(x: x + 26, y: y - 30))
            context.stroke(spout, with: .color(SceneInk.can), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            var handle = Path()
            handle.addArc(center: CGPoint(x: x - 1, y: y - 27), radius: 10, startAngle: .radians(.pi * 1.05), endAngle: .radians(.pi * 1.95), clockwise: false)
            context.stroke(handle, with: .color(SceneInk.can), lineWidth: 3)
            context.fill(Path(CGRect(x: x - 11, y: y - 20, width: 4, height: 14)), with: .color(Ink.color(0xA8D2DC)))
        case .candyBowl:
            shadow(24)
            let colors = [SceneInk.red, SceneInk.gold, SceneInk.blue, SceneInk.green, SceneInk.pink, Color.white]
            for i in 0..<9 {
                var c = context
                c.translateBy(x: x - 14 + Double(i) * 3.5, y: y - 17 - sin(Double(i) * 1.3) * 3)
                c.rotate(by: .radians(Double(i)))
                c.ellipse(0, 0, 4.5, 3, .color(colors[i % colors.count]))
            }
            var bowl = Path()
            bowl.move(to: CGPoint(x: x - 22, y: y - 16))
            bowl.addQuadCurve(to: CGPoint(x: x + 22, y: y - 16), control: CGPoint(x: x, y: y + 6))
            bowl.closeSubpath()
            context.fill(bowl, with: .color(Ink.color(0xC9DDE6)))
            context.fill(Path(CGRect(x: x - 7, y: y - 3, width: 14, height: 3)), with: .color(Ink.color(0xA9C2CE)))
        case .bouquet, .marigolds:
            shadow(18)
            // A little vase of flowers: mimosa-yellow and pink, or marigolds.
            let petals: [Color] = item == .marigolds ? [Ink.color(0xF59E0B), Ink.color(0xF97316)] : [SceneInk.pink, Ink.color(0xFDE047), Ink.color(0xF472B6)]
            var stems = Path()
            for k in -2...2 {
                stems.move(to: CGPoint(x: x, y: y - 14)); stems.addLine(to: CGPoint(x: x + Double(k) * 6, y: y - 34 - Double(abs(k)) * -3))
            }
            context.stroke(stems, with: .color(SceneInk.stem), lineWidth: 1.4)
            for k in -2...2 {
                let fx = x + Double(k) * 6, fy = y - 36 + Double(abs(k)) * 3
                let color = petals[(k + 2) % petals.count]
                for a in 0..<6 {
                    let angle = Double(a) / 6 * .pi * 2
                    context.circle(fx + cos(angle) * 3, fy + sin(angle) * 3, 2.6, .color(color))
                }
                context.circle(fx, fy, 1.8, .color(Ink.color(0xB45309)))
            }
            context.fill(Path(roundedRect: CGRect(x: x - 9, y: y - 16, width: 18, height: 16), cornerRadius: 4), with: .color(Ink.color(0x93C5FD, 0.85)))
        case .kinara, .menorah:
            shadow(26)
            let isMenorah = item == .menorah
            let count = isMenorah ? 9 : 7
            let spacing = isMenorah ? 5.4 : 6.5
            let candleColors: [Color] = isMenorah ? Array(repeating: Ink.color(0xDBEAFE), count: 9)
                : [Ink.color(0xC0262D), Ink.color(0xC0262D), Ink.color(0xC0262D), Ink.color(0x1F1F1F), Ink.color(0x15803D), Ink.color(0x15803D), Ink.color(0x15803D)]
            context.fill(Path(roundedRect: CGRect(x: x - 26, y: y - 8, width: 52, height: 6), cornerRadius: 2), with: .color(SceneInk.brass))
            context.fill(Path(CGRect(x: x - 2, y: y - 8, width: 4, height: 8)), with: .color(SceneInk.brass))
            for k in 0..<count {
                let cx = x + (Double(k) - Double(count - 1) / 2) * spacing
                let middle = isMenorah && k == 4
                let top = y - (middle ? 34 : 28)
                context.fill(Path(CGRect(x: cx - 1.6, y: top, width: 3.2, height: y - 8 - top)), with: .color(candleColors[k]))
                if night > 0.1 || frame.reduceMotion { context.glow(cx, top - 3, 7, SceneInk.flame.opacity(0.6 * max(night, 0.4))) }
                context.ellipse(cx, top - 3, 1.5, 2.6 * flicker, .color(SceneInk.candle))
            }
        case .eggBasket:
            shadow(24)
            let eggs: [UInt32] = [0xF9A8D4, 0x93C5FD, 0xFDE047, 0x86EFAC, 0xC4B5FD]
            for (k, hex) in eggs.enumerated() {
                context.ellipse(x - 14 + Double(k) * 7, y - 18 - (k.isMultiple(of: 2) ? 2 : 0), 4.5, 6, .color(Ink.color(hex)))
            }
            var basket = Path()
            basket.move(to: CGPoint(x: x - 20, y: y - 16)); basket.addLine(to: CGPoint(x: x + 20, y: y - 16))
            basket.addLine(to: CGPoint(x: x + 15, y: y)); basket.addLine(to: CGPoint(x: x - 15, y: y)); basket.closeSubpath()
            context.fill(basket, with: .color(Ink.color(0xB7834A)))
            var weave = Path()
            for k in 0..<4 { weave.move(to: CGPoint(x: x - 18 + Double(k), y: y - 12 + Double(k) * 3.5)); weave.addLine(to: CGPoint(x: x + 18 - Double(k), y: y - 12 + Double(k) * 3.5)) }
            context.stroke(weave, with: .color(Ink.color(0x8A5A2B)), lineWidth: 1)
            var handle = Path()
            handle.addArc(center: CGPoint(x: x, y: y - 16), radius: 16, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            context.stroke(handle, with: .color(Ink.color(0x8A5A2B)), lineWidth: 2.5)
        case .oilLamps:
            // Diyas, or kandil: three little clay lamps with flames.
            for k in -1...1 {
                let lx = x + Double(k) * 14, ly = y - 2
                if night > 0.1 { context.glow(lx, ly - 10, 14, SceneInk.flame.opacity(0.55 * night * flicker)) }
                var lamp = Path()
                lamp.move(to: CGPoint(x: lx - 7, y: ly - 6)); lamp.addQuadCurve(to: CGPoint(x: lx + 7, y: ly - 6), control: CGPoint(x: lx, y: ly + 4))
                lamp.addLine(to: CGPoint(x: lx + 9, y: ly - 8)); lamp.addLine(to: CGPoint(x: lx - 7, y: ly - 7)); lamp.closeSubpath()
                context.fill(lamp, with: .color(SceneInk.clay))
                context.ellipse(lx + 6, ly - 12, 1.8, 3.6 * flicker, .color(SceneInk.candle))
            }
        case .pomegranates:
            shadow(22)
            for (k, dx) in [-9.0, 9, 0].enumerated() {
                let py = y - 9 - (k == 2 ? 10 : 0)
                context.circle(x + dx, py, 9, .color(Ink.color(0xB91C1C)))
                context.circle(x + dx - 3, py - 3, 2.5, .color(Ink.color(0xF87171, 0.6)))
                var crown = Path()
                crown.move(to: CGPoint(x: x + dx - 3, y: py - 8)); crown.addLine(to: CGPoint(x: x + dx - 1.5, y: py - 12))
                crown.addLine(to: CGPoint(x: x + dx, y: py - 9)); crown.addLine(to: CGPoint(x: x + dx + 1.5, y: py - 12))
                crown.addLine(to: CGPoint(x: x + dx + 3, y: py - 8)); crown.closeSubpath()
                context.fill(crown, with: .color(Ink.color(0x7F1D1D)))
            }
        case .sabzeh:
            shadow(22)
            // Sprouted wheatgrass in a dish, tied with a red ribbon.
            var grass = Path()
            for k in 0..<22 {
                let gx = x - 15 + Double(k) * 1.45
                grass.move(to: CGPoint(x: gx, y: y - 9))
                grass.addQuadCurve(to: CGPoint(x: gx + sin(Double(k)) * 3, y: y - 30 - Double(k % 5) * 2), control: CGPoint(x: gx + 1, y: y - 20))
            }
            context.stroke(grass, with: .color(Ink.color(0x4ADE80)), lineWidth: 1.2)
            context.fill(Path(CGRect(x: x - 16, y: y - 20, width: 32, height: 3)), with: .color(SceneInk.red))
            var dish = Path()
            dish.move(to: CGPoint(x: x - 18, y: y - 10)); dish.addQuadCurve(to: CGPoint(x: x + 18, y: y - 10), control: CGPoint(x: x, y: y + 4))
            dish.closeSubpath()
            context.fill(dish, with: .color(Ink.color(0x60A5FA)))
        default:
            break
        }
    }

    // MARK: Weather and life

    func weather(_ context: GraphicsContext) {
        guard let raw = frame.layout.weather, let item = DecorItem(rawValue: raw) else { return }
        var r = seed
        for i in 0..<46 {
            let x0 = r.next(), y0 = r.next(), speed = r.between(14, 34), size = r.between(1, 2.4), sway = r.between(4, 14), phase = r.next() * 6
            let fall: Double = item == .snowfall ? 1 : item == .confetti ? 1.3 : item == .colourPowder ? -0.4 : 0.6
            let y = frame.reduceMotion ? y0 * SceneSpace.height
                : ((y0 * SceneSpace.height + time * speed * fall).truncatingRemainder(dividingBy: SceneSpace.height + 10) + SceneSpace.height + 10)
                    .truncatingRemainder(dividingBy: SceneSpace.height + 10) - 5
            let x = x0 * width + (frame.reduceMotion ? 0 : sin(time * 0.8 + phase) * sway * (item == .petals ? 1.5 : 1))
            var c = context
            c.translateBy(x: x, y: y)
            switch item {
            case .snowfall:
                c.circle(0, 0, size, .color(Color.white.opacity(0.85)))
            case .petals:
                c.rotate(by: .radians(phase + time))
                c.ellipse(0, 0, 3.6, 2.2, .color(Ink.hsl(335 + size * 6, 80, 80 - size * 4, 0.9)))
            case .confetti:
                c.rotate(by: .radians(phase + time * 2))
                let colors: [UInt32] = [0xF15BB5, 0xFEE440, 0x00BBF9, 0x00F5D4, 0x9B5DE5]
                c.fill(Path(CGRect(x: -2.5, y: -1.2, width: 5, height: 2.4)), with: .color(Ink.color(colors[i % colors.count])))
            case .autumnLeaves:
                guard i.isMultiple(of: 2) else { continue }
                c.rotate(by: .radians(phase + time))
                c.ellipse(0, 0, 4.5, 2.4, .color(Ink.hsl(20 + size * 12, 80, 48, 0.9)))
            case .colourPowder:
                guard i % 3 == 0 else { continue }
                let colors: [UInt32] = [0xF472B6, 0xFACC15, 0x22D3EE, 0xA855F7, 0x4ADE80]
                c.glow(0, 0, 10 + size * 4, Ink.color(colors[i % colors.count], 0.45))
            default:
                break
            }
        }
    }

    /// Fireflies after dark, more of them on a happy evening.
    func fireflies(_ context: GraphicsContext) {
        var r = seed
        for _ in 0..<7 {
            let fx = r.between(-0.8, 0.8), fy = r.between(0.2, 0.9), rx = r.between(8, 22), ry = r.between(5, 14)
            let speed = r.between(0.3, 0.8), phase = r.next() * 6
            let a = (1 - day) * 0.9 * (0.4 + 0.6 * abs(sin(time * 1.7 * speed + phase))) * (0.3 + 0.7 * frame.mood)
            guard a > 0.03 else { continue }
            let x = center + fx * 130 + sin(time * speed + phase) * rx
            let y = SceneSpace.soil - 20 - fy * 190 + cos(time * speed * 1.3 + phase) * ry
            context.glow(x, y, 9, Ink.color(0xFFF096, a))
        }
    }

    /// Bright and daytime: two butterflies around the crown.
    func butterflies(_ context: GraphicsContext, around crown: CGPoint) {
        guard frame.mood > 0.82, day > 0.35 else { return }
        for i in 0..<2 {
            let d = Double(i)
            let x = crown.x + sin(time * 0.55 + d * 2.4) * 70, y = crown.y - 10 + cos(time * 0.8 + d * 1.7) * 36
            let flap = frame.reduceMotion ? 0.7 : 0.25 + 0.75 * abs(sin(time * 13 + d))
            var c = context
            c.translateBy(x: x, y: y)
            let color = i == 0 ? Ink.hsl(320, 85, 75, 0.95) : Ink.hsl(200, 85, 70, 0.95)
            for side in [-1.0, 1] {
                c.ellipse(side * 4 * flap, -2, 4.5 * flap, 5, .color(color))
                c.ellipse(side * 3 * flap, 3, 3 * flap, 3.2, .color(color))
            }
            c.fill(Path(CGRect(x: -0.6, y: -4, width: 1.2, height: 8)), with: .color(Ink.color(0x28191E, 0.9)))
        }
    }

    /// A few glints around a bright crown.
    func glints(_ context: GraphicsContext, in box: CGRect) {
        let k = Ink.smooth((frame.mood - 0.84) / 0.12)
        guard k > 0 else { return }
        var r = seed
        for _ in 0..<6 {
            let x = box.minX + r.next() * box.width, y = box.minY + r.next() * box.height
            let size = r.between(1.2, 2.2), speed = r.between(1.5, 3), phase = r.next() * 6
            let twinkle = frame.reduceMotion ? 0.8 : max(0, sin(time * speed + phase))
            let radius = size * twinkle * k
            if radius > 0.4 { context.glint(x, y, radius, Ink.color(0xFFF0BE, 0.9 * twinkle * k)) }
        }
    }

    /// Thirsty: a little bubble with a drop in it — the one thing on the card
    /// that asks for something.
    func thirstBubble(_ context: GraphicsContext, near box: CGRect) {
        let a = Ink.smooth((0.56 - frame.mood) / 0.12) * (1 - Ink.smooth((0.2 - frame.mood) / 0.06))
        guard a > 0.02 else { return }
        let bob = frame.reduceMotion ? 0 : sin(time * 2.2) * 3
        let x = min(width - 30, box.maxX - 4), y = box.minY + 18 + bob
        var c = context
        c.opacity = a
        c.circle(x - 22, y + 30, 3, .color(Color.white.opacity(0.92)))
        c.circle(x - 14, y + 20, 5, .color(Color.white.opacity(0.92)))
        c.circle(x, y, 16, .color(Color.white.opacity(0.92)))
        var drop = Path()
        drop.move(to: CGPoint(x: x, y: y - 10))
        drop.addCurve(to: CGPoint(x: x + 7, y: y + 3), control1: CGPoint(x: x + 4, y: y - 3), control2: CGPoint(x: x + 7, y: y + 1))
        drop.addArc(center: CGPoint(x: x, y: y + 3), radius: 7, startAngle: .zero, endAngle: .radians(.pi), clockwise: false)
        drop.addCurve(to: CGPoint(x: x, y: y - 10), control1: CGPoint(x: x - 7, y: y + 1), control2: CGPoint(x: x - 4, y: y - 3))
        c.fill(drop, with: .color(SceneInk.water))
        c.ellipse(x - 2.5, y + 2, 1.6, 2.6, .color(Color.white.opacity(0.8)))
    }

    /// Dozing: under a glass dome, kept safe until somebody comes back. On
    /// waking it lifts off and fades.
    func dome(_ context: GraphicsContext, top: Double, alpha: Double) {
        guard alpha > 0.01 else { return }
        let w = 86.0, lift = frame.domeLift * 140
        var c = context
        c.opacity = alpha
        c.translateBy(x: 0, y: -lift)
        let bx = center, by = SceneSpace.soil
        var glass = Path()
        glass.move(to: CGPoint(x: bx - w, y: by + 8))
        glass.addLine(to: CGPoint(x: bx - w, y: top + 60))
        glass.addQuadCurve(to: CGPoint(x: bx, y: top), control: CGPoint(x: bx - w, y: top))
        glass.addQuadCurve(to: CGPoint(x: bx + w, y: top + 60), control: CGPoint(x: bx + w, y: top))
        glass.addLine(to: CGPoint(x: bx + w, y: by + 8))
        glass.closeSubpath()
        c.fill(glass, with: .color(SceneInk.glass))
        c.stroke(glass, with: .color(SceneInk.glassEdge), lineWidth: 1.6)
        var shine = Path()
        shine.move(to: CGPoint(x: bx - w + 12, y: by - 20))
        shine.addLine(to: CGPoint(x: bx - w + 12, y: top + 62))
        shine.addQuadCurve(to: CGPoint(x: bx - 30, y: top + 10), control: CGPoint(x: bx - w + 12, y: top + 16))
        c.stroke(shine, with: .color(Color.white.opacity(0.35)), lineWidth: 3)
        c.circle(bx, top - 5, 6, .color(Ink.color(0xEBF5FF, 0.6)))
        zees(c, x: bx + w - 14, y: top + 40)
    }

    func zees(_ context: GraphicsContext, x: Double, y: Double) {
        for i in 0..<3 {
            let k = frame.reduceMotion ? Double(i) / 3 : (time * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            var c = context
            c.opacity = sin(k * .pi)
            c.draw(Text(verbatim: "z").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Ink.color(0xEBF0FF, 0.8)),
                   at: CGPoint(x: x + k * 16, y: y - k * 34 - Double(i) * 2))
        }
    }
}
