#!/bin/zsh
# Puts the companion in a given state on the simulator and takes screenshots,
# for checking how it looks without tapping through the app.
#
#   scenario.sh <name> '<python dict>' [demo] [spot] [seconds...]
#
# The dict is written as the home's companion file (dates as seconds since
# 2001, which is how JSONEncoder writes a Date — `ref` is now, `day` is a day,
# `at(y, m, d, h)` is a local time). `demo` is passed as -companionDemo
# (care, decorate, celebrate, dress, album, holidays, lab, choose, pick, grow,
# labgrow) and `spot`
# as -companionSpot; `-` skips either. Screenshots are taken at each number of
# seconds after launch, as <name>_0.png, <name>_1.png… in the current folder.
#
# Example — a thirsty magnolia, watered five seconds in:
#   scenario.sh revive '{"current":{"species":"magnolia","seed":"x-0","startedAt":ref-6*day,"bonus":34},"lab":{"mood":"thirsty"}}' care - 5 6.5 8
#
# Set EXTRA_ARGS for more launch arguments, e.g. EXTRA_ARGS="-appLanguage tr".
#
# Development builds only (the companion and the demo hook are #if DEBUG).
# Build and install first:
#   xcodebuild -scheme NestZone -destination 'platform=iOS Simulator,name=iPhone 17' build
#   xcrun simctl install "iPhone 17" <DerivedData>/Build/Products/Debug-iphonesimulator/NestZone.app
NAME=$1; JSONEXPR=$2; DEMO=${3:--}; SPOT=${4:--}; shift 4 2>/dev/null; OFFSETS=("$@")
[[ ${#OFFSETS} -eq 0 ]] && OFFSETS=(6)
SIM=${SIM:-"iPhone 17"}; APPID=com.walhallaa.NestZone
DATA=$(xcrun simctl get_app_container "$SIM" $APPID data) || exit 1
FILE=$(ls "$DATA"/Documents/companion-*.json 2>/dev/null | head -1)
[[ -z "$FILE" ]] && { echo "Open Today once on the simulator so the companion file exists."; exit 1; }
python3 -c "
import json, time, datetime
ref = time.time() - 978307200
day = 86400
def at(y, m, d, h=20): return datetime.datetime(y, m, d, h).timestamp() - 978307200
json.dump($JSONEXPR, open('$FILE', 'w'))
"
xcrun simctl terminate "$SIM" $APPID 2>/dev/null
ARGS=(${=EXTRA_ARGS})   # e.g. EXTRA_ARGS="-appLanguage tr"
[[ "$DEMO" != "-" ]] && ARGS+=(-companionDemo $DEMO)
[[ "$SPOT" != "-" ]] && ARGS+=(-companionSpot $SPOT)
xcrun simctl launch "$SIM" $APPID $ARGS >/dev/null
START=$(python3 -c 'import time; print(time.time())')
i=0
for off in $OFFSETS; do
  python3 -c "import time; time.sleep(max(0, $START + $off - time.time()))"
  xcrun simctl io "$SIM" screenshot ${NAME}_$i.png >/dev/null 2>&1
  i=$((i + 1))
done
