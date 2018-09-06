#!/bin/bash -e

# This file is part of amon (https://github.com/solo-system/amon.git)

# This is a calendar.  
# rules for a calendar:
# It must also return 0 (a clean exit status).
# any info/debug output must go to stderr (and gets logged) Keep
# stdout clean for yes/no answer.  This is what the "1>&2" does below.
# also keep "-e" at the top for extra safety. (this causes bash to
# exit with nonzero exit status if any command anywnere fails).

# Having said all that, the wrapper that calls this handles any bad
# situation, and if this script produces nonsense results, the amon
# assumes recording should continue (or start).

# echo "Calendar script running" 1>&2

# TODO: better to do this in one call, (too lazy to parse that
# though).  gack - the minus signs in the following tell date to "NOT
# PAD". eg the first day of month should not be 01, but just 1.  This
# was causing problems later in the script since numbers with leading
# zeros are interpreted (by bash's arithmetic evaluation) as being in
# octal.  I got these errors in calendar.log:
# /boot/solo/calendar/5m-on-5m-off.sh: line 41: 08: value too great for base (error token is "08")

year=$(date +"%Y")
month=$(date +"%-m")
day=$(date +"%-d")
hour=$(date +"%-H")
minute=$(date +"%-M")

# don't look at seconds - you can't do anything meaningful with
# seconds.  This script is called every minute (at just a few seconds
# after the "top of the clock")
echo "$0: debug: year is $year, month is $month, day is $day, hour is $hour, minute is $minute" 1>&2

# if the clock wrong, we can't do anything meaningful - so assume
# recordings should be "on"
if [ $year -lt 2016 ] ; then
    echo "clock is not set - bailing out" 1>&2
    echo "on"
    exit 0
fi

# only record first 5 minutes of each 10 minutes.
# this logic says : "if remainder of $minute divided by ten is less than 5"
if [ $(($minute % 10)) -lt 5 ] ; then
    echo "on"
    exit 0
fi

echo "off"

# echo "Calendar script finished" 1>&2

# exit cleanly:
exit 0
