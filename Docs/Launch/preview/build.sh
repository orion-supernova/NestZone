#!/bin/zsh
# Cuts the raw simulator clips into the App Preview.
#   build.sh en|tr  <raw dir>
# Output: preview-<lang>.mp4 (886x1920, 30 fps, H.264, stereo AAC) and
# poster-<lang>.png. Needs ffmpeg and Google Chrome (for the caption PNGs).
set -e
L=${1:-en}; RAW=${2:-${0:A:h}/raw}
HERE=${0:A:h}; W=$HERE/work-$L; mkdir -p $W $HERE/captions
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
XF=0.4   # crossfade seconds

# shot name | clip | start | length | caption
if [ $L = en ]; then SHOTS=(
 "today|today|10.4|4.4|Your home, today"
 "lists|lists|15.4|5.0|Chores and shopping, shared"
 "plans|plans|11.0|4.2|Plans and dinner, together"
 "chat|chat|8.2|3.6|A chat just for the house"
 "money|fin|8.2|3.6|Split costs, settle up"
 "inbox|inbox|8.1|3.8|See what happened at home"
); else SHOTS=(
 "today|today|16.3|4.4|Bugün evde ne var?"
 "lists|lists|15.4|5.0|İşler ve alışveriş, ortak"
 "plans|plans|11.0|4.2|Planlar ve yemek, birlikte"
 "chat|chat|8.9|3.6|Sadece evdekilerin sohbeti"
 "money|fin|8.3|3.6|Masrafı böl, hesabı kapat"
 "inbox|inbox|8.1|3.8|Evde ne olmuş, hepsi burada"
); fi
# Optional per-language start overrides: $RAW/starts-$L.txt lines "shot=start"
typeset -A OVR; [ -f $RAW/starts-$L.txt ] && while IFS='=' read k v; do OVR[$k]=$v; done < $RAW/starts-$L.txt

i=0; INS=(); FILT=""; OFF=0; N=${#SHOTS}
for s in $SHOTS; do
  IFS='|' read name clip start len cap <<< "$s"
  [ -n "${OVR[$name]}" ] && start=${OVR[$name]}
  png=$HERE/captions/$L-$name.png
  enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$cap")
  "$CH" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --window-size=886,1920 --screenshot=$png "file://$HERE/caption.html#$enc" >/dev/null 2>&1
  # The simulator's recording only has frames where something moved, so it is
  # first turned into a steady 30 fps clip (raw/cfr/), which is what every cut
  # point below is measured on.
  src=$RAW/cfr/${L}_$clip.mp4
  [ -f $src ] || { mkdir -p $RAW/cfr; ffmpeg -v error -y -i $RAW/${L}_$clip.mov -vf "fps=30,scale=886:-2:flags=lanczos,crop=886:1920" -c:v libx264 -crf 12 -preset veryfast -pix_fmt yuv420p -an $src; }
  # Clip -> 886x1926 -> centre-crop 1920, 30 fps. Static tails (the recorder
  # writes no frames while nothing moves) are held with tpad.
  ffmpeg -v error -y -ss $start -i $src -loop 1 -t $len -i $png \
    -filter_complex "[0:v]fps=30,scale=886:-2:flags=lanczos,crop=886:1920,tpad=stop_mode=clone:stop_duration=$len,trim=duration=$len,setpts=PTS-STARTPTS[v];
      [1:v]format=rgba,fade=t=in:st=0.35:d=0.3:alpha=1,fade=t=out:st=$(python3 -c "print($len-0.75)"):d=0.3:alpha=1[c];
      [v][c]overlay=shortest=1,format=yuv420p" \
    -t $len -r 30 -c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p $W/seg$i.mp4
  i=$((i+1))
done

# Chain the crossfades.
ARGS=(); for k in {0..$((N-1))}; do ARGS+=(-i $W/seg$k.mp4); done
CUR="[0:v]"; OFFS=0; LENS=()
for s in $SHOTS; do IFS='|' read a b c len d <<< "$s"; LENS+=($len); done
for k in {1..$((N-1))}; do
  OFFS=$(python3 -c "print(round($OFFS+${LENS[$k]}-$XF,3))")
  FILT+="${CUR}[${k}:v]xfade=transition=fade:duration=${XF}:offset=${OFFS}[x$k];"
  CUR="[x$k]"
done
TOTAL=$(python3 -c "print(round($OFFS+${LENS[$N]},3))")
# A soft, generated pad (a Cmaj9 chord of sines with a slow swell). Synthesised
# here, so there is nothing to license.
AUD="aevalsrc='0.05*sin(2*PI*130.81*t)+0.04*sin(2*PI*164.81*t)+0.04*sin(2*PI*196*t)+0.03*sin(2*PI*246.94*t)+0.025*sin(2*PI*293.66*t)':s=48000:d=$TOTAL,tremolo=f=0.15:d=0.5,lowpass=f=900,afade=t=in:d=2,afade=t=out:st=$(python3 -c "print($TOTAL-2.5)"):d=2.5,aformat=channel_layouts=stereo"
ffmpeg -v error -y $ARGS -f lavfi -i "$AUD" \
  -filter_complex "${FILT%;}" -map "[x$((N-1))]" -map ${N}:a \
  -c:v libx264 -profile:v high -level 4.2 -preset slow -crf 17 -pix_fmt yuv420p -r 30 -movflags +faststart \
  -c:a aac -b:a 128k -ar 48000 -ac 2 -t $TOTAL $HERE/preview-$L.mp4
ffmpeg -v error -y -ss ${POSTER:-17.8} -i $HERE/preview-$L.mp4 -frames:v 1 $HERE/poster-$L.png
echo "built preview-$L.mp4 ($TOTAL s)"
