### function definitions for amon

function amonon {
    s=`getstate`
    if [ "$s" = "on" ]; then
	log "already [on], so doing nothing"
	return 0
    fi
    setstateon
    start
}

function amonoff {
    s=`getstate`
    if [ "$s" = "off" ]; then
        log "already [off], so doing nothing"
	return 0
    fi
    setstateoff
    stop
}

# This runs from crontab every minute.  Check sanity, then start/stop
# according to "statefile".
function watchdog {
    log "-- MARK : watchdog starting --"
    s=`getstate`
    log "(desired) state=[$s]: will cleanup() then make it so."

    # first do some cleanup (test processes and procfile are in sync)
    amoncleanup
    #retval=$?
    #[ $? -ne 0] && log "amoncleanup killed everything - now starting / stop according to statefile"

    if [ $s = "on" ]; then
        # log "state is [on] so starting recording, and split if it was already running"
        start -q

	# now tell arecord to split the audiofile.  Only if we didn't just start, and if the minute-of-day divides $DURATION
	retval=$?
	minute=`date +"%-M"`
	rem=$(($minute % $DURATION))
        [ $retval == 1 ] && [ $rem == 0 ] && amonsplit
    elif [ $s = "off" ]; then
        # log "state is [off] so stopping recording"
        stop -q
    else
        log "ERROR: state file is confused [$s].  This is a code error"
    fi

    status # print status for the log

    # log "MEM: Performing memory management"
    DO_MEM_STUFF=no
    if [ $DO_MEM_STUFF != "no" ] ; then
      freek=`df -k /mnt/sdcard | tail -1 | awk '{print $4}'`
      if [ ${freek} -lt ${MINMEMFREE} ] ; then
          log "MEM: too little free space (${freek} < ${MINMEMFREE}) => calling deloldest()"
          deloldest
      else
          log "MEM: plenty of free space (${freek} > ${MINMEMFREE}) => doing nothing"
      fi
    fi # end of "if DO_MEM_STUFF"

    # check if we should reboot
    hourmin=`date +"%H:%M"`
    if [ $NIGHTLYREBOOT -a $NIGHTLYREBOOT = $hourmin ] ; then
	log "rebooting since $hourmin = $NIGHTLYREBOOT"
        reboot
    else
	# log "not calling reboot since $hourmin != $NIGHTLYREBOOT"
	# those log messages were getting boring.
	true
     fi

    log "-- MARK : watchdog finished --"
} # end of watchdog

# send signal to arecord to split the output file
function amonsplit {
    
    if [ ! -f $PIDFILE ] ; then
	log "No pidfile - can't do amonsplit"
	return 0
    fi

    pid=`cat $PIDFILE`
    kill -USR1  $pid
    log "Sent split signal [USR1] to arecord process [pid=$pid]"
}

# show the configuration options.
function conf {
    echo "configuration is as follows:"
    echo "-----------------------------------"
    echo "NIGHTLYREBOOT is at: $NIGHTLYREBOOT"
    printenv
    echo "finished."
}


