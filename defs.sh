### function definitions for amon

function amonon {
    s=$(getstate)
    if [ "$s" = "on" ]; then
	log "already [on], so doing nothing"
	return 0
    fi
    setstateon
    start
}

function amonoff {
    s=$(getstate)
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

    # bail out if we are still booting...
    waitcount=10
    while [ ! -f /tmp/solo-boot.finished -a $waitcount -gt 0 ] ; do
	log "waiting for solo-boot to finish $waitcount secs left..."
	sleep 1
	((waitcount--))
    done
    if [ ! -f /tmp/solo-boot.finished ] ; then
	log "Waited 10 seconds unsuccessfully for /tmp/solo-boot.finished - so giving up."
	log "-- MARK -- : watchdog finished (unsuccessfully)"
	exit 0
    fi
     
    # count the number of watchdogs
    numothers=$(ls -l /tmp/amon* 2>/dev/null | wc -l)
    if [ $numothers -gt 0 ] ; then
	log "[WARNING: there are ($numothers) other watchdogs running]"
	# BAIL OUT here? - might get stuck though with a stale alien
	# lock file.  moreover - I've never seen this occur yet.  Boot
	# clumping of cronjobs seems to be sequential not parallel.
    else
	# log "[Good: there are zero ($numothers) other watchdogs running]"
	true
    fi

    lockfile=/tmp/amon-watchdog-$$.running
    touch $lockfile

    #log "---MARK--- watchdog starting. (locked by: $lockfile, no others running)"
    log "---MARK--- watchdog starting. [load: $(cat /proc/loadavg)]"
    #log "System load (from /proc/loadavg): $(cat /proc/loadavg)"

    # NOTE: this "dollar include" way of logging works - newlines are
    # maintained, but you don't get the timestamps in front of the
    # output in amon.log".  That's why logexec() exists.
    [[ -n "$DEBUG" ]] && logexec "df /boot / /mnt/sdcard/"

    # log "watchdog: first thing we do is cleanup()" # (test processes and procfile are in sync)
    amoncleanup
    cleanupcode=$?
    # log "amoncleanup() exit status=$cleanupcode (0=noprobs+stopped, 1=noprobs+running, 2=problem: killed everything)"

    if [ $cleanupcode == 2 ] ; then
	log "since amoncleanup() had to kill things, watchdog does nothing more on this pass, watchdog exiting."
	rm $lockfile
	log "-- MARK -- : watchdog finished"
	return
    fi
    
    # If mainswitch says off, then turn off, and do no more.
    mainswitch=$(getstate)
    if [ $mainswitch = "off" ] ; then
	log "mainswitch is OFF, so ensuring we are not recording"
	stop # strictly, we only need to stop if cleancode is 1 (running)
	rm $lockfile
	log "-- MARK -- : watchdog finished"
	return
    fi

    # If we get to here: there were no problems (cleanup), and mainswitch is ON.
    calendarDecision=$(calendarTarget)
    # log "calendarDecision returned : \"$calendarDecision\""
    read calonoff rbt <<< $calendarDecision
#    if [ "$rbt" ] ; then
#	log "Our state should be OFF with reboot time of $rbt"
#    elif [ $calonoff == "on" ] ; then
#	log "Our state should be ON"
#    elif [ $calonoff = "off" ] ; then 
#	log "Our state should be OFF (offers no reboot time)"
#    fi

    # This is the main action (4 way choice)
    if [ $calonoff = "on" ] ; then # we should be recording
	if [ $cleanupcode == 0 ] ; then  # but we are stopped
	    # Therefore we have to start:
	    log "we are stopped, but we should be recording, so starting..."
	    start
	else # we are already recording
	    log "All is good: we are recording, just as we should be."
	    # possibly split the audiofile, if the minute-of-day divides $DURATION
	    minute=$(date +"%-M")
	    rem=$(( $minute % $DURATION ))
            [ $rem == 0 ] && amonsplit
	fi
    elif [ $calonoff = "off" ] ; then # we should be stopped
	if [ $cleanupcode == 1 ] ; then  # but we are running.
	    log "we are running, but we should be stopped, so stop... "
	    stop
	else
	    log "All is good: we are stopped, just as we should be."
	fi
	
	if [ $WITTYPI == "yes" -a "$rbt" ] ; then
	    currentuptime=$(cut -f1 -d'.' /proc/uptime)
	    if [ $currentuptime -lt 180 ] ; then
		log "Refusing to shutdown: 180 sec min (uptime=$currentuptime)"
	    else
		log "Wittypi: setting reboot time to rbt=$rbt"
		sudo /home/amon/amon/wp.sh setrbt $rbt
		# sudo /home/amon/amon/wp.sh status
		log "Wittypi: syncing discs"
		sync ; sync # good ol' fasioned paranoia.
		log "Wittypi: *** Calling shutdown now: Bye. ***"
		sudo /home/amon/amon/wp.sh shutdown
		# change the above to shutdown-prep.
		# call the actual shutdown ourselves.
		# sudo poweroff.
	    fi # currentuptime check
	fi # wittypi and rbt
    fi # calonoff = "off"

    status # print status for the log

    # log "MEM: Performing memory management"
    DO_MEM_STUFF=no
    if [ $DO_MEM_STUFF != "no" ] ; then
      freek=$(df -k /mnt/sdcard | tail -1 | awk '{print $4}')
      if [ ${freek} -lt ${MINMEMFREE} ] ; then
          log "MEM: too little free space (${freek} < ${MINMEMFREE}) => calling deloldest()"
          deloldest
      else
          log "MEM: plenty of free space (${freek} > ${MINMEMFREE}) => doing nothing"
      fi
    fi # end of "if DO_MEM_STUFF"

    rm $lockfile
    [ "$DEBUG" ] && log "removed lockfile"

    # log "-- MARK -- : watchdog finished (removed $lockfile) --"
    log "-- MARK -- : watchdog finished."

} # end of watchdog

