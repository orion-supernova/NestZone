# Illustration rules, from the pomegranate

The pomegranate (`PomegranatePainter*.swift`) is the hero: the rules below are
what it does, written so the lemon, the olive, the sunflower or a pet can do the
same. Contact sheets: `-artSheet pomegranate`, `pomegranate-night`,
`pomegranate-close`, and from round 2 `pomegranate-crown` (the grown tree large,
by day, dusk, night, morning and in two moods), `pomegranate-young` (the stages
between a sprout and a crown, enlarged), `pomegranate-fruit` (the nested fruit
and the cutaway, close) and `pomegranate-shop` (the size of a shop cell); the
shots are in `art/hero/` (`pomegranate-before-*`, `-v1-*`, `-v2-*`).
Everything is `Canvas`, no shaders, no images.

Round 2 is sections 9-12 below (canopy light, fruit in the foliage, the cutaway,
and what made it cheap); sections 1-8 are still true where they do not say
otherwise.

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
- Leaves: the light is sorted into classes (section 9), not painted as a lit
  half on every leaf. The light on a sunstruck leaf's edge is a thin lens of the
  rim colour along its lit side, merged with the midribs and glints into one fill
  per clump (v1 filled the whole class path once more, shifted a hair, before the
  real fill; that doubled the fills and was dropped).
- Gloss: a short bright lens on the lit side of the midrib on about one
  sunstruck leaf in three.
- Round things (fruit): one radial gradient from the highlight point
  (`centre + L * 0.4r`), highlight = a soft streak plus a bright dot, both at
  `L`. A crown, collar or twig is always darker than the body it sits on.
- Waxy things (calyx, fruit) carry a thin light streak; matt things (petals,
  bark) do not.

## 4. Detail density

- **Card size (the big scene) is what is designed.** The grown pomegranate has
  ~28 clumps (about half of them the young tips' whorls, which are gone by
  grown); each is 2-5 sprigs of 2 leaf pairs + a tip leaf, so ~500 leaves,
  sorted into 4 classes by the light and drawn in about 220 fills with the
  fruit.
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
| young (.30-.5) | a slender vase of three canes, opened out with height, leaves in spaced pairs with the cane showing between and a fresh yellow-green tuft at each tip: a little tree, not a column |
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

- **Fills, not area, cost time.** Batch every shared thing into **one path per
  colour per clump or tier** and fill once. Per-leaf or per-flower fills are
  the mistake (the first draft's per-object fills ran at 13 fps for four trees;
  the old painter is ~50). Section 12 has the measurements.
- Prefer a fill to a stroke (a thin lens is a fill); a gradient only on the
  front tier's middle leaves and on round fruit. No clips in loops (one clip
  for the wood's shade is fine). No `Color` / gradient construction in a loop.
- Target: one tree <= ~1.3x the old painter's redraw on the simulator, and no
  change in the late frames of `-todayScroll 1` / `-companionScroll 1`. Round 2
  measured (section 12): recording 1.05x and frame time 1.19x of the old
  painter, against 2.15x and 1.55x for v1.
- If detail costs too much, make the same picture cheaper (fewer fills, a
  merged path, a lens for a stroke); do not strip it.


## 9. Canopy light (round 2)

v1 sorted a leaf into three classes by one number, how far it sat towards the
light inside its own clump, so every clump lit its sunny side the same way and
the crown came out as one pale blob in the middle. A crown is lit as a whole.

- **Four classes, by one brightness per leaf**: the shade (`d`), the middle
  (`m`), the lit (`l`) and the sunstruck (`s`, drawn only in the front tier;
  behind it the lit class holds both). Each class is one fill per clump, shade
  first.
- **The brightness is the sum of** the leaf's place on its own clump towards
  `L` (and how squarely it points at the light), *where the clump stands in the
  whole crown* (towards `L`, high or low, from the *grown* tree's positions so
  a leaf's light does not change while the tree grows), a penalty for the
  underside and for the clump's own core, **dapples** (five to seven soft
  gaussian patches in the crown, on the light's side and spread a little to
  either side) and a share of **luck per sprig** (so a whole sprig is lit or in
  shade, which is what makes patches and not speckle) and per leaf. Then a tier
  bias: the back is a step down.
