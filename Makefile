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
	if [ ! -d /home/amon/amon ] ; then mkdir -pv /home/amon/amon; fi
	cp -prv amon amon.conf defs.sh mics wp.sh WPutils.sh /home/amon/amon/
	chown -R amon.amon /home/amon/amon/
	chmod +x /home/amon/amon/amon
	if ! grep -q /home/amon/amon /home/amon/.bashrc ; then echo "adding path to bashrc" ; echo 'PATH=/opt/upgrade-alsa/installdir/bin:$$PATH:/home/amon/amon' >> /home/amon/.bashrc ; else echo "PATH already good" ; fi
