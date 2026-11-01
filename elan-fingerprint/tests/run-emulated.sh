#!/usr/bin/env bash
# Тесты без оборудования: сборка libfprint, прогон umockdev-тестов elan/elanmoc
# и проверка привязки драйвера 'elan' к заданному PID (позитивный и негативный контроль).
# Использование: ./run-emulated.sh <pid-hex> [workdir]
set -euo pipefail
PID=${1:?pid}; W=$(realpath -m "${2:-$(mktemp -d)}"); HERE=$(cd "$(dirname "$0")/.." && pwd)
TAG=${LIBFPRINT_REF:-v1.94.100}
OPTS=(-Ddrivers=elan,elanmoc -Ddoc=false -Dgtk-examples=false -Dudev_rules=disabled -Dudev_hwdb=disabled)
run_variant() { # $1=src $2=testdir
  ( cd "$1/build" && FP_DEVICE_EMULATION=1 FP_DRIVERS_ALLOWLIST=elan \
    LD_LIBRARY_PATH=$PWD/libfprint GI_TYPELIB_PATH=$PWD/libfprint \
    MESON_SOURCE_ROOT=$1 MESON_BUILD_ROOT=$PWD G_TEST_SRCDIR=$1/tests G_TEST_BUILDDIR=$PWD/tests \
    python3 "$1/tests/umockdev-test.py" "$2" --test capture ) >"$W/variant.log" 2>&1
}
cd "$W"
[[ -d base ]] || git clone -q --depth 1 --branch "$TAG" https://gitlab.freedesktop.org/libfprint/libfprint.git base
rm -rf patched; cp -r base patched; rm -rf patched/build
bash "$HERE/driver/add-elan-pid.sh" "$W/patched" "$PID"
VAR=$(bash "$HERE/driver/make-mock-variant.sh" "$W/patched" "$PID")
for s in base patched; do
  [[ -d $s/build ]] || meson setup "$s/build" "$s" "${OPTS[@]}" >/dev/null
  ninja -C "$s/build" >/dev/null
done
echo "== upstream тесты драйверов (patched)"; meson test -C patched/build elan elan-cobo elanmoc | tail -8
echo "== позитивный контроль: patched + PID $PID"
run_variant "$W/patched" "$VAR" && echo PASS || { echo FAIL; tail -20 "$W/variant.log"; exit 1; }
echo "== негативный контроль: upstream без патча + PID $PID (ожидается FAIL)"
run_variant "$W/base" "$VAR" && { echo "UNEXPECTED PASS (PID уже поддерживается upstream?)"; } || echo "PASS (драйвер не привязан, как ожидалось)"
