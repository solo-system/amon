This file is part of Solo (http://solo-system.github.io)

To add a new microphone, add a new file in here that describes the mic
and sets it up.

You also need to add the appropriate "hw" and "plug" pcms to asoundrc.

This is used from prepare_mic, so should make whatever calls to
"amixer..." are necessary to prepare us.  Particularly set the volume.
Volmes are different for each sound card, so add a "new" volume to
amon.conf (eg SB_VOLUME), which can be used in this script to set the
levels.  

Remember: CHANNELS, SAMPLERATE are both set on the arecord command
line, so are probably shouldn't be included here.

The most recently built is the soundblasterplay.conf file - so use
that as a template.

TODO:

Shadows (copies?) of these should live in /boot for users to edit
(then they could add their own mics).

Also - each new microphone needs an entry in asoundrc, so that should
really be a asound.d/ directory where new per-sound-card files can be
dropped by users.  That too should be shadowed in /boot, but haven't
done this yet. ( and don't know how to make alsa-lib read a
directory's worth of config files.  It does do so, however, for other
things: see https://www.alsa-project.org/main/index.php/Asoundrc
