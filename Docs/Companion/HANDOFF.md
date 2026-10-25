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
   - *The 40% was found* (24 October, `xctrace` Time Profiler; frames from
     the simulator's runtime are symbolicated by running `atos -l <load
     address> -o <image in the simulator's RuntimeRoot>` on the exported
     addresses). In a `List` screen's first build 140–170 of 400 samples are
     `swift_conformsToProtocol`, almost all under `DynamicPropertyCache.fields`:
     SwiftUI asks, once per field type of every view and modifier it meets,
     whether the field is a `DynamicProperty`, and the answer (yes or no) is
     cached for the process. An interposed `swift_conformsToProtocol` timed a
     cold ask at 0.85–1 ms, and a warm one at 0.0006 ms. It is the simulator:
     its frameworks are separate images on disk, so every cold ask reads all
     their conformance records, where a device answers from the dyld cache's
     table and reads only the app's ~4,000. `SIMCTL_CHILD_SWIFT_DEBUG_ENABLE_
     SHARED_CACHE_PROTOCOL_CONFORMANCES` changes nothing here.
   - *A warm-up was tried and dropped.* Asking the same questions on
     background threads after launch (Debug, simulator only) took 10–60 ms off
     each first build — Meals 228–246 to 177–201, Shopping's data frame
     206–228 to 162–174, Tasks barely — by walking 5,365 types through the
     runtime's private reflection entry points for ~4.8 s of eight threads.
     It made the simulator's numbers better and the app no better, so it is
     not in. With every runtime cache warm, a `List` screen's first build is
     120–140 ms in Debug: that is the simulator's floor, not a device's.
   - *Not reproduced.* Shopping's 375 ms data frame needs a long list; this
     household's is four items and arrives in 160–230 ms, mostly cold asks and
     the first `Text` formats. The code that grows with the list
     (`eventSections`, the grouping) was not profiled with a long one: add
     items, then read `-frameMeter 2`.
   - *Still open.* The `List` screens' first build is 115–200 ms on the
     simulator in Debug, and most of what is left of it is the simulator's
     lookups (above), not the screen's modifier chain as first thought.
     Shopping's 375 ms data frame needs a long list to reproduce: add items,
     then read `-frameMeter 2`. The phone has now answered (step 1): first
     builds are 42–86 ms there, not 115–290, so the `List` screens' first build
     is no longer worth work. What is open instead: the single 50 ms warm
     switch to Shopping (one frame, one run in two; undiagnosed, the trace was
     not kept), and the offscreen passes the first switches show (step 1).
     The iOS 27.0 simulator needs a signed-in account; the phone is on 27.0.1.
   - *iOS 27.* The 27.1 SDK was checked for anything that keeps a view
     hidden, shows or hides a toolbar item or search, or reports visibility.
     Nothing does; what it adds nearby (`visibilityPriority`,
     `toolbarOverflowMenu`, `CrossFadeNavigationTransition`,
     `TabsPickerStyle`) does a different job, so nothing is behind
     `#available(iOS 27, *)`.
0b. **Launch** — an optimistic launch built (24 October), not yet measured
   cleanly.
   - *What the previous pass found* (Release + `MEASURE`, iPhone 17
     simulator): about 700 ms before `main` is simulator dyld, which a phone
     does not pay; about 140 ms of store init; about 500 ms of session restore
     (network) with the launch screen up and the main thread idle; then a
     570 ms Today frame, nearly all SwiftUI building the `TabView` and
     `NavigationStack` for the first time (app code about 60 ms; the dock and
     Nestie each under 10%). `LaunchWarmup` took the first `Text`'s cost off:
     about 130 ms of CPU, 27 ms of wall clock. The offscreen-pass lead on the
     segment fades has a structural explanation (glass and vibrancy layers
     under a fractional opacity) that the simulator cannot show; on a phone,
     run Animation Hitches with and without the fade, and if it confirms it a
     snapshot crossfade is the candidate. Tooling: `xctrace` on the simulator
     shows running samples only, so use `sample <pid> 5 1` right after
     `simctl launch`; the Simulator's Debug menu and `CA_COLOR_OFFSCREEN` are
     not available headless; an aborted `xctrace` leaves `instruments*.ktrace`
     in `$TMPDIR`.
   - *What was built.* With a stored session and a cached home, Today and the
     tabs are drawn from the cache while the restore runs behind them
     (`AppFeature.State.isProvisional`). convex-swift does not wait for auth:
     `subscribe`, `mutation` and `action` queue their message at once, and
     the Rust client sends it with no identity (`convex` crate, `base_client`:
     nothing in `mutation`/`subscribe` looks at the auth state). A
     `requireUser` query throws, which ends the Combine publisher for good, and
     a mutation is refused, not parked. So `ConvexConnection.gate`
     (`AuthGate`) holds them: reads wait for the session, writes wait too and
     fail with `.offline` once the restore has found no network (the callers'
     rollback puts the old value back), and a refused session ends the reads
     quietly (no alert) and fails the writes with `.notAuthenticated`. The
     provider's single restore and its semaphore are untouched; an optimistic
     launch retries every few seconds, forever, instead of three times and the
     retry screen. Signing out from Settings before the restore has answered
     stays on a spinner until the restore ends or 10 s pass, then signs out with
     whatever push token exists and ends the session itself (the SDK's
     `.unauthenticated` is ignored while provisional, and `CurrentValueSubject`
     re-sends on `logout()` but only on its success path, so it cannot be
     relied on). If the token has not arrived by then, the sign-out
     unregisters the last token the device registered with (`PushTokenMemory`,
     in `UserDefaults`, written when a register succeeds), so an earlier
     launch's registration does not outlive it; it is forgotten once the server
     has dropped it, and kept if the call failed. A token iOS reissued between
     launches is handled at register time: the stale one is unregistered and the
     new one remembered, and sign-out unregisters both this launch's and the
     remembered token when they differ. Convex runs one client's mutations in submission order, so an unregister
     cannot overtake a register already sent. A write waits at most 8 s;
     released writes run in parallel, in arrival order at the start, like every
     other write. A refused
     session goes to the sign-in screen and now also
     clears the cached household (before, the file survived such a launch). A
     rejection also skips the one-second retry that used to precede it.
   - *Hooks.* `-optimisticLaunch 0` launches the old way, to measure the two
     against each other; with `-frameMeter 1` the log carries `launch: first
     view` and `launch: Today first frame`, in milliseconds since the process
     was created.
   - *Numbers* (simulator, Release + `MEASURE`, Today first frame since process
     start, ms): the machine was at a load average of 100+ because of other
     builds, so these are ordering, not size. Old / optimistic, three
     interleaved pairs: 1971 / 1348, 1654 / 1485, 2128 / 1805; first view was
     740–1100 in both. The restore overlaps the Today build now, so the
     difference should approach the restore's 500 ms on a quiet machine.
     Not done: five clean pairs, and a `sample`. The simulator lost its
     session part-way (see the report: the app is terminated seconds after
     launch in the script, which can kill an exchange that has rotated the
     token), and it needs a signed-in account again.
   - *A phone must confirm:* Today's first frame with the network on and with
     it off (the cached Today should stay and the writes should roll back);
     that no placeholder flicker or entrance replays when live data lands; a
     refused session (revoke it on the server) lands on sign-in with no
     household left on screen; sign-out before the restore answers, online
     (signs out when the restore ends) and offline (after 10 s); offline, sign
     out, sign in again, and `users:me` and `homes:listMine` come up. **The
     roughly 500 ms gain has to be measured on a phone** (and on a quiet
     simulator): the three simulator pairs above were taken under load.
   - *Open product question.* The app has no offline indicator except the
     full-screen retry view, which an optimistic launch never shows. A phone
     with no signal keeps the cached Today with placeholders and writes that
     roll back after 8 s, and nothing says why. Whether that needs a cue is the
     owner's call; nothing was added.
