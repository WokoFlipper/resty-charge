#!/bin/bash
# Install the charge-limit self-heal stack (needs root).
# Run in a terminal: ./install-selfheal.sh
set -u
D="$(cd "$(dirname "$0")" && pwd)"
echo "==> scripts"
sudo install -m 755 "$D/huawei-wmi-sfi.sh" /usr/local/bin/huawei-wmi-sfi.sh
sudo install -m 755 "$D/huawei-charge-heal.sh" /usr/local/bin/huawei-charge-heal.sh
echo "==> boot/resume service"
sudo install -m 644 "$D/huawei-wmi-mode-assert.service" /etc/systemd/system/huawei-wmi-mode-assert.service
sudo systemctl daemon-reload
sudo systemctl enable huawei-wmi-mode-assert.service
echo "==> pacman hook (kernel/driver updates)"
sudo install -m 644 "$D/huawei-charge-heal.hook" /etc/pacman.d/hooks/huawei-charge-heal.hook
echo "==> run once now"
sudo /usr/local/bin/huawei-wmi-sfi.sh
echo "threshold: $(cat /sys/devices/platform/huawei-wmi/charge_control_thresholds 2>/dev/null)"
echo "mode-assert: $(systemctl is-enabled huawei-wmi-mode-assert.service 2>/dev/null)"
echo Done.
