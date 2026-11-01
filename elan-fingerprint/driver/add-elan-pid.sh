#!/usr/bin/env bash
# Добавляет PID в таблицу драйвера libfprint 'elan' (image-сенсоры, протокол 0x40xx/0x00xx)
# и убирает его из списка неподдерживаемых устройств.
# Использование: add-elan-pid.sh <libfprint-src-dir> <pid-hex, напр. 0c4c> [quirk: ELAN_ALL_DEV|ELAN_0C42|ELAN_0C58|ELAN_0907|ELAN_0C03]
set -euo pipefail
SRC=${1:?libfprint src}; PID=${2:?pid}; QUIRK=${3:-ELAN_ALL_DEV}
PID=$(echo "$PID" | tr 'A-F' 'a-f' | sed 's/^0x//')
[[ $PID =~ ^[0-9a-f]{4}$ ]] || { echo "PID: 4 hex-цифры"; exit 1; }
H=$SRC/libfprint/drivers/elan.h
HWDB=$SRC/libfprint/fprint-list-udev-hwdb.c
grep -q "pid = 0x$PID," "$H" && { echo "PID 0x$PID уже в elan.h"; exit 0; }
sed -i "/{.vid = 0,  .pid = 0,  .driver_data = 0},/i\\  {.vid = ELAN_VEND_ID,  .pid = 0x$PID, .driver_data = $QUIRK}," "$H"
sed -i "/{ .vid = 0x04f3, .pid = 0x$PID },/d" "$HWDB"
grep -n "0x$PID" "$H"
