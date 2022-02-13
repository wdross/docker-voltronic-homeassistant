#!/bin/bash
INFLUX_ENABLED=`cat /etc/inverter/mqtt.json | jq '.influx.enabled' -r`

# Collect parameters one time for multiple references
MQTT_SERVER=`cat /etc/inverter/mqtt.json | jq '.server' -r`
MQTT_PORT=`cat /etc/inverter/mqtt.json | jq '.port' -r`
MQTT_TOPIC=`cat /etc/inverter/mqtt.json | jq '.topic' -r`
MQTT_DEVICENAME=`cat /etc/inverter/mqtt.json | jq '.devicename' -r`
MQTT_USERNAME=`cat /etc/inverter/mqtt.json | jq '.username' -r`
MQTT_PASSWORD=`cat /etc/inverter/mqtt.json | jq '.password' -r`
MQTT_CLIENTID=`cat /etc/inverter/mqtt.json | jq '.clientid' -r`
MQTT_MAXINTERVAL=`cat /etc/inverter/mqtt.json | jq '.maxinterval' -r`
# prevent bad/missing input from having an issue
[ "$MQTT_MAXINTERVAL" == "null" ] && MQTT_MAXINTERVAL=0
[ -z "$MQTT_MAXINTERVAL" ] && MQTT_MAXINTERVAL=0

pushMQTTData () {
    mosquitto_pub \
        -h $MQTT_SERVER \
        -p $MQTT_PORT \
        -u "$MQTT_USERNAME" \
        -P "$MQTT_PASSWORD" \
        -i $MQTT_CLIENTID \
        -t "$MQTT_TOPIC/sensor/"$MQTT_DEVICENAME"_$1" \
        -m "$2"

    if [[ $INFLUX_ENABLED == "true" ]] ; then
        pushInfluxData $1 $2
    fi
}

pushInfluxData () {
    INFLUX_HOST=`cat /etc/inverter/mqtt.json | jq '.influx.host' -r`
    INFLUX_USERNAME=`cat /etc/inverter/mqtt.json | jq '.influx.username' -r`
    INFLUX_PASSWORD=`cat /etc/inverter/mqtt.json | jq '.influx.password' -r`
    INFLUX_DEVICE=`cat /etc/inverter/mqtt.json | jq '.influx.device' -r`
    INFLUX_PREFIX=`cat /etc/inverter/mqtt.json | jq '.influx.prefix' -r`
    INFLUX_DATABASE=`cat /etc/inverter/mqtt.json | jq '.influx.database' -r`
    INFLUX_MEASUREMENT_NAME=`cat /etc/inverter/mqtt.json | jq '.influx.namingMap.'$1'' -r`
    
    curl -i -XPOST "$INFLUX_HOST/write?db=$INFLUX_DATABASE&precision=s" -u "$INFLUX_USERNAME:$INFLUX_PASSWORD" --data-binary "$INFLUX_PREFIX,device=$INFLUX_DEVICE $INFLUX_MEASUREMENT_NAME=$2"
}

# Get a list of all our topics into $Topics[@]
# Topics listed in /opt/inverter-mqtt/topics instead of this source file
mapfile -t Topics < /opt/inverter-mqtt/topics

# current readings and what time they are from (to the nearest second)
INVERTER_DATA=`timeout 10 /opt/inverter-cli/bin/inverter_poller -1`
# single quote prevents expanding $1 by bash, so awk can 'see' it as the literal $1
t=`awk '{ printf("%.0f",$1) }' < /proc/uptime`

# all the previous values and the times each was sent
PREV_INVERTER_DATA=`cat /ramdisk/response.txt`
PREV_SENT_TIMES=`cat /ramdisk/times.txt`

# start recreating times.txt based on when we sent each, overwriting our file
printf "{ " > /ramdisk/times.txt

# iterate thru all the Topics
for i in "${Topics[@]}"
do
  # Split our line up by double quoted strings; we only care about topic ([0])
  eval "arr=($i)"

  # now we want to get the value of the first word (topic name) from each
  # $INVERTER_DATA (current value), $PREV_INVERTER_DATA (last sent) and
  # $PREV_SENT_TIMES (time we last sent)

  current=`echo $INVERTER_DATA | jq ."${arr[0]}" -r`
  prev=`echo $PREV_INVERTER_DATA | jq ."${arr[0]}" -r`
  sent=`echo $PREV_SENT_TIMES | jq ."${arr[0]}" -r`
  [ -z "$sent" ] && sent=0 # hasn't been sent (or blank file), ensure a zero for math
  # If too long since we've sent this one parameter, clear prev so we can send now
  [ "$(($t-$sent))" -ge $MQTT_MAXINTERVAL ] && prev=

  # If we have data AND it's different than last time, send it now
  if [[ ! -z "$current" && "$current" != "$prev" ]]; then
    pushMQTTData "${arr[0]}" "$current"
    # Update our times.txt with the time of this current reading
    printf "\"${arr[0]}\":$t, " >> /ramdisk/times.txt
  else
    # record last time it was sent, not the current sample time
    # if we are not getting data and we did not ever receive any data
    # we'll be writting zeros for the times.  But that is when we last sent it -- never!
    printf "\"${arr[0]}\":$sent, " >> /ramdisk/times.txt
  fi
done

# need to have a nice, clean finale to satisfy jq: can't have that
# dangling comma, so we put a dummy value here and close it up
printf "\"unused\":1 }" >> /ramdisk/times.txt

echo $INVERTER_DATA > /ramdisk/response.txt # overwrite last data to RAM disk
