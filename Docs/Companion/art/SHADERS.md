# Nestie shaders — how to wire them

> **Not in the app.** They were built and wired on 20 October 2026, then removed the same day. With
> both passes on, Today ran at about 25 frames a second on the simulator: the main thread waited on the
> GPU every frame, and scrolling past the card stuttered. A shear transform does the wind now, and the
> painted finish was dropped. The source is in `shaders/CompanionShaders.metal`. It would need a
> device measurement (`-frameMeter 1`) before coming back in any form.

File: `NestZone/Features/Companion/CompanionShaders.metal` (compiled into the app's
`default.metallib` by the synchronized group; reach it with `ShaderLibrary.default`).
It exports exactly three symbols, `nestieSway`, `nestiePaint` and `nestieTwinkle`.
The helpers are `static` in `namespace nestie`, so they never collide with another `.metal` file.

All coordinates are in the **modified view's own points** (origin top-left, y down).
For the tree layer that is the card: `scale = size.height / SceneSpace.height`,
`root = (size.width / 2, SceneSpace.soil * scale)`, and the crown box is the existing
scene-unit crown rect times `scale`.

---

## 1. `nestieSway`: distortion (wind, gusts, tap, rustle)

```metal
[[ stitchable ]] float2 nestieSway(float2 position, float time, float wind, float2 root,
                                   float4 crown, float wobble, float droop)
```

| uniform | units | meaning | recommended |
|---|---|---|---|
| `time` | s | clock, **wrapped to 0…600 on the CPU**. Every frequency is a whole number of cycles per 600 s, so the wrap is seamless (checked: dx(0) − dx(600) = 0.0) | `date.timeIntervalSince(epoch).truncatingRemainder(dividingBy: 600)` |
| `wind` | 0…1 | overall wind | `0.6` (the canvas default). `0` under Reduce Motion. Optional: `min(1, 0.6 * (1.5 - 0.6 * progress) / 0.92)` keeps the canvas's "young plants sway more" |
| `root` | pt, float2 | where the trunk meets the soil. At or below `root.y` the position comes back **unchanged, bit for bit** | `CGPoint(x: size.width / 2, y: SceneSpace.soil * scale)` |
| `crown` | pt, float4 (x, y, w, h) | canopy box. `root.y - crown.y` is the tree's **height**, and every amplitude is a fraction of it. The ellipse inscribed in it is where leaves rustle | the existing crown rect × `scale`: `(center + left - 10, soil + top - 10, right - left + 20, max(-top * 0.75, 40))` |
| `wobble` | fraction of height (≈ rad), signed, + = right | the tap's lean, added to the bend | `motion.wobble * 0.75` (your `Ink.settle(…, amplitude: 0.22, frequency: 7.3, damping: 2.5)`; peaks near 0.10 → about 12 pt at the crown's top, the canvas's old tap reach). Never above 0.165 |
| `droop` | 0…1 | 0 cared for, 1 wilted. Crossfades to a slower, lazier sway set, more top-lag, ¼ of the rustle, slightly weaker gusts. **It does not rescale time**, so easing it never jumps the phase | `Ink.smooth((0.66 - mood) / 0.56)`, the canopy's own dryness |

What it does: bend = `height · b(h) · (wind · (sway + gust) + wobble)`. Here `h` is the height above the root over the tree's height, and `b(h) = h²` up to the crown's top (cantilever-like), easing flat (C¹) over the next 0.4 height. A small arc drop `0.4·dx²/(h·height)` keeps the crown from shearing. Gusts are the canvas's three sines, eased with a smoothstep, and they only ever push right (+x), as before. The top trails the base by a phase lag that grows when droopy. The rustle is two drifting layers of quintic gradient noise (12 pt and 7 pt cells), ≤ 1.3 pt × wind, only inside the crown ellipse and above 35–60 % of the height. It is read in the bent frame, so it stays on the crown.

### maxSampleOffset

```
lean = wind · 0.095 + |wobble|        // 0.095 = swayReach·1.25 + gustReach
dx ≤ 1.4 · height · lean + 1.3 · wind // 1.4 = bend ceiling (1 + overhang), 1.3 = rustle
dy ≤ 0.6 · height · lean² + 1.3 · wind
```

Use the **largest** wobble (0.165), not the current one, so the offset is constant per tree and does not resize the offscreen every frame:

```swift
func swayReach(root: CGPoint, crown: CGRect, wind: Double, maxWobble: Double = 0.165) -> CGSize {
    let height = root.y - crown.minY
    let lean = wind * 0.095 + maxWobble
    return CGSize(width: 1.4 * height * lean + 1.3 * wind, height: 0.6 * height * lean * lean + 1.3 * wind)
}
```

For the bench tree (card 361×236 pt, height ≈ 120 pt), at wind 0.6 and wobble 0.165 this gives ≈ (38.1 pt, 4.3 pt).

