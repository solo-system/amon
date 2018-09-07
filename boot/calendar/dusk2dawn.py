#!/usr/bin/python3

# This file is a Solo Calendar
# This file is part of amon (https://github.com/solo-system/amon.git)
# see readme.txt for info on calendars

# This calendar records from dusk until dawn

# Please prescribe the latitude and longitude of your solo deployment in this calendar.
# Also optionally prescribe a "fringe" in minutes which starts the
# recording earlier, and stops it later.
# sophisticated users may fiddle with pressure and horizon too, which affect the dusk/dawn timings.

# to test it, just run it (on your desktop) - it is stand alone.

import datetime
import sys
import ephem # for sunrise and sunset times. (pip install pyephem)
from datetime import timedelta
from datetime import timezone

# The solo's latitude and longitude: 
lat = '55.9667'; lon = '-3.2167'   # Edinburgh (GMT / BST) GMT+0
#lat = '34.0522'; lon = '-118.2437' # LA (PST /PDT) GMT-8
#lat = '42.3601'; lon = '-71.0589'  # Boston (EST / EDT) GMT-5

fringe=30 # pre-dusk and post-dawn extension in minutes.

# what is the output format we hand back to amon?
dateformat="%Y-%m-%d %H:%M:%S %Z" # for debug in stderr
returnformat="%Y %m %d %H %M %S" # what we return on stdout

# what time is it right now?
utcnow=datetime.datetime.utcnow().replace(tzinfo=timezone.utc)
print("\ndusk2dawn.py Started lat=%s lon=%s fringe=%s (time-now: %s)" % (lat, lon, fringe, utcnow.strftime(dateformat)), file=sys.stderr)

sun = ephem.Sun() # which astro-object are we interested in?

# set up the observer, at the SOLO's location.
solobox = ephem.Observer()
solobox.lat = lat ; solobox.lon = lon;

#solobox.pressure = 0 # atmospheric dispersion?
#solobox.horizon = '0.0' # degrees(?) raise the horizon for later dawn, earlier dusk.

# calculate the next rising/setting sun time (in UTC)
#   - call next_rising() to get the event time in UTC
#   - ... convert to python's datetime structure.
#   - ... and then explicitly setting timezone to "utc"
srise = solobox.next_rising(sun).datetime().replace(tzinfo=timezone.utc) 
sset  = solobox.next_setting(sun).datetime().replace(tzinfo=timezone.utc) 

fringetd = timedelta(minutes=fringe)
if (fringe != timedelta(minutes=0) ): print("WARNINIG: fringes might not work - it's UNTESTED", file=sys.stderr)

sriseb = srise - fringetd
ssetb = sset + fringetd

sriseblt = sriseb.astimezone()
ssetblt = ssetb.astimezone()

print("sunrise: pure=%s with-fringe=%s local=%s" % (srise.strftime(dateformat), sriseb.strftime(dateformat), sriseblt.strftime(dateformat)), file=sys.stderr)
print("sun set: pure=%s with-fringe=%s local=%s" % (sset.strftime(dateformat), ssetb.strftime(dateformat), ssetblt.strftime(dateformat)), file=sys.stderr)

if (srise < sset):
    waittime = sriseb - utcnow
    print('Decision: sun-rise is next (in %s) at %s, so it\'s currently night -> we should be ON' % (waittime, sriseblt.strftime(dateformat)), file=sys.stderr)
    print("on")
else:
    waittime = ssetb - utcnow
    print('Decision: sun-set is next (in %s) at %s, so it\'s currently day -> we should be OFF, rebooting at sunset' % (waittime, ssetblt.strftime(dateformat)) ,file=sys.stderr)
    print('off %s' % ssetblt.strftime(returnformat))

print("dusk2dawn.py Finished" ,file=sys.stderr)

########################
# Notes:
# can we get lat long from sys.environment("SOLOLAT", "SOLOLONG")
# REMEMBER: keep stdout clean to return "on" or "off ..."
#           Send all logging to stderr
# Warning: fringes are untested and I suspect buggy.
