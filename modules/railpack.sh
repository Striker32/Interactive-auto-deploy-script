#!/bin/bash

# Модуль автоматического определения стека и сборки через Railpack

railpack_deploy_raw() {
    cd "$PROJECT_MOUNT" || { ui_error "Не удалось перейти в директорию проекта $PROJECT_MOUNT"; return 1; }

    local app_image="project"
    local container_name="devtestops-auto-app"
    local buildkit_container="buildkit"

    ui_info "Анализ папки проекта движком Railpack..."
    
    touch ".devtestops_railpack_marker"
    if [ -z "$(ls -A .)" ]; then
        ui_error "Папка проекта пуста. Развертывание невозможно."
        return 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^${buildkit_container}$"; then
        ui_info "BuildKit демон не найден на хосте. Запуск служебного контейнера BuildKit..."
        
        if ! docker run --privileged -d \
            --name "$buildkit_container" \
            --restart always \
            moby/buildkit:latest >> "$LOG_FILE" 2>&1; then
            ui_error "Не удалось запустить BuildKit демон на хосте. Проверьте права Docker."
            return 1
        fi
        ui_success "Служебный контейнер BuildKit успешно запущен на хосте."
    else
        if ! docker ps --filter "name=${buildkit_container}" --filter "status=running" | grep -q "${buildkit_container}"; then
            ui_warn "BuildKit найден, но не запущен. Перезапуск..."
            docker rm -f "$buildkit_container" >/dev/null 2>&1 || true
            docker run --privileged -d --name "$buildkit_container" --net=host --restart always moby/buildkit:latest >> "$LOG_FILE" 2>&1
        fi
    fi

    export BUILDKIT_HOST="docker-container://${buildkit_container}"


    ui_warn "Railpack: Запуск сборки Docker-образа"
    ui_warn "Данный этап может занять длительное время"
    ui_warn "Логирование процесса должно скоро появится"
    
    
     railpack build . 2>&1 | tee -a "$LOG_FILE"

    if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        ui_success "Railpack успешно определил стек и собрал образ: $app_image"
    else
        ui_error "Railpack не смог собрать проект. Проверьте код приложения."
        rm -f ".devtestops_railpack_marker"
        return 1
    fi

    ui_info "Запуск изолированного контейнера приложения..."

    docker rm -f "$container_name" >/dev/null 2>&1 || true

    local run_args=(
        "-d"
        "--name" "$container_name"
        "--network" "devtestops-network"
        "-e" "PORT=8080"
        "-p" "8080:8080"
        "--restart" "on-failure"
    )

    if [ -n "$APP_DB_HOST" ]; then
        run_args+=("-e" "DB_HOST=$APP_DB_HOST")
        run_args+=("-e" "DB_PORT=$APP_DB_PORT")
        run_args+=("-e" "DB_USER=$APP_DB_USER")
        run_args+=("-e" "DB_PASSWORD=$APP_DB_PASS")
        run_args+=("-e" "DB_DATABASE=$APP_DB_NAME")
        run_args+=("-e" "DATABASE_URL=$APP_DB_TYPE://$APP_DB_USER:$APP_DB_PASS@$APP_DB_HOST:$APP_DB_PORT/$APP_DB_NAME")
    fi

    if docker run "${run_args[@]}" "$app_image"; then
        ui_success "Контейнер приложения успешно запущен!"
        export APP_PORT=8080
        return 0
    else
        ui_error "Не удалось запустить контейнер приложения."
        return 1
    fi
}
