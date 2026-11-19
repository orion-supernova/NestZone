#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Nestie's motion and finish, on the GPU.
//
// The tree is drawn by a canvas only when something about it changes — the
// mood, the growth, what hangs on it, the light — and these functions move
// and finish that one drawing every frame. A frame used to be hundreds of
// leaf paths built and filled on the main thread; now it is a handful of
// uniforms and a few texture reads per pixel, all of it on the GPU.
//
// Every length is in the layer's own points (the coordinate space of the
// view the effect is attached to, origin top left, y down), never in pixels,
// so the motion and the grain are the same size at 2x and 3x.

// The helpers are `static`, so none of them is exported into the app's
// default library beside the two stitchable functions.
namespace nestie {

/// Every motion here repeats exactly every `loop` seconds, because every
/// frequency is a whole number of cycles per loop. The Swift side passes its
/// clock as `seconds.truncatingRemainder(dividingBy: 600)`: the wrap is
/// invisible, and the float the GPU sees never grows large enough to lose the
/// precision a slow sine needs.
constant float loop = 600.0;
constant float tau = 6.283185307;

/// How far above the crown's top the bend keeps growing, as a fraction of the
/// tree's height. Over that stretch its slope eases to nothing, and past it
/// the bend is flat: whatever the layer holds up there — a star, a glow —
/// moves with the crown without a crease, and the displacement stays bounded.
constant float overhang = 0.4;
/// The slow sway at the crown's top, at full wind, as a fraction of the
/// tree's height.
constant float swayReach = 0.04;
/// How far a gust leans the crown's top, at full wind, as a fraction of the
/// tree's height. Gusts only ever push one way, the way the canvas drew them.
constant float gustReach = 0.045;
/// The leaves' flutter at full wind, in points.
constant float rustleReach = 1.3;

/// A sine that turns a whole number of `cycles` per loop.
static inline float wave(float time, float cycles, float phase) {
    return sin(tau * fract(time * (cycles / loop)) + phase);
}

/// The bend at a height `h` above the root, in tree heights: h² up to the
/// crown's top, the shape of a loaded cantilever, then easing flat over the
/// overhang so its slope never jumps. At most 1 + overhang.
static inline float bend(float h) {
    if (h <= 1.0) { return h * h; }
    float over = min(h - 1.0, overhang);
    return 1.0 + 2.0 * over - over * over / overhang;
}

/// A well-mixed 32-bit hash of a lattice cell, the same on every GPU.
static inline uint hash(int2 cell) {
    uint h = uint(cell.x) * 0x8da6b343u + uint(cell.y) * 0xd8163841u;
    h ^= h >> 16; h *= 0x7feb352du;
    h ^= h >> 15; h *= 0x846ca68bu;
    h ^= h >> 16;
    return h;
}

/// 0…1 from a hash.
static inline float unit(uint h) { return float(h >> 8) * (1.0 / 16777216.0); }

/// A pseudo-random gradient for a lattice corner, each component -1…1.
static inline float2 slope(int2 cell) {
    uint h = hash(cell);
    return float2(float(h & 0xffffu), float(h >> 16)) * (2.0 / 65535.0) - 1.0;
}

/// Smooth value noise, 0…1, one lattice cell per unit of `p`.
static inline float value(float2 p) {
    float2 i = floor(p), f = p - i;
    int2 c = int2(i);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = unit(hash(c)), b = unit(hash(c + int2(1, 0)));
    float d = unit(hash(c + int2(0, 1))), e = unit(hash(c + int2(1, 1)));
    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

/// Gradient noise, roughly -0.7…0.7 and zero on the lattice, with a quintic
/// fade so its slope is continuous too — a displacement with a kinked slope
/// shows the lattice as creases.
static inline float gradient(float2 p) {
    float2 i = floor(p), f = p - i;
    int2 c = int2(i);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = dot(slope(c), f);
    float b = dot(slope(c + int2(1, 0)), f - float2(1, 0));
    float d = dot(slope(c + int2(0, 1)), f - float2(0, 1));
    float e = dot(slope(c + int2(1, 1)), f - float2(1, 1));
    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

static inline float luma(float3 rgb) { return dot(rgb, float3(0.2126, 0.7152, 0.0722)); }

} // namespace nestie

/// The wind in the tree: a distortion that returns, for each pixel, where in
/// the cached drawing to read it from.
///
/// - `time`: seconds, wrapped to 0…600 on the CPU (see `nestie::loop`).
/// - `wind`: 0…1. 0 under Reduce Motion, which stills everything but the
///   tap's `wobble`.
/// - `root`: where the trunk meets the soil. Nothing at or below this line
///   moves — the position comes back untouched, bit for bit — so the pot and
///   the soil can share the layer and never shift.
/// - `crown`: the canopy's box, x, y, width, height. Its top edge sets the
///   tree's height (`root.y - crown.y`), which every amplitude is a fraction
///   of; the ellipse inside it is where the leaves rustle.
/// - `wobble`: the lean after a tap — how far the crown's top moves, as a
///   fraction of the tree's height (so roughly radians), signed, + to the
///   right. Comes from the CPU's damped spring and is added to the bend.
/// - `droop`: 0 cared for … 1 wilted. A drooping tree sways slower and
///   floppier (its top trails further behind its base) and barely rustles.
///
/// The bend grows with the square of the height above the root, the shape of
/// a loaded cantilever, so the trunk's foot is still and the crown carries
/// the motion; the crown drops a little as it swings, so it arcs instead of
/// shearing. Largest displacement, for `maxSampleOffset`, with
/// `lean = wind · 0.095 + |wobble|` (0.095 is `swayReach · 1.25 + gustReach`):
///
///     dx ≤ 1.4 · height · lean + 1.3 · wind
///     dy ≤ 0.6 · height · lean² + 1.3 · wind
///
/// 1.4 is the bend's ceiling, `1 + overhang`; 1.3 is `rustleReach`.
[[ stitchable ]] float2 nestieSway(float2 position, float time, float wind, float2 root, float4 crown,
                                   float wobble, float droop) {
    float height = max(root.y - crown.y, 1.0);
    float h = (root.y - position.y) / height;
    if (h <= 0.0) { return position; }

    float limp = saturate(droop);
    float k = min(h, 1.0 + nestie::overhang);
    float bend = nestie::bend(h);

    // Two whole sets of sway, brisk and lazy, crossfaded by the droop rather
    // than one set slowed down: scaling the clock by a mood that is easing
    // would jump the phase on every frame of the ease. The top trails the
    // base by `lag`, more so when it hangs limp.
    float lag = mix(0.35, 0.9, limp) * k;
    float brisk = nestie::wave(time, 119.0, -lag) + 0.35 * nestie::wave(time, 197.0, 1.7 - 1.3 * lag);
    float lazy = nestie::wave(time, 73.0, -lag) + 0.35 * nestie::wave(time, 127.0, 0.6 - 1.3 * lag);
    float sway = mix(brisk, lazy, limp) / 1.35 * nestie::swayReach * (1.0 + 0.25 * limp);

    // Gusts: the canvas's three sines, eased in and out of zero so a gust
    // arrives and lets go without a kink.
    float swell = (nestie::wave(time, 67.0, 0.0) + 0.5 * nestie::wave(time, 181.0, 1.0)
                   + 0.8 * nestie::wave(time, 23.0, 2.0)) / 2.3;
    float gust = smoothstep(0.0, 1.0, swell);
    float lean = gust * nestie::gustReach * (1.0 - 0.4 * limp);

    float dx = height * bend * (wind * (sway + lean) + wobble);
    // A branch of length L swung sideways by dx drops by about dx² / 2L.
    float dy = 0.4 * dx * dx / (max(h, 0.25) * height);

    // The leaves: a small, smooth flutter inside the crown's ellipse, from
    // two drifting layers of noise. Read in the bent tree's frame so the
    // flutter stays on the crown as it swings.
    float2 rustle = 0;
    float2 bent = position - float2(dx, 0);
    float2 centre = crown.xy + crown.zw * 0.5;
    float2 q = (bent - centre) / max(crown.zw * 0.55, float2(1.0));
    float inside = (1.0 - smoothstep(0.7, 1.1, length(q))) * smoothstep(0.35, 0.6, h);
    float amount = nestie::rustleReach * wind * (1.0 - 0.75 * limp) * (0.7 + 0.3 * gust) * inside;
    if (amount > 0.01) {
        float2 drift = float2(nestie::wave(time, 17.0, 0.0), nestie::wave(time, 13.0, 1.3)) * 6.5;
        float2 eddy = float2(nestie::wave(time, 11.0, 2.1), nestie::wave(time, 19.0, 0.4)) * 5.0;
        float2 coarse = bent / 12.0 + drift;
        float2 fine = bent / 7.0 - eddy;
        float2 n = float2(nestie::gradient(coarse), nestie::gradient(coarse + float2(31.7, 17.3)))
                 + 0.3 * float2(nestie::gradient(fine + float2(5.2, 63.1)), nestie::gradient(fine + float2(13.1, 47.9)));
        n *= float2(1.7, 1.2);
        float length2 = dot(n, n);
        if (length2 > 1.0) { n *= rsqrt(length2); }
        rustle = n * amount;
    }

    return position - float2(dx, dy) - rustle;
}

/// A painted finish for the flat vector tree: a darker, uneven rim inside the
/// silhouette and a soft contact shadow where a lighter shape meets a darker
/// one, a light from the top left that warms the lit edges and cools the
/// crown's far side, and a grain of paper and pigment.
///
/// - `crown`: the canopy's box, x, y, width, height — where the light falls.
/// - `strength`: 0…1, 0 returns the layer untouched. 1 is the tuned look.
///
/// The grain is a function of the position alone, never of time, so it is
/// painted on rather than shimmering. Apply this inside `nestieSway` (closer
/// to the content) and the grain and the rims travel with the leaves.
///
/// Five layer samples per pixel: the pixel and four neighbours 1.25 pt away.
/// Colours stay premultiplied: they are tinted unpremultiplied and
/// premultiplied again, and the alpha is never changed.
[[ stitchable ]] half4 nestiePaint(float2 position, SwiftUI::Layer layer, float4 crown, float strength) {
    half4 here = layer.sample(position);
    if (strength <= 0.0 || here.a < 0.004h) { return here; }

    const float r = 1.25;
    float4 c = float4(here);
    float4 e = float4(layer.sample(position + float2(r, 0)));
    float4 w = float4(layer.sample(position - float2(r, 0)));
    float4 s = float4(layer.sample(position + float2(0, r)));
    float4 n = float4(layer.sample(position - float2(0, r)));

    float3 colour = c.rgb / c.a;
    float lit = nestie::luma(colour);

    // The silhouette's rim: how much more opaque this pixel is than its
    // neighbours, uneven along its length like a brush's edge. Something
    // thinner than the probe — a bulb, a twig, the lights' wire — is all rim,
    // and darkening all of it only dirtied it, so a shape open on both sides
    // of either axis keeps its colour.
    float around = (e.a + w.a + s.a + n.a) * 0.25;
    float thin = max((1.0 - e.a) * (1.0 - w.a), (1.0 - s.a) * (1.0 - n.a));
    float rim = saturate((c.a - around) * 3.0) * (1.0 - thin) * (0.55 + 0.9 * nestie::value(position / 3.5));
    // Which way the edge faces: the outward normal, against a light from the
    // top left. The lit side warms, the far side darkens further.
    float2 outward = float2(w.a - e.a, n.a - s.a);
    float facing = dot(outward, float2(-0.6, -0.8)) / max(length(outward), 1e-3);
    float toLight = saturate(facing), away = saturate(-facing);

    // Contact shadow: a pixel darker than its opaque neighbours sits under
    // an edge, so it gets a little darker still. Only the darker side of a
    // boundary is touched, which reads as depth rather than an outline.
    float weight = e.a + w.a + s.a + n.a;
    float near = (nestie::luma(e.rgb) + nestie::luma(w.rgb) + nestie::luma(s.rgb) + nestie::luma(n.rgb))
                 / max(weight, 1e-3);
    float under = saturate((near - lit) * 3.0) * saturate(weight * 0.25);

    // The light across the crown.
    float2 extent = max(crown.zw * 0.5, float2(1.0));
    float2 uv = (position - crown.xy - extent) / extent;
    float across = dot(uv, float2(-0.6, -0.8));
    float canopy = 1.0 - smoothstep(0.8, 1.3, length(uv));
    float warm = smoothstep(-0.1, 1.0, across) * canopy;
    float cool = smoothstep(-0.1, 1.0, -across) * canopy;

    // Paper and pigment: fine grain plus a slow mottle, as density.
    float grain = nestie::value(position / 0.55) * 0.55 + nestie::value(position / 1.3) * 0.45 - 0.5;
    float mottle = nestie::gradient(position / 9.0);
    float density = grain * 0.22 + mottle * 0.12;

    float k = saturate(strength);
    float3 tint = float3(1.0)
        * mix(float3(1.0), float3(1.04, 1.02, 0.97), warm * k)
        * mix(float3(1.0), float3(0.94, 0.955, 1.0), cool * k);
    float shade = 1.0 - k * (rim * (0.08 + 0.14 * away) + under * 0.14);
    float glint = 1.0 + k * rim * toLight * 0.08;
    float3 painted = colour * tint * shade * glint;
    // Pigment density, after Bousseau et al.: thicker paint darkens the
    // midtones most and leaves white and black alone.
    painted -= painted * (1.0 - painted) * density * k;

    // Never brighter than 1 unless it already was, never negative; alpha is
    // the layer's own.
    painted = clamp(painted, 0.0, max(colour, float3(1.0)));
    return half4(half3(painted * c.a), here.a);
}
