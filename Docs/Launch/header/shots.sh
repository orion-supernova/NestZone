#!/bin/zsh
# Fresh stills of the screenshot houses for the Header: shots.sh en|tr
# (the home must already be "Our Place" for en and "Bizim Ev" for tr).
S=${SIM:-239DF118-3D9D-4EFE-A5F9-7DA1F9A02F24}; L=$1
OUT=${0:A:h}/shots; mkdir -p $OUT
snap(){ # name wait args...
  n=$1; w=$2; shift 2
  xcrun simctl terminate $S com.walhallaa.NestZone 2>/dev/null
  xcrun simctl status_bar $S override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --operatorName ""
  xcrun simctl launch $S com.walhallaa.NestZone -screenshotPersona Emma -storeDemo 1 -AppleLanguages "($L)" -AppleLocale "$([ $L = tr ] && echo tr_TR || echo en_US)" -appTheme basic "$@" >/dev/null
  sleep $w; xcrun simctl io $S screenshot $OUT/${L}_$n.png >/dev/null 2>&1
}
snap today 16
snap shop 18 -openTab lists -appTabSegments "shopping" -shoppingGroupedDemo 1
snap cal 16 -calendarMode month
snap money 16 -openTab house -appTabSegments "finance"
snap chat 18 -openConversation first
xcrun simctl terminate $S com.walhallaa.NestZone
