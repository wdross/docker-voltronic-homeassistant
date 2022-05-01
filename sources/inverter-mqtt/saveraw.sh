#!/bin/bash
# To track the Overall execution time of this shell script
o=`awk '{ printf("%.0f",$1) }' < /proc/uptime`

# current readings and what time they are from (to the nearest second)
tim=`date +%s`
INVERTER_DATA=`timeout 10 /opt/inverter-cli/bin/inverter_poller -b -1`
[ -z "$INVERTER_DATA" ] && INVERTER_DATA=`cat /ramdisk/keep.txt`

# We need to get current number of bytes from our host's network interface
rxb=`cat /sys/class/net/wlan0/statistics/rx_bytes`
txb=`cat /sys/class/net/wlan0/statistics/tx_bytes`

# Have to find the number of bytes that the last calculation was based off
prev=`cat /ramdisk/wlan0_rx_bytes.txt`
[ -z "$prev" ] && prev=0 # ensure a zero for math
# Store off (overwrite) what we have now for the subtraction next cycle
echo "$rxb" > /ramdisk/wlan0_rx_bytes.txt
let rxb-=prev

prev=`cat /ramdisk/wlan0_tx_bytes.txt`
[ -z "$prev" ] && prev=0 # ensure a zero for math
echo "$txb" > /ramdisk/wlan0_tx_bytes.txt
let txb-=prev

e=`awk '{ printf("%.0f",$1) }' < /proc/uptime`
let e-=o

# save off the amount of transmitted bytes, received bytes since last cycle as
# well as the time (seconds) of the above readings and script elapsed time
echo "$INVERTER_DATA" > /ramdisk/response.txt # overwrite last data to RAM disk
echo "$txb $rxb $tim $e" >> /ramdisk/response.txt # then append
