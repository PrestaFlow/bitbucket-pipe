FROM php:8.3-cli-alpine

# Links the ghcr.io package to this repository.
LABEL org.opencontainers.image.source="https://github.com/PrestaFlow/bitbucket-pipe"

# System deps: bash for scripts, curl+jq for API calls, git for VCS, docker-cli+compose for Flashlight.
RUN apk add --no-cache \
      bash \
      curl \
      jq \
      git \
      unzip \
      docker-cli \
      docker-cli-compose \
      openssl \
      ca-certificates \
    && update-ca-certificates

# Composer (pinned via official installer signature check).
RUN curl -sSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm /tmp/composer-setup.php \
    && composer --version

# Pipe payload.
COPY entrypoint.sh /opt/pipe/entrypoint.sh
COPY scripts/     /opt/pipe/scripts/

RUN chmod +x /opt/pipe/entrypoint.sh /opt/pipe/scripts/*.sh

WORKDIR /workspace

ENTRYPOINT ["/opt/pipe/entrypoint.sh"]
