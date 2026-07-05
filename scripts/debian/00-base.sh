#!/usr/bin/env bash
# devbox/scripts/debian/00-base.sh
# Core system packages every devbox needs.
# Idempotent: safe to run multiple times.
#
# Targets: Debian 12 (bookworm), Debian 13 (trixie), Ubuntu 22.04+, Ubuntu 24.04+
set -euo pipefail

log() { echo "[devbox:base] $*"; }

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log "Updating apt and installing core packages..."
apt-get update -qq
apt-get install -y --no-install-recommends \
  bash \
  git \
  curl \
  wget \
  ca-certificates \
  gnupg \
  jq \
  ripgrep \
  vim \
  build-essential \
  unzip \
  xz-utils \
  file \
  less \
  openssh-client \
  python3 \
  python3-pip \
  pkg-config \
  openssh-server \
  tmux \
  htop \
  sudo \
  tree \
  ca-certificates \
  | tail -1
rm -rf /var/lib/apt/lists/*

log "base packages installed"