# send signal to arecord to split the output file
function amonsplit {

    if [ ! -f $PIDFILE ] ; then
	log "No pidfile - can't do amonsplit"
	return 0
    fi

    pid=$(cat $PIDFILE)
    kill -USR1  $pid
    log "Sent split signal [USR1] to arecord process [pid=$pid]"
}

# show the configuration options. (this is not useful)
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

    # I _think_ the arecord cmd line needs format,channnels,rate.
    # all other setup needs done inside the mic's setup file (eg vol).
    # if it appears in /proc/asound/card0/stream0 -> arecord needs it
    # however, if it appears in amixer, do it in the mic setup file.

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
    
    s=$(getstate)
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
	# should check that $2 has a colon at the end, and an @ symbol in it
	# jdmc2@pcs isn't good enough, it just makes a local file called that.
	log "copying to $2 - running scp..."
	scp ${WAVDIR}/testrec.wav $2
    fi
    
}

# start recording - ignores "state" file. Return:
function start {
  # return: 1 if already runing (no-op)
  # return: 0 if we started (or at least, tried to start).
    
  if [ -f $PIDFILE ] ; then
      log "already running as [$(cat $PIDFILE)]"
      return 1
  fi

  if [ -f $ARECLOG ] ;then
      mkdir -p ${LOGDIR}/old/
      ts=$(tstamp)
      newname=${LOGDIR}/old/arecord-$ts.log
      mv $ARECLOG $newname
      log "backed up old arecord log file: $ARECLOG to $newname"
  fi

  # setup environment for arecord to correctly record
  prepare_microphone

  cmd="arecord $ABUFFER $MMAP $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE --process-id-file $PIDFILE --use-strftime $WAVDIR/%Y-%m-%d/audio-$SYSNAME-%Y-%m-%d_%H-%M-%S.wav"

  log "starting recording with: $cmd"
  $cmd  >& $ARECLOG &

  # We can't capture the retval and do anything here, because there is
  # no retval for a running process (and we hope arecord is running!).
  # Note: even if it failed, the way we've called (in bg) it prohibits
  # us getting the retval without a "wait ..." of somesuch.  But
  # that's ok, the watchdog will catch any problems next time around.

  sleep 2
  
  if [ -f $PIDFILE ] ; then
      log "recording running running as [$(cat $PIDFILE)]"
  else
      log "recording failed to start (no pidfile).  output of arecord.log follows:"
      log "$(cat $ARECLOG)"
  fi

  # whether we started or not, 0 means we tried. This could be
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

    pid=$(cat $PIDFILE)
    # should check that the pid has a wc -w of one.
    log "Sending a split signal first (so we don't leave bad header on last meaningful wav file)"
    kill -USR1  $pid
    # perhaps sleep here? (yes - it failed without a sleep.  Try 1s...)
    sleep 1
    log "Stopping (kill - SIGINT) process $pid.."
    kill -s SIGINT $pid
    sleep 1 ; sync #added this 2016-08-28 cos PIDFILE was hanging
		   #around, and the subsequent "status" (called from
		   #watchdog()) was reporting "running".

    rogues=$(pidof arecord)
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
	log "arecord is running as pid=[$(cat $PIDFILE)]"
    else
	log "arecord is not running (no pid file)"
    fi
    # PSOUT=$(ps -C arecord -o pid=,comm=)
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

    s=$(cat $STATEFILE)

    if [ "$s" = "on" -o "$s" = "off" ] ;then
      echo "$s"
      return 0
    else
      log "Error: unknown state: [$s]. I am _not_ fixing it"
      return 1
    fi
}

