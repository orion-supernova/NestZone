import Foundation

extension PlantPlan {
    /// This species in colourway `n` (1 to 3): the same plant, grown the same
    /// way, in other colours: the five greens, the petals, and where a cultivar
    /// is known for it a pattern (a variegated leaf, a flamed tulip). Shapes are
    /// never changed here. Names are in `ColourwayNames`; what each was drawn
    /// from is in `Docs/Companion/art/RULES.md`, section 17.
    func coloured(_ species: Species, _ n: Int) -> PlantPlan {
        var p = self
        p.colourway = n
        func leaves(_ ramp: [UInt32]) { p.ramp = ramp }
        func petals(_ deep: UInt32, _ mid: UInt32, _ pale: UInt32, heart: UInt32? = nil, tint: UInt32? = nil, anther: UInt32? = nil, streak: UInt32? = nil) {
            guard var f = p.flower else { return }
            (f.deep, f.mid, f.pale) = (deep, mid, pale)
            if let heart { f.heart = heart }
            if let tint { f.tint = tint }
            if let anther { f.anther = anther }
            if let streak { f.streak = streak }
            p.flower = f
        }
        switch (species, n) {
        // MARK: Sunflower
        case (.sunflower, 1): // 'Velvet Queen'
            petals(0x4A0A10, 0x7A1418, 0xB8432C, heart: 0x24120C, anther: 0xC8681C)
        case (.sunflower, 2): // a lemon sunflower
            petals(0xE2C020, 0xF6E24A, 0xFFF6A6, heart: 0x4A2E10, anther: 0xE8C830)
        case (.sunflower, 3): // an Italian white
            petals(0xD9CFA8, 0xF4EEDA, 0xFFFFFF, heart: 0x3A2A1A, anther: 0xC8A050)

        // MARK: Basil
        case (.basil, 1): // 'Dark Opal', purple
            leaves([0x2A1233, 0x4A2158, 0x6A3A7C, 0x9560A6, 0xD6A8DE])
            petals(0xE0A0C8, 0xF6D2E6, 0xFFF0F8, heart: 0x8A3C6A)
            p.stemTint = 0x5A2A66
        case (.basil, 2): // lemon basil
            leaves([0x3A5518, 0x5A7E28, 0x84A838, 0xAECB52, 0xDCEC8C])
        case (.basil, 3): // a variegated basil, cream at the edge
            leaves([0x1F4A32, 0x2E7040, 0x479A4C, 0x76C066, 0xC4EBA4])
            p.variegation = Variegation(pattern: .margin, tone: 0xFFF6D6)

        // MARK: Cactus
        case (.cactus, 1): // a blue columnar cactus, yellow-flowered
            leaves([0x1B3F4A, 0x2A5E66, 0x3F8283, 0x6AA8A3, 0xB4DAD2])
            petals(0xE8A010, 0xFFD23A, 0xFFF0A0, heart: 0xFFF6C0)
            p.spine = 0xD8DCE0
        case (.cactus, 2): // a golden barrel, orange-flowered
            leaves([0x3F5A1E, 0x5E8230, 0x86A845, 0xB0CC6A, 0xDCEBA8])
            petals(0xD8480E, 0xFF7A28, 0xFFC18A, heart: 0xFFE060)
            p.spine = 0xE8B84A
        case (.cactus, 3): // a purple prickly pear
            leaves([0x3A3358, 0x56507A, 0x7A7AA0, 0xA5A8C6, 0xD6D8EA])
            petals(0xA01E78, 0xE84AA8, 0xFFA8D8, heart: 0xFFD65A)
            p.spine = 0xF6E2C6

        // MARK: Daisy
        case (.daisy, 1): // an English pink
            petals(0xE8789E, 0xF6A5C0, 0xFFDDE8, heart: 0xF7C21B, tint: 0xD84A7E)
        case (.daisy, 2): // a golden marguerite
            petals(0xE09A10, 0xFFC62E, 0xFFE88A, heart: 0x7A4A1A, tint: 0xF08A20, anther: 0x5A3010)
        case (.daisy, 3): // a blue felicia
            petals(0x6A82D8, 0x9CB4F2, 0xE0E8FF, heart: 0xF7C21B, tint: 0x7C5CC8)

        // MARK: Mint
        case (.mint, 1): // chocolate mint
            leaves([0x16200F, 0x2C3A1A, 0x4A5A2A, 0x6E7A3E, 0xA8AC6C])
            p.stemTint = 0x5A3A2A
        case (.mint, 2): // a variegated pineapple mint
            leaves([0x1F5A34, 0x31804A, 0x4DA85A, 0x80CC78, 0xC8F0A8])
            p.variegation = Variegation(pattern: .margin, tone: 0xFFF3C8)
            p.stemTint = 0x6A4A3A
        case (.mint, 3): // a woolly apple mint
            leaves([0x2A4A3C, 0x426A56, 0x62907A, 0x8CB49C, 0xC4DCC8])
            petals(0xC27AA8, 0xE2B0CC, 0xF6E4EE)
            p.stemTint = 0

        // MARK: Rosemary
        case (.rosemary, 1): // a pink-flowered rosemary
            petals(0xC85A8A, 0xE89AC0, 0xFBD8EA, heart: 0xFFF0F6)
        case (.rosemary, 2): // a white-flowered one, silvery
            leaves([0x2E5646, 0x4A7A64, 0x76A38A, 0xA8C8A8, 0xE0EEDC])
            petals(0xD8E0D8, 0xF2F6F2, 0xFFFFFF, heart: 0xFFFFFF)
        case (.rosemary, 3): // a golden rosemary
            leaves([0x4A5A22, 0x6E8334, 0x9AAE48, 0xC6D470, 0xEEF2A8])

        // MARK: Snake plant
        case (.snakePlant, 1): // a silvery 'Moonshine'
            leaves([0x3C5A50, 0x5E8474, 0x8DB2A0, 0xBCD6C6, 0xE6F2EA])
            p.spine = 0xDDE8D8
        case (.snakePlant, 2): // a dark one edged in gold
            leaves([0x050B09, 0x0A1612, 0x12281F, 0x1C3F31, 0x4C7A64])
            p.spine = 0xC8A030
        case (.snakePlant, 3): // a lime 'Hahnii'
            leaves([0x3A5A1A, 0x5A8428, 0x86AE3A, 0xB4D45A, 0xE6F2A0])
            p.spine = 0xFFF4A0

        // MARK: Fern
        case (.fern, 1): // a silver lady
            leaves([0x2A4A4A, 0x426E6C, 0x6A9A94, 0x9CC4BC, 0xD8EEE8])
        case (.fern, 2): // a lemon-button, lime-gold
            leaves([0x3E5A1C, 0x5E8228, 0x8CAE38, 0xBCD85C, 0xF0F6A0])
        case (.fern, 3): // an autumn fern, copper
            leaves([0x2E1A14, 0x5A2C1E, 0x8A4528, 0xB26A3A, 0xD9A064])

        // MARK: Lavender
        case (.lavender, 1): // a white lavender
            petals(0xD8D6E6, 0xF2F0FA, 0xFFFFFF, heart: 0xB8B4D0, anther: 0xFFFFFF)
        case (.lavender, 2): // a pink lavender
            petals(0xC0508A, 0xE88CBE, 0xFAC8E4, heart: 0x8A2A5E, anther: 0xFFE4F2)
        case (.lavender, 3): // a deep 'Hidcote'
            petals(0x1E1A6E, 0x3A38A8, 0x8A86E0, heart: 0x12104A, anther: 0xD0D0FF)

        // MARK: Peony
        case (.peony, 1): // a white 'Festiva Maxima', flecked crimson
            petals(0xE6DEE0, 0xF8F4F4, 0xFFFFFF, heart: 0xF5C84B, tint: 0xC23C5E)
        case (.peony, 2): // a 'Coral Charm'
            petals(0xE8603A, 0xFF9068, 0xFFD2B0, heart: 0xF5C84B, tint: 0xC8401E)
        case (.peony, 3): // a deep crimson
            petals(0x8A1038, 0xC42060, 0xE86A98, heart: 0xF0C040, tint: 0x5A0A24)

        // MARK: Monstera
        case (.monstera, 1): // an albo variegata, white-splashed
            leaves([0x0E3228, 0x174C38, 0x226A42, 0x3A8A50, 0x7CBF7E])
            p.variegation = Variegation(pattern: .albo, tone: 0xF8F4DC)
        case (.monstera, 2): // a Thai constellation, flecked cream
            p.variegation = Variegation(pattern: .flecks, tone: 0xFFF4C0)
        case (.monstera, 3): // a mint-green one
            leaves([0x1F5A44, 0x2F8060, 0x4DA67C, 0x7CCDA2, 0xBEEED2])

        // MARK: Rose
        case (.rose, 1): // a white rose
            petals(0xD8D0D0, 0xF6F0EE, 0xFFFFFF, heart: 0xE0D4C0)
        case (.rose, 2): // a peach rose
            petals(0xE07A52, 0xF8A67E, 0xFFD9BE, heart: 0xC05A3A)
        case (.rose, 3): // a deep burgundy
            petals(0x3E0614, 0x6E0E2A, 0xB03058, heart: 0x24030C)

        // MARK: Orchid
        case (.orchid, 1): // a butter-yellow phalaenopsis with a red lip
            petals(0xE8A818, 0xFFE27A, 0xFFF6C0, heart: 0xC8341E, tint: 0xE8782A)
        case (.orchid, 2): // a violet one
            petals(0x5A2A9A, 0xB890E8, 0xE8D8FA, heart: 0x3A1A78, tint: 0x8E5AD0)
        case (.orchid, 3): // a pure white, green at the throat
            petals(0xD8E8D0, 0xFFFFFF, 0xFFFFFF, heart: 0x9CCB6A, tint: 0xC8E8B0, anther: 0xE8E080)

        // MARK: Bonsai
        case (.bonsai, 1): // autumn gold
            leaves([0x5A3A10, 0x8A5A14, 0xC4881E, 0xE8B440, 0xFFE48A])
        case (.bonsai, 2): // in blossom
            leaves([0x6A2E4A, 0xA04C74, 0xD880A4, 0xF2B2CC, 0xFFE2EC])
        case (.bonsai, 3): // a silvery olive
            leaves([0x2E4A40, 0x48685A, 0x6E8E7C, 0x9EB8A4, 0xD4E2D2])

        // MARK: Maple
        case (.maple, 1): // golden
            leaves([0x6A4A08, 0xA07410, 0xD8A41C, 0xF4CC3C, 0xFFF0A0])
        case (.maple, 2): // spring green
            leaves([0x1E4A2A, 0x2E7038, 0x4E9A48, 0x8CC468, 0xE4F0A8])
        case (.maple, 3): // a purple 'Bloodgood'
            leaves([0x2A0C20, 0x48142E, 0x6E1E3E, 0x9A3454, 0xD87894])
            p.barkTone = 0x4A2E3A

        // MARK: Pumpkin
        case (.pumpkin, 1): // a white 'Lumina'
            p.fruitTones = [0xB8B0A0, 0xE8E2D4, 0xFFFBF2, 0xFFFFFF]
        case (.pumpkin, 2): // a blue-grey 'Jarrahdale'
            p.fruitTones = [0x3E5560, 0x6E8E9A, 0xA2BEC6, 0xD4E4E8]
        case (.pumpkin, 3): // a deep red 'Cinderella'
            p.fruitTones = [0x6E0E0C, 0xB01C14, 0xE04A2C, 0xFF9A78]

        // MARK: Pine
        case (.pine, 1): // a blue spruce
            leaves([0x1E3A4C, 0x34607A, 0x5890AC, 0x8CBCD4, 0xD4EAF4])
        case (.pine, 2): // a golden pine
            leaves([0x4A4A12, 0x7A7A1C, 0xAEAA2C, 0xDCD456, 0xFFF8A0])
        case (.pine, 3): // frosted
            leaves([0x2A4A44, 0x4A7468, 0x7CA498, 0xB4D4CA, 0xF2FAF8])

        // MARK: Snowdrop
        case (.snowdrop, 1): // a yellow snowdrop
            petals(0xE8D88A, 0xF6EEB4, 0xFFFCE0, heart: 0xD8B82A, anther: 0xD4B030)
        case (.snowdrop, 2): // a green-tipped 'Viridapice'
            petals(0xC4D8C0, 0xF1F7F2, 0xFFFFFF, heart: 0x4E9A3A, anther: 0xE0D060)
        case (.snowdrop, 3): // a glaucous 'Elwesii'
            leaves([0x1E4450, 0x2E6676, 0x4A8A9C, 0x7CB4C4, 0xC8E4EC])
            petals(0xC4D6DA, 0xF2F8FA, 0xFFFFFF, heart: 0x5C9A48)

        // MARK: Tulip
        case (.tulip, 1): // a flamed Rembrandt
            petals(0xC8C0BC, 0xF6F2EC, 0xFFFFFF, heart: 0x2A1A10, tint: 0xFFFFFF, streak: 0xC8203A)
        case (.tulip, 2): // a 'Queen of Night'
            petals(0x1A0A22, 0x3A1450, 0x7A3C8E, heart: 0x0A0410, tint: 0x5A2470)
        case (.tulip, 3): // an 'Apricot Beauty'
            petals(0xE8805A, 0xF8A888, 0xFFD8C0, heart: 0x3A2A1A, tint: 0xF6C070)

        default:
            break
        }
        return p
    }
}
