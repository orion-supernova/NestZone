import Foundation

/// The colourways of the six trees: what each is painted with besides the
/// shapes, which are never touched (a colourway must not move a household's tree).
///
/// Two layers. `Canopy.Kind.recolour` changes the species' own table (the five
/// leaf tones, the bark, the blossom, the crop), which every painter already
/// reads through `Canopy.Tones`. What a painter keeps for itself (the skins a
/// fruit goes through as it ripens, the inside of a cut fruit, the fruit on the
/// soil) comes from the sets below, indexed by the canopy's colourway. Index 0 is
/// the original and holds the values the painters used to hold themselves, so
/// the original is unchanged.
enum TreeColours {
    /// One ripeness of skin, light to shade, as hex.
    struct Skin: Sendable {
        var hi, mid, shade: UInt32
        init(_ hi: UInt32, _ mid: UInt32, _ shade: UInt32) { (self.hi, self.mid, self.shade) = (hi, mid, shade) }
    }

    // MARK: Pomegranate

    struct PomegranateSet: Sendable {
        var green, blush: Skin
        /// The three ways it ripens.
        var ripe: [Skin]
        /// The arils of the cut fruit, in two jewel tones (light to dark), and the one that rolled out.
        var deeper, lighter, aril: Skin
        /// The inside of the cut fruit's cavity and the pith around it.
        var inside, pith: UInt32
        /// A fruit on the soil.
        var dropped: (sk: UInt32, dk: UInt32)
    }

    private static let pomegranates: [PomegranateSet] = [
        PomegranateSet(
            green: Skin(0xD9E49C, 0x8DB45A, 0x3C6A3A), blush: Skin(0xFCEBB0, 0xF0B062, 0xB8503A),
            ripe: [Skin(0xF07C84, 0xCD2C3F, 0x6C1223), Skin(0xF8A4AE, 0xDC536E, 0x8C2346), Skin(0xFCDCA0, 0xEE8E4C, 0xB93C2C)],
            deeper: Skin(0xE8405C, 0xB01236, 0x6A0A22), lighter: Skin(0xFF6F82, 0xD21E41, 0x8A0E2C), aril: Skin(0xFF7A8C, 0xB8183A, 0x7C0C26),
            inside: 0x3F0818, pith: 0xF2D2C2, dropped: (0x9A3A44, 0x5A1E2A)),
        // A white-flowered one, its fruit a blushed rose and its arils pale pink.
        PomegranateSet(
            green: Skin(0xE4ECB0, 0x9CC068, 0x4A7A44), blush: Skin(0xFFF2D0, 0xF4C890, 0xC0705A),
            ripe: [Skin(0xFFDCE0, 0xF0A0B0, 0xB04A66), Skin(0xFFE8E0, 0xF6B8A8, 0xB85A48), Skin(0xFFF0D0, 0xF8D090, 0xC8803A)],
            deeper: Skin(0xF29AB0, 0xD86A8C, 0x9A3050), lighter: Skin(0xFFC4D0, 0xF090A8, 0xB8506C), aril: Skin(0xFFC4D0, 0xE0809A, 0xA84060),
            inside: 0x6A2A3C, pith: 0xFFEEE4, dropped: (0xD89AA4, 0x8A4A5A)),
        // A dwarf with dark fruit: the skin nearly black wine, the arils deep ruby.
        PomegranateSet(
            green: Skin(0xCADC94, 0x7AA654, 0x34603A), blush: Skin(0xE8C0A0, 0xB86A5C, 0x6A2A3A),
            ripe: [Skin(0xB05A7A, 0x6E1E44, 0x2A0A1C), Skin(0xA04A6E, 0x5A1438, 0x220814), Skin(0xC06A7A, 0x7A2036, 0x300A14)],
            deeper: Skin(0x6A1030, 0x420820, 0x260414), lighter: Skin(0x8E1E48, 0x5A0C30, 0x34081C), aril: Skin(0xA02850, 0x640C34, 0x3A0620),
            inside: 0x2A0410, pith: 0xE0B8B8, dropped: (0x5A2A44, 0x2A1020)),
        // A golden one: yellow skin, amber arils.
        PomegranateSet(
            green: Skin(0xE4EC9C, 0xA0BC58, 0x4A7A38), blush: Skin(0xFFF4B8, 0xF4D070, 0xC89030),
            ripe: [Skin(0xFFF0A0, 0xF2C23A, 0xB8801A), Skin(0xFFF4B8, 0xF6D058, 0xC08C20), Skin(0xFFE8A0, 0xF0B030, 0xB07010)],
            deeper: Skin(0xE8A030, 0xC07818, 0x7A4A10), lighter: Skin(0xFFD060, 0xE8A828, 0x9A6414), aril: Skin(0xFFD060, 0xD89A20, 0x8A5A10),
            inside: 0x5A3410, pith: 0xFFF0C8, dropped: (0xD8A83A, 0x8A5A18)),
    ]

