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

# Detect architecture. Maps dpkg/arm architecture names to release suffixes.
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64)  AGE_ARCH="linux-amd64" ;;
  arm64)  AGE_ARCH="linux-arm64" ;;
  armhf)  AGE_ARCH="linux-arm" ;;
  *)
    echo "ERROR: unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# --- sops ---------------------------------------------------------------------
# Version + checksums match the services-ts monorepo convention.
SOPS_VERSION=v3.11.0
declare -A SOPS_CHECKSUMS=(
  ["amd64"]="775f1384d55decfad228e7196a3f683791914f92a473f78fc47700531c29dfef"
  ["arm64"]="c71d32f74b3a73ce283affe6ed36e221a8f1476c3d37963f60bd962fb1676681"
)

if command -v sops >/dev/null 2>&1; then
  log "sops already installed: $(sops --version)"
else
  log "Installing sops ${SOPS_VERSION} (${ARCH})..."
  curl -fsSL -o /usr/local/bin/sops \
    "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${ARCH}"
  echo "${SOPS_CHECKSUMS[$ARCH]}  /usr/local/bin/sops" | sha256sum -c -
  chmod +x /usr/local/bin/sops
  log "sops installed: $(sops --version)"
fi

# --- age ----------------------------------------------------------------------
# Encryption backend for sops.
AGE_VERSION=v1.2.1

if command -v age >/dev/null 2>&1; then
  log "age already installed: $(age --version 2>&1)"
else
  log "Installing age ${AGE_VERSION} (${AGE_ARCH})..."
  age_tmp="$(mktemp)"
  curl -fsSL -o "${age_tmp}" \
    "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-${AGE_ARCH}.tar.gz"
  # The tarball contains age/age and age/age-keygen (not version-prefixed paths).
  tar -xzf "${age_tmp}" -C /usr/local/bin \
    --strip-components=1 "age/age" "age/age-keygen"
  chmod +x /usr/local/bin/age /usr/local/bin/age-keygen
  rm -f "${age_tmp}"
  log "age installed: $(age --version 2>&1)"
fi
