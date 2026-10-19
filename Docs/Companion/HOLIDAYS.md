# Holiday dates: how they're worked out, and where they were checked

The companion dresses its scene for the days a household celebrates. There are
49 of them, from 11 traditions, in `NestZone/Features/Companion/Holidays.swift`.
This file records how each kind of date is found and what it was checked
against, so a date can be trusted, or questioned, without redoing the research.

## How a date is found

| Rule | Used for | How |
|---|---|---|
| Fixed day | New Year, Valentine's, Halloween, Christmas, national days… | `Rule.fixed` |
| Nth weekday | Mother's/Father's Day, Thanksgiving | `Rule.weekday` (−1 = last) |
| First weekday on or after a day | Midsummer Eve (Friday 19–25 June) | `Rule.weekdayOnOrAfter` |
| From Western Easter | Easter (stored from Good Friday), Carnival, Mothering Sunday, German Father's Day | Anonymous Gregorian computus |
| From Orthodox Easter | Orthodox Easter | Julian computus + 13 days (valid 1900–2099) |
| Another calendar | Islamic (Umm al-Qura), Hebrew, Chinese, Persian days | Foundation's calendars; the Gregorian year is walked a day at a time (`LunarIndex`) |
| Verified table | Diwali, Holi, Makar Sankranti, Vaisakhi, Guru Nanak Jayanti, Buddha Purnima | `HolidayTables`, 2026–2030 |
| Regional | Mother's Day, Father's Day, Vesak | `Rule.regional`, by the device's region |

Foundation numbers Hebrew months from Tishrei = 1, with Nisan = 8. Adar is
always 7: Adar II in a leap year, which is the one Purim is kept in. Adar I is
6, and only exists in leap years.

A year missing from a table has **no date**, never a guessed one. Extending a
table is a data change: add the year after checking the sources below.

## Computed days, checked (2026–2027)

Every day checked against a source matched it:

| Day | 2026 | 2027 | Checked against |
|---|---|---|---|
| Easter Sunday | 5 Apr | 28 Mar | List of dates for Easter |
| Orthodox Easter | 12 Apr | 2 May | List of dates for Easter |
| Ramadan begins | 18 Feb | 8 Feb | Diyanet, Umm al-Qura |
| Eid al-Fitr / Ramazan Bayramı | 20 Mar | 9 Mar | Diyanet, Saudi Umm al-Qura |
| Eid al-Adha / Kurban Bayramı | 27 May | 16 May | Diyanet, Saudi Umm al-Qura |
| Rosh Hashanah (1st day) | 12 Sep | 2 Oct | hebcal |
| Hanukkah (1st day; first candle the evening before) | 5 Dec | 25 Dec | hebcal |
| Passover (15 Nisan) | 2 Apr | 22 Apr | hebcal |
| Purim | 3 Mar | 23 Mar | hebcal |
| Lunar New Year | 17 Feb | 6 Feb | Hong Kong gazette |
| Mid-Autumn | 25 Sep | 15 Sep | Hong Kong gazette |
| Nowruz | 21 Mar | 21 Mar | equinox after noon in Tehran both years |
| Mothering Sunday (UK) | 15 Mar | — | computed from Easter; not checked against a source yet |
| Midsummer Eve (Sweden) | 19 Jun | 25 Jun | computed; not checked against a source yet |

**Islamic days can be a day apart from a country's own announcement.** For 2027,
Diyanet and Saudi Umm al-Qura give Eid al-Fitr on 9 March, while India and
Singapore list 10 March. For Eid al-Adha, they give 16 May and India and
Singapore list 17 May. The app follows Umm al-Qura, which matches Diyanet.

## Tables (New Delhi), 2026–2030

2026 and 2027 are India's gazetted holidays (DoPT OM F.No.12/2/2023-JCA). 2028–2030
come from Drik Panchang (New Delhi). Each was recomputed with Swiss Ephemeris
(Lahiri) using the standard rule: amavasya at pradosh, purnima at sunrise, or the
sankranti moment. The recomputed times were within 2–6 minutes of Drik's.

