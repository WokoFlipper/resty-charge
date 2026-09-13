#!/bin/sh
# Assert manual charge mode exactly like Huawei PC Manager does on Windows:
# the SFI WMI call switches the EC out of Smart Charge so the persisted
# thresholds in charge_control_thresholds are honoured. Runs at boot
# (via udev privilege chain), on resume, and after system updates.
set -eu

UC="/sys/kernel/debug/huawei-wmi"
WMI="/sys/devices/platform/huawei-wmi/charge_control_thresholds"
DEF="/etc/default/huawei-wmi/charge_control_thresholds"

if [ -w "$UC/arg" ]; then
    # Set charge mode to manual limits (Smart Charge off).
    echo 0x462848011503 > "$UC/arg"
    cat "$UC/call" >/dev/null 2>&1 || true   # status 0x01 => repeat
    cat "$UC/call" >/dev/null 2>&1 || true   # status 0x00 => OK
fi

if [ -r "$DEF" ] && [ -w "$WMI" ]; then
    cp -- "$DEF" "$WMI"
fi

exit 0
