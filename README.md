# Charge limit — battery charge-limit widget for Huawei/Honor MateBooks

Omarchy bar widget that caps battery charging at **70%**, **90%** or **95%**
to extend battery lifespan. The bar shows the limit as `(N)`; click it for
the preset menu with remaining runtime / time-to-limit estimation.

## Requirements

- Huawei/Honor MateBook with the kernel `huawei-wmi` driver
  (`/sys/devices/platform/huawei-wmi/charge_control_thresholds` must exist)
- Battery `BAT1` under `/sys/class/power_supply/`
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

## License

MIT — see [LICENSE](LICENSE).
