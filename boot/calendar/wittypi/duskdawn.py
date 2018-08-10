#!/usr/bin/python3

import ephem
sun = ephem.Sun()

# set up the observer:
solobox = ephem.Observer()
solobox.lat = '55.9667' ; solobox.lon = '-3.2167' # Edinburgh
#solobox.lat = '34.0522' ; solobox.lon = '-118.2437' # LA

# calculate the next rising sun time.
srise = solobox.next_rising(sun)
sset = solobox.next_setting(sun)

# and print them (the output doesn't seem to handle different time
# zones well - although the TIMES _are_ right, they are in the wrong
# timezone.  find out if next_setting returns a UTC number? and if so,
# how to re-zone it to SOLO_TIMEZONE (or whatever that variable is
# called).

print('Today rising: %s' % srise)
print('Today settig: %s' % sset)
