#!/usr/bin/env bash
# devbox entrypoint: init the sealed /data structure (first boot only),
# configure git identity and signing, then exec the CMD.
#
# /data is the container's sealed territory. It holds:
#   .ssh/     generated keypair + allowed_signers (the box's own identity)
#   repos/    container-native repository clones
#   bun/      bun cache
#   uv/       uv cache
#   npm/      npm cache
#   pip/      pip cache
#
# On first boot (no /data/.devbox-initialized marker), the entrypoint generates
# an SSH keypair, prints the public key for registration, and marks the volume
# initialized. Subsequent boots skip generation — the identity persists.
#
# Runs as the host user's uid (set via docker_run_as_host_user).
set -euo pipefail

# --- passwd entry --------------------------------------------------------------
# The host uid has no passwd entry. ssh-keygen requires one for signing.
if ! getent passwd "$(id -u)" >/dev/null 2>&1; then
  echo "devbox:x:$(id -u):$(id -g)::${HOME}:/bin/bash" >> /etc/passwd
  echo "devbox:x:$(id -g):" >> /etc/group
fi

# --- /data structure -----------------------------------------------------------
# Create all directories. mkdir -p only (never chmod) — the named volume seeds
# from the Dockerfile layer on first mount; bind mounts are the user's concern.
mkdir -p /data/.ssh /data/repos /data/bun /data/uv /data/npm /data/pip

# Symlink ~/.ssh → /data/.ssh so all tools find keys at the standard path.
# Remove a stale symlink/directory first (never a regular dir with content).
if [ -L "$HOME/.ssh" ]; then
  rm -f "$HOME/.ssh"
elif [ -d "$HOME/.ssh" ] && [ -z "$(ls -A "$HOME/.ssh" 2>/dev/null)" ]; then
  rmdir "$HOME/.ssh" 2>/dev/null || true
fi
if [ ! -e "$HOME/.ssh" ]; then
  ln -s /data/.ssh "$HOME/.ssh"
fi

# --- init phase: generate SSH identity (first boot only) ----------------------
# The box gets its own keypair. The operator registers the public key with
# GitHub (Settings → SSH and GPG keys → Signing keys). Subsequent boots reuse
# the persisted key — the marker file makes this idempotent.
MARKER="/data/.devbox-initialized"
SSH_KEY="/data/.ssh/id_ed25519"

if [ ! -f "$MARKER" ]; then
  echo "[devbox] First boot: generating SSH keypair"

  # Use the provided identity if GIT_SIGNING_KEY is set, otherwise generate.
  if [ -n "${GIT_SIGNING_KEY:-}" ]; then
    echo "[devbox] Materializing key from GIT_SIGNING_KEY"
    printf '%s\n' "$GIT_SIGNING_KEY" > "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    ssh-keygen -y -f "$SSH_KEY" > "${SSH_KEY}.pub"
  else
    comment="${GIT_USER_EMAIL:-devbox@local}"
    ssh-keygen -t ed25519 -N "" -f "$SSH_KEY" -C "$comment" >/dev/null
    echo "[devbox] Generated new keypair. Register this public key with GitHub:"
    cat "${SSH_KEY}.pub"
  fi

  # Generate allowed_signers from the public key + email (for local verification).
  if [ -n "${GIT_USER_EMAIL:-}" ]; then
    printf '%s %s\n' "$GIT_USER_EMAIL" "$(cat "${SSH_KEY}.pub")" > /data/.ssh/allowed_signers
  fi

  # Create the marker — init is complete.
  touch "$MARKER"
  echo "[devbox] Volume initialized"
fi

# --- git identity and signing -------------------------------------------------
# Configured from env vars and the now-guaranteed-present keypair.
if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
fi

PUBKEY="${SSH_KEY}.pub"
ALLOWED="/data/.ssh/allowed_signers"
if [ -f "$PUBKEY" ]; then
  git config --global gpg.format ssh
  git config --global user.signingkey "$PUBKEY"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true

  # Point git at allowed_signers for local verification. The file was created
  # during init; if it exists (user may have added more entries), use it as-is.
  if [ -f "$ALLOWED" ]; then
    git config --global gpg.ssh.allowedsignersfile "$ALLOWED"
  fi
fi

exec "$@"
