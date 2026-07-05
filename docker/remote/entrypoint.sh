#!/usr/bin/env bash
# devbox remote entrypoint: prepare /data caches, generate host keys,
# inject authorized SSH key, configure git identity and signing if provided,
# then exec the CMD (sshd).
set -euo pipefail

# Cache directories. Created at runtime because volumes mount
# AFTER the image layers but BEFORE this entrypoint runs. See docker/entrypoint.sh
# for the shared version. This is the remote variant — same dirs plus host key setup.
mkdir -p \
  /data/bun \
  /data/uv \
  /data/npm \
  /data/pip

# Generate SSH host keys if they don't exist.
ssh-keygen -A >/dev/null 2>&1

# Authorize the caller's public key so external clients can SSH in.
# The pubkey is injected via the SSH_AUTHORIZED_KEY env var.
if [ -n "${SSH_AUTHORIZED_KEY:-}" ]; then
  mkdir -p /root/.ssh
  printf '%s\n' "${SSH_AUTHORIZED_KEY}" > /root/.ssh/authorized_keys
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/authorized_keys
else
  echo "[devbox] WARNING: SSH_AUTHORIZED_KEY not set; no SSH access configured" >&2
fi

# Configure git identity from env vars, if provided.
# See docker/entrypoint.sh for the rationale.
if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
fi

# Materialize the signing keypair from the GIT_SIGNING_KEY secret. Fly can only
# inject secrets as env vars, so the private key content arrives here and is
# written to the standard path. The public key is derived from it.
if [ -n "${GIT_SIGNING_KEY:-}" ]; then
  mkdir -p /root/.ssh
  printf '%s\n' "${GIT_SIGNING_KEY}" > /root/.ssh/id_ed25519
  chmod 600 /root/.ssh/id_ed25519
  ssh-keygen -y -f /root/.ssh/id_ed25519 > /root/.ssh/id_ed25519.pub
fi

# Auto-configure SSH commit signing from the standard public key path.
PUBKEY="/root/.ssh/id_ed25519.pub"
ALLOWED="/root/.ssh/allowed_signers"
if [ -f "$PUBKEY" ]; then
  git config --global gpg.format ssh
  git config --global user.signingkey "$PUBKEY"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true

  if [ -f "$ALLOWED" ]; then
    git config --global gpg.ssh.allowedsignersfile "$ALLOWED"
  elif [ -n "${GIT_USER_EMAIL:-}" ]; then
    printf '%s %s\n' "$GIT_USER_EMAIL" "$(cat "$PUBKEY")" > "$ALLOWED"
    git config --global gpg.ssh.allowedsignersfile "$ALLOWED"
  fi
fi

exec "$@"
