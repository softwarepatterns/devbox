#!/usr/bin/env bash
# devbox remote entrypoint: prepare /data, generate host keys, inject SSH key, run sshd.
set -euo pipefail

# /data subdirectories. Created at runtime because Fly mounts the volume over
# /data, hiding anything created during build.
mkdir -p \
  /data/workspace \
  /data/uv \
  /data/npm \
  /data/bun \
  /data/cache

# Generate host keys if they don't exist.
ssh-keygen -A >/dev/null 2>&1

# Authorize the control plane's key so external clients can SSH in.
# The pubkey is injected via the CONTROL_PLANE_PUBKEY env var.
if [ -n "${CONTROL_PLANE_PUBKEY:-}" ]; then
  mkdir -p /root/.ssh
  printf '%s\n' "${CONTROL_PLANE_PUBKEY}" > /root/.ssh/authorized_keys
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/authorized_keys
else
  echo "[devbox] WARNING: CONTROL_PLANE_PUBKEY not set; no SSH access configured" >&2
fi

exec "$@"
