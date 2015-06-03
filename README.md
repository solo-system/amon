README for amon
---------------

Below are notes made prior to publishing to github.  Probably not much
use.  One day it will all be gh-pages / wiki or something...


-------------------

generated: wav files
	   pidfile   -> currently:/home/amon/amon    moveto:/var/lock?
	   state     -> /var/run
	   cron.log  -> 
	   arecord.log -> stay on sdcard
	   solo-boot.log -> copy itself to /sdcard/logs
	   dmesg -> solo-boot.sh can copy it to /sdcard/logs

	   
	   mountpoint = /mnt/sdcard/
	   amondata / wavs / 2015-01-01
	   	      	     2015-01-02
	   		     arecord.log
			     arecord.log.backup2014-12-31.
	   
	   /home/amon/	amon.log
			state
			pidfile
			cron.log

-----------------------------------------------------------------------	   

todo: SAMPLERATE - if not set in amon.conf, isn't set anywhere.
Should have default value of 16k in defs.sh, prepare mic (or some
other function).

todo: add target "amon test" - which records a 3 second test file.  if
given a $1 it scp's it to that machine.


First big change for some time : 

Integrate cirrus logic audio card.
----------------------------------

arecord uses asoundrc file to find default audio card.
We should use this functionality.
We need to define default audio card for BOTH use cases:
the cirrus AND the snowflake.
amon should NOT know about this.  Except using a –Dhw:sndrpiwsp flag to arecord
the string sndrpiwsp is from the usermanual, but is defined in .asoundrc in /home/pi/.asoundrc

Instead, the solo-boot.sh should know what we're doing, and setup an appropriate .asoundrc for us.
except, solo is not amon, and this is really an amon thing...
Perhaps amon should do it.  But amon is never "installed", so we'd need a "firstrun" flag or something.  Perhaps just the absense of .asoundrc could cause amon to generate an appropriate asoundrc file.

to get recording working on raspi with cirrus we need to do:
/home/pi/Reset_paths.sh 
/home/pi/Record_from_DMIC.sh
arecord -c 2 -f S16_LE -r 44100 out.wav

then to test:
./Playback_to_Lineout.sh
aplay out.wav


------

TODO: use file locking in /var/run to ensure no two amons run at the same time (really unlikely)

