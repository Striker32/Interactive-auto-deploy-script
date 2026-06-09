FROM debian:bookworm-slim

# Установка необходимых утилит и Docker CLI
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    iproute2 \
    procps \
    && curl -fsSL https://get.docker.com | sh \
    && curl -sSL https://railpack.com/install.sh | bash \
    && rm -rf /var/lib/apt/lists/*


WORKDIR /app

# Копируем структуру скрипта мастера
COPY wizard.sh .
COPY modules/ ./modules/

RUN chmod +x wizard.sh modules/*.sh

ENTRYPOINT ["./wizard.sh"]
