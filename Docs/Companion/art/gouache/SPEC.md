# Layered gouache tree: how it is built

Direction B. The canopy is overlapping leaf-shaped lobes in three depth tiers,
cool and dark at the back, warm and light in front, like layered cut paper.
Light comes from one place (upper left) for every part. Everything is code:
paths, solid fills and linear or radial gradients, nothing else.

- `tree.html`: the prototype, which is the reference implementation. Read it next to this file.
- `renders/`: the stills listed at the end.
- `tools/shot.sh`: headless Chrome render helper (`shot.sh OUT.png W H "query"`).

## 1. The brief as built

| Input | Range | Where it acts |
|---|---|---|
| `species` | magnolia, cherry, pomegranate, azalea, lemon, olive | the `SP` table (§6) |
| `seed` | any string (household id) | `build()` (§3), FNV-1a + mulberry32, identical to plant.html |
| `growth` | 0…1 | births and maturity (§8) |
| `mood` | 0…1 (1 bright, .62 content, .3 thirsty, .05 dozing) | five derived factors (§7) |
| `hour` | 0…24 | `day = clamp((cos((h−13)/24·2π)+.4)/1.1)`, same as plant.html |
| `t` | seconds | sway (§9). Ignore it if the app does motion in a shader |

Prototype URL params: `species seed growth mood hour t wind ops=1|table
sheet=species|mood|moods|growth|night|seeds|motion bg=0 pot=1 anim=1`.
A `t` in the URL draws one still on load (headless Chrome barely runs
requestAnimationFrame). Without `t` it animates and shows sliders.

**Not drawn: the pot, soil and sky.** The scene owns them. `pot=1` and the sky
are stand-ins for context only, and are excluded from every count.

## 2. Coordinates

- Tree space has its origin at the base of the trunk on the soil, x to the right, **y up is negative**.
  The page puts the origin at canvas (260, 282) of a 520×360 cell.
- `T.fit` is computed once in `build()` from the grown pose (growth 1, mood .62, t 0, no wind):
  `fit = min(S.H / −top, S.HW / max(−left, right))`, where `top/left/right` cover branch tips and clumps
  (centre ± 1.25R wide, 1.3R above, .8R below). `H` ≤ 226, so the grown tree is ≤ ~230 px tall.
- Draw order: the seed and fallen leaves go in **unscaled** pot space (they lie on the scene's soil, about
  ±40 × −2.4…+1.8). Then `scale(fit, fit)`, and the rest in model units.

## 3. The model, grown once from the seed

`r = rng(hash(seed))`. **The Swift port must call `r()` in exactly the order the JS does.**
That includes the calls inside object literals and function arguments, which JS evaluates left
to right, as Swift does. Don't hoist or reorder a single draw, or the household gets a different
tree. The order, in short:

1. `lean = (r()−.5)·2·F.lean`, then `alt = r()<.5 ? 1 : 0`.
2. Per stem `s` (1 or 3):
   - an angle jitter (multi-stem only), the trunk length, `birth` (multi-stem only) and the bend sign/size `b0`
   - then `F.segs` trunk segments. Each draws `rel` (k>0), `w1` (not last), the length, then inside
     `node()`: `dur`, `phase`. It also draws a **tuft** clump (young foliage riding the tip, dies when the
     next part grows).
3. `fan()` makes the limbs. Main limbs (depth 1): `F.limbs` plus one if `r()<limbsJ`. Forks (depth 2):
   2, or 3 if `r()<fork3`. Per limb: angle jitter (two draws), length, birth, then the `cup` bend (one
   draw, in the `node()` args), then `dur`, `phase`.
   - a non-terminal limb recurses first, then gets a tuft clump, then an **inner** clump if `r()<inner`
   - a terminal limb gets a **perm** clump in tier `r()<.2 ? 2−alt : 1+alt` (alt flips before it)
4. After each stem's fan, a tuft at the top of the trunk.
5. A clump draws, in order: the lobe count (`Cn.lobes` +0/1); per lobe `a, r0, len, hw, keep, ph`; two
   under-lobes (`a, keep, ph`); `acc` accents (`a, r0, len, keep, ph`); `tex` cut-outs (`a, d, a-jitter,
   len, keep`); then `ph`.
6. A perm clump: its own clump. Then a rear clump (tier 0) if `r()<rear`. Then the blossom count and per
   blossom `a, rad, size, rot, tilt, born, ph`. Then fruit if `r()<fruit.share`: count, `dx0`, then per
   fruit `dx` (not olive), `hang, size, ph, born, tilt`.
7. Births are normalised: wood and leaves into .08–.84 (`k = .76/maxEnd`), blossoms `.86 + born·.1`,
   fruit `.90 + born·.07`.
8. `fallen` (10 leaves on the soil), `sparks` (6 glints), `fallPh`.
9. **Depth tiers.** Pose the grown tree, then score every non-tuft, non-rear clump:
   `v = (y−y0)/(y1−y0)·.62 + (1−|x|/xmax)·.38 + (r()−.5)·.22` (one draw each, in clump order).
   Sort descending. The top `round(n·Cn.front)` (at least 1) are tier 2 (front), the rest tier 1.
   Low, central clumps come forward and high, outer ones sit behind. Then pose again for `fit`.

