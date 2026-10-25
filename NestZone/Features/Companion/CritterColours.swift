import Foundation

extension CritterPlan {
    /// This species in colourway `n` (1 to 3): the same body and the same
    /// numbers with another coat, and a small marking where a breed needs one
    /// (a bib, socks, a calico's patches, a panda's eye rings). Names are in
    /// `L10n.companionColour`; the palettes and what they were drawn from are in
    /// `Docs/Companion/art/RULES.md`, section 17.
    ///
    /// Shapes are shared with the original wherever the colour needs none: the
    /// cached geometry is keyed on `key`, and a colourway only gets a key of its
    /// own when a marking changes what is built (`needsOwnShapes`), so a
    /// recolour costs no more to build than the original.
    func coloured(_ n: Int) -> CritterPlan {
        var p = self
        p.colourway = n
        func coat(_ light: UInt32, _ coat: UInt32, _ shade: UInt32, _ belly: UInt32, _ mark: UInt32) {
            (p.light, p.coat, p.shade, p.belly, p.mark) = (light, coat, shade, belly, mark)
        }
        func face(_ nose: UInt32, _ accent: UInt32, _ iris: UInt32) { (p.nose, p.accent, p.iris) = (nose, accent, iris) }
        switch (species, n) {
        // MARK: Kitten
        case (.kitten, 1): // a silver tabby
            coat(0xE4E7EC, 0xB9BFC9, 0x7A8290, 0xF6F7FA, 0x4A505C)
            face(0xE4909C, 0xF1B6BC, 0x8DBF5E)
        case (.kitten, 2): // a black cat with a white bib and socks
            coat(0x5C5662, 0x2F2B35, 0x14121A, 0xFFFFFF, 0x2F2B35)
            face(0x9C7884, 0xEDA9B0, 0xE6B422)
            (p.marks, p.bib, p.socks) = (.plain, 1.7, 0xF5F2EE)
        case (.kitten, 3): // a calico
            coat(0xFFFDF8, 0xF3EDE4, 0xC8BDB0, 0xFFFFFF, 0xD9CFC4)
            face(0xF0A0A8, 0xF6B8B4, 0xD2A02A)
            (p.marks, p.patches) = (.plain, [0xE89A48, 0x2E2A33])

        // MARK: Owl
        case (.owl, 1): // a snowy owl
            coat(0xFFFFFF, 0xF2EFEA, 0xB5AEA8, 0xFFFFFF, 0x7A736D)
            face(0x4A423C, 0x4A423C, 0xFFC53D)
        case (.owl, 2): // a barn owl
            coat(0xF0CE96, 0xD09A55, 0x98652F, 0xFDF5E8, 0x8A5A30)
            face(0xB89A6A, 0xB89A6A, 0x2A1C14)
        case (.owl, 3): // a red screech owl
            coat(0xE9915A, 0xB8562E, 0x7A3319, 0xF0D3B0, 0x4D2415)
            face(0xD9C27C, 0xD9C27C, 0xF2C230)

        // MARK: Duckling
        case (.duckling, 1): // a mallard duckling: brown back, buff face and breast
            coat(0xB8935A, 0x86663A, 0x5A4126, 0xF4DC84, 0x4F3822)
            face(0xE8873A, 0xE8873A, 0x2A1C14)
            p.face = 0xF2D96E
        case (.duckling, 2): // a black-and-white duckling
            coat(0x6B6B78, 0x2D2D36, 0x17171D, 0xFAFAFA, 0x1F1F27)
            face(0xFF9F43, 0xFF9F43, 0x2A1C14)
            p.face = 0xF6F6F6
        case (.duckling, 3): // a blue Swedish duckling
            coat(0xB8C4D6, 0x8497B3, 0x53627C, 0xE8ECF3, 0x6A7B97)
            face(0xE0A24C, 0xE0A24C, 0x2A1C14)

        // MARK: Hamster
        case (.hamster, 1): // a winter white dwarf
            coat(0xF0F2F5, 0xC9CED8, 0x8E97A8, 0xFFFFFF, 0x5E6678)
            face(0xF0A8B4, 0xF3B6BC, 0x2A1C14)
        case (.hamster, 2): // a chocolate
            coat(0x9A6A4E, 0x6E4631, 0x3F2519, 0xE6CFAE, 0x2E1A10)
            face(0xC98C86, 0xE0A59E, 0x2A1410)
        case (.hamster, 3): // a dalmatian
            coat(0xFFFBF2, 0xF6F0E4, 0xCFC3B2, 0xFFFFFF, 0xC4B8A6)
            face(0xF0A0A8, 0xF3B6BC, 0x2A1C14)
            (p.marks, p.spotTone) = (.spots, 0x3A3036)

        // MARK: Bunny
        case (.bunny, 1): // a Himalayan: white, with dark points
            coat(0xFFFFFF, 0xF4F1EC, 0xC7C0BA, 0xFFFFFF, 0x8E8078)
            face(0x6E5650, 0xE8B4B8, 0xB8505E)
            (p.earColour, p.socks) = (0x5A4A44, 0x5A4A44)
        case (.bunny, 2): // a chestnut
            coat(0xD9A06A, 0xB87840, 0x7C4A22, 0xF4E3C8, 0x6A3E1E)
            face(0xD68C84, 0xE9A898, 0x5A3420)
        case (.bunny, 3): // a lilac
            coat(0xE4DAEA, 0xBDB0C6, 0x8C7F9B, 0xF7F2F8, 0x7B6E8A)
            face(0xE4A0B2, 0xEDB6C6, 0x7B5A6A)

        // MARK: Puppy
        case (.puppy, 1): // a chocolate lab
            coat(0xA87450, 0x7C4F32, 0x4A2B19, 0xE8C9A0, 0x3A2214)
            face(0x3A2420, 0xE0808E, 0x7A4A24)
            p.earColour = 0x5E3822
        case (.puppy, 2): // a black-and-white collie
            coat(0x5A5662, 0x2C2A33, 0x141319, 0xFFFFFF, 0x1A1820)
            face(0x1F1B1E, 0xF08A9A, 0x5B3A22)
            (p.earColour, p.socks, p.bib) = (0x24222A, 0xFFFFFF, 1.35)
        case (.puppy, 3): // a cream
            coat(0xFFFFFF, 0xF3E7D2, 0xC9B392, 0xFFFFFF, 0xB49C78)
            face(0x3A2A2A, 0xF29AA6, 0x5B3A22)
            p.earColour = 0xE8D2AE

        // MARK: Fox
        case (.fox, 1): // a silver fox
            coat(0x727684, 0x34353F, 0x16171D, 0xA3A8B5, 0x0C0C10)
            face(0x15151A, 0xC9A2A6, 0xD8A93A)
            (p.socks, p.earColour, p.tailTip) = (0x15151A, 0x15151A, 0xFFFFFF)
        case (.fox, 2): // a cross fox
            coat(0xD9A56A, 0xB96B36, 0x6E3B1C, 0xEBD6B4, 0x2E1C12)
            face(0x2A201E, 0xE9A99A, 0xC8902A)
            (p.socks, p.earColour, p.tailTip) = (0x24191A, 0x24191A, 0xF6EBD8)
            p.cross = 0x1E1514
        case (.fox, 3): // a golden fox
            coat(0xFBDDA0, 0xEFB765, 0xB87D2C, 0xFFF8EA, 0x8A5A22)
            face(0x3A2A22, 0xF1B4A0, 0xD9A030)
            (p.socks, p.earColour, p.tailTip) = (0x8A5A2A, 0x8A5A2A, 0xFFFFFF)

        // MARK: Hedgehog
        case (.hedgehog, 1): // an albino
            coat(0xFFF3E0, 0xF0DCC0, 0xC9AE8A, 0xFFF0E6, 0xD8C0A0)
            face(0xF0A8A8, 0xF6BAB2, 0x9A2C3C)
        case (.hedgehog, 2): // a cinnamon
            coat(0xE0A878, 0xB67A4A, 0x79492A, 0xF4DDB8, 0x5A3820)
            face(0x7A4A3A, 0xF0B2A6, 0x2A1C14)
        case (.hedgehog, 3): // salt and pepper
            coat(0xD8D8DC, 0x8E8C96, 0x4A4852, 0xF2EEEA, 0x2C2A32)
            face(0x3A3238, 0xF0B2A6, 0x2A1C14)

        // MARK: Deer
        case (.deer, 1): // a sika
            coat(0xA5724A, 0x7A4E32, 0x45281A, 0xF5E6D0, 0x3A2216)
            face(0x2A1F1C, 0xF2BDB0, 0x2A1A12)
            p.socks = 0x2E1E16
        case (.deer, 2): // a fallow
            coat(0xF2D199, 0xDDA962, 0xA06C2E, 0xFFF8EA, 0x8A5A22)
            face(0x2E2321, 0xF2BDB0, 0x3A2418)
            p.socks = 0x8A5E36
        case (.deer, 3): // a white fallow
            coat(0xFFFFFF, 0xF1ECE6, 0xB8B4C4, 0xFFFFFF, 0xC7C0CC)
            face(0x6B5A62, 0xF2C8C8, 0x3A2418)
            (p.socks, p.spotTone) = (0xC5BCC8, 0xD9D1DE)

        // MARK: Snow fox
        case (.snowFox, 1): // a blue morph, the arctic at dusk
            coat(0xA9B4CC, 0x7C89A6, 0x465270, 0xC6CEDF, 0x38435E)
            face(0x20202A, 0xE0B0B8, 0x6FA6D6)
            (p.socks, p.earColour, p.tailTip) = (0x38435E, 0x38435E, 0xC6CEDF)
        case (.snowFox, 2): // a summer coat
            coat(0xD2BFA6, 0xA38B73, 0x6C5A4A, 0xE9DDCD, 0x4A3C32)
            face(0x2B2420, 0xE0B0A0, 0xC89A3A)
            (p.socks, p.earColour, p.tailTip) = (0x5C4B3F, 0x5C4B3F, 0xD9CDBE)
        case (.snowFox, 3): // a lilac pearl
            coat(0xE8D6EC, 0xC4A9D1, 0x8A6FA3, 0xF4EBF6, 0x5C4A78)
            face(0x2B2434, 0xEDB6C8, 0x7FB0D8)
            (p.socks, p.earColour, p.tailTip) = (0x6F5A8A, 0x6F5A8A, 0xF1E6F5)

        // MARK: Polar cub
        case (.polarCub, 1): // a cinnamon bear
            coat(0xD9A877, 0xB07B4A, 0x76492A, 0xE8CBA0, 0x6A4024)
            face(0x3A2A26, 0xD9A090, 0x2A1C14)
        case (.polarCub, 2): // a panda
            coat(0xFFFFFF, 0xF6F4F0, 0xBDB8B8, 0xFFFFFF, 0x8C8586)
            face(0x1E1E22, 0xDDB5AA, 0x1E1A18)
            (p.earColour, p.socks, p.eyePatch) = (0x26252B, 0x26252B, 0x26252B)
        case (.polarCub, 3): // a black bear with a tan muzzle
            coat(0x55505A, 0x2B282F, 0x121015, 0xC9A26C, 0x15131A)
            face(0x15131A, 0xC99A80, 0x4A2E1A)

        // MARK: Penguin
        case (.penguin, 1): // a little blue penguin
            coat(0x7FB0D8, 0x4F82B0, 0x2A4A72, 0xF8FBFE, 0x23405E)
            face(0x5A6678, 0x5A6678, 0x2A1C14)
            p.gold = 0xB6D9EE
        case (.penguin, 2): // a rockhopper, red-eyed, with a yellow crest
            face(0xFF7A3C, 0xFF7A3C, 0xC8302A)
            p.gold = 0xF7D84A
        case (.penguin, 3): // an isabelline, brown where it should be black
            coat(0xC9A87E, 0xA2825F, 0x6A5038, 0xFBF4E8, 0x4A3826)
            face(0xFF9A3C, 0xFF9A3C, 0x4A2E1A)
            p.gold = 0xE8C48A

        // MARK: Turtle
        case (.turtle, 1): // a Hermann's tortoise, golden scutes in dark seams
            coat(0xDCC68A, 0xC2A66A, 0x8A7140, 0xE9D9A8, 0x6A5530)
            p.nose = 0x6A5530
            (p.shell, p.plates) = (0x4A3A1E, 0xDDB852)
        case (.turtle, 2): // a painted turtle, red at the rim
            coat(0x8FAE5C, 0x5E7C3A, 0x36502A, 0xE8C34A, 0x36502A)
            p.nose = 0x36502A
            (p.shell, p.plates, p.iris) = (0x2C3B2E, 0x8FA84A, 0x2A1E12)
        case (.turtle, 3): // an albino, pink-eyed
            coat(0xFAF2CC, 0xF0E4B0, 0xC8B87A, 0xFFF4D8, 0xC8B87A)
            p.nose = 0xE8A0A0
            (p.shell, p.plates, p.iris) = (0xD9BE78, 0xF6E7B0, 0xB0303C)

        // MARK: Goldfish
        case (.goldfish, 1): // a calico fantail
            coat(0xFFF6EE, 0xF4ECE6, 0xBFB4B4, 0xFFFFFF, 0xC8B8B8)
            p.patches = [0xFF7A2E, 0x2B2A38]
        case (.goldfish, 2): // a white oranda with a red cap
            coat(0xFFFFFF, 0xF8F4EE, 0xC4C2D0, 0xFFFFFF, 0xD8D2D2)
            p.face = 0xE2381E
        case (.goldfish, 3): // a black moor
            coat(0x5A5470, 0x262230, 0x0E0C14, 0x4A4458, 0x14121C)
            p.iris = 0x6A4A2A

        default:
            break
        }
        if needsOwnShapes(than: self, p) { p.key = "\(species.rawValue)#\(n)" }
        return p
    }

    /// Whether a recoloured plan has a marking that changes what is built: a
    /// bib, socks, ear colour, patches, spots, a face or eye rings.
    private func needsOwnShapes(than original: CritterPlan, _ p: CritterPlan) -> Bool {
        p.patches != original.patches || p.eyePatch != original.eyePatch || p.face != original.face || p.bib != original.bib
            || (p.socks == nil) != (original.socks == nil) || (p.earColour == nil) != (original.earColour == nil)
            || p.marks != original.marks || p.cross != original.cross
    }
}
