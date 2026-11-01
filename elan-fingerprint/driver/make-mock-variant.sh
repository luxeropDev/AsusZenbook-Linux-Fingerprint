#!/usr/bin/env bash
# Создает umockdev-вариант теста tests/elan с подменой PID 0c26 -> <pid>.
# Назначение: проверка привязки драйвера 'elan' к новому PID без оборудования.
# Использование: make-mock-variant.sh <libfprint-src-dir> <pid-hex>
set -euo pipefail
SRC=${1:?}; PID=$(echo "${2:?}" | tr 'A-F' 'a-f')
LE=$(echo "${PID:2:2}${PID:0:2}" | tr a-f A-F)   # little-endian idProduct в дескрипторе
SHORT=$(printf %x $((16#$PID)))
DST=$SRC/tests/elan-$PID
rm -rf "$DST"; cp -r "$SRC/tests/elan" "$DST"
# Правка только первого блока (сам сенсор), блоки хабов не трогаются.
awk -v le="$LE" -v pid="$PID" -v short="$SHORT" '
  BEGIN{blk=1}
  /^$/{blk++}
  blk==1 { sub(/F304260C/,"F304" le); sub(/PRODUCT=4f3\/c26\//,"PRODUCT=4f3/" short "/");
           sub(/ID_MODEL_ID=0c26/,"ID_MODEL_ID=" pid); sub(/^A: idProduct=0c26/,"A: idProduct=" pid) }
  {print}' "$SRC/tests/elan/device" > "$DST/device"
echo "$DST"
