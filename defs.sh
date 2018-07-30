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
    log ""
    log "-- MARK (wpdev+WITTY) : watchdog starting --"
    log "System load (from /proc/loadavg): $(cat /proc/loadavg)"

    log "watchdog: first thing we do is cleanup()" # (test processes and procfile are in sync)
    amoncleanup
    cleanupcode=$?
    log "amoncleanup() exit status=$cleanupcode (0=noprobs+stopped, 1=noprobs+running, 2=problem: killed everything)"

    if [ $cleanupcode == 2 ] ; then
	log "since amoncleanup() had to kill things, watchdog does nothing more on this pass, watchdog exiting."
	return
    fi
    
    # If mainswitch says off, then turn off, and do no more.
    mainswitch=`getstate`
    if [ $mainswitch = "on" ] ; then
	log "main switch is off, so ensuring we are off"
	stop # strictly, we only need to stop if cleancode is 1 (running)
	log "watchdog finished".
	return
    fi

    # If we get to here: there were no problems (cleanup), and mainswitch is ON.
    calendarDecision=$(calendarTarget)
    read calonoff rst <<< $calendarDecision
    if [ $rst ] ; then
	log "watchdog: Calendar says we should be off with a rst of $rst"
    elif [ $calonoff == "on" ] ; then
	log "watchdog: Calendar says we should be on"
    elif [ $calonoff = "off" ] ; then 
	log "watchdog: Calendar says we should be off (but offers no rst)"
    fi

    # if we should be on, then either start, or consider a split.
    if [ $calonoff = "on" ] ; then # we should be recording
	if [ $cleanupcode == 0 ] ; then  # but we are stopped
	    # Therefore we have to start:
	    log "we are stopped, but we should be started, so starting..."
	    start
	else # we are already recording
	    log "we are recording, as we should be. Consider a split...".
	    # possibly split the audiofile, if the minute-of-day divides $DURATION
	    minute=`date +"%-M"`
	    rem=$(( $minute % $DURATION ))
            [ $rem == 0 ] && amonsplit
	fi
    elif [ $calonoff = "off" ] ; then # we should be stopped
	if [ $cleanupcode == 1 ] ; then  # but we are running.
	    log "watchdog: calonoff is off ($calonoff), but we are running, so stop... "
	    stop
	    log "watchdog: stopped recording"
	    log "TODO: could look to reboot here, but chickening out to next pass"
	else # good - we are not running 
	    log "watchdog: we are off, as we should be - but should we reboot? (TODO)"
	fi
    
