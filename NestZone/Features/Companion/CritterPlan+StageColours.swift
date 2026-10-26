import Foundation

extension CritterPlan {
    /// A bird's, turtle's or goldfish's plan as it is at `stage`: the colours
    /// that only come with age are not there yet. A young owl's eyes are dark
    /// and turn yellow as it grows; a rockhopper's red eye is a grown bird's; a
    /// goldfish is bronze. Called by `at(stage:)` (`CritterPlan+Stages`, the
    /// mammals' mechanism) for every body that is not a sitter. Shapes are
    /// never changed here: what a stage adds to a bird is built once per plan
    /// (`DuckStages` and the others) and drawn by the stage's `Growth` table,
    /// so the key stays the plan's and nothing is built twice.
    func colours(atStage stage: Int) -> CritterPlan {
        var p = self
        p.life = stage
        switch species {
        case .owl where stage < 6:
            // Dark blue-brown eyes on a chick, bright by the time it can fly.
            let young = stage <= 3 ? 0.82 : stage == 4 ? 0.55 : 0.22
            p.iris = Self.blend(iris, 0x3A2A22, young)
        case .penguin where colourway == 2 && stage < 6:
            p.iris = 0x5A2A22
        case .goldfish where stage < 6:
            // Real goldfish are dull bronze-brown for their first months (a
            // dark one dark, a pale one a pale olive), and a colourway's
            // marks (a calico's patches, an oranda's cap) come with the
            // grown colour.
            let bronze: (UInt32, UInt32, UInt32, UInt32, UInt32) = switch colourway {
            case 1: (0xBDAE98, 0x9C8E78, 0x62574A, 0xD8CDB8, 0x4D4338)
            case 2: (0xC4B994, 0xA09A74, 0x686240, 0xD6D0B0, 0x524C34)
            case 3: (0x6A5A4C, 0x3E3028, 0x1E1612, 0x5A4A3E, 0x1A1210)
            default: (0xB9976A, 0x8D6E45, 0x5B442A, 0xCDB48C, 0x4B3820)
            }
            (p.light, p.coat, p.shade, p.belly, p.mark) = bronze
            p.nose = 0xB89A7A
            p.patches = []
            p.face = nil
        default:
            break
        }
        return p
    }

    private static func blend(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let x = Double((a >> shift) & 255), y = Double((b >> shift) & 255)
            return UInt32((x + (y - x) * t).rounded())
        }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }
}