Model sizes for seed `home_k7f3x9`:

| species | limbs | clumps | lobes | blooms | fruit |
|---|---|---|---|---|---|
| magnolia | 12 | 16 | 165 | 10 | 0 |
| cherry | 15 | 17 | 211 | 14 | 0 |
| pomegranate | 28 | 45 | 649 | 15 | 10 |
| azalea | 37 | 59 | 740 | 43 | 0 |
| lemon | 12 | 19 | 239 | 5 | 8 |
| olive | 12 | 17 | 383 | 2 | 13 |

Clump counts include tufts, which are dead (not drawn) on a grown tree.

## 4. Per redraw: the pose

**Skeleton** (parents before children). This is the same scheme as plant.html: relative angles, so a bend
in the trunk carries everything above it.

```
g     = ease((p − birth)/dur)              (0 → not drawn, nor any child)
m     = clamp((p − birth)/(1 − birth))
sway  = wk·(.35 + d·.3)·(sin(1.25t − .55d + phase·.3)·.03 + gust(t)·.05)·(1.5 − .6p)
droop = side·(d·.2 + .04)·(wilt·.62 + doze·.18 − glow·.16) + (d==0 ? leanSign·(wilt·.05 + doze·.03) : 0)
a     = parentEndTangent + rel·lerp(.35,1,g) + sway + droop
len   = len0·g·(.8 + .2p)
end   = start + len·(cos a, sin a);  ctrl = mid + bend·len·(−sin a, cos a)
w0,w1 = node widths · lerp(.3,1,m)·(.55 + .45g)   (w1 ≥ .5)
```

**Clumps.** A clump hangs off its node's end point.

```
k    = back((p − birth)/.07) · (tuft ? 1 − smooth((p − die)/.1) : 1)      (skip if ≤ .01)
mat  = .6 + .4·smooth((p − birth)/.3)
R    = R0 · k · mat · (1 + .07glow − .14thirst − .08doze) · breath
       breath = 1 + (.012 + .012doze)·sin(t·(.9 − .4doze))
x    = end.x + ox·sc + side·R0·(.2wilt + .08doze)
y    = end.y + oy·sc + R0·(.26wilt + .12doze − .1glow)        (side = sign of x)
```

## 5. Shapes: four path builders, all clockwise on screen

All fills are nonzero. Every sub-path is wound the same way, so a union of overlapping pieces never
punches a hole. Keep that if you rewrite one.

- **`oval(cx,cy,rx,ry,rot)`**: four cubics, κ = .5523, starting at +rx and going +θ (clockwise on screen).
  Use this, not `Path(ellipseIn:)`, whose direction you would have to check.
- **`arcCW(cx,cy,r,a0,a1)`**: arcs as cubics in ≤ 90° pieces, `k = 4/3·tan(Δ/4)`, increasing angle.
- **`leaf(x,y,a,len,hw,blunt)`**: base at (x,y), tip at `len` along `a`.
  `c1 = (.08len, ∓1.32hw)`, `c2 = ((.56+.3blunt)len, ∓(1.22−.22blunt)hw)`. The upper half goes out, the
  lower half comes back. `blunt` 0 is a pointed leaf, 1 a rounded petal.
- **`limb(L,w0,w1,off)`**: a tapered quadratic. Up the left side, an arc round the tip, down the right side,
  an arc round the base. `off` slides it sideways by that fraction of the limb's width (lit edge, core
  shadow). The lit side is the one whose outward normal faces `LIGHT = (−.62, −.78)`.

**A clump outline**, `sil(c,x,y,R,k)`:
- one body `oval(x, y+.04Rk, R·body·k·bodyK, R·body·flat·k·bodyK)`
- per lobe, a `leaf` based at `pos = lb.a` (around the top arc, 150°…390°), radius `lb.r0·R·k`
- **shingle orientation**: `a = pos + sign(dev)·sweep·min(1, |dev|/1.1)` with `dev = wrap(pos − UP)`. The
  top lobe stands up and the side lobes lean down along the outline like roof shingles. That is what turns a
  spiky star into a leafy, drooping crown, and `sweep` is the main mood knob (§7).
- the shadow copy (k = 1) also takes the accent leaves. Copies with k < 1 skip the two under-lobes.

## 6. Species

`ramp` is five leaf tones, deep → highlight. Tier *n* uses `ramp[n]` for its shadow and `ramp[n+1]` for its
lit side; `ramp[n+2]` is mixed in for the sun. So the back tier is cooler and darker and the front tier
warmer and lighter, all from one ramp.

