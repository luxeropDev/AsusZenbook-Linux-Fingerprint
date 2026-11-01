#!/usr/bin/env bash
# Функциональные тесты на реальном сенсоре через fprintd.
# Использование: ./enroll-verify.sh [user] [N попыток]
set -uo pipefail
U=${1:-$USER}; N=${2:-10}
FINGER=right-index-finger
LOG=$(mktemp -d)/fp-test.log
pass=0; fail=0
step() { echo "== $*" | tee -a "$LOG"; }

step "T1 устройство видно fprintd"
fprintd-list "$U" 2>&1 | tee -a "$LOG" | grep -q "Fingerprints for user\|has no fingers enrolled\|found" \
  && echo PASS || { echo "FAIL: fprintd не видит сенсор"; exit 1; }

step "T2 регистрация $FINGER (приложите палец до завершения)"
fprintd-delete "$U" -f "$FINGER" >/dev/null 2>&1
fprintd-enroll -f "$FINGER" "$U" 2>&1 | tee -a "$LOG" | grep -q "enroll-completed" && echo PASS || { echo FAIL; exit 1; }

step "T3 истинные совпадения: $N попыток тем же пальцем (FRR)"
for i in $(seq "$N"); do
  r=$(timeout 30 fprintd-verify -f "$FINGER" "$U" 2>&1 | tee -a "$LOG" | grep -o "verify-match\|verify-no-match\|verify-retry-scan" | tail -1)
  [[ $r == verify-match ]] && pass=$((pass+1)) || fail=$((fail+1)); echo "  $i: $r"
done
echo "FRR = $fail/$N"

step "T4 ложные совпадения: $N попыток ДРУГИМ пальцем (FAR)"
fa=0
for i in $(seq "$N"); do
  r=$(timeout 30 fprintd-verify -f "$FINGER" "$U" 2>&1 | tee -a "$LOG" | grep -o "verify-match\|verify-no-match" | tail -1)
  [[ $r == verify-match ]] && fa=$((fa+1)); echo "  $i: $r"
done
echo "FAR = $fa/$N (ожидается 0)"

step "T5 сохранность после перезапуска fprintd"
sudo systemctl restart fprintd; sleep 1
fprintd-list "$U" 2>&1 | grep -q "$FINGER" && echo PASS || echo FAIL

step "T6 PAM без входа (pamtester, сервис sudo)"
command -v pamtester >/dev/null && pamtester sudo "$U" authenticate || echo "pamtester не установлен"
echo "Лог: $LOG"
[[ $fa -eq 0 ]]