| Day | 2026 | 2027 | 2028 | 2029 | 2030 |
|---|---|---|---|---|---|
| Diwali (Lakshmi Puja) | 8 Nov | 29 Oct | 17 Oct | 5 Nov | 26 Oct |
| Holi (day of colours) | 4 Mar | 23 Mar ¹ | 11 Mar | 1 Mar | 20 Mar |
| Makar Sankranti | 14 Jan | 14 Jan ² | 15 Jan | 14 Jan | 14 Jan |
| Vaisakhi | 14 Apr | 14 Apr | 13 Apr | 14 Apr ³ | 14 Apr |
| Guru Nanak Jayanti | 24 Nov | 14 Nov | 2 Nov | 21 Nov | 10 Nov |
| Buddha Purnima (India) | 1 May | 20 May | 8 May | 27 May | 17 May |

1. **Holi 2027:** the gazette says 23 March; Drik Panchang and timeanddate say
   the 22nd. Purnima ends 16:14 IST on the 22nd, so the 23rd is the first sunrise
   in Krishna Pratipada. The app follows the gazette.
2. **Makar Sankranti 2027:** the DoPT restricted list says 14 January. Drik puts
   the sankranti at 21:14 IST, after sunset, which moves Punya Kaal to the 15th.
3. **Vaisakhi 2029** is Drik's date. Mesha Sankranti falls at about 03:55 IST on
   the 14th, and in 2025 a similar case made the government list say the 13th.
   Check the 2029 list when it's published.

**Vesak in Singapore** follows day 15 of the Chinese fourth month, and the app
computes it that way. That rule matched the Ministry of Manpower in every year
checked: 2024-05-22, 2025-05-12, 2026-05-31 and 2027-05-20. It differs from
India's Buddha Purnima in 2026 (1 May vs 31 May), 2028 and 2030. Malaysia uses
the same rule in the app.

Regional variants not modelled yet: Diwali is celebrated a day earlier (Naraka
Chaturdashi) in some southern states; Makar Sankranti, Pongal and Uttarayan vary
by state.

## Sources

- India DoPT holiday lists: https://www.gconnect.in/gc22/wp-content/uploads/2026/07/Holiday-list-2027.pdf ·
  https://dfe.gov.in/uploads/documents/list-of-gazetted-holidays-2026.pdf ·
  https://www.staffnews.in/2026/07/list-of-holidays-for-the-year-2027-gazetted.html
- Drik Panchang (New Delhi): https://www.drikpanchang.com/diwali/diwali-puja-calendar.html ·
  https://www.drikpanchang.com/festivals/holi/festivals-holi-rangwali.html ·
  https://www.drikpanchang.com/calendars/indian/indiancalendar.html ·
  https://www.drikpanchang.com/festivals/buddha-purnima/buddha-purnima-date-time.html
- Singapore MOM public holidays: https://www.mom.gov.sg/employment-practices/public-holidays
- Diyanet bayram dates (via press): https://www.dunya.com/gundem/2027-bayram-tarihleri-kurban-bayrami-ramazan-bayrami-ne-zaman-haberi-842648 ·
  https://www.cnnturk.com/turkiye/2027-resmi-tatiller-takvimi-dini-bayramlar-resmi-tatil-gunler-ne-zaman-2027-ramazan-ve-kurban-bayrami-tarihleri-3447415 ·
  https://www.evrensel.net/haber/5997565/diyanet-2027-takvimini-duyurdu-ramazan-ne-zaman-basliyor
- Saudi Arabia: https://www.timeanddate.com/holidays/saudi-arabia/2027
- Jewish calendar: https://www.hebcal.com/holidays/2026-2027 · https://www.hebcal.com/holidays/2027-2028
- Hong Kong gazette: https://www.gov.hk/en/about/abouthk/holiday/2027.htm
- Easter: https://en.wikipedia.org/wiki/List_of_dates_for_Easter
- Nowruz: https://en.wikipedia.org/wiki/Nowruz
- Hıdırellez customs: https://www.cumhuriyet.com.tr/yasam/hidirellez-ne-zaman-hangi-gun-basliyor-2026-hidirellez-rituelleri-2498584

The unit tests in `NestZoneTests/CompanionTests.swift` pin the dates above, so a
change to a rule that moves one of them fails loudly.