### Measured (CPU reference of the same math, plus GPU renders)
- Crown top, no tap: max |dx| **6.1 pt at wind 0.6**, 8.5 pt at wind 1. That is about what the per-branch canvas sway gave.
- Worst case, wind 1 with wobble ±0.15, 10 minutes of clock: |dx| 36.9 pt and dy 3.4 pt. The formula gives 41.2 and 4.3 (bend parts), so it holds.
- Fold check: minimum Jacobian determinant of the full mapping, rustle included, over a 0.7 pt grid × 240 times × droop 0/1 = **0.59**. It stays well above 0, so nothing tears or duplicates. Rustle ≤ 1.29 pt.
- Pot/soil: GPU renders at 18 moments (wind 1, wobble ±0.15, droop 0/½/1) against a still frame. **0 differing pixels** at and below the root row.

---

## 2. `nestiePaint`: layer effect (painted finish)

```metal
[[ stitchable ]] half4 nestiePaint(float2 position, SwiftUI::Layer layer, float4 crown, float strength)
```

| uniform | units | meaning | recommended |
|---|---|---|---|
| `crown` | pt, float4 | same box as the sway: where the warm/cool light falls | same value you pass to the sway |
| `strength` | 0…1 | 0 = untouched (early return), 1 = tuned look | `1`. It also works in `still` portraits, since ImageRenderer applies it |

What it does, all scaled by `strength`:
- A darker, slightly uneven rim inside the silhouette. It is darker still on edges facing away from a top-left light, with a faint warm glint on edges facing it, which gives the trunk roundness.
- Shapes thinner than the 1.25 pt probe (bulbs, twigs, wire) are left alone.
- A contact shadow on the darker side of colour boundaries (leaf under leaf).
- A warm top-left / cool bottom-right tint across the crown ellipse (≤ 4–6 %).
- Paper grain (0.55 pt + 1.3 pt value noise) plus a 9 pt mottle, applied as pigment density (Bousseau: `C -= C(1−C)·d`). This touches midtones only; white and black stay.

The grain is a function of `position` only, so it is stable, never animated.

Premultiplied alpha: the colour is un-premultiplied (only when a ≥ 0.004), tinted, clamped to `[0, max(1, original)]` and re-premultiplied. **Alpha is returned unchanged.**

`maxSampleOffset: CGSize(width: 1.25, height: 1.25)` (the probe radius).
**Samples: 5 per pixel** (centre + 4 at 1.25 pt). Transparent pixels cost 1 sample and an early return.

---

## 3. `nestieTwinkle`: color effect (optional)

```metal
[[ stitchable ]] half4 nestieTwinkle(float2 position, half4 colour, float time, float amount)
```

`time` is wrapped like the sway's. `amount` 0…1 (1 dips a glow to 60 %; 0 under Reduce Motion; e.g. `1 - day` while lights are out).

Why it is here: the cached tree freezes the fairy-light and star glows. Today `TreeState.twinkle` redraws the tree 4×/s at night for that. Put **only the night glows** (and the bulbs, if you like) in their own small cached Canvas, and apply `.colorEffect(twinkle)`. Then put it in the same ZStack as the tree, *inside* the sway, so it moves with the branches. That lets the tree stop redrawing for twinkle.

Limitation: a shader cannot tell bulbs apart. The phase is a smooth field across the layer (one cycle ≈ 18 pt), so neighbouring glows breathe out of step and a string shimmers along its length. It is not fully independent per bulb. Do not apply it to the whole tree layer, or it dims leaves too. Zero samples, about 60 ALU ops.

---

## The exact SwiftUI wiring

`Shader` arguments are positional and follow the implicit ones: `position` for all three, `layer` for layerEffect, `colour` for colorEffect. Order in Swift = order in the `.metal` signature after those.

```swift
let box = Shader.Argument.float4(crown.minX, crown.minY, crown.width, crown.height)
let t = date.timeIntervalSince(epoch).truncatingRemainder(dividingBy: 600)
let wind = reduceMotion ? 0.0 : 0.6

TreeLayer(canopy: canopy, state: snapshot.treeState(at: date))   // own Equatable view — see gotcha 1
    .equatable()
    // 1. Paint first (inner), so the grain and rims ride on the leaves.
    .layerEffect(
        ShaderLibrary.default.nestiePaint(box, .float(1)),
        maxSampleOffset: CGSize(width: 1.25, height: 1.25)
    )
    // 2. Then the wind (outer).
    .distortionEffect(
        ShaderLibrary.default.nestieSway(
            .float(t), .float(wind), .float2(root), box,
            .float(motion.wobble * 0.75), .float(droop)
        ),
        maxSampleOffset: swayReach(root: root, crown: crown, wind: 0.6)
    )
    // 3. The landing squash stays a plain transform, outside, anchored at the root.
    .scaleEffect(x: 1 - motion.bounce * 0.35, y: 1 + motion.bounce, anchor: SceneSpace.root)
```

Drop the `.rotationEffect(... wobble ..., anchor: SceneSpace.root)`. It swung the trunk's foot with the crown; the shader's `wobble` bends the tree and leaves the foot still.

Optional glows layer (twinkle) under the same sway: put `TreeLayer` and `GlowLayer().colorEffect(ShaderLibrary.default.nestieTwinkle(.float(t), .float(1 - day)))` in a `ZStack`, and apply the paint to the tree only. Apply the distortion once, to the ZStack.

