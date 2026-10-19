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
| `plan/plant.html` | The procedural plant in a browser: growth, moods, wake-up, clock, decorations, Decorate mode. URL options are listed in the file. |
| `plan/duck.html`, `duck.js`, `duck.css` | The duckling: seven stages, four moods, the wake-up. |
| `HANDOFF.md` | The session that produced this, as a handoff. |
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
| `Holidays.swift` | 49 holidays, their rules, the defaults per country, and the hemisphere. |
| `CompanionScene.swift` | The live scene: timeline, eased mood and growth, wake-up, drops, hearts, stage pops. |
| `PlantPainter.swift` | The procedural tree, grown from a seed. |
| `PetPainter.swift` | The duckling. |
| `ScenePainter.swift` | Sky and clock, pot and soil, 40 decorations, weather, fireflies, the thirst bubble, the dome. |
| `SceneInk.swift` | Seeded randomness, easing and colour helpers shared by the painters. |
| `CompanionCard.swift` | The card on Today, its one-line busy-day form, and the invitation. |
| `CompanionSheets.swift` | Choose, Decorate, Album, Our holidays, Lab, and the ceremony. |
| `CompanionNames.swift` | Every user-visible name, through `L10n`. |

It's wired in through `MainFeature`, which owns `companion` and passes it the
household's finished chores from Today's subscription. `HomeView` draws whatever
`AppView` hands it into its companion slot. `HouseTask` decodes `completed_at`.
State is saved per home in `Documents/companion-<homeID>.json`
(`SharedKey.companion`). Tests are in `NestZoneTests/CompanionTests.swift`.

## Trying it

1. Run a Debug build from Xcode (phone or simulator). Nestie is at the top of Today.
2. **Lab** on the card: grow it, set a mood, pretend it's any holiday, add Leaves, start over.
3. For screenshots without tapping, use `tools/scenario.sh`. Or launch with
   `-companionDemo care|decorate|celebrate|dress|album|holidays|lab|choose`
   (and `-companionSpot left`, for Decorate).
