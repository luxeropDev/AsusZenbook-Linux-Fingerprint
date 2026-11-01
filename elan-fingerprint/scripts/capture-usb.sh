#!/usr/bin/env bash
# Захват USB-трафика сенсора через usbmon (Linux) для анализа протокола.
# Использование: sudo ./capture-usb.sh <out.pcapng> [команда, напр. "fprintd-verify user"]
set -euo pipefail
OUT=${1:?out.pcapng}; shift || true
modprobe usbmon
dev=$(for d in /sys/bus/usb/devices/*; do [[ -f $d/idVendor && $(cat $d/idVendor) == 04f3 ]] && echo "$(cat $d/busnum) $(cat $d/devnum)"; done | head -1)
[[ -n $dev ]] || { echo "ELAN USB не найден"; exit 1; }
read -r bus devnum <<<"$dev"
echo "bus=$bus dev=$devnum"
tshark -i "usbmon$bus" -f "" -w "$OUT" &
tp=$!; sleep 1
if [[ $# -gt 0 ]]; then "$@" || true; else echo "Выполните действие с сенсором, затем Enter"; read -r; fi
kill -INT $tp; wait $tp || true
echo "Фильтр Wireshark: usb.device_address == $devnum"
tshark -r "$OUT" -Y "usb.device_address == $devnum && usb.capdata" -T fields \
  -e frame.number -e usb.endpoint_address -e usb.capdata 2>/dev/null | head -60
