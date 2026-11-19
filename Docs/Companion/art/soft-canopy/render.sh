#!/bin/bash
# usage: render.sh OUT.png "query string" [width height]
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$1"; QS="$2"; W="${3:-520}"; H="${4:-360}"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --default-background-color=00000000 --force-device-scale-factor=2 --window-size=$W,$H \
  --virtual-time-budget=1500 --screenshot="$OUT" "file://$DIR/tree.html?$QS" 2>/dev/null >/dev/null
echo "$OUT"
