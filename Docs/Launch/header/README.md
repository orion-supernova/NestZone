# Header and Search Results image

`header.html` is the whole design; `build.sh` renders it with headless Chrome in
both languages and both sizes Apple lists for App Store Connect's "Header and
Search Results" section: 5244 x 2950 and 3840 x 1646 (PNG, opaque, sRGB).
`shots.sh en|tr` retakes the three phone screens from the screenshot houses.

What was assumed, because the ASC page gives sizes and no safe-area map:

- The image is cropped differently per surface and orientation, so the name,
  the line and the middle phone's top half (the Today screen's header and its
  urgent card) sit in the central ~60% of the width and ~65% of the height.
  The two outer phones and the foot of the middle one bleed past that on
  purpose: losing them in a crop costs nothing.
- One layout unit is 1/100 of the height or 1/200 of the width, whichever is
  smaller, so the two sizes are the same picture at two sizes.
- Persona and houses are the screenshot ones (Emma, Maya, Leo, Sam / Ayse, Mert,
  Deniz); no real name, face or house is drawn. Theme: Basic (violet), the one
  the store screenshots use.
- The line is in the app's voice, not a claim: "Your home, in one shared app" /
  "Evin her seyi, tek ortak uygulamada" (written with Turkish letters in the
  image).

Files: `header-<en|tr>-5244x2950.png`, `header-<en|tr>-3840x1646.png`.
