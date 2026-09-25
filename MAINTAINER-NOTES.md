# Maintainer notes — resty.charge

Notes for the marketplace reviewer. User-facing docs live in `README.md`.

## What it is

Bar widget + helper script that caps battery charging (70/90/95%) on
Huawei/Honor laptops via the kernel `huawei-wmi` driver. Same EC interface
Huawei PC Manager uses on Windows.

## Hardware scope

- Requires `/sys/devices/platform/huawei-wmi/charge_control_thresholds`
  and battery `BAT1` under `/sys/class/power_supply/`.
- On other hardware the widget renders `(70)` and preset clicks do nothing
  harmful: the helper exits non-zero (`set -eu`, missing sysfs path) without
  touching any system state.
- Tested on: Honor/Huawei MateBook D15 (Ryzen 7 3700U), kernel 7.2.3-arch1-3,
  Omarchy 4.0.3, Quickshell shell.

## Validation

- `omarchy plugin validate` passes (rc=0).
- No symlinks in the folder. Plugin id is `resty.charge` (not `omarchy.*`).
- All QML entry points are safe relative paths.
- Live-tested: preset switching, threshold persistence, menu rendering,
  shell reloads — no QML errors in `omarchy-shell` journal.

## selfheal/ directory (optional, not loaded by the shell)

Boot/resume systemd service + pacman hook + installer against the known
Smart Charge issue (EC re-enables Smart Charge on reboot, ignoring limits).
Arch/pacman-specific, needs root via `install-selfheal.sh`. Safe to ignore
during plugin review — it is never executed by the widget itself.

## sleep-reset-layout.sh (optional, not loaded by the shell)

User-level workaround for an Omarchy suspend/lock system bug: the lock
screen keeps a non-Latin layout after resume and rejects the password
(upstream fix proposed in omacom/omarchy#13227). Watches `PrepareForSleep`
via `dbus-monitor` and runs `hyprctl switchxkblayout <kbd> 0` on every
keyboard. No root, no system files touched, never executed by the widget —
safe to ignore during plugin review.

## Support

Issues and hardware reports (other Huawei/Honor models, different `BATn`
names): https://github.com/WokoFlipper/resty-charge/issues
