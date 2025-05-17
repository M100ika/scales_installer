#!/bin/bash

set -euo pipefail

BASE_DIR="/home/pi/scales7.1"

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

echo_green "=== Генерация локалей: en_GB и ru_RU ==="

# Устанавливаем пакет, если его ещё нет
apt-get update
apt-get install -y locales

# Раскомментируем нужные строки в /etc/locale.gen
sed -i -e 's/^# *\(en_GB.UTF-8 UTF-8\)/\1/' \
       -e 's/^# *\(ru_RU.UTF-8 UTF-8\)/\1/' \
       /etc/locale.gen

# Генерируем
locale-gen

# Убедимся, что по-умолчанию остаётся английская
update-locale LANG=en_GB.UTF-8

echo_green "Сейчас локали:"
echo "  LANG:   $(grep '^LANG=' /etc/default/locale)"
echo "  Локали сгенерированы: $(locale -a | grep -E 'en_GB\.UTF-8|ru_RU\.UTF-8')"

# Обновляем репозитории и ставим git, venv и прочее
echo_green "Обновляем apt и устанавливаем git, python3-venv и pip"
apt-get update
apt-get install -y git python3-venv python3-pip

# Создание основного каталога, если он не существует
if [ ! -d "$BASE_DIR" ]; then
    mkdir -p "$BASE_DIR"
    echo_green "Каталог $BASE_DIR создан"
else
    echo_green "Каталог $BASE_DIR уже существует"
fi


DHCPCD_CONF="/etc/dhcpcd.conf"
DHCPCD_BLOCK=$(cat <<EOF

# Статическая настройка для eth0 (Ethernet)
interface eth0
static ip_address=192.168.1.249/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 1.1.1.1
nohook wpa_supplicant
EOF
)

# Добавим блок только если его ещё нет
if ! grep -q "interface eth0" "$DHCPCD_CONF"; then
    echo_green "Добавление конфигурации eth0 в $DHCPCD_CONF"
    echo "$DHCPCD_BLOCK" | tee -a "$DHCPCD_CONF" > /dev/null
else
    echo_green "Конфигурация eth0 уже присутствует в $DHCPCD_CONF"
fi

# Перезапуск служб для применения изменений
echo_green "Перезапуск служб для применения изменений"

echo_green "Настройки успешно применены."
echo_green "Настройка локального интерфейса eth0 через dhcpcd завершена."

# Git clone
SUBMODULE_DIR="$BASE_DIR/scales_submodule"
if [ ! -d "$SUBMODULE_DIR" ]; then
    git clone https://github.com/M100ika/scales_submodule.git "$SUBMODULE_DIR"
    echo_green "Git репозиторий scales_submodule клонирован"
else
    echo_green "Каталог $SUBMODULE_DIR уже существует"
fi
if [ ! -d "$SUBMODULE_DIR/.git" ]; then
    git clone https://github.com/M100ika/scales_submodule.git "$SUBMODULE_DIR"
    echo_green "Git репозиторий scales_submodule клонирован"
else
    echo_green "Git репозиторий уже существует"
fi

# Настройка безопасности git
git config --global --add safe.directory "$SUBMODULE_DIR"
chown -R pi:pi "$BASE_DIR"

# Настройка ветки
cd "$SUBMODULE_DIR"
if git show-ref --verify --quiet refs/heads/main; then
    git branch --set-upstream-to=origin/main main
else
    echo_red "Ветка main не существует локально"
fi


# Создание логов
mkdir -p "$SUBMODULE_DIR/scales_log/error_log"

# Установка виртуального окружения и зависимостей
if [ ! -d "vscales" ]; then
    python3 -m venv vscales
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
chmod 666 "$BASE_DIR"/scales_submodule/src/config.ini
echo_green "Копирование config.ini завершено" 

cp "$BASE_DIR"/scales_submodule/services/pcf.service /etc/systemd/system/
echo_green "Копирование pcf.service завершено" 

# Перезапуск и проверка статуса сервиса
systemctl daemon-reload
systemctl enable pcf.service
systemctl restart pcf.service

if systemctl is-active --quiet pcf.service; then
    echo_green "Демон запущен"
else
    echo_red "Ошибка демона"
fi

echo_green "Настройка демона завершена"

echo_green "Настройка завершена"

# Условие удаления скрипта: только если нет ошибок
cd /home/pi
rm -- "$0"
echo_green "Скрипт успешно самоудалился."

exit 0
