#!/usr/bin/env bash
# Определение сенсора ELAN и маршрута поддержки в libfprint.
# Таблицы PID извлечены из libfprint upstream, commit 6f9479c3 (2026-09-02, v1.94.100):
#   libfprint/drivers/elan.h, drivers/elanmoc/elanmoc.c, fprint-list-udev-hwdb.c
set -euo pipefail

ELAN_IMG="0903 0907 0c01 0c02 0c03 0c04 0c05 0c06 0c07 0c08 0c09 0c0a 0c0b 0c0c 0c0d 0c0e 0c0f 0c10 0c11 0c12 0c13 0c14 0c15 0c16 0c17 0c18 0c19 0c1a 0c1b 0c1c 0c1d 0c1e 0c1f 0c20 0c21 0c22 0c23 0c24 0c25 0c26 0c27 0c28 0c29 0c2a 0c2b 0c2c 0c2d 0c2e 0c2f 0c30 0c31 0c32 0c33 0c3d 0c42 0c4b 0c4d 0c4f 0c63 0c6e 0c58"
ELAN_MOC="0c7d 0c7e 0c82 0c88 0c8c 0c8d 0c98 0c99 0c9c 0c9d 0c9f 0ca3 0ca7 0ca8 0cb0 0cb2 0cb6"
# 3057 исключен: HID-тачпад, через который работает elanspi.
UNSUPPORTED="036b 0c00 0c4c 0c57 0c5a 0c5e 0c60 0c6c 0c70 0c72 0c77 0c7c 0c7f 0c80 0c85 0c8a 0c8e 0c90 0ca2 24cc 2706 3032 3058 3066 3087 309f 30c6 3104 310d 3128 3195 31fc 3201 3212"

in_list() { [[ " $2 " == *" $1 "* ]]; }

echo "== Модель =="
cat /sys/class/dmi/id/product_name 2>/dev/null || echo "DMI недоступен"
cat /sys/class/dmi/id/bios_version 2>/dev/null | sed 's/^/BIOS: /' || true

echo "== USB-устройства ELAN (VID 04f3) =="
found=0
for d in "${SYSFS:-/sys}"/bus/usb/devices/*; do
  [[ -f $d/idVendor ]] || continue
  [[ $(cat "$d/idVendor") == 04f3 ]] || continue
  pid=$(cat "$d/idProduct"); prod=$(cat "$d/product" 2>/dev/null || echo "?")
  found=1
  echo "04f3:$pid  product=\"$prod\"  sysfs=$d  autosuspend=$(cat "$d/power/control" 2>/dev/null)"
  if in_list "$pid" "$ELAN_IMG"; then
    echo "  -> ПОДДЕРЖИВАЕТСЯ: драйвер libfprint 'elan' (image, сопоставление на хосте, NBIS/bozorth3)"
  elif in_list "$pid" "$ELAN_MOC"; then
    echo "  -> ПОДДЕРЖИВАЕТСЯ: драйвер libfprint 'elanmoc' (match-on-chip)"
  elif in_list "$pid" "$UNSUPPORTED"; then
    echo "  -> В СПИСКЕ НЕПОДДЕРЖИВАЕМЫХ libfprint. См. docs/reverse-engineering.md"
  else
    echo "  -> НЕИЗВЕСТЕН libfprint. Возможен тачпад/HID. Проверьте product и интерфейсы:"
  fi
  for i in "$d":*; do
    if [[ -f $i/bInterfaceClass ]]; then
      echo "     intf $(basename "$i") class=$(cat "$i/bInterfaceClass") driver=$([[ -e $i/driver ]] && basename "$(readlink -f "$i/driver")" || echo none)"
    fi
  done
done
[[ $found == 1 ]] || echo "USB-устройств ELAN нет. Проверьте BIOS (Fingerprint enabled) и SPI/I2C: ls /sys/bus/spi/devices; grep -l ELAN /sys/bus/acpi/devices/*/hid"

echo "== ACPI ELAN (для SPI-сенсоров elanspi) =="
grep -H ELAN70 /sys/bus/acpi/devices/*/hid 2>/dev/null || echo "нет ELAN70xx"

echo "== Состояние стека =="
pacman -Q libfprint fprintd 2>/dev/null || echo "libfprint/fprintd не установлены"
command -v fprintd-list >/dev/null && fprintd-list "$USER" 2>&1 | head -5 || true
