#!/bin/bash

##
## Configure native sony-hid driver for USB & Bluetooth(sixaxis)
##

[[ -z "$SIXAXIS_TIMEOUT" ]] && SIXAXIS_TIMEOUT=600

unmangle_path() {
    local adjust
    local path
    local fullpath
    for path in ${1//// }; do
        if [[ "$adjust" -eq 1 ]]; then
            fullpath+="-$path"
            adjust=0
        else
            fullpath+="/$path"
        fi

        if [[ ! -e "$fullpath" ]]; then
            adjust=1
        fi
     done

     echo "$fullpath"
}

UDEV_DEVPATH="/sys$1"
# unmangle path (systemd brain-damage): https://github.com/systemd/systemd/issues/5072
if [[ ! -e "$UDEV_DEVPATH" ]]; then
    UDEV_DEVPATH="$(unmangle_path /sys$1)"
fi

# export udev variables into systemd service context
eval $(udevadm info --query=env --export "$UDEV_DEVPATH")
if [[ -z "$NAME" ]] || [[ -z "$UNIQ" ]]; then
    # we're not interested in the /jsX and /eventX udev events.
    exit 0
fi

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
                done
                printf '%s\n' "${buf[@]}"
            else
                # allow time for command to process before closing
                sleep 1
            fi
            break
        fi
    # read from bluetoothctl buffered line by line
    done < <(stdbuf -oL bluetoothctl <&3)
    exec 3>&-
}

sixaxis_detect() {
    local event
    SIXAXIS_MAC="${UNIQ//\"/}"

    for event in /sys/class/input/event[0-9]*; do
        if [[ "$(cat $event/device/uniq)" == "$SIXAXIS_MAC" && "$(cat $event/device/name)" == "${NAME//\"/}" ]]; then
            SIXAXIS_DEVICE="${event//\/sys\/class/\/dev}"
            SIXAXIS_NAME="${NAME//\"/} (${SIXAXIS_MAC^^})"
        fi
    done
}

sixaxis_calibrate() {
    local axis

    echo "Calibrating: $SIXAXIS_NAME"
    for axis in ABS_X ABS_Y ABS_RX ABS_RY; do
        libevdev-tweak-device --abs "$axis" --fuzz 3 "$SIXAXIS_DEVICE"
    done
}

sixaxis_timeout() {
    echo "Setting $SIXAXIS_TIMEOUT second timeout: $SIXAXIS_NAME"
    sixaxis-timeout "$SIXAXIS_DEVICE" "$SIXAXIS_TIMEOUT"
    if [[ "$?" -eq 1 ]]; then
        echo "Disconnecting: $SIXAXIS_NAME"
        send_bluezcmd "disconnect ${SIXAXIS_MAC^^}"
    fi
}

sixaxis_settrust() {
    echo "Setting Bluetooth trust: $SIXAXIS_NAME"
    send_bluezcmd "trust ${SIXAXIS_MAC^^}"
}

sixaxis_detect
if [[ -n "$SIXAXIS_DEVICE" ]]; then
    sixaxis_calibrate
    sixaxis_settrust
    sixaxis_timeout
fi

exit 0
