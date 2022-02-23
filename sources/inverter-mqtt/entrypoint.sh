#!/bin/bash
export TERM=xterm

# stty -F /dev/ttyUSB0 2400 raw

/opt/inverter-mqtt/mqtt-init.sh > /dev/null 2>&1 &

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

# wait until the clock lines up on the next integer multiple seconds
sleepUntilNextSecs 30
# after which we'll execute exactly every 30 seconds...
while true
do
  /opt/inverter-mqtt/mqtt-push.sh > /dev/null 2>&1
  sleepUntilNextSecs 30
done
