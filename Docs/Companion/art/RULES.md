# Illustration rules, from the pomegranate

The pomegranate (`PomegranatePainter*.swift`) is the hero: the rules below are
what it does, written so the lemon, the olive, the sunflower or a pet can do the
same. Contact sheets: `-artSheet pomegranate`, `pomegranate-night`,
`pomegranate-close`; the shots are in `art/hero/`. Everything is `Canvas`, no
shaders, no images.

## 1. Light

- **One light, from the sky.** The painter is told where the sun (or at night
  the moon) stands across the scene, -1 to 1 (`TreeState.light`,
  `SceneFrame.skySide(hour)`, the same number that places the sun). It becomes
  one unit vector `L`, never exactly overhead (at least a quarter of the way
  to a side, and higher by day than at dusk). Every highlight, shadow, lit
  half, rim and bounce comes from `L`. The pot's rim highlight follows the same
  side.
- A tree is lit from one side; the other side is the *shadow side* and gets its
  colour from a deeper ramp step, never from black.
- **Rim light** is a thin sliver of the light colour on the lit edge of the
  front and back tiers. Its colour is a warm white at noon, amber when the sun
  is low (dusk is `4 * day * (1 - day)`), cool blue-white by the moon. Rim alpha
  goes up at dusk and at night, down when dozing.
- **Bounce light**: a faint warm arc on the shadow side of round things
  (fruit), never more than ~30% alpha.
- **Night is cool, not grey.** Reds and greens drop more than blue
  (`RGB.night`); the lit side by moonlight is a *deeper* green with a pale rim,
  not a paler green. Test a night shot for "ghostly teal": if the lit patch is
  lighter than the day shadow side, it is wrong.

## 2. Palette ramps

Count the tones, and keep to the count.

| Material | Tones | How |
|---|---|---|
| Leaves | 5-step ramp per species (`Kind.ramp`), used as 3 classes per tier: deep, middle, sunlit; plus a lit-half tone and a rim tone | tier n uses ramp n, n+1, n+1~n+2 |
| New growth | the same classes mixed 40% towards a bronze | `fresh`: tips and clumps younger than .05 of growth |
| Fruit | 3 (highlight, body, shade) per skin; 3 skins (deep red, rose, yellow blush) + the unripe green-blush | ripeness mixes green, blush, then the skin |
| Flowers | 3 (deep, body, tip) + a gold for stamens | back petals deepest, front brightest |
| Wood | 3 (dark, base, light) + the leaves' shade over it | core shadow, lit edge, bark strokes in dark / light |

Colour is worked out in `init` of the look, never in a loop body. Mood moves are
RGB mixes towards a *dry* (olive) or *dozy* (straw) ramp so a leaf passes
through olive, not an odd hue.

## 3. Edges and highlights

- **No outlines.** An edge is a light sliver or a tonal break.
- Leaves: the half facing the light is a lighter tone (front tier only; the
  middle tier has none, which is what makes the front read as forward). The
  light edge is the whole class path, drawn once more shifted a hair towards `L`
  in the rim colour *before* the real fill: one fill, a rim on every leaf.
- Gloss: a short bright streak on the lit side of the midrib on about one leaf
  in seven, front tier only.
- Round things (fruit): one radial gradient from the highlight point
  (`centre + L * 0.4r`), highlight = a soft streak plus a bright dot, both at
  `L`. A crown, collar or twig is always darker than the body it sits on.
- Waxy things (calyx, fruit) carry a thin light streak; matt things (petals,
  bark) do not.

## 4. Detail density

- **Card size (the big scene) is what is designed.** The grown pomegranate has
  ~25 clumps showing; each is 3-5 sprigs of 2-3 leaf pairs + a tip leaf, ~25-45
  leaves, in 3 classes, so ~700-900 leaves, in about 130 fills.
