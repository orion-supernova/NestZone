#!/bin/zsh
# Frames raw/<lang>_NN.png (frame/frame.html: headline, subline, drawn iPhone,
# or frame/apple-bezel.png if it exists) and writes the two App Store sizes:
#   <lang>_NN.png            1320 x 2868   (6.9")
#   6.3/<lang>_NN.png        1206 x 2622   (6.3", the same picture scaled)
#   compose.sh [lang ...]    (default: en tr sv)
HERE=${0:A:h}; CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p $HERE/6.3
q(){ python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$1"; }
LANGS=(${@:-en tr sv})
while IFS=$'\t' read l n t s; do
  [[ " $LANGS " == *" $l "* ]] || continue
  [ -f $HERE/raw/${l}_$n.png ] || continue
  "$CH" --headless=new --disable-gpu --hide-scrollbars --force-color-profile=srgb --window-size=1320,2868 \
    --virtual-time-budget=4000 --screenshot=$HERE/${l}_$n.png \
    "file://$HERE/frame/frame.html#img=$(q file://$HERE/raw/${l}_$n.png)&t=$(q $t)&s=$(q $s)" >/dev/null 2>&1 </dev/null
  ffmpeg -nostdin -v error -y -i $HERE/${l}_$n.png -vf "scale=1206:2622:flags=lanczos" $HERE/6.3/${l}_$n.png
done < $HERE/captions.tsv
