# Nestie — the household companion

A plant or a pet on Today that the whole house grows by doing what it already
does. It graduates into an album after about two weeks, and is dressed up for
the days the house celebrates. "Nestie" is a working name. It lives in one
string, `L10n.companionBrand`, and the code calls the feature "companion".

**On a new machine, start with [HANDOFF.md](HANDOFF.md).** It records where
things stand, every decision and why, what's next, and what's still open.

## In this folder

| | |
|---|---|
| `plan/index.html` | The full plan: research, design, decisions, roadmap, with live demos. Open it in a browser. |
| `plan/shop.html` | v8's shop prototype (since replaced by the app's own design) and how each of its decisions was answered, with screenshots of what's built. |
| `plan/plant.html` | The procedural plant in a browser: growth, moods, wake-up, clock, decorations, Decorate mode. URL options are listed in the file. |
| `plan/duck.html`, `duck.js`, `duck.css` | The duckling: seven stages, four moods, the wake-up. |
| `art/compare.html` | The two tree directions side by side. |
| `art/gouache/` | The tree in the app, layered gouache: its prototype (`tree.html`), the guide (`SPEC.md`, with what the app does differently in §15) and renders. |
| `art/soft-canopy/` | The direction not taken, soft canopy: prototype, guide, renders and its finished Swift port, kept for reference (not compiled). |
| `art/SHADERS.md`, `art/shaders/` | Wind and painted-finish Metal shaders, tried and removed: they cost Today two thirds of its frames. Kept for reference. |
| `HANDOFF.md` | Where things stand and what's next, every decision and why, as a handoff. Start here. |
| `HOLIDAYS.md` | How every holiday date is worked out, what it was checked against, and where almanacs disagree. |
| `tools/growth_sim.py` | Monte Carlo of growth per household type; the agreed settings are in `growth_results.txt`. |
| `tools/free_tier_sim.py` | Same pace for a house without subscription features. |
| `tools/l10n_tool.py` | Adds strings to `L10n.swift` and `Localizable.xcstrings` together, from a JSON spec. |
| `tools/scenario.sh` | Puts the companion in a given state on the simulator and takes screenshots. |

## In the app

`NestZone/Features/Companion/`:

| File | What it does |
|---|---|
| `CompanionFeature.swift` | The reducer: growth, care, the jar, choosing, graduation, decorating, holidays, the lab. `CompanionFlag` keeps it to Debug builds. |
| `CompanionModels.swift` | Species, growth maths and moods, the house file (`CompanionHouse`), decorations and spots. |
| `CompanionCatalog.swift` | How every species and decoration is had (`Access`), where each stands for a house today, and paying: the checkout and making up Leaves with Sparkles. |
| `SparkleStore.swift` | The Sparkles store client: a test store for now, StoreKit or RevenueCat later. |
| `ShopDesign.swift` | What the companion adds to the shop's look: the stage that follows the hour (`ShopStage`), the window each thing stands in (`StageWell`), price tags and badges. |
| `CompanionShop.swift` | The shop (three shelves as pages), the purchase card snapped to the bottom edge with its coin flight, and the full-screen Sparkles store. |
| `Holidays.swift` | 49 holidays, their rules, the defaults per country, and the hemisphere. |
| `CompanionScene.swift` | The live scene in three layers — behind, the tree, in front — with eased mood and growth, wake-up, drops, hearts and stage pops. The tree is drawn only when it changes. |
| `CanopyPainter.swift` | The tree, grown from a seed: layered gouache, ported call for call from `art/gouache/tree.html`. |
| `PetPainter.swift` | The duckling. |
| `ScenePainter.swift` | Sky and clock, pot and soil, the decorations (sketched as emoji where not drawn yet), what it wears, weather, fireflies, the thirst bubble, the dome. |
| `SceneInk.swift` | Seeded randomness, easing and colour helpers shared by the painters. |
| `CompanionCard.swift` | The card on Today, its one-line busy-day form, and the invitation. |
| `CompanionSheets.swift` | The sheet container, Choose, Decorate, Album, Our holidays, Lab, and the ceremony. |
| `CompanionNames.swift` | Every user-visible name, through `L10n`. |

It's wired in through `MainFeature`, which owns `companion` and passes it the
household's finished chores from Today's subscription. `HomeView` draws whatever
`AppView` hands it into its companion slot. `HouseTask` decodes `completed_at`.
Money is drawn by `Amount` and `JarAmounts` (`Design/Components/Amount.swift`), and the one button that spends is `.depth` (`Design/Components/Buttons.swift`).
State is saved per home in `Documents/companion-<homeID>.json`
(`SharedKey.companion`). Tests are in `NestZoneTests/CompanionTests.swift`.

## Trying it

1. Run a Debug build from Xcode (phone or simulator). Nestie is at the top of Today.
2. **Lab** on the card: grow it, set a mood, pretend it's any holiday, add Leaves, start over.
   Under the tree, **− / +** takes points off and adds them four at a time, to watch it shrink and
   grow through its stages (development builds only).
3. For screenshots without tapping, use `tools/scenario.sh`. Or launch with
   `-companionDemo care|decorate|celebrate|dress|album|holidays|lab|choose|pick`
   (and `-companionSpot left`, for Decorate), or
   `buy|makeup|short|topup|pay|info|shop|store` for the shop, the purchase card
   and the Sparkles store (and `-companionShelf plants|pets` for the shop's
   shelf, `-sparkleOutcome ask|fail` for a pack that waits or fails).
   The app takes about ten seconds to reach Today.
4. For smoothness, launch with `-frameMeter 1` and read the late frames from
   the log (`log stream --predicate 'category == "Frames"'`).
   `-todayScroll 1` and `-companionScroll 1` make Today or Choose scroll by
   themselves, for a simulator nobody can touch. `-openTab lists` (or plans,
   house, messages) opens on that tab, and `-segmentCycle 1` walks its
   segments every 1.5 s, to measure a segment switch.
