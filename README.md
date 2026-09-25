# Charge limit — battery charge-limit widget for Huawei/Honor laptops

Omarchy bar widget that caps battery charging at **70%**, **90%** or **95%**
to extend battery lifespan. The bar shows the limit as `(N)`; click it for
the preset menu with remaining runtime / time-to-limit estimation.

> **Works on any Linux.** The charge-limit method itself (sysfs pair,
> `matebook-set-limit.sh`, Smart Charge WMI reset) is distro-independent —
> all it needs is a kernel with the `huawei-wmi` driver. Only the bar
> widget requires Omarchy/Quickshell; the `selfheal/` pacman hook is
> Arch-only, but the same two scripts restore the limit manually anywhere
> (see Troubleshooting).

## Requirements

- Huawei/Honor laptop with the kernel `huawei-wmi` driver
  (`/sys/devices/platform/huawei-wmi/charge_control_thresholds` must exist).
  Covers MateBook series as well as modern Honor MagicBook and other
  Huawei/Honor models — they share the same EC charge control and the same
  Smart Charge behavior on Linux.
- Kernel **≥ 5.5**: battery protection on the standard battery charge API
  landed in `huawei-wmi` v3.3 (merged in 5.5). Kernels 5.0–5.4 carry an older
  driver revision; < 5.0 needs the DKMS module from
  `aymanbagabas/Huawei-WMI`.
- Battery `BAT1` under `/sys/class/power_supply/` (adjust the sysfs paths in
  `Widget.qml` if your model exposes a different `BATn`).
- Your user in the `huawei-wmi` group (the `huawei-wmi` package udev rule
  handles permissions): `sudo usermod -aG huawei-wmi $USER`

## Install

```bash
# 1. helper script (no root needed at runtime thanks to the group above)
install -m 755 matebook-set-limit.sh ~/.local/bin/matebook-set-limit.sh

# 2. widget
mkdir -p ~/.config/omarchy/plugins
cp -r /path/to/resty-charge ~/.config/omarchy/plugins/resty.charge

# 3. validate + enable
omarchy plugin validate ~/.config/omarchy/plugins/resty.charge
omarchy plugin enable resty.charge
```

Or install straight from git:

```bash
omarchy plugin add https://github.com/<you>/resty-charge --enable
```

## How it works

Presets map to EC start/end pairs: `70 → 40 70`, `90 → 70 90`, `95 → 70 95`.
Charging starts below `start` and stops at `end`; above `end` the EC reports
`Not charging` and the machine runs on AC. The time field estimates remaining
runtime from live current (`charge_now / current_now`), or time-to-limit
while charging. Data refreshes every 30 seconds.

## Sleep timer

The menu also has a sleep timer: pick 15–90 minutes on the slider
(15-minute steps), press **Set**. The widget shows a live countdown, warns
visually 2 minutes and 1 minute before sleep, and **Cancel** aborts it.
Scheduling uses a transient systemd user timer (`resty-sleep-timer.timer`)
running `systemctl suspend`, so it survives shell restarts; on load the
widget restores the display from the saved target, but only while the
transient timer is still active (a reboot wipes it, so nothing stale can
fire). At zero the widget also issues `systemctl suspend` directly as
a fallback.

> **v1.1.0 note:** the timer originally scheduled `shutdown -h` (full power
> off) while the labels already said “sleep”. As of v1.2.0 the mechanism
> matches the labels — suspend only. Sorry for the mismatch.

## Files

| File | Purpose |
|---|---|
| `Widget.qml` | Bar widget + popup menu |
| `manifest.json` | Omarchy plugin manifest |
| `matebook-set-limit.sh` | Writes the pair to sysfs + persists to `/etc/default` |
| `sleep-reset-layout.sh` | Optional pre-sleep layout reset (see Known issue below) |
| `selfheal/` | Boot/resume service + pacman hook against kernel-update breakage (see below) |

## Known issue: limit stops working after reboot / kernel update