#    log "status: state=[$mainswitch], calendarDecision=[$calendarDecision] -> desired-state=[$s]: will cleanup() then make it so."

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

    # # check if we should reboot
    # hourmin=`date +"%H:%M"`
    # if [ $NIGHTLYREBOOT -a $NIGHTLYREBOOT = $hourmin ] ; then
    # 	log "rebooting since $hourmin = $NIGHTLYREBOOT"
    #     reboot
    # else
    # 	# log "not calling reboot since $hourmin != $NIGHTLYREBOOT"
    # 	# those log messages were getting boring.
    # 	true
    #  fi

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

    if  grep "Snowflake" /proc/asound/cards > /dev/null ; then
	MICNAME="Blue:Snowflake"
	AUDIODEVICE="-D hw:Snowflake"
	SNOWFLAKE_VOLUME="100%"
	log "Detected microphone: $MICNAME => preparing as audio source (volume set to $SNOWFLAKE_VOLUME)"
	amixer $AUDIODEVICE -q -c 1 set "Mic" $SNOWFLAKE_VOLUME
    elif grep -q -l -i dodotronic /proc/asound/card*/stream0 2>/dev/null; then
	conf=mics/dodotronic.conf
	log "prepare_mic: Found one of the dodotronic microphone types, sourcing $conf ..."
	. $conf
	log "prepare_mic: AUDIODEVICE=$AUDIODEVICE SAMPLERATE=$SAMPLERATE CHANELS=$CHANNELS ABUFFER=$ABUFFER MMAP=$MMAP"
    elif grep "USB-Audio - Sound Blaster Play! 2" /proc/asound/cards > /dev/null ; then
	MICNAME="soundblasterplay"
	conf=mics/$MICNAME.conf
	if [ -f $conf ] ; then
	    log "Detected microphone: \"$MICNAME\" microphone => reading config file \"$conf\""
	    . mics/$MICNAME.conf
	else
	    log "ERROR: No such mic config file: \"$conf\". Dunno what will happen..."
	fi
	log "prepare_mic: [MICTYPE=$MICNAME] AUDIODEVICE=$AUDIODEVICE SAMPLERATE=$SAMPLERATE CHANELS=$CHANNELS ABUFFER=$ABUFFER MMAP=$MMAP"
    elif grep "USB-Audio - Sound Blaster Play! 3" /proc/asound/cards > /dev/null ; then
	MICNAME="soundblasterplay3"
	conf=mics/$MICNAME.conf
	if [ -f $conf ] ; then
	    log "Detected microphone: \"$MICNAME\" microphone => reading config file \"$conf\""
	    . mics/$MICNAME.conf
	else
	    log "ERROR: No such mic config file: \"$conf\". Dunno what will happen..."
	fi
	log "prepare_mic: [MICTYPE=$MICNAME] AUDIODEVICE=$AUDIODEVICE SAMPLERATE=$SAMPLERATE CHANELS=$CHANNELS ABUFFER=$ABUFFER MMAP=$MMAP"
    elif grep -q "Fe-Pi_Audio" /proc/asound/cards ; then
        MICNAME="fe-pi"
        conf=mics/$MICNAME.conf
        if [ -f $conf ] ; then
            log "Detected microphone: \"$MICNAME\" microphone => reading config file \"$conf\""
            . mics/$MICNAME.conf
        else
            log "ERROR: No such mic config file: \"$conf\". Dunno what will happen..."
        fi
        log "prepare_mic: [MICTYPE=$MICNAME] AUDIODEVICE=$AUDIODEVICE SAMPLERATE=$SAMPLERATE CHANELS=$CHANNELS ABUFFER=$ABUFFER MMAP=$MMAP"
    elif grep RPiCirrus /proc/asound/cards > /dev/null ; then
	
	log "detected Cirrus Logic Audio Card => preparing as audio source"
	
	[ ! $CLAC_VOL ]     && { log "choosing default for CLAC_DIG_VOL" ; CLAC_VOL=31 ;}
	[ ! $CLAC_DIG_VOL ] && { log "choosing default for CLAC_DIG_VOL" ; CLAC_DIG_VOL=128 ;}
	
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
	    /home/amon/clac/Record_from_Linein_Micbias.sh  # with micbias!
	    amixer -q -Dhw:RPiCirrus cset name='IN3L Volume' $CLAC_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN3R Volume' $CLAC_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN3L Digital Volume' $CLAC_DIG_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN3R Digital Volume' $CLAC_DIG_VOL
        elif [ "$CLAC_AUDIO_SOURCE" = "dmic" ] ; then
	    log "setting record source to: $CLAC_AUDIO_SOURCE"
	    /home/amon/clac/Record_from_DMIC.sh  # dmic (onboard MEMS mics)
	    amixer -q -Dhw:RPiCirrus cset name='IN2L Volume' $CLAC_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN2R Volume' $CLAC_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN2L Digital Volume' $CLAC_DIG_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN2R Digital Volume' $CLAC_DIG_VOL
	else
	    log "WARNING: CLAC_AUDIO_SOURCE ($CLAC_AUDIO_SOURCE) not recognised - using default: \"dmic\""
	    /home/amon/clac/Record_from_DMIC.sh
	    amixer -q -Dhw:RPiCirrus cset name='IN2L Volume' $CLAC_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN2R Volume' $CLAC_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN2L Digital Volume' $CLAC_DIG_VOL
	    amixer -q -Dhw:RPiCirrus cset name='IN2R Digital Volume' $CLAC_DIG_VOL
	fi
	
	#	amixer -Dhw:RPiCirrus cset name='Line Input Switch' off  # turn it off for safety
