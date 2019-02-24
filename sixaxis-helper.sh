#!/bin/bash

##
## Configure native sony-hid driver for USB & Bluetooth (sixaxis)
##

SIXAXIS_DEVICE="$1"
# only process /dev/input/event*
! [[ "$SIXAXIS_DEVICE" =~ "/dev/input/event" ]] && exit 0

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
    while read -t "$2"; do
        slowecho "$1" >&3
        # collect output for specified amount of time, then echo it
        while read -t "$2" -r line; do
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
    done < <(stdbuf -oL bluetoothctl --agent=NoInputNoOutput <&3)
    exec 3>&-
}

sixaxis_calibrate() {
    local axis

    echo "Calibrating: $SIXAXIS_NAME"
    for axis in ABS_X ABS_Y ABS_RX ABS_RY ABS_Z ABS_RZ; do
        libevdev-tweak-device --abs "$axis" --fuzz 3 "$SIXAXIS_DEVICE" 2>/dev/null
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
    if grep "^Name=PLAYSTATION(R)3 Controller" /var/lib/bluetooth/*/*/info; then
        echo "BlueZ <5.48 hack: renaming BT profile(s) to make consistent with kernel module name"
        sed 's/.*Name=PLAYSTATION(R)3 Controller.*/Name=Sony PLAYSTATION(R)3 Controller/' -i /var/lib/bluetooth/*/*/info
        systemctl restart bluetooth
        exit
    fi
}

sixaxis_rename
sixaxis_calibrate
if [[ "$SIXAXIS_TIMEOUT" != "0" ]]; then
    sixaxis_timeout
fi
exit 0