Precompile at launch or on first appear. It surfaces signature mistakes too, which otherwise only fail at runtime:

```swift
Task {
    try? await ShaderLibrary.default.nestieSway(.float(0), .float(0), .float2(0, 0), .float4(0, 0, 1, 1), .float(0), .float(0)).compile(as: .distortionEffect)
    try? await ShaderLibrary.default.nestiePaint(.float4(0, 0, 1, 1), .float(1)).compile(as: .layerEffect)
}
```

---

## Gotchas found while verifying

1. **The Canvas must live in its own Equatable view, or it redraws anyway.** I counted Canvas renderer calls over 30 driven frames with `NSHostingView`. With the Canvas built inline in the body that reads the clock, the renderer ran 3–4 times on macOS, and on device expect every frame. With the Canvas in a separate `View, Equatable` and `.equatable()`, inside `TimelineView(.animation)`: the timeline ticked 31 times and the renderer ran **once**. Your `TreeLayer` already does this, so keep its inputs value-typed and compare only `state`.
2. **Effects rasterize their subtree offscreen.** With the sway at rest (identity), output differs from no effect by ≤ 2/255 (161k pixels over the card), from the offscreen pass. So:
   - Don't toggle `isEnabled` per frame. Under Reduce Motion, keep it on with `wind: 0, wobble: 0`, or pause the timeline.
   - `.drawingGroup()` inside `TreeLayer` is now a *second* offscreen. Worth measuring with and without it once the effects are on (your "two points cheaper" figure was without effects).
3. **maxSampleOffset matters when content leaves the view's bounds.**
   - Layer = whole card: `.zero` vs. the bound differed in only 5.4k pixels by ≤ 4/255 (resampling), so no visible clipping.
   - A layer framed 100 pt wide around the tree: `.zero` lost ~6k pixels of the leaning crown.
   - Use the formula and keep it constant.
4. **ImageRenderer applies all three effects** (verified on macOS 27: wobble 0.2 shifted the crown by a mean 52/255, and paint changed pixels). The `still` portraits in Choose and the album can share the look.
5. **Coordinates are the modified view's local space.** Attach the effects directly to the card-sized tree layer. If you add `.padding`/`.frame` between, the root and crown move.
   - To read the size without `viewSize` state, use `.visualEffect { content, proxy in content.distortionEffect(...) }`. Its closure is `@Sendable`, so capture plain values.
6. **Time:** pass it wrapped at 600 s. Any other wrap period makes a visible jump. An unwrapped `timeIntervalSinceReferenceDate` loses float precision.
7. **Shaders are looked up by name at runtime.** A typo or a wrong argument count fails only when drawn. `compile(as:)` reports it, e.g. "Function stitching failed: nestieSway … expected 5, received 1".
8. **`layer.sample` is premultiplied, in the layer's working colour space** (per `SwiftUI_Metal.h`). The paint's luma and tints are relative, so they behave the same in sRGB or linear. The output never changes alpha.
9. **Small emissive things against the sky still get a rim:**
   - A bulb bordering a branch on one side and the sky on the other came out ~12 % darker.
   - Bulbs open on both sides are untouched.
   - If bulbs should read as lit, draw them in the glows layer above the paint (still inside the sway).
10. **The tree layer has ink below the root** (the trunk sunk ~7 pt into the soil). It is untouched by construction (`h ≤ 0` returns early).

## Cost per pixel (analytic; not timed on a device)

| effect | samples | ALU (approx.) | where it runs |
|---|---|---|---|
| sway, below root | 1 (SwiftUI's read) | ~5, early return | pot, soil |
| sway, outside crown | 1 | ~60 (7 sines) | trunk, sky |
| sway, inside crown | 1 | ~300 (11 sines, 4 gradient-noise taps) | canopy |
| paint, transparent | 1 | ~3, early return | most of the card |
| paint, ink | 5 bilinear | ~250 (3 value + 1 gradient noise) | tree pixels only |
| twinkle | 0 | ~60 | glows layer |

At 3x the card is ~0.77 Mpx, and the tree covers maybe a quarter of it. Worst case is well under 0.5 GFLOP per frame, i.e. < 15 GFLOP/s at 30 fps, a percent or two of an A15-class GPU. Each effect also costs one offscreen texture pass. None of it is main-thread work.

## Files

- `shaders-contact-sheet.jpg` (beside this file): original, painted, sway trough and gust peak, tap ±0.15, sad and droop, night.
- The shaders themselves: `NestZone/Features/Companion/CompanionShaders.metal`. As wired in the app: `CompanionScene.body` (the paint on `TreeLayer`, the sway on the tree and `DecorLayer` together).
- `nestieTwinkle` (section 3) was not kept. The decorations got a layer of their own instead, outside the paint and under the same wind, which redraws a few bulbs a few times a second after dark.
- The macOS harness these were checked with was a scratch tool and is not in the repository. Its checks: the pot never moves (0 pixels below the root changed over 18 frames), the mapping never folds (smallest local stretch 0.59), the bound holds (worst dx 36.9 of 41.2 pt), and a Canvas in its own `Equatable` view is drawn once while the timeline ticks.
