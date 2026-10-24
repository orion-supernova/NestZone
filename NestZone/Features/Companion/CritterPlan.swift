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

    static func of(_ species: Species) -> CritterPlan? { table[species] }

    private static let table: [Species: CritterPlan] = Dictionary(
        uniqueKeysWithValues: Species.allCases.compactMap { species in CritterPlan(species).map { (species, $0) } })

    private init?(_ species: Species) {
        switch species {
        case .kitten:
            self.init(body: .sitter, origin: .blanket,
                      light: 0xF6C98A, coat: 0xE9A25A, shade: 0xBC6E34, belly: 0xFFF2DE, mark: 0xAE5B2A,
                      nose: 0xE98A93, accent: 0xF5AFA8, wrap: 0xC9B6EA, ears: .point, tail: .curl, marks: .tabby)
        case .owl:
            self.init(body: .perched, origin: .egg,
                      light: 0xB48C66, coat: 0x8C6A4B, shade: 0x5B4230, belly: 0xEFDDBE, mark: 0x6A4A33,
                      nose: 0xE9A23B, accent: 0xE9A23B, wrap: 0xF4EAD5, ears: .tuft, tail: .none, marks: .chevron,
                      whiskers: false)
        default:
            return nil
        }
    }

    private init(body: Body, origin: Origin, light: UInt32, coat: UInt32, shade: UInt32, belly: UInt32, mark: UInt32,
                 nose: UInt32, accent: UInt32, wrap: UInt32, ears: Ears, tail: Tail, marks: Marks, whiskers: Bool = true) {
        (self.body, self.origin, self.light, self.coat, self.shade, self.belly, self.mark) = (body, origin, light, coat, shade, belly, mark)
        (self.nose, self.accent, self.wrap, self.ears, self.tail, self.marks, self.whiskers) = (nose, accent, wrap, ears, tail, marks, whiskers)
    }
}
