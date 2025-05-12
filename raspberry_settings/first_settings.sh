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

# 2. Enable SSH
echo "=== 2. Enable SSH ==="
touch "$BOOT_DIR/ssh"

# 3. Отключение мастера и создание пользователя pi
# echo "=== 3. Создание userconf.txt для отключения мастера настройки ==="
# USERCONF_HASH=$(echo 'pi:raspberry' | openssl passwd -6 -stdin)
# echo "pi:$USERCONF_HASH" > "$BOOT_DIR/userconf.txt"

# 4. Настройка автологина
echo "=== 3. Настройка автологина ==="
AUTOLOGIN_DIR="$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$AUTOLOGIN_DIR"

cat <<EOF > "$AUTOLOGIN_DIR/autologin.conf"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOF

# 5. Wi-Fi конфигурация
echo "=== 4. Настройка Wi-Fi ==="
WPA_CONF="/home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/wpa_supplicant.conf"
if [ -f "$WPA_CONF" ]; then
  cp -v "$WPA_CONF" "$BOOT_DIR/wpa_supplicant.conf"
  # Копируем также в rootfs для работы после первой загрузки
  mkdir -p "$ROOTFS_DIR/etc/wpa_supplicant"
  cp -v "$WPA_CONF" "$ROOTFS_DIR/etc/wpa_supplicant/wpa_supplicant.conf"
else
  echo "ERROR: Файл wpa_supplicant.conf не найден!" >&2
  exit 1
fi

# 6. Копирование setup_bullseye.sh
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
# echo "=== 9. Добавление unblock-wifi.service ==="
# cat <<EOF > "$ROOTFS_DIR/etc/systemd/system/unblock-wifi.service"
# [Unit]
# Description=Unblock Wi-Fi at boot
# After=network-pre.target

# [Service]
# Type=oneshot
# ExecStart=/usr/sbin/rfkill unblock wifi

# [Install]
# WantedBy=multi-user.target
# EOF

# ln -sf /etc/systemd/system/unblock-wifi.service \
#        "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/unblock-wifi.service"

# 10. Создание сервиса для Wi-Fi
echo "=== Создание сервиса для Wi-Fi ==="
cat <<EOF > "$ROOTFS_DIR/etc/systemd/system/wifi-autoconnect.service"
[Unit]
Description=AutoConnect to Wi-Fi
After=network.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c '/sbin/wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf || true'
ExecStart=/bin/sh -c '/sbin/dhclient wlan0 || true'
ExecStop=/bin/sh -c '/sbin/wpa_cli terminate || true'
ExecStop=/bin/sh -c '/sbin/dhclient -r wlan0 || true'

[Install]
WantedBy=multi-user.target
EOF

chroot "$ROOTFS_DIR" systemctl enable wifi-autoconnect.service

# 11. Отключение интерактивных служб
echo "=== Отключение интерактивных служб ==="
chroot "$ROOTFS_DIR" systemctl disable raspi-config.service 2>/dev/null || true
chroot "$ROOTFS_DIR" systemctl mask firstboot.service 2>/dev/null || true
chroot "$ROOTFS_DIR" rm -f /etc/profile.d/raspi-config.sh 2>/dev/null


echo "=== Всё готово ==="
