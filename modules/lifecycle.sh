#!/bin/bash

lifecycle_menu() {
    while true; do
        echo -e "\n${BLUE}=== Управление существующим окружением ===${NC}"
        echo "1) [Статус]  Проверить состояние контейнеров и туннеля"
        echo "2) [Стоп]    Временно остановить приложение и туннель"
        echo "3) [Старт]   Запустить остановленное окружение"
        echo "4) [Очистка] Полное удаление (Graceful Shutdown) и освобождение портов"
        echo "5) Назад в главное меню"
        echo -n "Выберите действие: "
        read lifecycle_choice

        case "$lifecycle_choice" in
            1) lifecycle_status ;;
            2) lifecycle_stop ;;
            3) lifecycle_start ;;
            4) lifecycle_cleanup; break ;; # После полной очистки выходим в главное меню, так как проекта больше нет
            5) break ;;
            *) ui_error "Неверный выбор." ;;
        esac
    done
}

#!/bin/bash

# ... (оставляем lifecycle_menu без изменений) ...

lifecycle_status() {
    ui_info "Проверка статуса контейнеров..."
    
    echo -e "\n${YELLOW}Контейнеры проекта в $PROJECT_MOUNT:${NC}"
    if [ -f "$PROJECT_MOUNT/docker-compose.yml" ] || [ -f "$PROJECT_MOUNT/docker-compose.yaml" ]; then
        cd "$PROJECT_MOUNT" && docker compose ps
    else
        echo "Файлы конфигурации проекта не найдены."
    fi

    echo -e "\n${YELLOW}Статус прокси-туннеля:${NC}"
    if docker ps -a -f name="^/${PROXY_CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "$PROXY_CONTAINER_NAME"; then
        docker ps -f name="^/${PROXY_CONTAINER_NAME}$" --format "Имя: {{.Names}} | Статус: {{.Status}}"
        
        # Дополнительно выводим URL в статусе
        local current_url
        if current_url=$(docker logs "$PROXY_CONTAINER_NAME" 2>&1 | grep -oE "https://[a-zA-Z0-9.-]+.cloudpub.ru" | tail -n 1); then
            echo -e "${GREEN}Адрес туннеля: $current_url${NC}"
        fi
    else
        echo "Контейнер туннеля не существует."
    fi
    
    echo -e "\nНажмите Enter, чтобы вернуться в меню управления..."
    read
}

# ... (lifecycle_stop и lifecycle_start оставляем без изменений) ...

lifecycle_cleanup() {
    ui_warn "Остановка и удаление контейнеров...."

    local app_name="devtestops-auto-app"

    # 1. Уничтожаем прокси-туннель
    local proxy_config="/tmp/docker-compose.proxy.yml"
    if [ -f "$proxy_config" ]; then
        ui_info "Удаляю инфраструктуру туннеля..."
        docker compose -f "$proxy_config" down -v >> "$LOG_FILE" 2>&1
        rm -f "$proxy_config"
    fi
    docker rm -f "$PROXY_CONTAINER_NAME" >/dev/null 2>&1 || true

    # 2. СЦЕНАРИЙ А: Уничтожаем контейнеры приложения, если деплой шел через Docker Compose
    if [ -f "$PROJECT_MOUNT/docker-compose.yml" ] || [ -f "$PROJECT_MOUNT/docker-compose.yaml" ]; then
        ui_info "Уничтожаю контейнеры и сети приложения (Compose)..."
        cd "$PROJECT_MOUNT" && docker compose down -v --remove-orphans
    fi

# 3. СЦЕНАРИЙ Б: Уничтожаем контейнер приложения, если деплой шел через Railpack
    if [ -f "$PROJECT_MOUNT/.devtestops_railpack_marker" ]; then
        ui_info "Обнаружен маркер автодеплоя Railpack. Остановка контейнера..."
        
        docker rm -f "$app_name" >/dev/null 2>&1 || true

	docker rm -f "devtestops-db" >/dev/null 2>&1 || true
        
        echo -e "\n${YELLOW}[ПОДТВЕРЖДЕНИЕ] На хосте остался собранный Railpack-образ базы данных ($app_name).${NC}"
        echo "Вы можете оставить её, либо удалить."
	echo "Если вы хотите сохранить добавленные в БД данные при следующем развертывании,"
	echo "то следует пропустить данный этап"
        echo -n "Желаете БЕЗВОЗВРАТНО УДАЛИТЬ базу данных с хоста? (Yy/Nn): "
        read clean_image_choice

        if [[ "$clean_image_choice" =~ ^[Yy]$ ]]; then
            ui_info "Удаление Docker-образа $app_name..."
            docker rmi -f "$app_name" >> "$LOG_FILE" 2>&1
            ui_success "Образ успешно удален."
	    rm -f "$PROJECT_MOUNT/.devtestops_railpack_marker"
	else
	    echo "Образ базы данных сохранен"
        fi

    fi

    ui_success "Очистка завершена"
    echo -e "\nНажмите Enter, чтобы вернуться в главное меню..."
    read
}

lifecycle_stop() {
    ui_warn "Остановка окружения..."
    
    # 1. Останавливаем туннель
    if docker ps -q -f name="^/${PROXY_CONTAINER_NAME}$" >> "$LOG_FILE" 2>&1; then
        ui_info "Останавливаю контейнер туннеля..."
        docker stop "$PROXY_CONTAINER_NAME" >> "$LOG_FILE" 2>&1
    fi

    # 2. Останавливаем проект пользователя
    if [ -f "$PROJECT_MOUNT/docker-compose.yml" ] || [ -f "$PROJECT_MOUNT/docker-compose.yaml" ]; then
        ui_info "Останавливаю контейнеры приложения..."
        cd "$PROJECT_MOUNT" && docker compose stop
    fi
    
    ui_success "Окружение успешно переведено в спящий режим. Порты свободны."
}

lifecycle_start() {
    ui_info "Возобновление работы окружения..."

    # 1. Запускаем проект пользователя
    if [ -f "$PROJECT_MOUNT/docker-compose.yml" ] || [ -f "$PROJECT_MOUNT/docker-compose.yaml" ]; then
        ui_info "Запускаю контейнеры приложения..."
        cd "$PROJECT_MOUNT" && docker compose start
    fi

    # 2. Запускаем туннель
    if docker ps -a -f name="^/${PROXY_CONTAINER_NAME}$" >> "$LOG_FILE" 2>&1; then
        ui_info "Запускаю контейнер туннеля..."
        docker start "$PROXY_CONTAINER_NAME" >> "$LOG_FILE" 2>&1
        sleep 3
        
        ui_success "Туннель снова активен!"
        echo -e "${BLUE}Ваш публичный адрес:${NC}"
        docker logs "$PROXY_CONTAINER_NAME" 2>&1 | grep -oE "https://[a-zA-Z0-9.-]+.cloudpub.ru" | tail -n 1
    else
        ui_error "Контейнер туннеля не найден. Похоже, вам нужно запустить деплой заново."
    fi
}
