// The demo households' recipes, copied from the app's bundled samples
// (NestZone/Resources/sample_recipes_*.json) so they read exactly as an
// adopted Explore recipe does. Used only by convex/demo.ts.

export type DemoRecipe = {
  key: string;
  title: string;
  description: string;
  ingredients: string[];
  steps: string[];
  tags: string[];
  prep_time: number;
  cook_time: number;
  servings: number;
  difficulty: "easy" | "medium" | "hard";
};

export const DEMO_RECIPES_TR: DemoRecipe[] = [
  {
    "key": "authentic_carbonara",
    "title": "Spagetti Carbonara",
    "description": "Yumurta, pecorino ve guanciale ile yapılan gerçek Roma makarnası",
    "ingredients": [
      "400g spagetti",
      "150g guanciale ya da pancetta, küp doğranmış",
      "4 büyük yumurta sarısı",
      "1 bütün yumurta",
      "100g rendelenmiş Pecorino Romano",
      "Taze çekilmiş karabiber",
      "Makarna suyuna tuz"
    ],
    "steps": [
      "Büyük bir tencerede tuzlu suyu kaynat",
      "Spagettiyi al dente olana kadar haşla",
      "Bu arada geniş bir tavada guancialeyi çıtır çıtır olana kadar kavur",
      "Yumurta sarılarını, bütün yumurtayı ve pecorinoyu bir kapta çırp",
      "Yumurtalı karışıma bolca karabiber ekle",
      "Bir su bardağı makarna suyunu ayır, sonra makarnayı süz",
      "Sıcak makarnayı guancialeli tavaya al",
      "Ocaktan al, yumurtalı karışımı ekleyip hızlıca karıştır",
      "Kremsi kıvamı yakalayana kadar azar azar makarna suyu ekle",
      "Üzerine biraz daha pecorino ve karabiber koyup hemen servis et"
    ],
    "tags": [
      "pasta",
      "dinner"
    ],
    "prep_time": 10,
    "cook_time": 15,
    "servings": 4,
    "difficulty": "medium"
  },
  {
    "key": "turkish_kuru_fasulye",
    "title": "Kuru Fasulye",
    "description": "Salçalı, etsiz, tane tane kuru fasulye",
    "ingredients": [
      "500g kuru fasulye, akşamdan ıslatılmış",
      "1 büyük kuru soğan, küçük küçük doğranmış",
      "3 diş sarımsak, ezilmiş",
      "2 yemek kaşığı domates salçası",
      "400g konserve domates",
      "1 çay kaşığı pul biber",
      "1/2 çay kaşığı kimyon",
      "3 yemek kaşığı zeytinyağı",
      "2 su bardağı sıcak su",
      "Tuz ve karabiber",
      "Üzeri için taze maydanoz"
    ],
    "steps": [
      "Islattığın fasulyeleri süz, durula",
      "Fasulyeleri taze suda yaklaşık 45 dakika, yumuşayana kadar haşla",
      "Geniş bir tencerede zeytinyağını kızdır",
      "Soğanı pembeleşene kadar kavur, sarımsağı ekle",
      "Salçayı ekle, 2 dakika kavur",
      "Konserve domatesi, pul biberi ve kimyonu ekle",
      "Haşlanmış fasulyeleri ve suyu ekle",
      "Sos koyulaşana kadar 15-20 dakika kaynat",
      "Tuz ve karabiberle tadını ayarla",
      "Maydanozla süsle, yanında pilavla ye"
    ],
    "tags": [
      "dinner",
      "healthy"
    ],
    "prep_time": 20,
    "cook_time": 60,
    "servings": 6,
    "difficulty": "easy"
  },
  {
    "key": "shakshuka",
    "title": "Şakşuka",
    "description": "Baharatlı domates sosunda pişen yumurta, Kuzey Afrika usulü",
    "ingredients": [
      "2 yemek kaşığı zeytinyağı",
      "1 büyük soğan, küçük küçük doğranmış",
      "1 kırmızı kapya biber, küçük küçük doğranmış",
      "4 diş sarımsak, ezilmiş",
      "1 çay kaşığı pul biber",
      "1/2 çay kaşığı kimyon",
      "1/4 çay kaşığı acı biber",
      "800g konserve domates",
      "1/2 çay kaşığı şeker",
      "6 yumurta",
      "100g beyaz peynir",
      "Taze maydanoz ve kişniş",
      "Tuz ve karabiber"
    ],
    "steps": [
      "Geniş bir tavada zeytinyağını kızdır",
      "Soğanı yumuşayana kadar kavur",
      "Biberi ekle, 5 dakika pişir",
      "Sarımsağı, pul biberi, kimyonu ve acı biberi ekle",
      "Kokusu çıkana kadar yaklaşık 1 dakika pişir",
      "Domatesi ve şekeri ekle, tuz ve karabiberle tadını ayarla",
      "Koyulaşana kadar 10-15 dakika kaynat",
      "Sosun içinde yumurtalar için küçük çukurlar aç",
      "Yumurtaları çukurlara kır",
      "Kapağını kapat, yumurtalar tutana kadar 8-12 dakika pişir",
      "Üzerine beyaz peynir ufala",
      "Otlarla süsle, ekmekle servis et"
    ],
    "tags": [
      "breakfast",
      "dinner",
      "healthy"
    ],
    "prep_time": 15,
    "cook_time": 25,
    "servings": 4,
    "difficulty": "medium"
  },
  {
    "key": "classic_brownies",
    "title": "Brownie",
    "description": "Üstü çatlak, içi yoğun çikolatalı brownie",
    "ingredients": [
      "200g bitter çikolata, doğranmış",
      "175g tereyağı",
      "200g toz şeker",
      "3 büyük yumurta",
      "75g un",
      "25g kakao",
      "1/2 çay kaşığı tuz",
      "100g damla çikolata (istersen)"
    ],
    "steps": [
      "Fırını 180°C'ye ısıt",
      "20 cm'lik kare bir kalıbı yağlı kağıtla kapla",
      "Çikolatayı ve tereyağını benmari usulüyle erit",
      "Şekeri ekleyip karışana kadar çırp",
      "Yumurtaları tek tek ekleyip çırp",
      "Unu, kakaoyu ve tuzu birlikte ele",
      "Kuru malzemeleri çikolatalı karışıma yedirerek karıştır",
      "İstersen damla çikolataları da ekle",
      "Hazırladığın kalıba dök",
      "Kürdan temiz çıkana kadar 30-35 dakika pişir",
      "Dilimlemeden önce tamamen soğumasını bekle"
    ],
    "tags": [
      "dessert"
    ],
    "prep_time": 15,
    "cook_time": 35,
    "servings": 16,
    "difficulty": "easy"
  },
  {
    "key": "thai_green_curry",
    "title": "Tay Yeşil Köri",
    "description": "Hindistan cevizi sütlü, aromatik tavuklu köri",
    "ingredients": [
      "500g tavuk eti",
      "400ml hindistan cevizi sütü",
      "3 yemek kaşığı yeşil köri ezmesi",
      "1 patlıcan, doğranmış",
      "1 kırmızı biber",
      "Tay fesleğeni",
      "Balık sosu",
      "Şeker",
      "Basmati pirinç"
    ],
    "steps": [
      "Hindistan cevizi sütünün koyu kısmını tavaya al",
      "Köri ezmesini ekle, kokusu çıkana kadar kavur",
      "Tavuk etini ekle, pişir",
      "Kalan hindistan cevizi sütünü ekle",
      "Sebzeleri ekle, kaynat",
      "Balık sosu ve şekerle tadını ayarla",
      "Tay fesleğenini ekle",
      "Basmati pilavla servis et"
    ],
    "tags": [
      "dinner"
    ],
    "prep_time": 20,
    "cook_time": 25,
    "servings": 4,
    "difficulty": "medium"
  },
  {
    "key": "greek_salad",
    "title": "Yunan Salatası",
    "description": "Taze sebzeler ve beyaz peynirle hazırlanan Akdeniz salatası",
    "ingredients": [
      "3 büyük domates, dilimlenmiş",
      "1 salatalık, dilimlenmiş",
      "1 kırmızı soğan, ince dilimlenmiş",
      "200g beyaz peynir, küp doğranmış",
      "1/2 su bardağı siyah zeytin",
      "1/4 su bardağı zeytinyağı",
      "2 yemek kaşığı kırmızı şarap sirkesi",
      "1 çay kaşığı kekik",
      "Tuz ve karabiber"
    ],
    "steps": [
      "Domatesi, salatalığı ve soğanı geniş bir kapta birleştir",
      "Beyaz peyniri ve zeytinleri ekle",
      "Zeytinyağını, sirkeyi, kekiği, tuzu ve karabiberi karıştırıp sos yap",
      "Sosu salatanın üzerine dök, karıştır",
      "30 dakika dinlendir",
      "Pide ya da ekmekle servis et"
    ],
    "tags": [
      "lunch",
      "healthy",
      "vegetarian"
    ],
    "prep_time": 15,
    "cook_time": 0,
    "servings": 4,
    "difficulty": "easy"
  }
];