| | magnolia | cherry | pomegranate | azalea | lemon | olive |
|---|---|---|---|---|---|---|
| ramp | `#22404a #2d5b4f #3f7a50 #659c55 #a9c979` | `#2b4550 #3f6455 #5d8a5b #8ab36a #cfe4a0` | `#132b2a #1d4336 #2a5f40 #408046 #93bf6c` | `#16302c #21483b #2f6446 #4a874d #8dbb68` | `#1e4a3c #2a6a45 #3d8746 #5fa24a #b0d06e` | `#33463f #4a6057 #6a8375 #97ad9f #dae4db` |
| bark base / hi / dark | `#5d4b4d #bba79f #382c31` | `#553739 #a07c74 #33222a` + bands | `#4f3b35 #9a7c6c #2c201d` | `#4c3b36 #927666 #2c211e` | `#5f4c3e #ad9679 #382d25` | `#5d5047 #b2a493 #382f2a` + grooves |
| bloom a / b / c / glow | cup `#eea2bc #fde6ee #c2557f #ffe2ec` | sakura `#fde4eb #fff6f8 #d4607f #fff0f4` | flame `#f25a2c #ffa060 #a8281f #ffd0b0` | azalea `#d6478f #f7a8cd #a0275f #ffd6ea` | star `#fff8e6 #fffdf5 #f0c43c #fff6dc` | tiny `#f4f0d6 #fffbe8 #d4c77c` |
| fruit a / shade / hi / crown | — | — | pom `#cd2c3f #7c1426 #ffb0b0 #8d1c2b` | — | lemon `#f7d234 #d99c10 #fff8c0 #a4b43c` | olive `#3e2c45 #20162a #a796bb #4d5a2a` |
| form | 1 stem, trunk 44, 3 limbs (+1 50%), spread .68, vase | 1 stem, trunk 40, 4 limbs, spread 1.0, wide umbrella | 3 stems ±.26, shrub | 3 stems ±.5, trunk 18, low dome | 1 stem, trunk 64, round crown on a clear trunk | 3 trunk segments, gnarl 1, lean .12 |
| clump | R 36, 6 lobes, w .31, blunt .45 | R 31, 7 lobes, w .34, blunt .9 (fluffy) | R 32, 8 lobes, w .22, blunt .25 (glossy, narrow) | R 34, 7 lobes, w .32, dense | R 36, 7 lobes, w .3, dense | R 34, 14 lobes, w .13, blunt 0 (silvery, feathery) |

Cherry also has `bloomRamp = #8a4866 #c06d8f #e59bb5 #f6c3d2 #fff1f5`, weighted `.85 .95 1 1 1`. From
growth .86 the whole canopy turns to blossom: `ramp[i] = mix(ramp[i], bloomRamp[i], smooth((p−.86)/.1)·(.2+.8·open)·w[i])`.
That is where "lots of blossom" comes from, without a thousand flowers.

Every other number (form, can, sizes, shares, H/HW) is in `SP` at the top of `tree.html`. Port the table
verbatim.

**Blossom shapes**, `flower(kind,…)`, each appended to paths a (petals), b (inner), c (centre):
- **cup** (magnolia): a tall pale inner petal, plus two pink petals cupping it at ±(.26+.26·open).
- **sakura**: five petal ovals, a pale disc, a deep eye.
- **azalea**: five rounded petals (blunt .8), a lighter inner star, a dot.
- **flame** (pomegranate): a short red tube (c, drawn *first*), a four-oval orange ruffle, two light ruffles.
- **star** (lemon): five narrow cream petals, a yellow eye.
- **tiny** (olive): three dots.

**Buds**: a `leaf` pointing up, length 1.15s, plus a sepal. They sag with `wilt` and appear when open < .6
(for 60% of blossoms; every magnolia cup).

## 7. Mood: one number, five factors

```
thirst = smooth((.60 − m)/.30)   // colour drains, lobes shrink and fall        0 at ≥.60, 1 at ≤.30
doze   = smooth((.30 − m)/.25)   // paler, sparser, asleep                     0 at ≥.30, 1 at ≤.05
glow   = smooth((m − .70)/.28)   // saturated, lifted, luminous                0 at ≤.70, 1 at ≥.98
wilt   = smooth((.66 − m)/.42)   // posture
open   = smooth((m − .22)/.40)   // blossoms: open above ~.6, buds below ~.3
```

At the four named moods:

| | thirst | doze | glow | wilt | open |
|---|---|---|---|---|---|
| bright 1.0 | 0 | 0 | 1 | 0 | 1 |
| content .62 | 0 | 0 | 0 | .03 | 1 |
| thirsty .30 | 1 | 0 | 0 | .95 | .10 |
| dozing .05 | 1 | 1 | 0 | 1 | 0 |

**What each factor moves:**

- **Shape.** A quiet tree keeps every clump whole: clumps shrink, sag and curl, but never break into
  confetti.
  - `sweep = can.sweep + .32wilt + .1doze − .3glow`: lobes lean down the outline, or lift when bright.
  - `sag = .42thirst + .2doze`: the lobes' *positions* slide down the clump's sides,
    `pos' = pos + sign(dev)·sag·min(1, |dev|/1.2)`.
  - `blunt = min(1, can.blunt + .35thirst + .2doze)`: tired leaves fold to rounder tips, so no spikes.
  - `curl = .12thirst + .2doze`: a lobe with `keep < curl` is drawn at 55% length (a softly ragged outline).
  - `lenK = 1 − .14wilt` and `wK = 1 − .3wilt` (lobes shorter and narrower, as if folding).
  - `bodyK = 1 − .06thirst − .1doze`.
  - The lit copy shrinks: `litK = .74 − .04thirst − .04doze`.
  - The sun patch shrinks: `.42·(1 + .14glow)(1 − .3thirst − .3doze)`; its α is ×(1 − .4doze).
  - Clump size (pose): `×(1 + .07glow − .2thirst − .16doze)`. Clumps hang lower by
    `R0·(.1thirst + .22doze)` on top of the wilt term.
