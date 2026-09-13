# Charge limit — battery charge-limit widget for Huawei/Honor laptops

Omarchy bar widget that caps battery charging at **70%**, **90%** or **95%**
to extend battery lifespan. The bar shows the limit as `(N)`; click it for
the preset menu with remaining runtime / time-to-limit estimation.

## Requirements

- Huawei/Honor laptop with the kernel `huawei-wmi` driver
  (`/sys/devices/platform/huawei-wmi/charge_control_thresholds` must exist).
  Covers MateBook series as well as modern Honor MagicBook and other
  Huawei/Honor models — they share the same EC charge control and the same
  Smart Charge behavior on Linux.
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

## Files

| File | Purpose |
|---|---|
| `Widget.qml` | Bar widget + popup menu |
| `manifest.json` | Omarchy plugin manifest |
| `matebook-set-limit.sh` | Writes the pair to sysfs + persists to `/etc/default` |
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

### Automatic self-heal (`selfheal/`)

```bash
cd selfheal && ./install-selfheal.sh   # needs root, run in a terminal
```

Installs:

- `huawei-wmi-mode-assert.service` — re-asserts manual mode + thresholds at
  every boot (via the udev privilege chain) and on resume from
  suspend/hibernate.
- pacman hook `huawei-charge-heal.hook` — restores mode + thresholds right
  after any `linux*`/`huawei-wmi` package transaction, no reboot required.

Verify: `systemctl is-enabled huawei-wmi-mode-assert.service` → `enabled`.

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