- **Where it is darkest**: under each front clump (a soft shadow poured on what
  is behind, only for clumps with something behind them, see below), the
  interior of every clump, the lower crown, and the back tier. Not the outer
  edge: a flat black rim looks like a cut-out.
- **Keep the classes' tones apart**, ramp steps `n+1/2 .. n+3/4` from the back
  tier to the front; the shade leans cool (a little of a deep teal in it) and
  the sunstruck leans warm (the light's colour mixed in). By moonlight the
  lit classes are pulled most of the way back to the middle class and the shade
  is lifted a third of the way too, so a night tree is one low-contrast mass
  with a faint pale rim, not a ghost: do not make the rim brighter to rescue
  it.
- **Break the fan.** A sprig is a fan of leaves; a crown is not. Give every
  leaf an angle of its own (+-0.25 rad), widen the length range (0.78-1.2) and
  the sprig's lean, or the lit area reads as wheat.
- **Midribs and glints** on the sunstruck leaves are the detail that rewards a
  look: a pale lens down the middle, a short lens on the lit side of some. A
  gradient across the middle class (front tier only) is the only gradient in
  the leaves.
- A soft pool of light (a radial gradient, 0.65 of a clump) over the two
  sunniest upper front clumps, only once the crown is grown, helps the lit
  leaves read as one patch. It is weak on purpose (alpha ~0.1): it was a muddy
  haze at 0.2, and spilled onto the sky from a young crown.
- **No shadow on the sky.** A shadow poured behind a clump that has no leaves
  or wood behind it draws as a grey smudge on the background. Only clumps in
  the upper middle of the crown cast one (`ClumpArt.casts`).

## 10. Fruit in the foliage (round 2)

v1 hung each fruit on a thin hook below its clump, so it looked stuck on.

- **A fruit lives in a clump**, a little out from its middle and low in it, so
  its bottom shows under the sprigs and its top is under them. It is drawn
  *between* the clump's leaf classes: ordinary fruit after the middle leaves,
  about a third (`index % 3 == 1`) *deep* (smaller, higher, drawn after the
  shade only, so the middle leaves cover it too), and the lit leaves after
  them. A later clump of the same tier covers it further.
- **A short sturdy stalk**, 0.3 of the fruit's width, from the shoulder up into
  the leaves: a filled quad, not a stroke, and no highlight on it. A long
  curved stalk reads as a hook.
- **Leaves over it, never the same twice**: one to three lance leaves across
  its shoulders or its top, in one of four patterns picked by the fruit's
  index, the deep ones with a fourth across their side. Two leaves that cross
  over the middle read as a bow-tie: send them past each other.
- **Size and angle vary** (a quarter either way, the lean from the fruit's own
  tilt plus the side it hangs on and a thirsty tree's droop), and the calyx
  points down the lean.
- **The hero fruit is the exception.** The one that is cut open is drawn after
  every front clump, with no cover leaves, because a leaf across the cut hides
  the one thing a person looks at. It keeps a stub of a stalk.
- Bounce light, a soft shadow of the leaves across the shoulders and a stroke
  on the stalk each cost a fill per fruit and were taken out; the calyx is one
  fill, the glints one, the body one gradient.

## 11. The cutaway (round 2)

A donut is a ring with a ring inside it. A cut fruit is a torn skin, a thick
pale rind, a dark inside divided by white walls, and seeds.

- **A torn rind edge**: about twenty points round an ellipse whose radius
  wobbles (two sines) and is pulled out to a point at both ends of the split,
  joined by straight lines. The lip is that shape at 1.13 in a darker skin tone,
  the rind band at 0.97 in a warm pale pink (a little of the skin mixed in; cream
  looked like paper), the inside a *different* shape (a smoothed, wobbling blob
  at 0.76) so the rind is thicker in some places than others and a touch off
  centre. A wide dark stroke along the inside's edge is the rind's overhang.
- **Pale membrane walls** from the core outwards, four of them, bowed, in the
  rind's colour; they must stay visible, so the arils keep clear of them (a
  margin of about 14% of each chamber's width) and stop short of the rind.
- **Arils packed in rings per chamber** (1, 2 and 3 per chamber, so ~24), each
  long towards the middle, in two jewel tones (one fill each, a gradient along
  `L`), a thin dark outline for the whole lot (one stroke), a glint on every
  one (one fill) and a streak on a third of them. They are ~0.11 of the fruit
  across: bigger and they fill the cut and hide the walls.
- **Glisten without overdoing it**: one soft white sheen over the lit side of
  the packed arils (alpha ~0.2), a drop of juice on the lowest point of the
  lip, and one aril that has rolled out; no more.
- At night the jewels are mixed toward a deep wine, not darkened to black.

## 12. What made the redraw cheap (round 2)

v1 recorded in 1.46 ms against the old painter's 0.68 and held the stress page
(`-artSheet redraw`, four grown trees redrawn every frame) at 32 of the old
painter's 50. Round 2, which draws more, records in 0.72 ms and holds 42.
What worked, in the order of what it bought:

1. **Measure the right thing.** The simulator's cost here is not the main
   thread's recording but the GPU: the main thread sits in
   `-[_MTLCommandBuffer waitUntilScheduled]`. `-artSheet gpu -gpuTest N` draws
   four canvases of 700 leaves every frame laid out different ways: a fill per
   leaf is 22 frames, 28 fills of ~25 leaves each is 120, one fill is 120, 112
   fills is 107. **The unit is the fill (and the stroke), not the leaf, the
   curve or the area.** A leaf drawn as two quads, two cubics, a hexagon or a
   kite cost the same.
2. **One path per class per clump, in the clump's own units, kept** (`LeafArt`,
   `ClumpArt`, in `+Art.swift`). A leaf's class depends on the seed, the light
   (in tenths of the sky's side and quarters of the day) and the mood (in 40
   steps), and not on growth, so while a tree grows a redraw is a translate, a
   scale and a fill per class: no leaves built, no trig. A first build of all
   28 clumps is ~1 ms (Debug) and happens once per light and mood; the cache holds
   eight entries behind a `Mutex`. Colour is still worked out per redraw
   (`Look.init`).
3. **Strokes cost most, as fills**: the leaf-edge light, the twigs, the stalks,
   the midribs and glints are all thin filled shapes (a lens, a quad); taking the
   edge strokes and the twig strokes out of the clump loop was worth 4 frames each
   of 38. A round-capped stroke on thousands of tiny segments is the worst case.
4. **Merge what shares a colour**: the dark body and the twigs are one fill; the
   edge light, the midribs and the glints are one fill; at the back the lit and
   the sunstruck are one. A clump is at most seven fills (shadow, body, shade,
   middle, lit, sunstruck, edge light), a back clump five.
5. **Drop what nobody sees**: the lit half of every sunstruck leaf (a second
   shape per leaf), the bounce arc and the leaf-shade gradient on each fruit,
   a second stroke on the stalk, a shadow with sky behind it.
6. **Fewer, bigger leaves**: 720 to ~500, each a fifth longer, hides nothing
   and cost less than any of the above.

How to measure it, so it can be trusted (a good part of this round was
spent measuring a stale binary):
- **Install after every build** (`simctl install` the product) and name the
  simulator by UDID: with another device booted, `booted` is ambiguous and a
  build that is not installed is measured as the old one.
- The machine is noisy (a second agent, Xcode): run the new and the old
  **alternately**, three or four rounds each, and compare the means; a single
  run can be 30% off. `-artSheet redraw -artSheetCount 4 -frameMeter 1`, `frames`
  per two-second window; `tree draw` for the recording.
- `ImageRenderer` does not rasterise like the screen: 80 renders took 140 ms.
  Do not use it as a proxy.
- Numbers, iPhone 17 simulator (iOS 27), Debug, alternating runs:

| | recording | stress page, frames per window | Today flick | Choose flick (dropped in 30 s) |
|---|---|---|---|---|
| old painter (`-pomegranateLegacy 1`) | 0.68 ms | 50 | 0-1 late | 27-30 |
| v1 | 1.46 ms (2.15x) | 32 (1.55x) | 1-5 dropped | 31-33 |
| v2 | 0.72 ms (1.05x) | 42 (1.19x) | 1-2 dropped | 22-34 |
