# devbox local — local container for direct-access compute.
#
# No sshd, no network hardening. Access via docker exec.

FROM debian:bookworm-slim AS base

LABEL org.opencontainers.image.title="devbox-local"
LABEL org.opencontainers.image.description="Local dev container with full toolchain"
LABEL org.opencontainers.image.source="https://github.com/softwarepatterns/devbox"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Software Patterns LLC"

# tini: proper PID 1 for signal forwarding and zombie reaping.
RUN apt-get update -qq && apt-get install -y -qq tini && rm -rf /var/lib/apt/lists/*

# --- Cache configuration ------------------------------------------------------
# All tool caches live under /data so they persist with a single named volume:
#   docker run -v devbox-data:/data devbox-local
# Or bind individual caches to host directories:
#   docker run -v ~/.bun/install/cache:/data/bun devbox-local
ENV BUN_INSTALL_CACHE_DIR=/data/bun
ENV UV_CACHE_DIR=/data/uv
ENV npm_config_cache=/data/npm
ENV PIP_CACHE_DIR=/data/pip

# Create the default structure. Named volumes seed from this layer on first
# mount. The entrypoint recreates dirs if a bind mount hides them.
RUN mkdir -p /data/bun /data/uv /data/npm /data/pip

# --- Install all devbox tooling -----------------------------------------------
COPY scripts/debian/ /tmp/devbox-scripts/
RUN bash /tmp/devbox-scripts/00-base.sh \
    && bash /tmp/devbox-scripts/10-ts.sh \
    && bash /tmp/devbox-scripts/20-python.sh \
    && bash /tmp/devbox-scripts/30-secrets.sh \
    && bash /tmp/devbox-scripts/40-cicd.sh \
    && rm -rf /tmp/devbox-scripts

# --- Entrypoint ---------------------------------------------------------------
COPY docker/entrypoint.sh /usr/local/bin/devbox-entrypoint.sh
RUN chmod 755 /usr/local/bin/devbox-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devbox-entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
