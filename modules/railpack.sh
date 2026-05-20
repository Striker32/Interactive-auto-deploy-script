#!/bin/bash

# Модуль автоматического определения стека и сборки через Railpack

railpack_deploy_raw() {
    cd "$PROJECT_MOUNT" || { ui_error "Не удалось перейти в директорию проекта $PROJECT_MOUNT"; return 1; }

    local app_image="project"
    local container_name="devtestops-auto-app"
    local buildkit_container="buildkit"

    ui_info "Анализ папки проекта движком Railpack..."

    # 1. Проверяем, не пустая ли папка
    if [ -z "$(ls -A . 2>/dev/null)" ]; then
        ui_error "Папка проекта пуста. Развертывание невозможно."
        return 1
    fi

    # 2. Обеспечиваем инфраструктуру BuildKit на хосте
    if ! docker ps --format '{{.Names}}' | grep -q "^${buildkit_container}$"; then
        ui_info "BuildKit демон не найден на хосте. Запуск служебного контейнера BuildKit..."
        
        # Запускаем официальный BuildKit на хосте в привилегированном режиме (нужно для сборки слоев)
        if ! docker run --privileged -d \
            --name "$buildkit_container" \
            --restart always \
            moby/buildkit:latest &>/dev/null; then
            ui_error "Не удалось запустить BuildKit демон на хосте. Проверьте права Docker."
            return 1
        fi
        ui_success "Служебный контейнер BuildKit успешно запущен на хосте."
    fi

    # 3. Привязываем Railpack к запущенному BuildKit через Docker-сокет
    export BUILDKIT_HOST="docker-container://${buildkit_container}"

    # 4. Ставим маркер автогенерации Railpack
    touch ".devtestops_railpack_marker"

    ui_warn "Railpack: Запуск сборки Docker-образа..."
    
    # Теперь Railpack увидит переменную BUILDKIT_HOST и отправит сборку в контейнер buildkit
    if railpack build .; then
        ui_success "Railpack успешно определил стек и собрал образ: $app_image"
    else
        ui_error "Railpack не смог собрать проект. Проверьте код приложения."
        rm -f ".devtestops_railpack_marker"
        return 1
    fi

    ui_info "Запуск изолированного контейнера приложения..."

    # Удаляем старый контейнер приложения, если он был
    docker rm -f "$container_name" &>/dev/null || true

    # Запускаем приложение (порт 8080)
ui_info "Запуск изолированного контейнера приложения..."

    docker rm -f "$container_name" &>/dev/null || true

    # Формируем базовый массив аргументов для docker run
    local run_args=(
        "-d"
        "--name" "$container_name"
        "--network" "devtestops-network" # Подключаем приложение к сети БД
        "-e" "PORT=8080"
        "-p" "8080:8080"
        "--restart" "on-failure"
    )

    # Если переменная APP_DB_HOST не пустая (значит, БД была поднята), добавляем креды
    if [ -n "$APP_DB_HOST" ]; then
        run_args+=("-e" "DB_HOST=$APP_DB_HOST")
        run_args+=("-e" "DB_PORT=$APP_DB_PORT")
        run_args+=("-e" "DB_USER=$APP_DB_USER")
        run_args+=("-e" "DB_PASSWORD=$APP_DB_PASS")
        run_args+=("-e" "DB_DATABASE=$APP_DB_NAME")
        # Универсальный URL для ORM (Django, Prisma, SQLAlchemy)
        run_args+=("-e" "DATABASE_URL=$APP_DB_TYPE://$APP_DB_USER:$APP_DB_PASS@$APP_DB_HOST:$APP_DB_PORT/$APP_DB_NAME")
    fi

    # Запускаем контейнер, разворачивая массив аргументов
    if docker run "${run_args[@]}" "$app_image"; then
        ui_success "Контейнер приложения успешно запущен!"
        export APP_PORT=8080
        return 0
    else
        ui_error "Не удалось запустить контейнер приложения."
        return 1
    fi
}
