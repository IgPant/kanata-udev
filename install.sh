#!/bin/bash
set -e

KANATA_BIN="$(pwd)/kanata"
KANATA_CFG="$(pwd)/kanata.kbd"
SCRIPTS_DIR="$(dirname "$(readlink -f "$0")")"

echo "=== Kanata USB Keyboard Automator Installer ==="
echo ""
echo "Current keyboards connected:"
lsusb | grep -i keyboard || lsusb
echo ""

read -p "Enter keyboard USB vendor ID (e.g. 5262): " VENDOR_ID
read -p "Enter keyboard USB product ID (e.g. 4e4b): " PRODUCT_ID
read -p "Enter kanata binary path [$KANATA_BIN]: " KANATA_BIN_INPUT
read -p "Enter kanata config path [$KANATA_CFG]: " KANATA_CFG_INPUT

KANATA_BIN="${KANATA_BIN_INPUT:-$KANATA_BIN}"
KANATA_CFG="${KANATA_CFG_INPUT:-$KANATA_CFG}"
USERNAME="$(whoami)"
USER_UID="$(id -u)"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/udev-kanata-start.sh" << EOF
#!/bin/bash
if pgrep -x kanata > /dev/null; then
    exit 0
fi

uid=$USER_UID

systemd-run --uid=$USERNAME --setenv=DISPLAY=:0 \\
    --setenv=XDG_RUNTIME_DIR=/run/user/\$uid \\
    --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus \\
    --unit=kanata-udev \\
    $KANATA_BIN -c $KANATA_CFG &

sleep 3
sudo -u $USERNAME DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus notify-send "Kanata" "Keyboard disconnected - Kanata started" &
EOF

cat > "$BIN_DIR/udev-kanata-stop.sh" << EOF
#!/bin/bash
uid=$USER_UID

pkill kanata
sleep 1
if pgrep -x kanata > /dev/null; then
    pkill -9 kanata
fi

systemctl stop kanata-udev.service 2>/dev/null

sudo -u $USERNAME DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus notify-send "Kanata" "Keyboard connected - Kanata stopped" &
EOF

chmod +x "$BIN_DIR/udev-kanata-start.sh" "$BIN_DIR/udev-kanata-stop.sh"

echo ""
echo "Generated udev rule (needs sudo to install):"
echo ""
cat << RULE
ACTION=="remove", SUBSYSTEM=="usb", DEVTYPE=="usb_device", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", RUN+="$BIN_DIR/udev-kanata-start.sh"
ACTION=="add", SUBSYSTEM=="usb", DEVTYPE=="usb_device", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", RUN+="$BIN_DIR/udev-kanata-stop.sh"
RULE

read -p "Install udev rule now? (requires sudo) [Y/n]: " INSTALL
if [ "${INSTALL:-Y}" = "Y" ] || [ "$INSTALL" = "y" ]; then
    pkexec tee /etc/udev/rules.d/90-kanata-keyboard.rules << RULE
ACTION=="remove", SUBSYSTEM=="usb", DEVTYPE=="usb_device", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", RUN+="$BIN_DIR/udev-kanata-start.sh"
ACTION=="add", SUBSYSTEM=="usb", DEVTYPE=="usb_device", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", RUN+="$BIN_DIR/udev-kanata-stop.sh"
RULE
    pkexec udevadm control --reload-rules
    echo "Done! udev rules installed and reloaded."
else
    echo "Skipped. Install manually with the rule printed above."
fi

echo ""
echo "All done! Disconnect/reconnect your keyboard to test."
