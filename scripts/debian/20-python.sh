#!/usr/bin/env bash
# devbox/scripts/debian/20-python.sh
# Python toolchain: uv (fast Python package manager + resolver).
# Idempotent: safe to run multiple times.
#
# Targets: Debian 12 (bookworm), Debian 13 (trixie), Ubuntu 22.04+, Ubuntu 24.04+
set -euo pipefail

log() { echo "[devbox:python] $*"; }

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

if command -v uv >/dev/null 2>&1; then
  log "uv already installed: $(uv --version)"
else
  log "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # uv installs to ~/.local/bin. Ensure it's on PATH for non-interactive shells.
  ln -sf /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true
  log "uv installed: $(uv --version)"
fi
