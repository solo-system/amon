#!/usr/bin/python3

import datetime
import sys

t = datetime.datetime.now()
# t = datetime.datetime(2018, 1, 1, 22, 39, 0, 0)

#print(t)

# split the day into 5 sections:
# 0000 -> 0430 OFF (awake at 0430)
# 0430 -> 0630 ON  
# 0630 -> 1800 OFF (awake at 1800)
# 1800 -> 2000 ON
# 2000 -> 0000 OFF (awake at 0430 TOMORROW)

if ( t.time() < datetime.time(4, 30) ):
#   print("DEBUG: session 1 - off until 0430")
   print("off {} {} {} {} {} {}".format(t.year, t.month, t.day, 4, 30, 0))
elif ( t.time() < datetime.time(6, 30) ):
#   print("DEBUG: session 2 - on until 0630")
   print("on")
elif ( t.time() < datetime.time(18, 0) ):
#   print("DEBUG: session 3 - off until 1800")
   print("off {} {} {} {} {} {}".format(t.year, t.month, t.day, 18, 0, 0))
elif ( t.time() < datetime.time(20, 0)  ):
#   print("DEBUG: session 4 - on until 2000")
   print("on")
else: # it's after 2000 
#   print("DEBUG: session 5 - off until 0430 tomorrow")
   tomorrow = t + datetime.timedelta(days=1)
   print("off {} {} {} {} {} {}".format(tomorrow.year, tomorrow.month, tomorrow.day, 4, 30, 0))
