#!/bin/bash
# file: utilities.sh
#
# This script provides some useful utility functions
#

has_internet()
{
  nc -z -w 5 8.8.8.8 53  >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

force_ntp_update()
{
  /etc/init.d/ntp stop
  ntpd -q -g
  /etc/init.d/ntp start
}

is_rtc_connected()
{
  local result=$(i2cdetect -y 1)
  if [[ $result == *"68"* ]] ; then
    return 0
  else
    local result=$((i2cget -y 0x01 0x68 0x0F) 2>/dev/null)
    if [[ $result =~ ^0x[0-9A-Fa-f]{2}$ ]] ; then
      return 0
    else
      load_rtc
      hwclock &>/dev/null
      local err=$?
      unload_rtc
      if [ $err -eq 0 ] ; then
        return 0
      else
        return 1
      fi
    fi
  fi
}

load_rtc()
{
  modprobe rtc-ds1307
  if [ ! -d /sys/class/i2c-adapter/i2c-1/1-0068 ]; then
    local output=$((sh -c 'echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-1/new_device') 2>&1)
    if [ ! -z "$output" ] && [ "sh: echo: I/O error" != "$output" ] ; then
      log "$output"
    fi
  fi
}

unload_rtc()
{
  rmmod rtc-ds1307
}

get_sys_time()
{
  echo $(date +'%a %d %b %Y %H:%M:%S %Z')
}

get_rtc_timestamp()
{
  load_rtc
  LANG=C
  local rtctime=$(hwclock | awk '{$6=$7="";print $0}');
  unload_rtc
  if [ "$rtctime" == "" ] ; then
    echo ''
  else
    local rtctimestamp=$(date -d "$rtctime" +%s)
    echo $rtctimestamp
  fi
}

get_rtc_time()
{
  local rtc_ts=$(get_rtc_timestamp)
  if [ "$rtc_ts" == "" ] ; then
    echo 'N/A'
  else
    echo $(date +'%a %d %b %Y %H:%M:%S %Z' -d @$rtc_ts)
  fi
}

set_rtc_time()
{
  load_rtc
  hwclock --set --date="$*"
  unload_rtc
}

bcd2dec()
{
  local result=$(($1/16*10+($1&0xF)))
  echo $result
}

dec2bcd()
{
  local result=$((10#$1/10*16+(10#$1%10)))
  echo $result
}

dec2hex()
{
  printf "0x%02x" $1
}

get_utc_date_time()
{
  local date=$1
  if [ $date == '??' ]; then
    date='01'
  fi
  local hour=$2
  if [ $hour == '??' ]; then
    hour='12'
  fi
  local minute=$3
  if [ $minute == '??' ]; then
    minute='00'
  fi
  local second=$4
  if [ $second == '??' ]; then
    second='00'
  fi
  local datestr=$(date +%Y-)
  local curDate=$(date +%d)
  if [[ "$date" < "$curDate" ]] ; then
    datestr+=$(date --date="$(date +%m) +1 month" +%m-)
  else
    datestr+=$(date +%m-)
  fi
  datestr+="$date $hour:$minute:$second"
  datestr+=$(date +%:z)
  local result=$(date -u -d "$datestr" +"%d %H:%M:%S" 2>/dev/null)
  IFS=' ' read -r date timestr <<< "$result"
  IFS=':' read -r hour minute second <<< "$timestr"
  if [ $1 == '??' ]; then
    date='??'
  fi
  if [ $2 == '??' ]; then
    hour='??'
  fi
  if [ $3 == '??' ]; then
    minute='??'
  fi
  if [ $4 == '??' ]; then
    second='??'
  fi
  echo "$date $hour:$minute:$second"
}

get_local_date_time()
{
  local when=$1
  IFS=' ' read -r date timestr <<< "$when"
  IFS=':' read -r hour minute second <<< "$timestr"
  local bk_date=$date
  local bk_hour=$hour
  local bk_min=$minute
  local bk_sec=$second
  if [ $date == '??' ]; then
    date='01'
  fi
  if [ $hour == '??' ]; then
    hour='12'
  fi
  if [ $minute == '??' ]; then
    minute='00'
  fi
  if [ $second == '??' ]; then
    second='00'
  fi
  local datestr=$(date +%Y-)
  local curDate=$(date +%d)
  if [[ "$date" < "$curDate" ]] ; then
    datestr+=$(date --date="$(date +%m) +1 month" +%m-)
  else
    datestr+=$(date +%m-)
  fi
  datestr+="$date $hour:$minute:$second UTC"
  local result=$(date -d "$datestr" +"%d %H:%M:%S" 2>/dev/null)
  IFS=' ' read -r date timestr <<< "$result"
  IFS=':' read -r hour minute second <<< "$timestr"
  if [ -z ${2+x} ] ; then
    if [ $bk_date == '??' ]; then
      date='??'
    fi
    if [ $bk_hour == '??' ]; then
      hour='??'
    fi
    if [ $bk_min == '??' ]; then
      minute='??'
    fi
    if [ $bk_sec == '??' ]; then
      second='??'
    fi
  fi
  echo "$date $hour:$minute:$second"
}

get_startup_time()
{
  sec=$(bcd2dec $(i2c_read 0x01 0x68 0x07))
  if [ $sec == '80' ]; then
    sec='??'
  fi
  min=$(bcd2dec $(i2c_read 0x01 0x68 0x08))
  if [ $min == '80' ]; then
    min='??'
  fi
  hour=$(bcd2dec $(i2c_read 0x01 0x68 0x09))
  if [ $hour == '80' ]; then
    hour='??'
  fi
  date=$(bcd2dec $(i2c_read 0x01 0x68 0x0A))
  if [ $date == '80' ]; then
    date='??'
  fi
  echo "$date $hour:$min:$sec"
}

set_startup_time()
{
  i2c_write 0x01 0x68 0x0E 0x07
  if [ $4 == '??' ]; then
    sec='128'
  else
    sec=$(dec2bcd $4)
  fi
  i2c_write 0x01 0x68 0x07 $sec
  if [ $3 == '??' ]; then
    min='128'
  else
    min=$(dec2bcd $3)
  fi
  i2c_write 0x01 0x68 0x08 $min
  if [ $2 == '??' ]; then
    hour='128'
  else
    hour=$(dec2bcd $2)
  fi
  i2c_write 0x01 0x68 0x09 $hour
  if [ $1 == '??' ]; then
    date='128'
  else
    date=$(dec2bcd $1)
  fi
  i2c_write 0x01 0x68 0x0A $date
}

clear_startup_time()
{
  i2c_write 0x01 0x68 0x07 0x00
  i2c_write 0x01 0x68 0x08 0x00
  i2c_write 0x01 0x68 0x09 0x00
  i2c_write 0x01 0x68 0x0A 0x00
}

get_shutdown_time()
{
  min=$(bcd2dec $(i2c_read 0x01 0x68 0x0B))
  if [ $min == '80' ]; then
    min='??'
  fi
  hour=$(bcd2dec $(i2c_read 0x01 0x68 0x0C))
  if [ $hour == '80' ]; then
    hour='??'
  fi
  date=$(bcd2dec $(i2c_read 0x01 0x68 0x0D))
  if [ $date == '80' ]; then
    date='??'
  fi
  echo "$date $hour:$min:00"
}

set_shutdown_time()
{
  i2c_write 0x01 0x68 0x0E 0x07
  if [ $3 == '??' ]; then
    min='128'
  else
    min=$(dec2bcd $3)
  fi
  i2c_write 0x01 0x68 0x0B $min
  if [ $2 == '??' ]; then
    hour='128'
  else
    hour=$(dec2bcd $2)
  fi
  i2c_write 0x01 0x68 0x0C $hour
  if [ $1 == '??' ]; then
    date='128'
  else
    date=$(dec2bcd $1)
  fi
  i2c_write 0x01 0x68 0x0D $date
}

clear_shutdown_time()
{
  i2c_write 0x01 0x68 0x0B 0x00
  i2c_write 0x01 0x68 0x0C 0x00
  i2c_write 0x01 0x68 0x0D 0x00
}

system_to_rtc()
{
  log '  Writing system time to RTC...'
  load_rtc
  local err=$((hwclock -w) 2>&1)
  if [ "$err" == "" ] ; then
    log '  Done :-)'
  else
    log '  Failed :-('
    log "$err"
  fi
  unload_rtc
}

rtc_to_system()
{
  log '  Writing RTC time to system...'
  load_rtc
  local err=$((hwclock -s) 2>&1)
  if [ "$err" == "" ] ; then
    log '  Done :-)'
  else
    log '  Failed :-('
    log "$err"
  fi
  unload_rtc
}

trim()
{
  local result=$(echo "$1" | sed -n '1h;1!H;${;g;s/^[ \t]*//g;s/[ \t]*$//g;p;}')
  echo $result
}

current_timestamp()
{
  local rtctimestamp=$(get_rtc_timestamp)
  if [ "$rtctimestamp" == "" ] ; then
    echo $(date +%s)
  else
    echo $rtctimestamp
  fi
}

wittypi_home="`dirname \"$0\"`"
wittypi_home="`( cd \"$wittypi_home\" && pwd )`"
log2file()
{
  local datetime=$(date +'[%Y-%m-%d %H:%M:%S]')
  local msg="$datetime $1"
  echo $msg >> $wittypi_home/wittyPi.log
}

log()
{
  if [ $# -gt 1 ] ; then
    echo $2 "$1"
  else
    echo "$1"
  fi
  log2file "$1"
}

i2c_read()
{
  local retry=0
  if [ $# -gt 3 ] ; then
    retry=$4
  fi
  local result=$(i2cget -y $1 $2 $3)
  if [[ $result =~ ^0x[0-9a-fA-F]{2}$ ]] ; then
    echo $result;
  else
    retry=$(( $retry + 1 ))
    if [ $retry -eq 4 ] ; then
      log "I2C read $1 $2 $3 failed (result=$result), and no more retry."
    else
      sleep 1
      log2file "I2C read $1 $2 $3 failed (result=$result), retrying $retry ..."
      i2c_read $1 $2 $3 $retry
    fi
  fi
}

i2c_write()
{
  local retry=0
  if [ $# -gt 4 ] ; then
    retry=$5
  fi
  i2cset -y $1 $2 $3 $4
  local result=$(i2c_read $1 $2 $3)
  if [ "$result" != $(dec2hex "$4") ] ; then
    retry=$(( $retry + 1 ))
    if [ $retry -eq 4 ] ; then
      log "I2C write $1 $2 $3 $4 failed (result=$result), and no more retry."
    else
      sleep 1
      log2file "I2C write $1 $2 $3 $4 failed (result=$result), retrying $retry ..."
      i2c_write $1 $2 $3 $4 $retry
    fi
  fi
}

get_temperature()
{
  local ctrl=$(i2c_read 0x01 0x68 0x0E)
  i2c_write 0x01 0x68 0x0E $(($ctrl|0x20))
  sleep 0.2
  local t1=$(i2c_read 0x01 0x68 0x11)
  local t2=$(i2c_read 0x01 0x68 0x12)
  local sign=$(($t1&0x80))
  local c=''
  if [ $sign -ne 0 ] ; then
    c+='-'
    c+=$((($t1^0xFF)+1))
  else
    c+=$(($t1&0x7F))
  fi
  c+='.'
  c+=$(((($t2&0xC0)>>6)*25))
  echo -n "$c$(echo $'\xc2\xb0'C)"
  if hash awk 2>/dev/null; then
    local f=$(awk "BEGIN { print $c*1.8+32 }")
    echo " / $f$(echo $'\xc2\xb0'F)"
  else
    echo ''
  fi
}

clear_alarm_flags()
{
  local byte_F=0x0
  if [ -z "$1" ]; then
    byte_F=$(i2c_read 0x01 0x68 0x0F)
  else
    byte_F=$1
  fi
  byte_F=$(($byte_F&0xFC))
  i2c_write 0x01 0x68 0x0F $byte_F
}

do_shutdown()
{
  local halt_pin=$1
  local led_pin=$2
  local has_rtc=$3

  # light the white LED
  gpio -g mode $led_pin out
  gpio -g write $led_pin 1

  # restore GPIO-4
  gpio -g mode $halt_pin in
  gpio -g mode $halt_pin up

  if [ $has_rtc == 0 ] ; then
    # clear alarm flags
    clear_alarm_flags

    # only enable alarm A (startup)
    i2c_write 0x01 0x68 0x0E 0x05
  fi

  log 'Halting all processes and then shutdown Raspberry Pi...'

  # halt everything and shutdown
  shutdown -h now
}

schedule_script_interrupted()
{
  local startup_time=$(get_local_date_time "$(get_startup_time)" "nowildcard")
  local st_size=${#startup_time}
  local shutdown_time=$(get_local_date_time "$(get_shutdown_time)" "nowildcard")
  local sd_size=${#shutdown_time}
  if [ $st_size != '3' ] && [ $sd_size != '3' ] ; then
    local st_timestamp=$(date --date="$(date +%Y-%m-)$startup_time" +%s)
    local sd_timestamp=$(date --date="$(date +%Y-%m-)$shutdown_time" +%s)
    local cur_timestamp=$(date +%s)
    if [ $st_timestamp -gt $cur_timestamp ] && [ $sd_timestamp -lt $cur_timestamp ] ; then
      return 0
    fi
  fi
  return 1
}
