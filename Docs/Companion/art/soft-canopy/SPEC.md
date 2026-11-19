# Direction A: Soft canopy

> Not the app's tree. Layered gouache (`../gouache/`) was chosen on 20 October 2026. This
> direction is kept for reference, with its finished, verified Swift port in `CanopyPainter.swift`
> beside this file (not compiled into the app). To use it, swap it in for
> `NestZone/Features/Companion/CanopyPainter.swift`; the API is the same.

A household tree drawn from soft, rounded foliage clumps. Each clump has three
tones and a fourth hot highlight, a rim light on the lit edge, and a little leaf
texture. The trunk is chunky and tapered, with a lit side and a shadow side, and
it darkens where the canopy closes over it. Blossoms and fruit sit in small
clusters with a soft glow, and a few single leaves break the silhouette at the
edge. Everything comes from a seed, and the drawing uses nothing but paths,
solid or gradient fills, strokes, transforms and alpha.

- Prototype: `tree.html` (standalone, no dependencies)
- Renders: `renders/` (see the end of this file)
- Light: one light for the whole scene, from the upper left: `L = (-0.5, -0.866)`,
  `LA = atan2(L)` (−120°), `SA = LA + π` (the shadow side, +60°).

## URL parameters

| param | default | meaning |
|---|---|---|
| `species` | `magnolia` | `magnolia` `cherry` `pomegranate` `azalea` `lemon` `olive` |
| `seed` | `home_k7f3x9` | household id → FNV-1a → mulberry32 |
| `growth` | `.97` | 0..1: seed → sprout → sapling → young tree → tree → in bloom |
| `mood` | `.9` | 1 bright, .62 content, .3 thirsty, .05 dozing |
| `hour` | `13` | 0–24, mapped to `day` by `dayness(h)` (1 at noon, 0 at night), the same function as plant.html |
| `t` | (live loop) | time in seconds. When present, draws one still frame at `t` and stops (this is how renders are made) |
| `wind` | `.6` | 0..1 sway strength (0 = rest pose) |
| `ops` | off | `ops=1` prints draw calls and path segments for the frame |
| `sheet` | – | `species`, `night`, `moods`, `growth`, `seeds`: a grid of 520×360 cells |
| `audit` | – | `audit=1` sweeps species × 4 seeds × 8 stages × 6 moods × day/night × 3 moments, prints the maximum calls |
| `pot` | off | `pot=1` shows a placeholder pot for context only. **The tree never draws a pot.** The scene owns it |
| `bg` | auto | `none` skips the stand-in sky |
| `zoom`, `fx`, `fy` | – | close-up for inspection |

Canvas: 520×360 CSS px, backing store ×devicePixelRatio. The tree's origin is
the trunk base at (260, 282), the soil level. Up is −y. `M.fit` scales the
whole tree once (≤ 232 tall, ≤ 196 either side) with a single `scale(fit)`.

## Data model: what the seed decides (`build(seed, species)`)

`r = rng(hash(seed))`, exactly as in plant.html. `U(a,b) = a + (b−a)·r()`,
`I(a,b) = a + floor(r()·(b−a+1))`. **The Swift port must call `r()` in the
same order.** The order is the source order of `build()`; port it line by line.
Inside one statement the calls go left to right. The sequence is:

1. **Trunk.** `lean=(r()−.5)·S.lean`, `hj=U(.94,1.06)`, `wj=U(.92,1.08)`,
   `bend=(r()−.5)·2·S.trunkCurve`. The trunk top is
   `T = (sin lean·H, −cos lean·H)` with `H = trunkH·hj`. The control point is
   `tc = T/2 + (cos lean, sin lean)·bend·H` (one quadratic).
2. **Canopy envelope.** `C = (T.x·1.3 + U(−6,6), −cy·hj)`, `cw = canopy.cw·wj`,
   `ch = canopy.ch·hj`.
