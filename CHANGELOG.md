# Changelog — resty.charge

## v1.2.3 — bundled events daemon + suspend-guard fix (no widget changes)

- New `daemon/` folder: the headless events daemon (`matebook-charge-panel`,
  PASSIVE AppIndicator, no root) plus watchdog. Handles AC plug/unplug,
  limit-reached and low-battery notifications with sounds, and suspend at
  ≤12%. All paths portable (no hardcoded home dirs). Install: copy both
  files to `~/.local/bin`, add `matebook-charge-watchdog.sh` to autostart.
- Fixed: the 12% suspend branch checked the already-latched `notified_15`
  flag, so on a normal discharge suspend never fired (verified live: 10%,
  no suspend). The branch now uses its own `notified_12` flag (reset above
  12%). Marker `notified_12` identifies the fixed version.
- No widget changes.

## v1.2.2 — sleep-reset-layout: Hyprland socket self-discovery

- The workaround daemon now finds the Hyprland socket itself
  (`/run/user/<uid>/hypr/*/.socket.sock`) when the launcher did not
  propagate `HYPRLAND_INSTANCE_SIGNATURE` / `XDG_RUNTIME_DIR` — without
  this every `hyprctl` call failed silently and no reset ever happened.
- New `--reset-now` test hook proving discovery + reset without
  suspending (verified from a stripped environment).
- No widget changes.

## v1.2.1 — suspend layout workaround (docs + helper, no widget changes)

- New: `sleep-reset-layout.sh` — resets all keyboards to English on
  `PrepareForSleep`, working around an Omarchy system bug where the lock
  screen keeps a non-Latin layout after resume and rejects the password.
  **This plugin is not at fault**; upstream fix proposed in
  omacom/omarchy#13227. User-level daemon (no root), one autostart line —
  see README. Remove it once the official system fix is released.
- Manifest 1.2.1 with an updated description noting the caveat.

## v1.2.0 — sleep timer actually sleeps

- The "Sleep timer" block no longer powers the machine off. "Set" creates a
  transient systemd user timer (`resty-sleep-timer.timer`) that runs
  `systemctl suspend`; the target epoch is saved to
  `~/.cache/resty-charge-sleep-target` so the countdown display is restored
  on shell restart (only while the transient timer is still active — a reboot
  wipes it, so nothing stale can fire).
- `Cancel` stops the transient timer and removes the state file.
- Fallback at zero is now `systemctl suspend` (was `systemctl poweroff`).
- Warnings reworded to match: "Sleep in 2 minutes" / "Sleep in a minute".
- Apology: v1.1.0 scheduled `shutdown -h` while the labels already said
  "sleep timer". Labels and actions match again — sorry for the mismatch.

## v1.1.0 — sleep timer (shutdown scheduler)

- New menu block below the limit buttons: title, live value/countdown line,
  0–90 min slider (15-min steps, scale ticks), Set/Cancel buttons.
- Warnings 2 min (visual + click sound) and 1 min (critical) before the act.
- State restored on load via `shutdown --show`.
- **Note:** this version powered off (`shutdown -h`); superseded by v1.2.0.

## v1.0.0 — initial marketplace release

- Charge-limit presets 70/90/95 (`40 70`, `70 90`, `70 95`) for Huawei/Honor
  laptops via `huawei-wmi`, `(N)` bar icon, remaining-runtime estimation.
- `selfheal/` stack: boot/resume service + pacman hook against Smart Charge
  (see README), SECURITY.md, preview, uninstall docs.
