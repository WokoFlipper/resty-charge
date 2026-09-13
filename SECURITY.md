# Security notes — resty.charge

For the marketplace reviewer and for users. The plugin follows least
privilege: everything the widget itself does runs **unprivileged**.

## What runs without privileges

- `Widget.qml` — reads sysfs (`charge_control_thresholds`, `BAT1/*`) and
  runs `matebook-set-limit.sh` as the **current user**. No sudo, no pkexec,
  no setuid, no polkit calls anywhere in the widget code.
- `matebook-set-limit.sh` — writes sysfs + `/etc/default` relying on the
  `huawei-wmi` **group** (udev rule of the `huawei-wmi` package), never root.
- No network access, no data collection, no exfiltration of any kind.

## What needs root (explicit user action only)

Only `selfheal/install-selfheal.sh`, which the user runs **manually in a
terminal** (never executed by the widget, hooks, or installers). It installs:

| Artifact | Destination | Purpose |
|---|---|---|
| `huawei-wmi-sfi.sh` | `/usr/local/bin/` | WMI mode reset + threshold re-apply |
| `huawei-charge-heal.sh` | `/usr/local/bin/` | Wrapper called by the hook/service |
| `huawei-wmi-mode-assert.service` | `/etc/systemd/system/` | Boot/resume re-assert (oneshot) |
| `huawei-charge-heal.hook` | `/etc/pacman.d/hooks/` | PostTransaction restore on kernel/driver updates |

All four files are plain, auditable shell/systemd/hook text in `selfheal/`.
The service is `oneshot`, runs only `huawei-wmi-sfi.sh`, touches only the
two charge-control paths. The hook fires only on `linux*`/`huawei-wmi`
transactions. To remove every privileged trace, follow
README → Uninstall (step 3).

## Threat model summary

- Worst case of a compromised widget QML: attacker code runs **as the user**,
  same as any bar widget. It cannot escalate: privilege boundaries
  (`/usr/local/bin`, `/etc/systemd`, pacman hooks) are only crossed by the
  user explicitly running the installer in a terminal with sudo.
- The installer performs no downloads and contacts no network hosts.
