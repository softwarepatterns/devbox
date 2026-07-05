#!/usr/bin/env bash
# devbox/scripts/debian/40-cicd.sh
# CI/CD and infrastructure CLIs: gh (GitHub CLI), flyctl (Fly.io CLI).
# Idempotent: safe to run multiple times.
#
# Targets: Debian 12 (bookworm), Debian 13 (trixie), Ubuntu 22.04+, Ubuntu 24.04+
set -euo pipefail

log() { echo "[devbox:cicd] $*"; }

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

# --- gh (GitHub CLI) ----------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
  log "gh already installed: $(gh --version | head -1)"
else
  log "Installing gh (GitHub CLI)..."
  # gh uses an apt repository. Add it for proper package management and updates.
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt-get update -qq
  apt-get install -y -qq gh
  rm -rf /var/lib/apt/lists/*
  log "gh installed: $(gh --version | head -1)"
fi

# --- flyctl (Fly.io CLI) ------------------------------------------------------
if command -v flyctl >/dev/null 2>&1; then
  log "flyctl already installed: $(flyctl version 2>&1 | head -1)"
else
  log "Installing flyctl (Fly.io CLI)..."
  curl -LfsSL https://fly.io/install.sh | sh
  # flyctl installs to /root/.fly/bin. Make it available system-wide.
  ln -sf /root/.fly/bin/flyctl /usr/local/bin/flyctl 2>/dev/null || true
  log "flyctl installed: $(flyctl version 2>&1 | head -1)"
fi