# This still needs lots of work - 
function prepare_microphone {
    # choose and setup microphone.
    # how do they show up in /proc/asound/cards (or arecord -l)
    # Blue:snowflake mic -> "Snowflake"
    # Cirrus Logic Audio Card -> "sndrpiwsp"
    # Dodotronic ultrasound mic (200k) -> "bits"
    # New microphone here

    # Todo : This Setup won't work in long run.  For example, I bet
    # dodotronic 250k mic also shows up as "bits" in alsa.  And we
    # need a "per-mic" configuration file (in /boot)
    # micsetup.DODOTRONIC, so users can easily change their
    # preferences for each mic (from windows quite easily).  Can also
    # then support new mics by simply adding new micsetup.conf file.

    # Also question of whether the prepare_mic routine should SET the
    # cmdline for arecord (or whatever), or should set the values to
    # be on that command line.  Probably better to set the $cmd
    # variable, but then can we still use testrec?  

    if grep sndrpiwsp /proc/asound/cards > /dev/null ; then

	log "detected Cirrus Logic Audio Card => preparing as audio source"

	[ ! $CLAC_VOL ]     && { log "choosing default for CLAC_DIG_VOL" ; CLAC_VOL=31 ;}
	[ ! $CLAC_DIG_VOL ] && { log "choosing default for CLAC_DIG_VOL" ; CLAC_DIG_VOL=128 ;}
	[ ! $CLAC_SAMPLERATE ] && { log "choosing default for CLAC_SAMPLERATE" ; CLAC_SAMPLERATE="-r16000" ;}
	# TODO: why don't I check for channels here (and why do I call samplerate and channels CLAC_* ?)

	# WARNING : DON'T FIDDLE WITH THE ORDER OF THE
	# reset_paths, record_from_linein_micbias,  here.  Previously 
	# had other setup and it caused a hang: complaining:
	# bmc_2708 DMA transfer could not be stopped. (or similar).
	# The arecord (from amon testrec) hung, output 44 bytes, and 
	# syslog (dmesg) showed above message.

        # /home/pi/Record_from_DMIC.sh >> clac.log 2>&1
        # /home/pi/Record_from_Headset.sh >> clac.log 2>&1
        # /home/pi/Record_from_lineIn.sh >> clac.log 2>&1
	/home/amon/clac/Reset_paths.sh -q  # initialize everything to safe values

	if [ "$CLAC_AUDIO_SOURCE" = "linein" ] ; then
	    log "setting record source to: $CLAC_AUDIO_SOURCE"
	    /home/amon/clac/Record_from_lineIn_Micbias.sh -q  # with micbias!
	    amixer -q -Dhw:sndrpiwsp cset name='IN3L Volume' $CLAC_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN3R Volume' $CLAC_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN3L Digital Volume' $CLAC_DIG_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN3R Digital Volume' $CLAC_DIG_VOL
        elif [ "$CLAC_AUDIO_SOURCE" = "dmic" ] ; then
	    log "setting record source to: $CLAC_AUDIO_SOURCE"
	    /home/amon/clac/Record_from_DMIC.sh -q  # dmic (onboard MEMS mics)
	    amixer -q -Dhw:sndrpiwsp cset name='IN2L Volume' $CLAC_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN2R Volume' $CLAC_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN2L Digital Volume' $CLAC_DIG_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN2R Digital Volume' $CLAC_DIG_VOL
	else
	    log "WARNING: CLAC_AUDIO_SOURCE ($CLAC_AUDIO_SOURCE) not recognised - using default: \"dmic\""
	    /home/amon/clac/Record_from_DMIC.sh -q
	    amixer -q -Dhw:sndrpiwsp cset name='IN2L Volume' $CLAC_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN2R Volume' $CLAC_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN2L Digital Volume' $CLAC_DIG_VOL
	    amixer -q -Dhw:sndrpiwsp cset name='IN2R Digital Volume' $CLAC_DIG_VOL
	fi

#	amixer -Dhw:sndrpiwsp cset name='Line Input Switch' off  # turn it off for safety
#	if [ "$CLAC_PIP" != "on" ] ; then
#           log "WARNING: CLAC_PIP ($CLAC_PIP) (plug-in-power) is ON!"
#	   amixer -Dhw:sndrpiwsp cset name='Line Input Switch' on
#        fi

	SAMPLERATE=$CLAC_SAMPLERATE
	CHANNELS=$CLAC_CHANNELS
#	AUDIODEVICE="-Dhw:sndrpiwsp" # override this, cos the above scripts set it all up nicely.
	AUDIODEVICE="-Dclac"
	MMAP=""
	log "prepare_mic: [MICTYPE=CLAC] CHANNELS=$CHANNELS AUDIODEVICE=$AUDIODEVICE MMAP=$MMAP CLAC_VOL=$CLAC_VOL CLAC_DIG_VOL=$CLAC_DIG_VOL CLAC_AUDIO_SOURCE=$CLAC_AUDIO_SOURCE CLAC_PIP=$CLAC_PIP"

    elif grep "Snowflake" /proc/asound/cards > /dev/null ; then
	log "Detected Blue:Snowflake microphone => preparing as audio source"
	log "setting volume to $VOLUME ..."
	AUDIODEVICE="-D hw:Snowflake"
	amixer $AUDIODEVICE -q -c 1 set "Mic" $VOLUME
	# MMAP="--mmap" # turned this off (may 2015) for no good reason.
    elif grep "UltraMic 200K" /proc/asound/cards > /dev/null ; then
	MICNAME="dodotronic-200k"
	log "Detected \"$MICNAME\" microphone => preparing as audio source"

	conf=mics/$MICNAME.conf
	if [ -f $conf ] ; then 
	    log "reading microphone config file: $conf"
#	    set -x
	    . mics/$MICNAME.conf
#	    set +x
	    log "done reading microhpone config file"
	else
	    log "Can't find configuration for microphone $MICNAME - no mics/$MICNAME.conf file"
	    log "Dunno what will happen - ..."
	fi
	log "prepare_mic: [MICTYPE=$MICNAME] AUDIODEVICE=$AUDIODEVICE SAMPLERATE=$SAMPLERATE CHANELS=$CHANNELS ABUFFER=$ABUFFER MMAP=$MMAP"
    else
	log "ERROR: warning - microphone not recognised. Doing no mic_preparation"
    fi
}

