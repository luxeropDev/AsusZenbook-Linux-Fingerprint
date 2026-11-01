#!/usr/bin/env bash
# Ограничения доступа к fprintd: регистрация/удаление отпечатков только для администраторов.
set -euo pipefail
[[ $EUID -eq 0 ]] || exit 1
cat > /etc/polkit-1/rules.d/50-fprintd-admin-enroll.rules <<'R'
// Регистрация и удаление отпечатков требуют пароля администратора (группа wheel).
polkit.addRule(function(action, subject) {
  if (action.id == "net.reactivated.fprint.device.enroll" ||
      action.id == "net.reactivated.fprint.device.setusername") {
    return polkit.Result.AUTH_ADMIN_KEEP;
  }
});
R
chmod 644 /etc/polkit-1/rules.d/50-fprintd-admin-enroll.rules
# Шаблоны хранятся в /var/lib/fprint/<user>/ — доступ только root.
chmod -R go-rwx /var/lib/fprint 2>/dev/null || true
ls -ld /var/lib/fprint
