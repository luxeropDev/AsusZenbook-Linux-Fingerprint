#!/usr/bin/env bash
# Безопасное включение pam_fprintd для выбранных PAM-сервисов (Arch Linux, KDE Plasma 6).
# Принципы:
#  - отпечаток = "sufficient" (дополнительный путь), пароль остается рабочим;
#  - резервная копия каждого файла; откат: ./apply-pam.sh --revert;
#  - SDDM (вход в сеанс) не изменяется по умолчанию: KWallet требует пароль для разблокировки.
# Перед запуском откройте второй root-терминал (sudo -i) для отката при ошибке.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Запуск через sudo"; exit 1; }
LINE="auth       sufficient   pam_fprintd.so max-tries=3 timeout=15"
SERVICES=${SERVICES:-"sudo polkit-1"}
BK=/etc/pam.d/.fprint-backup

if [[ ${1:-} == --revert ]]; then
  for f in "$BK"/*; do [[ -f $f ]] && cp -a "$f" "/etc/pam.d/$(basename "$f")" && echo "restored $(basename "$f")"; done
  exit 0
fi

pacman -Q fprintd >/dev/null
fprintd-list "${SUDO_USER:?}" | grep -q finger || { echo "Нет зарегистрированных отпечатков у $SUDO_USER"; exit 1; }
mkdir -p "$BK"; chmod 700 "$BK"

for s in $SERVICES; do
  f=/etc/pam.d/$s
  if [[ ! -f $f ]]; then
    [[ $s == polkit-1 ]] && printf '#%%PAM-1.0\nauth       include      system-auth\naccount    include      system-auth\npassword   include      system-auth\nsession    include      system-auth\n' > "$f" || { echo "нет $f"; continue; }
  fi
  [[ -f $BK/$s ]] || cp -a "$f" "$BK/$s"
  grep -q pam_fprintd.so "$f" && { echo "$s: уже настроен"; continue; }
  # Вставка перед первой auth-строкой.
  awk -v l="$LINE" '!d && /^auth/ {print l; d=1} {print}' "$f" > "$f.new" && mv "$f.new" "$f"
  echo "$s: добавлено"
done

# kscreenlocker (Plasma 6) использует отдельный сервис kde-fingerprint из пакета kscreenlocker.
[[ -f /etc/pam.d/kde-fingerprint ]] && echo "kde-fingerprint: присутствует (экран блокировки работает без правок)" \
  || echo "kde-fingerprint: отсутствует — обновите kscreenlocker"

echo "Проверка: pamtester sudo $SUDO_USER authenticate"
command -v pamtester >/dev/null && sudo -u "$SUDO_USER" pamtester sudo "$SUDO_USER" authenticate || true
