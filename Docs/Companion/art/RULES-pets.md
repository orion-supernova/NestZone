# Illustration rules for pets, from the kitten

The kitten (`CritterPainter*.swift`, `CritterGeometry.swift`, `CritterLook.swift`,
`PetMotion.swift`) is the pets' hero, as the pomegranate is the plants'
(`RULES.md`: read it first, the light, the palette ramps, the no-outlines rule
and the performance habits are the same). Everything is `Canvas`; no shaders, no
images. The owl is the second proof that the system is parameters, not a
drawing. Contact sheets, all Debug (`xcrun simctl launch <udid> com.walhallaa.NestZone ...`):

| Launch argument | Shows |
|---|---|
| `-artSheet kitten` | every stage by day and at dusk, then the four moods |
| `-artSheet kitten-close` | the grown pet at card size by day, dusk and night, then two faces cropped from an 800-point drawing |
| `-artSheet kitten-moods` | the four moods large, then the light (morning, evening, night, moon) |
| `-artSheet kitten-stages` | the seven stages large, two to a row, and the grown pet at dusk |
| `-artSheet pet-variants` | four more rows of the plan (hamster, bunny, puppy, fox), content and thirsty; Debug only, none is in the app |
| `-artSheet pet-redraw -frameMeter 1` | the cost bench (below); `-artSheetSpecies owl`, `-artSheetCount 1`, `-artSheetMood thirsty` |

Any pet species works in place of `kitten`. The shots from the pass are in
`art/pets/` (`index.html` lays before and after side by side).

## 1. One light, from the sky

- The pet takes `SceneFrame.skySide(hour)` through `CritterLook`, in the same
  way the pomegranate does: one unit vector `L` toward the sun (or the moon at
  night), at least a quarter of the way to a side, higher at noon than at dusk.
  Never invent a light of your own. Mirrored parts (the ears) get `L` with its x
  flipped, not a second light.
- **Every form** is `form(...)`: a rim, a ramp along `L`, a cool core shadow on
  the far side, a soft highlight toward `L`. Three to four fills; do not add a
  fifth. The rim is the path shifted 0.9 unit toward `L` and drawn *before* the
  real fill, so the sliver shows only on the lit edge, in the sky's colour
  (warm white at noon, amber at dusk, cool by the moon). Rim alpha is
  .26 by day, up to .6 at dusk and .56 by moon, halved asleep.
- **Shadow is a cool violet, never black and never grey** (`CritterLook.cool`:
  alpha .2 by day, .34 by moon). Night is cool, not ghostly: the lit side by
  moonlight is *deeper* than the day's shadow side, not paler; the colours go
  through `RGB.night` with a `dim` of .55 for fur, .3 for irises.
- **Contact shadow** is two ellipses on the floor, leaning away from the light
  by `-L.x * 5`: a wide soft pool and a tight dark one under the weight. A
  detail that touches the floor (bowl, curled body) gets its own.
- **Catchlights** sit on the side `L` points to; a second, small one opposite.
  They do not move when the eye looks about, because a reflection on a cornea
  does not.

## 2. Proportions per stage

The pet is drawn in the duckling's 120-unit box, feet at (60, 108), seen from
the front-left. Stages scale the whole figure about the feet
(`PetMotion.scales` 1, 1, .82, .62, .74, .86, 1) and a *baby factor*
(`babyness`: .6 at stage 3, .4, .2, 0 at grown) changes the proportions on top
of that:

| Stage | Reads as | What changes |
|---|---|---|
| 0 bundle | a knitted blanket, knotted, with a tassel | dome with V stitches in rows that sag at the sides, a knot like two cloth ears, a cuff |
| 1 peek | the bundle wobbling | ears over the edge, a dark gap with two eyes and a nose in it, a roll of knit over them |
| 2 hatchling | head out, blanket folded back | the head alone (babyness 1), two paws over the fold |
| 3 baby | a tiny kitten | per unit of `babyness` (.6 here): head x(1 + .5b), eyes +32%b, ears +18%b taller and +10%b wider, eyes 8%b further apart, body 10%b lower (short legs), tail 2b wider; the curled one's head x(1 + .35b) |
| 4-5 little, young | a young cat | the same, linearly less |
| 6 grown | a grown cat | head 1.08 of the kitten plan's base, eyes 4.9 x 5.45, ears 24 tall |

