import Foundation

/// What a drawn pet is: one of three body plans and the numbers that make a
/// species of it, as `PlantPlan` does for the plants. The plan says how it is
/// built and moves; the numbers say what it looks like.
///
/// - `sitter`: a small mammal sitting, seen from the front-left, with a head
///   that faces us. A kitten, and as rows of it the hamster, bunny, puppy,
///   fox and hedgehog, then deer, snow fox and polar cub: ears
///   (`Ears`), tail (`Tail`), markings, a longer or pointed muzzle, a
///   chubby cheek, socks, a bib, the coat's colours. What only one species
///   does (the hamster's seed, the hedgehog's spines) is a function for it in
///   `CritterPainter+Species`.
/// - `perched`: a bird standing upright, face on, with wings folded. An owl
///   now; the penguin is the same plan with a flat beak, flippers and no
///   tufts.
/// - `waddler`: a bird seen from the side, round and downy, a bill that
///   opens, webbed feet: the duckling (`CritterPainter+Duck`). `PetPainter`
///   is its old, flat painter, kept to compare against. The penguin is the
///   same plan, upright and rocking (`CritterPainter+Penguin`).
/// - `shelled`: a turtle seen from the side, a shell of scutes, a neck that
///   stretches and tucks (`CritterPainter+Turtle`).
/// - `swimmer`: a goldfish in its bowl (`CritterPainter+Fish`); the bowl is
///   built once and the fish is what moves.
///
/// All share the duckling's seven stages (`origin` says what comes before
/// the animal: a blanket bundle for a mammal, an egg for a bird), its motion
/// (`PetMotion`) and its moods.
struct CritterPlan: Equatable, Sendable {
    enum Body: Sendable { case sitter, perched, waddler, shelled, swimmer }
    enum Origin: Sendable { case blanket, egg }
    enum Ears: Sendable { case point, round, long, drop, tuft, leaf, none }
    enum Tail: Sendable { case curl, stub, plume, wag, cotton, none }
    enum Marks: Sendable { case tabby, plain, mask, chevron, spots }
    /// How a pupil answers the light: a cat's is a slit by day and opens
    /// round at night; a bird's is always round.
    enum Pupil: Sendable { case slit, round }

    var body: Body
    var origin: Origin
    /// The coat: its light, its middle and its shade; the belly and paws or
    /// the face disc; and what is marked on it (stripes, the inside of an ear).
    var light, coat, shade, belly, mark: UInt32
    var nose: UInt32
    /// An owl's beak and feet, a cat's inner ear.
    var accent: UInt32
    /// The blanket's colour, or the egg's.
    var wrap: UInt32
    var ears: Ears
    var tail: Tail
    var marks: Marks
    /// How tall the ears stand, how wide the head and the body are, against
    /// the kitten: 1 is the kitten's.
    var earHeight = 1.0
    var headWidth = 1.0
    var bodyWidth = 1.0
    var whiskers = true

    // The numbers below are what a species changes without a new drawing; the
    // kitten's are the defaults, and `RULES-pets.md` says what each does.

    /// The eye: the iris's colour, the pupil's answer to the light, and how
    /// big the eye is against the kitten's (1).
    var iris: UInt32 = 0xC9A227
    var pupil: Pupil = .slit
    var eyeSize = 1.0
    /// How far apart the eyes sit, against the kitten's (1).
    var eyeSpread = 1.0
    /// How much fur breaks the outline (cheek tufts, chest ruff, tail fuzz,
    /// haunch): 1 is a kitten's, 0 is sleek, 1.6 a fluffy one.
    var fur = 1.0
    /// How long the muzzle is, against the kitten's (1): a dog or a fox is
    /// longer, a hamster shorter.
    var muzzle = 1.0

    /// The lower face: 0 is the kitten's round chin, 1 a pointed muzzle (a fox, a
    /// hedgehog); and how far the cheeks bulge (a hamster's pouches).
    var chin = 0.0
    var cheek = 0.0
    /// The nose leather against the kitten's (a puppy's is big).
    var noseSize = 1.0
    /// How much bigger the pale chest is (a fox's bib).
    var bib = 1.0
    /// How far the outer eye corner is turned up (a fox's slant), in radians.
    var eyeTilt = 0.0
    /// What the ends of things are coloured: the legs from the ankle down
    /// (a fox's black socks), the ears (a puppy's darker ones, the fox's
    /// black backs), the tail's tip (a fox's white one).
    var socks: UInt32?
    /// How wide the legs are against the kitten's (a fawn's are thin, a cub's
    /// stout), how much fuller a brush is (a winter fox's), and how big a
    /// rabbit-style tail ball is (a deer's flag is small).
    var legWidth = 1.0
    /// A turtle's shell: its dome, and the scutes laid on it.
    var shell: UInt32 = 0x3F7A52
    var plates: UInt32 = 0x9CCB66
    var tailFluff = 1.0
    var tailSize = 1.0
    var earColour: UInt32?
    var tailTip: UInt32?

