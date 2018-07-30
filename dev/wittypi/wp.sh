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
. $my_dir/utilities.sh

# unload the rtc from /dev if it's there.
if [ -e /dev/rtc ] ; then
  unload_rtc
fi

function JCrbt_set(){
    shift
    echo JCrbt_set: reboot time sought is: $*
    echo "about to set_startup_time date=$2 hour=$3 minute=$4 second=$4"
#    set_startup_time 
}


JCbounce()
{
    echo "JCBounce() here: lets bounce back in 1 minute:"

    # get the datetime in 2 minutes in UTC
    rbt=$(date -u -d "1 minute" +"%d %H:%M:%S")
    IFS=' ' read -r date timestr <<< "$rbt"
    IFS=':' read -r hour minute second <<< "$timestr"

    echo "Bounce: will be back on: $date at: $hour:$minute:$second (UTC)"
    
    set_startup_time $date $hour $minute $second
    
    do_shutdown 4 17 0
}

reset_startup_time()
{
    log '  Clearing auto startup time...' '-n'
    clear_startup_time
    log ' done :-)'
}

reset_shutdown_time()
{
    log '  Clearing auto shutdown time...' '-n'
    clear_shutdown_time
    log ' done :-)'
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
    systime='>>> Your system time is: '
    systime+="$(get_sys_time)"
    echo "$systime"

    # output RTC time
    rtctime='>>> Your RTC time is:    '
    rtctime+="$(get_rtc_time)"
    echo "$rtctime"

    sut=$(get_startup_time) # ; supl=$(get_local_date_time "$sdt")
    echo "INFO:. Schedule next startup [$sut]"
    exit
elif [ "$1" == "setrbt" ] ; then
    # call JCrbt_set
    echo "calling JCrbt_set with $# args"
    JCrbt_set $*
    echo "done calling JCrbt_set"
else    
    echo "command line not recognised. (try: status, bounce)"
    exit
fi

echo "At end of wp.sh ... exiting"
exit