- **Sparseness** comes from smaller clumps leaving gaps, not from missing lobes. Only the cut-outs inside the
  light are skipped (`keep < drop`, `drop = .2thirst + .42doze`).
- **Posture**: the branch droop and clump offsets in §4.
- **Leaves on the soil**: `round(10·clamp(.55thirst + .45doze))` of the fallen leaves are drawn. When
  thirst > .3 one leaf is falling at any time (a 5.5 s cycle, deterministic in t).
- **Colour**, per ramp step `i`, in `leafTone`:
  ```
  c = mix(ramp[i], DRY[i],  thirst·(i<2 ? .75 : .85))    DRY  = #4d4b31 #646039 #7f7b44 #9d9652 #c9c07c  (olive)
  c = mix(c,       DOZE[i], doze·.8)                       DOZE = #8b8466 #a29a78 #bab08b #cfc59f #e4dbb9  (pale straw)
  → HSL: s ×= 1 + .34glow;  i≥2: l += 5glow, h −= 8glow;  i<2: l += 1.5glow
  → night(…, dim = [1, .96, .92, .86, .74][i])
  ```
  Thirsty goes olive and dozing goes pale straw with little contrast. Both are RGB mixes, so they pass
  through olive rather than rotating through odd hues.
- **Bark**: s ×= 1 − .25thirst − .35doze; l += 4thirst + 7doze.
- **Blossoms**: s ×= (.5 + .5open)(1 + .12glow)(1 − .4doze); size ×(.35 + .65open)(1 + .14glow).
  Buds take `mix(mix(c, a, .55), ramp[3], .4thirst + .25doze)`, and a dense species (azalea) shows buds
  for only 30% of its blossoms.
- **Fruit**: s ×= (.62 + .38m)(1 − .3doze); size ×(1 − .12thirst − .1doze).
- **Luminous (bright)**: a radial gradient behind the crown in `#fff4cc`, α .4·glow (×(.4+.6day)).
  Per-flower glows α (.16 + .2glow), up to 4 glints.

## 8. Growth

- 0–.085: the seed (two fills) wobbles; it is gone by .125.
- .09–.30: two seed leaves at the first segment's tip, popping in with `back()`.
- From .08: the wood grows segment by segment. Every non-terminal node carries a **tuft** (a small tier-2
  clump) that pops in at 35% of the node's growth and shrinks away as the next part arrives. That gives the
  sprout → sapling → young tree read.
- Perm clumps pop in (`back`, .07 wide) as their branch completes, then mature in size over .3.
- Blossoms .86–.96 (pop .05). Fruit .90–.97. Cherry's canopy turns pink over .86–.96.
- Stage names: seed .04, sprout .12, sapling .30, young tree .52, tree .76, in bloom .97.

## 9. Motion

Every motion term is a pure function of `t`. Under the new brief the app sways a cached picture with a
shader, so **skip this section in the port** if you take that route. Freeze `t` (or pass 0) and the still
is unchanged.

- `gust(t) = max(0, (sin .7t + .5 sin(1.9t+1) + .8 sin(.23t+2))/2.3)`.
  `spring(t, lag) = g + .9(g − gust(t−lag−.35))` with `g = gust(t−lag)`. It overshoots when the gust
  changes, which gives springy secondary motion without state.
- `wk = wind·(.4 + .6·min(1, m/.62))·(1 + .25glow)`: a thirsty tree is limp, a bright one lively.
- Branches use the skeleton sway (§4), which grows with depth.
- **Parallax per tier**, `par(tier, extra)`:
  - amplitude `SWAY[tier].amp + extra` with amp 1.1, 2, 3 (back to front), lag .55, .3, .12, phase 0, .9, 1.7
  - `dx = A(sin(1.1t + c.ph + ph + .4extra)·.45 + spring(t, lag − .08extra)·1.1)`, `dy = A·.35·sin(1.7t + 1.3c.ph + ph)`
  - the lit copy uses extra .6 and the sun patch 1.1, so light shifts slightly over its own shadow
- Lobe flutter: ±.03 / .05 / .07 rad on the shadow / lit / sun copies. Fruit swings as a pendulum on its stem.
- Breathing: clump scale 1.2% at .9 rad/s, slower and deeper when dozing.

## 10. Drawing order and calls