    /// Which species this is, and the key under which what is built from the
    /// plan once is kept (`CritterGeometry`): the species' name, unless a
    /// Debug variant says otherwise.
    let species: Species
    var key: String

    static func of(_ species: Species) -> CritterPlan? {
#if DEBUG
        if let debugOverride { return debugOverride }
#endif
        return table[species]
    }

#if DEBUG
    /// The art sheet draws a plan that is not in the table (`-artSheet
    /// pet-variants`) by setting this around one canvas; nothing ships it.
    nonisolated(unsafe) static var debugOverride: CritterPlan?

    /// What a few more pets would be as rows, to prove the system is
    /// parameters: nothing here is in the app, nothing is drawn but these.
    static func variant(_ name: String) -> CritterPlan? {
        guard var p = table[.kitten] else { return nil }
        p.key = "kitten+" + name
        switch name {
        case "hamster":
            (p.light, p.coat, p.shade, p.belly, p.mark) = (0xF0D2A4, 0xD9AC72, 0xA9773E, 0xFFF1DC, 0x9C6A36)
            (p.ears, p.earHeight, p.headWidth, p.bodyWidth) = (.round, 0.55, 1.28, 1.08)
            (p.tail, p.marks, p.eyeSize, p.eyeSpread, p.fur, p.muzzle) = (.stub, .plain, 0.82, 1.12, 1.3, 0.7)
            (p.pupil, p.iris) = (.round, 0x4A3320)
        case "bunny":
            (p.light, p.coat, p.shade, p.belly, p.mark) = (0xEDE6DC, 0xCFC3B6, 0x9C8F86, 0xFFFAF2, 0x8E8078)
            (p.ears, p.earHeight, p.headWidth, p.bodyWidth) = (.long, 1.9, 1.0, 1.0)
            (p.tail, p.marks, p.eyeSize, p.fur, p.muzzle, p.whiskers) = (.stub, .plain, 0.9, 1.1, 0.8, true)
            (p.pupil, p.iris, p.nose) = (.round, 0x6B4A3A, 0xE7A1A8)
        case "puppy":
            (p.light, p.coat, p.shade, p.belly, p.mark) = (0xE6C79A, 0xC99A5E, 0x8F6334, 0xFFF0D8, 0x6E4A28)
            (p.ears, p.earHeight, p.headWidth, p.bodyWidth) = (.drop, 1.0, 1.08, 1.05)
            (p.tail, p.marks, p.eyeSize, p.fur, p.muzzle) = (.curl, .plain, 1.0, 1.1, 1.35)
            (p.pupil, p.iris, p.nose) = (.round, 0x5B3A22, 0x3A2A2A)
        case "fox":
            (p.light, p.coat, p.shade, p.belly, p.mark) = (0xF3A867, 0xDD7A33, 0x9C4A1C, 0xFFF0E0, 0x4A2A1A)
            (p.ears, p.earHeight, p.headWidth, p.bodyWidth) = (.point, 1.25, 0.98, 0.95)
            (p.tail, p.marks, p.eyeSize, p.fur, p.muzzle) = (.plume, .plain, 0.86, 1.5, 1.5)
            (p.pupil, p.iris, p.nose) = (.slit, 0xC98A1F, 0x2E2220)
        default:
            return nil
        }
        return p
    }
#endif

    private static let table: [Species: CritterPlan] = Dictionary(
        uniqueKeysWithValues: Species.allCases.compactMap { species in CritterPlan(species).map { (species, $0) } })

