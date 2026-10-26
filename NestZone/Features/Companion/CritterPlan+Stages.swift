import Foundation

/// The life stages of a mammal pet. A pet's stage is not a scale: the baby, the
/// little one and the young one each have their own silhouette, proportions,
/// features and coat, and a stage is the species' plan with those numbers
/// changed (`at(stage:)`), under a key of its own, so the shapes built from it
/// (`CritterGeometry`) are cached per stage as they are per species and
/// colourway. `RULES-pets.md`, "Life stages", says what each stage is and why.
///
/// Colours are mixed *toward* a target from the plan's own, never replaced, so
/// a colourway (a calico, a cross fox) is the same animal at every age.
extension CritterPlan {
    /// What one stage changes, against the grown pet (1 is grown).
    struct Growth {
        var head = 1.0, headScale = 1.0
        var body = 1.0, bodyHeight = 1.0
        var ears = 1.0, earKind: Ears?
        var earFold = 0.0
        var muzzle = 1.0, eye = 1.0, eyeSpread = 1.0
        var legLength = 1.0, pawSize = 1.0, splay = 0.0
        var tailLength = 1.0, tailWidth = 1.0
        var fur = 1.0, marks = 1.0, lid = 0.0
        /// How far the coat is washed toward `wash` (a pale downy baby, a
        /// chocolate fox kit), and the colour of the eyes at this age.
        var fade = 0.0, wash: UInt32?
        var iris: UInt32?, irisAmount = 0.0
        var legWidth = 1.0
        var spots = 1.0
        var tailTip = true
        var cheek = 0.0
    }

    /// The plan at a stage; 3 and above only (before that it is a bundle). The
    /// grown plan comes back as it is.
    func at(stage: Int) -> CritterPlan {
        guard body == .sitter, stage < 6 else { return self }
        let g = Self.growth(species, stage: max(3, stage))
        var p = self
        p.life = max(3, stage)
        // "@s": a colourway key is "<species>#<n>", so this cannot meet one.
        p.key = key + "@s" + String(p.life)
        p.headWidth *= g.head; p.headScale = g.headScale
        p.bodyWidth *= g.body; p.bodyHeight = g.bodyHeight
        p.earHeight *= g.ears; p.earFold = g.earFold
        if let kind = g.earKind { p.ears = kind }
        p.muzzle = muzzle * g.muzzle
        p.eyeSize *= g.eye; p.eyeSpread *= g.eyeSpread
        p.legLength = g.legLength; p.pawSize = g.pawSize; p.splay = g.splay
        p.tailLength = g.tailLength; p.tailWidth = g.tailWidth
        p.fur *= g.fur; p.markStrength = g.marks; p.lidHeavy = g.lid
        p.legWidth *= g.legWidth
        p.cheek = cheek * (1 + g.cheek)
        p.spotSize = g.spots
        if let w = g.wash, g.fade > 0 {
            func m(_ c: UInt32) -> UInt32 { Self.mix(c, w, g.fade) }
            p.coat = m(coat); p.light = m(light); p.shade = m(shade); p.mark = m(mark)
        }
        if let i = g.iris { p.iris = Self.mix(iris, i, g.irisAmount) }
        p.tipShown = g.tailTip
        // An adult deer's spots are gone: the grown plan is plain, the young have them.
        if species == .deer { p.marks = .spots }
        return p
    }

