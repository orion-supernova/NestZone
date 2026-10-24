import Foundation

/// What a drawn pet is: one of two body plans and the numbers that make a
/// species of it, as `PlantPlan` does for the plants. The plan says how it is
/// built and moves; the numbers say what it looks like.
///
/// - `sitter`: a small mammal sitting, seen from the front-left, with a head
///   that faces us. A kitten now. The hamster, bunny, puppy, fox, hedgehog,
///   deer and the two bears are rows here: ears (`Ears`), tail (`Tail`),
///   markings, a longer muzzle for a dog or a fox, the coat's colours.
/// - `perched`: a bird standing upright, face on, with wings folded. An owl
///   now; the penguin is the same plan with a flat beak, flippers and no
///   tufts. The duckling keeps its own painter, `PetPainter`.
///
/// Both share the duckling's seven stages (`origin` says what comes before
/// the animal: a blanket bundle for a mammal, an egg for a bird), its motion
/// (`PetMotion`) and its moods.
struct CritterPlan: Equatable, Sendable {
    enum Body: Sendable { case sitter, perched }
    enum Origin: Sendable { case blanket, egg }
    enum Ears: Sendable { case point, round, long, drop, tuft, none }
    enum Tail: Sendable { case curl, stub, plume, none }
    enum Marks: Sendable { case tabby, plain, mask, chevron }
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