export const DEMO_RECIPES_EN: DemoRecipe[] = [
  {
    "key": "authentic_carbonara",
    "title": "Authentic Carbonara",
    "description": "Classic Roman pasta with eggs, pecorino, and guanciale - no cream needed!",
    "ingredients": [
      "400g spaghetti or spaghettoni",
      "150g guanciale or pancetta, diced",
      "4 large egg yolks",
      "1 whole large egg",
      "100g Pecorino Romano, freshly grated",
      "Freshly ground black pepper",
      "Coarse sea salt for pasta water"
    ],
    "steps": [
      "Bring a large pot of salted water to rolling boil",
      "Cook spaghetti until al dente (check package instructions)",
      "Meanwhile, cook guanciale in large skillet over medium heat until golden and crispy",
      "In a bowl, whisk egg yolks, whole egg, and grated pecorino",
      "Add generous amount of freshly ground black pepper to egg mixture",
      "Reserve 1 cup of starchy pasta water before draining",
      "Add hot drained pasta to skillet with guanciale",
      "Remove from heat and quickly toss pasta with egg mixture",
      "Add pasta water gradually while tossing until creamy and silky",
      "Serve immediately with extra pecorino and black pepper"
    ],
    "tags": [
      "pasta",
      "dinner"
    ],
    "prep_time": 10,
    "cook_time": 15,
    "servings": 4,
    "difficulty": "medium"
  },
  {
    "key": "turkish_kuru_fasulye",
    "title": "Turkish White Bean Stew",
    "description": "Hearty white bean stew in tomato sauce",
    "ingredients": [
      "500g dried white beans, soaked overnight",
      "1 large onion, diced",
      "3 cloves garlic, minced",
      "2 tbsp tomato paste",
      "400g canned tomatoes",
      "1 tsp paprika",
      "1/2 tsp cumin",
      "3 tbsp olive oil",
      "2 cups vegetable broth",
      "Salt and pepper to taste",
      "Fresh parsley for garnish"
    ],
    "steps": [
      "Drain and rinse soaked beans",
      "Boil beans in fresh water until tender (about 45 minutes)",
      "Heat olive oil in large pot",
      "Sauté onion until translucent, add garlic",
      "Stir in tomato paste and cook for 2 minutes",
      "Add canned tomatoes, paprika, and cumin",
      "Add cooked beans and broth",
      "Simmer until sauce thickens (15-20 minutes)",
      "Season with salt and pepper",
      "Garnish with parsley and serve with rice"
    ],
    "tags": [
      "dinner",
      "healthy"
    ],
    "prep_time": 20,
    "cook_time": 60,
    "servings": 6,
    "difficulty": "easy"
  },
  {
    "key": "shakshuka",
    "title": "Shakshuka",
    "description": "North African poached eggs in spiced tomato sauce",
    "ingredients": [
      "2 tbsp olive oil",
      "1 large onion, diced",
      "1 red bell pepper, diced",
      "4 cloves garlic, minced",
      "1 tsp paprika",
      "1/2 tsp cumin",
      "1/4 tsp cayenne pepper",
      "800g canned tomatoes",
      "1/2 tsp sugar",
      "6 eggs",
      "100g feta cheese",
      "Fresh parsley and cilantro",
      "Salt and pepper"
    ],
    "steps": [
      "Heat oil in large cast iron pan",
      "Sauté onion until softened",
      "Add bell pepper and cook for 5 minutes",
      "Add garlic, paprika, cumin, and cayenne",
      "Cook until fragrant (about 1 minute)",
      "Add tomatoes and sugar, season with salt and pepper",
      "Simmer until thickened (10-15 minutes)",
      "Make wells in sauce for eggs",
      "Crack eggs into wells",
      "Cover and cook until eggs are set (8-12 minutes)",
      "Sprinkle with feta cheese",
      "Garnish with herbs and serve with bread"
    ],
    "tags": [
      "breakfast",
      "dinner",
      "healthy"
    ],
    "prep_time": 15,
    "cook_time": 25,
    "servings": 4,
    "difficulty": "medium"
  },
  {
    "key": "classic_brownies",
    "title": "Classic Brownies",
    "description": "Fudgy brownies with crackled tops",
    "ingredients": [
      "200g dark chocolate, chopped",
      "175g butter",
      "200g brown sugar",
      "3 large eggs",
      "75g flour",
      "25g cocoa powder",
      "1/2 tsp salt",
      "100g chocolate chips (optional)"
    ],
    "steps": [
      "Preheat oven to 350°F (180°C)",
      "Line 8-inch square pan with parchment paper",
      "Melt chocolate and butter in double boiler",
      "Whisk in sugar until combined",
      "Beat in eggs one at a time",
      "Sift together flour, cocoa, and salt",
      "Fold dry ingredients into chocolate mixture",
      "Add chocolate chips if using",
      "Pour into prepared pan",
      "Bake 30-35 minutes until toothpick comes out clean",
      "Cool completely before cutting"
    ],
    "tags": [
      "dessert"
    ],
    "prep_time": 15,
    "cook_time": 35,
    "servings": 16,
    "difficulty": "easy"
  },
  {
    "key": "thai_green_curry",
    "title": "Thai Green Curry",
    "description": "Aromatic coconut curry with chicken",
    "ingredients": [
      "500g chicken thigh, sliced",
      "400ml coconut milk",
      "3 tbsp green curry paste",
      "1 eggplant, cubed",
      "1 red bell pepper, sliced",
      "Thai basil leaves",
      "Fish sauce",
      "Sugar",
      "Jasmine rice for serving"
    ],
    "steps": [
      "Heat thick coconut milk in wok",
      "Add curry paste and fry until fragrant",
      "Add chicken and cook until nearly done",
      "Add remaining coconut milk and simmer",
      "Add vegetables and cook until tender",
      "Season with fish sauce and sugar",
      "Stir in Thai basil",
      "Serve with jasmine rice"
    ],
    "tags": [
      "dinner"
    ],
    "prep_time": 20,
    "cook_time": 25,
    "servings": 4,
    "difficulty": "medium"
  },
  {
    "key": "greek_salad",
    "title": "Greek Salad",
    "description": "Fresh Mediterranean salad with vegetables and feta",
    "ingredients": [
      "3 large tomatoes, sliced",
      "1 cucumber, sliced",
      "1 red onion, thinly sliced",
      "200g feta cheese, cubed",
      "1/2 cup Kalamata olives",
      "1/4 cup olive oil",
      "2 tbsp red wine vinegar",
      "1 tsp dried oregano",
      "Salt and pepper to taste"
    ],
    "steps": [
      "Combine tomatoes, cucumber, and onion in large bowl",
      "Add feta cheese and olives",
      "Whisk olive oil, vinegar, oregano, salt, and pepper",
      "Toss salad with dressing",
      "Let sit for 30 minutes to marinate",
      "Serve with pita bread"
    ],
    "tags": [
      "lunch",
      "healthy",
      "vegetarian"
    ],
    "prep_time": 15,
    "cook_time": 0,
    "servings": 4,
    "difficulty": "easy"
  }
];