After every reboot the embedded controller returns to **Smart Charge** mode,
which ignores all thresholds and charges to 100%. A kernel update can do the
same (module rebind). Symptoms: threshold file shows e.g. `40 70` but the
battery keeps charging past it.

Manual fix (root):

```bash
sudo sh -c 'echo 0x462848011503 > /sys/kernel/debug/huawei-wmi/arg'
sudo cat /sys/kernel/debug/huawei-wmi/call   # status 0x01 => repeat
sudo cat /sys/kernel/debug/huawei-wmi/call   # status 0x00 => OK
~/.local/bin/matebook-set-limit.sh 40 70
```

This is the same WMI mode call Huawei PC Manager sends on Windows.

### Automatic self-heal (`selfheal/`, optional)

```bash
cd selfheal && ./install-selfheal.sh   # needs root, run in a terminal
```

Optional and never runs on its own: only this explicit installer crosses
the privilege boundary (sudo, in your terminal). See [SECURITY.md](SECURITY.md)
for exactly what gets installed where.

Installs:

- `huawei-wmi-mode-assert.service` — re-asserts manual mode + thresholds at
  every boot (via the udev privilege chain) and on resume from
  suspend/hibernate.
- pacman hook `huawei-charge-heal.hook` — restores mode + thresholds right
  after any `linux*`/`huawei-wmi` package transaction, no reboot required.

Verify: `systemctl is-enabled huawei-wmi-mode-assert.service` → `enabled`.

## Known issue: lock screen keeps a non-Latin layout after suspend (Omarchy bug — not this plugin)

> **This plugin is not at fault.** A critical bug was found in the system:
> Omarchy's suspend path (`PrepareForSleep` → `omarchy-system-sleep-lock`
> → `omarchy-shell lock lock`) never resets the keyboard layout, while the
> manual lock path (`omarchy-system-lock`) does — it runs
> `hyprctl switchxkblayout all 0`. XKB layout survives suspend, so if you
> sleep on e.g. Russian, the lock screen after resume is also Russian and
> the password is rejected (Cyrillic instead of Latin), forcing a hard
> reboot. This affects the sleep timer above and any suspend, not just this
> widget.
>
> Upstream fix proposed: https://github.com/omacom/omarchy/pull/13227 —
> until it lands, use the bundled workaround below.

### Workaround: `sleep-reset-layout.sh`

Resets all keyboards to layout 0 (English) on every `PrepareForSleep`
signal, before the lock screen appears (layout is global, so even a
late reset still fixes subsequent keypresses):

```bash
install -m 755 sleep-reset-layout.sh ~/.local/bin/sleep-reset-layout.sh
```

and add to `~/.config/hypr/autostart.lua`:

```lua
o.launch_on_start("sleep-reset-layout.sh")
```

User-level daemon, no root, watches the same D-Bus signal as Omarchy's own
sleep monitor and touches nothing else. Remove it once the official system
fix is released.

## Uninstall

```bash
# 1. remove the widget (keeps your bar layout clean)
omarchy plugin disable resty.charge
omarchy plugin remove resty.charge
# (equivalent manual way: delete ~/.config/omarchy/plugins/resty.charge/)

# 2. helper script (optional)
rm -f ~/.local/bin/matebook-set-limit.sh

# 3. self-heal stack (only if you installed it)
sudo systemctl disable huawei-wmi-mode-assert.service
sudo rm -f /etc/systemd/system/huawei-wmi-mode-assert.service \
  /etc/pacman.d/hooks/huawei-charge-heal.hook \
  /usr/local/bin/huawei-wmi-sfi.sh \
  /usr/local/bin/huawei-charge-heal.sh
sudo systemctl daemon-reload
# Your last charge limit stays in the EC until changed; to uncap fully:
# echo '95 100' | sudo tee /sys/devices/platform/huawei-wmi/charge_control_thresholds
```

The widget never touches your Omarchy/bar configuration files on install or
removal — it only adds its own folder. The charge limit itself is applied
exclusively on your clicks; nothing is written silently.

## License

MIT — see [LICENSE](LICENSE).