**First, every visible clump's outline once.** Sort the clumps by (tier, then height, top first). For each,
build `Sh = sil(c, x, y, R, 1)` at its tier-0 parallax position and keep it. Append it to:
- `U[tier]`, the tier's union
- `RimP[tier]`, translated `(−.055R, −.07R)` towards the light
- `Cast[tier]`, translated `(+.07R, +.11R)` away from it
- for tier 1 and 2 non-tuft clumps, an oval to `WoodShade` at `(x + .08R, y + .42R)`, rx `R·body·1.02`,
  ry `R·body·flat·.95`

Then, all in one `save` / `scale(fit)` / `restore`:

1. **Unscaled**: the seed (2 fills, early only), then fallen leaves (1, linear gradient across ±40).
2. **Crown light**: 1 radial fill, when bright, or at night in bloom.
3. **Tier 0**:
   - rim `RimP[0]`: 1 fill, always
   - each clump: shadow + lit = 2 fills
4. **The wood** (all limbs batched; root limbs have a **flat** base):
   - silhouette plus root flare: 1 fill, vertical gradient
   - core shadow strip: 1 fill
   - lit edge strip: 1 fill, gradient
   - **glint** (smooth bark only: magnolia, cherry, lemon), a thin strip at `side·.2`, width `.07 w`: 1 fill
   - marks: 1 stroke (cherry bands, olive grooves, pomegranate and azalea "fibre")
   - **olive knot**: 1 fill
   - **canopy shade on the wood**: `clip(bark)`, then fill `WoodShade` with a vertical gradient `SHADE`
     α .42 → .12 from the crown's middle to its bottom: 1 fill
5. **Tier 1**, then **tier 2**. For each tier:
   1. **cast shadow**: `clip(union of the tiers behind)` (for tier 2 the bark is in the union too), then
      fill `Cast[tier]` with `SHADE` at α `shadeA`. 1 fill. Tier 1 skips it when there is no tier 0.
   2. **rim** `RimP[tier]`: 1 fill, only at night (`1 − day > .3`)
   3. every clump of the tier:
      - shadow: linear gradient along the light
      - lit: radial gradient
      - tier 2 only: the **split halves** (`veins`), solid `vein` α .85
      - sun patch: solid
      - tier 2 only: cut-outs
   4. this tier's fruit:
      - glows, n radial fills
      - stems, 1 stroke
      - bodies, n radial fills
      - highlights, 1 fill
      - crowns / nubs, 1 fill
   5. this tier's blossoms, in this order:
      - glows: n radial fills; a dense species glows only for blossoms with `born < .35`
      - pomegranate tubes: 1 fill, batched
      - **each flower's parts**: 1–2 gradient fills each (§14)
      - olive dots: 1 fill
      - centres / calyxes: 1 fill
      - throat spots: 1 fill
      - stamens: 1 stroke, width .55
      - anthers: 1 fill
      - buds: 1 fill
      - sepals: 1 fill
6. Seed leaves of a sprout (2). Glints (1).

Per-tier tones:

| tone | formula |
|---|---|
| `sh0` | `ramp[n]` +4L −4h |
| `sh1` | `ramp[n]` −4L +6h |
| `li0` | `mix(ramp[n+1], ramp[n+2], (.34+.18glow)(1−.45·night)(1−.35doze))` |
| `li1` | `ramp[n+1]` |
| `li2` | `ramp[n+1]` −4L +5h |
| `vein` | `mix(ramp[n+1], ramp[n], .38)` |
| `sun` | `mix(ramp[n+1], ramp[n+2], (.5+.18glow)(1−.35·night)(1−.4thirst))` |
| `tex` | `mix(ramp[n], ramp[n+1], .5)` |
| `SHADE` | `ramp[0]` mixed .35 with `#122027`, −10L. The tree's own deepest tone, so a pink cherry gets a rose shadow, not grey |
| `shadeA` | `(.3 + .05glow)(1 − .35thirst − .3doze)(1 − .25·night)` |
| `RIM` | by night `mix(ramp[4], #d9e2ff, .6)`, by day `mix(ramp[4], #fff8e2, .5)` |
| `rimA` | `(.18 + .12glow)(1 − .3doze)(1 + 2·night)`; tiers 1 and 2 use ×.55 |

The shadow gradient runs from `centre + LIGHT·R` to `centre − .8·LIGHT·R`. The lit gradient is centred at
`lit centre + (−.3R, −.36R)` with radius 1.1R, stops 0 / .55 / 1.

**Measured** (fill + stroke calls per redraw, tree only, pot and sky excluded), 6 seeds × 4 moods × 6
stages × day/night × 3 moments, by `?ops=table`. Clips are not counted: there are at most 3 per redraw
(wood shade, cast 1, cast 2).

| species | worst | mean | grown, mood .9, day (render 01) | port baseline worst |
|---|---|---|---|---|
| magnolia | 141 | 32 | 82 | 95 |
| cherry | 101 | 32 | 82 | 77 |
| pomegranate | **232** | 59 | 166 | 201 |
| azalea | 209 | 62 | 207 | 188 |
| lemon | 151 | 36 | 93 | 132 |
| olive | 138 | 34 | 88 | 131 |

