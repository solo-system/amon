#!/bin/bash -e

# This file is a Solo Calendar
# This file is part of amon (https://github.com/solo-system/amon.git)
# see readme.txt for info on calendars

# Turn recording "on" for the even numbered hours, off otherwise.

datestr=$(date +"%Y %-m %-d %-H %-M %-S")
read year month day hour minute second <<< $datestr

# if the hour is even, return "on"
if [ $(( $hour % 2 )) == 0 ] ; then
    echo "$datestr: we are in first 5 mins of 10, so calendar returning ON" 1>&2
    echo "on"
    exit 0
fi

# We will return "off", so calculate the reboot time (rbt):
# get the time 1 hour in the future, zeroing the mins+secs.
read -a rbt <<< $(date  +"%Y %-m %-d %-H 0 0" -d "1 hour")

# print the output and the reboot time:
echo "off ${rbt[@]}"
echo "$datestr: we are in second 5 mins of 10, so calendar returning OFF with reboot time of ${rst[@]}" 1>&2

exit 0

#############################
# Notes:
# "read -a" does a "read into an array.  the "<<<" is a "here-file"
# the rbt we return is a 6-tuple of y m d h m s
# to print the whole array : ${rbt[@]} expands to be that
