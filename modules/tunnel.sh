#!/bin/bash

tunnel_launch() {
    ui_info "\nЗапуск туннеля CloudPub..."
    local proxy_config="/tmp/docker-compose.proxy.yml"

    cat <<EOF > "$proxy_config"
version: '3.8'
services:
  tunnel:
    image: $PROXY_IMAGE_NAME
    container_name: $PROXY_CONTAINER_NAME
    entrypoint: ["/bin/sh", "-c"]
    command: ["clo set token ${USER_TOKEN} && clo publish http host.docker.internal:${APP_PORT}"]
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: on-failure
EOF

    docker compose --file "$proxy_config" up -d

    ui_info "Проверка связи и инициализация публичного адреса..."
    sleep 6
    
    local log_output
    log_output=$(docker logs "$PROXY_CONTAINER_NAME" 2>&1)

    if echo "$log_output" | grep -qiE "error|Неверный|invalid"; then
        ui_error "Ошибка запуска туннеля!"
        echo "$log_output"
        docker compose -f "$proxy_config" down -v >> "$LOG_FILE" 2>&1
        rm -f "$proxy_config"
        exit 1
    fi

	ui_success "Туннель успешно инициализирован и поднят"

}
