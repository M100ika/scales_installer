#!/bin/bash

set -euo pipefail

BASE_DIR="/home/pi/scales7.1"
DOWNLOADS="/home/pi/Downloads/" 

echo_green() {
    echo -e "\e[32m$1\e[0m"
}

echo_red() {
    echo -e "\e[31m$1\e[0m"
}

sudo apt-get update
sudo apt-get install libminizip1
sudo apt-get install -f 
# Проверка наличия прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    echo_red "Этот скрипт нужно запускать с правами суперпользователя (root)." >&2
    exit 1
fi

# Создание основного каталога, если он не существует
if [ ! -d "$BASE_DIR" ]; then
    mkdir -p "$BASE_DIR"
    echo_green "Каталог $BASE_DIR создан"
else
    echo_green "Каталог $BASE_DIR уже существует"
fi

# Удаление существующего подключения eth0, если оно есть
if nmcli connection show | grep -q 'eth0'; then
    nmcli connection delete eth0
    echo_green "Существующее подключение eth0 удалено"
fi

# Настройка NetworkManager для исключения eth0
echo -e "[keyfile]\nunmanaged-devices=interface-name:eth0" > /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager
echo_green "NetworkManager больше не управляет интерфейсом eth0."

sleep 30

# Включение и запуск systemd-networkd
systemctl enable systemd-networkd
systemctl start systemd-networkd
echo_green "systemd-networkd активирован и запущен."

# Конфигурация для eth0 через systemd-networkd
cat <<EOF > /etc/systemd/network/10-eth0.network
[Match]
Name=eth0

[Network]
Address=192.168.1.249/24
EOF

systemctl restart systemd-networkd
echo_green "Настройка локального интерфейса eth0 через systemd-networkd завершена."

# # Создание или обновление Wi-Fi подключения
# nmcli connection add type wifi ifname wlan0 con-name "REET1212scales-auto" autoconnect yes ssid 'REET1212scales' || \
# nmcli connection modify "REET1212scales-auto" autoconnect yes wifi-sec.key-mgmt wpa-psk wifi-sec.psk '19571212'

# echo_green "WiFi подключение 'REET1212scales-auto' настроено для автоматического подключения"

# Установка Git репозитория
cd "$BASE_DIR" 
if [ ! -d ".git" ]; then
    git init
    git clone https://github.com/M100ika/scales_submodule.git
    git config --global --add safe.directory "$BASE_DIR" 
    echo_green "Git репозиторий настроен"
else
    echo_green "Git репозиторий уже существует"
fi

cd "$BASE_DIR"/scales_submodule

# Установка виртуального окружения и зависимостей
if [ ! -d "vscales" ]; then
    python -m venv vscales
    echo_green "Виртуальное окружение создано"
else
    echo_green "Виртуальное окружение уже существует"
fi

source "$BASE_DIR"/scales_submodule/vscales/bin/activate
if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
    echo_green "Зависимости установлены"
else
    echo_green "Файл requirements.txt не найден"
fi

echo_green "Настройка виртуального окружения завершена"

# Копирование конфигурационных файлов
cp "$BASE_DIR"/scales_submodule/services/config.ini "$BASE_DIR"/scales_submodule/src/
sudo chmod 777 "$BASE_DIR"/scales_submodule/src/config.ini
chmod +x "$BASE_DIR"/scales_submodule/src/config.ini
echo_green "Копирование config.ini завершено" 

cp "$BASE_DIR"/scales_submodule/services/pcf.service /etc/systemd/system
echo_green "Копирование pcf.service завершено" 

# Перезапуск и проверка статуса сервиса
sudo systemctl restart pcf.service
if systemctl is-active --quiet pcf.service; then
    echo_green "Демон запущен"
else
    echo_green "Ошибка демона"
fi

echo_green "Настройка демона завершена"

# Установка TeamViewer
cd "$DOWNLOADS"
wget https://download.teamviewer.com/download/linux/teamviewer-host_armhf.deb
dpkg -i teamviewer-host_armhf.deb
echo_green "Установка TeamViewer завершена"

echo_green "Настройка завершена"

# Условие удаления скрипта: только если нет ошибок
if [ $? -eq 0 ]; then
    rm -- "$0"
    echo_green "Скрипт успешно самоудалился."
fi
exit 0
