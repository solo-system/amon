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


function watchdog {
    #  HACK - ABOUT TO DEPLOY TO FIELD, SO SET STATE TO "ON"
    ## setstateon
    log "-- MARK --"
    s=`getstate`
    log "state=[$s].  Doing a cleanup then setting recording as required."

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
	log "not calling reboot since $hourmin != $NIGHTLYREBOOT"
     fi

} # end of watchdog

# send signal to arecord to split the output file
function amonsplit {
  pid=`cat $PIDFILE`
  kill -USR1  $pid
  log "sent USR1 to pid=$pid"
}

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
    # New microphone here
    if grep sndrpiwsp /proc/asound/cards > /dev/null ; then

	log "detected Cirrus Logic Audio Card => preparing as audio source"
#	if [ "$CLAC_AUDIO_SOURCE" != "linein" ] ; then
#	    log "WARNING: CLAC_AUDIO_SOURCE ($CLAC_AUDIO_SOURCE) not currently supported"
#	fi

	# WARNING : DON'T FIDDLE WITH THE ORDER OF THE
	# reset_paths, record_from_linein_micbias,  here.  Previously 
	# had other setup and it caused a hang: complaining:
	# bmc_2708 DMA transfer could not be stopped. (or similar).
	# The arecord (from amon testrec) hung, output 44 bytes, and 
	# syslog (dmesg) showed above message.

        # /home/pi/Record_from_DMIC.sh >> clac.log 2>&1
        # /home/pi/Record_from_Headset.sh >> clac.log 2>&1
        # /home/pi/Record_from_lineIn.sh >> clac.log 2>&1
	/home/pi/Reset_paths.sh -q  # initialize everything to safe values
	/home/pi/Record_from_lineIn_Micbias.sh -q  # set up for line in.
#	amixer -Dhw:sndrpiwsp cset name='Line Input Switch' off  # turn it off for safety
#	if [ "$CLAC_PIP" != "on" ] ; then
#           log "WARNING: CLAC_PIP ($CLAC_PIP) (plug-in-power) is ON!"
#	   amixer -Dhw:sndrpiwsp cset name='Line Input Switch' on
#        fi

	[ ! $CLAC_VOL ]     && { log "choosing default for CLAC_DIG_VOL" ; CLAC_VOL=31 ;}
	[ ! $CLAC_DIG_VOL ] && { log "choosing default for CLAC_DIG_VOL" ; CLAC_DIG_VOL=160 ;}
	[ ! $CLAC_SAMPLERATE ] && { log "choosing default for CLAC_SAMPLERATE" ; CLAC_SAMPLERATE="-r44100" ;}

	amixer -q -Dhw:sndrpiwsp cset name='IN3L Volume' $CLAC_VOL
	amixer -q -Dhw:sndrpiwsp cset name='IN3R Volume' $CLAC_VOL
	amixer -q -Dhw:sndrpiwsp cset name='IN3L Digital Volume' $CLAC_DIG_VOL
	amixer -q -Dhw:sndrpiwsp cset name='IN3R Digital Volume' $CLAC_DIG_VOL
	SAMPLERATE=$CLAC_SAMPLERATE
	CHANNELS=$CLAC_CHANNELS
	AUDIODEVICE="-Dhw:sndrpiwsp" # override this, cos the above scripts set it all up nicely.
	MMAP=""
	log "prepare_mic: [MICTYPE=CLAC] CHANNELS=$CHANNELS AUDIODEVICE=$AUDIODEVICE MMAP=$MMAP CLAC_VOL=$CLAC_VOL CLAC_DIG_VOL=$CLAC_DIG_VOL CLAC_AUDIO_SOURCE=$CLAC_AUDIO_SOURCE CLAC_PIP=$CLAC_PIP"

    elif [ grep "Snowflake" /proc/asound/cards > /dev/null ] ; then
	log "Detected Blue:Snowflake microphone => preparing as audio source"
	log "setting volume to $VOLUME ..."
	AUDIODEVICE="-D hw:Snowflake"
	amixer $AUDIODEVICE -q -c 1 set "Mic" $VOLUME
	# MMAP="--mmap" # turned this off (may 2015) for no good reason.
    else
	log "ERROR: warning - microphone not recognised."
    fi
}

function testrec {
    log "Performing a test recording [ 3 seconds long ...]"
    prepare_microphone
    cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -d 3 -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE  testrec.wav"
    log "running: $cmd"
    $cmd

    if [ $? -ne 0 ] ; then
	log "testrec: ERROR: something went wrong (arecord already running? \"amon status\" to check)"
    else
	log "Recording complete: see file testrec.wav"
	file testrec.wav
	log "scp testrec.wav jdmc2@t510j:"
    fi
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

  cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE --max-file-time $MAXDURATION --process-id-file $PIDFILE --use-strftime $WAVDIR/%Y-%m-%d/audio-$HOSTNAME-%Y-%m-%d_%H-%M-%S.wav"

  log "about to run: $cmd"
  $cmd  >& $ALOG &
  sleep 1
  log "arecord process started as pid=[`cat $PIDFILE`]"

  return $?
}

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

# get status back to the user (not sure if this is useful
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

function amonlog {
    less -f $AMONLOG
}

function amonping {
#    log "amon version : $VERSION"
    log "Ping: response.  Happy."
}

function diskusage {
    str=`df -h $WAVDIR | tail -1`

    log "$str"
}

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

    rm -rvf *.log testrec.wav ${WAVDIR}/*

}

#function handle-reboot {
#    # TODO = the path names here are HORRIBLE - need to use $BASE etc...
# log "detected a reboot - handling it..."
# log "removing the reboot file..."
# rm -f $REBOOTED
# log "backing up the audio and copying logfiles therein (not really)"
# mv -v ${AMONDATA}/wavs ${AMONDATA}/stack
# mkdir $WAVDIR
# mv -v ${AMONDATA}/stack $WAVDIR/push
#
# log "done handling reboot"
#}

# used during testing to get the most recent audio to hp for listening test.
#function copylast {
#	afile=`find $WAVDIR -type f -name \*.wav | grep -v stack | sort | tail -2 | head -1`
#	ls -l $afile
#	
#	host=$HOSTNAME
#
#	dest=hp
#        if [ "$1" ] ; then
#          dest="$1"
#	fi
#
#	to=$dest:tmpaud/$host/
#	cmd="scp $afile $to"
#	echo "running: $cmd"
#	$cmd
#}

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

function usage() {
    echo "Usage: amon status|ping|others"
    echo "Usage: amon help  --- for more help"
}

function help() {
    echo "Help section for amon."
    echo "unwritten.  Sorry"
    [ -r amon.help ] && cat amon.help
}

function testargs() {
    echo "testargs here with args: $*"
    echo "bye"
}

# close down things and reboot (called from watchdog)
function reboot() {
    log "REBOOT: shutting down amon, and rebooting"
    stop
    sync
    sudo reboot
    return 0
}
