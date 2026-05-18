#!/bin/bash

# Подключаем модуль Nixpacks
source "$(dirname "$0")/modules/nixpacks.sh"

project_locate_deploy() {
    cd "$PROJECT_MOUNT" || { ui_error "Не удалось перейти в директорию проекта $PROJECT_MOUNT"; return 1; }

    # СЦЕНАРИЙ А: Если у пользователя есть свой родной docker-compose
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        ui_info "Обнаружен существующий docker-compose файл. Запуск деплоя..."
        docker compose up -d --build
        return 0
    fi

    # СЦЕНАРИЙ Б: Если у пользователя "голый" код без докера — вызываем Nixpacks
    ui_info "Конфигурация Docker Compose не найдена."
    nixpacks_deploy_raw
}
