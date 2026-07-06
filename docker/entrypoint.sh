#!/usr/bin/env bash
# devbox local entrypoint: create a passwd entry for the running uid, prepare
# /data caches, configure git identity and signing, then exec the CMD.
#
# Runs as the host user's uid (set via docker_run_as_host_user). No root, no
# remap, no gosu — the uid already matches the mounted files. HOME is set to
# /home/devbox by the Dockerfile.
set -euo pipefail

# --- passwd entry --------------------------------------------------------------
# The host uid has no passwd entry (Docker --user sets the uid but not the
# identity). ssh-keygen requires a valid passwd entry for signing — without it,
# every signed commit fails with "No user exists for uid NNN". Create one.
# /etc/passwd and /etc/group are world-writable (set in the Dockerfile) so this
# works as a non-root user. Same pattern as VS Code Dev Containers.
if ! getent passwd "$(id -u)" >/dev/null 2>&1; then
  echo "devbox:x:$(id -u):$(id -g)::${HOME}:/bin/bash" >> /etc/passwd
  echo "devbox:x:$(id -g):" >> /etc/group
fi

# --- cache directories ---------------------------------------------------------
# mkdir -p only (never chmod). The Dockerfile creates these with chmod 1777;
# named volumes seed from that layer on first mount. Bind-mounted dirs are the
# user's responsibility — we must not change permissions on host directories.
mkdir -p /data/bun /data/uv /data/npm /data/pip

# Ensure HOME .ssh exists for the allowed_signers file if we need to generate it.
mkdir -p "$HOME/.ssh"

# --- git identity and signing -------------------------------------------------
if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
fi

# Auto-configure SSH commit signing if a public key exists at the standard path.
# Git's signingkey points at the .pub (standard); ssh-keygen resolves the
# private key from it. The private key must be present alongside it.
PUBKEY="$HOME/.ssh/id_ed25519.pub"
ALLOWED="$HOME/.ssh/allowed_signers"
if [ -f "$PUBKEY" ]; then
  git config --global gpg.format ssh
  git config --global user.signingkey "$PUBKEY"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true

  # Local signature verification. If the user already has an allowed_signers
  # file (e.g. they mounted their whole ~/.ssh), use it as-is and never
  # overwrite it. Otherwise generate a single-entry file from the public key
  # and GIT_USER_EMAIL. Without this, `git log` emits a confusing error on
  # every signed commit: "gpg.ssh.allowedSignersFile needs to be configured."
  if [ -f "$ALLOWED" ]; then
    git config --global gpg.ssh.allowedsignersfile "$ALLOWED"
  elif [ -n "${GIT_USER_EMAIL:-}" ]; then
    printf '%s %s\n' "$GIT_USER_EMAIL" "$(cat "$PUBKEY")" > "$ALLOWED"
    git config --global gpg.ssh.allowedsignersfile "$ALLOWED"
  fi
fi

exec "$@"