    static func pomegranate(_ colourway: Int) -> PomegranateSet { pomegranates[min(max(colourway, 0), 3)] }

    // MARK: Lemon

    struct LemonSet: Sendable {
        var green, pale: Skin
        var ripe: [Skin]
        /// The cut lemon: the rind's pith, the flesh in three tones, the drop on its rind.
        var pith: UInt32
        var juice: Skin
        var vesicles, drop: UInt32
        /// A lemon on the soil.
        var dropped: (sk: UInt32, dk: UInt32)
    }

    private static let lemons: [LemonSet] = [
        LemonSet(
            green: Skin(0xE4EEA6, 0x9CBF4A, 0x4A7A2E), pale: Skin(0xF4F4A8, 0xD5D545, 0x86982A),
            ripe: [Skin(0xFFF7B4, 0xF7D234, 0xC48A12), Skin(0xF6F5A0, 0xE6DA3A, 0x9A9A1C), Skin(0xFFEFA0, 0xF2BE2A, 0xB97A10)],
            pith: 0xFFF4CE, juice: Skin(0xFFF3A8, 0xF9DC5E, 0xE8B536), vesicles: 0xFFFAD0, drop: 0xF8E27A, dropped: (0xC7B038, 0x7A6A1C)),
        // A pink variegated eureka: the rind striped green and cream, the flesh pink.
        LemonSet(
            green: Skin(0xDCEAB0, 0x8EB85A, 0x44743A), pale: Skin(0xEEF2B8, 0xC4D078, 0x7C9A3C),
            ripe: [Skin(0xF2F0B0, 0xCCD468, 0x7A9A30), Skin(0xF6F2BC, 0xDCD878, 0x8AA838), Skin(0xF8EEB4, 0xE4D070, 0xA08A28)],
            pith: 0xFFF0DC, juice: Skin(0xFFD0DC, 0xF7A0B8, 0xE07090), vesicles: 0xFFE4EA, drop: 0xF8B0C0, dropped: (0xC8D064, 0x7A8A2C)),
        // A lime: green all the way.
        LemonSet(
            green: Skin(0xE4F0A8, 0x8CC050, 0x3E7228), pale: Skin(0xE0EE9C, 0x9CCB48, 0x4E7E24),
            ripe: [Skin(0xE4F0A0, 0x9CCB48, 0x4E7E24), Skin(0xD8EC98, 0x84BC40, 0x3E7220), Skin(0xECF4B0, 0xA8D054, 0x5A8A2C)],
            pith: 0xF4FADC, juice: Skin(0xF2FAC8, 0xD8EC88, 0xA8C84C), vesicles: 0xF8FCE0, drop: 0xDCEE8C, dropped: (0x8CC050, 0x3E6A24)),
        // A blood orange's lemon: orange rind flushed red, deep crimson flesh.
        LemonSet(
            green: Skin(0xE4EEA6, 0x9CBF4A, 0x4A7A2E), pale: Skin(0xFFE0A0, 0xF0B040, 0xB87A1C),
            ripe: [Skin(0xFFC890, 0xF0803A, 0xA83A18), Skin(0xFFB890, 0xE8602C, 0x9A2A14), Skin(0xFFD0A0, 0xF49048, 0xB04A1C)],
            pith: 0xFFE8CC, juice: Skin(0xF07080, 0xC8283C, 0x8A0E24), vesicles: 0xFFB0B8, drop: 0xE05068, dropped: (0xE0702C, 0x8A3410)),
    ]

    static func lemon(_ colourway: Int) -> LemonSet { lemons[min(max(colourway, 0), 3)] }

    // MARK: Cherry and olive: the skins a fruit goes through, with where in the ripening each is

