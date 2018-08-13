#!/usr/bin/python3

# This calendar supports witty pi (offers a reboot time when
# recommending "off").
# see: http://rhodesmill.org/pyephem/date.html
# to test it, just run it (on your desktop) - it is stand alone.
#
# can we get lat long from sys.environment("SOLOLAT", "SOLOLONG")
# REMEMBER: keep stdout clean to return "on" or "off ..."
#           Send all logging to stderr
# Warning: deltas are untested and I suspect buggy.

import datetime
import sys
import ephem # for sunrise and sunset times. (pip install pyephem)
from datetime import timedelta
from datetime import timezone

# what is the output format we hand back to amon?
dateformat="%Y-%m-%d %H:%M:%S %Z" # for debug in stderr
returnformat="%Y %m %d %H %M %S" # what we return on stdout

# what time is it right now?
utcnow=datetime.datetime.utcnow().replace(tzinfo=timezone.utc)
print("now: %s" % utcnow.strftime(dateformat),file=sys.stderr)

sun = ephem.Sun() # which astro-object are we interested in?

# set up the observer, at the SOLO's location.
solobox = ephem.Observer()
solobox.lat = '55.9667'; solobox.lon = '-3.2167'   # Edinburgh (GMT / BST) GMT+0
solobox.lat = '34.0522'; solobox.lon = '-118.2437' # LA (PST /PDT) GMT-8
solobox.lat = '42.3601'; solobox.lon = '-71.0589'  # Boston (EST / EDT) GMT-5

#solobox.pressure = 0 # atmospheric dispersion?
#solobox.horizon = '0.0' # degrees(?) raise the horizon for later dawn, earlier dusk.

# calculate the next rising/setting sun time (in UTC)
#   - call next_rising() to get the event time in UTC
#   - ... convert to python's datetime structure.
#   - ... and then explicitly setting timezone to "utc"
srise = solobox.next_rising(sun).datetime().replace(tzinfo=timezone.utc) 
sset  = solobox.next_setting(sun).datetime().replace(tzinfo=timezone.utc) 
print("sunrise: %s" % srise.strftime(dateformat) ,file=sys.stderr)
print("sun set: %s" % sset.strftime(dateformat) ,file=sys.stderr)

delta = timedelta(minutes=0)
if (delta != timedelta(minutes=0) ): print("WARNINIG: borders might not work - they are UNTESTED", file=sys.stderr)
print("add the border: %s" % delta,file=sys.stderr)
sriseb = srise - delta
ssetb = sset + delta
print("sunrise (with border): %s" % sriseb.strftime(dateformat) ,file=sys.stderr)
print("sun set (with border): %s" % ssetb.strftime(dateformat) ,file=sys.stderr)

#print("convert these UTC times into localtime:",file=sys.stderr)
sriseblt = sriseb.astimezone()
ssetblt = ssetb.astimezone()
print("sunrise (local): %s" % sriseblt.strftime(dateformat) ,file=sys.stderr)
print("sun set (local): %s" % ssetblt.strftime(dateformat) ,file=sys.stderr)


if (srise < sset):
    waittime = sriseb - utcnow
    print('sun-rise is next (in %s) at %s, so it\'s currently night -> we should be ON' % (waittime, sriseblt.strftime(dateformat)), file=sys.stderr)
    print("on")
else:
    waittime = ssetb - utcnow
    print('sun-set is next (in %s), at %s, so it\'s currently day -> we should be OFF, rebooting at sunset' % (waittime, ssetblt.strftime(dateformat)) ,file=sys.stderr)
    print('off %s' % ssetblt.strftime(returnformat))
