# Handoff: Nestie, the household companion

Written over the working sessions of 19–23 October 2026 so the work can
continue on another machine. The full plan is `plan/index.html`. This file is
the short version, plus everything a new session needs to keep going without
the old conversation.

## Start here (23 October 2026)

- **Where it stands:** round four (v9) is built and committed to `dev`,
  pushed as work in progress. `stage` hasn't moved and nothing is released.
  Nestie is still Debug-only (`CompanionFlag`). The motion pass and the
  tap and shake fixes are app-wide, though, so they ship with whatever
  version comes next (see "Before the next release").
- **The next job:** the segments' screens are kept alive now (step 0 under
  "Next steps" says what was done and measured). What is left of the hitch is
  the first switch to each module, which has to build it (Calendar, Issues and
  Finance now build in beats, 130–155 ms; the `List` screens are still 120–250),
  and a warm switch of about 55–80 ms; the open items are in step 0's "Still
  open".
- **To look at on a phone:** the new micro-animations (they build, but the
  simulator here can't be tapped, so they weren't watched one by one);
  whether the check in the "All square" seal draws itself in; the stamp with
  Reduce Motion on; the short pause between the budget ring's two sweeps.
- **The plan in a browser:** `plan/index.html#next` has the same "start
  here", the v9 shop in screenshots and the roadmap. `plan/shop.html` has
  v8's prototype and how each of its decisions was answered.
- **A prompt for a fresh session:** "Read Docs/Companion/HANDOFF.md first,
  then CLAUDE.md. Step 0 of Next steps is done; read its "Still open". Measure with
  `-frameMeter 2 -openTab plans -segmentCycle 4 -appTabSegments "calendar,tasks,finance"`.
  Build and typecheck only, no tests."

## How we got here

The session started with the navigation rework (five grouped tabs, a quieter
Today, "Add anything"), committed earlier on `dev`. Testers then said Today felt
a bit empty. You asked for something interactive on it, like SumOne's pet and
house decorating: the household picks a plant or pet, it grows as chores, plans
and interactions happen, and it graduates with a ceremony into an achievements
album before the next one starts. You also asked for "really awesome" drawing
and animation.

The plan went through five versions, each driven by your answers:

1. **v1–v2** — research (SumOne, Widgetable, Finch, Forest, Pikmin Bloom, Neko
   Atsume…), design, and a growth simulation. You set the pace at about two
   weeks for an active house, asked for a wide catalog, a finale when everything
   is grown, earned plus bought currency for monetisation, no vote in a
   one-person house, and an illustrator hired now. You corrected the Turkish
   too: sunflower is *Ayçiçeği*, not *Güneş*.
2. **v3** — buying must never delay the finale. Purchases belong to a house
   "like a real house". Everything ships in one release. Subscriptions are
   planned for features (problems, money, maybe calendar, custom movie
   collections and recipes). You asked for Leaves/Sparkles in plain words, what
   animals do, and whether an illustrator can do Rive.
3. **v4** — mood was too subtle ("thirsty and happy are barely different"), the
   demo duck was hard to find, "parts kit" needed explaining, decorating needed
   a design, and you wanted seasonal things to buy (a Halloween pumpkin,
   Christmas or New Year).
4. **v5 (this session)** — you asked for:
   - wake-up ("phasing") animations;
   - Nestie as the name for now, both names changeable later;
   - me as the illustrator, animator and motion designer;
   - nothing that costs money (no Rive, no paid tools);
   - one house jar instead of separate banks;
   - every tradition's holidays, not just Turkish ones;
   - a simple MVP to try on local builds;
   - all of it saved in the repo, to continue elsewhere.
