#!/bin/bash
export TERM=xterm

# stty -F /dev/ttyUSB0 2400 raw

/opt/inverter-mqtt/mqtt-init.sh > /dev/null 2>&1 &

# Run the MQTT Subscriber process in the background (so that way we can change the configuration on the inverter from home assistant)
/opt/inverter-mqtt/mqtt-subscriber.sh &

# execute exactly every 30 seconds...
watch -n 30 /opt/inverter-mqtt/mqtt-push.sh > /dev/null 2>&1