3. **Clumps.** These come in three groups, generated in this order:
   - **Ring** (tier 1, makes the silhouette). Its count is `I(ring.n)`. For each one:
     `u=(k+.5+(r()−.5)·.5)/n`, angle `a=lerp(arc0,arc1,u)`,
     `rad=ring.rad·U(.92,1.06)`, `R=U(ring.r)`, `keep=.25+r()·.75`, and the position is
     `C + (cos a·cw·rad, sin a·ch·rad)`.
   - **Back** (tier 0). Its count is `I(back.n)`. For each one: `u=(k+.5+(r()−.5)·.6)/n`,
     `a=lerp(arc0+.25, arc1−.25, u)`, `rad=back.rad·U(.8,1.2)`, `R=U(back.r)`,
     `keep=r()·.8`, and the position is `C + (cos a·cw·rad, sin a·ch·rad − ch·.12)`.
   - **Front** (tier 2). Its count is `I(front.n)`. For each one: `u=(k+.5+(r()−.5)·.5)/n`,
     `y=C.y+ch·U(front.y)`, `R=U(front.r)`, `keep=1+r()`, and
     `x = C.x + (u−.5)·cw·front.spread`.
   - **Each clump** (`addClump`): `nb=I(lobes)` bumps. Lobe 0 is the core at
     `(0, .14)`, r `.74`. The bumps sit on the top arc 195°–345°:
     `u=(j+.5+(r()−.5)·.4)/nb`, `a=lerp(3.40, 6.02, u)`, `d=U(.4,.5)`,
     `r=U(.46,.58)`, at `(cos a·d, sin a·d)`. All units are fractions of `R`.
     Then the **leaf marks**: each lobe gets 2 (the core gets 3), with
     `a=U(.25,2.9)`, `d=U(.38,.72)·lobe.r`, angle `a+π/2+U(−.5,.5)` and size
     `U(.13,.19)`. Then the **gloss lobe** is chosen with no randomness: the bump
     with the largest `x·LX+y·LY`. Last come `rot=(r()−.5)·.4`,
     `sq=squash·U(.94,1.06)`, spring `w0=U(1.7,2.6)` and `ph=r()·TAU`.
   - The **crown** is the highest ring clump. Its `keep` is set to 2, so it is never lost to sleep.
4. **Limbs.** Sort the clumps by `atan2` from T. This step uses no `r()`. Split
   them into `S.limbs` contiguous groups. A limb ends at `T + (centroid−T)·reach`
   and bends by `(r()−.5)·.35`. Its spring is `U(1.5,2.1)`. Each member clump
   gets a twig bend `(r()−.5)·.25`, in member order.
5. **Births.** Rank the clumps by distance from the crown and set
   `b = .24 + .58·rank/(n−1)`. A limb's birth is `max(.17, min(member b) − .13)`,
   with duration `.12`. A twig grows over `[b−.07, b+.01]`, and the clump pops
   over `[b, b+.07]` (`back` easing, 1.9 overshoot).
6. **Edge leaves.** Only ring clumps get them. The count is `I(edge.n)`. The angle is the
   outward direction from C `+(r()−.5)·edge.spread`, clamped so that
   `sin a ≤ .35` (never pointing down). Then `d=U(.82,.92)`, `len=U(edge.len)`,
   `w=edge.w·U(.85,1.15)`, `ph=r()·TAU`, `f=U(5,8)`, `keep=r()` and
   `birth=b+.03+r()·.04`.
7. **Blossom clusters and fruit**, per clump. Clusters:
   `n=floor(bloom.clusters·R/27·(back? .6:1)·U(.6,1.4)+r())`. Each cluster has
   `a=U(−2.95,.25)`, `rho=U(.3,.82)` and `nf=I(bloom.per)`. Each flower has
   `fa=r()·TAU`, `fd=nf>1?U(.6,1):0`, `size=U(bloom.size)`, `rt=r()·TAU` and
   `birth=.86+r()·.08`. Fruit only grows on tier ≥ 1:
   `n=floor(fruit.per·R/27+r())`. Each fruit has `a=U(.35,2.8)`, `rho=U(.62,.9)`,
   `size`, `stem=fruit.stem·U(.8,1.2)`, `ph`, `birth=.9+r()·.06` and
   `k=I(fruit.cluster)`.
