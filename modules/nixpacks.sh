#!/bin/bash

# Модуль автоматического определения стека и сборки через Nixpacks

nixpacks_deploy_raw() {
    # Переходим в папку проекта внутри Мастера
    cd "$PROJECT_MOUNT" || { ui_error "Не удалось перейти в директорию проекта $PROJECT_MOUNT"; return 1; }

    local app_name="devtestops-auto-app"

    ui_info "Анализ папки проекта движком Nixpacks..."

    # 1. Проверяем, не пустая ли папка
    if [ -z "$(ls -A . 2>/dev/null)" ]; then
        ui_error "Папка проекта пуста. Развертывание "голого" кода невозможно."
        return 1
    fi

    # 2. Ставим маркер автогенерации Nixpacks для последующей очистки
    touch ".devtestops_nixpacks_marker"

    ui_warn "Nixpacks: Запуск анализа стека и сборки Docker-образа..."
    ui_info "Это может занять некоторое время при первом запуске (скачивание базовых пакетов)..."

    # Магия стриминга контекста: сжимаем файлы в Мастере и передаем в Nixpacks по сокету на хост
    if nixpacks build . --name "$app_name" --current-dir; then
        ui_success "Nixpacks успешно определил стек и собрал образ: $app_name"
    else
        ui_error "Nixpacks не смог собрать проект. Проверьте исходный код приложения."
        rm -f ".devtestops_nixpacks_marker"
        return 1
    fi

    ui_info "Запуск изолированного контейнера приложения..."

    # Удаляем старый контейнер приложения, если он остался от предыдущего деплоя
    docker rm -f "$app_name" &>/dev/null || true

    # Запускаем контейнер. 
    # Флаг -e PORT=8080 заставляет внутренний сервер Nixpacks слушать порт 8080
    # Пробрасываем его на жесткий порт 8080 хоста для авто-детекции нашим network.sh
    if docker run -d \
        --name "$app_name" \
        -e PORT=8080 \
        -p 8080:8080 \
        --restart on-failure \
        "$app_name"; then
        
        ui_success "Контейнер приложения успешно запущен!"
        # Экспортируем порт для модуля сети, чтобы он пропустил этот шаг без вопросов к юзеру
        export APP_PORT=8080
        return 0
    else
        ui_error "Не удалось запустить собранный контейнер."
        return 1
    fi
}