5. **v6 (the MVP's bugs)** — trying the MVP, you found:
   - "Holidays" wrapping onto two lines. Every label is now one line in both
     languages.
   - The movie night row on Today repeating what the dock showed. Today now
     never repeats the dock.
   - Every tree laggy and basic-looking. This led to the new art and the
     rendering below; you suggested Metal, which was tried and measured (see
     "Things learned"). Two illustration directions were
     drawn. You chose layered gouache ("more detailed, more premium, more
     realistic, more artsy"), which then had a second pass.
   - The question of whether an item could cost Leaves or Sparkles. It was
     settled as two currencies, one price per item, with a welcome gift.
   - The Turkish. It is now written in Turkish, casual and street-level, never
     translated off the English.
6. **v7 (the shop)** — you asked for:
   - a confirmation before anything is bought, in either currency;
   - when Leaves run short (60 of 100), an offer to make up the rest (40)
     with Sparkles, and with no Sparkles, a way to the store;
   - StoreKit or RevenueCat only at the last step, chosen then;
   - the whole catalog ready now, with placeholders for what isn't drawn —
     the art is its own job later;
   - the roadmap to production.
7. **v8 (the shop, redesigned)** — the first shop "looked horrible… from the
   2000s": unreadable small grey text, system alerts, a glass pill inside the
   toolbar's own glass. You asked for fun, playful, friendly yet premium, with
   art, design and motion teams, and shared a talk on animation as the motion
   philosophy for the whole app. Four teams (art and design, motion,
   readability and UX, research) worked it out; it was prototyped in
   `plan/shop.html`, then built. Decisions still open are on that page,
   under "Decisions for you".
8. **v9 (the shop, on the app's own design)** — the v8 shop's solid plum,
   big type, drawn coins and lip buttons read as "a game app shop, not this
   app". You liked the pressed-in 3D feel but wanted it clean and premium,
   on Apple's system, with Telegram- and Duolingo-like micro-animation
   everywhere. You answered v8's six calls (below, under Decided) and
   reported four bugs: shelves switching while scrolled to the bottom, a
   flicker on switch, the shop too easy to swipe away, Water's drops
   restarting on every tap, plus a gap under the half-sheets. You also
   asked for no motion to be removed, only fixed or added to.
9. **After v9 (23 October)** — asked whether to fix the segment-switch
   hitch by keeping the segments' screens alive, you said yes, and asked for
   everything to be saved in the plan and pushed, to carry on in a new
   session.

## Decided

- **Name:** Nestie, for now. One string (`L10n.companionBrand`); the code says
  "companion".
- **Pace:** about two weeks for an active household. The MVP uses 1 point per
  finished chore, at most 9 a day, 64 to graduate, plus 1 per day of care. The
  server version uses the simulated curve in `tools/`.
- **Plants and pets together,** one album, a ceremony at graduation, the next
  one chosen straight after: a vote for two or more people, a direct pick for
  one.
- **Moods** (bright, content, thirsty or sleepy, dozing) change six things at
  once. It never dies.
- **Waking up:** every change of state has a transition (see the table in the
  plan). After quiet days, one chore or care wakes it all the way.
- **Art and motion are all code,** at $0. No Rive, no illustrator, no paid tools.
  Flat, rounded vector style.
- **The tree is "layered gouache"** (`art/gouache/`), your choice: leaf-shaped
  lobes in three depth tiers with per-clump light, cast shadows inside the
  canopy, the canopy's shade on the wood, a night rim light, and petals with
  gradients and stamens. Thirsty and dozing read as one tired, drooping tree.
  "Soft canopy" (`art/soft-canopy/`) is kept for reference with its finished
  Swift port. The two are compared in `art/compare.html`.
- **How it is drawn:**
  - The tree is drawn only when what it shows changes.
  - The wind is a shear of that picture about the root, so the pot never
    moves.
  - The scene holds still while Today scrolls and under any sheet.
  - Choose and the album draw portraits as single still canvases.
- **One house jar** (Kumbara) with **two currencies**, and every item priced in
  exactly one of them — never "100 Leaves or 5 Sparkles" for the same thing
  (that's pay-to-skip-progress). **Short of Leaves, the rest can be made up
  with Sparkles, one for one** (v7, your call): the same price, paid partly in
  the other coin. Sparkles are never made up with Leaves. **Leaves** are progress only, never sold
  (welcome 150, +10 per stage, +100 per graduation). **Sparkles** are the
  purchase currency, with a few earned like a merge game's level-up (welcome
  180, +5 per stage, +25 per graduation). Everything bought goes into the
  house's jar and everyone spends from it; the feed shows who added and
  spent. The **welcome gift** is about 1.5× a starter item in each currency,
  celebrated, so a new house buys something at once and keeps a little.
- **The finale** counts only what can be had without paying, so buying never
  delays it.
- **Nothing is bought without asking.** A confirmation with the price and
  what's left; the make-up offer when Leaves are short; "not enough" with a
  way to the Sparkles store, which comes back to the same question once
  there's enough.
- **The whole catalog is in the app** (v7): 39 species and 51 decorations,
  each had one way — free, Leaves, Sparkles, a pack, in season, with a
  holiday, or earned. What isn't drawn is sketched as its emoji until the art
  pass.
- **Decorating:** nine spots (a "Wearing" one joined in v7), Decorate mode,
  preview before buying. Holiday
  things are free while the day lasts, go back in the box afterwards, and return
  next year.
- **Holidays:** 49 days from 11 traditions, chosen per house, with suggestions
  per country. Religious days get free things only, never sold. Solemn days
  aren't dressed up.
- **The companion stays free** alongside the planned subscriptions, at the same
  pace for free houses.
- **The shop is an ordinary NestZone screen** (v9): glass cards on the
  Backdrop, the theme's accent, the system's `leaf.fill` and `sparkle` for
  money (`Amount`), one pressed-in `.depth` button for spending. No palette
  of its own and no drawn coins.
- **v8's six calls, answered (v9):**
  - The stage follows the hour: day or dusk by the scene's own curve
    (`ShopStage`). The Lab can still hold it at dusk.
  - Exactly one "Best value" tag, on the pack with the lowest price per
    Sparkle. The refill plays every time a pack lands, and the store is full
    screen so it's seen however far down you are.
  - Segment switches replay their entrances. That's kept; "don't animate
    what repeats" is for desktop tools.
  - The budget ring settles with no bounce (`Motion.dataDraw`), and so does
    every chart of money.
  - Settling up gets an "All square" stamp with a haptic, not confetti.
  - No motion is removed, only fixed or added to, across the app. The rules
    are in CLAUDE.md under "Motion".
- **Segment screens stay alive** (your call, 23 October): a switch shows a
  screen that's already built instead of building it again, and the
  entrances still replay. Next step 0.

## Still open (your call)

1. **What leaves with a person under the jar?** Recommended: nothing — the jar
   and what it bought stay with the house.
2. **Top-up prices.** Suggested: four packs of Sparkles (Leaves are never
   sold), around 300 / 1,000 / 2,200 / 5,000, on Apple's price tiers, with
   Turkish prices from local tiers.
3. **Free spots or free placement** for decorating. Recommended: spots, as built.
4. **Subscriber perks.** Suggested: 300 Sparkles a month into the jar, plus one
   exclusive seasonal thing.
5. **Deleting a house with a jar that isn't empty.** The warning should state
   both balances.
6. **StoreKit 2 or RevenueCat.** Your call at the money step. Either one
   replaces `SparkleStoreClient.liveValue` and nothing else; the server
   verifies every top-up either way.
7. **The make-up rate.** Built at one Sparkle per Leaf
   (`Exchange.leavesPerSparkle`). Two per Sparkle would make topping up
   cheaper; it's one number.

Calls made in v7 that you may want to change, all in `CompanionCatalog.swift`:
- The watering can and the windowsill are every house's from the start;
  dusk stays ✨ 160, as before (the plan had it seasonal).
- Holiday things with a price (the pumpkin, bats, baubles, the star, the
  gift box, the full moon, the winter sky) are free while their holiday lasts
  and on sale then to keep — but only during a holiday that isn't a faith's.
  Christmas puts the baubles out free; New Year sells them.
- Everyday things a holiday brings (fairy lights at Diwali, a lantern at Lunar
  New Year) are free that day, as before, and on sale as always.
- The party hat is free on any day the house calendar has a birthday;
  the tiny crown comes with growing every species that costs no Sparkles.
- Seasons that follow nature (cherry, tulip, maple, snowdrop, watermelon) turn
  round south of the equator; the pumpkin, the pine and the bunny keep their
  days.

## What's built

An MVP in the app, **Debug builds only** (`CompanionFlag`).

**The shop (v9):** `ShopDesign.swift` holds only what the companion adds:
the stage that follows the hour, the window each thing stands in, price
tags and badges. `CompanionShop.swift` has:
- the shop: three shelves as pages, each with its own scroll, under a switch
  in the bar; it can't be swiped away;
- the purchase card, snapped to the bottom edge, whose coins fly from the
  jar to the thing;
- the full-screen Sparkles store, whose pinned counter takes six sparkles
  from every pack that lands.

`Amount` and `JarAmounts` (`Design/Components/Amount.swift`) draw money
everywhere, and `.depth` (`Buttons.swift`) is the one button that spends.
The card replaces every system alert. Water stacks a pour per tap rather
than restarting one.

**The shop and the catalog (v7):**
- `CompanionCatalog.swift`: how each thing is had (`Access`), where it stands
  for a house today (`ShopContext.standing`), and paying (`checkout`,
  `Exchange`). Bought species are kept in the house file (`ownedSpecies`).
- The jar on the card opens the **shop** (decorations by spot, plants, pets
  and the two packs). **Choose** shows every species, usable first, with its
  price or when it comes back. Decorate's buy button and the jar there work
  the same way.
- Every purchase goes through `State.card` (v9; it was an alert in v7).
  "See Sparkle packs" opens the **Sparkles store** full screen; after a pack,
  if there's enough, it closes and asks about the thing again.
- `SparkleStore.swift`: a test store, four packs (300 / 1,000 / 2,200 /
  5,000), "Free test", nothing charged.
- Sketches: an undrawn species is its emoji, a seedling or an egg first, then
  growing with every stage, swaying, bouncing and drooping with the mood;
  lights and baubles hang round it. Undrawn decorations are their emoji in
  their spot. The winter sky is a drawn tint.
- The Lab can pretend it's a birthday (the party hat). Release, TestFlight
and App Store builds compile it but never show it. It's described in README.md.

**Growth** is read from `HouseTask.completedAt`, which the server already sends
for the Done list. So every phone sees the same growth from chores, with no
backend change.

**Everything else is on the device**, per home: the companion, care, the album,
the jar, the scene and the chosen holidays, in
`Documents/companion-<homeID>.json`. Two phones in the same house won't share
those until the server version.

**Verified:**
- v9, Debug on the simulator: the card's make-up, short and pay steps by
  night and by day; the shop and the store in English and Turkish; shelves
  switching while scrolled to the bottom, with no flicker; Water tapped
  repeatedly; Today scrolling itself at 0–1 late frames in 120; a Lists
  segment switch frame by frame (the underline draws out, travels and
  lands). Debug, Release (arm64) and the test target all build. The rest
  of the app's new micro-animations compile but were not watched one by
  one: a headless simulator can't be tapped.
- v7: Debug build, test target compiles. On the simulator, in English and
  Turkish: the confirmation, the make-up offer, "not enough", the store saying
  how many more the kilim needs, a pack bought and the make-up question back;
  the shop's three shelves, Choose, a sketched sunflower with lights, a bow and
  a balcony, a sketched kitten with a scarf, the duckling in a party hat.
- Debug build, Release build (arm64), test target compiles.
- v6, on the simulator:
  - the new tree for all six species, by day and at night;
  - the moods, including the dome when dozing and the bubble when thirsty;
  - the decorations hung on the canopy, the wind, and the pot staying still;
  - the welcome gift and the prices in Turkish;
  - labels on one line.
- v6, the gouache tree: all six species by day and at night, the cherry's
  bloom, fruit, the four moods, a wake-up from dozing, the falling leaf of a
  thirsty tree, decorations by day and night, and the Choose portraits.
- v6 frames (`-frameMeter`, simulator, Debug): Today at rest with a grown,
  decorated tree, 120 of 120 frames in every two seconds. Today flicking up
  and down, 118–120 with at most 2 late. Choose scrolling, 120, after one
  late frame as the sheet opens. With the Metal shaders it had been about 50
  of 120, and that was the stutter you saw. Not measured on a phone yet.
- A wake-up costs about 1.5 ms a frame to redraw the tree in a Debug build.
- In the simulator, on a real household:
  - the card, the thirsty and dozing wake-ups, the duckling;
  - Halloween, New Year and Diwali scenes;
  - Decorate, Our holidays, Choose, Album, the ceremony.

Per the working agreement, the tests were not run (build and typecheck only).

## Next steps: from here to the App Store

Is the MVP done? As something to try on one phone, yes: growing, moods, the
album, holidays, decorating, the shop, the whole catalog, every purchase
asking first. What keeps it from shipping:
- everything except growth lives on one phone, so two people in a house see
  two different jars, albums and scenes;
- no money changes hands;
- 32 species and 10 decorations are sketches;
- it has never been measured on a phone.

In order — each step can go to testers on its own:

0. **Keep the segments' screens alive** — done (23 October), view-only.
   - *What changed.* `SegmentedRoot` (`App/AppView.swift`) keeps a `@State`
     set of visited modules and draws a `ForEach` of them in the `ZStack`,
     with no `.id`. A hidden one is `opacity(0)`, `allowsHitTesting(false)`
     and `accessibilityHidden(true)` (`SegmentPage`); the `Motion.fade`
     crossfade stays. No reducer or backend change.
   - *Telling a screen where it stands.* `\.segmentPhase`
     (`Design/SegmentPhase.swift`) is set per segment: `onScreen`, `leaving`
     (while it fades out, 260 ms) and `away` (after). It is one value per
     segment, so a switch changes it for the two screens it concerns and
     invalidates only the views that read it there. Elsewhere it stays
     `onScreen`, so pushed screens and sheets are untouched.
   - *Toolbars and search.* `segmentToolbar`, `segmentSearchable` and
     `segmentFocus` (`Design/SegmentChrome.swift`) replace `.toolbar` and
     `.searchable` at the root of Tasks, Shopping, Notes, Calendar, Recipes,
     Movies, Finance and Issues, and release a field's focus on a switch so no
     keyboard is left over a hidden screen. The search sits in a `.background`
     rather than wrapping the screen in an `if`, which would rebuild it.
     Checked in the simulator on Lists and Plans: each segment's bar shows its
     own items, and the search button only on Notes and Meals. House was not
     looked at by eye (one button each).
   - *Entrances.* `appear`, `appearInPlace`, `drawIn` and `bounces` rewind when
     the phase reaches `away` (behind the opacity) and play when it is
     `onScreen` again, with the same Reduce Motion fallbacks; a row built
     while its segment is away waits for that return. A first build waits
     for the stage too, so its entrances play once, a few frames after the
     tap rather than in its frame.
   - *Nothing runs while hidden.* `pulse` and the two loading shimmers
     (`ImagePlaceholder`, `LoadingView`) stop off screen. Finance's square-up
     moment waits until its segment is on screen, so the stamp and its haptics
     are not spent unseen. Every other haptic in the eight screens is keyed on
     a local tap counter. `ConfettiBurst` is idle until triggered and lasts
     1.1 s, so it was left.
   - *Measured* (iPhone 17 simulator, iOS 26.5, `-frameMeter 1 -openTab <tab>
     -segmentCycle 4`; the worst frame in the 2-second window holding each
     switch, same machine, before then after):
     Lists: tasks→shopping (first) 286→224 ms, →notes (first) 115→110,
     →tasks 143→134, →shopping 133→75, →notes 77→98.
     Plans: calendar→meals (first) 294→292, →movies (first) 107→116,
     →calendar 234→232, →meals 159→86, →movies 117→93.
     House: finance→problems (first) 285→291, →finance 49→77.
     The simulator was loaded (load average ~8), so differences under about
     50 ms are noise.
   - *Staging a switch, and the scoped fade* (24 October, from a profile).
     A switch used to do everything in one frame: the fade, the underline, the
     bar rebuilt, the search coming and going, and every row of two screens
     re-reading the phase. `SegmentedRoot` now holds `onStage`, which follows
     `store.selected` by 50 ms: the fade and the underline land in the tap's
     frame, the phase (bar items, search, entrances) a few frames later. The
     fade is `.animation(Motion.fade) { $0.opacity(...) }` in `SegmentPage`,
     not an `animation(value:)` and `.transition` on the container, which
     animated everything the switch touched underneath. Warm switches, the
     worst frame per window, three runs of each tab on the loaded iPhone 17
     simulator (iOS 26.5): Plans 60–74 ms (was 64–99), Lists 56–81 (was 62–86),
     House 33–54 (was 46–50, noise). First switches did not move: 225–275 ms.
   - *Why the 50 ms is safe.* `onStage` is only ever assigned the module chosen
     at that moment, so a page becomes `onScreen` only by being chosen, and
     entrances play on the way into `onScreen`, so none can play on the page
     being left. In the lag, the page being left is still `onScreen` (its bar
     items stand for 50 ms, but it is untouchable and hidden from VoiceOver, so
     VoiceOver never points at nothing) and the page arriving is `leaving`.
     What must not outlast the tap uses `segmentChosen`, which moves with it:
     `segmentTask`, so Finance's square-up is cancelled when the segment stops
     being chosen, and its `abandonSquareUp` lands the stamp at once instead of
     slamming and buzzing behind another screen. (Making nobody `onScreen`
     for the 50 ms was tried: it costs about 15 ms back, since the old
     screen's phase change is the expensive half.) Finance no longer reads the
     phase in its `body`; no other module screen does.
   - *Sheets.* A sheet or a `navigationDestination(item:)` inside a segment
     inherits the segment's environment. Every reader goes through `LivePhase`,
     which answers `onScreen` when `isPresented`, so a sheet keeps its own bar
     and entrances whatever the segment behind it is doing. Not seen in the
     simulator (a sheet opened over a segment that is then switched away from
     is hard to arrange); check it on a phone.
   - *Alerts.* A failed write that lands after a switch away presents its alert
     over the segment now showing. Left on purpose: the copy names what did not
     stick.
   - *Looked at.* Lists, Plans and House in the simulator, mid-fade and at
     rest: each segment's bar shows only its own items, search only on Notes
     and Meals. Notes' search keeping its text across a switch was not driven
     (nothing here can type into the simulator). The same Plans run on an
     iOS 27.0 simulator was not possible: it needs a signed-in account.
   - *The slow "first return" was a first build* (24 October). `-segmentCycle`
     walked `dropFirst + all`, ending on the tab's last segment, and the last
     segment is remembered per device, so every later run opened on Movies,
     Notes or Issues. Its "return" to Calendar or Tasks was that screen's first
     build, 200–230 ms. Proved by log: with Calendar the opening segment there
     is no `CalendarView` body and no `DayCell` body on return, and the frame
     is 58–78 ms like any warm one; opened on Movies, `@identity` changes on
     the `CalendarView` at the same switch. The walk now goes others, the
     opening one, others again, home, and ends where it began.
   - *Building in beats* (`Design/Staged.swift`). A screen's first frame was
     most of its cost: SwiftUI looks up the whole type of the screen (every
     modifier, every branch) and builds it in one block. `stagedBuild(n)` at a
     screen's root and `Staged(k) { ... }` around pieces of it make the piece
     at beat k, one display frame after the one before (`FrameTick`; a sleep
     resumed the moment the main thread was free and put two beats in one
     block), starting once the screen is on stage. The piece is type-erased
     (`AnyView`) so its type is not part of the screen's, and fades up as it
     lands unless it was made later by a face switch. In use: Calendar (bar |
     grid | day panel), Issues and Finance (bar | the face). Only a first build
     is staged; a kept segment is already at its last beat.
   - *Measured* (iPhone 17 simulator, iOS 26.5, `-frameMeter 2`, worst late
     frame per switch, three runs each, before then after; `-appTabSegments`
     picks the segment a tab opens on): Calendar first 243–281 to 149–154,
     Finance first 243–249 to 129–157, Issues first 168–179 to 135–142.
     Unchanged: Recipes first 251–265 (224–315 after, noisy), Shopping 213–228,
     Tasks 185–199, Notes 116–160, Movies 105–162. Returns: Calendar 58–74 to
     60–78, Tasks about 64, Finance 52–61 to 47–55, Issues 47–51. Warm
     switches 40–120 before and after.
   - *Identical picture.* Month grid, Issues board and Finance overview, light
     and dark, before and after: no differing pixel in the content area
     (six pairs).
   - *Smaller things.* `DayCell` is `Equatable` (not the closure) and says its
     date once per day and language, so a month's cells redraw when their own
     day, dots or state change, and not forty-two date formats on every
     push. `-frameMeter 2` logs each late frame.
   - *What did not work, so nobody tries it again.* Resolving the screens'
     body types on a background thread beforehand (10–20 ms of 215). Erasing
     branches that are not taken (no change). Writing `TabSegments.remember`
     from an effect instead of the reducer: it took the tap's 14 ms off but
     Recipes' first switch got 60–90 ms worse. Staging a `List`'s rows or the
     whole list (Tasks, Shopping, Recipes): nothing measurable, and a staged
     whole list leaves the screen with no toolbar and no backdrop.
   - *Still open.* The first frame of a screen is 100–150 ms even with nothing
     in it: the screen's own modifiers (a dozen sheets, alerts, feedback and
     tasks are a dozen types to look up, about 40% of that frame in the
     profile) plus the switch. Below 150 needs fewer or shared modifier
     chains per screen, or the `List` screens' first build (UIKit list
     creation, about 100 ms of Tasks), neither of which can change the
     picture. The data arriving after the build is a frame of its own on
     Shopping (about 375 ms with a long list). This is Debug on the
     simulator, where unspecialised generics make every type lookup slow; a
     phone in Release has not been measured, and the iOS 27.0 simulator needs
     a signed-in account.
   - *iOS 27.* The 27.1 SDK was checked for anything that keeps a view
     hidden, shows or hides a toolbar item or search, or reports visibility.
     Nothing does; what it adds nearby (`visibilityPriority`,
     `toolbarOverflowMenu`, `CrossFadeNavigationTransition`,
     `TabsPickerStyle`) does a different job, so nothing is behind
     `#available(iOS 27, *)`.
1. **Measure on a phone.** A Debug build on a device with `-frameMeter 1`;
   scroll Today, Choose and the shop. Opening Choose still drops one frame on
   the simulator.
2. **Shared by the house — the server version.** Backend first, additive only:
   - Tables: `companions`, `companion_growth` (a ledger keyed per credited
     thing), `companion_scene`, the jar plus `jar_ledger`, `owned_items`
     (decorations and species), holidays per house.
   - Growth hooks in the existing writes: `tasks:update`,
     `shopping:setPurchased`, `meals:set`, `issues:setStatus`, `polls:vote`,
     plus an hourly sweep for events that ended. Each schedules a
     `companion:reconcile`.
   - `shop:buy`: the same checkout as `CompanionHouse.checkout`, make-up
     included, debiting the jar and adding the item in one write. The client's
     catalog and the server's must agree; the server's wins.
   - One live read, `companion:forHome`.
   - The app swaps `@Shared(.companion)` for a client with a live
     subscription; the feature's state shape stays.
   - Remember: one deployment serves every app version. Add, never remove.
3. **The vote for the next one** (a `generic` poll; a new poll kind would decode
   as `.movie` on old builds), and at most three notifications.
4. **The jar takes money.** Choose StoreKit 2 or RevenueCat; it replaces
   `SparkleStoreClient.liveValue`. Four consumables in App Store Connect,
   priced from Apple's tiers. `jar:topUp` verifies each transaction on the
   server, once; App Store Server Notifications for refunds (the jar can go
   below zero; nothing bought is taken back). The review notes say Sparkles are
   consumables, shared by the house, with no random boxes.
5. **The art pass** (its own job): the 32 sketched species — new growth rules
   for the plants, a few body plans for the pets — and the 10 sketched
   decorations; scenes as real backdrops; things to wear drawn on. Measure
   again.
6. **The finale**: "You've grown them all", the crown, growing a favourite
   again in a new colour.
7. **Release:**
   - turn `CompanionFlag` on for Release;
   - an accessibility pass (VoiceOver on the shop and the store) and one more
     read of the Turkish;
   - a feature-tier changelog entry for the version, written for the household;
   - bump `MARKETING_VERSION`; `./deploy.sh` (backend first).

## Before the next release

The motion pass isn't behind `CompanionFlag`. The micro-animations, the
"All square" stamp, the ring that settles, and the double-buzz and
double-shake fixes reach every household with the next version, whatever it
turns out to be. It has no changelog entry yet, because no version number
has been chosen (`stage` is 1.11.0, and so is `MARKETING_VERSION`). When it
is, add a `<version>-fixes` entry (kind `improvement`) in the same commit
as the bump. Draft, to be read once more:

- EN: "Fixes and improvements" — "Small things that make the app nicer to
  use." Highlights: "Improved animations and haptics all over the app",
  "Settling up now ends with an "All square" stamp", "Fixed taps that
  buzzed twice", "Fixed a wrong home code shaking twice".
- TR: "Düzeltmeler ve iyileştirmeler" — "Uygulamayı daha keyifli yapan
  ufak şeyler." Highlights: "Animasyonlar ve titreşimler elden geçti",
  "Borçlar kapanınca artık "Hesap kapandı" damgası basılıyor", "Bazı
  dokunuşlarda iki kere titreşme düzeldi", "Yanlış ev kodunda alanın iki
  kere sallanması düzeldi".

## Things learned the hard way

- **A toolbar button paints its label in the tint,** whatever the label
  asks for: the shop's jar came out violet on dark glass (~2:1) despite
  `.foregroundStyle(.primary)`. `.tint(.primary)` on the button fixes it.
  `Button(role: .close)` outside a toolbar draws the word "Close" in the
  tint, so the card uses an `IconButton` X.
- **One tap, felt once.** `.pressable` buzzes on press, so a control that
  also gives its own haptic on the tap uses `.pressableQuiet`; `Chip` ticks
  on its own, so a screen never adds one around it.
- **Compare against a baseline before blaming new motion.** A worktree at
  the last commit, built with the same Debug hooks and measured interleaved
  with the new build, showed the segment-switch hitch was already there.

- **Measure before fixing a "lag".** Instruments' Time Profiler can attach to
  the simulator (`xctrace record --device <sim UDID> --attach <pid>`), and its
  export summed per function shows where a frame goes. It showed:
  - The old tree was ~1,900 fills a frame; batching took it to ~20. That was
    not enough on its own.
  - The real cost was SwiftUI building and rasterising those paths 30 times a
    second on the main thread.
  - A layer drawn only on change removed it.
- **A CPU profile does not show stutter caused by waiting.** With the wind and
  a painted finish as SwiftUI shader effects, the main thread looked only ~12%
  busy, yet Today ran at ~25 fps: every frame it waited on the GPU for the two
  passes, and a wait is not a CPU sample. A frame counter (`-frameMeter`) is
  what showed it. The fixes that were tried:
  - Baking the tree into an image didn't help.
  - Hosting the scene in its own UIKit layer stopped the re-rendering, but the
    layout it added each frame cost more than it saved.
  - Replacing the distortion with a transform and dropping the finish took
    Today back to 60 fps.
  The shaders are kept in `art/shaders/` with their notes.
- **An `Equatable` view is what keeps a canvas from redrawing.** A canvas
  inside a `TimelineView` redraws every tick even when its inputs are the same;
  wrapped in its own `Equatable` view with `.equatable()`, it draws once.
- **A companion's seed is not its identity.** It is the home and the album
  count, so choosing again before anything graduates keeps it. Anything cached
  per tree is keyed on seed and species, or the new choice wears the old tree.
- **Hold the card still only when it is covered.** It pauses under Decorate,
  the moments, and any sheet pulled up to full height — not at half height,
  where it is still on screen: paused under the lab, points added there grew
  the tree unseen and it jumped when the sheet closed. Choose and the album
  draw their portraits as single still canvases (`ScenePortrait`).
- **A cached still freezes anything that was moving.** The prototype's falling
  leaf hung in mid-air in the picture; it moved to the scene's front layer,
  which animates. Check a port for every term of `t` before caching it.
- **A type name can clash across the module.** The port's private `Segment`
  collided with the tab bar's `Segment` and broke the build with misleading
  type-check timeouts. Give private helper types specific names.
- **Read SwiftUI state in `body`, not only in a `Canvas` closure.** The scene
  first drew without its tree about half the time. The tree is built `onAppear`,
  but `body` never read it, so SwiftUI didn't know to hand the timeline a fresh
  closure. `CompanionScene` now builds a `Snapshot` of all animated state in
  `body` and draws from that.
- **The simulator is headless here.** No window to click. Drive states with
  `tools/scenario.sh` (writes the companion file and passes `-companionDemo`),
  and remember to reinstall the build before running it. The app takes about
  ten seconds to reach Today, so take screenshots at 12 seconds or later.
  `-companionDemo buy | makeup | short | topup | shop | store` drive the
  purchase questions and the store; `-companionShelf plants | pets` opens the
  shop on that shelf.
- **An alert can't come up from under a sheet.** The purchase questions are
  attached to the sheet (`CompanionSheet`), not the card — every purchase
  starts in one.
- **Headless Chrome barely runs `requestAnimationFrame`.** To check a prototype
  animation, step the page's own `frame(t)` by hand from a harness, after
  zeroing its `last` and stubbing `requestAnimationFrame`.
- **`git diff` on `Localizable.xcstrings`** can show thousands of deletions that
  aren't there. Compare the JSON keys, or use `--diff-algorithm=histogram`.
- **The generic simulator destination fails to link** (the Convex static library
  is arm64-only). Build Release with
  `-destination 'platform=iOS Simulator,name=iPhone 17'`.
- **Turkish names:** check what is actually drawn. Avoid "Palamut" (it's the
  fish). "Ay yıldız" reads as the Turkish flag, so the crescent garland is
  "Hilal ve yıldızlar".

## Working agreements (from this machine's memory)

- Build and typecheck only; never run `xcodebuild test`.
- Verify, never guess: ask for missing facts and check the checkable ones.
  (Holiday dates were checked against official sources. See HOLIDAYS.md.)
- In the UX rework, never delete a feature: move it, redesign it or make it
  optional.
- Show proposals as a local HTML file opened in the browser, never a published
  artifact.
- Commit only when asked. Pushing `dev` is fine when asked; only
  `./deploy.sh` moves `stage`, which is what Xcode Cloud builds.
- `graphify query "<question>"` before reading or grepping source (a hook
  insists, subagents included), and `graphify update .` after changing code.
- Strings go through `tools/l10n_tool.py`, which writes `L10n.swift` and
  `Localizable.xcstrings` together.

The raw session transcript stays on the original Mac, under
`~/.claude/projects/`. It isn't committed: it's large, full of tool output, and
holds household data. This file is the portable version.
