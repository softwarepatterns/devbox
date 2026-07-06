# devbox local — sealed compute container.
#
# The container owns its state under /data (named volume). Host mounts are
# allowed but unsupported — /data is the container's trusted territory.
#
# Designed for docker_run_as_host_user: true (Hermes passes --user uid:gid).

FROM debian:bookworm-slim AS base

LABEL org.opencontainers.image.title="devbox-local"
LABEL org.opencontainers.image.description="Sealed compute container with full toolchain"
LABEL org.opencontainers.image.source="https://github.com/softwarepatterns/devbox"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Software Patterns LLC"

# tini: proper PID 1 for signal forwarding and zombie reaping.
RUN apt-get update -qq && apt-get install -y -qq tini && rm -rf /var/lib/apt/lists/*

# --- Home + passwd for dynamic uid --------------------------------------------
# The container runs as the host user's uid (via docker_run_as_host_user), which
# has no passwd entry. We need:
#   1. /home/devbox as HOME (writable by any uid, like /tmp)
#   2. /etc/passwd and /etc/group writable so the entrypoint can add a passwd
#      entry for the running uid (ssh-keygen requires it for signing)
RUN mkdir -p /home/devbox && chmod 1777 /home/devbox
ENV HOME=/home/devbox
ENV TMPDIR=/tmp

# --- /data structure -----------------------------------------------------------
# /data is the container's sealed territory. Expected as a named volume.
# The entrypoint creates the full structure at runtime (after volume mount):
#   /data/.ssh        generated SSH keypair + allowed_signers (sealed identity)
#   /data/repos       container's own repository clones
#   /data/bun         BUN_INSTALL_CACHE_DIR
#   /data/uv          UV_CACHE_DIR
#   /data/npm         npm_config_cache
#   /data/pip         PIP_CACHE_DIR
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

# --- Entrypoint ---------------------------------------------------------------
# /etc/passwd and /etc/group writable so the non-root entrypoint can add a
# passwd entry for the running uid. Must come AFTER apt installs (they reset
# these files to 644).
RUN chmod 666 /etc/passwd /etc/group
COPY docker/entrypoint.sh /usr/local/bin/devbox-entrypoint.sh
RUN chmod 755 /usr/local/bin/devbox-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devbox-entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
