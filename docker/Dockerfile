# devbox — sealed compute container with full development toolchain, for agents.
#
# The container owns its state under /data (named volume): SSH identity, repos,
# and tool caches. Host mounts (/workspace) are allowed but unsupported.
#
# Runs two ways:
#   docker run devbox                           # local: shell via docker exec
#   docker run -e DEVBOX_SSH=true devbox        # remote: sshd on :2222
#
# For Fly.io deployment, see docker/fly.toml.

FROM debian:bookworm-slim AS base

LABEL org.opencontainers.image.title="devbox"
LABEL org.opencontainers.image.description="Sealed compute container with full toolchain, for agents"
LABEL org.opencontainers.image.source="https://github.com/softwarepatterns/devbox"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Software Patterns LLC"

# tini: proper PID 1 for signal forwarding and zombie reaping.
RUN apt-get update -qq && apt-get install -y -qq tini && rm -rf /var/lib/apt/lists/*

# --- /data cache configuration ------------------------------------------------
# /data is the container's sealed territory (named volume). The entrypoint
# creates the full structure at runtime after the volume mounts:
#   /data/.ssh     SSH identity (signing key, host keys, authorized_keys)
#   /data/repos    container-native repository clones
#   /data/bun      BUN_INSTALL_CACHE_DIR
#   /data/uv       UV_CACHE_DIR
#   /data/npm      npm_config_cache
#   /data/pip      PIP_CACHE_DIR
ENV BUN_INSTALL_CACHE_DIR=/data/bun
ENV UV_CACHE_DIR=/data/uv
ENV npm_config_cache=/data/npm
ENV PIP_CACHE_DIR=/data/pip

# --- Install all devbox tooling -----------------------------------------------
COPY scripts/debian/ /tmp/devbox-scripts/
RUN bash /tmp/devbox-scripts/00-base.sh \
    && bash /tmp/devbox-scripts/10-ts.sh \
    && bash /tmp/devbox-scripts/20-python.sh \
    && bash /tmp/devbox-scripts/30-secrets.sh \
    && bash /tmp/devbox-scripts/40-cicd.sh \
    && rm -rf /tmp/devbox-scripts

# --- sshd (for remote mode) ---------------------------------------------------
# Installed and configured in the image so the same image works for both
# local (docker exec) and remote (sshd) modes. The entrypoint starts sshd
# only when DEVBOX_SSH=true is set. Port 2222: Fly's SSH proxy occupies :22.
RUN apt-get update -qq && apt-get install -y -qq openssh-server \
    && mkdir -p /run/sshd \
    && sed -i 's/^#\?Port .*/Port 2222/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && rm -rf /var/lib/apt/lists/*

# --- Entrypoint ---------------------------------------------------------------
COPY docker/entrypoint.sh /usr/local/bin/devbox-entrypoint.sh
RUN chmod 755 /usr/local/bin/devbox-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devbox-entrypoint.sh"]
# Default CMD: idle shell. DEVBOX_SSH=true starts sshd (remote mode).
CMD ["tail", "-f", "/dev/null"]
