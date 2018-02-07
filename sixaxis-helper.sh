#!/bin/bash

##
## Configure native sony-hid driver for USB & Bluetooth (sixaxis)
##

SIXAXIS_DEVICE="$1"
SIXAXIS_MAC="$(cat ${SIXAXIS_DEVICE/\/dev/\/sys\/class}/device/uniq)"
SIXAXIS_NAME="$(cat ${SIXAXIS_DEVICE/\/dev/\/sys\/class}/device/name) (${SIXAXIS_MAC^^})"
[[ -z "$SIXAXIS_TIMEOUT" ]] && SIXAXIS_TIMEOUT=600

function send_bluezcmd() {
    # create a named pipe & fd for input for bluetoothctl
    local fifo="$(mktemp -u)"
    mkfifo "$fifo"
    exec 3<>"$fifo"
    local line
    while read -r line; do
        if [[ "$line" == *"[bluetooth]"* ]]; then
            echo -e "$1" >&3
            read -r line
            if [[ -n "$2" ]]; then
                # collect output for specified amount of time, then echo it
                local buf
                while read -r -t "$2" line; do
                    buf+=("$line")
                    # reply to any optional challenges
                    if [[ -n "$4" && "$line" == *"$3"* ]]; then
                        echo -e "$4" >&3
                    fi
                done
                printf '%s\n' "${buf[@]}"
            fi
            sleep 1
            echo -e "quit" >&3
            break
        fi
    # read from bluetoothctl buffered line by line
    done < <(stdbuf -oL bluetoothctl <&3)
    exec 3>&-
}

sixaxis_calibrate() {
    local axis

    echo "Calibrating: $SIXAXIS_NAME"
    for axis in ABS_X ABS_Y ABS_RX ABS_RY; do
        libevdev-tweak-device --abs "$axis" --fuzz 3 "$SIXAXIS_DEVICE"
    done
}

sixaxis_timeout() {
    echo "Setting $SIXAXIS_TIMEOUT second timeout on: $SIXAXIS_NAME"
    sixaxis-timeout "$SIXAXIS_DEVICE" "$SIXAXIS_TIMEOUT"
    if [[ "$?" -eq 1 ]]; then
        echo "Disconnecting: $SIXAXIS_NAME"
        send_bluezcmd "disconnect ${SIXAXIS_MAC^^}"
    fi
}

sixaxis_calibrate
sixaxis_timeout

exit 0
