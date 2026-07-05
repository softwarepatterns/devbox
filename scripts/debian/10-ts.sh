#!/usr/bin/env bash
# devbox/scripts/debian/10-ts.sh
# TypeScript/JavaScript toolchain: bun, node.
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

# --- node (LTS via NodeSource) -------------------------------------------------
# Some third-party npm scripts and build pipelines assume a real `node` binary
# on PATH (bun's compatibility isn't universal). Install the NodeSource LTS.
if command -v node >/dev/null 2>&1; then
  log "node already installed: $(node --version)"
else
  log "Installing node LTS (NodeSource)..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y -qq nodejs
  rm -rf /var/lib/apt/lists/*
  log "node installed: $(node --version)"
fi
