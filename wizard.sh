#!/bin/bash

# Глобальные константы автоматизации
export PROJECT_MOUNT="/project"
export PROXY_IMAGE_NAME="cloudpub-local:latest"
export PROXY_CONTAINER_NAME="devtestops_proxy"
export CLOPUB_DIST_URL="https://cloudpub.ru/download/stable/clo-3.0.2-stable-linux-x86_64.tar.gz"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Автоматический импорт всех модулей
for module in "$BASE_DIR"/modules/*.sh; do
    if [ -f "$module" ]; then
        source "$module"
    fi
done

# Интерактивный пайплайн деплоя (бывшая функция main)
# Интерактивный пайплайн деплоя
run_deploy_pipeline() {
    # ИСПРАВЛЕНО: Если окружение уже существует, env_check_existing вернет 1.
    # Мы используем оператор '|| return', чтобы сразу выйти из функции деплоя.
    env_check_existing || return 1
    
    env_prepare_proxy       # Этап 1: Подготовка прокси образа
    auth_get_token          # Этап 2: Авторизация в цикле
    project_locate_deploy   # Этап 3: Деплой или генерация шаблона
    network_validate_port   # Этап 5: Авто-проверка или ввод порта
    tunnel_launch           # Этап 6: Старт туннеля
}

# Новая точка входа с Главным Меню
main() {
    while true; do
        clear
        ui_banner
        echo -e "${BLUE}=== ГЛАВНОЕ МЕНЮ РУКОВОДСТВА ===${NC}"
        echo "1) Развернуть новое окружение проекта (Deploy)"
        echo "2) Управление существующим окружением (Lifecycle / СТОП / СТАРТ / ОЧИСТКА)"
        echo "3) Выйти из Мастера настройки"
        echo -n "Выберите пункт меню: "
        read main_choice

        case "$main_choice" in
            1)
                run_deploy_pipeline
                echo -e "\nНажмите Enter, чтобы вернуться в главное меню..."
                read
                ;;
            2)
                lifecycle_menu
                ;;
            3)
                ui_info "До свидания!"
                exit 0
                ;;
            *)
                ui_error "Неверный выбор. Используйте цифры 1-3."
                sleep 2
                ;;
        esac
    done
}

main "$@"
