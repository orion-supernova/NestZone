#!/bin/zsh
# Records one raw clip of the app from a launch argument set, on the booted
# simulator. Usage: capture.sh <out.mov> <seconds> <lang en|tr> [launch args...]
# The home must already be the screenshot house for that language
# (-switchHome "Our Place" / "Bizim Ev", once; it is remembered).
S=${SIM:-239DF118-3D9D-4EFE-A5F9-7DA1F9A02F24}
OUT=$1; SECS=$2; LANG=$3; shift 3
xcrun simctl terminate $S com.walhallaa.NestZone 2>/dev/null
xcrun simctl status_bar $S override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --operatorName ""
xcrun simctl io $S recordVideo --codec h264 --force "$OUT" 2>/dev/null &
REC=$!
sleep 1.5
xcrun simctl launch $S com.walhallaa.NestZone -screenshotPersona Emma -storeDemo 1 -AppleLanguages "($LANG)" -AppleLocale "${LOCALE:-$([ "$LANG" = tr ] && echo tr_TR || echo en_US)}" -appTheme basic "$@" >/dev/null
sleep $SECS
kill -INT $REC; wait $REC 2>/dev/null
xcrun simctl terminate $S com.walhallaa.NestZone
