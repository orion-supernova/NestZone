# NestZone's voice, in every language

NestZone is read by people who live together: flatmates, couples, families.
Every string is written the way one of them would say it out loud to another,
in their own language. Not translated. Not a press release. Not a manual.

## The test

Read the line out loud. Would a person who grew up speaking this language say
exactly this, to a housemate, in the kitchen? If it sounds like a subtitle,
an airline announcement or a translation, rewrite it.

Grammatical is the floor, not the goal. "Free while it lasts" and
"o günlerde bedava" are grammatical and nobody says them.

## Rules for all languages

- **Second person, casual.** English "you". Turkish `sen`. Swedish `du`.
- **Short.** A label fits one line. A button is one to three words. A message
  is one sentence when one will do.
- **Say the thing.** "Couldn't save. Try again." not "An error occurred while
  attempting to save your changes."
- **Everyday words.** "Fix", "bills", "who's doing what". Never "utilize",
  "functionality", "işlevsellik", "funktionalitet".
- **Write it in the language, don't carry the English over.** Rebuild the
  sentence the way that language builds it: word order, idiom, what gets said
  and what's left unsaid. Keep the meaning, not the words.
- **No forced jokes.** Warm and light is good; a pun that only works in
  English is not carried over, it is replaced or dropped.
- **Brand words never change:** NestZone, NestZone Plus, PLUS, Nestie.
- **Placeholders stay exactly:** `%@`, `%lld`, `%1$@`, `%2$lld`… Reorder
  positional ones (`%1$@`) if the language needs a different order. Never
  drop one, never add one.
- **Plurals** keep the catalog's variation structure. Swedish needs `one`
  and `other`; Turkish uses `other` (it does not inflect the noun after a
  number).
- **Punctuation:** the typographic ellipsis `…`, curly quotes in prose,
  `·` as the separator the app already uses.
- **Names with suffixes (Turkish):** suffix by how the name is said, not by
  the spelling (`Micke'ye`, `@goksu.ozahishali'ya`). Where a placeholder takes
  a suffix and the name is unknown, rebuild the sentence so it needs none.

## Glossary

| English | Turkish | Swedish | Note |
|---|---|---|---|
| Today | Bugün | Idag | tab |
| Lists | Listeler | Listor | tab |
| Tasks / chores | İşler / ev işi | Sysslor / syssla | "chore" = syssla |
| Shopping | Alışveriş | Handla | segment; the list is "inköpslistan" |
| Notes | Notlar | Anteckningar | segment |
| Plans | Planlar | Planer | tab |
| Calendar | Takvim | Kalender | |
| Meals | Yemek | Mat | segment; "Ours · Explore" = "Bizimkiler · Keşfet" / "Våra · Utforska" |
| Movies | Filmler | Film | segment |
| Movie night | Film gecesi | Filmkväll | |
| Watchlists / Your watchlists | İzleme listeleri / Senin listelerin | Filmlistor / Dina filmlistor | |
| House | Ev | Hemmet | tab |
| Money | Para | Pengar | |
| Problems | Sorunlar | Fel & fix | "Problem" is fine in running text |
| Messages | Mesajlar | Meddelanden | tab |
| Who's doing what | Kim ne yapıyor | Vem gör vad | |
| At a glance | Bir bakışta | Översikt | |
| Add anything | Bir şey ekle | Lägg till | the dock's "Add anything…" field: "Lägg till vad som helst…" |
| Activity · Updates | Hareketler · Yenilikler | Händelser · Nyheter | the bell |
| Quiet hours | Sessiz saatler | Tysta timmar | |
| household / house | ev | hushållet / hemmet | |
| housemate | ev arkadaşı | de du bor med / sambo (couple) | avoid "husmedlem" |
| settle up | hesaplaşmak | göra upp | |
| Leaves (Nestie's progress) | Yaprak | Löv | currency, never sold |
| Sparkles (bought) | Işıltı | Gnistor | currency |
| Pinned note | Sabit not | Fäst lapp | "pin" = fästa |
| Holidays | Özel günler | Högtider | |
| Plus feature locked | Plus'ta | Ingår i Plus | |

## The two that started this

| key | before (EN / TR) | why it's wrong |
|---|---|---|
| `info_holiday` | "Comes with %@, free while it lasts." / "%@ gelince gelir, o günlerde bedava." | "while it lasts" is shop-sign English; "o günlerde bedava" is word-for-word. Say when you get it and that it costs nothing: e.g. "Free for %@." / "%@ için bedava." |
| `info_holidays`, `info_season` | same pattern | same fix |
