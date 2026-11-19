import SwiftUI

/// The three backdrops: a window with a sill, a balcony, a rooftop. Each is the
/// room or the place the companion stands in, drawn in front of the sky and
/// behind the companion, with the sky left showing where there is sky to see.
///
/// Nothing in a backdrop moves, so none of it is drawn per frame: it is a
/// `SceneryLayer`, one picture drawn again only when the light changes (the
/// hour's brightness to a fiftieth, the sun's side to a tenth).
extension ScenePainter {
    typealias RGB = Canopy.RGB

    func backdrop(_ context: GraphicsContext) {
        switch scenery {
        case .windowsill?: windowsill(context)
        case .balcony?: balcony(context)
        case .starryRooftop?: rooftop(context)
        default: break
        }
    }

    /// A backdrop colour as the hour leaves it: dimmer and cooler by night,
    /// and warmed a little when the sun is low.
    func hue(_ hex: UInt32, dim: Double = 0.9, warm: Double = 0.22) -> RGB {
        lamp.tone(hex, dim: dim).mix(RGB(0xFFA866), lamp.dusk * warm)
    }

    /// A vertical gradient between two colours, top to bottom of `rect`.
    func vertical(_ top: RGB, _ bottom: RGB, in rect: CGRect) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [top.color(), bottom.color()]), startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY))
    }

    /// A gradient along the light across `rect`: lit end, middle, shade end.
    func alongLight(_ light: RGB, _ mid: RGB, _ dark: RGB, in rect: CGRect) -> GraphicsContext.Shading {
        let L = lamp.L, r = max(rect.width, rect.height) / 2
        return .linearGradient(
            Gradient(stops: [.init(color: light.color(), location: 0), .init(color: mid.color(), location: 0.5), .init(color: dark.color(), location: 1)]),
            startPoint: CGPoint(x: rect.midX + L.x * r, y: rect.midY + L.y * r), endPoint: CGPoint(x: rect.midX - L.x * r, y: rect.midY - L.y * r))
    }

    // MARK: Windowsill

    /// A sash window seen from inside: plastered wall, a white frame with a
    /// transom bar and two mullions, curtains tied back at both sides, and the
    /// sill the companion stands on, with a stack of books and a candle at its
    /// ends where the card is wide enough to have ends.
    private func windowsill(_ context: GraphicsContext) {
        let W = width, c = center, L = lamp.L
        let night = 1 - day
        let rim = lamp.rim.color(lamp.rimAlpha)
        let outer = CGRect(x: 22, y: 10, width: W - 44, height: 324)
        let glass = outer.insetBy(dx: 12, dy: 12)
        let a = max(64, min(W * 0.22, 122)), barY = 96.0
        let xs: [Double] = [glass.minX, c - a - 4, c - a + 4, c + a - 4, c + a + 4, glass.maxX]
        let rows: [(Double, Double)] = [(glass.minY, barY - 4), (barY + 4, glass.maxY)]
        var panes: [CGRect] = []
        for (y0, y1) in rows {
            for i in [0, 2, 4] { panes.append(CGRect(x: xs[i], y: y0, width: xs[i + 1] - xs[i], height: y1 - y0)) }
        }
        var holes = Path()
        for pane in panes { holes.addRect(pane) }

        // The wall: plaster, warmer at the top, with a scatter of faint dabs for the trowel.
        var wall = Path(CGRect(x: 0, y: 0, width: W, height: SceneSpace.height))
        wall.addPath(holes)
        let wallRect = CGRect(x: 0, y: 0, width: W, height: SceneSpace.height)
        context.fill(wall, with: vertical(hue(0xEBDAC3), hue(0xDCC6A8), in: wallRect), style: FillStyle(eoFill: true))
        var plaster = context
        plaster.clip(to: wall, style: FillStyle(eoFill: true))
        var r = seed
        var dabsLight = Path(), dabsDark = Path()
        for _ in 0..<90 {
            let x = r.next() * W, y = r.next() * SceneSpace.height, rx = r.between(5, 15), ry = r.between(2.5, 6)
            if r.next() < 0.5 { dabsLight.addEllipse(in: CGRect(x: x, y: y, width: rx, height: ry)) } else { dabsDark.addEllipse(in: CGRect(x: x, y: y, width: rx, height: ry)) }
        }
        plaster.fill(dabsLight, with: .color(Color.white.opacity(0.1 + 0.05 * day)))
        plaster.fill(dabsDark, with: .color(Color.black.opacity(0.045)))
        // The room's side of the light: a wash on the wall nearest the sun.
        plaster.fill(Path(wallRect), with: .linearGradient(
            Gradient(colors: [lamp.rim.color(0.18 * day), .clear]),
            startPoint: CGPoint(x: L.x > 0 ? W : 0, y: 0), endPoint: CGPoint(x: c, y: 0)))

        // The frame: a ring, then the bars across it, painted white.
        var ring = Path(outer)
        ring.addRect(glass)
        let paint = alongLight(hue(0xFBF8F2), hue(0xEDE6DA), hue(0xCDC2B2), in: outer)
        context.fill(ring.offsetBy(dx: 1.5, dy: 2), with: .color(Color.black.opacity(0.14)), style: FillStyle(eoFill: true))
        context.fill(ring, with: paint, style: FillStyle(eoFill: true))
        var bars = Path()
        bars.addRect(CGRect(x: xs[1], y: glass.minY, width: 8, height: glass.height))
        bars.addRect(CGRect(x: xs[3], y: glass.minY, width: 8, height: glass.height))
        bars.addRect(CGRect(x: glass.minX, y: barY - 4, width: glass.width, height: 8))
        context.fill(bars, with: paint)
        // Bevels: a lit edge on the sunward side of every pane, a shadow on the other.
        var litEdges = Path(), shadeEdges = Path()
        for pane in panes {
            let side: Double = L.x > 0 ? pane.maxX : pane.minX
            litEdges.addRect(CGRect(x: side - (L.x > 0 ? 1.4 : 0), y: pane.minY, width: 1.4, height: pane.height))
            litEdges.addRect(CGRect(x: pane.minX, y: pane.minY, width: pane.width, height: 1.4))
            let far: Double = L.x > 0 ? pane.minX : pane.maxX
            shadeEdges.addRect(CGRect(x: far - (L.x > 0 ? 0 : 2.2), y: pane.minY, width: 2.2, height: pane.height))
            shadeEdges.addRect(CGRect(x: pane.minX, y: pane.maxY - 2.2, width: pane.width, height: 2.2))
        }
        context.fill(shadeEdges, with: .color(hue(0x8E7F6C).color(0.3)))
        context.fill(litEdges, with: .color(Color.white.opacity(0.55)))
        context.stroke(Path(outer), with: .color(hue(0x8E7F6C).color(0.35)), lineWidth: 1)
        if lamp.rimAlpha > 0.03 { context.stroke(Path { $0.move(to: CGPoint(x: outer.minX + 1, y: outer.minY + 0.7)); $0.addLine(to: CGPoint(x: outer.maxX - 1, y: outer.minY + 0.7)) }, with: .color(rim), lineWidth: 1.2) }

        // The glass: a faint reflection across every pane, and a line of cold at the foot.
        var reflection = context
        reflection.clip(to: holes)
        var sheen = Path()
        for (x, w) in [(0.18, 34.0), (0.3, 12.0), (0.62, 26.0)] {
            let x0 = W * x
            sheen.move(to: CGPoint(x: x0, y: 0)); sheen.addLine(to: CGPoint(x: x0 + w, y: 0))
            sheen.addLine(to: CGPoint(x: x0 + w - 150, y: 340)); sheen.addLine(to: CGPoint(x: x0 - 150, y: 340)); sheen.closeSubpath()
        }
        reflection.fill(sheen, with: .color(Color.white.opacity(0.05 + 0.05 * day)))
        reflection.fill(Path(CGRect(x: 0, y: 296, width: W, height: 40)), with: .linearGradient(
            Gradient(colors: [.clear, Color.white.opacity(0.07 + 0.05 * night)]), startPoint: CGPoint(x: 0, y: 296), endPoint: CGPoint(x: 0, y: 332)))
        // The frame's shadow falls a little way into the room on the shaded side.
        reflection.fill(Path(CGRect(x: L.x > 0 ? glass.minX : glass.maxX - 6, y: glass.minY, width: 6, height: glass.height)), with: .linearGradient(
            Gradient(colors: [Color.black.opacity(0.1), .clear]), startPoint: CGPoint(x: L.x > 0 ? glass.minX : glass.maxX, y: 0), endPoint: CGPoint(x: L.x > 0 ? glass.minX + 6 : glass.maxX - 6, y: 0)))

        // Curtains, tied back, the far one lit from the other side.
        let drape = hue(0xA9C3AE, dim: 0.85)
        curtain(context, in: lamp, tone: drape)
        var mirrored = context
        mirrored.translateBy(x: W, y: 0)
        mirrored.scaleBy(x: -1, y: 1)
        curtain(mirrored, in: lamp.lit(from: CGPoint(x: -L.x, y: L.y)), tone: drape)
        // The rod, brass, with a finial at each end.
        let brass = hue(0xC9A24A, dim: 0.85)
        context.stroke(Path { $0.move(to: CGPoint(x: 8, y: 6)); $0.addLine(to: CGPoint(x: W - 8, y: 6)) }, with: .color(brass.shifted(-12).color()), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        context.stroke(Path { $0.move(to: CGPoint(x: 8, y: 5)); $0.addLine(to: CGPoint(x: W - 8, y: 5)) }, with: .color(brass.color()), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        for x in [6.0, W - 6] {
            WearArt.form(context, Path(ellipseIn: CGRect(x: x - 5, y: 1, width: 10, height: 10)), centre: CGPoint(x: x, y: 6), radius: 5, lamp, lamp.lifted(brass, 0.4), brass, brass.shifted(-18), highlight: 0.5, core: 0.5)
        }

        // The sill: a deep oak ledge, its top face, its front, and the shadow under it.
        let wood = hue(0xC9A06A), woodDark = hue(0xA9814C)
        let top = Path { p in
            p.move(to: CGPoint(x: 14, y: 334)); p.addLine(to: CGPoint(x: W - 14, y: 334))
            p.addLine(to: CGPoint(x: W - 2, y: 348)); p.addLine(to: CGPoint(x: 2, y: 348)); p.closeSubpath()
        }
        context.fill(Path(CGRect(x: 0, y: 356, width: W, height: 4)), with: .linearGradient(
            Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.3)]), startPoint: CGPoint(x: 0, y: 354), endPoint: CGPoint(x: 0, y: 360)))
        context.fill(Path(CGRect(x: 2, y: 348, width: W - 4, height: 9)), with: .linearGradient(
            Gradient(colors: [woodDark.color(), woodDark.shifted(-9).color()]), startPoint: CGPoint(x: 0, y: 348), endPoint: CGPoint(x: 0, y: 357)))
        context.fill(top, with: vertical(wood.shifted(-5), wood.shifted(6), in: CGRect(x: 0, y: 334, width: W, height: 14)))
        var grain = Path()
        for (y, x0, len) in [(337.5, 0.05, 0.4), (340, 0.3, 0.55), (342.5, 0.1, 0.3), (344.5, 0.5, 0.42), (346.2, 0.2, 0.6)] {
            grain.move(to: CGPoint(x: W * x0, y: y)); grain.addLine(to: CGPoint(x: W * (x0 + len), y: y + 0.4))
        }
        context.stroke(grain, with: .color(Color.white.opacity(0.22)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        context.stroke(Path { $0.move(to: CGPoint(x: 2, y: 348.4)); $0.addLine(to: CGPoint(x: W - 2, y: 348.4)) }, with: .color(Color.white.opacity(0.4)), lineWidth: 1)
        // A bar of sun across the sill, from the glass, slanted away from the light.
        var sun = context
        sun.clip(to: top)
        let slant = -L.x * 36
        sun.fill(Path { p in
            p.move(to: CGPoint(x: c - 150 + slant, y: 334)); p.addLine(to: CGPoint(x: c + 20 + slant, y: 334))
            p.addLine(to: CGPoint(x: c + 70 + slant * 1.6, y: 348)); p.addLine(to: CGPoint(x: c - 100 + slant * 1.6, y: 348)); p.closeSubpath()
        }, with: .color(lamp.rim.color(0.2 * day + 0.08 * lamp.moon)))

        // Where there is room beside the companion: books on the left, a candle on the right.
        if W >= 440 { sillProps(context, left: c - 176, right: c + 176, night: night) }
    }

    /// One side's curtain, hung from the rod at the origin's edge: a panel that
    /// narrows to a tie-back and flares to the sill, folded in long runs.
    private func curtain(_ context: GraphicsContext, in look: WearLook, tone: RGB) {
        var panel = Path()
        panel.move(to: CGPoint(x: 0, y: 8))
        panel.addLine(to: CGPoint(x: 58, y: 8))
        panel.addCurve(to: CGPoint(x: 35, y: 205), control1: CGPoint(x: 60, y: 70), control2: CGPoint(x: 38, y: 150))
        panel.addCurve(to: CGPoint(x: 67, y: 330), control1: CGPoint(x: 32, y: 250), control2: CGPoint(x: 72, y: 292))
        panel.addLine(to: CGPoint(x: 0, y: 330))
        panel.closeSubpath()
        context.fill(panel.offsetBy(dx: 2.5, dy: 1.5), with: .color(Color.black.opacity(0.13)))
        WearArt.form(context, panel, centre: CGPoint(x: 30, y: 170), radius: 70, look, look.lifted(tone, 0.22), tone, tone.shifted(-13, 3), highlight: 0.2, core: 0.5)
        var inside = context
        inside.clip(to: panel)
        // Folds: long soft runs from the rod to the tie-back and out to the hem.
        var deep = Path(), pale = Path()
        for k in 0..<7 {
            let f = Double(k) / 6
            let x0 = 5 + 50 * f, x1 = 4 + 31 * f, x2 = 5 + 61 * f
            var fold = Path()
            fold.move(to: CGPoint(x: x0, y: 8))
            fold.addQuadCurve(to: CGPoint(x: x1, y: 205), control: CGPoint(x: (x0 + x1) / 2 + 3, y: 100))
            fold.addQuadCurve(to: CGPoint(x: x2, y: 330), control: CGPoint(x: (x1 + x2) / 2 - 3, y: 275))
            if k.isMultiple(of: 2) { deep.addPath(fold) } else { pale.addPath(fold) }
        }
        inside.stroke(deep, with: .color(tone.shifted(-16, 2).color(0.38)), style: StrokeStyle(lineWidth: 5.5, lineCap: .butt))
        inside.stroke(pale, with: .color(look.lifted(tone, 0.4).color(0.3)), style: StrokeStyle(lineWidth: 4.5, lineCap: .butt))
        // The hem, a shade deeper, and rings along the rod.
        inside.fill(Path(CGRect(x: 0, y: 322, width: 80, height: 10)), with: .color(tone.shifted(-14, 2).color(0.55)))
        var rings = Path()
        for x in stride(from: 4.0, through: 54, by: 10) { rings.addEllipse(in: CGRect(x: x - 2.2, y: 3, width: 4.4, height: 7)) }
        context.stroke(rings, with: .color(hue(0xC9A24A, dim: 0.85).color(0.9)), lineWidth: 1)
        // The tie-back: a twisted rope round the waist, with a tassel.
        let rope = hue(0xEAD9A8, dim: 0.8)
        var tie = Path()
        tie.move(to: CGPoint(x: 0, y: 198)); tie.addQuadCurve(to: CGPoint(x: 39, y: 209), control: CGPoint(x: 22, y: 211))
        context.stroke(tie, with: .color(rope.shifted(-14).color()), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        context.stroke(tie, with: .color(rope.color()), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2.4, 1.2]))
        var tassel = Path()
        for dx in stride(from: -3.0, through: 3, by: 1.5) { tassel.move(to: CGPoint(x: 38 + dx * 0.4, y: 214)); tassel.addLine(to: CGPoint(x: 38 + dx, y: 232)) }
        context.stroke(tassel, with: .color(rope.shifted(-6).color()), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        WearArt.form(context, Path(ellipseIn: CGRect(x: 34.4, y: 209, width: 7.2, height: 7.2)), centre: CGPoint(x: 38, y: 212.6), radius: 4, look, look.lifted(rope, 0.4), rope, rope.shifted(-16), highlight: 0.4, core: 0.4)
    }

    private func sillProps(_ context: GraphicsContext, left: Double, right: Double, night: Double) {
        // Two books, one flat, one on top, with the pages showing at the edge.
        let book1 = CGRect(x: left - 22, y: 337, width: 44, height: 10)
        let book2 = CGRect(x: left - 17, y: 328, width: 36, height: 9)
        for (rect, hex) in [(book1, UInt32(0x3F6E8F)), (book2, 0xB5524A)] {
            let cover = hue(hex, dim: 0.85), pages = hue(0xF2E8D2, dim: 0.7)
            context.fill(Path(roundedRect: rect.offsetBy(dx: 1.2, dy: 1.4), cornerRadius: 1.6), with: .color(Color.black.opacity(0.18)))
            WearArt.form(context, Path(roundedRect: rect, cornerRadius: 1.6), centre: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, lamp, lamp.lifted(cover, 0.25), cover, cover.shifted(-12), highlight: 0.25, core: 0.5)
            context.fill(Path(CGRect(x: rect.minX + 3, y: rect.minY + 2.2, width: rect.width - 5.5, height: rect.height - 4.4)), with: .color(pages.color()))
            context.fill(Path(CGRect(x: rect.minX + 3, y: rect.minY + 3.6, width: rect.width - 5.5, height: 0.6)), with: .color(Color.black.opacity(0.12)))
            context.fill(Path(CGRect(x: rect.minX, y: rect.minY + 2.4, width: 2.4, height: rect.height - 4.8)), with: .color(Color.black.opacity(0.18)))
        }
        // A candle in a glass: wax, a flame that is always lit, and its light at night.
        let x = right, base = 347.0
        context.ellipse(x + 1, base + 0.6, 9.5, 2.2, .color(SceneInk.shadow))
        let glass = Path(roundedRect: CGRect(x: x - 7, y: base - 17, width: 14, height: 17), cornerRadius: 3)
        context.fill(glass, with: .color(hue(0xBFD8E8, dim: 0.7).color(0.45)))
        let wax = hue(0xF7EBCF, dim: 0.6)
        context.fill(Path(roundedRect: CGRect(x: x - 5.8, y: base - 12, width: 11.6, height: 11.5), cornerRadius: 2), with: .color(wax.color()))
        context.fill(Path(CGRect(x: x - 5.8, y: base - 12, width: 4, height: 11.5)), with: .color(Color.white.opacity(0.22)))
        context.stroke(glass, with: .color(Color.white.opacity(0.5)), lineWidth: 0.8)
        context.fill(Path(CGRect(x: x - 0.4, y: base - 15.5, width: 0.8, height: 3.6)), with: .color(Color.black.opacity(0.7)))
        context.glow(x, base - 19, 34, Ink.color(0xFFB45A, 0.12 + 0.34 * night))
        context.ellipse(x, base - 18.4, 1.9, 3.5, .color(SceneInk.flame))
        context.ellipse(x, base - 17.8, 1, 2.1, .color(SceneInk.candle))
    }
}
