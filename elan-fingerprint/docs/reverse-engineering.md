# Процедура для PID без поддержки libfprint

Применяется, только если `scripts/detect.sh` показал PID вне таблиц `elan`/`elanmoc`.

## Шаг 1. Проверка совместимости с драйвером `elan` (без Windows)

Многие PID ELAN отличаются только идентификатором при одинаковом протоколе.

```sh
cd driver
ELAN_PID=<pid> makepkg -si          # libfprint с добавленным PID
sudo systemctl stop fprintd
# путь бинарника на Arch: /usr/lib/fprintd (проверка: systemctl cat fprintd | grep ExecStart)
sudo G_MESSAGES_DEBUG=all /usr/lib/fprintd -t 2>&1 | tee fprintd-debug.log
# во втором терминале:
fprintd-enroll
```

Критерии совместимости в `fprintd-debug.log`:

- `sensor dimensions, WxH:` — разумные значения (например 96x96, 144x64);
- `calibration` завершается без бесконечного цикла;
- изображение распознается (enroll проходит 5+ этапов).

Если калибровка зацикливается — пересобрать с `ELAN_QUIRK=ELAN_0C58` (30 попыток). Если изображение повернуто/искажено — `ELAN_QUIRK=ELAN_0C03` (без поворота).

Откат: `sudo pacman -S libfprint`.

## Шаг 2. Захват трафика Windows-драйвера

Требуется, если шаг 1 не дал рабочего результата (сенсор не отвечает на `40 19`/`00 0c`, либо это match-on-chip).

1. Windows-драйвер: страница поддержки ASUS UM431DA → раздел Biometric → пакет `ELAN Fingerprint Driver` (WBF). Анализ бинарного кода драйвера не нужен: протокол извлекается из USB-трафика.
2. Виртуальная машина Windows (QEMU/libvirt) с пробросом USB-устройства `04f3:<pid>`.
3. На хосте Linux: `sudo scripts/capture-usb.sh enroll-windows.pcapng`, затем регистрация отпечатка в «Параметры → Учетные записи → Windows Hello».
4. Повторить для: инициализации, успешной верификации, неудачной верификации, удаления отпечатка.

## Шаг 3. Анализ

```sh
tshark -r enroll-windows.pcapng -Y 'usb.capdata && usb.device_address==N' \
  -T fields -e frame.number -e usb.endpoint_address -e usb.capdata
```

- 2-байтовые OUT-пакеты с префиксом `40`/`00` → семейство `elan` (docs/protocol.md).
- OUT-пакеты с префиксом `40 ff` и ответами со статусами → семейство `elanmoc` (сравнить с `libfprint/drivers/elanmoc/elanmoc.h`).
- Другая структура → новый драйвер.

## Шаг 4. Новый драйвер (только при новом протоколе)

Шаблон: `libfprint/drivers/elanmoc/` (match-on-chip, `FpDevice`) или `elan.c` (image, `FpImageDevice`).
Обязательные элементы для upstream:

- таблица `FpIdEntry`, класс устройства, машина состояний `FpiSsm`;
- umockdev-тест: `sudo tests/create-driver-test.py <driver>` (захватывать боковую сторону пальца, не реальный отпечаток);
- удаление PID из `libfprint/fprint-list-udev-hwdb.c`;
- merge request в https://gitlab.freedesktop.org/libfprint/libfprint с `lsusb -v` и логом.
