# Handoff: Nestie, the household companion

Written at the end of the working session of 19–20 October 2026 so the work can
continue on another machine. The full plan is `plan/index.html`. This file is
the short version, plus everything a new session needs to keep going without
the old conversation.

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
- **One house jar** (Kumbara), one currency (Leaves). It's filled by growing and,
  later, by anyone's top-ups (consumable in-app purchases); everyone spends from
  it; the feed shows who added and spent. This replaced v3's per-person Sparkles
  and moving boxes.
- **The finale** counts only what can be had without paying, so buying never
  delays it.
- **Decorating:** eight spots, Decorate mode, preview before buying. Holiday
  things are free while the day lasts, go back in the box afterwards, and return
  next year.
- **Holidays:** 49 days from 11 traditions, chosen per house, with suggestions
  per country. Religious days get free things only, never sold. Solemn days
  aren't dressed up.
- **The companion stays free** alongside the planned subscriptions, at the same
  pace for free houses.

## Still open (your call)

1. **What leaves with a person under the jar?** Recommended: nothing — the jar
   and what it bought stay with the house.
2. **Top-up prices.** Suggested: four packs, around 300 / 1,000 / 2,200 / 5,000
   Leaves, on Apple's price tiers, with Turkish prices from local tiers.
3. **Free spots or free placement** for decorating. Recommended: spots, as built.
4. **Subscriber perks.** Suggested: 300 Leaves a month into the jar, plus one
   exclusive seasonal thing.
5. **Deleting a house with Leaves in the jar.** The warning should state the
   balance.

## What's built

An MVP in the app, **Debug builds only** (`CompanionFlag`). Release, TestFlight
and App Store builds compile it but never show it. It's described in README.md.

**Growth** is read from `HouseTask.completedAt`, which the server already sends
for the Done list. So every phone sees the same growth from chores, with no
backend change.

**Everything else is on the device**, per home: the companion, care, the album,
the jar, the scene and the chosen holidays, in
`Documents/companion-<homeID>.json`. Two phones in the same house won't share
those until the server version.

**Verified:**
- Debug build, Release build (arm64), test target compiles.
- In the simulator, on a real household:
  - the card, the thirsty and dozing wake-ups, the duckling;
  - Halloween, New Year and Diwali scenes;
  - Decorate, Our holidays, Choose, Album, the ceremony.

Per the working agreement, the tests were not run (build and typecheck only).

## Next steps

1. **The server version** — backend first, additive only:
   - Tables: `companions`, `companion_growth` (a ledger keyed per credited
     thing), `companion_scene`, house jar plus `jar_ledger`, `owned_items`,
     holidays per house.
   - Growth hooks in the existing writes: `tasks:update`,
     `shopping:setPurchased`, `meals:set`, `issues:setStatus`, `polls:vote`,
     plus an hourly sweep for events that ended. Each schedules a
     `companion:reconcile`.
   - One live read, `companion:forHome`.
   - The app swaps `@Shared(.companion)` for a client with a live
     subscription; the feature's state shape stays.
   - Remember: one deployment serves every app version. Add, never remove.
2. **The vote for the next one** (a `generic` poll; a new poll kind would decode
   as `.movie` on old builds), and at most three notifications.
3. **Jar top-ups:** StoreKit 2 consumables, verified on the server
   (`jar:topUp`), plus App Store server notifications for refunds.
4. **More to grow:**
   - pets from a few body plans (round, four-legged, bird, fish);
   - plants with new growth rules (a stalk and a head for the sunflower, pads
     for the cactus, a rosette for basil).
5. **Release:**
   - turn `CompanionFlag` on for Release;
   - add a changelog entry for the version (a feature-tier entry, written for
     the household);
   - bump `MARKETING_VERSION`.

## Things learned the hard way

- **Read SwiftUI state in `body`, not only in a `Canvas` closure.** The scene
  first drew without its tree about half the time. The tree is built `onAppear`,
  but `body` never read it, so SwiftUI didn't know to hand the timeline a fresh
  closure. `CompanionScene` now builds a `Snapshot` of all animated state in
  `body` and draws from that.
- **The simulator is headless here.** No window to click. Drive states with
  `tools/scenario.sh` (writes the companion file and passes `-companionDemo`),
  and remember to reinstall the build before running it.
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
- Commit only when asked.

The raw session transcript stays on the original Mac, under
`~/.claude/projects/`. It isn't committed: it's large, full of tool output, and
holds household data. This file is the portable version.
