#!/bin/bash -e

year=$(date +"%Y")
month=$(date +"%m")
day=$(date +"%d")
hour=$(date +"%H")
minute=$(date +"%M")

# if the clock isn't set, we can't do anything meaningful - so assume
# recordings should be "on"
if [ $year -lt 2016 -o $month -lt 6 ] ; then
    # (>&2 echo "clock is not set - bailing out")
    echo "on"
    exit 0
fi

# this causes early bail out - this should not be trusted as a return value
#grep xxxxxxxxxxxxxxxxxx /etc/passwd

# seconds are not meaningful.  onoff runs every minute, so seconds are
# not viable.

# ( >&2 echo year is $year, month is $month, day is $day, hour is $hour, minute is $minute)

# in Bash - the following integer compare operatiors:
# -lt is less    than, -le is "less than or equal to"
# -gt is greater than, -ge is "greater than or equal to"
# -eq is equal

# only record first 5 minutes of each 10 minutes.
if [ $(($minute % 10)) -lt 5 ] ; then
    echo "on"
    exit 0
fi

echo "off"
exit 0
