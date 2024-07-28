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

# Добавление сети в wpa_supplicant.conf
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
NETWORK_BLOCK="
network={
        ssid=\"REET1212scales\"
        psk=\"19571212\"
        key_mgmt=WPA-PSK
}
"

# Проверка наличия сети в wpa_supplicant.conf и добавление, если она отсутствует
echo_green "Добавление сети в $WPA_SUPPLICANT_CONF"
echo "$NETWORK_BLOCK" | sudo tee -a "$WPA_SUPPLICANT_CONF" > /dev/null


# Добавление конфигурации в dhcpcd.conf
DHCPCD_CONF="/etc/dhcpcd.conf"
DHCPCD_BLOCK="

interface eth0
static ip_address=192.168.1.249/24"

# Проверка наличия конфигурации в dhcpcd.conf и добавление, если она отсутствует
echo_green "Добавление конфигурации в $DHCPCD_CONF"
echo "$DHCPCD_BLOCK" | sudo tee -a "$DHCPCD_CONF" > /dev/null

# Перезапуск служб для применения изменений
echo_green "Перезапуск служб для применения изменений"

echo_green "Настройки успешно применены."
echo_green "Настройка локального интерфейса eth0 через systemd-networkd завершена."

# Установка Git репозитория
cd "$BASE_DIR" 
if [ ! -d ".git" ]; then
    git init
    git clone https://github.com/M100ika/scales_submodule.git
    git config --global --add safe.directory "$BASE_DIR"/scales_submodule 
    echo_green "Git репозиторий настроен"
else
    echo_green "Git репозиторий уже существует"
fi

cd "$BASE_DIR"/scales_submodule
mkdir scales_log/error_log

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

echo_green "Настройка виртуального окружения завершена"s

# Копирование конфигурационных файлов
cp "$BASE_DIR"/scales_submodule/services/config.ini "$BASE_DIR"/scales_submodule/src/
sudo chmod 777 "$BASE_DIR"/scales_submodule/src/config.ini
chmod +x "$BASE_DIR"/scales_submodule/src/config.ini
echo_green "Копирование config.ini завершено" 

cp "$BASE_DIR"/scales_submodule/services/pcf.service /etc/systemd/system/
echo_green "Копирование pcf.service завершено" 

# Перезапуск и проверка статуса сервиса
sudo systemctl enable pcf.service
sudo systemctl start pcf.service
sudo systemctl restart pcf.service
if systemctl is-active --quiet pcf.service; then
    echo_green "Демон запущен"
else
    echo_green "Ошибка демона"
fi

echo_green "Настройка демона завершена"

# Установка TeamViewer
# cd "$DOWNLOADS"
# wget https://download.teamviewer.com/download/linux/teamviewer-host_15.55.3_armhf.deb
# dpkg -i teamviewer-host_armhf.deb
# echo_green "Установка TeamViewer завершена"

echo_green "Настройка завершена"

# Условие удаления скрипта: только если нет ошибок
if [ $? -eq 0 ]; then
    rm -- "$0"
    echo_green "Скрипт успешно самоудалился."
fi
exit 0
