#!/bin/bash 

wav=/home/amon/amon/calibrate1k.wav

echo "this is playback.sh"
echo "the time is `date`"

amixer sset PCM,0 100%

aplay $wav

echo "playback.sh finished."

exit 0
