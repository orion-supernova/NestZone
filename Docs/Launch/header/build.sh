#!/bin/zsh
# Header and Search Results images, en/tr/sv, rendered with headless Chrome from the real 1.13 captures
# (../screenshots/raw/<lang>_NN.png) and the drawn iPhone. Output (opaque RGB PNG):
#   header-<lang>-5244x2950.png  header-<lang>-3840x1646.png
#   search-<lang>-3840x2560.png  search-<lang>-1920x1280.png
HERE=${0:A:h}; CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
shot(){ "$CH" --headless=new --disable-gpu --hide-scrollbars --force-color-profile=srgb --default-background-color=ff0f0820 \
  --window-size=$2,$3 --force-device-scale-factor=1 --virtual-time-budget=6000 --screenshot=$HERE/$1 "file://$HERE/header.html#$4" >/dev/null 2>&1 </dev/null; }
LANGS=(${@:-en tr sv}); for L in $LANGS; do
  shot header-$L-5244x2950.png 5244 2950 $L
  shot header-$L-3840x1646.png 3840 1646 $L
  shot search-$L-3840x2560.png 3840 2560 "$L&search"
  ffmpeg -nostdin -v error -y -i $HERE/search-$L-3840x2560.png -vf scale=1920:1280:flags=lanczos $HERE/search-$L-1920x1280.png
done
