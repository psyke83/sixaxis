#!/bin/bash

##
## Configure native sony-hid driver for USB & Bluetooth (sixaxis)
##

SIXAXIS_DEVICE="$1"
# only process /dev/input/event*
! [[ "$SIXAXIS_DEVICE" =~ "/dev/input/event" ]] && exit 0

BLUETOOTH_MAC="$(cat ${SIXAXIS_DEVICE/\/dev/\/sys\/class}/device/phys 2>/dev/null)"
SIXAXIS_MAC="$(cat ${SIXAXIS_DEVICE/\/dev/\/sys\/class}/device/uniq 2>/dev/null)"
SIXAXIS_NAME="$(cat ${SIXAXIS_DEVICE/\/dev/\/sys\/class}/device/name 2>/dev/null) (${SIXAXIS_MAC^^})"

# Parse user timeout configuration (stripping non-number characters to prevent security issues)
SIXAXIS_TIMEOUT=$(grep -e '^SIXAXIS_TIMEOUT=.*' "/opt/retropie/configs/all/sixaxis_timeout.cfg" 2>/dev/null | cut -d '=' -f2)
SIXAXIS_TIMEOUT="${SIXAXIS_TIMEOUT//[!0-9]/}"
[[ -z "$SIXAXIS_TIMEOUT" ]] && SIXAXIS_TIMEOUT=600

function slowecho() {
    local line

    IFS=$'\n'
    for line in $(echo -e "${1}"); do
        echo -e "$line"
        sleep 1
    done
    unset IFS
}

function send_bluezcmd() {
    # create a named pipe & fd for input for bluetoothctl
    local fifo="$(mktemp -u)"
    mkfifo "$fifo"
    exec 3<>"$fifo"
    local line
    while true; do
        slowecho "$1" >&3
        # collect output for specified amount of time, then echo it
        while read -r line; do
            printf '%s\n' "$line"
            # (slow) reply to any optional challenges
            if [[ -n "$3" && "$line" == *"$3"* ]]; then
                slowecho "$4" >&3
                break
            fi
        done
        slowecho "quit\n" >&3
        break
    # read from bluetoothctl buffered line by line
    done < <(timeout "$2" stdbuf -oL bluetoothctl --agent=NoInputNoOutput <&3)
    exec 3>&-
}

sixaxis_calibrate() {
    local axis

    echo "Calibrating: $SIXAXIS_NAME"
    for axis in ABS_X ABS_Y ABS_RX ABS_RY ABS_Z ABS_RZ; do
        libevdev-tweak-device --abs "$axis" --fuzz 10 "$SIXAXIS_DEVICE" 2>/dev/null
    done
}

sixaxis_timeout() {
    echo "Setting $SIXAXIS_TIMEOUT second timeout on: $SIXAXIS_NAME"
    sixaxis-timeout "$SIXAXIS_DEVICE" "$SIXAXIS_TIMEOUT" 2>/dev/null
    if [[ "$?" -eq 0 ]]; then
        echo "Disconnecting: $SIXAXIS_NAME"
        send_bluezcmd "disconnect ${SIXAXIS_MAC^^}" "1" &>/dev/null
    fi
}

sixaxis_rename() {
    local bt_profile="/var/lib/bluetooth/${BLUETOOTH_MAC^^}/${SIXAXIS_MAC^^}/info"

    if [[ "$(grep -e "^Name=PLAYSTATION(R)3 Controller" -e "^Trusted=true" -c "$bt_profile" 2>/dev/null)" == "2" ]]; then
        echo "BlueZ <5.48 hack: renaming BT profile to make consistent with kernel module name"
        systemctl stop bluetooth
        sed 's/.*Name=PLAYSTATION(R)3 Controller.*/Name=Sony PLAYSTATION(R)3 Controller/' -i "$bt_profile"
        systemctl start bluetooth
        exit 0
    fi
}

sixaxis_leds() {
    local led_paths=($(find "${SIXAXIS_DEVICE/\/dev/\/sys\/class}/device/device/leds" -name "*::sony?" 2>/dev/null))
    local led_type="sony_controller_battery_"$SIXAXIS_MAC"-charging-blink-full-solid"
    local led

    for led in "${led_paths[@]}"; do
        if [[ "$(cat "$led"/brightness)" -eq 1 ]]; then
            echo "Configuring LED: $led"
            echo "none" >"$led"/trigger
            echo "1" >"$led"/brightness
            echo "$led_type" >"$led"/trigger
        fi
    done
}

sixaxis_rename
sixaxis_leds
sixaxis_calibrate
if [[ "$SIXAXIS_TIMEOUT" == "0" ]] || [[ "$BLUETOOTH_MAC" =~ "usb" ]]; then
    # delay exit of service slice until device is removed
    tail -f "$SIXAXIS_DEVICE" &>/dev/null
else
    sixaxis_timeout
fi
exit 0