1. **Measure on a phone** — partly done (24 October): the segment switches.
   - *Setup.* iPhone 16e (60 Hz), iOS 27.0.1, a **Release** build with the
     hooks compiled in (`MEASURE`, CLAUDE.md, Commands), launched under
     `xcrun xctrace record --template 'Animation Hitches' --instrument os_log
     --device <udid> --launch com.walhallaa.NestZone --time-limit 40s -- <args>`.
     The template gives the system's hitches; the `os_log` instrument carries
     the frame meter (`-frameMeter 2`), which the device otherwise only shows
     to root (`log collect` wants sudo). Export both with `xctrace export
     --xpath '/trace-toc/run[1]/data/table[@schema="os-log"]'` (and
     `"hitches"`). The app must not already be running, or the recording ends
     at once with no rows. Kill a hung `xctrace` and delete
     `$TMPDIR/instruments*.ktrace`: an aborted run leaves gigabytes there.
   - *Numbers* (worst late frame per switch, ms; Release on the phone, two or
     three runs, then the iPhone 17 simulator in Debug from step 0):

     | Switch | Phone | Simulator |
     |---|---|---|
     | Lists, first build | 48–86 (one 261 on Shopping, not repeated) | 110–224 |
     | Lists, return | 31–45 | 134 |
     | Lists, warm | 30–50 | 75–98 |
     | Plans, first build | 42–52 | 116–292 |
     | Plans, return | 34–35 | 232 |
     | Plans, warm | 30–41 | 86–93 |
     | House, first, return, warm | 25–33 | 77–291 |
     | First window after launch | 138–222 | n/a |

     Two or three late frames per switch, not one. The 40% was a simulator
     artefact in the sense that matters (first builds are 3–5 times faster on
     the phone, warm ones about 2), but this compares Release on a device with
     Debug on a simulator, so it does not separate `-Onone` from the
     conformance lookups.
   - *What the hitches say.* The 50–67 ms system hitches in the first switches
     of Lists and Plans carry "potentially expensive render, 44–54 offscreen
     passes" and "expensive GPU work": the crossfade of a whole screen as one
     group is rendered offscreen. It is a lead, not a diagnosis; no profile of
     it was taken. Nothing else on the phone is over 66 ms but the launch.
   - *Not measured, still to do:* Today scrolling (`-todayScroll 1`), Choose
     (`-companionDemo choose`, `-companionScroll 1`) and the shop
     (`-companionDemo shop`, `-companionShelfCycle 1`) — the owner took the
     phone back first; cold launch with the App Launch template; House with the
     second opening (`-appTabSegments "tasks,calendar,maintenance"`); Time
     Profiler on the 50 ms warm switch to Shopping and on the offscreen passes.
     Whatever is on the phone is the Release+`MEASURE` build, not a Debug one:
     reinstall a Debug build (or TestFlight) before it is used.
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

   **The backend is deployed (852fec8, 24 October).** It typechecks, and
   both rounds of the Convex review's blockers are fixed. Nothing existing changed its
   arguments or its return. No shipped build calls it yet, so it can still be
   widened (never narrowed); the API freezes when the first client build that
   calls it ships. A second, additive round — readiness, `grownSpecies`,
   graduate-before-start, the wake, `start`'s `requestId`, `RULES_VERSION` 2 —
   is built and reviewed, waiting on its deploy; after it, run
   `npx convex run companion:scheduleMissingWakes '{}'` once.
   - *Tables* (all new):
     - `companion_homes`, one per house: the jar's two balances, `welcomed`,
       what was bought (decor and species, bounded by the catalog), the
       layout, the holidays (absent means the region's), region, `tz_offset`,
       the one growing, the album's count and species, and the imports'
       high-water marks. The plan's scene, jar, holidays and owned items
       became this one row, so the card reads one document.
     - `companions`: the one growing and the album (`growing`, `graduated`,
       `released` when swapped before graduating). `points` is kept on the
       row, never summed on a read.
     - `companion_growth`, the ledger: one row per credited thing, its key
       unique per companion (`task:<id>`, `shop:<id>:<at>`, `meal:<date>`,
       `fix:<id>`, `poll:<id>`, `event:<id>:<start>`,
       `care:<companion>:<user>:<day>`). Nothing counts twice, and a
       graduate's rows are its history: never moved, never recounted.
     - `companion_days`: each day's tally, the rest bank, and the house's size
       as of that day (written the first time the day is counted, so a member
       moving in doesn't regrow last month). A change recounts that day and
       carries the bank through the few after it, moving `points` by the
       difference.
     - `jar_ledger`: signed moves, each keyed once (`welcome`,
       `stage:<slot>:<n>`, `graduation:<slot>`, `buy:<requestId>`,
       `import:<userId>`, later `topUp:<txn>`). The balance and its row are
       written together (`moveJar`), so the jar and its feed can't disagree.
       A reward's slot is the house's place in its album (`album_count`
       when paid), not the companion: letting one go and starting another
       never pays a stage twice, only a graduation moves the slot, and only
       the one growing can graduate. Every credit is once per real
       achievement: the welcome once per house, a stage once per slot, a
       graduation once per slot, and `graduate` refuses anything younger than
       six days. The curve alone could get there in about three — a day
       split across a midnight counts twice — so the floor is held there,
       not trusted to the arithmetic. That rule is one function,
       `readiness` (growing, the house's current one, 64 points, six days
       old), and `graduate`, `start` and `forHome` all ask it.
     - **A ready one is never let go** (24 October). `start` called while
       the current one `readiness` says is ready graduates it first, in the
       same write, through the same `graduateNow` `graduate` uses — the
       album card, `graduation:<slot>`, the slot moved — and only then
       starts the new one in the next slot (its stages key on the new
       `album_count`). Chosen over refusing because the case is a phone
       whose `graduate` failed and that moved on to Choose, or a second
       phone choosing mid-ceremony: the house did grow it, so refusing
       would strand a choice behind an error for a tap-order problem, and
       releasing it would lose the card and the reward. `start` returns
       `graduated` so the phone can show it; a late `graduate` for it finds
       it graduated and pays nothing. The new species is checked against
       the house after that graduation, so what it just earned counts; a
       refusal throws and undoes the graduation with it.
     - **`start` takes an optional `requestId`**, the tap's, stored on the
       new row (`start_request`) with the one it graduated (`follows`). A
       retry with the same id while that one is still the house's current
       returns the first answer — the same `companionId`, `welcome: null`,
       and `graduated` naming the one it followed with `paid: null` — and
       releases, starts and pays nothing. Without an id, the 10-second
       same-species guard still covers a double tap.
   - *Growth is the sim's curve* (`tools/growth_sim.py`), and the server's
     number is the truth (your call, 24 October): a day's life is
     `9·(1−e^(−raw/R_N))`, care at most 2, with the sim's rules (a repeated
     chore a quarter, a quick log half, past four a person's chores halve, two
     shopping trips, two events, two fixes — a problem fixed within ten
     minutes of being written down counts half — one movie, the rest bank).
     64 graduates; stages are the app's thresholds. Care counts once per
     person per day. A companion counts its days in the offset the house had
     when it arrived (`companions.tz_offset`), so moving the house's days
     can't add any under one that is growing.
   - *Hooks.* `noteGrowth` in `tasks:update` (ticked or reopened),
     `tasks:removeFinished`, `shopping:setPurchased`, `meals:set`,
     `meals:clear`, `issues:setStatus` (to or from fixed), `polls:vote`
     (movie rounds, and only a vote that can move the answer) and
     `polls:unvote` (a yes taken back): one indexed
     read, and a scheduled `companion:reconcile` only for a house growing one.
     The reconcile reads the thing back from its own table, so it is right in
     any order and any number of times.
     - Shopping is credited per trip (`shop:<id>:<at>`): a second tick of the
       same item within 12 hours is the same trip, and an untick takes the
       credit back only within 2 hours of it (a slip). Unticking something
       bought last week takes nothing, because that trip happened; ticking it
       again next week is a new one.
     - A movie round counts once two people (or the only one) said yes to the
       same title. Bills don't count yet.
     - The hourly cron `sweepEvents` walks the companions that are growing,
       20 houses a page, not the deployment's events. Each house is two reads
       of at most 100 on `by_home_series_end` — what could only have ended
       inside the window, and what runs on past it with `FOREVER` series
       first — so a house with many one-offs planned ahead can't push its
       standing series out, and a page stays near 4,000 reads. It credits
       occurrences that ended in the last three hours (the key makes the
       overlap harmless) and the day's planned dinner once it is 17:00 in
       the house; a dinner, today's included, never counts before then. Each
       page and each credit is caught and logged, so one house failing costs
       nobody else; the next hour picks up what was missed. No write
       schedules a job of its own.
     - An import's chore backfill is a page of 100 at a time, each page
       scheduling the next, at the live path's weights. The chain is pinned
       to the companion and the start it was made for, and stops if either
       moves.
   - *`shop:buy`* is `ShopContext.standing` and `checkout` ported, make-up
     included. `requestId` is the tap's: a retry with the same thing returns
     the first answer (made-up Leaves included) and never debits twice; the
     same id for a different thing is refused; a second phone buying the same
     thing gets `owned`. `expectedPrice`, required, is what the card showed;
     if the catalog says otherwise nothing is bought (`priceChanged`). Every
     outcome the card has a screen for is a status: `bought`, `owned`,
     `short`, `unavailable`, `priceChanged`.
   - *Where the house is.* Region and offset are set when the house's row is
     made and move after that only through `companion:setPlace`, which fills
     in what's missing at once; after that the offset moves at most once a
     day and the region at most once in 30, so the hemisphere can't be
     flipped to bring a season's species round early. A phone travelling
     does not move the house.
   - *Reads.* `companion:forHome`: the version, the house (with
     `grownSpecies`, bounded by the catalog, for the shop's "grown them all"),
     the one growing (points, stage, paid stage, last care, the caller's care
     days on it, at most 60, and its readiness: `isReady` is `graduate`'s
     own answer, `pointsReady` the 64 points alone, `readyAt` the six-day
     floor, `startedAt + 6 days`, which is also what is sent while the points
     aren't there), the newest 120 credited things for the mood, the newest
     30 jar moves (who added, who spent). A query doesn't re-run because
     time passed, so every companion gets exactly one scheduled
     `companion:wake` at `readyAt`: from `start` right after the insert, and
     from `importLocal` when it creates one or moves one's start (a wake is
     pinned to the start it was made for, so one for an old start does
     nothing). It only stamps `of_age_at` on the row to make every card's
     read run again; the rule stays the clock. Run early, it reschedules
     itself at the floor instead of stamping. Companions growing from before
     the wake existed get theirs from the one-off
     `companion:scheduleMissingWakes` (the `by_status` range whose floor is
     still ahead, a page of 200 at a time); duplicates are accepted rather
     than tracked, because the second wake to run finds `of_age_at` set and
     does nothing.
     `companion:album` is its own read, opened with the album. Writes: `setPlace`, `start` (the welcome, once),
     `care`, `graduate`, `setLayout` (filtered as Decorate's Done is),
     `setHolidays`, `importLocal`.
   - *One catalog.* `tools/catalog_export/export_catalog.sh` compiles the
     app's own `CompanionModels.swift`, `CompanionCatalog.swift` and
     `Holidays.swift` and writes `backend/convex/lib/companionData.ts`:
     prices, access, packs, stages, rewards, every holiday's first days for
     2025–2036 as Foundation computes them, the defaults per region, the
     south. The Swift stays the one source and the server never re-derives a
     lunar calendar. `forHome`'s `catalogVersion` is the file's hash plus
     `RULES_VERSION` (lib/companion.ts), bumped by hand whenever a rule there
     changes an answer. Foundation's calendars can move a lunar date between
     macOS releases, so the output is checked in and its diff reviewed like
     code; a diff nobody expected is a question, not a commit. Run it with
     any catalog change, in the same commit, backend first.
   - *A test phone's MVP file* (`importLocal`). The MVP only ran on Debug
     builds, so only the admins (`lib/admin.ts`) and the ids in
     `COMPANION_IMPORT_USER_IDS` may import; anyone else, and anyone after
     `IMPORT_SUNSET` (31 March 2027), gets `closed`. Once per person per
     house. A file is a phone's word, so it is taken only as far as the house
     could really have got, and the same house results whichever phone comes
     first:
     - **no Sparkles, ever, and nothing priced in them** (your call, 24
       October, belt and braces: the MVP's Sparkles were free tests, and the
       test store's are reset when the jar starts taking real money, step 4);
     - Leaves are capped at what the file could have earned — the welcome if
       the house hadn't had it here, six stages and a graduation per album
       card accepted, the paid stages of the one growing — and credited only
       above the most any import has brought (`import_max_leaves`), so
       imports come to the largest, never a sum;
     - what was bought is the union of Leaves-priced things; the holidays are
       the union with what the house keeps now, region defaults included;
     - album cards are kept only if they could have been grown: at least six
       days each (64 points at 11 a day), none overlapping another card or a
       companion the house chose here and is growing, and no more of them
       than six-day runs fit since the MVP first landed (`IMPORT_EPOCH`, 20
       October 2026, a471076);
     - the one growing is the earliest started, its start clamped between
       `IMPORT_EPOCH` and now, if the house could grow it today — judged
       before this file's purchases count, so a file can't grant itself a
       species and pass — and it started after the album's last card; a
       later phone replaces one an import made, never one chosen here, and
       its scene comes with it. The stages its file was paid for are marked
       paid in the slot;
     - care days count from the last fortnight only; the lab stays on the
       phone;
     - growth is recounted from the chores since it started, so an imported
       companion may land at a lower stage than the phone showed (your call,
       24 October: the curve is the truth). Stages already paid are never
       paid again or taken back.
   - *Deleting a house* drops its `companion_homes` row with the house and
     drains the rest in batches (`companion:purgeHome`), so leaving never
     waits on a long ledger.
   - *The client swap* — **done (24 October), not yet run against the real
     house.** `CompanionClient` (`Core/Network/Clients/`) holds the live
     `companion:forHome` (the whole card, decoded by `CompanionPayload`; kinds
     lenient, rows lossy, an unreadable companion is an error state and never
     "none"), `companion:album` (live only while the album sheet is open; the
     shop reads `house.grownSpecies`), and the writes `setPlace`, `start`,
     `care`, `graduate`, `setLayout`, `setHolidays`, `importLocal`, `shop:buy`;
     all through `ConvexConnection`, so the auth gate covers them.
     `CompanionFeature.State` keeps its shape: `house` is computed from
     `served` (the server's) with the in-flight `writes` and the Lab laid over
     it. Failures alert (`AlertState.failure`), except a care tap, which just
     un-checks the button. How it holds together:
     - *An entry shows only while `served` does not already show it* (a buy's
       debit stops once `served` owns the thing, a start's companion once
       `served` is growing it, the welcome while `served.welcomed` is false), so
       the answer and the push can arrive in either order. On the answer, what
       the server returned is folded into `served` (layout, holidays, care day,
       the jar after a buy) and the entry goes; a start's and a graduation's
       entry wait for the push that has the new companion. Graduation is drawn
       before a start. A timeout (15 s) is a failure; request ids make a late
       arrival harmless. A lost answer that the push already shows is not an
       error. Floaters ("+10") fire from the write and the server's real
       `welcome`/`paid`, once per write, never from a delivery for a write of
       ours. `-nestieOrder pushFirst|answerFirst` runs either order.
     - *Buying.* Debit locally, `shop:buy` with a request id per tap and the
       card's price. `bought` confirms, `owned` shows the item as had,
       `short` shows "not enough", `priceChanged` re-asks at the server's
       price, `unavailable` and a network error show a notice on the card. A
       lost answer keeps the request id, so Try again is the same purchase.
       `start` has its own per-tap request id and may answer `graduated` (a
       ready one was graduated first): its coins and a one-time ceremony.
     - *The timeout* (15 s) is one continuation resumed once by the call, the
       sleeper or a cancel (`WriteRace`), because the Rust call ignores
       cancellation and a task group would wait for it; a late success is
       ignored and the push corrects the screen.
     - *A graduation is never lost.* One that `start` brought is held in
       `State.moment` (memory only; after a relaunch the album card is the
       record) and plays once, 450 ms after no sheet is open and none is about
       to open (`momentReady`; `pendingSheet`/`placeOnOpen` declare what is
       about to). Presenting it in the action that closes a sheet is dropped by
       SwiftUI, hence the delay. A graduation pushed from another phone shows
       no ceremony today.
     - Answered start and graduation entries also go when the served companion
       moves on, and after 120 s; an unanswered choice's request id is dropped
       once the house is growing something else.
     - *Ready* is the server's `isReady` as sent; `readyAt` is the "Ready on …"
       line. The client has no day floor of its own.
     - *Nothing the Lab influences is sent.* The server calls use `serverShop`
       (`served` and `now` only), Decorate's Done and Dress go through
       `serverSafe`, the care gate and key use `now`, a buy under Lab coins
       stays in the Lab. The Lab is a local preview in its own file
       (`companionLab-<home>.json`); the test store's Sparkles land there too
       (the server's `jar:topUp` exists since step 4; the test store never calls it).
     - *Place* once per launch, only when the house row lacks it. *Import:* the
       MVP's file is offered once per person and home (mark in UserDefaults,
       written on any answer or error that asking again would repeat, never
       after a transport failure); the file is never changed.
     - *Delivery cost.* What the card draws (`jar`, `look`, `mood`, `stage`,
       `visibleLayout`, …) is worked out once per action in `refresh()` and
       assigned only on change, and the card is built of small views that each
       read their own part. Measured in the bench (Debug, simulator, Today-like
       scroll): quiet 120/120 with 0 late; a push every 400 ms that only adds
       activity 0 late; a push that also moves the points every 2 s, 0–4 late per
       2 s (it redraws the scene's growth). Before the split the same
       400 ms push cost 0–3 late per 2 s.
     - *Catalog version:* `CatalogVersion.exported` (kept by
       `export_catalog.sh`) is compared with `forHome`'s and logged.
     - *Bench:* `-nestieBench 1` (`NestieBench.swift`, Debug) runs the real
       feature against a stand-in server with no session; its header lists the
       scenario, script, order and failure arguments. Every write was run in
       both orders. Tests: `CompanionServerTests` (written; the suite was
       built, not run). Still to do signed in: a real `forHome` decode, one
       care tap, a start, an album open, the frame meter on the real Today.

3. **The vote for the next one** (a `generic` poll; a new poll kind would decode
   as `.movie` on old builds), and at most three notifications.

   **The server side is built (24 October), typechecked and dry-run, not
   deployed or committed.** Additive only: a `companion_votes` table, four
   optional fields on `companions` (`undecided`, `chosen_at`, `vote_id`,
   `notified`), `companion:decide`, three internal mutations (`voteChanged`,
   `membersChanged`, `closeVote`), wider returns on `forHome` and `graduate`,
   guards on `polls:vote`, `unvote`, `addItem`, `remove` and `setStatus` that
   only fire for this poll, a scheduled re-check in `homes:leave` (its
   arguments and return unchanged), and two internal-only options on
   `push.notifyHome`. The dry run deletes no index. The rules are in
   `lib/companionVote.ts`; the writes are in `companion.ts`. Reviewed once;
   the fixes are in. (While this was being written, the deployment gained the
   `companion_votes` table and its indexes from another push, without these
   functions, so the latest dry run lists no index to add.)
   - *Who and when.* The server opens it, inside `graduate`, when the house
     has two or more members and at least two things to choose. A house of
     one picks as before (`start`). So does `start`'s graduate-first path:
     that phone is already choosing.
   - *A seed grows meanwhile* (the plan's promise). The same write starts the
     next one as a seed (`undecided`), the first option standing in for its
     species, so chores, care, events and dinners while the house decides all
     count, and its six days run from the graduation. A seed is never ready
     (`readiness`). The vote gives it a species; the growth stays.
   - *The options.* Three: the best plant, the best pet, the best of the rest.
     Only what `start` would take today (every house's, bought, earned, in
     season), never the one that just graduated. Bought and not grown leads
     (the newest arrival), then in season, earned, every house's; anything in
     the album comes last. Within a tier the order turns by the album's count,
     so two graduations in a row don't offer the same three.
   - *The ballot.* Yes or no per option, swiped like movie night, through
     `polls:vote` with the species as the target. A ballot grows nothing.
   - *How it ends.* When every member has answered every option (asked again
     after each new answer, and when somebody leaves the house); after 24
     hours; when someone settles it (`decide`, on the ballots so far, once
     somebody else has answered); or when someone picks before anyone else has
     answered (`start`).
   - *The winner.* Most yeses among current members. A tie goes to one the
     house hasn't grown, then to the fewer noes, then to the server's order.
     It has to be growable at that moment (a season can end inside the day);
     if it isn't, the next one wins.
   - *Nobody says yes.* It closes with no winner and no notification. The
     seed keeps growing, and whoever picks first picks: any species the house
     can grow.
   - *Twice can't happen.* The vote turns `closed` in the write that applies
     the species, and Convex runs two closing writes one after the other: the
     second finds it closed and answers with what was chosen.
   - *Picking instead of voting* (my call). Nobody waits on anybody, and no
     answer is thrown away. A member may pick straight away, any species,
     until someone else has answered; after that they vote or `decide`, and
     `decide` counts every answer exactly as the deadline would. A free
     override would make the vote theatre, and no override would hold a house
     to the slowest phone for a day. `decide` waits for one other answer
     rather than an hour: settling a vote nobody else has touched is just
     picking, which `start` already does, and a waiting time would only hold
     up the person who's there.
   - *The house's choice holds until it graduates.* A pick that lands after
     the vote chose (a phone that was offline, Choose left open) gets the same
     answer if it agrees and "The house already chose" if it doesn't. It can
     never let the choice go, along with its growth. There is no window for a
     change of mind: one member undoing the house's vote is the case it
     guards against. The next chance is the next vote, and a ready one still
     graduates through `start` as always. A seed that one person `picked`
     before anyone else answered can be changed like any pick.
   - *Old builds* (verified in the review with git). Every TCA build has
     `case movie, recipe, generic` (`Poll.swift` since 3efc4a5, and on `stage`
     at 1.11.0), so a `generic` poll decodes as `generic`, never as the
     `.movie` fallback. They list polls by kind, too: `.movie` in movie night,
     `.recipe` in dinner, `.movie` in the dock (dev). Pre-TCA builds filter on
     the string, `$0.type == "movie"` (`PollsManager.swift:129`). So a
     `generic` poll is never drawn anywhere. The server never calls
     `polls:create`, whose `polls` push every build routes to the movie game.
   - *Three notifications,* through `push.notifyHome`, so each lands in the
     feed: `ready` (all grown up, to the whole house), and only where there's
     a vote, `vote` (it opened) and `arrived` (it was chosen; not to whoever
     chose it). A seed that grew up while nobody chose gets `ready` alone when
     it is chosen, with `arrived` marked rather than sent a second later.
     Category `companion`: an old build shows a plain row that goes nowhere,
     never the movie game. Each is keyed once on `companions.notified`,
     written in the same mutation that schedules the push. The copy is in both
     languages; English is sent, as by every other push, because nothing on
     the server knows a reader's language.
     - *Who hears them: `COMPANION_NOTIFY`.* Unset or `off`, nobody: no push,
       no feed row. Only Debug builds draw Nestie, and every build reads the
       feed. `sandbox`: pushes only to devices on the APNs sandbox gateway
       (development-signed Xcode installs; `push_tokens.environment` is the
       gateway the token really works on, corrected on the first
       `BadDeviceToken`), and no feed row. `on`: everyone, push and feed. The
       key is written whatever the setting, so turning it on later announces
       nothing stale. It goes to `sandbox` after the deploy, and to `on` with
       `CompanionFlag` (step 7).
       A `sandbox` send is strict: a `BadDeviceToken` is skipped, never retried
       on production, corrected or dropped, so a TestFlight build that
       misreports "sandbox" isn't reached through the fallback.
     - `ready`: "Nestie's all grown up!" / "It's the big moment. Come to
       Today." TR "Nestie kocaman oldu!" / "Büyük an geldi, Bugün'e bir uğra."
     - `vote`: "Who's next?" / "Nestie's in the album now. Help pick the
       next one." TR "Sıradaki kim olsun?" / "Nestie albüme girdi. Yenisini
       beraber seçiyoruz, gel oyunu ver."
     - `arrived`: "The new one's here!" / "Come say hi on Today." TR "Yenisi
       geldi!" / "Bugün'e gel, bir merhaba de."
   - *The economy.* No new coin. The welcome is once, stages once per slot,
     the graduation as before. An undecided seed grows but pays no stage
     (its stand-in may be a pet, whose seven stages come earlier); when it is
     chosen, `chooseSeed` pays up to the real species' stage at its points.
   - *Client built (24 October), built and test-built, tests not run.* Payload
     (`CompanionVote`, `Current.undecided`), `ballot` / `decide` / wider
     `graduate` in `CompanionClient`, entries `writes.ballots` and a seed
     pick (`Start.seedID`) in `CompanionFeature`, `CompanionVoteViews.swift`
     (card section, `VoteView` sheet), `ActivityCategory.companion` -> Today,
     server refusals as copy (`CompanionVoteRefusal`). An undecided seed is
     drawn as a sprout (`seedStandIn`), never as its stand-in. The server does
     not say who voted, only counts. Bench: `-nestieScenario vote|voteAlone`,
     `-nestieScript vote|voteSettle|votePick`.
   - *For the client* (spec, now built):
     - `forHome.current.undecided`: draw a seed or an egg, not `species`.
     - `forHome.vote`: the poll, open or closed, the deadline, the options
       with yes and no counts, the caller's answers, `answered` of `members`,
       `othersVoted`, how it ended, the winner.
     - Ballots: `polls:vote` and `polls:unvote` on `vote.pollId`.
     - `companion:decide { homeId }` gives `chosen`, `noVotes`, `alone`
       (nobody else has answered: pick with `start` instead), `closed` or
       `none`.
     - `start` on a seed is the pick. It throws "The house is voting on the
       next one" once someone else has answered, and "The house already chose"
       for a different species once the vote has chosen.
     - `graduate` now also returns `vote`: show the vote, not Choose.
     - `ActivityCategory.companion`, routed to Today.
     - The pick, `decide` and the ballots are optimistic, each with its own
       rollback.
   - *Questions for you* (each with my recommendation):
     - Turkish pushes need the phone's language on the server: an optional
       `language` on `registerDevice`, then per-device copy for every push,
       not only Nestie's. Recommended, as its own small change.
     - Twenty-four hours, or shorter? Recommended: 24 h. Most votes end
       earlier, when everyone has answered.
     - Should a member on an old build, who can't see Nestie, count towards
       "everyone"? Today they do, so that house's vote waits for the deadline
       unless someone settles it. Recommended: keep it. Settling it is one tap.
4. **The jar takes money.** Choose StoreKit 2 or RevenueCat; it replaces
   `SparkleStoreClient.liveValue`. Four consumables in App Store Connect,
   priced from Apple's tiers. `jar:topUp` verifies each transaction on the
   server, once; App Store Server Notifications for refunds (the jar can go
   below zero; nothing bought is taken back). The review notes say Sparkles are
   consumables, shared by the house, with no random boxes.
   - *Client, done (StoreKit 2):* `SparkleStoreKit` behind
     `SparkleStoreClient`; `SparkleSettlement` is the rule (server first, then
     `finish`; `credited`/`already`/`revoked` finish, `invalid` and unknown
     do not). `appAccountToken` is a v5 UUID derived from the user id
     (`SparkleAccount`: SHA-256 of `nestzone.user:<id>`), so the server can
     tie a receipt to a person. `NestZone.storekit` (repo root, outside the
     target) is the Debug run scheme's StoreKit configuration; `-sparkleStore
     test` is the old test store. To do: App Store Connect products, the
     server's environment setting for Xcode/sandbox, an end-to-end purchase
     on a device, then the refunds (server notifications).

   **StoreKit 2, chosen (open question 6). The server side is built (24
   October), typechecked and dry-run, not deployed or committed.** Additive
   only: a new table, three new modules, one HTTP route, one dependency
   (`@apple/app-store-server-library`, the first `"use node"` module on this
   deployment; the dry run shows only "the server's version for Node.js
   actions" changing).
   - *The contract.* `jar:topUp({ homeId, signedTransaction })`, an action;
     `signedTransaction` is `jwsRepresentation`. It answers `{ status,
     sparkles, jar }`: `credited` (now in the jar), `already` (credited
     before: this house hears the same `sparkles`, another house 0), `revoked`
     (Apple took it back; nothing moved now), `invalid` (not ours to credit).
     `invalid` means the data is not Apple's or not ours to credit: offline
     verification fails, Sandbox while it is off, Xcode from a non-test
     account, not a consumable, or bought by another account. The client
     leaves `invalid` unfinished anyway, so the buyer's own phone can still
     send it. A thrown error is not an answer — not a member, or a genuine
     Apple transaction we can't settle yet (online check failed but offline
     passed, `APPLE_APP_ID` unset, a Production product not in the table) —
     and the transaction stays unfinished for the next try. `jar` is the
     balances after, or null.
   - *The buyer.* The app signs `appAccountToken` into every purchase,
     `SparkleAccount.token`: SHA-256 of `nestzone.user:<users._id>`, the first
     16 bytes as a version 5 UUID. `accountToken` in lib/jar.ts is the same
     bytes; `credit` refuses (`invalid`, logged) a token that isn't the
     caller's, and a missing one outside Xcode. Test vector, checked in Swift
     and Node: `jh7abc123def456ghi789jkl0mn1pq2r` ->
     `d04f2213-14a2-506a-8069-fc02089326a9`.
   - *Products.* `com.walhallaa.NestZone.sparkles.300`, `.1000`, `.2200`,
     `.5000`, consumables. The server's table is `CATALOG.sparklePacks` from
     the exported catalog, so it is `SparklePack.shelf` by construction; a
     `quantity` above one multiplies, up to ten.
   - *Verification* (convex/jar.ts): the environment is read off the JWS only
     to choose a verifier, which then refuses it if the claim was false. Apple
     Root CA - G3 is pinned in lib/jar.ts (fingerprint in the comment,
     checked twice against apple.com's certificate). Online first (OCSP); if
     that fails for any reason, offline as of the JWS's signing date, and only
     the offline verdict can make it `invalid`. Then bundle id, `Consumable`,
     a known product. `JAR_ENVIRONMENTS` says what may credit, and always
     includes Production; unknown names are logged. Production without
     `APPLE_APP_ID` throws. `Xcode` is
     unverifiable and so accepted only when listed, and only for the admins
     and `JAR_TEST_USER_IDS`: it mints Sparkles, and is for Debug builds
     running the StoreKit configuration file.
   - *Once* (convex/jarStore.ts). `jar_purchases`, one row per
     (transaction, environment) across the deployment, written in the same
     transaction as the `topUp` ledger row (`topup:<transactionId>`; other
     environments carry their name, `topup:Sandbox:<id>`, because Xcode
     numbers from 0 on every Mac). Never purged with a house.
   - *Refunds.* `POST /appstore/notifications` (http.ts) for V2: `REFUND` and
     `REVOKE` debit what was credited, once (`refund:<transactionId>`), and
     set `revoked_at`; the jar may go below zero and nothing bought is taken
     back. A refund for a transaction we never saw leaves a tombstone, so the
     pre-refund JWS can't be credited afterwards. Anything else — `TEST`,
     `REFUND_DECLINED`, `REFUND_REVERSED`, consumption requests, unknown
     transactions — is a 200 and ignored. Every verified type is logged
     first, `TEST` included. 400 for a payload that isn't Apple's; 500 when a
     retry could work, and for a genuine payload addressed to another app id
     or environment (`INVALID_APP_IDENTIFIER`/`INVALID_ENVIRONMENT`, logged as
     an error): that is our configuration, and a 200 would lose a refund. Sandbox and Production
     notifications are both verified whatever `JAR_ENVIRONMENTS` says, so a
     Sandbox top-up credited while Sandbox was on still comes back out.
   - *The test store.* The phone's `SparkleStoreClient` (while `isTestStore`)
     never calls the server and its Sparkles stay in the Lab, so there was
     nothing to gate: no path mints Sparkles on the server except `Xcode`
     above.
   - *Not done, deliberately.* `REFUND_REVERSED` does not re-credit (rare; a
     second key would be needed so a later refund still debits). A JWS signed
     before a refund whose notification never arrived would still credit;
     closing that needs the App Store Server API's transaction lookup, which
     needs an API key. No push or feed row for a top-up yet.
   - *Your App Store Connect to-do:*
     1. Create four consumables with exactly these product ids:
        `com.walhallaa.NestZone.sparkles.300`, `…sparkles.1000`,
        `…sparkles.2200`, `…sparkles.5000`, priced from the tiers in open
        question 2 (2.99 / 8.99 / 17.99 / 34.99).
     2. Copy the app's Apple ID (App Information -> Apple ID, digits) and
        `npx convex env set APPLE_APP_ID <digits>`.
     3. App Information -> App Store Server Notifications: Version 2, both
        Production and Sandbox URL
        `https://nestzone-convex-api.walhallaa.com/appstore/notifications`.
     4. On the server, add a cloudflared ingress rule like the
        `/.well-known/*` one, `path: /appstore/.*` -> `http://127.0.0.1:3211`,
        above the catch-all for that hostname, and restart the tunnel. Until
        then the URL is 404 (checked 24 October). Then "Request a Test
        Notification" should log a `TEST` and get a 200.
     5. For a TestFlight round, `JAR_ENVIRONMENTS "Production,Sandbox"`, back
        to `Production` after: Sandbox Sparkles are free to anyone with a
        sandbox account, and this is the only deployment. **While a build is
        in App Review, `JAR_ENVIRONMENTS` must include Sandbox, or the
        reviewer's purchase won't deliver; remove it after.** What a round
        credited, newest first, 500 at most a call:
        `npx convex run jarStore:credited '{"environment":"Sandbox"}'`.
   - *What's left for the app:* `SparkleStoreClient.liveValue` on StoreKit 2,
     calling `jar:topUp` with `jwsRepresentation` and finishing on any status;
     `Transaction.updates` and `.unfinished` sent the same way.
5. **The art pass** (its own job): the 32 sketched species — new growth rules
   for the plants, a few body plans for the pets — and the 10 sketched
   decorations; scenes as real backdrops; things to wear drawn on. Measure
   again.
   - *Done (25 October), every species:* the pomegranate and kitten heroes set
     the bar (`Docs/Companion/art/RULES.md`, `RULES-pets.md`); then the trees
     (lemon, olive, magnolia, cherry, azalea), all 19 potted plants (rules
     `stalk`, `bush`, `column`, `vine`, `tuft`, `cane`, `sprig`, `blades`,
     `frond`, `spray`, `sculpt`, `trail`; their own stage names) and all
     pets (`sitter`, `waddler`, `shelled`, `swimmer`, `SpineField`). Each
     went through two critique passes and a fix round from me, and is
     measured in its RULES section: plants at or under ~0.7 ms recording,
     trees within 1.3x the old GPU cost, no pet above the kitten (the dozing
     goldfish, 0.42 ms against 0.35, is the one exception, accepted).
     Before and after sheets: `Docs/Companion/art/{trees,plants,pets}/index.html`.
     A reviewer pass on the integration (caches, concurrency, Reduce Motion,
     Release flags, strings) found nothing blocking.
   - *Done:* the decorations, the three scene backdrops (cached, with the
     sky) and the things to wear, which follow each pet's head and body in
     every mood (`Docs/Companion/art/decor/`, RULES.md §16). The shop draws
     every tile from a cached still (`ShopStill`, `DecorPortrait`; let go on
     a memory warning and in the background), Choose went from 113 to about
     11 late frames, and the card stacks at the accessibility sizes
     (`Docs/Companion/art/shop/`). A full set of decorations used to drop
     a frame every few seconds: the per-frame canvases now render
     asynchronously (CLAUDE.md). A crash is fixed on the way: a tree's
     crown cache was keyed on its seed alone, so a new tree with the old
     seed indexed off the end of the old tree's layout.
   - *Open:* re-measure Today, Choose and the shop on the phone with the
     new art.
6. **The finale**: "You've grown them all", the crown, growing a favourite
   again in a new colour.
   - *Server, built (25 October, not deployed):* the finale is the moment
     every `freeToHave` species is in `grown_species`, the same condition as
     the `grownAll` reward (`grownAllFree` in lib/companion.ts, which the
     reward now asks too). All additive:
     - Schema: `companions.colour` (1–3, absent is the original),
       `companion_homes.grown_colours` (`"<species>:<colour>"`, bounded by
       species × 3) and `companion_homes.finale_at`.
     - `start` takes an optional `colour`. Not an integer 1–3: throws
       "There's no such colour". Otherwise it needs the finale reached, the
       species already grown and that colourway not grown yet
       (`colourOpen`), or throws "That colour can't be grown yet" — `start`
       refuses by throwing, never by a status, and the app matches the
       message as it does "The house already chose". Checked after any
       graduation in the same write, like the species, so the graduation
       that completes the finale can be followed by a colour at once. The
       species must still be growable today, as for any start. Without a
       colour nothing changed: a species already grown can be grown again
       in its original colour, as always. A double tap counts as one only
       with the same colour; after a vote chose, a pick with a colour is
       "The house already chose" (the vote chose the original); picking an
       undecided seed may give it a colour.
     - A graduation adds a coloured one to `grown_colours`. The graduation
       that first completes `freeToHave` (`finale_at` unset, not complete
       before, complete after) stamps `finale_at` with its own
       `graduated_at` and says `finale: true` — on `graduate`'s result and
       on `start`'s `graduated`. Once: the next finds `finale_at` set, and
       `graduate` called again finds the companion graduated. A `start`
       retried with the same `requestId` reports the same graduation again,
       `finale` included (`follows.graduated_at === finale_at`), because the
       first answer may never have arrived; the app keys the ceremony on the
       companion id.
     - A house complete before this shipped has no `finale_at`, and gets
       none: `finaleAt` is null and no ceremony is played, but colours are
       open to it (the rule reads `grown_species`, not `finale_at`). The same
       for a house completed by `importLocal`, which doesn't stamp it.
     - Reads: `forHome.house.finaleAt` (number or null) and
       `.grownColours` (sorted), `forHome.current.colour` and each album
       entry's `colour` (number or null).
     - The vote stays species-only and offers nothing coloured; a seed the
       vote chose grows in the original. Other members' phones learn of the
       finale from `finaleAt` turning non-null, not from a `finale` flag.
7. **Release:**
   - turn `CompanionFlag` on for Release, and in the same release
     `npx convex env set COMPANION_NOTIFY on` (it is `sandbox` until then, so
     only Xcode installs hear Nestie and the feed stays clean);
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