8. **Glows.** `cluster.glow = r() < min(1, 12/totalClusters)`, so about 12 per tree.
9. **Fallen leaves.** There are 14, on the soil: `x=U(−38,38)`, `y=U(−3.5,2.5)`,
   `rot=r()·TAU`, `s=U(4.4,5.6)` and `tone=r()`.
10. **Bark marks.** There are 4 (`lines`), 6 (`bands`) or 7 (`gnarl`), in trunk space
   `(t along, u across, −.5..+.5)`.
11. **Twinkles.** There are 6: `a=−π·(.08+.84·(i+U(.15,.85))/6)`, `d=U(.92,1.12)`,
    `s=U(2.2,3.4)`, `w=U(1.6,2.8)`, `ph`.
12. **Knots.** `S.knots` of them, spread up the trunk and alternating sides.

Then come the deterministic derived data, which use no `r()`. The port can
compute these once per tree and store them.

- **Depth layers.** The back clumps are layer 0. Sort the rest by
  `tier·1000 + y` (the ring top-down first, then the front clumps). A clump's
  layer is `1 + max(layer)` of every earlier clump it overlaps
  (`dist < (R1+R2)·.8`), capped at 5. No two overlapping clumps share a
  layer, so painter's order between them is exact while each layer is still one
  batch.
- **Rim arcs.** For each lobe, sample its lit edge `LA ± 1.15` at 19 points.
  Keep the longest run whose points are not inside any other lobe of any clump,
  or nothing if the run is shorter than .45 rad. The angles are stored relative
  to the clump's rotation.
- **Occlusion.** A blossom cluster, fruit or edge leaf is `hidden` if, at rest,
  a clump on a higher layer covers it. These parts are drawn once after all
  layers, so this check is what keeps them from showing through.
- **Fit and box.** `fit = min(1, 232/top, 196/maxSide)`. `box` holds the canopy
  top, bottom, centre and radius; the gradients are laid out on it.

## Drawing order and batching (one frame, `drawTree`)

Every shape of one colour goes into one path and is filled once. Each item
below is one fill or stroke call; empty batches are skipped. Everything below
is inside `translate(base) · scale(fit)` except the fallen leaves, which are
drawn unscaled before the `scale(fit)`.

| # | what | calls | paint |
|---|---|---|---|
| 0 | fallen leaves on the soil (mood) | 2 | two straw tones |
| 1 | halo behind the crown | 1 | radial gradient |
| 2 | seed (growth < .125) | 2 | solid |
| 3 | twigs to back clumps (hidden behind them) | 1 | wood shadow |
| 4 | **layer 0** (back) | 8 | see the layer recipe below, plus an AO refill of its body |
| 5 | wood: contact shadow, base, shadow strip, light strip, bark marks, knots, AO refill | 7 | radial · solid ×3 · stroke · solid · linear |
| 6 | **layers 1…n** (n ≤ 5) | 7 each | layer recipe |
| 7 | blossoms: ≤ 12 glows, dark petals, light petals, centres, buds ×2 | ≤ 17 | radial / solid |
| 8 | fruit: stems, body, shadow, light, crown/nub, spec | 6 | stroke + solid |
| 9 | edge leaves: dark halves, lit halves, midribs | 3 | solid + stroke |
| 10 | twinkles (bright only) | 1 | solid |
| 11 | sprout cotyledons (growth .1–.33) | 2 | solid |

**The layer recipe** is an offset stack. For every lobe of every clump in the
layer:

