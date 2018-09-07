#!/bin/bash -e

# This file is a Solo Calendar
# This file is part of amon (https://github.com/solo-system/amon.git)
# see readme.txt for info on calendars

# This calendar records for 5 mins, then off for 5 mins.

datestr=$(date +"%Y %-m %-d %-H %-M %-S")
read year month day hour minute second <<< $datestr

# This is the main decision: only record first 5 minutes of each 10 minutes.
# this logic says : "if remainder of $minute divided by ten is less than 5"
if [ $(( $minute % 10 )) -lt 5 ] ; then
    echo "$datestr: we are in first 5 mins of 10, so calendar returning ON" 1>&2
    echo "on"
    exit 0
fi

# We will return "off", so calculate the reboot time (rst)
# The time 10 mins into future is:
read -a rst <<< $(date  +"%Y %-m %-d %-H %-M %-S" -d "10 minutes")

# "minutes" rounds to be multiple of ten, and zero the "seconds" element.
rst[4]=$((   ${rst[4]} / 10 * 10   ))  # round down minutes
rst[5]=0                               # clear out the seconds

# print the output and debug
echo "off ${rst[@]}"
echo "$datestr: we are in second 5 mins of 10, so calendar returning OFF with reboot time of ${rst[@]}" 1>&2

exit 0

############################
# NOTE: gack - the minus signs in the following tell date to "NOT
# PAD". eg the first day of month should not be 01, but just 1.  This
# was causing problems later in the script since numbers with leading
# zeros are interpreted (by bash's arithmetic evaluation) as being in
# octal.  I got these errors in calendar.log:
# /boot/solo/calendar/5m-on-5m-off.sh: line 41: 08: value too great for base (error token is "08")
# 10#08 solves the base problem (yuk).

# if the clock wrong, we can't do anything meaningful - so assume
# recordings should be "on"
#if [ $year -lt 2018 ] ; then
#    echo "clock is not set - bailing out" 1>&2
#    echo "on"
#    exit 0
#fi
