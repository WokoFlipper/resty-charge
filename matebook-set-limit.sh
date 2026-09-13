#!/bin/sh
# Helper: set Huawei/Honor laptop charge limit via huawei-wmi pair.
# Usage: matebook-set-limit.sh <start> <end>
#   e.g. 40 70 (70%), 70 90 (90%), 70 95 (95%)
#
# Install to ~/.local/bin (no root needed at runtime if your user is in
# the huawei-wmi group; the udev rule of the huawei-wmi package handles that).
# Persists the choice to /etc/default/huawei-wmi/charge_control_thresholds
# (group-writable for huawei-wmi).

set -eu

SYSFS=/sys/devices/platform/huawei-wmi/charge_control_thresholds
DEFAULT=/etc/default/huawei-wmi/charge_control_thresholds

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <start_pct> <end_pct>" >&2
    exit 2
fi

START="$1"
END="$2"

case "$START:$END" in
    0:70|0:90|0:100) ;;          # simple threshold style
    40:70|70:90|70:95) ;;
    70:70|90:90|95:95) ;;      # allow single-value style too
    *)
        echo "unsupported pair: $START $END (allowed: 40 70, 70 90, 70 95)" >&2
        exit 3
        ;;
esac

PAIR="$START $END"

printf '%s\n' "$PAIR" > "$SYSFS"
if [ -d "$(dirname "$DEFAULT")" ]; then
    printf '%s\n' "$PAIR" > "$DEFAULT"
    chmod g=u "$DEFAULT" 2>/dev/null || true
    chgrp huawei-wmi "$DEFAULT" 2>/dev/null || true
fi

echo "Charge limit set to: $(cat "$SYSFS")"
