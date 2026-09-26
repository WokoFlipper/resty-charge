#!/bin/sh
# Keep the MateBook charge-limit tray applet alive.
# Launched from hypr autostart; respawns the applet if it dies (crash,
# killed during system/kernel update, tray-host restart, etc.).
# Inherits the interactive session environment (DISPLAY, DBUS, WAYLAND).
#
# No hardcoded home dirs: the applet is resolved next to this script,
# then ~/.local/bin, then PATH.

_SDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -x "$_SDIR/matebook-charge-panel" ]; then
    APP="$_SDIR/matebook-charge-panel"
elif [ -x "$HOME/.local/bin/matebook-charge-panel" ]; then
    APP="$HOME/.local/bin/matebook-charge-panel"
else
    APP="matebook-charge-panel"
fi

# Single instance only.
exec 9>/tmp/matebook-charge-watchdog.lock
flock -n 9 || exit 0

while true; do
    pgrep -f "^python3 $APP$" >/dev/null 2>&1 || {
        setsid python3 "$APP" >/dev/null 2>&1 < /dev/null &
    }
    sleep 20
done
