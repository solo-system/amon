#!/usr/bin/python3

# This file is a Solo Calendar
# This file is part of amon (https://github.com/solo-system/amon.git)
# see readme.txt for info on calendars

# This calendar records two periods per day.
# split the day into 5 sections:
# 0000 -> 0430 OFF (awake at 0430)
# 0430 -> 0630 ON  
# 0630 -> 1800 OFF (awake at 1800)
# 1800 -> 2000 ON
# 2000 -> 0000 OFF (awake at 0430 TOMORROW)

import sys
import datetime
import pytz

# what is the output format we hand back to amon?
returnformat="%Y %m %d %H %M %S" # returned on stdout as the reboot time
fmt = '%Y-%m-%d %H:%M:%S %Z%z' # mostly for debug

# get NOW in UTC - and ensure the datetime object is AWARE it's a UTC timezone (not naive).
naive_utc_now = datetime.datetime.utcnow()

# make an aware version of the above - so it KNOWS it's in UTC.
aware_utc_now = pytz.utc.localize(naive_utc_now)

# get a represenataion of NOW aware of local (system) timezone:
now = aware_utc_now.astimezone()

print("\ntwice-a-day.py (time-now: {})".format(now.strftime(fmt)), file=sys.stderr)

if ( now.time() < datetime.time(4, 30) ):
   t = now.replace(hour=4, minute=30, second=0)
   # is t naive?
   rbt = t.astimezone(pytz.utc)
   rs = "off {}".format(rbt.strftime(returnformat))
   print(rs)
   print("twice-a-day.py: session 1 (0000->0430): off rbt= (0430) {}".format(rbt), file=sys.stderr)
   print("twice-a-day.py: rebooting in {}".format(rbt-aware_utc_now), file=sys.stderr)
   print("twice-a-day.py: returning: {}".format(rs), file=sys.stderr)

elif ( now.time() < datetime.time(6, 30) ):
   rs = "on"
   print(rs)
   print("twice-a-day.py: session 2 (0430->0630): on", file=sys.stderr)
   print("twice-a-day.py: returning: {}".format(rs), file=sys.stderr)

elif ( now.time() < datetime.time(18, 0) ):
   t = now.replace(hour=18, minute=0, second=0)
   rbt = t.astimezone(pytz.utc)
   rs = "off {}".format(rbt.strftime(returnformat))
   print(rs)
   print("twice-a-day.py: session 3 (0630->1800): off. rbt= (1800) {}".format(rbt), file=sys.stderr)
   print("twice-a-day.py: rebooting in {}".format(rbt-aware_utc_now), file=sys.stderr)
   print("twice-a-day.py: returning: {}".format(rs), file=sys.stderr)

elif ( now.time() < datetime.time(20, 0)  ):
   rs = "on"
   print(rs)
   print("twice-a-day.py: session 4 (between 1800 and 2000) - on", file=sys.stderr)
   print("twice-a-day.py: returning: {}".format(rs), file=sys.stderr)

else:
   t = now + datetime.timedelta(days=1) # skip one day into the future (to get DATE right)
   t = t.replace(hour=4,minute=30,second=0) # fix up the time for restart tomorrow.
   rbt = t.astimezone(pytz.utc)
   rs = "off {}".format(rbt.strftime(returnformat))
   print(rs)
   print("twice-a-day.py: session 5 (after 2000) - off - reboot at 0430 tomorrow", file=sys.stderr)
   print("twice-a-day.py: rebooting in {}".format(rbt-aware_utc_now), file=sys.stderr)
   print("twice-a-day.py: returning: {}".format(rs), file=sys.stderr)

