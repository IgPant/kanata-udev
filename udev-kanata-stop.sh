#!/bin/bash
echo "$(date) - udev-kanata-stop triggered" >> /tmp/kanata-udev.log

uid=$(id -u igorantunes)

pkill kanata
sleep 1
if pgrep -x kanata > /dev/null; then
    pkill -9 kanata
fi

systemctl stop kanata-udev.service 2>/dev/null


