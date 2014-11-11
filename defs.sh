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
    freek=`df -k /mnt/sdcard | tail -1 | awk '{print $4}'`
    if [ ${freek} -lt ${MINMEMFREE} ] ; then 
        log "MEM: too little free space (${freek} < ${MINMEMFREE}) => calling deloldest()"
        deloldest
    else
        log "MEM: plenty of free space (${freek} > ${MINMEMFREE}) => doing nothing"
    fi

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

  log "setting volume to $VOLUME"
  amixer -q -c 1 set "Mic" $VOLUME

  cmd="arecord $ABUFFER --mmap $AUDIODEVICE -v --file-type wav -f $AUDIOFORMAT $CHANNELS $SAMPLERATE --max-file-time $MAXDURATION --process-id-file $PIDFILE --use-strftime $WAVDIR/%Y-%m-%d/audio-$HOSTNAME-%Y-%m-%d_%H-%M-%S.wav"

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
      log "Error: unknown state: [$s]. I am notfixing it"
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
    lmsg="$ts: [amon[$AMONPID]->${FUNCNAME[1]}]: $msg" 

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
    echo "unwritten. sorry."
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

    rm -rvf *.log ${WAVDIR}/*

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

# function amondiff {
#   log "Diff here!"
#
# #    SERVER=jdmc2.com
#     if [ "$1" ] ; then 
# 	SERVER="$1"
# 	log "comparing with $SERVER"
#     fi
#
#     log "comparing with $SERVER ...  Enter password only if you are sure"
#
#     scp -p jdmc2@$SERVER:code/amon/amon ./amon.download
#     scp -p jdmc2@$SERVER:code/amon/defs.sh ./defs.sh.download
#     scp -p jdmc2@$SERVER:code/amon/amon.php ./amon.php.download
#
#     log "Diff amon (local -- remote):"
#     diff amon amon.download
#
#
#     log "Diff defs.sh (local -- remote):"
#     diff defs.sh defs.sh.download
#
#     log "Diff amon.php (local -- remote):"
#     diff amon.php amon.php.download
#
#     rm -f *.download
#     log "done"
# }

# function update {

#     SERVER=jdmc2.com
#     if [ "$1" ] ; then 
# 	SERVER="$1"
# 	log "updating from $SERVER"
#     fi

#     log "updating from $SERVER ...  Enter password only if you are sure"

#     # backup the originals 
#     mvv amon
#     mvv defs.sh
#     mvv amon.php

#     scp -p jdmc2@$SERVER:code/amon/amon .
#     scp -p jdmc2@$SERVER:code/amon/defs.sh .
#     scp -p jdmc2@$SERVER:code/amon/amon.php .

#     cp amon.php ../public_html/utils/

#     V=`grep "VERSION=" amon | head -1`
#     log "update Complete (to amon version: $V)"
#     log "done"
# }

# function amonmerge {
#     log "merge here!"

#     SERVER=jdmc2.com
#     if [ "$1" ] ; then 
# 	SERVER="$1"
#     fi

#     log "Merging with $SERVER ..."

#     scp -p amon.conf jdmc2@$SERVER:code/amon/amon.conf
#     scp -p amon jdmc2@$SERVER:code/amon/amon
#     scp -p defs.sh jdmc2@$SERVER:code/amon/defs.sh 
#     scp -p /home/jdmc2/public_html/utils/amon.php jdmc2@$SERVER:code/amon/amon.php
#     log "merge complete"
# }

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
