Rules for calendars:


This file is part of amon (https://github.com/solo-system/amon.git)

Rules for a calendar:
 - It must return 0 (a clean exit status).
 - keep stdout clean for on/off decision and optional reboot time.
 - all logging redirected to stderr via 1>&2, gets logged into calendar.log
 - optionally return a reboot time (rbt) if "off", for witty pi.
 - reboot time is a sextuple (y m d h m s) in UTC.

So, 3 forms of valid output are:

on
off
off 2018 12 31 23 59 0