#	if [ "$CLAC_PIP" != "on" ] ; then
#           log "WARNING: CLAC_PIP ($CLAC_PIP) (plug-in-power) is ON!"
#	   amixer -Dhw:RPiCirrus cset name='Line Input Switch' on
#        fi

	AUDIODEVICE="-Dclac"
	MMAP=""
	log "prepare_mic: [MICTYPE=CLAC] CHANNELS=$CHANNELS AUDIODEVICE=$AUDIODEVICE MMAP=$MMAP CLAC_VOL=$CLAC_VOL CLAC_DIG_VOL=$CLAC_DIG_VOL CLAC_AUDIO_SOURCE=$CLAC_AUDIO_SOURCE CLAC_PIP=$CLAC_PIP"
    else
	log "Warning - microphone not recognised -> so not calling prepare_mic() - recording unlikely to work"
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

    # remove the old log and wav file:
    rm -vf ${WAVDIR}/testrec.log ${WAVDIR}/testrec.wav

    # Avoid the watchdog (on the minute mark) - it will kill us.
    while [ $(date +"%S") -gt 50 -o $(date +"%S") -lt 10 ] ; do
	echo "Standby (avoiding watchdog at 0 seconds) ... waiting $(date)"
	sleep 1
    done
    echo "[avoiding watchdog...] ... now safe to do - it's $(date)"

    TESTREC_LEN=3 # record for this many seconds
    log "Performing a test recording [ $TESTREC_LEN seconds long ...]"
    prepare_microphone
    cmd="arecord -d $TESTREC_LEN $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE ${WAVDIR}/testrec.wav"
    log "running: $cmd"
    $cmd >& ${WAVDIR}/testrec.log
    #log "waiting 3 seconds..."
    #sleep 3
    #kill -9 %1
    log "Recording Done - see:"
    log "${WAVDIR}/testrec.wav or ${WAVDIR}/testrec.log"
    ls -l ${WAVDIR}/testrec.wav ${WAVDIR}/testrec.log
    log "testrec finished"

    if [ -n "$2" ] ; then
	# TODO:
	# should check that $2 has a colon at the end, and an @ symbol in it
	# jdmc2@pcs isn't good enough, it just makes a local file called that.
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

# start recording - ignores "state" file. Return:
function start {
  # return: 1 if already runing (no-op)
  # return: 0 if we started (or at least, tried to start).
    
  if [ -f $PIDFILE ] ; then
      log "already running as [`cat $PIDFILE`]"
      return 1
  fi

  if [ -f $ALOG ] ;then
      mkdir -p ${LOGDIR}/old/
      ts=`tstamp`
      newname=${LOGDIR}/old/arecord-$ts.log
      mv -v $ALOG $newname
      log "backed up old arecord log file: $ALOG to $newname"
  fi

  # setup environment for arecord to correctly record
  prepare_microphone

  # cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE --max-file-time $MAXDURATION --process-id-file $PIDFILE --use-strftime $WAVDIR/%Y-%m-%d/audio-$SYSNAME-%Y-%m-%d_%H-%M-%S.wav"

  # Argh - max_file_duratino is also broken at the moment in arecord. So remove it for the moment, and hope the watchdog takes care of it.  Once arecord is working again (in 1.0.29, hopefully) we can reintroduce the --max-file-time...
  cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE --process-id-file $PIDFILE --use-strftime $WAVDIR/%Y-%m-%d/audio-$SYSNAME-%Y-%m-%d_%H-%M-%S.wav"

  log "starting recording with: $cmd"
  $cmd  >& $ALOG &

  # We can't capture the retval and do anything here, because there is
  # no retval for a running process (and we hope arecord is running!).
  # Note: even if it failed, the way we've called (in bg) it prohibits
  # us getting the retval without a "wait ..." of somesuch.  But
  # that's ok, the watchdog will catch any problems next time around.

  # this return 0 is needed to stop amonsplit from running immediately after we start recording.
  # we return with 1 (at the top of this function) if we were already running.

  # but we can at least _look_ to see if the start worked, and show the arecord.log file if it failed:
  sleep 2
  
  if [ -f $PIDFILE ] ; then
      log "recording running running as [`cat $PIDFILE`]"
  else
      log "recording failed to start (no pidfile).  output of arecord.log follows:"
      log "$(cat $ALOG)"
  fi

  # whether we started or not, 0 means we tried. TODO - this could be
  # improved by introducing a third return value for Tried-and-failed,
  # and Tried-and-succeeded.
  return 0 
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
    sleep 1 ; sync #added this 2016-08-28 cos PIDFILE was hanging
		   #around, and the subsequent "status" (called from
		   #watchdog()) was reporting "running".

    rogues=`pidof arecord`
    if [ -n "$rogues" ] ; then
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

    if [ "$1" = '-q' ] ; then
	STDOUT=0
	shift
    else
	STDOUT=1
    fi
    
    ts=`tstamp`
    msg="$1"
    lmsg="$ts: [amon[$AMONPID]->${FUNCNAME[1]}]: $msg"  # I've been reading "man bash".

    # could send this to a logfile if something is set...
    echo "$lmsg" >> $AMONLOG

    # if stdin is a tty (interactive session) also print to stdout - and we aren't in "-q" mode
    [ $STDOUT -eq 1 ] && tty -s && echo "$msg"
}