- **shadow:** the lobe circle at full size. Filled with a vertical linear
  gradient (top `mix(shadow, body, .45)` → bottom `shadow`).
- **body:** the same circle moved `.13r` toward the light, radius `.88r`. This
  leaves a shadow crescent on the far side. Filled with a vertical linear
  gradient `mix(body, light, .25)` → `body` (.55) → `mix(body, shadow, .35)`.
  On layer 0 the body path is filled a second time with a radial AO gradient
  centred between the trunk top and the canopy bottom.
- **marks:** small almond ellipses (leaf texture). Dark (`mix(body, shadow, .6)`
  at α .5), or silvery for olive (`mix(light, rim, .4)` at α .55).
- **light caps:** on bumps with `y < .05`, a circle moved `.33r` toward the
  light, radius `.56r`. Filled with a radial gradient centred up-left of the
  canopy (`box.c + L·.8·box.r`, radius `1.9·box.r`):
  `mix(light, rim, .22)` → `mix(light, body, .55)`.
- **hot:** on bumps with `y < −.12`, a circle `.47r` toward the light, radius
  `.3r`. Colour `mix(light, rim, .45)`, α `.18 + .42·vig`.
- **rim:** a stroke of the precomputed arcs at radius `.955r`, width 1.4, round
  caps. Colour `rim` at α .7, pulled toward `(205,214,255)` by `.75·night`.
- **gloss:** one ellipse per clump on its gloss lobe, at `.5r` toward the light,
  `.2r × .085r`, along the tangent. White, α
  `S.gloss·(.12+.8·vig)·(1−.85·dry)·(1−.5·night)`.

Layer colours: layer 0 uses the tier-0 tones (L ×.86, hue 8% toward 200°).
The last layer uses tier 2 (L ×1.035). Layers in between are darkened by
`6%·(1−depth)`. Distant clumps sit back and the front ones pop.

**Wood.** Each segment is a tapered quadratic limb with round ends (`limb()`).
The **shadow strip** is the same limb moved `−.21·w` across itself, away from
the light, at `.56` of the width. The **light strip** is moved `+.3·w`, at
`.16` of the width. Limb strips start at `t = .22`, so they never cross at the
fork. Which side is lit is decided per segment: the normal whose dot product
with `L` is positive. The AO is the wood base path filled again with a vertical
linear gradient: dark at the canopy bottom, clear about 38 pt below the trunk
top. Olive uses two crossing trunks (`twin`).

**Flowers**, by type. Petals are `petal()`, two cubics from the base.
- `cup` (magnolia): two outer petals at ±.42 rad (dark), one centre petal
  (light), and a deep blush ellipse at the base (`mid`). They stay upright and
  tilt ±.25.
- `star5` / `star4`: n petals (dark). The light petals are the same petals at
  .76 size, moved .14·s toward the light. The centre is a dot.
- `trumpet` (pomegranate): a tube (dark), three flared petals (light) and a
  stamen dot.
- Bud: a teardrop (bud dark) plus a smaller one moved toward the light (bud light).

**Fruit.** A stem, then the body (`pom` circle, `lemon` ellipse plus a nub,
`olive` ellipse), a shadow crescent (`SA ± 1.3`), a light ellipse toward `L`,
and a spec dot. A pomegranate also gets a 3-point crown opposite the stem.

### What the Swift port must know

- **Winding.** Every filled subpath is traced clockwise on screen (increasing
  canvas angle), so shapes overlapping in one batch union under non-zero fill.
  `ell()` is four cubics, `circ()` is `move(to:)` plus a full arc, `petal()`
  goes out on the −n side and back on +n, and `limb()` goes up the left side and
  down the right with clockwise end arcs. `leafHalf()` reverses the traversal for
  side +1 for the same reason. Keep these exactly, or overlapping shapes punch
  holes.
