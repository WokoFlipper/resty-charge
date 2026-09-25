#!/bin/bash
# sleep-reset-layout — сбрасывать раскладку на английскую (layout 0) перед сном,
# чтобы экран блокировки всегда принимал латинский пароль.
#
# Причина: цепочка сна Omarchy (omarchy-system-sleep-monitor → omarchy-system-sleep-lock
# → `omarchy-shell lock lock`) не трогает XKB-раскладку, а Hyprland/XKB переживают
# suspend без сброса. Если уйти в сон на русской раскладке — локскрин после
# пробуждения тоже на русской, и пароль не принимается.
#
# Запуск: exec-once из ~/.config/hypr/autostart.lua. Работает как демон:
# слушает PrepareForSleep на системной шине (как штатный монитор Omarchy)
# и переключает ВСЕ клавиатуры на layout 0 до того, как появится локскрин.
# Даже если локскрин успеет раньше — раскладка глобальная, последующие
# нажатия уже пойдут по-английски.

set -u

reset_layout() {
  local keyboards kb
  keyboards=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name' 2>/dev/null)
  # fallback на встроенную клавиатуру, если jq/hyprctl недоступны
  if [[ -z ${keyboards:-} ]]; then
    keyboards="at-translated-set-2-keyboard"
  fi
  while IFS= read -r kb; do
    [[ -n ${kb:-} ]] && hyprctl switchxkblayout "$kb" 0 >/dev/null 2>&1 || true
  done <<<"$keyboards"
}

dbus-monitor --system \
  "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" 2>/dev/null |
  while IFS= read -r line; do
    if [[ $line == *"boolean true"* ]]; then
      # true = сон начинается (false = пробуждение, ничего не делаем)
      reset_layout
    fi
  done
