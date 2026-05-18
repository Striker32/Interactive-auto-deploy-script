#!/bin/bash

network_validate_port() {
    if [ -f "$PROJECT_MOUNT/.devtestops_generated" ]; then
        export APP_PORT=8080
        ui_success "Для эталонного шаблона автоматически назначен порт: $APP_PORT"
        return 0
    fi

    while true; do
        echo -e "\n${YELLOW}Этап 5: Сетевые настройки${NC}"
        
        # УЛУЧШЕНИЕ UX: Если порт уже был задан в генераторе шаблонов, не спрашиваем его заново
        if [ -z "$APP_PORT" ]; then
            echo -n "Укажите порт, на котором ваше приложение слушает HTTP запросы на хосте (например, 8080): "
            read APP_PORT
        else
            ui_info "Используется автоматически настроенный порт приложения: $APP_PORT"
        fi

        if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [ "$APP_PORT" -le 0 ] || [ "$APP_PORT" -gt 65535 ]; then
            ui_error "Неверный формат порта. Введите число от 1 до 65535."
            unset APP_PORT # Сбрасываем, чтобы в случае ошибки спросить заново
            continue
        fi

        # Проверяем, слушает ли какой-либо контейнер этот внешний порт на хосте
        if ! docker ps --format '{{.Ports}}' | grep -q ":$APP_PORT->"; then
            ui_error "Порт $APP_PORT не обнаружен среди опубликованных портов Docker-контейнеров."
            echo "Убедитесь, что ваше приложение успешно запустилось и работает."
            unset APP_PORT # Сбрасываем порт, давая пользователю возможность ручного ввода/исправления
            
            # Если контейнер упал, даем пользователю шанс разобраться или ввести другой порт
            echo "Нажмите Enter для повторной проверки или изменения настроек..."
            read
            continue
        else
            ui_success "Порт $APP_PORT успешно обнаружен в Docker-сети хоста."
            export APP_PORT
            break
        fi
    done
}
