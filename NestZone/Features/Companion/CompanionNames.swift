import SwiftUI

// What everything in the companion is called, in one place. The feature's own
// name ("Nestie") is `L10n.companionBrand`, so changing it is one string.

extension Species {
    public var title: LocalizedStringResource {
        switch self {
        case .magnolia: L10n.speciesMagnolia
        case .cherry: L10n.speciesCherry
        case .pomegranate: L10n.speciesPomegranate
        case .azalea: L10n.speciesAzalea
        case .lemon: L10n.speciesLemon
        case .olive: L10n.speciesOlive
        case .duckling: L10n.speciesDuckling
        }
    }
}

extension CompanionMath {
    /// "Sapling", "Little one" — or "Grown" once it is ready.
    static func stageTitle(_ stage: Int, isPet: Bool, isReady: Bool) -> LocalizedStringResource {
        if isReady { return isPet ? L10n.petStageGrown : L10n.plantStageGrown }
        if isPet {
            return switch stage {
            case 0: L10n.petStageEgg
            case 1: L10n.petStageWobbly
            case 2: L10n.petStageHatchling
            case 3: L10n.petStageBaby
            case 4: L10n.petStageLittle
            case 5: L10n.petStageYoung
            default: L10n.petStageGrown
            }
        }
        return switch stage {
        case 0: L10n.plantStageSeed
        case 1: L10n.plantStageSprout
        case 2: L10n.plantStageSapling
        case 3: L10n.plantStageYoung
        case 4: L10n.plantStageTree
        default: L10n.plantStageBloom
        }
    }
}

extension Mood {
    /// A plant is thirsty after quiet days; a pet is sleepy.
    func title(isPet: Bool) -> LocalizedStringResource {
        switch self {
        case .bright: L10n.moodBright
        case .content: L10n.moodContent
        case .thirsty: isPet ? L10n.moodSleepy : L10n.moodThirsty
        case .dozing: L10n.moodDozing
        }
    }
}

extension Spot {
    var title: LocalizedStringResource {
        switch self {
        case .above: L10n.spotAbove
        case .sky: L10n.spotSky
        case .weather: L10n.spotWeather
        case .tree: L10n.spotTree
        case .pot: L10n.spotPot
        case .left: L10n.spotLeft
        case .right: L10n.spotRight
        case .ground: L10n.spotGround
        }
    }
}

extension Decor {
    var title: LocalizedStringResource {
        switch self {
        case let .item(item): item.title
        case let .flags(holiday): L10n.decorFlags(String(localized: holiday.title))
        }
    }

    var symbol: String {
        switch self {
        case let .item(item): item.symbol
        case let .flags(holiday): Holiday.with(holiday)?.symbol ?? "🎏"
        }
    }
}

extension DecorItem {
    var title: LocalizedStringResource {
        switch self {
        case .bunting: L10n.decorBunting
        case .fairyLights: L10n.decorFairyLights
        case .paperLantern: L10n.decorPaperLantern
        case .wateringCan: L10n.decorWateringCan
        case .kilim: L10n.decorKilim
        case .terracotta: L10n.decorTerracotta
        case .glazedPot: L10n.decorGlazedPot
        case .goldPot: L10n.decorGoldPot
        case .dusk: L10n.decorDusk
        case .ornaments: L10n.decorOrnaments
        case .treeStar: L10n.decorTreeStar
        case .giftBox: L10n.decorGiftBox
        case .snowfall: L10n.decorSnowfall
        case .heartGarland: L10n.decorHeartGarland
        case .bouquet: L10n.decorBouquet
        case .pumpkin: L10n.decorPumpkin
        case .bats: L10n.decorBats
        case .fullMoon: L10n.decorFullMoon
        case .spookyBunting: L10n.decorSpookyBunting
        case .papelPicado: L10n.decorPapelPicado
        case .marigolds: L10n.decorMarigolds
        case .kinara: L10n.decorKinara
        case .confetti: L10n.decorConfetti
        case .shamrocks: L10n.decorShamrocks
        case .fireworks: L10n.decorFireworks
        case .autumnLeaves: L10n.decorAutumnLeaves
        case .eggBasket: L10n.decorEggBasket
        case .petals: L10n.decorPetals
        case .ramadanLantern: L10n.decorRamadanLantern
        case .crescentGarland: L10n.decorCrescentGarland
        case .candyBowl: L10n.decorCandyBowl
        case .oilLamps: L10n.decorOilLamps
        case .pomegranates: L10n.decorPomegranates
        case .menorah: L10n.decorMenorah
        case .colourPowder: L10n.decorColourPowder
        case .kites: L10n.decorKites
        case .redLanterns: L10n.decorRedLanterns
        case .harvestMoon: L10n.decorHarvestMoon
        case .wishNotes: L10n.decorWishNotes
        case .sabzeh: L10n.decorSabzeh
        }
    }

