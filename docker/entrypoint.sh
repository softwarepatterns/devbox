#!/usr/bin/env bash
# devbox entrypoint: init sealed /data (first boot), configure git identity and
# signing, optionally start sshd, then exec the CMD.
#
# Two modes:
#   DEVBOX_SSH unset  → local mode: tail -f /dev/null (access via docker exec)
#   DEVBOX_SSH=true   → remote mode: sshd on :2222 (access via SSH)
#
# In both modes the sealed /data model is identical: the container owns its
# SSH identity, repos, and caches under /data (named volume).
set -euo pipefail

log() { echo "[devbox] $*"; }

# --- passwd entry --------------------------------------------------------------
# The running uid may not have a passwd entry (docker_run_as_host_user sets
# the uid but not the identity). ssh-keygen requires a valid entry for signing.
if ! getent passwd "$(id -u)" >/dev/null 2>&1; then
  echo "devbox:x:$(id -u):$(id -g)::${HOME}:/bin/bash" >> /etc/passwd
  echo "devbox:x:$(id -g):" >> /etc/group
fi

# --- /data structure -----------------------------------------------------------
# The container's sealed territory. All dirs created here (not in the Dockerfile)
# because named volumes mount over /data at runtime, hiding image-created dirs.
mkdir -p /data/.ssh /data/repos /data/bun /data/uv /data/npm /data/pip

# Symlink ~/.ssh → /data/.ssh so all tools find keys at the standard path.
# Never overwrites a dir that has content (could be a user-provided /data/.ssh).
if [ -L "$HOME/.ssh" ]; then
  rm -f "$HOME/.ssh"
elif [ -d "$HOME/.ssh" ] && [ -z "$(ls -A "$HOME/.ssh" 2>/dev/null)" ]; then
  rmdir "$HOME/.ssh" 2>/dev/null || true
fi
if [ ! -e "$HOME/.ssh" ]; then
  ln -s /data/.ssh "$HOME/.ssh"
fi

# --- init phase: generate SSH identity (first boot only) ----------------------
# The box gets its own keypair. Register the public key with GitHub (Settings →
# SSH and GPG keys → Signing keys). Subsequent boots reuse the persisted key.
MARKER="/data/.devbox-initialized"
SSH_KEY="/data/.ssh/id_ed25519"

if [ ! -f "$MARKER" ]; then
  log "First boot: generating SSH keypair"

  if [ -n "${GIT_SIGNING_KEY:-}" ]; then
    log "Materializing key from GIT_SIGNING_KEY"
    printf '%s\n' "$GIT_SIGNING_KEY" > "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    ssh-keygen -y -f "$SSH_KEY" > "${SSH_KEY}.pub"
  else
    comment="${GIT_USER_EMAIL:-devbox@local}"
    ssh-keygen -t ed25519 -N "" -f "$SSH_KEY" -C "$comment" >/dev/null
    log "Generated new keypair. Register this public key with GitHub:"
    cat "${SSH_KEY}.pub"
  fi

  # Generate allowed_signers for local signature verification.
  if [ -n "${GIT_USER_EMAIL:-}" ]; then
    printf '%s %s\n' "$GIT_USER_EMAIL" "$(cat "${SSH_KEY}.pub")" > /data/.ssh/allowed_signers
  fi

  touch "$MARKER"
  log "Volume initialized"
fi

# --- git identity and signing -------------------------------------------------
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

  if [ -f "$ALLOWED" ]; then
    git config --global gpg.ssh.allowedsignersfile "$ALLOWED"
  fi
fi

# --- sshd (remote mode) --------------------------------------------------------
# In remote mode, authorize the caller's key and start sshd alongside the CMD.
# The authorized key is for SSH ACCESS to the box; the signing key is separate
# (generated above for git commit signing).
if [ "${DEVBOX_SSH:-}" = "true" ]; then
  # Generate host keys if they don't exist.
  ssh-keygen -A >/dev/null 2>&1

  # Authorize the caller's public key.
  if [ -n "${SSH_AUTHORIZED_KEY:-}" ]; then
    mkdir -p /root/.ssh
    printf '%s\n' "${SSH_AUTHORIZED_KEY}" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
  else
    log "WARNING: DEVBOX_SSH=true but SSH_AUTHORIZED_KEY not set; no SSH access" >&2
  fi

  # Start sshd in the background, then exec the original CMD.
  /usr/sbin/sshd
  log "sshd listening on :2222"
fi

exec "$@"
