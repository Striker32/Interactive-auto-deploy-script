#!/bin/bash

tmpl_generate_layout() {
    local lang_choice
    
    ui_warn "В директории $PROJECT_MOUNT не найден docker-compose.yml"
    echo "Вы можете автоматически сгенерировать окружение для вашего стека:"
    echo "1) PHP (Apache + Базовый каркас)"
    echo "2) Указать другую подпапку (вручную)"
    echo "3) Выйти из мастера"
    echo -n "Выберите вариант: "
    read lang_choice

    case "$lang_choice" in
        1)
            tmpl_build_php
            ;;
        2)
            echo -n "Укажите имя подпапки относительно /project: "
            read SUB_PATH
            if [ -n "$SUB_PATH" ]; then
                PROJECT_MOUNT="/project/$SUB_PATH"
            fi
            ;;
        3)
            ui_info "Выход из мастера."
            exit 0
            ;;
        *)
            ui_error "Неверный выбор. Повтор анализа директории..."
            ;;
    esac
}

tmpl_build_php() {
    ui_info "\n--- Настройка окружения PHP ---"
    
    local php_ver
    local php_port
    
    # Интерактивный опрос параметров с дефолтными значениями
    echo -n "Введите версию PHP [по умолчанию: 8.2]: "
    read php_ver
    : "${php_ver:=8.2}"

    echo -n "Укажите порт для публикации приложения на хосте [по умолчанию: 8080]: "
    read php_port
    : "${php_port:=8080}"

    ui_info "Создание инфраструктурных файлов в $PROJECT_MOUNT..."

    # 1. Генерируем Dockerfile для PHP
    cat <<EOF > "$PROJECT_MOUNT/Dockerfile"
FROM php:${php_ver}-apache
RUN docker-php-ext-install pdo pdo_mysql 2>/dev/null || true
COPY . /var/www/html/
WORKDIR /var/www/html/
EOF

    # 2. Генерируем docker-compose.yml приложения
    cat <<EOF > "$PROJECT_MOUNT/docker-compose.yml"
services:
  web-php:
    build: .
    container_name: devtest_php_app
    ports:
      - "${php_port}:80"
EOF

    # 3. Создаем простейший тестовый index.php, если папка совсем пустая
    if [ ! -f "$PROJECT_MOUNT/index.php" ]; then
        cat <<EOF > "$PROJECT_MOUNT/index.php"
<?php
echo "<div style='text-align: center; margin-top: 50px; font-family: Arial, sans-serif;'>";
echo "  <h1 style='color: #2b579a;'>DevTestOps Мастер</h1>";
echo "  <p style='font-size: 1.2em;'>Инфраструктура <strong>PHP v${php_ver}</strong> успешно сгенерирована и работает внутри контейнера!</p>";
echo "  <hr style='width: 50%; margin: 20px auto;'>";
echo "  <p style='color: #666;'>Текущее время сервера: " . date('Y-m-d H:i:s') . "</p>";
echo "</div>";
EOF
    fi

    ui_success "Инфраструктура PHP успешно создана!"
    
    # Экспортируем порт, чтобы Этап 5 (сетевая проверка) подхватил его автоматически
    export APP_PORT="$php_port"
}