The worst case is 232, under the ≤ ~260 asked for a mood change that redraws every frame for ~1.5 s.
Quiet trees cost less (smaller clumps, fewer open flowers). Before trimming, the second pass reached 282:
the split halves and cut-outs on tier 1 and a per-flower gradient pomegranate tube were removed to get
back under.

History, for the record: the first strictly-batched version (one path per depth layer, ~12–24 calls)
looked flat and noisy. Per-clump fills in depth order are what made the canopy read as volume.

## 11. Porting to SwiftUI Canvas

| JS | Swift |
|---|---|
| `new Path2D()` + `moveTo` / `lineTo` / `quadraticCurveTo` / `bezierCurveTo` / `closePath` | `Path` + `move(to:)` / `addLine` / `addQuadCurve` / `addCurve` / `closeSubpath`, 1:1 |
| `ctx.fill(path)` with a solid colour | `context.fill(path, with: .color(c))` |
| linear gradient | `.linearGradient(Gradient(stops:), startPoint:, endPoint:)` |
| radial gradient | `.radialGradient(Gradient(stops:), center:, startRadius:, endRadius:)` |
| `ctx.scale(fit, fit)` | `context.scaleBy(x: fit, y: fit)` |
| `globalAlpha` | only used for the stand-in pot. Glow alphas are baked into colour stops |
| `stroke` (stems, bark marks, stamens) | `context.stroke(path, with:, style: StrokeStyle(lineWidth:, lineCap: .round))` |
| `ctx.save(); ctx.clip(path); …; ctx.restore()` | `var c = context; c.clip(to: path); c.fill(…)`: a copy of the context, so the clip ends with it |
| `path.addPath(other, new DOMMatrix([1,0,0,1,dx,dy]))` | `path.addPath(other, transform: CGAffineTransform(translationX: dx, y: dy))` |

