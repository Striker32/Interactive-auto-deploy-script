r#!/bin/bash

env_prepare_proxy() {
    ui_info "Этап 1: Подготовка локального прокси-образа..."
    
    # ИСПРАВЛЕНИЕ №1: Весь процесс сборки (включая docker build) должен быть строго внутри IF
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${PROXY_IMAGE_NAME}$"; then
        ui_warn "Образ $PROXY_IMAGE_NAME не найден. Скачиваю бинарник и собираю образ..."
        
        local tmp_dir="/tmp/clopub_build"
        mkdir -p "$tmp_dir"
        
        if ! curl -sSL "$CLOPUB_DIST_URL" -o "$tmp_dir/clo.tar.gz"; then
            ui_error "Не удалось скачать дистрибутив CloudPub."
            return 1
        fi # ИСПРАВЛЕНИЕ №2: Убран мусорный 'Tint', поставлен 'fi'
        
        tar -xzf "$tmp_dir/clo.tar.gz" -C "$tmp_dir"
        local binary_path
        binary_path=$(find "$tmp_dir" -type f -name "clo" | head -n 1)
        
        if [ -z "$binary_path" ]; then
            ui_error "Бинарный файл clo не найден в архиве."
            return 1
        fi
        
        cp "$binary_path" "$BASE_DIR/clo"
        rm -rf "$tmp_dir"

        # ИСПРАВЛЕНИЕ №3: docker build перенесен сюда. Он выполнится только если файла 'clo' еще нет в образах.
        docker build -t "$PROXY_IMAGE_NAME" -f- "$BASE_DIR" <<EOF >> "$LOG_FILE" 2>&1
FROM debian:bookworm-slim
RUN groupadd -g 10001 proxygroup && \
    useradd -u 10001 -g proxygroup -m -s /bin/bash proxyuser
COPY clo /usr/local/bin/clo
RUN chmod +x /usr/local/bin/clo
WORKDIR /home/proxyuser
RUN chown -R proxyuser:proxygroup /home/proxyuser
USER proxyuser
EOF
        # Чистим за собой тяжелый бинарник на хосте после сборки образа
        rm -f "$BASE_DIR/clo"
        ui_success "Локальный прокси-образ успешно собран и готов."
    else
        ui_success "Локальный прокси-образ уже существует в системе."
    fi
}

env_check_existing() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER_NAME}$"; then
        echo -e "\n${YELLOW}[ВНИМАНИЕ] Обнаружено ранее созданное окружение для этого проекта!${NC}"
        echo "----------------------------------------------------------------------"
        echo -e "• Если вы хотите просто ${GREEN}ВКЛЮЧИТЬ${NC} или ${RED}ВЫКЛЮЧИТЬ${NC} его, используйте Пункт 2 (Управление)."
        echo -e "• Если вы хотите ${YELLOW}ПЕРЕСОЗДАТЬ${NC} сервер с нуля (изменить токен, порт или стек),"
        echo -e "  вам необходимо сначала выполнить ${RED}Очистку (Пункт 2 -> 4)${NC}."
        echo "----------------------------------------------------------------------"
        echo -n "Хотите перейти в меню управления прямо сейчас? (y/n): "
        read user_answer

        if [[ "$user_answer" =~ ^[YyДд]$ ]]; then
            lifecycle_menu
        fi
        
        return 1
    fi
    
    return 0
}
