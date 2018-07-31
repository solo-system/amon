#!/bin/bash -e

# This file is part of amon (https://github.com/solo-system/amon.git)

# This calendar makes the Solo record 1 hour on, one hour off.
# (the even hours are on, odd hours are off).


datestr=$(date +"%Y %-m %-d %-H %-M %-S")
read year month day hour minute second <<< $datestr

#echo "$0: debug: year is $year, month is $month, day is $day, hour is $hour, minute is $minute" 1>&2

# only record first 5 minutes of each 10 minutes.
# this logic says : "if remainder of $minute divided by ten is less than 5"
if [ $(( $hour % 2 )) == 0 ] ; then
    echo "on"
    exit 0
fi

# We will return "off", so calculate the reboot time (rst)

# get the time in 1 hour in the future, and then zero the mins+secs.
read -a rst <<< $(date  +"%Y %-m %-d %-H 0 0" -d "1 hour")

# munge it: "minutes" rounds to be multiple of ten, and zero the "seconds" element.
rst[4]=$((   ${rst[4]} / 10 * 10   ))
rst[5]=0

# print the output.
echo "off ${rst[@]}"

# echo "Calendar script finished" 1>&2

# exit cleanly:
exit 0
