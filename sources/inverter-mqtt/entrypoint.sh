#!/bin/bash
export TERM=xterm

# stty -F /dev/ttyUSB0 2400 raw

# Run the MQTT Subscriber process in the background (so that way we can change the configuration on the inverter from home assistant)
/opt/inverter-mqtt/mqtt-subscriber.sh &

sleepUntilNextSecs() { # args sec_quantity
    # figure the next multiple of sec_quantity and sleep until then
    local slp now
    printf -v now '%(%s)T' -1
    slp=$(( $now%$1 ))
    if (( slp > 0 )); then
      slp=$(( $1-$slp ))
    fi
    # printf 'sleep %ss, -> %(%c)T\n' $slp $((now+slp))
    sleep $slp
}

sec=`awk 'BEGIN{FS="="} /^run_interval/{print $2}' /etc/inverter/inverter.conf`
[ -z "$sec" ] && sec=0
# Then we'll keep it in a reasonable range: smaller than 15 is unlikely to behave
# well if the serial unit is unhooked/powered off, as the timeout expression is 10 seconds!
if (( sec < 15 )); then
  sec=15
elif (( sec > 600 )); then
  sec=600
fi

# Now we can execute exactly on the specified interval...
while true
do
  sleepUntilNextSecs "$sec"
  /opt/inverter-mqtt/saveraw.sh > /dev/null 2>&1
done
