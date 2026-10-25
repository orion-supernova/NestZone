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
| `-artSheet batch-a` | the six pets of batch A (duckling, hamster, bunny, puppy, fox, hedgehog), grown, in the four moods |
| `-artSheet batch-a-faces`, `batch-a-faces2` | their faces, bright and thirsty, cropped from an 800-point drawing |
| `-artSheet batch-a-night` | the same six in the morning, at dusk, by night and by the moon |
| `-artSheet batch-b`, `batch-b-night` | the seven pets of batch B (deer, snow fox, polar cub, penguin, turtle, goldfish, and the redone owl) grown in the four moods, then in the morning, at dusk, by night and by the moon |
| `-artSheet pet-redraw -frameMeter 1` | the cost bench (below); `-artSheetSpecies owl`, `-artSheetCount 1`, `-artSheetMood thirsty` |
| `-ducklingLegacy 1` | (any launch) draws the duckling with its old, flat painter (`PetPainter`), to compare |

Launch arguments given to `xcrun simctl launch` did not reach the app on a simulator that other builds were also launching on; `xcrun simctl spawn <udid> defaults write com.walhallaa.NestZone artSheet <page>` (and `frameMeter`, `artSheetSpecies`, ...) and a plain launch did. Any pet species works in place of `kitten`. The shots from the pass are in
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
- **Batch A** (duckling, hamster, bunny, puppy, fox, hedgehog), the same bench,
  medians of the per-second means, the kitten run in the same session as the
  reference (the Mac was shared, so the absolute numbers run higher than the
  quiet-machine ones above; the ratios are what counts). Content / bright /
  thirsty / dozing, in ms: kitten .43 / .48 / .58 / .58; duckling .24 / .26 /
  .35 / .27 (the old flat painter was .05-.22); hamster .35 / .42 / .47 / .39;
  bunny .44 / .37 / .52 / .40; puppy .41 / .47 / .48 / .45; fox .42 / .44 /
  .56 / .45; hedgehog .35 / .34 / .43 / .23. None is dearer than the kitten in
  the same session. The first draw of a species (it builds its geometry) is
  1-2 ms worst frame for the fox and hedgehog and under 1 ms for the rest.
  A plain `Canvas` portrait in the Choose grid was tried inside a
  `drawingGroup` and was no better in an interleaved A/B on a quiet machine
  (1-6 late frames in 45 s either way, all at the cold start), so it is not
  there. `-nestieBench 1 -nestieSpecies <pet> -todayScroll 1 -frameMeter 1`
  for 45 s: late frames kitten 3, duckling 2, hamster 2, bunny 4, puppy 6, fox
  2, hedgehog 2, every one of them in the cold-start windows. `-companionScroll
  1` on Choose, 45 s, quiet machine, six runs each of the fox and the
  hedgehog: 1-6 late frames.