    private init?(_ species: Species) {
        switch species {
        case .kitten:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xF6C98A, coat: 0xE9A25A, shade: 0xBC6E34, belly: 0xFFF2DE, mark: 0xAE5B2A,
                      nose: 0xE98A93, accent: 0xF5AFA8, wrap: 0xC9B6EA, ears: .point, tail: .curl, marks: .tabby, species: species)
            headWidth = 1.08
        case .owl:
            self.init(body: .perched, origin: .egg,
                      light: 0xB48C66, coat: 0x8C6A4B, shade: 0x5B4230, belly: 0xEFDDBE, mark: 0x6A4A33,
                      nose: 0xE9A23B, accent: 0xE9A23B, wrap: 0xF4EAD5, ears: .tuft, tail: .none, marks: .chevron,
                      species: species, whiskers: false)
            iris = 0xFFC53D
            pupil = .round
            eyeSize = 1.0
        case .duckling:
            self.init(body: .waddler, origin: .egg,
                      light: 0xFFE98A, coat: 0xFFD447, shade: 0xE5A21E, belly: 0xFFF0B0, mark: 0xF0B52A,
                      nose: 0xFF9F43, accent: 0xFF9F43, wrap: 0xFFF3DC, ears: .none, tail: .stub, marks: .plain,
                      species: species, whiskers: false)
            iris = 0x3B2812
            pupil = .round
            eyeSize = 1.0
            fur = 1.3
        case .hamster:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xF6D8A6, coat: 0xDFA864, shade: 0xA8733C, belly: 0xFFF2DC, mark: 0x93602E,
                      nose: 0xE98FA0, accent: 0xF3A9A0, wrap: 0xBFE3CF, ears: .round, tail: .none, marks: .plain, species: species)
            (earHeight, headWidth, bodyWidth) = (0.5, 1.26, 1.08)
            (eyeSize, eyeSpread, fur, muzzle, cheek, bib) = (0.95, 1.08, 0.8, 0.62, 1.7, 1.4)
            (pupil, iris) = (.round, 0x33211A)
        case .bunny:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xF1EAE0, coat: 0xD3C7BA, shade: 0x9A8D86, belly: 0xFFFBF4, mark: 0x8E8078,
                      nose: 0xEFA1AC, accent: 0xF4B6BF, wrap: 0xF4C7D3, ears: .long, tail: .cotton, marks: .plain, species: species)
            (earHeight, headWidth, bodyWidth) = (1.7, 1.0, 1.0)
            (eyeSize, eyeSpread, fur, muzzle) = (0.94, 1.08, 1.15, 0.78)
            (pupil, iris) = (.round, 0x6A4034)
        case .puppy:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xEECE9E, coat: 0xD9A767, shade: 0x94642F, belly: 0xFFF1DA, mark: 0x7A4F26,
                      nose: 0x2F2424, accent: 0xF08A9A, wrap: 0xB7D3F2, ears: .drop, tail: .wag, marks: .plain, species: species, whiskers: false)
            (headWidth, bodyWidth) = (1.08, 1.05)
            (eyeSize, fur, muzzle, noseSize) = (1.0, 1.1, 1.3, 1.7)
            (pupil, iris, earColour) = (.round, 0x5B3A22, 0xA46F38)
        case .fox:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xF8B070, coat: 0xE8782C, shade: 0xA24A1A, belly: 0xFFF5E8, mark: 0x6A3216,
                      nose: 0x2A201E, accent: 0xF4A9A0, wrap: 0xF2D3A6, ears: .point, tail: .plume, marks: .mask, species: species)
            (earHeight, headWidth, bodyWidth) = (1.3, 1.0, 0.95)
            (eyeSize, eyeSpread, fur, muzzle, chin, bib, eyeTilt) = (0.86, 1.0, 1.0, 1.35, 1.0, 1.6, 0.14)
            (pupil, iris) = (.slit, 0xD89A22)
            (socks, earColour, tailTip) = (0x3A2724, 0x3A2724, 0xFFF6EA)
        case .hedgehog:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xC9A47C, coat: 0x8F6D4D, shade: 0x543E2D, belly: 0xEBCFA9, mark: 0x3E2C20,
                      nose: 0x3B2A2A, accent: 0xF0B2A6, wrap: 0xCFE0B4, ears: .round, tail: .none, marks: .plain, species: species, whiskers: false)
            (earHeight, headWidth, bodyWidth) = (0.42, 0.98, 1.0)
            (eyeSize, eyeSpread, fur, muzzle, chin, noseSize) = (0.8, 1.12, 0.6, 1.3, 1.0, 1.4)
            (pupil, iris) = (.round, 0x2A1C14)
        case .deer:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xE6B684, coat: 0xCB8C56, shade: 0x8C5632, belly: 0xFFF3E0, mark: 0x6E4429,
                      nose: 0x2E2321, accent: 0xF2BDB0, wrap: 0xD4E6BE, ears: .leaf, tail: .cotton, marks: .spots, species: species, whiskers: false)
            (earHeight, headWidth, bodyWidth) = (1.22, 0.9, 0.94)
            (eyeSize, eyeSpread, fur, muzzle, chin, noseSize, cheek) = (1.12, 1.06, 0.3, 1.3, 0.85, 1.3, 0)
            (pupil, iris) = (.round, 0x3A2418)
            (legWidth, tailSize, socks) = (0.62, 0.62, 0x5A3E2C)
        case .snowFox:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xFFFFFF, coat: 0xE4EBF5, shade: 0x8C9FC4, belly: 0xFFFFFF, mark: 0x7482A0,
                      nose: 0x2B2B34, accent: 0xF0B7B7, wrap: 0xBFD8F0, ears: .point, tail: .plume, marks: .mask, species: species)
            (earHeight, headWidth, bodyWidth) = (1.0, 1.02, 1.0)
            (eyeSize, eyeSpread, fur, muzzle, chin, bib, eyeTilt) = (0.84, 1.02, 1.8, 1.38, 0.95, 1.5, 0.12)
            (pupil, iris) = (.slit, 0x4F86B5)
            (socks, earColour, tailTip) = (0x7482A0, 0x7C8BAA, 0xD8E1F0)
            tailFluff = 1.3
        case .polarCub:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xFFFBF1, coat: 0xF1EADF, shade: 0xB3A59B, belly: 0xFFFCF6, mark: 0xB6A79B,
                      nose: 0x26262C, accent: 0xDDB5AA, wrap: 0xC2DDF4, ears: .round, tail: .stub, marks: .plain, species: species, whiskers: false)
            (earHeight, headWidth, bodyWidth) = (0.5, 1.2, 1.16)
            (eyeSize, eyeSpread, fur, muzzle, chin, noseSize, cheek) = (0.8, 1.14, 0.85, 1.35, 0.6, 1.8, 0.25)
            (pupil, iris) = (.round, 0x2A1C14)
            legWidth = 1.3
        case .penguin:
            self.init(body: .waddler, origin: .egg,
                      light: 0x6C7CA8, coat: 0x3B4769, shade: 0x1B2238, belly: 0xF8FAFE, mark: 0x232B45,
                      nose: 0xFF9A3C, accent: 0xFF9A3C, wrap: 0xE6F0FA, ears: .none, tail: .stub, marks: .plain, species: species, whiskers: false)
            (iris, pupil, eyeSize, fur) = (0x2A1C14, .round, 1.0, 0.7)
        case .turtle:
            self.init(body: .shelled, origin: .egg,
                      light: 0xE4EDAE, coat: 0xB9CF7A, shade: 0x7F9C4F, belly: 0xF4EEC8, mark: 0x547040,
                      nose: 0x547040, accent: 0xF2A9A4, wrap: 0xD7EEE0, ears: .none, tail: .stub, marks: .plain, species: species, whiskers: false)
            (iris, pupil, eyeSize) = (0x2D2416, .round, 1.0)
            (shell, plates) = (0x3F7A52, 0xA3CD66)
        case .goldfish:
            self.init(body: .swimmer, origin: .egg,
                      light: 0xFFC884, coat: 0xFF8B3E, shade: 0xCF4F1F, belly: 0xFFE8C2, mark: 0xB43A14,
                      nose: 0xFFB59A, accent: 0xF2A9A4, wrap: 0xD4EEF4, ears: .none, tail: .stub, marks: .plain, species: species, whiskers: false)
            (iris, pupil, eyeSize) = (0x2B1A10, .round, 1.0)
        default:
            return nil
        }
    }

    private init(body: Body, origin: Origin, light: UInt32, coat: UInt32, shade: UInt32, belly: UInt32, mark: UInt32,
                 nose: UInt32, accent: UInt32, wrap: UInt32, ears: Ears, tail: Tail, marks: Marks, species: Species, whiskers: Bool = true) {
        self.species = species
        self.key = species.rawValue
        (self.body, self.origin, self.light, self.coat, self.shade, self.belly, self.mark) = (body, origin, light, coat, shade, belly, mark)
        (self.nose, self.accent, self.wrap, self.ears, self.tail, self.marks, self.whiskers) = (nose, accent, wrap, ears, tail, marks, whiskers)
    }
}
