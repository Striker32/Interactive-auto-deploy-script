#!/bin/bash

# Модуль автоматического развертывания баз данных

provision_database() {
    ui_info "Настройка окружения баз данных..."

    # Всегда создаем общую сеть для приложения и БД (ошибки игнорируем, если сеть уже есть)
    docker network create devtestops-network >> "$LOG_FILE" 2>&1 || true

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
    if [ -f "*.sql" ]; then
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

	    #
            docker rm -f devtestops-db >/dev/null 2>&1 || true
	    docker volume rm devtestops-pg-data >/dev/null 2>&1 || true

            # Запускаем БЕЗ монтирования файла дампа (только чистый volume)
            docker run -d \
                --name devtestops-db \
                --network devtestops-network \
                -e POSTGRES_USER=appuser \
                -e POSTGRES_PASSWORD=$DB_PASS \
                -e POSTGRES_DB=appdb \
                -v devtestops-pg-data:/var/lib/postgresql/data \
                --restart on-failure \
                postgres:15-alpine >> "$LOG_FILE" 2>&1

            export APP_DB_TYPE="postgres"
            export APP_DB_HOST="devtestops-db"
            export APP_DB_PORT="5432"
            export APP_DB_USER="appuser"
            export APP_DB_PASS="$DB_PASS"
            export APP_DB_NAME="appdb"

            # Если нашли дамп — ждем, пока БД «проснется», и заливаем через STDIN
            if [ -n "$init_script" ]; then
                ui_info "Обнаружен скрипт: $(basename "$init_script"). Ожидание готовности СУБД..."
                
                local counter=0
                # Ждем готовности базы принимать соединения (макс 15 сек)
                until docker exec devtestops-db pg_isready -U appuser -d appdb >> "$LOG_FILE" 2>&1; do
                    sleep 1
                    counter=$((counter + 1))
                    if [ $counter -gt 15 ]; then
                        ui_error "База данных не успела запуститься. Пропуск импорта."
                        break
                    fi
                done

                # База готова? Стримим файл напрямую в psql
                if [ $counter -le 15 ]; then
                    ui_info "Импорт структуры и данных из $(basename "$init_script")..."
                    if docker exec -i devtestops-db psql -U appuser -d appdb < "$init_script" >> "$LOG_FILE" 2>&1; then
                        ui_success "Дамп успешно импортирован!"
                    else
                        ui_error "Ошибка при выполнении SQL-скрипта дампа."
			return 1
                    fi
                fi
            fi

            ui_success "PostgreSQL успешно настроен!"
            ;;
2)
            

	    ui_info "Запуск MySQL..."
            DB_PASS=$(openssl rand -hex 8)

            docker rm -f devtestops-db >> "$LOG_FILE" 2>&1 || true
	    docker volume rm devtestops-mysql-data >> "$LOG_FILE" 2>&1 || true

            docker run -d \
                --name devtestops-db \
                --network devtestops-network \
                -e MYSQL_ROOT_PASSWORD=$(openssl rand -hex 12) \
                -e MYSQL_USER=appuser \
                -e MYSQL_PASSWORD="$DB_PASS" \
                -e MYSQL_DATABASE=appdb \
                -v devtestops-mysql-data:/var/lib/mysql \
                --restart on-failure \
                mysql:8.0 >> "$LOG_FILE" 2>&1

            export APP_DB_TYPE="mysql"
            export APP_DB_HOST="devtestops-db"
            export APP_DB_PORT="3306"
            export APP_DB_USER="appuser"
            export APP_DB_PASS="$DB_PASS"
            export APP_DB_NAME="appdb"

	    local counter=0
            ui_info "Ожидание готовности MySQL..."
            # Флаг -h 127.0.0.1 заставит утилиту проверять сетевой порт.
            # Это гарантирует, что цикл завершится ТОЛЬКО когда начнется Фаза 2.
            until docker exec devtestops-db mysqladmin ping -h 127.0.0.1 -u appuser -p"$DB_PASS" >> "$LOG_FILE" 2>&1; do
                sleep 1
                counter=$((counter + 1))
                if [ $counter -gt 30 ]; then
                    ui_error "MySQL не запустился за отведенное время."
		    return 1
                    break
                fi
            done

            # Если база успешно поднялась — заливаем дамп
            if [ $counter -le 30 ]; then
                if [ -n "$init_script" ]; then
                    ui_info "Импорт структуры и данных в MySQL..."
                    # Временно убираем, чтобы в консоли развертывания
                    # видеть реальную ошибку, если что-то пойдет не так с самим SQL
                    if docker exec -i -e MYSQL_PWD="$DB_PASS" devtestops-db mysql -u appuser appdb < "$init_script"; then
                        ui_success "Дамп в MySQL успешно импортирован!"
                    else
                        ui_error "Ошибка при выполнении SQL-скрипта в MySQL."
			return 1
                    fi
                else
                    ui_success "MySQL успешно запущен (пустая БД)."
                fi
            fi
            ui_success "MySQL успешно настроен! Данные сохранены в volume 'devtestops-mysql-data'."
            ;;
    esac
}
