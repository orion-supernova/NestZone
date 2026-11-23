#!/bin/zsh
# contact.sh <lang> <out.png>: the eight screenshots of a language on one sheet (for review).
HERE=${0:A:h}; L=$1; OUT=$2
ffmpeg -v error -y -i $HERE/${L}_01.png -i $HERE/${L}_02.png -i $HERE/${L}_03.png -i $HERE/${L}_04.png \
  -i $HERE/${L}_05.png -i $HERE/${L}_06.png -i $HERE/${L}_07.png -i $HERE/${L}_08.png \
  -filter_complex "[0][1][2][3]hstack=4[a];[4][5][6][7]hstack=4[b];[a][b]vstack,scale=2000:-1" $OUT
