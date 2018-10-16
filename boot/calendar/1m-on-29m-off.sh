#!/bin/bash -e

# This file is a Solo Calendar
# This file is part of amon (https://github.com/solo-system/amon.git)
# see readme.txt for info on calendars

# on for 1 minute, off for 29 minutes.

# NOTE: This calendar is not suitable for witty pi - the "on" time is
# too short (by the time it's booted, its shutdown time again).  Such
# a calendar is not impossible, but it needs to be cleverer than this
# one is.

datestr=$(date +"%Y %-m %-d %-H %-M %-S")
read year month day hour minute second <<< $datestr

# if the hour is even, return "on"
if [ $minute = 0 -o $minute = 30 ] ; then
    echo "$datestr: minute is 0 or 30, so calendar returning ON" 1>&2
    echo "on"
    exit 0
fi

# print the output (WITHOUT a reboot time - we aren't that clever):
echo "$datestr: minute is neither 0 nor 30, so calendar returning OFF" 1>&2
echo "off"

exit 0
