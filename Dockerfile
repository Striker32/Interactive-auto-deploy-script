FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    iproute2 \
    procps \
#    && curl -fsSL https://get.docker.com | sh \
    && curl -sSL https://railpack.com/install.sh | bash \
    && rm -rf /var/lib/apt/lists/*

COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose

WORKDIR /app

COPY wizard.sh .
COPY modules/ ./modules/

RUN chmod +x wizard.sh modules/*.sh

ENTRYPOINT ["./wizard.sh"]
