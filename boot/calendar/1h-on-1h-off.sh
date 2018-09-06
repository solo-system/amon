#!/bin/bash -e

# This file is a Solo Calendar
# This file is part of amon (https://github.com/solo-system/amon.git)

# 
# Turn recording "on" for the even numbered hours, off otherwise.
#

datestr=$(date +"%Y %-m %-d %-H %-M %-S")
read year month day hour minute second <<< $datestr

if [ $(( $hour % 2 )) == 0 ] ; then
    echo "on"
    exit 0
fi

# We will return "off", so calculate the reboot time (rbt):
# get the time 1 hour in the future, with zeroes for mins+secs.
read -a rbt <<< $(date  +"%Y %-m %-d %-H 0 0" -d "1 hour")

# print the output and the reboot time:
echo "off ${rbt[@]}"

exit 0

# Notes:
# "read -a" does a "read into an array.  the "<<<" is a "here-file"
# the rbt we return is a n-tuple of y m d h m s
# to print the whole array : ${rbt[@]} expands to be that
