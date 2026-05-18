#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Функция для динамического получения текущей ссылки туннеля
ui_get_active_url() {
    if docker ps -q -f name="^/${PROXY_CONTAINER_NAME}$" > /dev/null; then
        local url
        url=$(docker logs "$PROXY_CONTAINER_NAME" 2>&1 | grep -oE "https://[a-zA-Z0-9.-]+.cloudpub.ru" | tail -n 1)
        if [ -n "$url" ]; then
            echo "$url"
            return 0
        fi
    fi
    return 1
}

ui_banner() {
    echo -e "${BLUE}=== DevTestOps: Мастер настройки (Контейнерная версия) ===${NC}"
    
    # Динамический статус в шапке
    local active_url
    if active_url=$(ui_get_active_url); then
        echo -e "${GREEN}[АКТИВЕН] Публичный адрес: ${active_url}${NC}"
        # Дублируем запись в файл на хосте внутри папки проекта для удобства пользователя
        #if [ -d "$PROJECT_MOUNT" ]; then
        #    echo "$active_url" > "$PROJECT_MOUNT/.devtestops_url"
        #fi
    else
        echo -e "${YELLOW}[СТАТУС] Нет активных туннелей${NC}"
    fi
    echo -e "---------------------------------------------------------\n"
}

ui_info() { echo -e "${BLUE}[ИНФО] $1${NC}"; }
ui_success() { echo -e "${GREEN}[ОК] $1${NC}"; }
ui_warn() { echo -e "${YELLOW}[ВНИМАНИЕ] $1${NC}"; }
ui_error() { echo -e "${RED}[!] Ошибка: $1${NC}"; }
