import Foundation

/// What each colourway is called, in English and in Turkish, for the screen
/// that offers them. Kept beside the painters that draw them so a palette and
/// its name are changed together; the screen reads them through
/// `Colourway.name` and puts them in the String Catalog when it lands.
///
/// `n` is 1 to 3 (0 is the original, which has no name of its own: it is just
/// the species). The Turkish is written as Turkish, short and casual: what a
/// person would say pointing at it.
struct ColourwayName: Equatable, Sendable {
    let en: String
    let tr: String
}

enum ColourwayNames {
    /// The name of colourway `n` of a species, or a plain "Colour n" for one
    /// this build has no name for.
    static func name(_ species: Species, _ n: Int) -> ColourwayName {
        guard let list = table[species], (1...list.count).contains(n) else { return ColourwayName(en: "Colour \(n)", tr: "Renk \(n)") }
        return list[n - 1]
    }

    private static func names(_ list: [(String, String)]) -> [ColourwayName] { list.map { ColourwayName(en: $0.0, tr: $0.1) } }

    private static let table: [Species: [ColourwayName]] = [
        // Plants
        .sunflower: names([("Velvet Queen", "Kadife kraliçe"), ("Lemon", "Limon sarısı"), ("Italian white", "Krem beyazı")]),
        .basil: names([("Dark Opal", "Mor fesleğen"), ("Lemon basil", "Limonlu fesleğen"), ("Variegated", "Alacalı")]),
        .cactus: names([("Blue torch", "Mavi sütun"), ("Golden barrel", "Altın fıçı"), ("Purple prickly pear", "Mor incir")]),
        .daisy: names([("English pink", "Pembe papatya"), ("Golden marguerite", "Altın papatya"), ("Blue felicia", "Mavi papatya")]),
        .mint: names([("Chocolate mint", "Çikolatalı nane"), ("Pineapple mint", "Alacalı nane"), ("Apple mint", "Elmalı nane")]),
        .rosemary: names([("Pink flowers", "Pembe çiçekli"), ("White flowers", "Beyaz çiçekli"), ("Golden", "Altın yapraklı")]),
        .snakePlant: names([("Moonshine", "Ay ışığı"), ("Black gold", "Kara altın"), ("Lime hahnii", "Limon yeşili")]),
        .fern: names([("Silver lady", "Gümüş eğrelti"), ("Lemon button", "Limon eğrelti"), ("Autumn fern", "Bakır eğrelti")]),
        .lavender: names([("White", "Beyaz lavanta"), ("Pink", "Pembe lavanta"), ("Hidcote", "Koyu lavanta")]),
        .peony: names([("White", "Beyaz şakayık"), ("Coral", "Mercan"), ("Crimson", "Koyu kırmızı")]),
        .monstera: names([("Albo variegata", "Beyaz alacalı"), ("Thai constellation", "Tayland yıldızı"), ("Mint", "Nane yeşili")]),
        .rose: names([("White", "Beyaz gül"), ("Peach", "Şeftali gül"), ("Burgundy", "Bordo gül")]),
        .orchid: names([("Butter yellow", "Tereyağı sarısı"), ("Violet", "Mor orkide"), ("Pure white", "Saf beyaz")]),
        .bonsai: names([("Autumn gold", "Sonbahar altını"), ("In blossom", "Çiçek açmış"), ("Silver olive", "Gümüş zeytin")]),
        .maple: names([("Golden", "Altın akçaağaç"), ("Spring green", "Bahar yeşili"), ("Bloodgood", "Mor akçaağaç")]),
        .pumpkin: names([("White Lumina", "Beyaz kabak"), ("Blue Jarrahdale", "Mavi kabak"), ("Red Cinderella", "Kızıl kabak")]),
        .pine: names([("Blue spruce", "Mavi ladin"), ("Golden pine", "Altın çam"), ("Frosted", "Kırağılı")]),
        .snowdrop: names([("Yellow", "Sarı kardelen"), ("Green-tipped", "Yeşil uçlu"), ("Glaucous", "Mavi yapraklı")]),
        .tulip: names([("Rembrandt", "Çizgili lale"), ("Queen of Night", "Gece kraliçesi"), ("Apricot", "Kayısı lale")]),
        // Trees
        .magnolia: names([("White", "Beyaz manolya"), ("Black Tulip", "Mor manolya"), ("Yellow", "Sarı manolya")]),
        .cherry: names([("White Yoshino", "Beyaz Yoshino"), ("Weeping pink", "Salkım pembe"), ("Deep Kanzan", "Koyu Kanzan")]),
        .pomegranate: names([("White-flowered", "Beyaz çiçekli"), ("Dark dwarf", "Kara nar"), ("Golden", "Altın nar")]),
        .azalea: names([("White", "Beyaz açelya"), ("Flame orange", "Alev turuncusu"), ("Violet", "Mor açelya")]),
        .lemon: names([("Pink variegated", "Pembe alacalı"), ("Lime", "Misket limonu"), ("Blood orange", "Kan portakalı")]),
        .olive: names([("Green Manzanilla", "Yeşil zeytin"), ("Golden bronze", "Altın zeytin"), ("Silver ruby", "Gümüş yakut")]),
        // Pets
        .kitten: names([("Silver tabby", "Gümüş tekir"), ("Black with a white bib", "Beyaz önlüklü kara"), ("Calico", "Üç renkli")]),
        .owl: names([("Snowy owl", "Kar baykuşu"), ("Barn owl", "Peçeli baykuş"), ("Red screech owl", "Kızıl baykuş")]),
        .duckling: names([("Mallard", "Yaban ördeği"), ("Black and white", "Siyah beyaz"), ("Blue Swedish", "Mavi ördek")]),
        .hamster: names([("Winter white", "Kar beyazı"), ("Chocolate", "Çikolata"), ("Dalmatian", "Benekli")]),
        .bunny: names([("Himalayan", "Himalaya"), ("Chestnut", "Kestane"), ("Lilac", "Leylak")]),
        .puppy: names([("Chocolate lab", "Çikolata"), ("Border collie", "Siyah beyaz"), ("Cream", "Krem")]),
        .fox: names([("Silver fox", "Gümüş tilki"), ("Cross fox", "Haçlı tilki"), ("Golden fox", "Altın tilki")]),
        .hedgehog: names([("Albino", "Albino"), ("Cinnamon", "Tarçın"), ("Salt and pepper", "Tuz biber")]),
        .deer: names([("Sika", "Sika"), ("Fallow", "Alageyik"), ("White fallow", "Beyaz geyik")]),
        .snowFox: names([("Arctic dusk", "Alacakaranlık"), ("Summer coat", "Yaz tüyü"), ("Lilac pearl", "Leylak inci")]),
        .polarCub: names([("Cinnamon bear", "Tarçın ayı"), ("Panda", "Panda"), ("Black bear", "Kara ayı")]),
        .penguin: names([("Little blue", "Minik mavi"), ("Rockhopper", "Sarı kaşlı"), ("Isabelline", "Kahverengi")]),
        .turtle: names([("Golden tortoise", "Altın kabuk"), ("Painted turtle", "Boyalı"), ("Albino", "Albino")]),
        .goldfish: names([("Calico fantail", "Üç renkli"), ("White oranda", "Kırmızı başlı"), ("Black moor", "Kara")]),
    ]
}
