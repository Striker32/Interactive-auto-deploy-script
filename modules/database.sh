#!/bin/bash

# Модуль автоматического развертывания баз данных

provision_database() {
    ui_info "Настройка окружения баз данных..."

    # Всегда создаем общую сеть для приложения и БД (ошибки игнорируем, если сеть уже есть)
    docker network create devtestops-network &>/dev/null || true

    echo -e "${YELLOW}Нужна ли база данных для этого проекта?${NC}"
    echo "1) PostgreSQL"
    echo "2) MySQL"
    echo "3) Не нужна (пропустить)"
    read -p "Ваш выбор [3]: " db_choice

    # Сбрасываем переменные на случай повторных запусков
    export APP_DB_TYPE=""
    export APP_DB_HOST=""
    export APP_DB_PORT=""
    export APP_DB_USER=""
    export APP_DB_PASS=""
    export APP_DB_NAME=""

    # Ищем дамп в текущей папке проекта (поддерживаем популярные имена)
    local init_script=""
    if [ -f "init.sql" ]; then
        init_script="$PWD/init.sql"
    elif [ -f "dump.sql" ]; then
        init_script="$PWD/dump.sql"
    elif [ -f "db.sql" ]; then
        init_script="$PWD/db.sql"
    fi

    case "$db_choice" in
        1)
            ui_info "Запуск PostgreSQL..."
            DB_PASS=$(openssl rand -hex 8)

            docker rm -f devtestops-db &>/dev/null || true

            # Собираем базовые аргументы контейнера
            local pg_args=(
                "-d"
                "--name" "devtestops-db"
                "--network" "devtestops-network"
                "-e" "POSTGRES_USER=appuser"
                "-e" "POSTGRES_PASSWORD=$DB_PASS"
                "-e" "POSTGRES_DB=appdb"
                "-v" "devtestops-pg-data:/var/lib/postgresql/data"
                "--restart" "on-failure"
            )

            # Если нашли дамп — монтируем его в папку инициализации
            if [ -n "$init_script" ]; then
                ui_info "Обнаружен скрипт инициализации: $(basename "$init_script"). Монтируем для автоимпорта..."
                pg_args+=("-v" "$init_script:/docker-entrypoint-initdb.d/init.sql:ro")
            fi

            docker run "${pg_args[@]}" postgres:15-alpine > /dev/null

            export APP_DB_TYPE="postgres"
            export APP_DB_HOST="devtestops-db"
            export APP_DB_PORT="5432"
            export APP_DB_USER="appuser"
            export APP_DB_PASS="$DB_PASS"
            export APP_DB_NAME="appdb"

            ui_success "PostgreSQL запущен! Данные сохранены в volume 'devtestops-pg-data'."
            ;;
        2)
            ui_info "Запуск MySQL..."
            DB_PASS=$(openssl rand -hex 8)

            docker rm -f devtestops-db &>/dev/null || true

            # Собираем базовые аргументы контейнера
            local mysql_args=(
                "-d"
                "--name" "devtestops-db"
                "--network" "devtestops-network"
                "-e" "MYSQL_ROOT_PASSWORD=$(openssl rand -hex 12)"
                "-e" "MYSQL_USER=appuser"
                "-e" "MYSQL_PASSWORD=$DB_PASS"
                "-e" "MYSQL_DATABASE=appdb"
                "-v" "devtestops-mysql-data:/var/lib/mysql"
                "--restart" "on-failure"
            )

            # Если нашли дамп — монтируем его в папку инициализации
            if [ -n "$init_script" ]; then
                ui_info "Обнаружен скрипт инициализации: $(basename "$init_script"). Монтируем для автоимпорта..."
                mysql_args+=("-v" "$init_script:/docker-entrypoint-initdb.d/init.sql:ro")
            fi

            docker run "${mysql_args[@]}" mysql:8.0 > /dev/null

            export APP_DB_TYPE="mysql"
            export APP_DB_HOST="devtestops-db"
            export APP_DB_PORT="3306"
            export APP_DB_USER="appuser"
            export APP_DB_PASS="$DB_PASS"
            export APP_DB_NAME="appdb"

            ui_success "MySQL запущен! Данные сохранены в volume 'devtestops-mysql-data'."
            ;;
        *)
            ui_info "Использование базы данных пропущено."
            return 0
            ;;
    esac
}
