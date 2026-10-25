import SwiftUI

/// What a pet wears. A hat is drawn inside the head's own frame, a bow or a
/// scarf at the throat inside the body's, so each moves as that part does: a
/// kitten's hat nods with its head, a sleeping one's scarf rises and falls with
/// its breath, an owl's bow turns with the owl. The drawings are `WearArt`'s,
/// the same ones a plant wears.
///
/// A dozing pet wears its nightcap, and a hat gives way to it: it fades out as
/// the cap goes on, and back in as the cap flies off at waking.
extension CritterPainter {
    /// The thing worn, if it is one of the four.
    var worn: DecorItem? {
        guard let raw = frame.layout.wearing, let item = DecorItem(rawValue: raw), item.kind == .wearing, item.isDrawn else { return nil }
        return item
    }

    private var wearLook: WearLook { WearLook(L: look.L, day: look.day, slump: look.slump) }

    /// 1 with the nightcap off, 0 with it on, and between while it flies away.
    private var hatShown: Double {
        let capOn = frame.mood < 0.15 || frame.domeLift > 0
        return capOn ? frame.domeLift : 1
    }

    /// A hat standing on `foot` (the top of the head, in the frame `c` is in),
    /// tipped by `tilt`, `scale` times the size it is drawn at.
    func hat(_ c: GraphicsContext, foot: CGPoint, tilt: Double = 0, scale: Double = 1) {
        guard let item = worn, item == .partyHat || item == .tinyCrown else { return }
        let shown = hatShown
        guard shown > 0.01 else { return }
        var h = c
        h.opacity *= shown
        h.translateBy(x: foot.x, y: foot.y)
        h.rotate(by: .radians(tilt + (item == .partyHat ? -0.1 : 0.03)))
        h.scaleBy(x: scale, y: scale)
        if item == .partyHat {
            WearArt.partyHat(h, wearLook, strap: true)
        } else {
            WearArt.crown(h, wearLook, glint: frame.reduceMotion ? 0.5 : max(0, sin(time * 1.9 + 1)))
        }
    }

    /// A bow or a scarf tied at `throat`, `span` either side, the band turned
    /// by `tilt` and the knot and tails `size` times their usual size.
    func neckwear(_ c: GraphicsContext, at throat: CGPoint, span: Double, tilt: Double = 0, size: Double = 1) {
        guard let item = worn, item == .bow || item == .scarf else { return }
        var n = c
        n.translateBy(x: throat.x, y: throat.y)
        n.rotate(by: .radians(tilt))
        n.scaleBy(x: size, y: size)
        if item == .bow {
            WearArt.bow(n, wearLook, span: span / size)
        } else {
            WearArt.scarf(n, wearLook, span: span / size)
        }
    }
}

#if DEBUG
extension CritterPainter {
    /// Where the emoji stood before a pet wore its things: still points in the
    /// box, for the "before" picture (`-decorBefore 1`).
    static func legacyWearing(_ plan: CritterPlan, stage: Int) -> (top: CGPoint, neck: CGPoint) {
        var top = plan.body == .sitter ? CGPoint(x: 47, y: 31) : plan.body == .waddler ? CGPoint(x: 46, y: 33) : CGPoint(x: 60, y: 33)
        var neck = plan.body == .sitter ? CGPoint(x: 47, y: 67) : plan.body == .waddler ? CGPoint(x: 47, y: 70) : CGPoint(x: 60, y: 72)
        if stage < 2 {
            top = CGPoint(x: 60, y: 46); neck = CGPoint(x: 60, y: 90)
        } else if stage == 2 {
            top = CGPoint(x: 60, y: 66); neck = CGPoint(x: 60, y: 90)
        }
        let scale = stage < 2 ? 1 : PetMotion.scales[stage]
        func scaled(_ p: CGPoint) -> CGPoint { CGPoint(x: 60 + (p.x - 60) * scale, y: 108 + (p.y - 108) * scale) }
        return (scaled(top), scaled(neck))
    }
}
#endif
