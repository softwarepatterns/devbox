# devbox remote — SSH-accessible compute target.
#
# Used by: Fly.io machines, cloud VMs, any scenario where an external client
# (agent framework, human, CI runner) connects over SSH.
#
# Security posture: sshd with key-only auth on port 2222 (Fly's hallpass
# occupies :22). authorized_keys injected at runtime via CONTROL_PLANE_PUBKEY
# env var (set as a Fly secret or Docker env). No password auth.

FROM debian:bookworm-slim AS base

LABEL org.opencontainers.image.title="devbox-remote"
LABEL org.opencontainers.image.description="SSH-accessible compute target with sshd, key-only auth, volume support"
LABEL org.opencontainers.image.source="https://github.com/softwarepatterns/devbox"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Software Patterns LLC"

# tini: proper PID 1 init process. Handles SIGTERM forwarding and zombie
# reaping. The remote variant's sshd is a proper daemon, but tini ensures
# clean shutdown and zombie reaping for spawned SSH sessions.
RUN apt-get update -qq && apt-get install -y -qq tini && rm -rf /var/lib/apt/lists/*

# --- Install all devbox tooling -----------------------------------------------
# Copy scripts and run them. Each script is idempotent and self-contained.
COPY scripts/debian/ /tmp/devbox-scripts/
RUN bash /tmp/devbox-scripts/00-base.sh \
    && bash /tmp/devbox-scripts/10-ts.sh \
    && bash /tmp/devbox-scripts/20-python.sh \
    && bash /tmp/devbox-scripts/30-secrets.sh \
    && bash /tmp/devbox-scripts/40-cicd.sh \
    && rm -rf /tmp/devbox-scripts

# --- sshd configuration -------------------------------------------------------
# Port 2222: Fly's built-in SSH proxy (hallpass) occupies :22. The service
# config in fly.toml maps external :22 → internal :2222.
RUN mkdir -p /run/sshd \
    && sed -i 's/^#\?Port .*/Port 2222/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# --- Entrypoint ---------------------------------------------------------------
COPY docker/remote/entrypoint.sh /usr/local/bin/devbox-entrypoint.sh
RUN chmod 755 /usr/local/bin/devbox-entrypoint.sh

# IMPORTANT: Do NOT create /data or WORKDIR /data in this Dockerfile.
# Fly mounts a volume at /data at runtime. Any Dockerfile layer that touches
# /data corrupts the rootfs overlay, causing every binary to return ENOENT.
# The entrypoint creates /data subdirectories at runtime after the volume mount.

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devbox-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