# perform a test recording to check microphone settings etc...
function testrec {

    # Argh - the -d option to arecord (duration) doesn't work pre arecord --version = 1.0.29
    # Currently raspbian ships with:
    # amon@solo:~/amon $ arecord --version
    # arecord: version 1.0.28 by Jaroslav Kysela <perex@perex.cz>
    # (april 21st 2016).
    # see: http://comments.gmane.org/gmane.linux.alsa.user/38692
    # so we have to do a "run in background and kill" - yuk.
    
    s=`getstate`
    if [ $s != 'off' ] ; then
	log "Refusing to undertake test recording: since state is not off (its $s)"
	log "do \"amon off\" first, then retry"
	return 0
    fi

    # Don't do it around the turn of the minute - cos the watchdog
    # will kill us.
    while [ $(date +"%S") -gt 50 -o $(date +"%S") -lt 10 ] ; do
	echo "Standby (avoiding watchdog at 0 seconds) ... waiting $(date)"
	sleep 1
    done
    echo "safe to do - it's $(date)"
    
    log "Performing a test recording [ 3 seconds long ...]"
    prepare_microphone
    cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE ${WAVDIR}/testrec.wav"
    log "running: $cmd"
    $cmd >& ${WAVDIR}/testrec.log &
    log "waiting 3 seconds..."
    sleep 3
    kill -9 %1
    log "Done - hopefully recorded.  Check:"
    log "${WAVDIR}/testrec.wav or ${WAVDIR}/testrec.log"
    ls -l ${WAVDIR}/testrec.wav ${WAVDIR}/testrec.log
    log "testrec finished"

    if [ -n "$2" ] ; then
	log "copying to $2 - running scp..."
	scp ${WAVDIR}/testrec.wav $2
    fi
    
#    if [ $? -ne 0 ] ; then
#	log "testrec: ERROR: something went wrong (arecord already running? \"amon status\" to check)"
#    else
#	log "Recording complete: see file testrec.wav"
#	file testrec.wav
#	log "scp testrec.wav jdmc2@t510j:"
#   fi
}

# start recording - ignores "state" file.
function start {
  if [ -f $PIDFILE ] ; then
      log "already running as [`cat $PIDFILE`]"
      return 1
  fi

  if [ -f $ALOG ] ;then
      ts=`tstamp`
      newname=${WAVDIR}/arecord-$ts.log
      mv $ALOG $newname
      log "backed up old arecord log file: $ALOG to $newname"
  fi

  # setup environment for arecord to correctly record
  prepare_microphone

  # cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE --max-file-time $MAXDURATION --process-id-file $PIDFILE --use-strftime $WAVDIR/%Y-%m-%d/audio-$SYSNAME-%Y-%m-%d_%H-%M-%S.wav"

  # Argh - max_file_duratino is also broken at the moment in arecord. So remove it for the moment, and hope the watchdog takes care of it.  Once arecord is working again (in 1.0.29, hopefully) we can reintroduce the --max-file-time...
  cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE --process-id-file $PIDFILE --use-strftime $WAVDIR/%Y-%m-%d/audio-$SYSNAME-%Y-%m-%d_%H-%M-%S.wav"

  log "about to run: $cmd"
  $cmd  >& $ALOG &
  retval=$?

  log "startup recording process returned status value of $retval"
  if [ $retval -eq 0 ] ; then
      sleep 1
      log "arecord process started as pid=[`cat $PIDFILE`]"
      # set led flash to "recording"
  else
      log "arecord process failed to start returning error code $retval"
      log "I suppose it'll try again in a minute..."
      # could look for the error here
      # set led flash to "not recording"
  fi

  return $?
}

