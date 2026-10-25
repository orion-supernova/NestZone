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
otherwise. Round 3 is section 14: the other five trees (lemon, olive, magnolia,
cherry, azalea) brought to the same level on one shared engine, with the
before and after in `art/trees/index.html` and the pages `-artSheet <tree>-crown`,
`-detail`, `-young`, `-night` and `-shop`.

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
  lighter than the day shadow side, it is wrong. Round 3 went further (section
  14): by moonlight every leaf class is drawn towards one deep blue and pulled
  close to the others, and the rim is a steel blue at low alpha. The pomegranate's
  night crown had been a pale grey-green; it is now a dim blue mass.

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


## 13. Plants (round A)

The potted plants (`PlantPainter*.swift`, `PlantArt.swift`, shots in
`art/plants/`, `<plant>-before-*` and `-v1-*`, index in `art/plants/index.html`)
follow sections 1-8 and 12 with the plant-sized differences below. Contact
sheets: `-artSheet <species>` (stages by day and dusk, the four moods),
`-artSheet plant-<species>` (the card: day, dusk, night, thirsty, dozing) and
`-artSheet plant-<species>-close` (bloom, foliage, thirsty, foot), and
`-artSheet plants-grid` (all eight at the shop's size).

**The toolkit, so a ninth plant is a row and a rule, not a painter.**

- **One light.** `PlantPainter.L` is the sky's vector (`LeafArt.sun`, as the
  pomegranate's); `rimTone` / `glow` are warm white, amber at dusk, cool by the
  moon. `PlantLayer` now compares `light`, so the plant is drawn again when the
  sun moves a tenth. Dozing is calm: `wilt` is only 55% of a thirsty plant's, so
  a dozing plant sags a little and keeps its colour low and its blooms shut.
- **Leaves and petals are cached unit shapes** (`LeafShape`, 13 kinds, each
  at steps of 0.15 of bend, built once behind a `Mutex`): outline, the two
  halves either side of the rib, the veins as thin triangles, a rim strip per
  edge and a glint, all fills, all wound the same way so that a merged path never
  has a hole where two overlap (a monstera is the exception, filled even-odd and
  one leaf to a fill). A leaf in a plant is `addPath(shape, transform:)`.
- **`LeafBatch` merges a tier**: three greens by how the leaf faces the light
  (`PlantPainter.bright`, with luck per leaf), the half of each leaf that faces
  the light as one lighter fill, the veins, the edge light, the glints and one
  quiet shadow: at most nine fills a tier however many leaves. The shadow is a
  deep green at 17% and offset a hair: a grey one was a cut-out on the sky.
- **Blooms are rings** (`PlantPainter.Ring`, `rosette`): each ring of petals is
  one radial gradient fill, with the lit and shaded halves, the rim strip and
  the veins merged across the ring where the ring is big enough to show them.
  A ring comes in at its own point of the way open (`appears`), so a bud
  swells, a cup opens and the outer petals unfold last, and a half-open
  (thirsty or dozing) house shows a cup, not a ruin.
- **Spines, hairs, thorns and stamens are filled triangles** (`Path.spike`),
  and the cactus's fans of spines, the sunflower's seed spiral and the moss
  are cached unit paths (`SpineArt`, `DiscArt`, `MossArt`).
- **The seed is the species' own** (`PlantPlan.SeedLook`): a striped husk, a
  few black seeds, a bulb, a tuber, a rosehip, a cutting.

**Rules and what each plant does on them.** New rules only where the existing
four could not say it: `tuft` (a rosette and several flower stems that open
in turn) and `cane` (woody canes with compound leaves and a bloom at each tip).

| Plant | Rule | What is new | Growth |
|---|---|---|---|
| Sunflower | `stalk` | A spiral of 150 seeds and two rings of tiny florets, two rings of 21 ray petals (length, width, curl all different), bracts, a furry stem (lit hairs pale, shaded ones dark), big veined heart leaves, a bee when bright by day, a petal on the soil | seed to .1; seed leaves; a leaf at every hand's width (.15 to .72); bud .6; petals .82; head opens .84 to .98 |
| Basil | `bush` | Five fuller leaf pairs and two branches, cupped glossy ovals with veins and a glint, a tall white spike of two-lipped florets in green cups that replaces the young tuft | pairs from .12 every tenth; branches .4 and .5; spike .88 |
| Monstera | `vine` | Fenestrated leaves cut by age (heart, slit, slit and holed), a moss pole put in at .3 and tied with twine, aerial roots out of three nodes, three stems as before | leaves .12 to .8; pole .3; roots .34 to .54 |
| Cactus | `column` | Ribs tiled as bands lit by their angle to the sun, valleys and crests, a fan of spines on an areole at every crest, a waxy flower | arms .5 and .72; pups .7 and .8; bud .7; flower .86 |
| Daisy | `tuft` | A rosette of nine spoon leaves, three stems (tall, middle, short) opening at .74, .84 and .92; two rings of rays blushing at the tip around a golden floret disc | rosette from .1; stems from .26 |
| Tulip | `tuft` | Four clasping strap leaves, three stems: open, half open and a bud; a waxy cup of six tepals flamed with yellow, dark heart and stamens when open | stems from .28; opens .78 and .9; the third stays a bud |
| Rose | `cane` | Two arching canes and a short third, thorns, compound leaves of five serrated leaflets (bronze while new), a rose, a cup and a bud; four rings of satin petals, a rolled light edge, a wound heart | cane .1 to .55; second .3; third .5; roses open .7 and .8 |
| Peony | `tuft` | Four low leaves and stems with one cut glossy leaf each, three blooms: ruffled in four rings with a crown of gold stamens, a half-open one, a green bud with a pink slit | stems from .3; opens .8 and .93; the third stays a bud |

**Mood.** Thirsty: leaves hang and curl, stems lean out and sag, heads nod,
blooms stay half shut, petals on the soil. Dozing: the same posture at 55%,
blooms shut (a daisy folds, a tulip is a nodding cup, a rose is a bud), tones low.

**What the two critique passes threw out** (screenshot, reject, fix): the first
pass rejected flat whole-leaf tones (luck swing cut by a third), a grey drop
shadow on the sky, a monstera whose pole read as a second stem and whose slits
were saw-teeth (narrower, forward-swept slits, a lighter pole, thicker roots), a
cactus flower like a lotus with a heavy green wrap (an upright cup, small
sepals), spines that sparkled (smaller, no pure white), a basil spike that was a
dark olive cup with a few dots (a spike twice as tall in lighter green, the
tuft gives way), blooms too small to read (daisy x1.45, tulip x1.55, peony
x1.4, rose x1.5), a peony that was a cabbage (fewer, flatter leaves, deeper
cuts) and dozing plants that drooped as thirsty ones. The second pass threw out
faceted, origami petals on the rose (finer steps, a smooth petal), a pinwheel
of peony stamens (a burst), a rose that showed only sepals when thirsty
(shut until it is really opening, sepals only once it spreads), and slits that
ran at right angles to the rib (they run along the veins).

**Numbers** (iPhone 17 simulator, Debug, `-artSheet redraw -artSheetCount 4
-frameMeter 1`, `tree draw` is the recording; the machine was shared, the
baseline of the four old painters was read before any change and the new ones
three times, not alternating, so the spread is the noise).

| | recording before | recording now | stress frames per window before | now |
|---|---|---|---|---|
| sunflower | 0.45 ms | 0.31-0.35 ms | 83 | 115-120 |
| basil | 1.18 ms | 0.41-0.43 ms | 41 | 104-120 |
| monstera | 0.52 ms | 0.46-0.55 ms | 82 | 78-105 |
| cactus | 0.24 ms | 0.23-0.25 ms | 105 | 120 |
| daisy | sketch | 0.51-0.58 ms | | 89-118 |
| tulip | sketch | 0.29-0.31 ms | | 119 |
| rose | sketch | 0.71-0.77 ms | | 74-99 |
| peony | sketch | 0.42-0.48 ms | | 108-118 |

The budget is section 12's: about 0.7 ms. The rose was 0.99 ms until its path
copies were cut (merging a compound leaf through a second batch copied every path
again; adding the leaflets straight into the tier's batch, plain leaves at five
steps a segment and only monstera, peony and petal shapes at nine, shading on
the outer two rings of a rose only) and is the heaviest.

Today's flick (`-nestieBench 1 -nestieScenario ready -nestieSpecies <raw>
-todayScroll 1 -frameMeter 1`, late frames per two-second window, the first two
windows dropped) and Choose's (`-nestieScript choose -companionScroll 1`), the
magnolia in the same minutes as the control. The machine was loaded to a load
average of hundreds (another agent, a full disk), so read it as "the same band
as a tree", not as absolute numbers:

| Today flick | late per window | | Choose flick | late per window |
|---|---|---|---|---|
| magnolia (control) | 16.5, 23.3 | | monstera | 17.8 |
| sunflower | 10.3 | | peony | 9.7 |
| daisy | 10.0 | | | |
| tulip | 14.0 | | | |
| peony | 17.3 | | | |
| monstera | 16.9 | | | |
| rose | 16.8 | | | |
| basil | 21.6 | | | |

No plant stands out from the tree on either screen; the redraw happens only when
a mood or the growth eases in, and the wind is a shear of the cached layer.

## 14. One engine, five more trees (round 3)

Lemon, olive, magnolia, cherry and azalea are painted the pomegranate's way,
from the same skeleton as before (a household's tree keeps its limbs, clumps,
blossom and fruit places), each with its own painter and extensions
(`LemonPainter*.swift` and so on). What they share is written once:

- **`TreeCore`** is the pose, the light, the four leaf classes and one clump
  painted back to front, with *hooks* between the classes (`Between.deep`, `.mid`,
  `.over`) for the species' own fruit; `TreeArt` is the order every tree is
  drawn in (ground, clumps by tier, wood, young leaves, pools of sun, the cut
  fruit, blossoms, seed leaves, a last pass). `LeafSpec` is what a species' leaves
  are (shape, width, how many sprigs, alternate or opposite, a share turned over
  to show another colour, whether the dark body behind them is wanted).
  `LeafArt` builds any of them; the pomegranate's spec is its defaults, so its
  crown did not move (checked pixel for pixel by day; only its bark and its night colours changed, on purpose).
- **`TreeInk`** is the moonlight rule and the leaf colours, used by the
  pomegranate too: at night the four classes are mixed towards one deep blue and
  the rim to a steel blue (section 1).
- **`TreeWood`** is the stems, with a `BarkStyle` per species: shredded,
  smooth, gnarled (burls in the outline, ridges that twist, an arched hollow
  in the trunk and not the limbs), lenticel, fine.
- **`BloomArt`** is a flower-covered crown: each clump's blossoms built once in
  the clump's units, sorted by the same light into classes, one fill per class.

What was learned, and holds for the next tree:

1. **Bark goes with the grain, never across it.** Every mark is a thin lens along
   the stem, in broken lengths; a short stroke across the stem, tilted, is what
   made the pomegranate read as crisscross X marks. A limb's own marks start
   a quarter of the way out so they do not cross the stem it leaves, a limb's lit
   edge and core shadow start thin at the fork, and the stems of a tree are painted
   one after another (each stem's bark over the last) so one stem's light is never
   laid across another where they cross low down.
2. **Two-tone leaves are two colours, not one with a glint.** The olive's tops
   are the dark half of its ramp and its undersides the silver half; about two
   leaves in five are turned over (`LeafArt.u`, a fill of its own). The silver
   is kept for the undersides, so a leaf turned over is the brightest thing in the
   crown. Narrow leaves need almost no dark body behind them (`LeafSpec.body`), or
   it shows as a balloon.
3. **A flowering tree is told in the order it grows.** Magnolia: bare wood and silver
   buds (the young leaves are gone from its canes by .6), goblets on bare wood,
   leaves only after (`leafy`, applied to the tufts too), and a few flowers stay.
   Cherry: blossom before leaf, thinning as the fruit sets. Azalea: the buds
   first, then flowers over everything.
4. **Flowers cover; they do not decorate.** Cherry and azalea paint every clump's
   flowers last, back to front over the whole crown (a front tier's leaves over a
   back tier's flowers left the shrub green with flowers in a band). Behind, a
   flower is a scalloped dot; in front it is the whole flower (five petals and a red
   eye with notches and stamens, or a corolla with a throat, spots and long
   stamens). Flowers of one class merge into one blob, so one extra fill under
   them, the union of every flower moved a hair away from the light in a darker
   tone, parts each from the next. Never push positions onto the clump's
   edge to keep them in (it draws a string of beads): draw again.
5. **No fruit in the model means derive it from what is there.** The cherry's
   pairs hang from about half its blossom sites (hashed from the blossom's own
   numbers), because giving the cherry a `crop` would change every household's
   seed draws and with them its skeleton.
6. **Fills are the cost, again.** Behind a flower-covered crown the leaf classes
   are merged (`LeafSpec.flat`: two classes behind, three in front, no glints)
   and the flowers keep two or three classes; a front clump is about 14 fills, a
   back one 5. A flower shape with fewer curves is cheaper on this GPU too
   (a back flower is ten quads, not twenty). Soft pools of sun are off on trees
   whose flowers are the light (`TreeArt.dappled`): a wash over them is a haze.
7. **Story details** stayed at four: the species' own seed (a pale pointed lemon
   seed, an olive stone, a red magnolia seed, a cherry stone, a dark speck), a
   fallen leaf, the fallen flower (a white petal, a curled magnolia petal browning
   at the edge, pink petals and others still in the air, a whole azalea corolla)
   and a dropped fruit when thirsty.
8. **The cutaway need not be the pomegranate's.** The lemon is cut across: a wheel
   of nine segments in a pale rind and thick pith, vesicles, seeds in two of them,
   a gleam of juice and a drop, with the rest of the lemon behind as a crescent
   of dimpled skin and its nipple. It hangs from a limb in the open, not over the
   trunk, so it is chosen well out to one side.

Numbers, iPhone 17 simulator (iOS 27), Debug, alternating runs, three rounds each
(`-artSheet redraw -artSheetCount 4 -artSheetSpecies <tree> -frameMeter 1`, old is
`-treeLegacy <tree>`). The machine was shared and noisy: recording is the mean of
`tree draw` over a run, frames per two-second window is the stress page.

| | recording old | recording new | stress page old | stress page new |
|---|---|---|---|---|
| lemon | 0.52 ms | 0.47 ms (0.9x) | 61 | 53 |
| olive | 0.63 ms | 0.59 ms (0.94x) | 56 | 44 |
| magnolia | 0.44 ms | 0.43 ms (1.0x) | 71 | 68 |
| cherry | 0.92 ms | 0.84 ms (0.9x) | 44 | 43 |
| azalea | 1.97 ms | 1.67 ms (0.85x) | 23 | 17 |

`-nestieBench 1 -nestieSpecies <tree> -todayScroll 1` and `-companionScroll 1`
(Choose) late and dropped frames per window were no worse than the old painter's
for any of the five, within the noise (for example lemon 1.0 late against 5.8,
azalea 0.5 against 6.8, Choose 4.2 dropped against 15.1).

### Fix round (v2)

Four things the first round got wrong, and what holds now:

9. **Flowers that cover are read as flowers only if they are few and large, in
   clusters with gaps.** The azalea's first bloom was 18 to 38 small flowers on every
   clump, which at card size was one pink blob with a pale smear where the sun was
   (a light class that spans the crown is a stain on flowers). Now each clump has one or two
   *trusses* (`BloomSpec.truss`): a middle flower and a ring of six, each about a fifth
   of the clump across, spaced round the dome so leaves show between, and the
   outer ones standing out of the leaves for a bumpy silhouette. **The light is
   on the truss's own sunny side**: a flower's class comes from how far it sits towards the
   sun from its truss's middle (and a little from where the clump stands), so every
   truss has a lit side and a shaded one, and no patch spans the crown. Each flower
   keeps its throat (a deeper pink disc), its three spots and its long stamens. Back
   clumps carry one small truss; the front ones two. This was also the cost: fewer, larger
   flowers are fewer curves.
10. **A tired tree is the same tree.** The shared pose shrinks a clump by a fifth and sinks
   and slides it, and the pomegranate's dense whorls survive that; a crown of few leaves (a lemon,
   an olive, a cherry) was left as bare limbs, a Y fork with leaves at its tips. For every
   tree but the pomegranate, `TreeCore.calmed` takes back three fifths of the pose's
   shrink and sink (the limbs still droop, because that is posture), and
   `LeafSpec.calm` (0.45) takes that share of the dropped leaves, the curled-short leaves and
   the shrunken dark body behind them. A flower-covered crown keeps its flowers when it is
   thirsty or dozing: `BloomArt` thins them (a quarter, a third) and `Tones` pales them, and
   they are not shut into buds. Thirsty is the same tree drooping and paling with a few leaves
   on the soil; dozing is the same tree, calm and dimmed under the dome.
11. **No marks at a fork.** A limb's bark stops short of the fork at its end (84 percent)
   and starts after the fork it leaves (a quarter out, a sixth on a trunk's segments); its lit edge
   and core shadow are drawn from 30 percent of the way along it (`TreeWood.from`),
   because a lens that starts at the fork is a white thread across the stem it leaves
   (starting thin was the first attempt, and drew a thread).
12. **Merge fills by tone.** The olive keeps two tones in the back (dark and middle, plus the
   silver undersides) and three in the middle, and all of them in front (`LeafSpec.merge`), with
   four sprigs instead of five. The silver two-tone is kept.

Numbers, same method, three rounds each of old against new on the loaded machine
(the stress page is frames per two seconds): azalea 17 against 22 (1.26x) with
recording 1.6 ms against 1.9 (0.83x); olive 32 against 36 (1.12x) with recording
1.1 ms against 1.3 (0.9x). The Today scroll bench was no worse than the old painter's for either,
within the noise.