- No `ellipse` or `arc` is used in the tree; circles are `oval()`'s four cubics. That keeps the winding
  identical (see §5). If you use `Path(ellipseIn:)` anyway, check its direction against `leaf`, or a union
  can open holes. Clips use the nonzero rule (SwiftUI's default), and every clip path is a union of
  clockwise pieces.
- Colours: the prototype goes hex → RGB → HSL for the mood moves (`toHsl` / `fromHsl` are standard,
  h in degrees, s/l in 0–100), then through `night()`.
  `night`: `n = (1−day)·dim`; desaturate `s ×= 1 − .25n`; then in RGB `r ×= 1 − .46n, g ×= 1 − .4n,
  b ×= 1 − .14n`. It is a cool filter, deliberately **not** a hue rotation (the old one turned lemons
  orange). Moonlight: `ramp[4] = mix(ramp[4], #cdd6ff, .3n)`. Blossom glows lean towards the petal colour
  at night.
- Numbers: use `Double`. `hash` / `rng` need 32-bit wrapping arithmetic (`&*`, `&+`, `UInt32`), as the
  existing `Ink.Random` already does if it matches mulberry32. **Check that it does.** The old port uses
  `Ink.Random(seed)`, and SplitMix64 would grow a different tree from the same id.
- **Bug found and fixed here**: on multi-stem species a later stem may be the only wood grown so far. The
  root flare and seed leaves must use the first *grown* root node, not `nodes[0]`. The old code crashed
  on that.
- Cache: build `T` once per (seed, species). With the new brief the whole picture is cached per
  (growth, mood, day, decorations). Every function here is pure, so re-render on change and nothing else.
- Reduce Motion: pass a fixed `t`.
- The tree never draws outside x ∈ [−230, 230], y ∈ [−235, +2] in canvas px around its base (the fit
  guarantees the top; glows can reach ~20 px further).

## 12. What got richer, and what is left

Done in the second pass, as listed in §14:
- the clipped cast shadow
- the canopy's shade on the wood
- rims (tier 0 always, every tier by moonlight)
- per-flower gradients, stamens and throats
- two-tone midrib split on the front tier
- coherent quiet moods
- bark glint, fibre marks and the olive knot
- flat stem bases

Still open:
1. Midrib halves on tier 1 too (+~10 calls on the dense species).
2. Cut-outs back on tier 1 at night only, when the moonlit rims make tier 1 read anyway.
3. A contact shadow where the trunk meets the soil. That belongs to the scene, which owns the soil.

## 13. Renders (`renders/`)

Kept in the repository as JPEG. Any other still can be made with `tools/shot.sh`.

| file | what |
|---|---|
| `01-species-day.jpg` | the six species, growth .97, mood .9, 13:00, with call counts |
| `02-moods-magnolia.jpg` | magnolia at bright 1, content .62, thirsty .3, dozing .05 |
| `03-growth-magnolia.jpg` | seed .04, sprout .12, sapling .30, young tree .52, tree .76, in bloom .97 |
| `05-night-species.jpg` | all six at 23:00 |
| `06-moods-all-species.jpg` | 6 species × 4 moods |
| `07-seeds-magnolia.jpg` | six household ids, same species: seeded variety |
| `09-moods-before-after.jpg` | magnolia and azalea, 4 moods: the first version (top) vs the second pass (bottom) |

## 14. Changes since the port baseline

The baseline is `scratchpad/port-b/baseline/tree.html`. This is everything that differs from it, so the
port can apply the delta without re-reading the rest.

### 14.0 Not changed (verified by diff)

- `build()` is byte-identical, and so is every `r()` call. **No new randomness**, nothing appended.
  Every household grows the same tree.
- `pose()` keeps every term that is non-zero at the build pose (mood .62), so the tier assignment and
  `fit` computed in `build()` are unchanged. Its two changes below use only `thirst`/`doze`, which are 0
  at .62.
- `hash`, `rng`, `oval`, `arcCW`, `leaf`, `moodFactors`, `night`, `par`, `gust`, `spring`, the sky, the
  stand-in pot and the page code are all unchanged.

### 14.1 Species table: new keys, draw-only (`build()` never reads them)

| species | new keys |
|---|---|
| magnolia | `bark.glint: true` |
| cherry | `bark.glint: true`, `bloom.anther: '#f2cf6b'` |
| pomegranate | `bark.mark: 'fibre'`, `bloom.anther: '#ffd25a'` |
| azalea | `bark.mark: 'fibre'`, `bloom.anther: '#e8a24a'`, `bloom.dense: true` |
| lemon | `bark.glint: true`, `bloom.anther: '#f0b93c'` |
| olive | none (it already has `mark: 'groove'`, which now also gets a knot) |

### 14.2 Constants

- `DRY` is now `#4d4b31 #646039 #7f7b44 #9d9652 #c9c07c` (olive; was olive to straw).
- New: `DOZE = #8b8466 #a29a78 #bab08b #cfc59f #e4dbb9` (pale straw).

### 14.3 New and changed functions

- **`limb(P, L, w0, w1, off = 0, flat = false)`**: new `flat` parameter. When true, skip the base
  `arcCW` (the closePath draws a straight base instead). Used for every root node (`parent == null`) in the
  bark, edge, core and glint paths.
- **New `halfLeaf(P, x, y, a, len, hw, blunt, side)`**: one half of a `leaf`, split at a midrib that is a
  quadratic with control `(.5len, −.12hw)` in leaf space. Both halves are clockwise:
  - `side < 0`: `moveTo(base)`; the leaf's first cubic to the tip; quad back along the midrib to the base
  - `side > 0`: `moveTo(base)`; quad along the midrib to the tip; the leaf's second cubic back to the base
- **New `bloomParts(kind, x, y, s, tilt, rot, open, C, B)`**: returns a list of `{path, gradient, stops}`
  filled one by one (each a separate fill), and appends shared pieces to
  `B = {under, pc, st, an, spot, flat}`. It replaces `flower()` in `drawBlooms`; `flower()` is still in the
  file but unused.

| kind | own fills (gradient, stops) | shared pieces |
|---|---|---|
| `cup` | **inner petal** (the same `leaf` as before), linear from base to tip at 1.3s: `mix(c,b,.5)`@0, `mix(a,b,.6)`@.5, `b`@1. **Two outer petals** (as before), linear base → 1.14s along the axis: `c`@0, `a`@.45, `mix(a,b,.7)`@1 | calyx → `pc` |
| `sakura` | petals (5 ovals as before), radial r 1.05s: `mix(c,a,.4)`@0, `a`@.4, `b`@1 | 7 straight stamens of .42s at `rot+.3+i·2π/7` → `st`, anthers r .06s → `an`, eye r .12s → `pc` |
| `azalea` | petals (5 leaves, blunt .8, as before), radial r s: `c`@0, `mix(c,a,.6)`@.32, `a`@.6, `mix(a,white,.22)`@1 | 4 throat dots r .045s on the petal nearest UP → `spot`, 5 curved stamens of 1.05s around `up+.9` (spread .9) → `st`/`an` |
| `flame` | ruffle (4 ovals as before), radial r .62s centred at `X(.8s, 0)`: `b`@0, `a`@.45, `mix(a,c,.45)`@1 | tube (`leaf` .78s × .24s) → `under`; 3 anther dots at `u = .98s`, `v ∈ {−.2, 0, .2}s` → `an` |
| `star` | petals (5 narrow leaves as before), radial r .9s: `mix(b,c,.3)`@0, `a`@.35, `b`@1 | 5 stamens .36s from `rot+.6` (spread .8·2π) → `st`/`an`, centre r .15s → `pc` |
| `tiny` | none | 3 dots → `flat` |

  Stamens are `moveTo(centre)` then `quadraticCurveTo(centre + (cos(a−.25), sin(a−.25))·.55len, tip)`, with
  anthers as `oval` dots at the tips. Sakura stamens are straight `lineTo`s.

### 14.4 `palette()` / `leafTone()`

- `leafTone`: `c = mix(c, DRY[i], thirst·(i<2 ? .75 : .85))`, then **new** `c = mix(c, DOZE[i], doze·.8)`.
  **Removed** `s ×= 1 − .5doze; l = lerp(l, 80, .3doze)`. The glow lines are unchanged.
- `o.fallen = night(toHsl(mix(#b9a25c, #d6c79c, doze)), day, .9)` (was a straw `leafTone`).

### 14.5 `pose()`

- Clump scale `sc = k·mat·(1 + .07glow − .2thirst − .16doze)·breath` (was `−.14thirst −.08doze`).
- Clump `y = … + R0·(.26wilt + .1thirst + .22doze − .1glow)` (was `.26wilt + .12doze − .1glow`).

### 14.6 `drawTree()`, in order (new steps marked ★)

1. Fallen leaves fill with a linear gradient from (−40, −3) to (40, 3): `fallen` → `fallen −8L +6h` (was solid).
2. Mood shape constants:
   - `drop` now applies only to cut-outs
   - ★ `curl = .12thirst + .2doze`
   - `bodyK = 1 − .06thirst − .1doze`
   - `sweep = can.sweep + .32wilt + .1doze − .3glow`
   - ★ `blunt = min(1, can.blunt + .35thirst + .2doze)`, used for lobes and halves instead of `can.blunt`
   - ★ `sag = .42thirst + .2doze`
   - `litK = .74 − .04thirst − .04doze`
   - `at(pos)` adds `sign(dev)·sag·min(1, |dev|/1.2)`
   - ★ `lobeLen = R·len·k·lenK·(keep < curl ? .55 : 1)`
3. `sil()`: **no lobe or accent is skipped any more** (the `keep < drop` tests are gone). Lobes use
   `lobeLen` and `blunt`.
4. ★ `veins(c, x, y, R, k)`: for every non-under lobe with `keep ≥ curl`, at the lit copy's position and
   scale, call `halfLeaf` with `side = −1` if `(−sin a·LIGHT.x + cos a·LIGHT.y) > 0`, else `+1`.
5. Tones: `li0` gains `×(1 − .35doze)`; `sun` gains `×(1 − .4thirst)`; ★ `vein`, ★ `SHADE`, ★ `shadeA`,
   ★ `RIM`, ★ `rimA` (§10).
6. ★ Precompute every visible clump's `Sh` plus `U`, `RimP`, `Cast` and `WoodShade` (§10). `drawClump`
   reuses `Sh` instead of building it.
7. `drawClump`: shadow → lit → ★ veins (tier 2 only, `vein` α .85) → sun (α ×(1 − .4doze)) → cut-outs
   (**tier 2 only** now).
8. `drawWood`:
   - root limbs flat
   - ★ glint strip (smooth barks): `limb(q, .07w0, .05w1, side·.2)` for depth ≤ 1 with w0 > 2.5, filled
     `barkHi +10L` at α .55·(1 − .5doze), after the lit edge
   - marks: `'fibre'` is one groove at −.1 (`'groove'` stays at −.16 and .12)
   - ★ olive knot: on depth-0 non-root segments with `g > .9` and `w0 > 3`, an oval at u = .45, `w·(.13, .2)`, rotated to
     the segment, fill `barkDark` α .85
   - ★ wood shade: `save`; `clip(bark)`; fill `WoodShade` with a linear gradient `(0, cym) → (0, bot+20)`,
     `SHADE` α .42·(1 − .3doze) → α .12; `restore`
9. The tier loop is now, per tier:
   - ★ cast (tier ≥ 1; §10)
   - ★ rim (tier 0 always; tiers 1 and 2 only when `1 − day > .3`)
   - the clumps
   - then wood (tier 0) or fruit and blossoms (tiers 1 and 2)
10. `drawBlooms`:
    - glows are skipped for `dense` species unless `born < .35`
    - buds: `born < (dense ? .3 : .6)` (or every cup); colour mix towards `ramp[3]` is `.4thirst + .25doze`
    - fills, in order: glows → `under` (`bc −4L`, flame only) → each flower's parts → `flat` (`ba`) →
      `pc` (`bc`) → `spot` (`bc −10L` α .8) → `st` (stroke `mix(bc, ba, .3)` α .85, width .55, round
      caps) → `an` (`tone(anther, day, .5)`, default `#f2cf6b`) → buds → sepals

## 15. In the app

`NestZone/Features/Companion/CanopyPainter.swift` is this prototype ported call for call (the model
was checked number for number against `build()` for 3 seeds × 6 species). Where the app differs:

- **One still per state, no motion.** It draws `t = 0` and no wind. The wind is a shear of the cached
  picture about the root. GPU shaders for the wind and a painted finish were tried and removed
  (`../SHADERS.md`).
- **The falling leaf is the scene's.** A still would hang it in mid-air, so the app drops the
  prototype's last `r()` draw (nothing after it, so no tree changes) and `ScenePainter.fallingLeaf`
  lets one fall for real, every seven seconds, from under a clump.
- **Fruit bodies go through Core Graphics.** The two-circle radial gradient has no SwiftUI
  equivalent, and a single-centre fit left a ring. Only the fruit uses `withCGContext`.
- **Cut at the soil.** The scene clips the tree to the soil's surface inside the pot's rim, so roots
  go into the earth.
- **Cherry bloom** — the haze in the middle of green → pink is in both, here and in the app (§6's
  canopy ramp, `HAZE`).
