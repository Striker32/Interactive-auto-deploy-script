#!/bin/bash

# Глобальные константы автоматизации
export PROJECT_MOUNT="/project"
export PROXY_IMAGE_NAME="cloudpub-local:latest"
export PROXY_CONTAINER_NAME="devtestops_proxy"
export CLOPUB_DIST_URL="https://cloudpub.ru/download/stable/clo-3.0.2-stable-linux-x86_64.tar.gz"
LOG_DIR="/project"
LOG_FILE="$LOG_DIR/deploy.log"

mkdir -p "$LOG_DIR"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


for module in "$BASE_DIR"/modules/*.sh; do
    if [ -f "$module" ]; then
        source "$module"
    fi
done


run_deploy_pipeline() {
 
   trap 'pipeline_cleanup; exit 1' SIGINT SIGTERM

    env_check_existing && \
    env_prepare_proxy && \
    auth_get_token && \
    project_locate_deploy && \
    network_validate_port && \
    tunnel_launch

    trap - SIGINT SIGTERM

    if [ $? -eq 0 ]; then
       ui_success "Пайплайн успешно завершен!"
        return 0
    else
        ui_error "Пайплайн прерван на одном из этапов."
        pipeline_cleanup
	return 1
    fi
}

pipeline_cleanup() {
    trap '' SIGINT SIGTERM
    
    
    if [ -n "$PROXY_CONTAINER_NAME" ]; then
        docker rm -f "$PROXY_CONTAINER_NAME" >> "$LOG_FILE" 2>&1
    fi
    
    docker rm -f devtestops-auto-app devtestops-db >> "$LOG_FILE" 2>&1
    
    docker network rm devtestops-network >> "$LOG_FILE" 2>&1
    
    [ -f "$proxy_config" ] && rm -f "$proxy_config"
    
    ui_info "Очистка завершена."
}

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
                ;;
        esac
    done
}

main "$@"
