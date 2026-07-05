#!/usr/bin/env bash
# devbox/scripts/debian/10-ts.sh
# TypeScript/JavaScript toolchain: bun.
# Idempotent: safe to run multiple times.
#
# Targets: Debian 12 (bookworm), Debian 13 (trixie), Ubuntu 22.04+, Ubuntu 24.04+
set -euo pipefail

log() { echo "[devbox:ts] $*"; }

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

if command -v bun >/dev/null 2>&1; then
  log "bun already installed: $(bun --version)"
else
  log "Installing bun..."
  export BUN_INSTALL=/usr/local
  curl -fsSL https://bun.sh/install | bash
  # bun installer adds to /usr/local/bin automatically via BUN_INSTALL
  log "bun installed: $(bun --version)"
fi
