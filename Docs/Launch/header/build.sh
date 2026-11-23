#!/bin/zsh
# Renders the Header and Search Results image in both sizes and languages.
# Output: header-<lang>-5244x2950.png and header-<lang>-3840x1646.png (sRGB,
# opaque). Needs Google Chrome; the stills come from shots.sh.
HERE=${0:A:h}
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for L in en tr; do for S in 5244x2950 3840x1646; do
  W=${S%x*}; H=${S#*x}
  "$CH" --headless=new --disable-gpu --hide-scrollbars --force-color-profile=srgb --default-background-color=ff0f0820 \
    --window-size=$W,$H --force-device-scale-factor=1 --virtual-time-budget=4000 \
    --screenshot=$HERE/header-$L-$S.png "file://$HERE/header.html#$L" >/dev/null 2>&1
done; done