- **Arcs.** Always `move(to:)` the arc's start before `addArc`. Canvas `arc`
  joins with a line from the current point, so an unmatched start draws a
  stray line. Canvas `arc(x,y,r,a0,a1,false)` maps to SwiftUI
  `addArc(center:radius:startAngle:endAngle:clockwise: false)` on a y-down
  Canvas. Check this once: the flags are mirrored in some UIKit APIs.
- No clipping, no blur, no filters, no shadows and no image patterns are used.
  The only gradients are `createLinearGradient` / `createRadialGradient` with
  2–3 stops (`.linearGradient` / `.radialGradient` shading). Two gradients are
  drawn under a transform (the AO ellipse and the contact shadow use
  `translate + scale(1, k)`). In SwiftUI, apply the same transform to a copy of
  the context; the gradient is transformed with it, as in canvas.
- `ellipse()` is never called; ellipses are cubics. `roundRect` and `fillRect`
  appear only in the stand-in sky and pot, which are not part of the tree.
- Colour maths: `hex → rgb`, `mixc` in sRGB, HSL for the mood saturation and
  lightness, then `night(c, n)` multiplies by `lerp(1, MOON, n)` with
  `MOON = (.62, .67, .92)`. Blossoms and glows use `n·.75` / `n·.5`, so they
  glow at night. There are about 40 distinct colours per frame; cache them by
  `(mood, day)` if needed.
- `wrap(a)` is the shortest angle. `rot(x,y,a)` is the standard rotation with y down.
- **Caching under the new brief.** Draw the picture once per state change. Use
  `wind: 0`, and a fixed `t` such as 0, so the idle bob and the twinkle phase
  are stable. Hand the result to the GPU sway/rustle shader. The twinkles
  depend on time; either freeze them in the picture or draw them in an overlay.

## Per-species parameters

`leaf = [shadow, body, light, rim]`, `wood = [base, shadow, light]`,
`bloom.cols = [dark, light, centre/blush]`, `bud = [dark, light]`,
`fruit.cols = [body, shadow, light, spec, crown/nub]`.