# stop recording (ignores state file)
function stop {

    if [ ! -f $PIDFILE ] ; then
      log "No pidfile - can't stop anything"
      return 0
    fi

    pid=`cat $PIDFILE`
    # should check that the pid has a wc -w of one.
    log "Stopping (kill - SIGINT) process $pid.."
    kill -s SIGINT $pid
    rogues=`pidof arecord`
    if [ -s "$rogues" ] ; then
	log "WARNING: just killed $pid, but rogues remain : $rogues"
    else
	log "(no rogues)"
    fi
}

# get status back to the user (are we running?)  don't confuse with
# "amon state" which gives contents of "statefile" - what we _should_
# be doing.  If all is well, they match.
function status {
    if [ -f "$PIDFILE" ] ; then
	log "running as pid=[`cat $PIDFILE`]"
    else
	log "not running (no pid file)"
    fi
    # PSOUT=`ps -C arecord -o pid=,comm=`
    # log "ps output is $PSOUT"
}



#############################
### HELPER FUNCTIONS BELOW
#############################

function state {
    getstate
}

function getstate {

    if [ ! -r $STATEFILE ] ; then
	log "Error: no state file exists. I am not fixing it"
       exit -1
    fi

    s=`cat $STATEFILE`

    if [ "$s" = "on" -o "$s" = "off" ] ;then
      echo "$s"
      return 0
    else
      log "Error: unknown state: [$s]. I am _not_ fixing it"
      return 1
    fi
}

function setstateon {
    s=`getstate`

    if [ "$s" = "on" ] ; then
      log "state already [on] => doing nothing"
    else
      echo "on" > $STATEFILE
      log "state changed to [on]"
    fi
}

function setstateoff {
    s=`getstate`

    if [ "$s" = "off" ] ; then
	log "state already [off] => doing nothing"
    else
       echo "off" > $STATEFILE
       log "state changed to [off]"
    fi
}

# write response/log to both logfile and (if it exists) the screen.
function log {
    ts=`tstamp`
    msg="$1"
    lmsg="$ts: [amon[$AMONPID]->${FUNCNAME[1]}]: $msg"  # I've been reading "man bash".

    # could send this to a logfile if something is set...
    echo "$lmsg" >> $AMONLOG

    # if stdin is a tty (interactive session) also print to stdout
    tty -s && echo "$msg"
}

function tstamp {
    date +"%Y-%m-%d_%H-%M-%S"
}

# unlikely to ever be up to date...
function amonhelp {
    echo "---------- HELP: ---------------"
    echo "amon stop - to stop recording"
    echo "amon start - to start recording"
    echo "amon on - turns on desired-state and starts"
    echo "amon off - turns off desired-state and stops"
    echo "amon log - show all log entries"
    echo "amon testrec - perform a test recording into testrec.wav"
    echo "amon ping - see if amon is listening and happy"
    echo "amon deep-clean - deletes all data including logs *CAREFUL*"
    echo "... There are lots more ... TODO"
    echo "--------------------------------"
}

# Show the log file (only useful interactively)
function amonlog {
    less -f $AMONLOG
}

# fun wee ping, just to check all is well.
function amonping {
#    log "amon version : $VERSION"
    log "Ping: response.  Happy."
}

function diskusage {
    str=`df -h $WAVDIR | tail -1`

    log "$str"
}


# This is important - it is run as part of the watchdog every minute.
function amoncleanup {

   # Deal with inconsistent situations
   # there are 2 things to look at - processes, and the pidfile
   # ps can return 0, 1, or multiple instances of arecord
   # pidfile can be either absent, presnetbutempty, havecontents
   # the only situations that are allowed are:
   # pidfile absent AND noprocesses
   # OR
   # 1 process AND pidfile matches single processid.

   # first situation - nopidf and no processes
   numprocs=`countprocs`

   if [ ! -f $PIDFILE -a $numprocs -eq 0 ] ; then
      log "no-op: [stopped] no procs and no procfile."
      return 0
   fi

   # Also OK if pidfile matches ps output.
   if [ -f $PIDFILE ] ; then
     # get a list of the processes and the pid from the file:
     procs=`procids`
     pidf=`cat $PIDFILE`

     # We need the -n clause, because they must match AND be nonzero length
     if [ -n "$pidf" -a "$pidf" = "$procs" ] ; then
       log "no-op: [running] (pidfile [$pidf] matches ps [$procs])."
       return 0
     fi
   fi

   log "We have a problem:  stop/kill all procs and removing pidfile... pidf=$pidf AND procs=$procs"

   # actually do the cleanup.
   # kill all the processes
   log "sending all processes SIGINT"
   killall -s SIGINT arecord
   sleep 1
   log "sending all processes SIGKILL"
   killall -s SIGKILL arecord
   sleep 1
   log "should have killed all processes."

   # remove the pidfile
   if [ -f $PIDFILE ] ; then
       log "removing stale pidfile"
       rm -f $PIDFILE
   fi

   # We took action, so tell caller
   return 1
}