function setstateon {
    s=$(getstate)

    if [ "$s" = "on" ] ; then
      log "state already [on] => doing nothing"
    else
      echo "on" > $STATEFILE
      log "state changed to [on]"
    fi
}

function setstateoff {
    s=$(getstate)

    if [ "$s" = "off" ] ; then
	log "state already [off] => doing nothing"
    else
       echo "off" > $STATEFILE
       log "state changed to [off]"
    fi
}

# write response/log to both logfile and (if it exists) the screen.
function log {

    if [ ! -f $AMONLOG ] ; then
	echo "WARN: log(): $(tstamp):  there is no amonlogfile: $AMONLOG"
	echo "WARN: log(): I was asked to log the message: \"$1\""
#	echo "ERROR: I _think_ this happens just as we call shutdown (does that make sense? - time=$(tstamp))"
	# don't bail out here - good to continue to see the "no such file" complaints from below.
    fi

    if [ "$1" = '-q' ] ; then
	STDOUT=0
	shift
    else
	STDOUT=1
    fi
    
    ts=$(tstamp)
    msg="$*"
    lmsg="$ts: [amon[$AMONPID]->${FUNCNAME[1]}]: $msg"  # I've been reading "man bash".

    # if we have a log file, write to it.
    if [ -f $AMONLOG ] ; then
	echo "$lmsg" >> $AMONLOG
    fi
    
    # if stdin is a tty (interactive session) also print to stdout - and we aren't in "-q" mode
    [ $STDOUT -eq 1 ] && tty -s && echo "$msg"
}

