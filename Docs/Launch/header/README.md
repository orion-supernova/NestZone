# Header and Search Results images

`header.html` is the whole design; `build.sh [en tr sv]` renders it with headless Chrome:

- `header-<lang>-5244x2950.png` and `header-<lang>-3840x1646.png` (Header and Search Results section)
- `search-<lang>-3840x2560.png` and `search-<lang>-1920x1280.png` (the 3:2 Search Results asset)

All are opaque RGB PNG, sRGB, under 7 MB. They use the real 1.13 captures in
`../screenshots/raw/<lang>_NN.png` (01 Today, 03 Shopping, 04 Calendar; each language from its own screenshot
house) in the same drawn iPhone as the store screenshots (`../screenshots/frame/`; a
`frame/apple-bezel.png` is used if it exists). Retake the captures with `../screenshots/shoot.sh`.

Assumptions (ASC gives sizes, not a safe-area map): the header is cropped differently per surface, so the name,
the line and the middle phone's top half sit in the central ~60% x 65%; the outer phones and the foot of the middle
one bleed past it on purpose. The search image has to read small: the name is large, the promise is one line,
two phones, nothing else. Theme: Basic (violet).
