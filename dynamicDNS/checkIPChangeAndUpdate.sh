#!/bin/bash

# The file where the current public IP will be stored
IP_FILE="/home/pi/dynamicDNS/ip.txt"

# Fetch the current public IP
CURRENT_IP=$(curl -s https://ipinfo.io/ip)

if [ -f $IP_FILE ]; then
    # Read the previous IP from the file
    PREVIOUS_IP=$(cat $IP_FILE)

    # If the IP has changed, update the file and call updateDNS.sh
    if [ "$CURRENT_IP" != "$PREVIOUS_IP" ]; then
        echo $CURRENT_IP > $IP_FILE
        /home/pi/dynamicDNS/updateDNS.sh
    fi
else
    # This is the first time the script is run
    echo $CURRENT_IP > $IP_FILE
    /home/pi/dynamicDNS/updateDNS.sh
fi

