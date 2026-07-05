#!/usr/bin/env bash
# devbox remote entrypoint: prepare /data caches, generate host keys,
# inject SSH key, then exec the CMD (sshd).
set -euo pipefail

# Cache and workspace directories. Created at runtime because volumes mount
# AFTER the image layers but BEFORE this entrypoint runs. See docker/entrypoint.sh
# for the shared version. This is the remote variant — same dirs plus host key setup.
mkdir -p \
  /data/bun \
  /data/uv \
  /data/npm \
  /data/pip \
  /data/workspace

# Generate SSH host keys if they don't exist.
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
