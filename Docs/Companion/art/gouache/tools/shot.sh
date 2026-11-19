#!/bin/zsh
# usage: shot.sh OUT.png WIDTH HEIGHT "query string"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --default-background-color=00000000 --force-device-scale-factor=${SCALE:-2} --window-size=$2,$3 \
  --virtual-time-budget=1500 --screenshot="$1" "file://$DIR/tree.html?$4" >/dev/null 2>&1
ls -la "$1" | awk '{print $5, $9}'