- **Batch B** (deer, snow fox, polar cub, penguin, turtle, goldfish, owl), the
  same bench, the kitten run first in the same session for every mood, medians
  of the per-second means after the first second, content / bright / thirsty /
  dozing, in ms: kitten .39-.43 / .39 / .46 / .35-.40; deer .30 / .28 / .30 /
  .26; snow fox .43 / .38 / .44 / .36; polar cub .28 / .28 / .29 / .23; penguin
  .20 / .19 / .24 / .18; turtle .26 / .25 / .32 / .29; goldfish .40 / .40 /
  .44 / .42 (dozing is .07 over the kitten's .35, the bowl's dozen fills, and
  .08 under its .50 before the pebbles' lit copies were merged into one);
  owl .25 / .24 / .28 / .34 (.17 on a quiet machine before the redo, which
  is not comparable with these). Worst frame after the first second under
  1 ms for every pet but the snow fox's 0.9 and, in two runs, a single 8 to 15
  ms frame (deer, owl) that the kitten's runs also show once in a while on a
  shared machine. First frame of a cold process, no `prepare`: kitten 3.9-4.9,
  turtle 3.0, penguin 2.8, snow fox 4.3, polar cub 4.8, owl 4.0, deer 13,
  goldfish 15-45; the app prepares off the main thread, which the bench
  (a bare `Canvas`) does not, so the last two are the worst case and were not
  re-measured with `prepare`. `-nestieBench 1 -nestieSpecies <pet>
  -todayScroll 1 -frameMeter 1` for 48 s: late frames of about 2,400 to 2,600:
  kitten 2, deer 1, snow fox 1, polar cub 1, penguin 1, turtle 0, goldfish 1,
  owl 1, all in the cold-start window.
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
| `ears` | `.point`, `.round`, `.long` (a bunny's, bent at five steps), `.drop` (a pup's, furred and in `earColour`), `.leaf` (a fawn's: broad, pointed, held out to the side), `.tuft`, `.none` (the shape) |
| `earHeight` | how tall they stand (1) |
| `headWidth`, `bodyWidth` | the proportions |
| `eyeSize`, `eyeSpread` | how big, how far apart (the eyes carry the soul: raise `eyeSize` for a hamster, lower it for a fox) |
| `pupil` | `.slit` (cat, fox) or `.round` (everything else) |
| `fur` | scales every edge dab: 0 sleek, 1 kitten, 1.6 fluffy |
| `muzzle` | muzzle length (a dog or a fox 1.3-1.5, a hamster .7) |
| `marks` | tabby stripes, plain, `.mask` (a fox's white lower face and dark tear lines), chevron, `.spots` (a fawn's, on the back and the haunch, curled up too) |
| `tail` | `.curl`, `.stub`, `.plume` (a brush, fuller in the middle, with `tailTip`), `.wag` (a pup's), `.cotton` (a rabbit's ball), `.none` |
| `whiskers` | off for birds, a dog and a hedgehog (the dots stay) |
| `chin`, `cheek` | the lower face: 0 is the kitten's round chin, 1 a pointed muzzle (fox, hedgehog); `cheek` bulges it (a hamster's pouches, 1.7). A long muzzle carries the nose and mouth down to its end (`HeadGeometry.drop`) |
| `noseSize`, `bib`, `eyeTilt` | the nose leather (a pup's is 1.7), how much bigger the pale chest is (a fox's bib 1.6), how far the outer eye corner is turned up (a fox's slant, radians) |
| `socks`, `earColour`, `tailTip` | what the ends are coloured: legs from the ankle down, the ears (a pup's darker ones, a fox's black tips), the tail's tip |
| `legWidth`, `tailFluff`, `tailSize` | how wide the legs are (a fawn's .62, a cub's 1.3), how much fuller a brush is (the winter fox's 1.3), how big a rabbit-style tail ball is (a deer's flag .62) |
| `shell`, `plates` | a turtle's dome and the scutes on it |
| `species` | the key under which `CritterGeometry` keeps what was built from the plan |

Eyes, light, fur, the bowl, the nightcap, the five idle motions and all four
moods are inherited as they are. The body plan (`sitter`, `perched`,
`waddler`, `shelled`, `swimmer`) decides which painter runs; a new plan that does not fit any is a
new painter, and should come with its own section here.

### Batch A: what the plan could not say

Five of the six pets of batch A are rows of the sitter, and the sixth, the
duckling, a bird seen from the side, is the one body plan added (`waddler`,
`CritterPainter+Duck.swift`, with the same `form`, `eye`, bowl, nightcap and
moods; it bounces rather than breathes). What is only one species' is a
function for that species in `CritterPainter+Species.swift`, switched on
`plan.species` and kept short: the hamster's hands and seed, the hedgehog's
sit, hood and ball. Rules the batch wrote:

- **A bent part is built at steps, not bent per frame.** A rabbit's ear at
  five bends (`HeadGeometry.bunnyEar`). At rest the painter draws one;
  between two moods it draws the two nearest at their weights. The numbers
  for each mood must therefore be whole steps (`by(4, 3, 1, 0)`), or the
  resting ear is two faint ears (the pass-1 ghost).
- **A coloured end is cut at build time.** The fox's black ear tips, white
  cheeks and socks are `Path.intersection` of the form's own outline with a
  region, so the ruff and the notches come out the right colour with no
  extra shape. Never a second shape laid over an edge.
- **A wag is a rotation about the root**, not a new tail: the spine's three
  free points turned by `sin(time * 13) * .34 * bright` about the first. A
  twitch is a small offset on the nose and the whiskers, not a redraw.
- **Spines are the new fur kind** (`SpineField`, `CritterSpines.swift`):
  narrow pointed blades laid in rows from the rim in, the outermost row first
  so each row covers the roots of the last, every blade with a pale tip (its
  last 42%). Two fills a row (blades, then tips) and a lit copy of the tips
  moved toward `L`. The animal's outline is the spines' own points, so it needs
  no fuzz. Keep a blade under 10 units and about 1 unit of half-width: at 12
  and 1.7 they read as cut paper.
- **A pale face is a palette swap on the same head.** The hedgehog's face is
  `belly`, only the crown is dark: `sitterHead` takes its light, coat and dark
  from the belly for it. A hedgehog drawn with the coat's colour on the face
  was a bear in a hat.
- **Dozing can be a ball or a tail.** The hedgehog's is rings of spines
  round the whole circle with a gap low on the left for the snout, one shut
  eye and an ear; the fox's tail comes round over its nose (so the head is
  drawn first), and ends in the white tip, shortened so the tip does not
  disappear into the white muzzle.
- A duckling's mood is posture too: bright holds the head up and flutters
  the wing, thirsty bows the head to the bowl (rotation about the neck), and
  dozing brings the head down onto the chest, squashes the body and folds
  the wing.

### Batch B: what the plans could not say

Deer, snow fox and polar cub are rows of the sitter; the penguin is a second
species of the waddler; the turtle (`shelled`) and the goldfish (`swimmer`)
are the two body plans added, each with its own geometry file and painter
(`CritterGeometry+Turtle`, `CritterPainter+Turtle`, `CritterGeometry+Fish`,
`CritterPainter+Fish`), and everything else (the light, `form`, the eye, the
bowl, the nightcap, the four moods) inherited. The owl was redone. Rules the
batch wrote:

- **A new kind of leg is a width, not a drawing.** `legWidth` narrows or
  widens the sitter's legs, paws and toes about their own middle, at build
  time: a fawn's .62 with a dark hoof (`socks`), a cub's 1.3. A fawn's spots
  (`Marks.spots`) are soft ovals laid along the form, one path for the back
  and one for the haunch, drawn through `hairs` in the belly's colour so each
  has a lit edge; the curled pose has its own set.
- **A winter coat is the same fox with more of it.** The snow fox is the fox
  row with `fur` 1.8, `tailFluff` 1.3, a bib of 1.5, a pale blue shade (`8C9FC4`)
  and frosty grey socks and ear backs. White on a pale sky only reads through
  its shade, so the shade is a clear cool blue and the cast shadow stays
  violet. Ice-blue eyes with the fox's slit.
- **A thick coat is shorter tufts, not longer.** The cub at `fur` 1.7 grew
  thorns along the haunch (the same mistake as rejection 10); at .85 the
  edge is soft and the cheeks still look thick.
- **A penguin rocks; it does not bounce.** `PetMotion.offsets(waddle:)`: a
  lean of .075 rad every 0.9 s about the feet when bright, with the foot it
  leans away from lifting 2.6 units (`PenguinGeometry` has its own feet);
  content is a .014 sway every 2.8 s; thirsty holds still and bows. The head
  is where the duckling's is (46, 47) so hats, the hatchling and the face
  crop need no special case. Black head, a white face disc small enough to
  leave a dark crown round it (a big one made it a ghost), a crescent of gold
  at the neck, a flipper that waves when bright and hugs in when it dozes.
- **A shell is built once and only filled.** The dome, the pale rim, 16
  scutes (three rows of hexagons tilted to follow the curve, one path), their
  growth rings: four fills and two strokes. What moves is the neck, a ribbon
  laid out per frame from under the rim to the head: stretched and swaying
  when bright, easy when content, sagging forward to the bowl when thirsty,
  drawn back to rest at the rim when it dozes (the head and neck are drawn *behind*
  the shell so a drawn-in head slides under it, the legs fold to 30%, the
  shell settles 4 units and the nightcap goes on the shell). A turtle is low
  and wide, so it is drawn 18% larger than the others to fill the card.
- **Refraction is drawn once and cheap.** The goldfish's bowl is a cached
  `BowlGeometry`: the glass, the water cut at eight levels (made when a level
  is first drawn, `Path.intersection` was most of a 15 ms first frame), 30
  pebbles, a rim of the sky's light on the lit side, a window highlight, a
  pool of bright light on the floor *on the side away from the sun*. What
  refraction does to the fish: it is magnified 20% and foreshortened by up
  to 26% as it swims near the curved wall (`wall`), the gravel is seen
  through a tint of the water, and a dashed line on the glass marks where the
  water was when the bowl is low. The fish and the weed are the only things
  that move. Thirsty is the water going down to level 62 and the fish hanging
  at the surface, head up (+.62 rad), gulping, looking out; dozing it rests
  on the gravel, eyes shut, the cap on its head. A bowl does not breathe
  (`PetMotion.offsets(still:)`) and has no empty bowl beside it, it is the
  bowl. Stages: a jelly egg on the gravel, a fry at 40%, then the fish grows
  into the same bowl.
- **Never mirror a catchlight.** The fish faces left or right by a mirrored
  context, so its eye is drawn in a context mirrored back and the form's light
  is flipped with it (`L` override), or the highlight lands on the wrong side
  after a turn.
- **Build off the main thread.** `CritterGeometry.prepare(plan)` builds every
  shape of a plan on a utility task when the scene appears
  (`CompanionScene`'s `.task(id:)`), so the first frame fills paths and
  builds none. The first frame of an unprepared goldfish was 15 to 45 ms and
  of the deer 13 ms (the kitten's, in the same bench, 4 to 5).
- **The owl.** It had no fur treatment at all: a smooth egg and a smooth oval
  head. Now painted feathers round the body and in each wing (`hairs`, one
  fill each), the head's silhouette broken by short feathers (`FurEdge`, the
  shadow side more), a ruff of short strokes round each face disc (2 to 3.4
  long; the first, at 3 to 5, was a sun of thorns), the disc's hard ring
  softened to .18 alpha, the brow feather at .22 alpha (at .5 it frowned), a
  bigger hooked beak and bigger ear tufts.
- **The duckling's collar is gone.** A pale arc under the bill read as a
  collar or a strange smile whatever its width; removed, with its geometry.
  The breast gradient already fades into the neck, which is what down looks
  like.

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

Batch A's passes (each a screenshot, a list of rejections, a fix; the shots
are in `art/pets/index.html`):

9. **Ears that ghost.** Two bends faded together at rest are two faint ears.
   A resting mood is a whole step of the five (`by(4, 3, 1, 0)`).
10. **A bear in a hat.** The hedgehog's face in the coat's brown. A pale face,
    a dark mask round the eyes, only the crown in spines; and spines of 12 by
    1.7 are cut paper (under 10 by about 1).
11. **A pillow and a tail that are feet and a belly.** A long pale foot read
    as a tongue or a tail, a big pale belly as a cushion; small feet, a small
    belly, fading into the spines.
12. **Kitten whiskers on a dog and a thin flame for a brush.** Whiskers off for
    a pup, the fox's plume fuller in the middle (`bulge`) with its tip cut from
    the same outline.
13. **A hook across a duckling's face.** The old scarf as a thick, short
    white arc under the bill; thinner, longer and lower.
14. **Sticks for hands.** The hamster's paws as two thin arms and a seed nobody
    could see; short arms, paws held up under the chin, the seed 1.75 times
    its size and nibbled.

Batch B's passes:

15. **A rabbit with spots.** The fawn's first ears stood straight up. A deer's
    are broad and held out to the side (`Ears.leaf`, +.82 rad when it is at
    ease), and a longer, narrower muzzle with a darker nose.
16. **Thorns on a bear.** Edge tufts at `fur` 1.7 on a white cub read as
    spikes down the haunch; .85.
17. **A flipper for a tail.** The snow fox's brush at 1.18 fluff with a blue-grey
    tip was a fish tail. Rounder (fluff 1.3) and the tip nearly white.
18. **A ghost with eyes.** The penguin's white face disc filled the whole head;
    a smaller one with a dark crown round it, and the gold patch as a crescent
    along the neck, not a blob.
19. **Same pose, four moods.** At rest (time 0) every sine is zero, so the
    goldfish's bright and content were one picture. Bright now has its own
    static pose: the veil fanned wider, the dorsal fin taller, the fish higher
    in the bowl and tilted up, the mouth wider.
20. **A small bowl and a small turtle.** Both stood at 60% of the card's
    height; the bowl is drawn 12% larger, the turtle 18%, the fish 20% larger
    inside the bowl.
21. **A sun of thorns on the owl.** See the owl above.
22. **A fin through the glass.** The goldfish's dorsal fin and tail crossed the
    bowl's rim and wall when it swam high or to the side. Nothing crosses the
    glass: the dorsal is lower, the fish never rises above 21 units (times its
    scale) below the surface (thirsty alone may break it, on purpose), the tail
    is shorter (14 units), and the fish's x is clamped so its tail and nose stay
    inside the wall, whichever way it faces, blended through the turn so nothing
    jumps.