| | magnolia | cherry | pomegranate | azalea | lemon | olive |
|---|---|---|---|---|---|---|
| trunkH, trunkW | 58, [29,16] | 68, [27,14] | 50, [25,15] | 24, [21,14] | 68, [25,15] | 64, [33,16] twin |
| canopy cy/cw/ch | 145/80/70 | 138/112/50 | 136/92/62 | 104/110/62 | 146/84/70 | 140/118/48 |
| ring arc | 150–390° | 168–372° | 155–385° | 160–380° | 130–410° | 168–372° |
| ring n / R / rad | 6–7 / 28–34 / .74 | 7–8 / 24–30 / .8 | 6–7 / 27–33 / .76 | 7–8 / 28–34 / .74 | 7–8 / 27–32 / .74 | 7–8 / 23–28 / .82 |
| back n / R | 2 / 28–32 | 2–3 / 24–28 | 2 / 26–30 | 3 / 28–32 | 2–3 / 27–31 | 2 / 22–26 |
| front n / R | 2–3 / 30–36 | 3–4 / 25–30 | 2–3 / 28–34 | 3–4 / 30–35 | 3 / 29–34 | 2–3 / 24–29 |
| limbs, squash | 3, .92 | 4, .84 | 3, .9 | 4, .88 | 3, .95 | 4, .74 |
| leaf | `#2A5956 #4A8D60 #8FC478 #E6F6BF` | `#2E5D51 #5A9B63 #A3D185 #EAF7C6` | `#143A33 #255B42 #3F7E4B #C6E79A` | `#22503F #3D7A4E #76AF67 #DDF1B2` | `#2A6844 #4E9F4D #A5D86A #F1FAC3` | `#485F51 #7B927D #B9C8B2 #EFF4E7` |
| canopy in bloom | – | ×.9 toward `#C98AAE #F3BCD2 #FFE4EE #FFF7FA` | – | – | – | – |
| wood | `#7D6159 #573F3B #AB8C7F` | `#6C4846 #4A302F #956B65` (bands) | `#6F574C #4C3A33 #977D70` | `#6A4F45 #4A3730 #937466` | `#7C6A57 #594B3E #A6927B` | `#827569 #5B5149 #AB9F92` (gnarl, 3 knots) |
| flower | cup 9–11.5 | star5 3.8–4.8, pw .62 | trumpet 7–8.5 | star5 5.5–7, pw .72 | star5 3.6–4.4, pw .42 | star4 2.6–3.2 |
| bloom.cols | `#D2689A #FBD3E2 #C04F84` | `#F2A6C4 #FFF0F5 #E07592` | `#B92D1E #F35B33 #FFD25A` | `#B32B7F #F25AAE #FFE3F2` | `#E8DDBF #FFFCF1 #F1C84A` | `#DCD5B2 #F6F2DC #E1CF74` |
| glow / bud | `#FFB0CF` / `#7F8C78 #B9C1AA` (grey, furry) | `#FFC4DA` / `#D9739B #F2A9C4` | `#FF8E62` / `#B83424 #E8603E` | `#FF7BC2` / `#A62E78 #E0629F` | `#FFF4C2` / `#C7A3BE #EBD3E3` (purple-tinged) | `#FFF9DA` / `#B9B79A #DCDBC4` |
| clusters, per | .75, 1–2 | 1.4, 2–4 | .55, 1–2 | 1.5, 2–4 | .6, 2–3 | .5, 2–3 |
| fruit | – | – | pom 6.5–8, per .5: `#C42A3D #861A2D #F2696D #FFE0E0 #7A1424` | – | lemon 7–8.5, per .5: `#F6CF35 #D79F1E #FFF08C #FFFFFF #B98F1A` | olive 3–3.6 ×2–3, per .9: `#3F2C46 #24182B #6F5578 #EADFEE` |
| edge leaves n / len / w | 1–2 / 6.5–8 / 1 | 1–2 / 5.5–7 / 1 (stay green in bloom) | 1–2 / 6–7.5 / .85 | 1 / 5–6 / .9 | 1–2 / 6–7.5 / .85 | 2–3 / 7.5–9 / .42, `#6E8672` top `#D0DACB` silver underside |
| gloss | .45 | .25 | .9 | .35 | .65 | .2 (silvery marks) |

Shared values: dry (straw) `#655C36 #A39249 #D6C37A #F3E7B0`, dry wood
`#8C7D6E`, sprout stem `#4E8F4A #3A6E3E #8CC56E`, seed `#8A5A3A` and
`#D2A27A`, fallen leaves `#9A7A3E` and `#CDAE62`.

## Mood mapping (exact)

```
vig   = smooth((m − .62) / .38)      bright 1, content 0
dry   = smooth((.66 − m) / .56)      content .015, thirsty .71, dozing 1
sleep = smooth((.32 − m) / .27)      thirsty .016, dozing 1
slump = dry + .6·sleep
open  = smooth((m − .22) / .40)      flowers open; thirsty .10, so buds
```

- **Leaf colour**, per tone i:
  - Start from `c = leaf[i]`, mixed toward the bloom canopy (cherry).
  - `c = mix(c, DRY[i], .9·dry)` takes it olive at thirsty and straw at dozing.
  - Then, in HSL, `s ×= (1+.34·vig)·(1−.1·(1−vig)·(1−dry))·(1−.5·sleep)`: bright
    is more saturated, content a touch calmer, dozing pale.
  - `l += (.035 for light and rim, .012 otherwise)·vig`.
  - Light and rim also shift hue: `h −= 7·vig` (a warmer, yellower light).
  - `l = lerp(l, .8, .3·sleep)` (paler).
- **Size and shape.** Clump radius `×(1 + .1·vig − .13·dry − .09·sleep)`
  (plump or shrunken). Squash `×(1 + .05·vig − .07·dry)`.
