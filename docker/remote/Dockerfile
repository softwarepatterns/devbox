# devbox remote — SSH-accessible compute target.
#
# sshd with key-only auth on port 2222. authorized_keys injected at runtime
# via SSH_AUTHORIZED_KEY env var.

FROM debian:bookworm-slim AS base

LABEL org.opencontainers.image.title="devbox-remote"
LABEL org.opencontainers.image.description="SSH-accessible compute target with sshd, key-only auth, volume support"
LABEL org.opencontainers.image.source="https://github.com/softwarepatterns/devbox"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Software Patterns LLC"

# tini: proper PID 1 for signal forwarding and zombie reaping.
RUN apt-get update -qq && apt-get install -y -qq tini && rm -rf /var/lib/apt/lists/*

# --- Cache configuration ------------------------------------------------------
# Same ENV vars as the local variant. The remote variant mounts a Fly volume
# at /data, so caches persist across machine restarts automatically.
ENV BUN_INSTALL_CACHE_DIR=/data/bun
ENV UV_CACHE_DIR=/data/uv
ENV npm_config_cache=/data/npm
ENV PIP_CACHE_DIR=/data/pip

# Do NOT create /data here. Fly mounts a volume at /data at runtime; any
# Dockerfile layer that touches /data corrupts the rootfs overlay (verified
# the hard way — every binary returns ENOENT). The entrypoint creates
# subdirectories at runtime after the volume mounts.

# --- Install all devbox tooling -----------------------------------------------
COPY scripts/debian/ /tmp/devbox-scripts/
RUN bash /tmp/devbox-scripts/00-base.sh \
    && bash /tmp/devbox-scripts/10-ts.sh \
    && bash /tmp/devbox-scripts/20-python.sh \
    && bash /tmp/devbox-scripts/30-secrets.sh \
    && bash /tmp/devbox-scripts/40-cicd.sh \
    && rm -rf /tmp/devbox-scripts

# --- sshd configuration -------------------------------------------------------
# Port 2222: Fly's built-in SSH proxy (hallpass) occupies :22.
RUN mkdir -p /run/sshd \
    && sed -i 's/^#\?Port .*/Port 2222/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# --- Entrypoint ---------------------------------------------------------------
COPY docker/remote/entrypoint.sh /usr/local/bin/devbox-entrypoint.sh
RUN chmod 755 /usr/local/bin/devbox-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devbox-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