# properly log the output of external commands, throug a while loop calls to log()
function logexec {
    #shift
    local cmd="$*"
    log "about to run cmd=\"$cmd\""
    $cmd | while read line ; do log "$line" ; done
    log "finished running cmd=\"$cmd\""
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
    str=$(df -h $WAVDIR | tail -1)

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
   numprocs=$(countprocs)

   if [ ! -f $PIDFILE -a $numprocs -eq 0 ] ; then
      log "no-op: [stopped and happy] no procs and no procfile. returning 0"
      return 0 # all is clean AND stopped
   fi

   # Also OK if pidfile matches ps output.
   if [ -f $PIDFILE ] ; then
     # get a list of the processes and the pid from the file:
     procs=$(procids)
     pidf=$(cat $PIDFILE)

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
    s=$(getstate)
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
    rm -rvf *.log testrec.wav ${WAVDIR}/* ${LOGDIR}/{amon.log,arecord.log,calendar.log,cron.log} ${LOGDIR}/old/arecord-*.log

    # make an empty log file - log() gets hysterical without an amon.log:
    touch ${LOGDIR}/amon.log

    # and make the first log entry:
    log "re-created empty log file after deep-clean"
}

# count the number of "arecord" processes running"
function countprocs {
   n=$(ps --no-headers -C arecord | wc -l)
   echo $n
}

# print the list of pids of the arecord process
function procids {
  ids=$(ps --no-headers -C arecord -o pid | sed 's:^ *::g')
  echo $ids
}

# remove the wav file that's oldest (memory management)
function deloldest {
    oldest=$(find "$WAVDIR" -type f -name \*.wav -printf '%T+ %p\n' | sort | head -n 1 | awk '{print $2}')
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

    # note - all the logging uses -q, so it doesn't go to stdout - we
    # need stout clean for the yes/no answer

    if [ -z "$CALENDAR" ] ; then
	log -q "No calendar specified.  So default to \"on\"."
	echo "on"
	return 0
    fi

    if [ ! -f "$CALENDAR" ] ; then
	log -q "WARNING: No such calendar: \"$CALENDAR\".  So default to \"on\"."
	echo "on"
	return 0
    fi
    
    #log -q "Checking calendar: $CALENDAR (output logged into $LOGDIR/calendar.log)"

    # now run the calendar file, grabbing the output.
    decision=$($CALENDAR 2>> $LOGDIR/calendar.log)
    returnval=$?

    if [ $returnval -ne 0 ] ; then
	log -q "Warning: probem with calendar: $CALENDAR (see log in $LOGDIR/calendar.log)"
	log -q "calendar script returned nonzero exit status [$returnval][\"$decision\"], so giving up on calendar"
	echo "on"
	return 0
    fi

    # This is new for wittypi - decision might include a reboot time, so split it.
    read onoff rbt <<< $decision

    if [ $onoff != "on" -a $onoff != "off" ] ; then
	log -q "Warning: probem with calendar: $CALENDAR (see log in $LOGDIR/calendar.log)"
	log -q "Calendar must return yes/no as first token. Invalid: \"$decision\"  (assuming \"on\")"
	echo "on"
	return 0
    fi

    # Logging: See if the calendar returned a reboot time.
    if [ "$rbt" ] ; then
	log -q "Calendar's verdict is: \"$onoff\" with rbt=\"$rbt\" [$CALENDAR]"
	if [ "$WITTYPI" != yes ]; then
	    log -q "WARNING: Calendar returned reboot time for nonexistent Witty Pi - ignoring rbt"
	    log -q "WARNING: See calendar log in $LOGDIR/calendar.log"
	fi
    else
	log -q "Calendar's verdict is: \"$onoff\" [$CALENDAR]"
	if [ $onoff = "off" -a "$WITTYPI" = yes ]; then
	    log -q "WARNING: Calendar failed to provide a reboot time for the Witty Pi.  So stopping, but not shutting down"
	    log -q "WARNING: See calendar log in $LOGDIR/calendar.log"
	fi
    fi
    

    # if we passed all those tests, then we have a valid output from the calendar, and should return it
    # log -q "calendar returned a valid answer \"$decision\" - using it"
    echo "$decision"
    return 0

} # end of calendarTarget()

function checkwav() {

    if [ $# -ne 1 ] ; then
	log "error: checkwav takes 1 filename argument"
	return -1
    fi

    log "would check file \"$1\""

    ls -l "$1"

    log "should incorporate the details from hd.sh here TODO"

    log "checkwav finished"
}

function wavdump(){


    if [ "$2" ] ; then
	file=$2
    else
	file=$(find $AMONDATA -type f -printf '[%12s bytes]: %p\n' | sort -k 4  | awk '{print $4}' | tail -2 | head -1)
    fi
    
    log "about to wavdump.sh $file"
    /home/amon/amon/wavdump.sh $file
    log "Done: to wavdump.sh $file"

}