- **Portrait size** (a shop cell, ~110 pt) must read as the same plant from the
  same code: silhouette (lance leaves, dome with a few shoots standing out),
  the red of the fruit, the orange of the flowers, the trunk's fork. Do not
  draw a second, simpler version; the same painter just has less room.
- **Close-up size** (what a person sees if they look): crowns on fruit,
  crinkles on petals, the filaments, bark strokes, the arils. These are
  *reward* details. They are allowed to be invisible at portrait size.
- Mass first: a dark body behind each clump supplies the depth between leaves
  (smaller and lighter when the tree is sparse, or it shows as a balloon), a
  long young shoot now and then breaks the dome.

## 5. Stage design

Every stage gets its own reason to look at it:

| Stage (growth) | What is new |
|---|---|
| seed (.04) | a *ruby* seed on the soil (the species' own seed, not a generic husk) |
| sprout (.16) | two narrow bronze seed leaves |
| young (.38) | a slender whip of 3 stems, tip whorls of bronze leaves |
| growing (.62) | the stems fork; the first buds, small and pointed |
| budding (.8) | most flowers open; the first fruit set |
| grown (.97) | fruit in 3 colours at 3 ripenesses, one split open; a third of the flowers stay; the fallen petal and aril on the soil |

Things grow *in*, never pop: size follows `Ink.back` over a window of about .04-.1.
Births are windows inside the shared growth timeline; never move the skeleton's
(`Canopy.Grower` draws are the household's tree and must stay in order).

## 6. Mood

Mood does three things, and only these, so it is cheap and consistent:
posture (leaves and fruit sag: `pull`, `wilt`), tone (the dry / dozy ramps,
fruit saturation) and quantity (leaves dropped and curled short, buds instead
of open flowers, fallen things on the soil).

- **Thirsty:** olive, curled short leaves, a few dropped, flowers stay buds,
  fruit smaller and duller, one fruit on the soil, more leaves on the soil.
- **Dozing:** calm: straw, less contrast, a gentle droop, edges softer. No
  extra drama.
- **Bright:** richer, a soft glow; never a new effect.
- Never turn a quiet tree into confetti: leaves thin out, clumps do not break up.

## 7. Story-detail budget

At most **four** small things, each rewarding a close look and none competing
with the plant: the species' own seed, a fallen leaf (always from `.45`), a
fallen petal while it flowers, one loose aril from the split fruit (and the
pinpoint of sky on the pot rim, drawn for every species). Mood-only extras
(the dropped fruit) replace, not add to, the budget. If a detail is visible only
by labelling it, it is too small; if it can be named from a portrait cell, it is
too loud.

## 8. Performance budget

The tree layer is drawn only when its state changes, so the budget is what a
*redraw* costs while a mood or a stage eases in, measured with
`-artSheet redraw -frameMeter 1` (four grown trees redrawn every frame; add
`-artSheetCount 1` for one, `-artSheetSpecies <name>`, `-pomegranateLegacy 1`
for the old painter) and `log stream --predicate 'category == "Frames"'` for
`tree draw` (the recording cost, Debug only).

- **Ops, not area, cost time.** Batch every shared thing into **one path per
  colour per clump or tier** and fill once. Per-leaf or per-flower fills are
  the mistake (the first draft's per-object fills ran at 13 fps for four trees;
  batching and shifting a copy for the rim gave ~30; the old painter is ~50).
- Prefer a fill to a stroke; prefer one shifted copy of a path to a shape per
  leaf for light; a gradient only on the front tier's leaves and on round
  fruit. No clips in loops (one clip for the wood's shade is fine). No
  `Color` / gradient construction in a loop.
- Target: one tree <= 2x the old painter's redraw on the simulator, and no
  change in the late frames of `-todayScroll 1` / `-companionScroll 1`
  (pomegranate: 15-22 dropped in 30 s against 15-16 before, identical worst
  frame; the one-time first draw is the 250 ms hitch both show).
- If detail costs too much, make the same picture cheaper (fewer fills, a
  shifted copy, a batch); do not strip it.
