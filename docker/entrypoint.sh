#!/usr/bin/env bash
# devbox entrypoint: init /data identity, configure git signing, optionally
# start sshd, then exec the CMD.
#
# All SSH state lives under /data/.ssh and persists across restarts:
#   id_ed25519 + .pub       the box's own signing keypair (generated on init)
#   allowed_signers         for local git signature verification
#   authorized_keys         who can SSH in (from SSH_AUTHORIZED_KEY, persisted)
#   ssh_host_*_key + .pub   sshd host keys (so clients don't get warnings)
#
# Init is per-file: each file is its own init signal. Delete one, only that
# one regenerates on next boot. No marker file — presence of the target data
# IS the detection.
set -euo pipefail

log() { echo "[devbox] $*"; }

SSH_DIR="/data/.ssh"

# --- /data structure -----------------------------------------------------------
mkdir -p "$SSH_DIR" /data/repos /data/bun /data/uv /data/npm /data/pip

# Symlink ~/.ssh → /data/.ssh so all tools find keys at the standard path.
if [ -L "$HOME/.ssh" ]; then
  rm -f "$HOME/.ssh"
elif [ -d "$HOME/.ssh" ] && [ -z "$(ls -A "$HOME/.ssh" 2>/dev/null)" ]; then
  rmdir "$HOME/.ssh" 2>/dev/null || true
fi
if [ ! -e "$HOME/.ssh" ]; then
  ln -s "$SSH_DIR" "$HOME/.ssh"
fi

# --- signing keypair (generated if absent) ------------------------------------
SSH_KEY="$SSH_DIR/id_ed25519"

if [ ! -f "$SSH_KEY" ]; then
  if [ -n "${GIT_SIGNING_KEY:-}" ]; then
    log "Materializing signing key from GIT_SIGNING_KEY"
    printf '%s\n' "$GIT_SIGNING_KEY" > "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    ssh-keygen -y -f "$SSH_KEY" > "${SSH_KEY}.pub"
  else
    comment="${GIT_USER_EMAIL:-devbox}"
    log "Generating signing keypair"
    ssh-keygen -t ed25519 -N "" -f "$SSH_KEY" -C "$comment" >/dev/null
    log "Register this public key with GitHub (Settings → SSH and GPG keys → Signing keys):"
    cat "${SSH_KEY}.pub"
  fi
fi

# --- allowed_signers (generated if absent) ------------------------------------
# For local git signature verification. Uses the signing pubkey + GIT_USER_EMAIL.
ALLOWED="$SSH_DIR/allowed_signers"
if [ ! -f "$ALLOWED" ] && [ -f "${SSH_KEY}.pub" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
  printf '%s %s\n' "$GIT_USER_EMAIL" "$(cat "${SSH_KEY}.pub")" > "$ALLOWED"
fi

# --- git identity and signing -------------------------------------------------
if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
fi

PUBKEY="${SSH_KEY}.pub"
if [ -f "$PUBKEY" ]; then
  git config --global gpg.format ssh
  git config --global user.signingkey "$PUBKEY"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  if [ -f "$ALLOWED" ]; then
    git config --global gpg.ssh.allowedsignersfile "$ALLOWED"
  fi
fi

# --- sshd (remote mode) --------------------------------------------------------
# In remote mode: persist host keys and authorized_keys to /data/.ssh so they
# survive restarts. ssh-keygen -A is idempotent — only generates what's missing.
if [ "${DEVBOX_SSH:-}" = "true" ]; then
  # Host keys: generate to /data/.ssh so they persist. Point sshd at them.
  ssh-keygen -A -f /data >/dev/null 2>&1 || ssh-keygen -A >/dev/null 2>&1

  # Authorized keys: persist from env if the file doesn't exist yet.
  AUTH="$SSH_DIR/authorized_keys"
  if [ ! -f "$AUTH" ] && [ -n "${SSH_AUTHORIZED_KEY:-}" ]; then
    printf '%s\n' "${SSH_AUTHORIZED_KEY}" > "$AUTH"
  fi
  if [ ! -f "$AUTH" ]; then
    log "WARNING: DEVBOX_SSH=true but no authorized_keys; no SSH access" >&2
  fi

  # Tell sshd to use /data/.ssh for host keys and authorized_keys.
  sed -i "s|^#\?HostKey /etc/ssh/ssh_host_|HostKey /data/.ssh/ssh_host_|" /etc/ssh/sshd_config
  sed -i "s|^#\?AuthorizedKeysFile.*|AuthorizedKeysFile /data/.ssh/authorized_keys|" /etc/ssh/sshd_config

  /usr/sbin/sshd
  log "sshd listening on :2222"
fi

exec "$@"