    private static let cherries: [[(at: Double, skin: Skin)]] = [
        [(0, Skin(0xE2E890, 0x9FB650, 0x4E6B2A)), (0.45, Skin(0xFFC89A, 0xE8785A, 0xA63A2E)), (1, Skin(0xFF8A94, 0xC41A36, 0x5A0A1A))],
        // Yoshino: a dark red cherry as ever, a little darker.
        [(0, Skin(0xE2E890, 0x9FB650, 0x4E6B2A)), (0.45, Skin(0xFFC0A0, 0xD8604C, 0x8E2A24)), (1, Skin(0xF0707E, 0x9E1230, 0x440814))],
        // Weeping: a golden-red 'Rainier' ripening to blush.
        [(0, Skin(0xE8EC9C, 0xB0C25C, 0x5A7430)), (0.45, Skin(0xFFE8A8, 0xF4C060, 0xC8803A)), (1, Skin(0xFFC8A0, 0xE8805A, 0xA8402E))],
        // Kanzan: nearly black.
        [(0, Skin(0xE0E49A, 0x98AE58, 0x4E6B2E)), (0.45, Skin(0xE8A090, 0xB04050, 0x701A28)), (1, Skin(0xB86478, 0x5A0C28, 0x24040E))],
    ]

    static func cherry(_ colourway: Int) -> [(at: Double, skin: Skin)] { cherries[min(max(colourway, 0), 3)] }

    struct OliveSet: Sendable {
        var stops: [(at: Double, skin: Skin)]
        var dropped: (sk: UInt32, dk: UInt32)
    }

    private static let olives: [OliveSet] = [
        OliveSet(stops: [(0, Skin(0xC9D98A, 0x7E9A3E, 0x3E5A22)), (0.34, Skin(0xE3E39A, 0xB7B85A, 0x6E7330)),
                         (0.62, Skin(0xC58AA6, 0x8A4A72, 0x4A2448)), (1, Skin(0x8F7AA8, 0x3E2C4C, 0x1C1226))], dropped: (0x6E4F7C, 0x2A1A36)),
        // A green olive that stays green, as a Manzanilla does.
        OliveSet(stops: [(0, Skin(0xC9D98A, 0x7E9A3E, 0x3E5A22)), (0.5, Skin(0xD8E48C, 0x9AB24A, 0x56702A)),
                         (1, Skin(0xBCD27C, 0x6E8E34, 0x34501C))], dropped: (0x7E9A3E, 0x3E5A22)),
        // A golden-bronze one.
        OliveSet(stops: [(0, Skin(0xC9D98A, 0x7E9A3E, 0x3E5A22)), (0.34, Skin(0xEEDC9A, 0xC8B050, 0x7C6A2C)),
                         (0.62, Skin(0xF0C48A, 0xC88444, 0x7A4420)), (1, Skin(0xE8B070, 0xB86A38, 0x6A3418))], dropped: (0xB86A38, 0x6A3418)),
        // A ruby one.
        OliveSet(stops: [(0, Skin(0xC9D98A, 0x7E9A3E, 0x3E5A22)), (0.34, Skin(0xE3E39A, 0xB7B85A, 0x6E7330)),
                         (0.62, Skin(0xE8909C, 0xC03A5A, 0x6A1A36)), (1, Skin(0xE08A9A, 0xA82444, 0x4A0A1E))], dropped: (0xA82444, 0x4A0A1E)),
    ]

    static func olive(_ colourway: Int) -> OliveSet { olives[min(max(colourway, 0), 3)] }
}

// MARK: - The species' own table