    /// Stands in for the drawing in the tray.
    var symbol: String {
        switch self {
        case .bunting: "🎏"
        case .fairyLights: "✨"
        case .paperLantern: "🏮"
        case .wateringCan: "🪣"
        case .kilim: "🧶"
        case .terracotta: "🏺"
        case .glazedPot: "🫙"
        case .goldPot: "🏆"
        case .dusk: "🌆"
        case .ornaments: "🔴"
        case .treeStar: "⭐️"
        case .giftBox: "🎁"
        case .snowfall: "❄️"
        case .heartGarland: "💕"
        case .bouquet: "💐"
        case .pumpkin: "🎃"
        case .bats: "🦇"
        case .fullMoon: "🌕"
        case .spookyBunting: "🏴"
        case .papelPicado: "🎊"
        case .marigolds: "🌼"
        case .kinara: "🕯️"
        case .confetti: "🎉"
        case .shamrocks: "☘️"
        case .fireworks: "🎆"
        case .autumnLeaves: "🍂"
        case .eggBasket: "🧺"
        case .petals: "🌸"
        case .ramadanLantern: "🏮"
        case .crescentGarland: "🌙"
        case .candyBowl: "🍬"
        case .oilLamps: "🪔"
        case .pomegranates: "🍎"
        case .menorah: "🕎"
        case .colourPowder: "🎨"
        case .kites: "🪁"
        case .redLanterns: "🏮"
        case .harvestMoon: "🌕"
        case .wishNotes: "📜"
        case .sabzeh: "🌱"
        }
    }
}

extension Holiday.Family {
    var title: LocalizedStringResource {
        switch self {
        case .worldwide: L10n.holidayFamilyWorldwide
        case .christian: L10n.holidayFamilyChristian
        case .muslim: L10n.holidayFamilyMuslim
        case .jewish: L10n.holidayFamilyJewish
        case .hindu: L10n.holidayFamilyHindu
        case .sikh: L10n.holidayFamilySikh
        case .buddhist: L10n.holidayFamilyBuddhist
        case .eastAsian: L10n.holidayFamilyEastAsian
        case .persian: L10n.holidayFamilyPersian
        case .turkish: L10n.holidayFamilyTurkish
        case .national: L10n.holidayFamilyNational
        }
    }
}

extension Holiday.ID {
    public var title: LocalizedStringResource {
        switch self {
        case .newYear: L10n.holidayNewYear
        case .valentines: L10n.holidayValentines
        case .womensDay: L10n.holidayWomensDay
        case .stPatricks: L10n.holidayStPatricks
        case .carnival: L10n.holidayCarnival
        case .earthDay: L10n.holidayEarthDay
        case .mothersDay: L10n.holidayMothersDay
        case .fathersDay: L10n.holidayFathersDay
        case .midsummer: L10n.holidayMidsummer
        case .halloween: L10n.holidayHalloween
        case .dayOfTheDead: L10n.holidayDayOfTheDead
        case .bonfireNight: L10n.holidayBonfireNight
        case .thanksgivingUS: L10n.holidayThanksgivingUS
        case .thanksgivingCA: L10n.holidayThanksgivingCA
        case .kwanzaa: L10n.holidayKwanzaa
        case .epiphany: L10n.holidayEpiphany
        case .orthodoxChristmas: L10n.holidayOrthodoxChristmas
        case .easter: L10n.holidayEaster
        case .orthodoxEaster: L10n.holidayOrthodoxEaster
        case .christmas: L10n.holidayChristmas
        case .ramadan: L10n.holidayRamadan
        case .eidAlFitr: L10n.holidayEidAlFitr
        case .eidAlAdha: L10n.holidayEidAlAdha
        case .islamicNewYear: L10n.holidayIslamicNewYear
        case .mawlid: L10n.holidayMawlid
        case .roshHashanah: L10n.holidayRoshHashanah
        case .sukkot: L10n.holidaySukkot
        case .hanukkah: L10n.holidayHanukkah
        case .purim: L10n.holidayPurim
        case .passover: L10n.holidayPassover
        case .makarSankranti: L10n.holidayMakarSankranti
        case .holi: L10n.holidayHoli
        case .diwali: L10n.holidayDiwali
        case .vaisakhi: L10n.holidayVaisakhi
        case .guruNanakJayanti: L10n.holidayGuruNanakJayanti
        case .vesak: L10n.holidayVesak
        case .lunarNewYear: L10n.holidayLunarNewYear
        case .dragonBoat: L10n.holidayDragonBoat
        case .tanabata: L10n.holidayTanabata
        case .midAutumn: L10n.holidayMidAutumn
        case .nowruz: L10n.holidayNowruz
        case .yalda: L10n.holidayYalda
        case .hidirellez: L10n.holidayHidirellez
        case .childrensDayTR: L10n.holidayChildrensDayTR
        case .republicDayTR: L10n.holidayRepublicDayTR
        case .canadaDay: L10n.holidayCanadaDay
        case .independenceUS: L10n.holidayIndependenceUS
        case .bastilleDay: L10n.holidayBastilleDay
        case .independenceMX: L10n.holidayIndependenceMX
        }
    }
}

extension View {
    /// Every label in the companion is one line, in every language: it shrinks
    /// a little before it would wrap, and only then truncates. "Özel günler"
    /// broke onto two lines under its icon, and a two-line label in a row of
    /// one-line ones is a layout that has stopped holding.
    func oneLine(shrinking minimum: CGFloat = 0.75) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minimum)
            .allowsTightening(true)
    }
}