// Swedish: the house's own everyday food first (köttbullar, pytt, lax,
// kladdkaka), written in Swedish rather than taken off the English, then
// three of the bundled samples (sample_recipes_sv.json) as they read there.
export const DEMO_RECIPES_SV: DemoRecipe[] = [
  {
    key: "kottbullar",
    title: "Köttbullar med potatismos",
    description: "Hemmagjorda köttbullar med gräddsås, mos och lingon – som hos mormor",
    ingredients: [
      "500 g blandfärs",
      "1 gul lök, finhackad",
      "0,5 dl ströbröd",
      "1 dl mjölk eller grädde",
      "1 ägg",
      "Salt och vitpeppar",
      "Smör till stekning",
      "1 kg mjölig potatis",
      "2 dl grädde och 2 dl buljong till såsen",
      "1 msk soja",
      "Lingonsylt och pressgurka till"
    ],
    steps: [
      "Blanda ströbröd och mjölk, låt svälla i några minuter",
      "Fräs löken mjuk i lite smör och låt svalna",
      "Rör ihop färs, lök, ägg och ströbrödssmeten, smaka av med salt och peppar",
      "Rulla små bullar med blöta händer",
      "Stek köttbullarna i smör i omgångar tills de är bruna runt om",
      "Koka potatisen mjuk, häll av och mosa med smör och varm mjölk",
      "Häll grädde och buljong i stekpannan, låt koka ihop och smaka av med soja",
      "Servera med mos, sås, lingonsylt och pressgurka"
    ],
    tags: ["dinner"],
    prep_time: 25,
    cook_time: 30,
    servings: 4,
    difficulty: "medium"
  },
  {
    key: "pytt_i_panna",
    title: "Pytt i panna",
    description: "Tärnad potatis, korv och lök i stekpannan, med stekt ägg och rödbetor",
    ingredients: [
      "800 g kokt potatis, gärna från igår",
      "300 g falukorv eller rester av kött",
      "1 gul lök",
      "Smör och rapsolja",
      "4 ägg",
      "Salt och svartpeppar",
      "Inlagda rödbetor",
      "Hackad persilja"
    ],
    steps: [
      "Skär potatis, korv och lök i små tärningar",
      "Stek potatisen gyllene i smör och olja, det får ta sin tid",
      "Lägg i lök och korv och stek tills allt har fått fin färg",
      "Smaka av med salt och peppar",
      "Stek äggen i en egen panna",
      "Servera pytten med ett stekt ägg, rödbetor och persilja"
    ],
    tags: ["dinner"],
    prep_time: 15,
    cook_time: 25,
    servings: 4,
    difficulty: "easy"
  },
  {
    key: "ugnslax",
    title: "Ugnsbakad lax med dillpotatis",
    description: "Lax i ugnen med citron och dill – vardagsmiddag som känns lite fin",
    ingredients: [
      "600 g laxfilé",
      "1 citron",
      "1 knippe dill",
      "800 g fast potatis",
      "2 dl crème fraiche",
      "1 tsk dijonsenap",
      "Salt och svartpeppar"
    ],
    steps: [
      "Sätt ugnen på 175°C",
      "Koka potatisen i saltat vatten med några dillkvistar",
      "Lägg laxen i en ugnsform, salta, peppra och lägg på citronskivor",
      "Baka laxen i mitten av ugnen i cirka 20 minuter",
      "Rör ihop crème fraiche, senap, hackad dill och lite citronsaft",
      "Servera laxen med dillpotatis och kall sås"
    ],
    tags: ["dinner", "healthy"],
    prep_time: 10,
    cook_time: 25,
    servings: 4,
    difficulty: "easy"
  },
  {
    key: "kladdkaka",
    title: "Kladdkaka",
    description: "Kladdig chokladkaka med vispad grädde – fikats bästa vän",
    ingredients: [
      "100 g smör",
      "2 ägg",
      "2,5 dl strösocker",
      "1,5 dl vetemjöl",
      "4 msk kakao",
      "2 tsk vaniljsocker",
      "1 krm salt",
      "Vispad grädde och bär till"
    ],
    steps: [
      "Sätt ugnen på 175°C",
      "Smörj och bröa en form med löstagbar kant",
      "Smält smöret och låt det svalna lite",
      "Rör ihop ägg och socker, men vispa inte",
      "Blanda i mjöl, kakao, vaniljsocker och salt",
      "Rör ner smöret och häll smeten i formen",
      "Grädda i cirka 15 minuter, den ska vara kladdig i mitten",
      "Låt kakan stelna i kylen och servera med grädde och bär"
    ],
    tags: ["dessert"],
    prep_time: 10,
    cook_time: 15,
    servings: 8,
    difficulty: "easy"
  },
  {
    key: "authentic_carbonara",
    title: "Äkta carbonara",
    description: "Romersk klassiker med ägg, pecorino och guanciale – ingen grädde!",
    ingredients: [
      "400 g spaghetti eller spaghettoni",
      "150 g guanciale eller pancetta, tärnad",
      "4 stora äggulor",
      "1 helt stort ägg",
      "100 g nyriven pecorino romano",
      "Nymald svartpeppar",
      "Grovt salt till pastavattnet"
    ],
    steps: [
      "Koka upp en stor kastrull saltat vatten",
      "Koka spaghettin al dente (kolla tiden på paketet)",
      "Stek under tiden guancialen i en stor stekpanna på medelvärme tills den är gyllene och krispig",
      "Vispa ihop äggulor, ägg och riven pecorino i en skål",
      "Mal ner rikligt med svartpeppar i äggblandningen",
      "Spara 2,5 dl av pastavattnet innan du häller av",
      "Lägg den varma pastan i pannan med guancialen",
      "Dra av pannan från värmen och vänd snabbt runt pastan med äggblandningen",
      "Häll i pastavatten lite i taget och vänd tills det blir krämigt och blankt",
      "Servera direkt med extra pecorino och svartpeppar"
    ],
    tags: ["pasta", "dinner"],
    prep_time: 10,
    cook_time: 15,
    servings: 4,
    difficulty: "medium"
  },
  {
    key: "greek_salad",
    title: "Grekisk sallad",
    description: "Fräsch medelhavssallad med grönsaker och fetaost",
    ingredients: [
      "3 stora tomater, i bitar",
      "1 gurka, i bitar",
      "1 rödlök, tunt skivad",
      "200 g fetaost, i tärningar",
      "1 dl kalamataoliver",
      "0,5 dl olivolja",
      "2 msk rödvinsvinäger",
      "1 tsk torkad oregano",
      "Salt och peppar"
    ],
    steps: [
      "Blanda tomat, gurka och lök i en stor skål",
      "Lägg i fetaost och oliver",
      "Vispa ihop olivolja, vinäger, oregano, salt och peppar",
      "Vänd salladen med dressingen",
      "Låt dra i 30 minuter",
      "Servera med pitabröd"
    ],
    tags: ["lunch", "healthy", "vegetarian"],
    prep_time: 15,
    cook_time: 0,
    servings: 4,
    difficulty: "easy"
  },
  {
    key: "thai_green_curry",
    title: "Thailändsk grön curry",
    description: "Doftande kokoscurry med kyckling",
    ingredients: [
      "500 g kycklinglårfilé, i bitar",
      "400 ml kokosmjölk",
      "3 msk grön currypasta",
      "1 aubergine, tärnad",
      "1 röd paprika, strimlad",
      "Thaibasilika",
      "Fisksås",
      "Socker",
      "Jasminris till"
    ],
    steps: [
      "Värm den tjocka delen av kokosmjölken i en wok",
      "Fräs currypastan tills det doftar",
      "Lägg i kycklingen och stek tills den nästan är klar",
      "Häll i resten av kokosmjölken och låt puttra",
      "Lägg i grönsakerna och låt koka tills de är mjuka",
      "Smaka av med fisksås och socker",
      "Rör ner thaibasilikan",
      "Servera med jasminris"
    ],
    tags: ["dinner"],
    prep_time: 20,
    cook_time: 25,
    servings: 4,
    difficulty: "medium"
  }
];
