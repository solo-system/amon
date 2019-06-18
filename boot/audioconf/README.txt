This file is part of Solo (http://solo-system.github.io)

To add a new soundcard, add a file in here that contains:

1) SOUNDCARD_REGEXP - a way to match the conf to the hardware detected
   and shown in /proc/asound/cards

2) Initialisation (unmute, volume, line/mic input etc). "amixer" is
   used for this.

Use one of the existing .conf files as a template.  The name of the
file is irrelevant (but must end in .conf), but the SOUNDCARD_REGEXP
is vital - ensure it matches how the sound card shows up in
/proc/asound/cards.

This directory used from defs.sh's configure_soundcard(), so should make
whatever calls to "amixer..." are necessary to initialise the soundcard.
In particular - set the volume, and unmute the soundcard.

Remember: CHANNELS, SAMPLERATE are both set on the arecord command
line, so are probably shouldn't be included here.
