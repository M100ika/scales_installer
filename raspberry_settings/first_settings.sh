#!/usr/bin/env bash
set -euo pipefail

# Пути к монтированным разделам
BOOT_DIR="/media/maxat/bootfs"
ROOTFS_DIR="/media/maxat/rootfs"

# Проверка точек монтирования
for d in "$BOOT_DIR" "$ROOTFS_DIR"; do
  if [ ! -d "$d" ]; then
    echo "Ошибка: $d не смонтирован!" >&2
    exit 1
  fi
done

echo "=== 1. HDMI ==="
cat <<EOF >> "$BOOT_DIR/config.txt"
# Принудительный HDMI
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16       # 1080p60
hdmi_drive=2       # HDMI, не DVI
disable_overscan=1 # без чёрных полей
EOF

echo "=== 2. SSH ==="
touch "$BOOT_DIR/ssh"

echo "=== 3. Wi-Fi ==="
cp "/home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/wpa_supplicant.conf" \
   "$ROOTFS_DIR/etc/wpa_supplicant/wpa_supplicant.conf"

echo "=== 4. setup_bullseye.sh ==="
mkdir -p "$ROOTFS_DIR/home/pi"
cp "/home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/setup_bullseye.sh" \
   "$ROOTFS_DIR/home/pi/"
chmod +x "$ROOTFS_DIR/home/pi/setup_bullseye.sh"

# === 5. Локали ===
# Локали будут настраиваться непосредственно на устройстве через setup_bullseye.sh

echo "Локали будут сгенерированы на устройстве при первой загрузке через setup_bullseye.sh."

echo "=== 6. Отключение blanking и включение HDMI ==="
RCLOCAL="$ROOTFS_DIR/etc/rc.local"
if [ ! -f "$RCLOCAL" ]; then
  cat <<'EOF' > "$RCLOCAL"
#!/bin/bash
for tty in /dev/tty{1..6}; do
  setterm --blank 0 --powersave off --powerdown 0 <"$tty" >"$tty"
done
/usr/bin/vcgencmd display_power 1
exit 0
EOF
  chmod +x "$RCLOCAL"
  echo "Создан /etc/rc.local."
else
  grep -q 'setterm --blank 0' "$RCLOCAL" \
    || cat <<'EOF' >> "$RCLOCAL"

# --- Блок от first_settings.sh
for tty in /dev/tty{1..6}; do
  setterm --blank 0 --powersave off --powerdown 0 <"$tty" >"$tty"
done
/usr/bin/vcgencmd display_power 1
# --- Конец блока
EOF
  echo "Дополнен /etc/rc.local."
fi

echo "=== Всё готово ==="
