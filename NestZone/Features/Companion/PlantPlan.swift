import Foundation

/// What a drawn plant is: one of a few growth rules and the numbers that make
/// a species of it. The rule says how a plant grows (a single stem and a bloom,
/// leaf pairs up a branching stem, a ribbed body that puts out arms, stems that
/// climb, arch and trail, flower stems out of a leafy tuft, arching canes with
/// compound leaves); the numbers say what it looks like (height, the five
/// greens, leaf shape, bloom colours). The trees keep their own table
/// (`Canopy.Kind`); the rest of the plants are new rows here, not new painters:
///
/// - `stalk`: a sunflower: one stem, a leaf at every hand's width, a head.
/// - `bush`: basil now; mint, rosemary and lavender change the leaf and the
///   spike.
/// - `column`: a cactus now; the snake plant is the same body without ribs and
///   with blades for arms.
/// - `vine`: a monstera now, on its moss pole; fern and orchid take leaf shapes
///   of their own.
/// - `tuft`: a rosette of leaves and flower stems that rise out of it, each
///   with its own bloom that opens in its own time: daisy, tulip and peony.
///   A tuft's stems are the plan's `stems`; the bloom is the flower's.
/// - `cane`: woody canes that arch out with compound leaves, thorns and a bloom
///   at the tip: a rose. A climbing rose or a bramble is the same canes with
///   longer reach.
struct PlantPlan: Equatable, Sendable {
    enum Rule: Sendable { case stalk, bush, column, vine, tuft, cane }

    /// What a bloom is, which says how its head is built.
    enum Bloom: Sendable { case none, sunflower, spike, cactus, daisy, tulip, peony, rose }

    /// What the seed looks like in the soil, so it is the species' own.
    enum SeedLook: Sendable { case husk, dot, bulb, tuber, hip, cutting }

    struct Flower: Equatable, Sendable {
        /// The petal's deep, middle and pale tones, and the heart of the bloom.
        var deep, mid, pale, heart: UInt32
        /// The stamens, spikes and anthers.
        var anther: UInt32 = 0xF2CF6B
        /// A blush at a petal's tip or a flame at its base.
        var tint: UInt32 = 0
        var petals: Int
        var size: Double = 1
        var bloom: Bloom
    }

    /// One flower stem of a tuft: how far off centre it stands, how tall it
    /// grows, when it starts to rise and when its bloom opens (past 1, never
    /// within the plant's growth: it stays a bud), and how big a bloom it bears.
    struct Stem: Equatable, Sendable {
        var x, height, born, opens: Double
        var size = 1.0
    }

    var rule: Rule
    /// The grown plant's height above the soil, and its reach either side.
    var height: Double
    var reach: Double
    /// Five greens, deep to highlight, as a tree's ramp is.
    var ramp: [UInt32]
    var leaf: LeafShape.Kind
    var leafLength: Double
    var flower: Flower?
    /// A column's radius and its ribs.
    var girth = 0.0
    var ribs = 0
    var spine: UInt32 = 0xF3E9C8
    var stems: [Stem] = []
    /// A tuft's rosette: how many leaves and how long.
    var basal = 0
    var basalLength = 0.0
    /// Leaves on each flower stem.
    var stemLeaves = 0
    var seedLook = SeedLook.husk

    /// The plan for a species, or `nil` while it is still a sketch.
    static func of(_ species: Species) -> PlantPlan? { table[species] }

    private static let table: [Species: PlantPlan] = Dictionary(
        uniqueKeysWithValues: Species.allCases.compactMap { species in PlantPlan(species).map { (species, $0) } })

