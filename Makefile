### This file is part of Solo. (https://www.github.com/solo-system)

### Makefile to install "amon".

default:
	echo "no default target yet, sorry"

install: alsaconf bootfiles homefiles

alsaconf:
	cp -v asoundrc /usr/share/alsa/alsa.conf.d/alsa-solo.conf

# move the boot files into /boot/solo (amon.conf and calendars)
bootfiles:
	cp -rv boot/* /boot/solo/
# 	chown -R amon.amon /boot/solo # dont' do this - permission denied(!)

homefiles:
	mkdir -pv /home/amon/amon
	cp -prv amon amon.conf defs.sh mics /home/amon/amon/
	chown -R amon.amon /home/amon/amon/
	chmod +x /home/amon/amon/amon
	echo 'PATH=$$PATH:/home/amon/amon' >> /home/amon/.bashrc
