#!/bin/bash

BASE_DIR="/home/pi/scales7.1"
DOWNLOADS="/home/pi/Downloads/" 

# Проверка наличия прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт нужно запускать с правами суперпользователя (root)." >&2
    exit 1
fi

if [ ! -d "$BASE_DIR" ]; then
    mkdir -p "$BASE_DIR"
    echo "Каталог $BASE_DIR создан"
else
    echo "Каталог $BASE_DIR уже существует"
fi

# Удаление существующего подключения eth0, если оно есть
if nmcli connection show | grep -q 'eth0'; then
    nmcli connection delete eth0
    echo "Существующее подключение eth0 удалено"
fi

# Настройка eth0 через NetworkManager
nmcli connection add type ethernet ifname eth0 con-name eth0 ip4 192.168.1.249/24 gw4 192.168.1.1
nmcli connection modify eth0 ipv4.dns "192.168.1.1 8.8.8.8"
nmcli connection up eth0

echo "Настройка сетевого интерфейса eth0 завершена."

cd "$BASE_DIR" 

if [ ! -d ".git" ]; then
    git init
    git clone https://github.com/M100ika/scales_submodule.git
    git config --global --add safe.directory "$BASE_DIR" 
    echo "Git репозиторий настроен"
else
    echo "Git репозиторий уже существует"
fi

cd "$BASE_DIR"/scales_submodule

if [ ! -d "vscales" ]; then
    python -m venv vscales
    echo "Виртуальное окружение создано"
else
    echo "Виртуальное окружение уже существует"
fi

source "$BASE_DIR"/scales_submodule/vscales/bin/activate

# Установка зависимостей
if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
    echo "Зависимости установлены"
else
    echo "Файл requirements.txt не найден"
fi

echo "Настройка виртуального окружения завершена"

cp "$BASE_DIR"/scales_submodule/services/pcf.service /etc/systemd/system
echo "Копирование pcf.service завершено" 

# sudo systemctl restart pcf.service
sudo systemctl restart pcf.service

# Проверка статуса сервиса
if systemctl is-active --quiet pcf.service; then
    echo "Демон запущен"
else
    echo "Ошибка демона"
fi

echo "Настройка демона завершена"


cd "$DOWNLOADS"
# Установка TeamViewer
wget https://download.teamviewer.com/download/linux/teamviewer-host_armhf.deb
dpkg -i teamviewer-host_armhf.deb
echo "Установка TeamViewer завершена"

echo "Настройка завершена"