Eyes, ears and head are the first things a child counts: **a baby has a big
head, big eyes set low, big ears, short legs and a thick short tail.** A grown
one has none of that exaggeration.

## 3. Eye construction

Built in layers, in this order (see `CritterPainter.eye`), about eight ops open:

1. A socket in shadow (the coat's shade at .3 alpha, a hair bigger than the eye).
2. The opening, in the iris's darkest tone.
3. The iris: a radial gradient centred *low* in the eye (light passes through
   the far side from the light), light, mid, dark, plus a thin darker ring.
4. The pupil: a slit by day, **round at night**, wider when bright
   (`pupilW` = .34 + .56 night + .2 bright + .12 thirsty, for a cat; a bird's is
   always round, .5 + .26 night + .12 bright). Never a thinner slit than .34 by
   day: a hairline slit makes a kitten look fierce.
5. The glow: a pale crescent on the lower edge of the iris.
6. Catchlights (section 1).
7. The lid: a cover in the face's colour clipped to the opening, with a thin
   dark lash line at its edge. `closed = 1 - (1 - droop) * (1 - blink)`.
8. The upper-lid line, a thin dark arc, only while the eye is open (alpha .4).

Shut eyes are a curve with a light lid above and a lash at the outer corner,
never a line. Tilt acts: outer corners down when it wants something (.2 rad),
slightly up when bright (-.1).

## 4. Fur treatment

No outlines. Fur is five things, each one fill or two, built once per plan
(`CritterGeometry`):

- **Form** (section 1) for each big mass: body, haunch, head, ears, tail, legs.
- **Painted hairs**: ~50 short strokes per mass (4.2-6.2 long, .7 wide) that
  *go round the form* (tangent to the centre), as one path drawn twice, the
  second a hair toward the light in the lit tone. They are the texture; keep them
  under .3 alpha.
- **Tabby stripes** follow the form: tapered crescents (`Path.fur`) starting on
  the spine and wrapping toward the belly, bowed against the curve of the
  ribs. Lit copy shifted toward `L`. Never ellipses, never evenly spaced: two
  lengths, bend increasing toward the tail.
- **Edge fur is the silhouette itself** (`CritterFur.FurEdge.furry`): the outline
  of a form is walked and, every 6-12 units, pushed out into a small pointed
  tuft (1.4-3 units tall, ~3.6 across, leaning along the edge), so the edge is
  irregular and the fur is *one fill with the form it belongs to*. Never a
  separate leaf-shaped shape stuck on the edge: that reads as a fleck floating
  off the animal. Fewer tufts on the lit side (30% height) than on the shadow
  side (100%), and the cheeks always (the head's outline, cheek half only). The
  geometry has two variants, shadow on the left and on the right, chosen by the
  sign of `L.x`. Tails get the same by pushing a few points of the ribbon's
  edge out (`furRibbon`), with no fuzz stuck on.
- **Markings**: the forehead's three strokes (thin, pointed down), the
  eye-liner stripes running back from the outer corners, two cheek stripes,
  tail rings as quads between the tail's two edges so they end at the fur
  exactly.

Lighter muzzle and chest: radial gradients that end *soft* (the chest fades to
nothing at its rim), never a hard sticker. **Legs are the coat's colour with a
pale sock at the paw only** (a vertical fade to cream from the ankle down, plus
the paw), their own form shading, and a soft glow of the coat at the shoulder so
they melt into the body without a seam. A pale leg on a pale chest reads as a
cut-out. Whisker pads are puffs with four
dark dots each, the nose is a leather triangle with a gradient and a glint, the
ears carry pink inside, deepest at the base, with three cream hairs.

## 5. Mood acting

Moods are four poses blended by `PetMotion.weights` (dozing .05, thirsty .3,
content .62, bright 1), so a mood easing in is a *blend*, never a switch, and
every part takes its numbers through `PetMotion.by(doze, thirst, content, bright)`.
A pose is posture, face and tail, and only these.

| | Posture | Ears | Eyes | Mouth | Tail | Extra |
|---|---|---|---|---|---|---|
| **bright** | tall, bobs up on its paws every 1.5 s, head tilts .1 rad and sways | up, forward (-.03), 7% taller | wide, dilated, outer corners up | open smile with a tongue | up with a question-mark curl, sways fast, tip flicks | a blush |
| **content** | a relaxed sit, sunk 1.2 | easy (.12) | open, slow trusting blink every 7.5 s (.8 s long) | closed "w" | a lazy S, tip lifts now and then | |
| **thirsty** | sunk 2.4, shoulders low, head dropped 4.5 and turned .17 toward the bowl | flat and sideways (1.04 rad), one a bit more, 18% shorter | wide open, outer corners down, **looking at the bowl**; every 6.5 s it glances at you for a second | a small open "o"; a lick every 7 s | low along the floor, the tip twitching | **a little empty bowl beside it, only in this mood**: ceramic, a painted band, one last drop; it slides in as the mood arrives |
| **dozing** | **curled up** on the floor (its own pose, not a sitting one with its eyes shut): the head laid on the front paws, the tail wrapped over them, breathing slowly | back and relaxed | shut, with lash | a small smile | wrapped | the nightcap, which flies off when it wakes |

The point of the table: *thirsty* must never read as *asleep*. The tests are
the open eyes, the direction of the gaze, the bowl, and the ears; the scene's
own "z z z" belongs to dozing only. A pet that wants something also changes
what the room does around it (the sun is behind a cloud for every quiet mood,
that is the scene's).

Waking: lids flutter (`PetMotion.lids`), then the stretch and shake of
`PetMotion.offsets`.

## 6. Idle motion budget

Five idle motions, no more, none of which runs when `reduceMotion` is on
(they freeze at time 0; the poses and the blend remain):

1. **Breath**: the whole figure about the feet, sy +1.4% (content) to +3%
   (dozing), period 3.6 s (curled: 4.2 s). Never a bob while sitting.
2. **Blink**: 0.16 s every 4.3 s; a double every 12.9 s; the slow one
   (content only) every 7.5 s.
3. **Tail**: a sway that grows toward the tip; flick (bright, every 3.4 s),
   lift (content, every 6.5 s), twitch (thirsty, every 3.8 s).
4. **Ear twitch**: one ear, alternating, 0.2 s every 5.3 s.
5. **Head**: tilt sway (bright), the glance (thirsty), the drift of the eyes
   (content, tiny).

Plus the whiskers' sway (a sine, one stroke). Anything new replaces one of
these; `pulse` stays at one per screen as everywhere.

## 7. Performance budget

A pet is drawn whole every frame (the scene's 30 fps canvas), unlike the tree.
So:

- **Build once, fill every frame.** Silhouettes, hairs, stripes, ears and
  everything else that does not change live in `CritterGeometry` keyed by
  species; a painter fills them and moves only what acts (tail spine, ear
  angles, the eye's layers, whiskers, mouth). No `Path.smooth` and no random
  numbers in a draw.
- **Fills, not strokes; batch by colour.** One path per colour per part. A
  gradient only on a form, the muzzle, the iris and the chest. No clips except
  one per eye while a lid is down. No `Color` or `Gradient` built in a loop.
- **Budget** (simulator, `-artSheet pet-redraw -frameMeter 1 -artSheetCount 1`,
  `pet draw` in the Frames log, mean per frame, recording only): a grown cat
  <= 0.6 ms, an owl <= 0.45 ms. Measured on the iPhone 17 simulator (iOS 27.0),
  three runs each, medians: the old kitten 0.39 ms and the new 0.43-0.51 ms
  by mood (bright .51, thirsty .50, content .47, dozing .45); the old owl 0.30
  and the new 0.34-0.39; the duckling 0.05-0.06 either way. Worst frame under
  1.05 ms (the first draw builds the geometry). Whole-app CPU at rest with one
  pet on the bench: 8.3% of a core before, 11.3% after. Two pets on one screen
  are never needed.
- **Re-measured after the fur and leg rework (v2)**, a quieter machine, same
  bench: kitten 0.34-0.38 ms against 0.32 for the old painter, owl 0.17 ms, the
  duckling 0.08 ms (0.22 ms while thirsty, which draws the bowl; it builds a small
  `CritterPainter` for it). The attached fur is fewer fills than the leaf dabs
  were, so v2 is cheaper than v1.
- **Scrolling is untouched**: `-nestieBench 1 -nestieSpecies kitten -todayScroll 1
  -frameMeter 1` for 75 s: 0-1 late frames in the steady state both before and
  after (the one run that showed 29 before and 4 after was the first-draw hitch
  of a cold launch, in the noise); `-companionScroll 1` on Choose: 0 late
  before, 1 after. The pet is paused while Today scrolls, as before.
- **Shifted copies are the context moved, not the path copied** (a rim, a lit
  copy of the hairs): `var lit = c; lit.translateBy(...); lit.fill(path)`. Copying
  a 200-element path to move it was the biggest single cost in the first draft.
- If detail costs too much, make the same picture cheaper (a shifted copy, a
  batch, a cached path); do not strip it.

## 8. A new pet is a row

`CritterPlan` is the species: the coat (light, coat, shade, belly, mark), the
nose and the inner ear, the iris, and these numbers (kitten = 1):

| Parameter | Does |
|---|---|
| `ears` | `.point`, `.round`, `.long`, `.drop`, `.tuft`, `.none` (the shape) |
| `earHeight` | how tall they stand (1) |
| `headWidth`, `bodyWidth` | the proportions |
| `eyeSize`, `eyeSpread` | how big, how far apart (the eyes carry the soul: raise `eyeSize` for a hamster, lower it for a fox) |
| `pupil` | `.slit` (cat, fox) or `.round` (everything else) |
| `fur` | scales every edge dab: 0 sleek, 1 kitten, 1.6 fluffy |
| `muzzle` | muzzle length (a dog or a fox 1.3-1.5, a hamster .7) |
| `marks` | tabby stripes, plain, mask, chevron |
| `tail` | `.curl`, `.stub`, `.plume`, `.none` |
| `whiskers` | off for birds |
| `species` | the key under which `CritterGeometry` keeps what was built from the plan |

Eyes, light, fur, the bowl, the nightcap, the five idle motions and all four
moods are inherited as they are. The body plan (`sitter`, `perched`) decides
which painter runs; a new plan that does not fit either is a new painter, and
should come with its own section here.

## 9. What the art-direction passes rejected

Each pass was a screenshot, a list of rejections, a fix:

1. **Leaves, not fur.** Edge dabs, back stripes and brow strokes drawn at the
   tree's leaf size read as leaves stuck on a cat. Fix: edge fur 3-5 units,
   half-width ~1.3, stripes 60% as wide, brows as thin pointed strokes.
2. **A grumpy kitten.** Half-closed lids, a dark lid line and tilted eyes make a
   kitten look old and cross. Fix: larger rounder eyes set lower, a pupil never
   thinner than .34 of the iris by day, the lid line only while the lid is
   actually down, the upper-lid arc at .26 alpha.
3. **A lump for a tail.** Wrapping the tail along the floor in front of the paw
   read as a brown block; the content pose is a lazy S instead (the wrap is the
   sleeping pose). A dozing tail must stay inside the picture's floor margin
   (y <= 112 in the box).
4. **A sticker bib.** The pale chest with a hard edge; now it fades to 55%
   alpha at its rim. Spikes: a stripe may not start above the body's
   outline. A beard: the chin patch is small.
5. **Thirsty was asleep.** The first answer was to shut the eyes; the fix is
   the whole list in section 5 (the open eyes with a direction, the sideways ears,
   the low tail, the bowl, the lick), and removing the scene's "z z z" from
   every mood but dozing (`CompanionScene.drawFront`).

6. **Fur still read as leaves.** Even small, detached tufts float off the
   silhouette; the fix is the attached notches of section 4. Fur goes on the
   shadow side and the cheeks, and there are fewer.
7. **A pink glitch on the face.** It was the scene's pink butterfly seen edge
   on, flying over the head. Butterflies now circle a point up and to the right
   of a pet (`CompanionScene.drawFront`, `ScenePainter.butterflies(swing:)`).
8. **The duckling's thirsty was asleep too.** `PetPainter` now has the same
   acting: eyes open, a ring of white and the dark shifted toward the bowl, the
   head dipped toward it, the beak a little open, the same bowl; its eyes shut
   only when properly asleep (`PetMotion.sleep`).
