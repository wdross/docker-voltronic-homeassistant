#!/bin/bash
#
# Simple script to register the MQTT topics when the container starts for the first time...

MQTT_SERVER=`cat /etc/inverter/mqtt.json | jq '.server' -r`
MQTT_PORT=`cat /etc/inverter/mqtt.json | jq '.port' -r`
MQTT_TOPIC=`cat /etc/inverter/mqtt.json | jq '.topic' -r`
MQTT_DEVICENAME=`cat /etc/inverter/mqtt.json | jq '.devicename' -r`
MQTT_USERNAME=`cat /etc/inverter/mqtt.json | jq '.username' -r`
MQTT_PASSWORD=`cat /etc/inverter/mqtt.json | jq '.password' -r`
MQTT_CLIENTID=`cat /etc/inverter/mqtt.json | jq '.clientid' -r`

# update to make this a retained message (-r), so it doesn't have to be
# re-broadcast every so often in the event of a Homeassistant restart
registerTopic () {
    mosquitto_pub \
        -h $MQTT_SERVER \
        -p $MQTT_PORT \
        -u "$MQTT_USERNAME" \
        -P "$MQTT_PASSWORD" \
        -i $MQTT_CLIENTID \
        -r \
        -t "$MQTT_TOPIC/sensor/"$MQTT_DEVICENAME"_$1/config" \
        -m "{
  \"name\": \""$MQTT_DEVICENAME"_$1\",
  \"unit_of_measurement\": \"$2\",
  \"state_topic\": \"$MQTT_TOPIC/sensor/"$MQTT_DEVICENAME"_$1\",
  \"unique_id\": \"${MQTT_CLIENTID}_$1\",
  \"icon\": \"mdi:$3\"
}"
}

registerInverterRawCMD () {
    mosquitto_pub \
        -h $MQTT_SERVER \
        -p $MQTT_PORT \
        -u "$MQTT_USERNAME" \
        -P "$MQTT_PASSWORD" \
        -i $MQTT_CLIENTID \
        -t "$MQTT_TOPIC/sensor/$MQTT_DEVICENAME/config" \
        -m "{
  \"name\": \""$MQTT_DEVICENAME"\",
  \"state_topic\": \"$MQTT_TOPIC/sensor/$MQTT_DEVICENAME\"
}"
}

# Get a list of all our topics into $Topics[@]
# Topics listed in /opt/inverter-mqtt/topics instead of this source file
mapfile -t Topics < /opt/inverter-mqtt/topics

for i in "${Topics[@]}"
do
  # Split our line up by double quoted strings
  eval "array=($i)"

  # we want to pass "Topic" "Units" "mdi_icon"
  registerTopic "${array[0]}" "${array[1]}" "${array[2]}"
done

# Add in a separate topic so we can send raw commands from assistant back to the inverter via MQTT (such as changing power modes etc)...
registerInverterRawCMD
