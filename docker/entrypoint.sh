#!/usr/bin/env bash
# devbox entrypoint: ensure /data cache structure exists, then exec the CMD.
#
# Runs AFTER volume mounts (Docker's lifecycle: image layers → volumes → entrypoint).
# Idempotent: mkdir -p is a no-op if dirs already exist (from Dockerfile or a
# seeded named volume). The only case where this is strictly necessary is a
# bind mount to an empty host directory over /data, which hides Dockerfile-
# created subdirs — this recreates them.
set -euo pipefail

# All persistent cache and workspace directories live under /data.
mkdir -p \
  /data/bun \
  /data/uv \
  /data/npm \
  /data/pip \
  /data/workspace

exec "$@"
