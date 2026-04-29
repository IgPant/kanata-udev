#!/bin/bash
echo "$(date) - udev-kanata-start triggered" >> /tmp/kanata-udev.log

if pgrep -x kanata > /dev/null; then
    echo "$(date) - kanata already running, skipping" >> /tmp/kanata-udev.log
    exit 0
fi

uid=$(id -u igorantunes)

systemd-run --uid=igorantunes --setenv=DISPLAY=:0 \
    --setenv=XDG_RUNTIME_DIR=/run/user/$uid \
    --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
    --unit=kanata-udev \
    /home/igorantunes/kanata -c /home/igorantunes/kanata.kbd >> /tmp/kanata-udev.log 2>&1

echo "$(date) - kanata launched via systemd-run" >> /tmp/kanata-udev.log

sleep 3
sudo -u igorantunes DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus notify-send "Kanata" "Keyboard disconnected — Kanata started" &
