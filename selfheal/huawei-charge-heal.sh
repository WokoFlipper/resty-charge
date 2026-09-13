#!/bin/sh
# huawei-charge-heal.sh — restore Huawei charge control right after a
# kernel/driver package transaction. Installed as a pacman PostTransaction
# hook (see huawei-charge-heal.hook in this directory).
#
# Runs as root. Delegates to huawei-wmi-sfi.sh which re-asserts manual
# charge mode (Smart Charge off — the same WMI call Huawei PC Manager makes
# on Windows) and copies the persisted threshold (/etc/default) back into
# sysfs. The bar widget re-reads the value within seconds, and the
# boot/resume service covers reboots.
#

DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/huawei-wmi-sfi.sh"
exit 0
