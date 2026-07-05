#!/usr/bin/env bash
# devbox entrypoint: ensure /data cache structure exists, configure git
# identity and signing if provided, then exec the CMD.
#
# Runs AFTER volume mounts (Docker's lifecycle: image layers → volumes → entrypoint).
# Idempotent: mkdir -p is a no-op if dirs already exist (from Dockerfile or a
# seeded named volume). The only case where this is strictly necessary is a
# bind mount to an empty host directory over /data, which hides Dockerfile-
# created subdirs — this recreates them.
set -euo pipefail

# All persistent cache directories live under /data.
mkdir -p \
  /data/bun \
  /data/uv \
  /data/npm \
  /data/pip

# Configure git identity from env vars, if provided.
# One identity (user.name + user.email) sets both author and committer — no
# split-identity commits.
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
