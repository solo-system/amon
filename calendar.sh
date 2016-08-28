#!/bin/bash -e

# this is a sample "calendar.sh" script.  It must print on or off and nothing else.
# It must also return 0 (a clean exit status).
# any info/debug output must go to stderr (and gets logged).  Keep
# stdout clean for yes/no answer.  This is what the "1>&2" does.
# also keep "-e" at the top for extra safety.
# (this causes bash to exit with nonzero exit status if any command anywnere fails).

# Having said all that, the wrapper that calls this handles any bad
# situation, and if this script produces nonsense results, the amon
# assumes recording should continue (or start).

# echo "Calendar script running" 1>&2

year=$(date +"%Y")
month=$(date +"%m")
day=$(date +"%d")
hour=$(date +"%H")
minute=$(date +"%M")

# if the clock isn't set, we can't do anything meaningful - so assume
# recordings should be "on"
if [ $year -lt 2016 -o $month -lt 6 ] ; then
    echo "clock is not set - bailing out" 1>&2
    echo "on"
    exit 0
fi

# this causes early bail out - this should not be trusted as a return value
#grep xxxxxxxxxxxxxxxxxx /etc/passwd

# seconds are not meaningful.  onoff runs every minute, so seconds are
# not viable.

echo year is $year, month is $month, day is $day, hour is $hour, minute is $minute 1>&2

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

# echo "Calendar script finished" 1>&2

# exit cleanly:
exit 0
