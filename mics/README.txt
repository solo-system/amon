This file is part of Solo (http://solo-system.github.io)

To add a new soundcard, add a file in here that contains:
1) SOUNDCARD_REGEXP - a way to match the conf to the hardware detected and shown in /proc/asound/cards
2) initialisation (unmute, volume, line/mic input etc). 

This is used from defs.sh's prepare_microphone(), so should make
whatever calls to "amixer..." are necessary to prepare us.
Particularly set the volume.  Volmes are different for each sound
card, so add a "new" volume to amon.conf (eg SB_VOLUME), which can be
used in this script to set the levels.

Remember: CHANNELS, SAMPLERATE are both set on the arecord command
line, so are probably shouldn't be included here.
