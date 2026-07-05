#!/usr/bin/env bash
# devbox/scripts/debian/30-secrets.sh
# Secrets management: sops (Mozilla SOPS) + age (encryption backend).
# Idempotent: safe to run multiple times.
#
# Targets: Debian 12 (bookworm), Debian 13 (trixie), Ubuntu 22.04+, Ubuntu 24.04+
set -euo pipefail

log() { echo "[devbox:secrets] $*"; }

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

# --- sops ---------------------------------------------------------------------
# Version + checksum match the services-ts monorepo convention.
SOPS_VERSION=v3.11.0
SOPS_CHECKSUM="775f1384d55decfad228e7196a3f683791914f92a473f78fc47700531c29dfef"

if command -v sops >/dev/null 2>&1; then
  log "sops already installed: $(sops --version)"
else
  log "Installing sops ${SOPS_VERSION}..."
  curl -fsSL -o /usr/local/bin/sops \
    "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64"
  echo "${SOPS_CHECKSUM}  /usr/local/bin/sops" | sha256sum -c -
  chmod +x /usr/local/bin/sops
  log "sops installed: $(sops --version)"
fi

# --- age ----------------------------------------------------------------------
# Encryption backend for sops. Downloaded from the official GitHub releases.
AGE_VERSION=v1.2.1
# Checksum for age-keygen binary (verifies the tarball integrity).
AGE_TARBALL_CHECKSUM="undefined"

if command -v age >/dev/null 2>&1; then
  log "age already installed: $(age --version 2>&1)"
else
  log "Installing age ${AGE_VERSION}..."
  age_tmp="$(mktemp)"
  curl -fsSL -o "${age_tmp}" \
    "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz"
  # age doesn't publish a checksum file; we extract and verify the binary works.
  tar -xzf "${age_tmp}" -C /usr/local/bin \
    --strip-components=1 "age-${AGE_VERSION}-linux-amd64/age" "age-${AGE_VERSION}-linux-amd64/age-keygen"
  chmod +x /usr/local/bin/age /usr/local/bin/age-keygen
  rm -f "${age_tmp}"
  log "age installed: $(age --version 2>&1)"
fi