- **Posture.**
  - The trunk leans `leanSign·.07·slump`.
  - Each limb rotates `side·(.2·slump − .1·vig)` (out and down when thirsty, up when bright).
  - Each twig rotates a further `side·.12·slump`.
  - Each clump drops `(5·slump·R/27 − 4·vig)·sz` and moves out `2·side·slump·sz`.
- **Sparse (dozing).** `vis = smooth((keep − .55·sleep)/.08 + 1)`, snapped to 0
  below .45. Back clumps go first, then about 40% of the ring. The crown and
  front clumps never go. Their twigs stay as bare branches.
- **Flowers.** Open flowers scale `.35 + .65·open` (drawn while `open > .12`).
  Buds scale `1 − open` (drawn while `open < .6`) and hang toward the ground by
  `(π−.4)·(.5·dry + .3·sleep)`. Bloom saturation is `×(1−.35·dry)(1+.1·vig)`.
  Glow α is `(.22+.18·night)·open·(1−.5·sleep)`.
- **Fruit.** Saturation `×(1−.45·dry)`. Size `×(1−.12·dry)`. Shine `(.55+.45·vig)(1−.6·dry)`.
- **Edge leaves.** Visible while `keep > .35·dry + .4·sleep`. They swing toward
  hanging by `.45·dry + .35·sleep`. Size `×(1 + .05·vig − .12·dry)`.
- **Fallen leaves.** `round(14·clamp((.55·dry + .45·sleep − .12)/.88))` lie on
  the soil: about 4 when thirsty, all 14 when dozing.
- **Wood.** Mixed 25% toward dry wood by `dry`. Paler and less saturated by `sleep`.
- **Bright only.** The gloss rises to full. The halo α goes `.1 → .24`. Six
  twinkles appear around the crown.

How it reads:

- **Bright:** vivid, warm-lit, plump and lifted, with glossy spots, twinkles and
  a warm halo.
- **Content:** the same tree, calmer and cooler.
- **Thirsty:** olive canopy, clumps shrunk and hanging outward, flowers closed
  to buds, a few leaves on the soil.
- **Dozing:** pale straw, a third of the canopy gone (bare twigs show), drooping,
  and the soil covered in leaves.

## Growth

```
sz   = lerp(.36, 1, smooth((g−.1)/.74))         overall size
spr  = sz·lerp(.45, 1, smooth((g−.25)/.45))     how far limbs and twigs reach (a young crown is compact)
szR  = sz^.6                                    clump radius scale (young clumps relatively bigger: cute)
tg   = ease((g−.085)/.16)·lerp(.42, 1, smooth((g−.12)/.7))     trunk length
wf   = lerp(.22, 1, smooth((g−.1)/.8))          trunk width
```

| stage | growth | what shows |
|---|---|---|
| seed | 0–.085 | a seed that wobbles, then cracks (scales out over .085–.125) |
| sprout | ~.1–.3 | a green stem with two seed leaves (`back` pop at .1, fall away from .27) |
| sapling | ~.25–.5 | the stem turns to bark (.18–.34). The crown clump pops at .24, the next ones follow outward from it |
| young tree, tree | .5–.84 | limbs extend; clumps pop with overshoot until .82 |
| in bloom | .86–.97 | flowers pop at .86–.94. The cherry canopy blushes pink (`bloomIn = smooth((g−.84)/.1)`). Fruit arrives at .9–.96 |

## Motion model (prototype only; the app will use the GPU shader)

Everything is stateless, so a frame is a pure function of `t`. The gust is
`G(t) = Σ aₖ sin(ωₖt + pₖ)` with `(a, ω, p) = (1, .7, 0), (.5, 1.9, 1), (.8, .23, 2)`.
A part with a spring of natural rate ω₀ and damping ζ answers with its exact
steady-state response. Each sine is scaled by `A = 1/√((1−r²)² + (2ζr)²)` and
delayed by `φ = atan2(2ζr, 1−r²)`, with `r = ω/ω₀`. The result is
`sig = .45 + .55·Σ/2.3`; the .45 is a steady lean with the wind.

