FROM haproxy:3.2-bookworm

LABEL org.opencontainers.image.source="https://github.com/apple050620312/HAProxyPterodactyl"
LABEL org.opencontainers.image.description="HAProxy runtime image for Pterodactyl"
LABEL org.opencontainers.image.licenses="MIT"

USER root
RUN useradd --create-home --home-dir /home/container --shell /bin/bash container

COPY --chmod=755 docker/pterodactyl-entrypoint.sh /usr/local/bin/pterodactyl-entrypoint
COPY --chmod=755 docker/start-haproxy.sh /usr/local/bin/pterodactyl-haproxy

USER container
ENV USER=container \
    HOME=/home/container
WORKDIR /home/container

# The upstream HAProxy image has its own entrypoint. Pterodactyl instead passes
# the egg startup command in the STARTUP environment variable.
ENTRYPOINT []
CMD ["/usr/local/bin/pterodactyl-entrypoint"]