    /// One colour a share of the way to another, channel by channel.
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func ch(_ shift: UInt32) -> UInt32 {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return UInt32((x + (y - x) * t).rounded()) & 0xFF
        }
        return ch(16) << 16 | ch(8) << 8 | ch(0)
    }

    /// The three stages of each species: from real development, exaggerated
    /// to read at card size. Stage 3 is the newborn-to-baby (head as wide as
    /// the body, stubby legs, eyes newly open), 4 the chubby, playful little
    /// one, 5 the lanky, awkward young one with its markings coming in.
    static func growth(_ species: Species, stage: Int) -> Growth {
        var g: Growth
        switch stage {
        case 3:
            g = Growth(head: 1.0, headScale: 1.22, body: 0.78, bodyHeight: 0.86, ears: 0.5, earFold: 1, muzzle: 0.7, eye: 1.0, eyeSpread: 1.12,
                       legLength: 0.4, pawSize: 0.7, splay: 0.6, tailLength: 0.55, tailWidth: 1.3, fur: 1.9, marks: 0.3, lid: 0.1, fade: 0.3, wash: 0xFFF1DF,
                       iris: 0x86A0C4, irisAmount: 0.92)
        case 4:
            g = Growth(head: 1.0, headScale: 1.14, body: 0.9, bodyHeight: 0.9, ears: 0.8, earFold: 0.4, muzzle: 0.85, eye: 1.0, eyeSpread: 1.07,
                       legLength: 0.7, pawSize: 0.95, splay: 0.4, tailLength: 0.8, tailWidth: 1.15, fur: 1.45, marks: 0.6, lid: 0.05, fade: 0.14, wash: 0xFFF1DF,
                       iris: 0x84AEB8, irisAmount: 0.6)
        default:
            g = Growth(head: 0.96, headScale: 1.0, body: 0.82, bodyHeight: 1.0, ears: 1.25, muzzle: 1.0, eye: 0.96, eyeSpread: 1.0,
                       legLength: 1.75, pawSize: 1.35, splay: 0, tailLength: 1.1, tailWidth: 0.72, fur: 0.85, marks: 1.15, lid: 0, iris: 0xB7B04A, irisAmount: 0.4)
        }
        // What is only one species': each is real development, exaggerated a
        // little to read at card size.
        let i = stage - 3
        func pick<T>(_ a: T, _ b: T, _ c: T) -> T { [a, b, c][i] }
        switch species {
        case .puppy:
            // Soft floppy ears on a round head, paws far too big for it, blue-grey eyes.
            g.pawSize = pick(0.95, 1.2, 1.5); g.legLength = pick(0.45, 0.75, 1.5)
            g.iris = 0x7F93AE; g.irisAmount = pick(0.9, 0.55, 0.2)
            g.muzzle = pick(0.72, 0.85, 1.0); g.ears = 1; g.earFold = 0
            g.tailLength = pick(0.6, 0.85, 1.1)
        case .fox:
            // A kit is dark chocolate with a short blunt muzzle and small round
            // ears; the coat turns red, the white tip starts, the muzzle lengthens.
            g.fade = pick(0.78, 0.5, 0.1); g.wash = 0x4A2C20
            g.earKind = pick(.round, .round, .point); g.ears = pick(0.42, 0.6, 1.12); g.earFold = 0
            g.muzzle = pick(0.5, 0.75, 0.95); g.tailTip = stage >= 5
            g.iris = 0x7F9CBA; g.irisAmount = pick(0.9, 0.6, 0.15)
            g.fur = pick(1.5, 1.3, 0.95); g.tailLength = pick(0.6, 0.8, 1.05); g.tailWidth = pick(1.2, 1.1, 0.8)
        case .snowFox:
            g.fade = pick(0.42, 0.25, 0.08); g.wash = 0xA29B96
            g.earKind = pick(.round, .round, .point); g.ears = pick(0.45, 0.62, 1.12); g.earFold = 0
            g.muzzle = pick(0.55, 0.78, 0.95); g.fur = pick(0.85, 0.8, 0.7)
            g.iris = 0x7F9CBA; g.irisAmount = pick(0.5, 0.3, 0.1)
            g.tailLength = pick(0.65, 0.85, 1.05); g.tailWidth = pick(1.15, 1.1, 0.85)
        case .bunny:
            // A kit is a round ball with short ears; the ears shoot up before the rest.
            g.ears = pick(0.38, 0.6, 0.86); g.earFold = 0
            g.body = pick(0.92, 0.95, 0.9); g.bodyHeight = pick(0.95, 0.96, 1.0)
            g.legLength = pick(0.4, 0.65, 1.3); g.iris = 0x5B4A5A; g.irisAmount = pick(0.4, 0.2, 0)
            g.fade = pick(0.2, 0.1, 0.03)
        case .hamster:
            // A pup is pink and nearly hairless, eyes shut; then fuzzy.
            g.fade = pick(0.62, 0.3, 0.05); g.wash = 0xF1B3AE
            g.fur = pick(0.15, 0.55, 0.9); g.lid = pick(1.4, 0.45, 0.05); g.ears = pick(0.8, 0.9, 1.0)
            g.iris = 0x3A2A2A; g.irisAmount = 0.2; g.tailLength = 1; g.legLength = 1
            g.cheek = pick(-0.55, -0.25, 0); g.earFold = 0
        case .hedgehog:
            // A hoglet's spines are soft and white and darken as it grows.
            g.fade = pick(0.7, 0.45, 0.15); g.wash = 0xF3EBDD
            g.fur = pick(0.8, 0.8, 0.8); g.ears = 1; g.earFold = 0; g.lid = pick(0.5, 0.2, 0)
            g.iris = 0x2A1C14; g.irisAmount = 0.1; g.legLength = 1
        case .deer:
            // A fawn has big spots that fade, long wobbly legs and large ears.
            g.legLength = pick(1.22, 1.3, 1.45); g.legWidth = pick(0.9, 0.95, 1)
            g.ears = pick(0.85, 0.88, 0.92); g.earFold = 0; g.splay = pick(0.5, 0.25, 0)
            g.spots = pick(1.7, 1.45, 1.0); g.marks = pick(1.0, 0.9, 0.4)
            g.muzzle = pick(0.75, 0.85, 1.0); g.fade = pick(0.2, 0.1, 0); g.wash = 0xFFF1DF
            g.iris = 0x3A2418; g.irisAmount = 0; g.lid = pick(0.12, 0.04, 0)
            g.body = pick(0.82, 0.86, 0.88); g.bodyHeight = pick(0.84, 0.88, 0.96)
        case .polarCub:
            // Tiny, round and sleepy.
            g.fade = pick(0.35, 0.2, 0.05); g.wash = 0xFFF1D6
            g.ears = pick(0.8, 0.9, 1.0); g.earFold = 0; g.lid = pick(0.5, 0.22, 0.05)
            g.fur = pick(0.6, 0.55, 0.6); g.muzzle = pick(0.7, 0.85, 1.0); g.legLength = pick(0.45, 0.7, 1.12)
            g.iris = 0x2A1C14; g.irisAmount = 0.1; g.legWidth = pick(1.1, 1.05, 1)
            g.body = pick(0.86, 0.92, 0.94); g.bodyHeight = pick(0.84, 0.9, 1.0)
        default:
            break
        }
        return g
    }
}
