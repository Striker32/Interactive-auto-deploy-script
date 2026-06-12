#!/bin/bash

# Проверка на наличие docker-compose.yml
source "$(dirname "$0")/modules/railpack.sh"
source "$(dirname "$0")/modules/database.sh"

project_locate_deploy() {
    cd "$PROJECT_MOUNT" || { ui_error "Не удалось перейти в директорию проекта $PROJECT_MOUNT"; return 1; }

    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        ui_info "Обнаружен существующий docker-compose файл. Запуск деплоя..."
        docker compose up -d --build
        return 0
    fi

    ui_info "Конфигурация Docker Compose не найдена. Переход к авто-сборке."

    
    provision_database || return 1

    if ! railpack_deploy_raw; then
        return 1
    fi
}