- Trunk (ω₀ 1.3, ζ .6): `θ = wind·.03·sig·(1.4−.4g)`. It rotates about the
  base, and its control point rotates half as much, so the trunk bends rather
  than tilting.
- Limb (ω₀ 1.5–2.1, ζ .45): `+wind·.05·sig`, about the trunk top. Twigs and
  clumps ride on their limb.
- Clump (ω₀ 1.7–2.6, ζ .3, springy):
  - Sideways offset `wind·3·sig·R/27`.
  - Idle bob `.55·sin(ω₀t+φ)·(.4+.6·wind)`.
  - Tilt `offset·.012`.
  - The clump moves as a unit, with its blossoms and fruit.
- Fruit swings like a pendulum: `−2θ_trunk + (.1+.1·wind)·sin((1.6+.3q)t + φ)`.
- Edge leaves flutter: `(.05 + .2·wind·G)·sin(f·t + φ)`, `f = 5–8`.
- Flowers turn slightly: `.08·wind·sin(.8t + rt)`.

## Measured draw calls (fill + stroke per frame, tree only)

Measured with `audit=1`: 6 species × 4 seeds × 8 growth stages × 6 moods × day/night × 3 moments.

| species | worst frame | typical in bloom, mood .9, day | path segments (worst) |
|---|---|---|---|
| magnolia | 64 | 63 | 1636 |
| cherry | 71 | 69 | 2925 |
| pomegranate | 69 | 68 | 1692 |
| azalea | 70 | 69 | 3126 |
| lemon | **72** | 71 | 2280 |
| olive | 68 | 68 | 2257 |

The maximum is **72 calls**, within the original 120 and far inside the new ~300.
Growth stages are cheaper: seed 2, sprout 6, sapling about 26, young tree about 39.
The count is bounded by construction: at most 6 layers × 7, plus 12 glows, plus
a fixed number of other batches. Path complexity is about 1.1k–3.1k segments.

## What could get richer under the new ~300-call budget

1. **Per-clump light gradients.** Fill each clump's light cap with its own
   radial gradient, so each lump gets its own soft falloff instead of the
   canopy-wide one. That costs about 14 calls and gives the biggest gain in form.
2. **Inner occlusion.** Add a soft dark radial gradient wherever a clump tucks
   under the one in front of it, one per front clump (about 10 calls). The
   layer stack already gives a hard crescent; this adds the soft one.
3. **More layers.** Raise `MAXL` from 5 to 8, so overlapping ring clumps never
   share a batch (about 21 calls).
4. **Bounce light.** Add a faint warm or cool stroke along the bottom edge of
   each layer, reflected light from the ground or sky (6 calls).
5. **Glow on every blossom cluster** instead of 12, and a two-stop glow with a
   brighter core (about 30–40 calls).
6. **Bark.** Give the trunk base its own linear gradient across its width, and
   add more knots, root flare detail and a moss tint for olive (about 4 calls).
7. **Petals.** Draw each petal with its own two-tone gradient, a vein stroke
   for magnolia and pomegranate, and stamen dots (about 6 calls).
8. **Twinkles.** If the cached picture should keep them, bake 2–3 phases.
   Otherwise move them to the shader overlay.

## Renders

Kept in the repository (as JPEG):

- `renders/1_species_day.jpg`: all six species, growth .97, mood .9, by day
- `renders/2_moods_magnolia.jpg`: bright, content, thirsty, dozing
- `renders/3_growth_lemon.jpg`: seed, sprout, sapling, young tree, tree, in bloom
- `renders/5_species_night.jpg`: all six at night
- `renders/7_seeds_olive.jpg`: six household seeds of one species (variation)

Any other still can be made from `tree.html` with the URL parameters above.
