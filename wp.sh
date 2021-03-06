#!/bin/bash

# must be root
if [ "$(id -u)" != 0 ]; then
  echo 'Sorry, you need to run this script with sudo'
  exit 1
fi

# include utilities script in same directory
my_dir_tmp="`dirname \"$0\"`"
my_dir="`( cd \"$my_dir_tmp\" && pwd )`"
if [ -z "$my_dir" ] ; then
  exit 1
fi
. $my_dir/wp-utils.sh

# unload the rtc from /dev if it's there.
if [ -e /dev/rtc ] ; then
    echo "wp.sh is about to unload /dev/rtc0"
    unload_rtc
fi

function JCrbt_set(){
    if [ $# -ne 6 ] ; then
	echo "JCrbt_set ERROR: didn't get 6 args. Exiting"
	exit -1
    fi
    echo "JCrbt_set: reboot time sought is: $*"
    echo "JCrbt_set: about to set_startup_time date=$3 hour=$4 minute=$5 second=$6"
    set_startup_time $3 $4 $5 $6
    echo "JCrbt_set: done - now check it.."
    sut=$(get_startup_time)  ; supl=$(get_local_date_time "$sut")
    echo "JCrbt_set: next reboot time is: sut=[$sut] supl=[$supl]"
}


function JCbounce()
{
    echo "JCBounce() here: lets bounce back in 1 minute:"

    # get the datetime in 2 minutes in UTC
    rbt=$(date -u -d "1 minute" +"%d %H:%M:%S")
    IFS=' ' read -r date timestr <<< "$rbt"
    IFS=':' read -r hour minute second <<< "$timestr"

    echo "JCbounce: will be back on: $date at: $hour:$minute:$second (UTC)"
    
    set_startup_time $date $hour $minute $second

    sut=$(get_startup_time)  ; supl=$(get_local_date_time "$sut")
    echo "JCbounce: next reboot time is: sut=[$sut] supl=[$supl]"
    
    do_shutdown 4 17 0
}

reset_startup_time()
{
#    log '  Clearing auto startup time...' '-n'
    clear_startup_time
#    log ' done :-)'
}

reset_shutdown_time()
{
#    log '  Clearing auto shutdown time...' '-n'
    clear_shutdown_time
#    log ' done :-)'
}

reset_all()
{
    reset_startup_time
    reset_shutdown_time
    delete_schedule_script
}

reset_data()
{
    echo 'Here you can reset some data:'
    echo '  [1] Clear scheduled startup time'
    echo '  [2] Clear scheduled shutdown time'
    echo '  [3] Stop using schedule script'
    echo '  [4] Perform all actions above'
    read -p "Which action to perform? (1~4) " action
    case $action in
        [1]* ) reset_startup_time;;
        [2]* ) reset_shutdown_time;;
        [3]* ) delete_schedule_script;;
        [4]* ) reset_all;;
        * ) echo 'Please choose from 1 to 4';;
    esac
}


# MAIN loop is below, but if command line arg is "bounce" then bounce.
if [ "$1" == "bounce" ] ; then
    JCbounce
elif [ "$1" == "status" ] ; then
    systime="$(get_sys_time)"
    rtctime="$(get_rtc_time)"
    echo "System time is: $systime"
    echo "RTC time is   : $rtctime"
    
    sut=$(get_startup_time)
    supl=$(get_local_date_time "$sut")
    echo "Startup time is: [$sut] [$supl]"
    exit
elif [ "$1" == "setrbt" ] ; then
    # call JCrbt_set
    shift
    if [ $# -ne 6 ] ; then
	echo "wp.sh[setrbt] ERROR: didn't get 6 args. Exiting"
	exit -1
    fi

    # ensure the shutdown timer is disabled (we never use it).
    reset_shutdown_time
    
    echo "wp.sh[setrbt]: calling JCrbt_set with $# args"
    JCrbt_set $*
    echo "wp.sh[setrbt]: done calling JCrbt_set"
elif [ "$1" == "shutdown" ] ; then
    # do the shutdown
    echo "wp.sh[shutdown]: calling JCrbt_set with $# args"
    do_shutdown 4 17 0
elif [ "$1" == "reset" ] ; then
    # reset the timer (only need to worry about the shutdown timer.
    echo "wp.sh[reset()]: calling reset_shutdown_time"
    reset_shutdown_time
    echo "wp.sh[reset()]: finished calling reset_shutdown_time"
else    
    echo "command line not recognised. (try: status, bounce)"
    exit
fi

echo "At end of wp.sh ... exiting"
exit
