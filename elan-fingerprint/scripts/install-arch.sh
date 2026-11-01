#!/usr/bin/env bash
# Установка штатного стека для поддерживаемого PID (elan / elanmoc).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Запуск через sudo"; exit 1; }
pacman -S --needed --noconfirm libfprint fprintd pamtester usbutils
# fprintd активируется через D-Bus; явный enable не требуется. Перезапуск для подхвата нового libfprint:
systemctl restart fprintd.service 2>/dev/null || true
# Удаление сторонних TOD-сборок, конфликтующих с upstream:
pacman -Qq 2>/dev/null | grep -E '^libfprint-(tod|2-tod)' && echo "ВНИМАНИЕ: установлены TOD-пакеты, удалите их" || true
echo "Готово. Проверка: fprintd-list \"$SUDO_USER\""
