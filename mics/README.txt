For each new mic:
    define a .conf file (user editable bash variables)

The main script searches for the conf file, sourcing it once found.

Shadows (copies?) of these should live in /boot for users to edit.

.conf files should probably contain at least:

SAMPLERATE
CHANNELS
MMAP
AUDIODEVICE
