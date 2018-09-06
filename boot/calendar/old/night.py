#!/usr/bin/python
import datetime
import sys

### This file is part of www.solo-system.org
### Calendar example written in python
# this calendar is for "night" recording : between 9pm and 6am

# get the date and time
t = datetime.datetime.now()

# a single line of debug (to stderr)
print >> sys.stderr, "night.py: debug: year=%d, month=%d, day=%d, hour=%d, minute=%d." % (t.year, t.month, t.day, t.hour, t.minute)

# if hour is after nine, or before 6, then ON
if t.hour >= 21 or t.hour < 6 :
    print "on"
else:
    print "off"

