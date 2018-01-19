#!/bin/bash

##
## Configure native sony-hid driver for USB & Bluetooth(sixaxis)
##

[[ -z "$SIXAXIS_TIMEOUT" ]] && SIXAXIS_TIMEOUT=600

UDEV_ENV="$1"
# unmangle path (systemd brain-damage...)
if [[ ! -e "/sys$UDEV_ENV" ]]; then
    UDEV_ENV="${UDEV_ENV:0:41}-${UDEV_ENV:42}"
    UDEV_ENV="${UDEV_ENV:0:45}-${UDEV_ENV:46}"
    UDEV_ENV="${UDEV_ENV:0:51}-${UDEV_ENV:52}"
    [[ ! -e "/sys$UDEV_ENV" ]] && exit
fi

# export udev variables into systemd service context
eval $(udevadm info --query=env --export "/sys$UDEV_ENV")
if [[ -z "$NAME" ]] || [[ -z "$UNIQ" ]]; then
    # we're not interested in the /jsX and /eventX udev events.
    exit 0
fi

send_bluezcmd() {
    echo -e "$@\nquit" | bluetoothctl >/dev/null
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