    private init?(_ species: Species) {
        switch species {
        case .sunflower:
            self.init(rule: .stalk, height: 205, reach: 78,
                      ramp: [0x1B4A2A, 0x2A6A34, 0x3F8C3A, 0x6FB04A, 0xBADB70],
                      leaf: .heart, leafLength: 54,
                      flower: Flower(deep: 0xE0900E, mid: 0xFFC82E, pale: 0xFFE98A, heart: 0x3A2210, anther: 0xE8A21C, petals: 21, bloom: .sunflower))
            seedLook = .husk
        case .basil:
            self.init(rule: .bush, height: 142, reach: 74,
                      ramp: [0x16432B, 0x226B38, 0x35923E, 0x62B94B, 0xB6E27A],
                      leaf: .ovate, leafLength: 38,
                      flower: Flower(deep: 0xB9A5E0, mid: 0xF1ECFA, pale: 0xFFFFFF, heart: 0x9CCB6A, petals: 4, bloom: .spike))
            seedLook = .dot
        case .cactus:
            self.init(rule: .column, height: 122, reach: 56,
                      ramp: [0x1D4A3A, 0x2C6A4A, 0x44895A, 0x6DAE72, 0xB5DA9A],
                      leaf: .ovate, leafLength: 0,
                      flower: Flower(deep: 0xD93878, mid: 0xFF6FA8, pale: 0xFFC4DB, heart: 0xFFD65A, petals: 9, bloom: .cactus))
            girth = 21
            ribs = 5
            seedLook = .dot
        case .monstera:
            self.init(rule: .vine, height: 176, reach: 96,
                      ramp: [0x123A2E, 0x1B5A40, 0x2A7E4B, 0x47A45A, 0x98D08A],
                      leaf: .monstera3, leafLength: 60, flower: nil)
            seedLook = .cutting
        case .daisy:
            self.init(rule: .tuft, height: 132, reach: 62,
                      ramp: [0x1E5230, 0x2F7A3C, 0x4A9C45, 0x7CC055, 0xC5E88A],
                      leaf: .spoon, leafLength: 38,
                      flower: Flower(deep: 0xD9D2E4, mid: 0xFFFFFF, pale: 0xFFF8EE, heart: 0xF7C21B, anther: 0xE48A18, tint: 0xF4A6BE, petals: 17, size: 1, bloom: .daisy))
            stems = [Stem(x: -16, height: 126, born: 0.3, opens: 0.74), Stem(x: 5, height: 150, born: 0.26, opens: 0.84),
                     Stem(x: 24, height: 104, born: 0.38, opens: 0.92, size: 0.9)]
            basal = 9
            basalLength = 42
            seedLook = .dot
        case .tulip:
            self.init(rule: .tuft, height: 150, reach: 56,
                      ramp: [0x1B4A34, 0x2B6E47, 0x4A9460, 0x7ABB88, 0xC4E6C0],
                      leaf: .strap, leafLength: 80,
                      flower: Flower(deep: 0xB3172B, mid: 0xE8374A, pale: 0xFF9C7A, heart: 0x2A1A10, anther: 0x3B2A2A, tint: 0xF6C34A, petals: 6, bloom: .tulip))
            stems = [Stem(x: -3, height: 138, born: 0.28, opens: 0.78), Stem(x: 14, height: 114, born: 0.34, opens: 0.9, size: 0.92),
                     Stem(x: -18, height: 92, born: 0.4, opens: 1.2, size: 0.85)]
            basal = 4
            basalLength = 84
            seedLook = .bulb
        case .rose:
            self.init(rule: .cane, height: 172, reach: 70,
                      ramp: [0x173D2A, 0x25593A, 0x35784A, 0x5A9C5C, 0xA9D58E],
                      leaf: .leaflet, leafLength: 22,
                      flower: Flower(deep: 0x8E0F31, mid: 0xC81E4A, pale: 0xF2708F, heart: 0x6A0A22, petals: 5, bloom: .rose))
            seedLook = .hip
        case .peony:
            self.init(rule: .tuft, height: 140, reach: 84,
                      ramp: [0x153C2C, 0x225A3E, 0x32764A, 0x57985A, 0xA2CC86],
                      leaf: .lobed, leafLength: 54,
                      flower: Flower(deep: 0xD8648A, mid: 0xF2A0BB, pale: 0xFFDCE6, heart: 0xF5C84B, anther: 0xF0B72F, tint: 0xB23C66, petals: 5, size: 1, bloom: .peony))
            stems = [Stem(x: -8, height: 132, born: 0.3, opens: 0.8, size: 1), Stem(x: 20, height: 112, born: 0.36, opens: 0.93, size: 0.8),
                     Stem(x: -26, height: 88, born: 0.44, opens: 1.2, size: 0.7)]
            basal = 4
            basalLength = 40
            stemLeaves = 1
            seedLook = .tuber
        default:
            return nil
        }
    }

    private init(rule: Rule, height: Double, reach: Double, ramp: [UInt32], leaf: LeafShape.Kind, leafLength: Double, flower: Flower?) {
        (self.rule, self.height, self.reach, self.ramp, self.leaf, self.leafLength, self.flower) = (rule, height, reach, ramp, leaf, leafLength, flower)
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
