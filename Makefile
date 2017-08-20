### This file is part of Solo. (https://www.github.com/solo-system)

### Makefile to install "amon".

default:
	echo "no default target yet, sorry"

alsaconf:
	cp -v asoundrc /usr/share/alsa/alsa.conf.d/alsa-solo.conf
