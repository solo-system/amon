#!/usr/bin/python3

# This calendar supports witty pi (offers a reboot time when
# recommending "off").
# see: http://rhodesmill.org/pyephem/date.html
# to test it, just run it (on your desktop) - it is stand alone.
#
# can we get lat long from sys.environment("SOLOLAT", "SOLOLONG")
# REMEMBER: keep stdout clean to return "on" or "off ..."
#           Send all logging to stderr

import sys
import ephem # for sunrise and sunset times. (pip install pyephem)
from datetime import timedelta
from datetime import timezone
#from dateutil import tz
#from datetime import astimezone

sun = ephem.Sun() # which astro-object are we interested in?

# set up the observer, at the SOLO's location.
solobox = ephem.Observer()
solobox.lat = '55.9667'; solobox.lon = '-3.2167'   # Edinburgh (GMT / BST) GMT+0
solobox.lat = '34.0522'; solobox.lon = '-118.2437' # LA (PST /PDT) GMT-8
solobox.lat = '42.3601'; solobox.lon = '-71.0589'  # Boston (EST / EDT) GMT-5

# calculate the next rising/setting sun time (results are in UTC)
srise = solobox.next_rising(sun)
sset  = solobox.next_setting(sun)

# Choose: do it all in python3's native datetime objects?, or stick with the simpler pyephem object?
# 
# convert these to python3's native datetime object:
print('INFO: PYTHON datetime way: BELOW', file=sys.stderr)
srisedt = srise.datetime() ; print(srisedt)
ssetdt = sset.datetime() ; print(ssetdt)

print("set the timezone to UTC...:")
# set the timezone to UTC
srisedtutc = srisedt.replace(tzinfo=timezone.utc) ; print(srisedtutc)
ssetdtutc = ssetdt.replace(tzinfo=timezone.utc) ; print(ssetdtutc)


print("add the 30 minute border:")
delta = timedelta(minutes=30) ; print(delta)
srisedtutcb = srisedtutc - delta ; print(srisedtutcb)
ssetdtutcb = srisedtutc + delta ; print(ssetdtutcb)

print("convert these UTC times into localtime:")
srisedtblt = srisedtutcb.astimezone() ; print(srisedtblt)
ssetdtblt = ssetdtutcb.astimezone() ; print(ssetdtblt)

#print datetime.utcnow().strftime('%m/%d/%Y %H:%M:%S %Z')
#print datetime.now(GMT).strftime('%m/%d/%Y %H:%M:%S %Z')
#print datetime.now(EST).strftime('%m/%d/%Y %H:%M:%S %Z')



print('INFO: OLD WAY BELOW', file=sys.stderr)

# add 30 minute borders (as Raoul requests)
sriseb = ephem.Date(srise - 30 * ephem.minute)
ssetb  = ephem.Date(sset  + 30 * ephem.minute)

# Convert to local time (this converts the types to datetime.datetime from ephem.date)
sriseblt = ephem.localtime(sriseb)
ssetblt  = ephem.localtime(ssetb)

print('INFO: Next rising: %s(UTC) border: %s(UTC) localtime: %s' % (srise, sriseb, sriseblt), file=sys.stderr)
print('INFO: Next settng: %s(UTC) border: %s(UTC) localtime: %s' % (sset, ssetb, ssetblt), file=sys.stderr)

print('srise is type %s, sriseb is type %s, sriseblt is type %s' % (type(srise), type(sriseb), type(sriseblt)),file=sys.stderr  )

# Now do the maths to decide what to actually DO?
# Which comes first? Sunrise or Sunset ?

if (sriseblt < ssetblt):
    print('INFO: sun-rise is the next event, so it\'s currently night.  We should be ON', file=sys.stderr)
    print('on')
else:
    print('INFO: sun-set is the next event, so it\'s currently day.  We should be OFF, rebooting at sunset',file=sys.stderr)
    print('off %s' % ssetblt);


### Notes while implementing:

# look - behind the scenes, ephem.Date is a float (only a float).
# so you can do float stuff to it, just remember to make it back into a ephem.date afterwards.
#if isinstance(srise, float):
#    print("it's a float, really")
#blah = ephem.Date(srise + 1) # this adds a day
#print('blah is %s' %blah)
