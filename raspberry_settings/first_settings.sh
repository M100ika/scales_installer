#!/usr/bin/env bash
set -euo pipefail

# Пути к монтированным разделам
BOOT_DIR="/media/maxat/bootfs"
ROOTFS_DIR="/media/maxat/rootfs"
CUSTOM_CFG="/home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/config.txt"

# Проверка точек монтирования
for d in "$BOOT_DIR" "$ROOTFS_DIR"; do
  if [ ! -d "$d" ]; then
    echo "Ошибка: $d не смонтирован!" >&2
    exit 1
  fi
done

# 1. Копируем config.txt
echo "=== 1. Copy custom config.txt ==="
if [ -f "$CUSTOM_CFG" ]; then
  cp "$CUSTOM_CFG" "$BOOT_DIR/config.txt"
  echo "Скопирован кастомный config.txt в $BOOT_DIR."
else
  echo "WARNING: $CUSTOM_CFG не найден. Пропускаем копирование config.txt."
fi

# 1.1 Генерация cmdline.txt с корректным PARTUUID
echo "=== 1.1 Генерация cmdline.txt с корректным PARTUUID ==="
ROOT_DEV=$(findmnt -n -o SOURCE "$ROOTFS_DIR")
ROOT_PARTUUID=$(lsblk -no PARTUUID "$ROOT_DEV")

if [ -z "$ROOT_PARTUUID" ]; then
  echo "Ошибка: не удалось определить PARTUUID для rootfs!"
  exit 1
fi

cat <<EOF > "$BOOT_DIR/cmdline.txt"
console=tty1 root=PARTUUID=$ROOT_PARTUUID rootfstype=ext4 fsck.repair=yes rootwait consoleblank=0 vt.global_cursor_default=0
EOF
echo "Создан cmdline.txt с PARTUUID=$ROOT_PARTUUID"

# 2. SSH
echo "=== 2. Enable SSH ==="
touch "$BOOT_DIR/ssh"

# 3. Отключение мастера и создание пользователя pi
echo "=== 3. Создание userconf.txt для отключения мастера настройки ==="
USERCONF_HASH=$(echo 'pi:raspberry' | openssl passwd -6 -stdin)
echo "pi:$USERCONF_HASH" > "$BOOT_DIR/userconf.txt"

# 4. Настройка автологина
echo "=== 4. Настройка автологина с проверкой пути к agetty ==="
AUTOLOGIN_DIR="$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$AUTOLOGIN_DIR"

# Автоматически определить путь к agetty
AGETTY_PATH=$(chroot "$ROOTFS_DIR" which agetty || echo "/sbin/agetty")

cat <<EOF > "$AUTOLOGIN_DIR/autologin.conf"
[Service]
ExecStart=
ExecStart=-$AGETTY_PATH --autologin pi --noclear %I \$TERM
EOF

# 5. Wi-Fi конфиг
echo "=== 5. Wi-Fi конфигурация ==="
cp "/home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/wpa_supplicant.conf" \
   "$ROOTFS_DIR/etc/wpa_supplicant/wpa_supplicant.conf"

# 6. Скопировать setup_bullseye.sh (без chown)
echo "=== 6. Копируем setup_bullseye.sh ==="
mkdir -p "$ROOTFS_DIR/home/pi"
cp "/home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/setup_bullseye.sh" \
   "$ROOTFS_DIR/home/pi/"
chmod +x "$ROOTFS_DIR/home/pi/setup_bullseye.sh"

# 7. Удаление rc.local, если есть
echo "=== 7. Удаление rc.local, если есть ==="
RCLOCAL="$ROOTFS_DIR/etc/rc.local"
if [ -f "$RCLOCAL" ]; then
  echo "=== Найден rc.local — удаляю ==="
  rm -f "$RCLOCAL"
else
  echo "rc.local не найден — пропускаем."
fi

# 8. Отключение raspi-config.service
echo "=== 8. Отключение raspi-config.service ==="
chroot "$ROOTFS_DIR" systemctl disable raspi-config.service || true

# 9. Добавление systemd-сервиса для разблокировки Wi-Fi
echo "=== 9. Добавление unblock-wifi.service ==="
cat <<EOF > "$ROOTFS_DIR/etc/systemd/system/unblock-wifi.service"
[Unit]
Description=Unblock Wi-Fi at boot
After=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/rfkill unblock wifi

[Install]
WantedBy=multi-user.target
EOF

# Активируем сервис
ln -sf /etc/systemd/system/unblock-wifi.service "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/unblock-wifi.service"

echo "=== Всё готово ==="
