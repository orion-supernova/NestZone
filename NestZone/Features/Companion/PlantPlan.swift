import Foundation

/// What a drawn plant is: one of a few growth rules and the numbers that make
/// a species of it. The rule says how a plant grows (a single stem and a bloom,
/// leaf pairs up a branching stem, a ribbed body that puts out arms, stems that
/// climb, arch and trail); the numbers say what it looks like (height, the
/// five greens, leaf shape, bloom colours). The trees keep their own table
/// (`Canopy.Kind`); the rest of the plants are new rows here, not new painters:
///
/// - `stalk`: a sunflower now; daisy, tulip, rose and peony want a bloom of
///   their own (`Flower.Kind`) on the same stem.
/// - `bush`: basil now; mint, rosemary and lavender change the leaf and the
///   spike.
/// - `column`: a cactus now; the snake plant is the same body without ribs and
///   with blades for arms.
/// - `vine`: a monstera now; fern and orchid take `LeafKind`s of their own.
struct PlantPlan: Equatable, Sendable {
    enum Rule: Sendable { case stalk, bush, column, vine }

    /// A leaf's outline. A juvenile leaf of any kind is whole; `split` leaves
    /// cut themselves into lobes as they age.
    enum LeafKind: Sendable { case ovate, heart, split }

    struct Flower: Equatable, Sendable {
        /// The petal's deep, middle and pale tones, and the heart of the bloom.
        var deep, mid, pale, heart: UInt32
        /// The stamens, spikes and anthers.
        var anther: UInt32 = 0xF2CF6B
        var petals: Int
        var size: Double
    }

    var rule: Rule
    /// The grown plant's height above the soil, and its reach either side.
    var height: Double
    var reach: Double
    /// Five greens, deep to highlight, as a tree's ramp is.
    var ramp: [UInt32]
    var leaf: LeafKind
    var leafLength: Double
    /// Half the leaf's width as a share of its length, and where it is widest.
    var leafWidth: Double
    var widest: Double
    var flower: Flower?
    /// A column's radius, its ribs and its arms.
    var girth = 0.0
    var ribs = 0
    var spine: UInt32 = 0xF3E9C8

    /// The plan for a species, or `nil` while it is still a sketch.
    static func of(_ species: Species) -> PlantPlan? { table[species] }

    private static let table: [Species: PlantPlan] = Dictionary(
        uniqueKeysWithValues: Species.allCases.compactMap { species in PlantPlan(species).map { (species, $0) } })

    private init?(_ species: Species) {
        switch species {
        case .sunflower:
            self.init(rule: .stalk, height: 205, reach: 78,
                      ramp: [0x1B4A2A, 0x2A6A34, 0x3F8C3A, 0x6FB04A, 0xBADB70],
                      leaf: .heart, leafLength: 54, leafWidth: 0.4, widest: 0.34,
                      flower: Flower(deep: 0xE79A12, mid: 0xFFC82E, pale: 0xFFE98A, heart: 0x3A2210, petals: 15, size: 1))
        case .basil:
            self.init(rule: .bush, height: 142, reach: 74,
                      ramp: [0x16432B, 0x226B38, 0x35923E, 0x62B94B, 0xB6E27A],
                      leaf: .ovate, leafLength: 38, leafWidth: 0.4, widest: 0.4,
                      flower: Flower(deep: 0xB9A5E0, mid: 0xE6DDF7, pale: 0xFFFFFF, heart: 0x9CCB6A, petals: 4, size: 1))
        case .cactus:
            self.init(rule: .column, height: 122, reach: 56,
                      ramp: [0x1D4A3A, 0x2C6A4A, 0x44895A, 0x6DAE72, 0xB5DA9A],
                      leaf: .ovate, leafLength: 0, leafWidth: 0, widest: 0.5,
                      flower: Flower(deep: 0xD93878, mid: 0xFF6FA8, pale: 0xFFC4DB, heart: 0xFFD65A, petals: 9, size: 1),
                      girth: 21, ribs: 5)
        case .monstera:
            self.init(rule: .vine, height: 176, reach: 96,
                      ramp: [0x123A2E, 0x1B5A40, 0x2A7E4B, 0x47A45A, 0x98D08A],
                      leaf: .split, leafLength: 60, leafWidth: 0.5, widest: 0.4,
                      flower: nil)
        default:
            return nil
        }
    }

    private init(rule: Rule, height: Double, reach: Double, ramp: [UInt32], leaf: LeafKind, leafLength: Double,
                 leafWidth: Double, widest: Double, flower: Flower?, girth: Double = 0, ribs: Int = 0) {
        (self.rule, self.height, self.reach, self.ramp, self.leaf) = (rule, height, reach, ramp, leaf)
        (self.leafLength, self.leafWidth, self.widest, self.flower, self.girth, self.ribs) = (leafLength, leafWidth, widest, flower, girth, ribs)
    }
}

/// What a house's seed decides about its plant, drawn once and read by the
/// rules: which way it leans, which side its first leaf is on, a little
/// difference for every leaf. The same seed grows the same plant on every
/// phone.
struct PlantSeed: Equatable, Sendable {
    /// -1 or 1.
    let side: Double
    /// Which way the plant leans, in -1…1.
    let lean: Double
    /// Forty draws in 0…1, for whatever a rule wants varied.
    let jitter: [Double]

    init(_ seed: String) {
        var r = Ink.Random(seed + "-plant")
        side = r.next() < 0.5 ? -1 : 1
        lean = (r.next() - 0.5) * 2
        jitter = (0..<40).map { _ in r.next() }
    }

    /// The nth draw, spread over `low…high`.
    func between(_ n: Int, _ low: Double, _ high: Double) -> Double {
        low + (high - low) * jitter[n % jitter.count]
    }
}