extension Canopy.Kind {
    /// Paints the species in colourway `n` (1 to 3): the leaves, the wood, the
    /// blossom and the fruit. The form and the crown are left alone, because a
    /// colourway must not move a household's tree.
    mutating func recolour(_ species: Species, _ n: Int) {
        func flower(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ glow: UInt32, anther: UInt32? = nil) {
            (self.flower.a, self.flower.b, self.flower.c, self.flower.glow) = (a, b, c, glow)
            if let anther { self.flower.anther = anther }
        }
        func crop(_ a: UInt32, _ shade: UInt32, _ hi: UInt32, _ crown: UInt32) {
            guard var crop = self.crop else { return }
            (crop.a, crop.shade, crop.hi, crop.crown) = (a, shade, hi, crown)
            self.crop = crop
        }
        switch (species, n) {
        // MARK: Magnolia
        case (.magnolia, 1): // a white magnolia
            flower(0xF4F0EA, 0xFFFFFF, 0xD8C8B8, 0xFFFFFF)
        case (.magnolia, 2): // 'Black Tulip', deep wine
            ramp = [0x1E3A44, 0x2A5148, 0x3A6E4A, 0x5C8E4E, 0x9CBE70]
            flower(0x8E2A6A, 0xC5589A, 0x5E1448, 0xF0B8DC)
        case (.magnolia, 3): // a yellow magnolia
            ramp = [0x2A4A2A, 0x3A6A32, 0x56883A, 0x86AE4E, 0xC8DE8A]
            flower(0xF2D86A, 0xFFF1A8, 0xC99A1C, 0xFFF6C8, anther: 0xE8A02C)

        // MARK: Cherry
        case (.cherry, 1): // a white Yoshino
            bloomRamp = [0x7A6E78, 0xB8AEB8, 0xE6DEE6, 0xF8F4F8, 0xFFFFFF]
            flower(0xF6F2F4, 0xFFFFFF, 0xE8B8C4, 0xFFFFFF)
        case (.cherry, 2): // a weeping pink
            bloomRamp = [0x8A3A60, 0xC8608C, 0xEE8EB4, 0xF8B8D0, 0xFFE0EC]
            flower(0xF6B4CC, 0xFFE0EC, 0xD03C78, 0xFFE8F0)
        case (.cherry, 3): // a deep Kanzan
            bloomRamp = [0x6A1A40, 0xA03468, 0xCC5C90, 0xE488B0, 0xF8B8D4]
            flower(0xD8508C, 0xF29AC0, 0x8E1244, 0xFFC8E0)

        // MARK: Pomegranate
        case (.pomegranate, 1): // white-flowered
            flower(0xF2E8DC, 0xFFFFFF, 0xD8B8A8, 0xFFFFFF)
            crop(0xF0A0B0, 0xB04A66, 0xFFDCE0, 0xB05A68)
        case (.pomegranate, 2): // a dwarf with dark fruit
            ramp = [0x10282A, 0x1A4034, 0x265A3C, 0x3A7842, 0x86B466]
            crop(0x6E1E44, 0x2A0A1C, 0xB05A7A, 0x4A1230)
        case (.pomegranate, 3): // golden
            flower(0xF2B52C, 0xFFD87A, 0xC27A10, 0xFFF0B8, anther: 0xFFE06A)
            crop(0xF2C23A, 0xB8801A, 0xFFF0A0, 0x9A7A2A)

        // MARK: Azalea
        case (.azalea, 1): // a white azalea with a green throat
            flower(0xF0EDEA, 0xFFFFFF, 0xC8E0B0, 0xFFFFFF)
        case (.azalea, 2): // a flame-orange one
            flower(0xF0622C, 0xFFA666, 0xB8300E, 0xFFD4B0, anther: 0xFFE08A)
        case (.azalea, 3): // a violet one
            flower(0x8A5FC8, 0xC8A8EE, 0x5A2E9A, 0xE8DAFF)

        // MARK: Lemon
        case (.lemon, 1): // a pink variegated eureka
            ramp = [0x1E4A40, 0x2A6A4A, 0x3D8A4C, 0x62A854, 0xB8D480]
            flower(0xFFF2F0, 0xFFFAF8, 0xE8A0B8, 0xFFF0F2)
            crop(0xCCD468, 0x7A9A30, 0xF2F0B0, 0x9AAA44)
        case (.lemon, 2): // a lime
            ramp = [0x1A4A34, 0x246A3C, 0x34883E, 0x54A446, 0xA4D468]
            crop(0x9CCB48, 0x4E7E24, 0xE4F0A0, 0x6E9A3A)
        case (.lemon, 3): // a lemon with an orange's blush
            ramp = [0x1E4A3C, 0x2A6A45, 0x3D8746, 0x5FA24A, 0xB0D06E]
            flower(0xFFF0E8, 0xFFFAF4, 0xE8A07C, 0xFFF0E4, anther: 0xE8802C)
            crop(0xF0803A, 0xA83A18, 0xFFC890, 0x8AA038)

        // MARK: Olive
        case (.olive, 1): // a green Manzanilla
            ramp = [0x2E4A36, 0x46684A, 0x6A8C64, 0x9AB88C, 0xDCE8D4]
            crop(0x7E9A3E, 0x3E5A22, 0xC9D98A, 0x5A6A2A)
        case (.olive, 2): // a golden-bronze one
            ramp = [0x3A4A38, 0x566A4C, 0x7C9068, 0xAAB894, 0xE4EAD8]
            crop(0xB86A38, 0x6A3418, 0xE8B070, 0x6A5A2A)
        case (.olive, 3): // a silver-blue one with ruby fruit
            ramp = [0x2F4650, 0x46606E, 0x6A8694, 0x9CB4BE, 0xDCE8EC]
            crop(0xA82444, 0x4A0A1E, 0xE08A9A, 0x4D5A3A)

        default:
            break
        }
    }
}
