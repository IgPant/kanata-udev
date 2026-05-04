#!/bin/bash
set -e

KANATA_BIN="$(pwd)/kanata"
KANATA_CFG="$(pwd)/kanata.kbd"

echo "=== Kanata USB Keyboard Automator Installer ==="
echo ""
echo "Current USB devices:"
lsusb
echo ""

KEYBOARDS=()
echo "Add keyboards one by one. Leave vendor ID empty to finish."
while true; do
    read -p "Enter keyboard USB vendor ID (e.g. 5262) [enter to stop]: " VENDOR_ID
    [ -z "$VENDOR_ID" ] && break
    read -p "Enter keyboard USB product ID (e.g. 4e4b): " PRODUCT_ID
    KEYBOARDS+=("$VENDOR_ID:$PRODUCT_ID")
    echo "Added $VENDOR_ID:$PRODUCT_ID"
done

if [ ${#KEYBOARDS[@]} -eq 0 ]; then
    echo "No keyboards added. Exiting."
    exit 1
fi

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

EOF

chmod +x "$BIN_DIR/udev-kanata-start.sh" "$BIN_DIR/udev-kanata-stop.sh"

UDEV_RULE=""
for KB in "${KEYBOARDS[@]}"; do
    VID="${KB%%:*}"
    PID="${KB##*:}"
    HID_VID=$(printf "%04x" "0x$VID")
    HID_PID=$(printf "%04x" "0x$PID")
    UDEV_RULE+="
ACTION==\"remove\", SUBSYSTEM==\"input\", ENV{ID_VENDOR_ID}==\"$VID\", ENV{ID_MODEL_ID}==\"$PID\", RUN+=\"$BIN_DIR/udev-kanata-start.sh\"
ACTION==\"remove\", SUBSYSTEM==\"hid\", ENV{HID_ID}==\"0003:0000${HID_VID^^}:0000${HID_PID^^}\", RUN+=\"$BIN_DIR/udev-kanata-start.sh\"
ACTION==\"remove\", SUBSYSTEM==\"usb\", DEVTYPE==\"usb_device\", ATTR{idVendor}==\"$VID\", ATTR{idProduct}==\"$PID\", RUN+=\"$BIN_DIR/udev-kanata-start.sh\"

ACTION==\"add\", SUBSYSTEM==\"input\", ENV{ID_VENDOR_ID}==\"$VID\", ENV{ID_MODEL_ID}==\"$PID\", RUN+=\"$BIN_DIR/udev-kanata-stop.sh\"
ACTION==\"add\", SUBSYSTEM==\"hid\", ENV{HID_ID}==\"0003:0000${HID_VID^^}:0000${HID_PID^^}\", RUN+=\"$BIN_DIR/udev-kanata-stop.sh\"
ACTION==\"add\", SUBSYSTEM==\"usb\", DEVTYPE==\"usb_device\", ATTR{idVendor}==\"$VID\", ATTR{idProduct}==\"$PID\", RUN+=\"$BIN_DIR/udev-kanata-stop.sh\"
"
done

echo ""
echo "Generated udev rule:"
echo "$UDEV_RULE"

read -p "Install udev rule now? (requires sudo) [Y/n]: " INSTALL
if [ "${INSTALL:-Y}" = "Y" ] || [ "$INSTALL" = "y" ]; then
    echo "$UDEV_RULE" | pkexec tee /etc/udev/rules.d/90-kanata-keyboard.rules > /dev/null
    pkexec udevadm control --reload-rules
    echo "Done! udev rules installed and reloaded."
else
    echo "Skipped. Install manually with the rule printed above."
fi

echo ""
echo "All done! Disconnect/reconnect your keyboard to test."
