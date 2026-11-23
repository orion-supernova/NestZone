#!/bin/zsh
# Fresh simulator screens of the 1.13 UI for the store screenshots.
#   shoot.sh en|tr|sv [subjects...]     (default: all eight)
# Writes raw/<lang>_NN.png at the simulator's own size (1206 x 2622).
# The house is switched by name first (remembered on the device), the persona
# hides the real account, and the status bar is pinned to 9:41.
S=${SIM:-239DF118-3D9D-4EFE-A5F9-7DA1F9A02F24}; L=$1; shift
OUT=${0:A:h}/raw; mkdir -p $OUT
case $L in
  en) HOUSE="Our Place";       PERSONA=Emma; LOC=en_US ;;
  tr) HOUSE="Bizim Ev";        PERSONA=Elif; LOC=${LOCALE:-tr_TR} ;;
  sv) HOUSE="Hemma hos oss";   PERSONA=Sara; LOC=sv_SE ;;
esac
APP=com.walhallaa.NestZone
base=(-screenshotPersona $PERSONA -storeDemo 1 -AppleLanguages "($L)" -AppleLocale $LOC -appTheme basic)
xcrun simctl status_bar $S override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --operatorName ""
xcrun simctl terminate $S $APP 2>/dev/null
xcrun simctl launch $S $APP $base -switchHome "$HOUSE" >/dev/null; sleep 18; xcrun simctl terminate $S $APP
snap(){ n=$1; w=$2; shift 2
  xcrun simctl terminate $S $APP 2>/dev/null
  xcrun simctl launch $S $APP $base "$@" >/dev/null; sleep $w
  xcrun simctl io $S screenshot $OUT/${L}_$n.png >/dev/null 2>&1; }
want(){ [ $# -eq 0 ] || return 0; return 0 }
run(){ n=$1; shift; if [ ${#SUBJ} -eq 0 ] || [[ " $SUBJ " == *" $n "* ]]; then snap $n "$@"; fi }
SUBJ="$*"
run 01 20 
run 02 20 -openTab lists -appTabSegments "tasks,calendar,finance"
run 03 22 -openTab lists -appTabSegments "shopping,calendar,finance" -shoppingGroupedDemo 1
run 04 22 -calendarMode agenda
run 05 20 -openTab house -appTabSegments "tasks,calendar,finance"
run 06 22 -openConversation first
run 07 40 -openMovieNight 1
run 08 20 -openTab house -appTabSegments "tasks,calendar,maintenance"
xcrun simctl terminate $S $APP