function tstamp {
    date +"%Y-%m-%d_%H-%M-%S"
}

# unlikely to ever be up to date...
function amonhelp {
    echo "---------- HELP: ---------------------------------------"
    echo "amon ping           - see if amon is listening and happy"
    echo "amon state          - what position is the materswitch?"
    echo "amon status         - are we recording right now?"
    echo "amon log            - show all log entries"
    echo "amon diskusage      - show disk usage"
    echo "amon find           - list all files recorded (and logs)"
    echo "amon stop           - to stop recording"
    echo "amon start          - to start recording"
    echo "amon on             - turns on desired-state and starts"
    echo "amon off            - turns off desired-state and stops"
    echo "amon testrec [addr] - make test recording into testrec.wav [optionally scp to addr]"
    echo "amon deep-clean     - deletes all data including logs *CAREFUL*"
    echo "----------------------------------------------------------"
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
      log "no-op: [stopped and happy] no procs and no procfile. returning 0"
      return 0 # all is clean AND stopped
   fi

   # Also OK if pidfile matches ps output.
   if [ -f $PIDFILE ] ; then
     # get a list of the processes and the pid from the file:
     procs=`procids`
     pidf=`cat $PIDFILE`

     # We need the -n clause, because they must match AND be nonzero length
     if [ -n "$pidf" -a "$pidf" = "$procs" ] ; then
       log "no-op: [running and happy] (pidfile [$pidf] matches ps [$procs]) returning 1"
       return 1 # all is clean AND running
     fi
   fi

   log "We have a problem:  stop/kill all procs and removing pidfile... pidf=$pidf AND procs=$procs and return 2"

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
   sync; sleep 1 # let things settle (this situation is V rare, so no efficienty worries here).
   
   # We took action, so tell caller
   return 2 # there was a problem, so I killed everything.
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

    # could rm all $AMONDATA. but amon.state lives in there. (see note above)
    #rm -rvf *.log testrec.wav ${WAVDIR}/* ${LOGDIR}/*
    rm -rvf *.log testrec.wav ${WAVDIR}/* ${LOGDIR}/{amon.log,arecord.log,calendar.log,cron.log}

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

# show the user all the recorded files (and logs). Sort lexically on filename.
function amonfind() {
    find $AMONDATA -type f -printf '[%12s bytes]: %p\n' | sort -k4
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
# we handle all errors here, and don't bubble them up.
function calendarTarget() {

    if [ -z $CALENDAR ] ; then
	log -q "No calendar: config variable CALENDAR is empty assuming \"on\""
	echo "on"
	return 0
    fi

    # note - all the logging uses -q, so it doesn't go to stdout - we
    # need stout clean for the yes/no answer

    log -q "Checking calendar: $CALENDAR (logged into $LOGDIR/calendar.log)"

    if [ ! -f $CALENDAR ] ; then
	log -q "No such calendar file: $CALENDAR - assuming \"on\""
	echo "on"
	return 0
    fi

# I disabled this, because: what does "executable" mean on a FAT partition (/boot/ is FAT).      
#    if [ ! -x $CALENDAR ] ; then
#	log -q "found calendar in $CALENDAR but it's not executable"
#	echo "on"
#	return 0
#    fi

    # now run the calendar file, grabbing the output.
    decision=$($CALENDAR 2>> $LOGDIR/calendar.log)
    returnval=$?

    if [ $returnval -ne 0 ] ; then
	log -q "calendar script returned nonzero exit status [$returnval][\"$decision\"], so giving up on calendar"
	echo "on"
	return 0
    fi

    # This is new for wittypi - decision might include a reboot time.
    log -q "This is new for wittypi"
    read yesno rst <<< $decision
    log -q "split the decision=\"$decision\" into yesno=\"$yesno\" and rst=\"$rst\". End."
    
    if [ $yesno != "on" -a $yesno != "off" ] ; then
	log -q "Calendar script returned invalid answer \"$decision\"  - ignoring"
	echo "on"
	return 0
    fi

    # if we passed all those tests, then we have a valid output from the calendar, and should return it
    log -q "YAHOO: calendar returned a valid answer \"$decision\" - using it"
    echo "$decision"
    return 0

} # end of calendarTarget()