# this is dangerous - clears out all generated files (recordings logs
# etc...)  dont delete everything in $(LOGDIR} cos we loose amon.state
# (the masterswitch) -> the next cronjob creates one by default in the
# "on" position, which aint what we want.
function deep-clean {
    s=`getstate`
    if [ $s != 'off' ] ; then
	log "Refusing to deep-clean, since state is not off (its $s)"
	return 0
    fi

    log "performing deep clean - in 3 seconds.  ctrl-C to cancel..."
    sleep 1
    log "2 ... REMOVING ALL AUDIO AND LOGS"
    sleep 1
    log "1 ... "
    sleep 1

    #rm -rvf *.log testrec.wav ${WAVDIR}/* ${LOGDIR}/*
    rm -rvf *.log testrec.wav ${WAVDIR}/* ${LOGDIR}/{amon.log,arecord.log}

}

# count the number of "arecord" processes running"
function countprocs {
   n=`ps --no-headers -C arecord | wc -l`
   echo $n
}

# print the list of pids of the arecord process
function procids {
  ids=`ps --no-headers -C arecord -o pid | sed 's:^ *::g'`
  echo $ids
}

# remove the wav file that's oldest (memory management)
function deloldest {
    oldest=`find "$WAVDIR" -type f -name \*.wav -printf '%T+ %p\n' | sort | head -n 1 | awk '{print $2}'`
    if [ ! -f ${oldest} ] ; then
	log "MEM: couldn't find a file to delete... giving up."
    fi
    log "MEM: deleting oldest file: $oldest"
    echo "MEM: deleted" > $oldest # zero the length
    mv $oldest $oldest.deleted # move it to new name (not ending in .wav)
    ls -l $oldest.deleted
}

# show the user all the recorded files (and logs)
function amonfind() {
        find $AMONDATA -ls
}

function usage() { # TODO: tidy up: "help", "usage", "amonhelp", "amonusage"
    echo "Usage: amon status|ping|others"
    echo "Usage: amon usage  --- for more help"
}

# for debug
function testargs() {
    echo "testargs here with args: $*"
    echo "bye"
}

# close down things and reboot (called from watchdog if we want it)
function reboot() {
    log "REBOOT: shutting down amon, and rebooting"
    stop
    sync
    sudo reboot
    return 0
}

# this function must return 0 - it mustn't fail.  It wraps the
# calendar_script in error checking, and taking appropriate action -
# we handle all errors here, and don't pass them on
function calendarTarget() {
    log "Checking calendar state..."

    if [ ! -f $CALENDAR_SCRIPT ] ; then
	log "No calendar file: $CALENDAR_SCRIPT - assuming \"on\""
	echo "on"
	return 0
    fi

    if [ ! -x $CALENDAR_SCRIPT ] ; then
	log "found calendar in $CALENDAR_SCRIPT but it's not executable"
	echo "on"
	return 0
    fi


    decision=$($CALENDAR_SCRIPT)
    returnval=$?

    if [ $returnval -ne 0 ] ; then
	log "calendar script didn't return with zero exit status, so giving up on calendar"
	echo "on"
	return 0
    fi

    if [ ${decision} != "yes" -a ${decision} != "no" ] ; then
	log "Calendar script returned invalid answer \"$decision\"  - ignoring"
	echo "on"
	return 0
    fi

    # if we passed all those tests, then we have a valid output from the calendar, and should return it
    log "YAHOO: calendar returned a valid answer \"$decision\" - using it"
    echo "$decision"
    return 0
} # end of calendarTarget()
