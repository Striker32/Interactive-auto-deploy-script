#!/bin/bash

auth_get_token() {
    local auth_check
    
    while true; do
        echo -e "\n${YELLOW}Авторизация токена в системе Cloudpub${NC}"
        echo "Перейдите на https://cloudpub.ru, зарегистрируйтесь и получите токен."
        echo -n "Введите ваш токен (ввод скрыт): "
        read -s USER_TOKEN
        echo -e "\n"

        if [ -z "$USER_TOKEN" ]; then
            ui_error "Токен не может быть пустым."
            continue
        fi

        ui_info "Проверка валидности токена в системе CloudPub..."
        
        # Делаем запрос к CLI clo 3.x
        auth_check=$(docker run --rm "$PROXY_IMAGE_NAME" /bin/sh -c "clo set token ${USER_TOKEN} && clo ls" 2>&1) || true
        
        if echo "$auth_check" | grep -qiE "Нет зарегистрированных сервисов" || [ -z "$auth_check" ]; then
            ui_info "Ответ от сервера: $auth_check"
            ui_success "Токен успешно верифицирован!"
            # Если аккаунт просто чистый, выведем дружелюбное уведомление
            #if echo "$auth_check" | grep -q "Нет зарегистрированных сервисов"; then
                ui_info "Аккаунт верифицирован (активных сервисов пока нет)."
            #fi
            export USER_TOKEN
            break
        else
            ui_error "Введенный токен не прошел проверку системы CloudPub."
            echo -e "${RED}--- ОТВЕТ СЕРВЕРА С ОШИБКОЙ ---${NC}"
            echo "$auth_check"
            echo -e "${RED}--------------------------------${NC}"
            unset USER_TOKEN
            continue

        fi
    done
}
