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

    case "$db_choice" in
        1)
            ui_info "Запуск PostgreSQL..."
            # Генерируем случайный безопасный пароль
            DB_PASS=$(openssl rand -hex 8)
            
            # Удаляем старый контейнер БД, если он завис
            docker rm -f devtestops-db &>/dev/null || true
            
            # Запускаем Postgres с привязкой к постоянному volume 'devtestops-pg-data'
            docker run -d \
                --name devtestops-db \
                --network devtestops-network \
                -e POSTGRES_USER=appuser \
                -e POSTGRES_PASSWORD=$DB_PASS \
                -e POSTGRES_DB=appdb \
                -v devtestops-pg-data:/var/lib/postgresql/data \
                --restart on-failure \
                postgres:15-alpine > /dev/null
            
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
            
            docker run -d \
                --name devtestops-db \
                --network devtestops-network \
                -e MYSQL_ROOT_PASSWORD=$(openssl rand -hex 12) \
                -e MYSQL_USER=appuser \
                -e MYSQL_PASSWORD=$DB_PASS \
                -e MYSQL_DATABASE=appdb \
                -v devtestops-mysql-data:/var/lib/mysql \
                --restart on-failure \
                mysql:8.0 > /dev/null
            
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
