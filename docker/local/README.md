# devbox-local

A Docker container with a full development toolchain. Start it, exec in, work.

## Features

Pre-installed: git, bun, node, uv, sops, age, gh, flyctl, ripgrep, jq, vim,
tmux, htop, python3, ssh, build-essential.

All tool caches are under `/data` for simple persistence. Clean lifecycle
with tini as PID 1 — `docker stop` works instantly.

Designed for `--user <uid>:<gid>` at launch (e.g. Hermes's
`docker_run_as_host_user: true`). The entrypoint creates a passwd entry for
the running uid at runtime, so tools like ssh-keygen work without a fixed
in-image user. HOME is `/home/devbox` (world-writable, like `/tmp`).

## Usage

### Run with a shell

```bash
docker build -f docker/local/Dockerfile -t devbox-local .

docker run -d --name devbox --user "$(id -u):$(id -g)" devbox-local
docker exec -it devbox bash
docker stop devbox
```

### Persist all caches

```bash
docker run -d --name devbox --user "$(id -u):$(id -g)" -v devbox-data:/data devbox-local
```

### Bind individual caches to your host

```bash
docker run -d --name devbox --user "$(id -u):$(id -g)" \
  -v ~/.bun/install/cache:/data/bun \
  -v ~/.cache/uv:/data/uv \
  devbox-local
```

### Mount your project

```bash
docker run -d --name devbox --user "$(id -u):$(id -g)" -v $(pwd):/workspace devbox-local
docker exec -it -w /workspace devbox bash
```

### Cache locations

| Container path | Tool | Host default             |
|----------------|------|--------------------------|
| /data/bun      | bun  | ~/.bun/install/cache     |
| /data/uv       | uv   | ~/.cache/uv              |
| /data/npm      | npm  | ~/.npm                   |
| /data/pip      | pip  | ~/.cache/pip             |

## Install

```bash
docker build -f docker/local/Dockerfile -t devbox-local .
```

Requires Docker (Docker Desktop, Colima, OrbStack, or dockerd).

## Development

The local Dockerfile runs the same install scripts as all other devbox
variants. Tooling logic lives in `scripts/debian/`, not the Dockerfile.
Adding a tool means editing a script, not the Dockerfile.

Iterate:

```bash
docker build -f docker/local/Dockerfile -t devbox-local . && \
docker run -d --name devbox --user "$(id -u):$(id -g)" devbox-local && \
docker exec -it devbox bash
```

Test:

```bash
./test/run.sh debian:bookworm-slim
```

## GitHub identity (optional)

The local container acts as you — it reuses your existing SSH identity, your
age key, and your git identity. Mount your `~/.ssh` directory read-only into
`/home/devbox/.ssh`. This gives the box your signing keypair and your
`allowed_signers` file (so `git log` verifies signatures locally without
the confusing "allowedSignersFile needs to be configured" error).

Mount targets use `/home/devbox/` (the container HOME):

```bash
docker run -d --name devbox --user "$(id -u):$(id -g)" \
  -v ~/.ssh:/home/devbox/.ssh:ro \
  -v ~/.config/sops/age:/home/devbox/.config/sops/age:ro \
  -e GIT_USER_NAME="Dane Stuckel" \
  -e GIT_USER_EMAIL="dane.stuckel@gmail.com" \
  devbox-local
```

SOPS finds the age key via its default path or the `SOPS_AGE_KEY` env var.

The entrypoint detects the signing public key, configures SSH signing, and
points git at the `allowed_signers` file — all automatically. In any repo
with a `.env.enc`, `./scripts/github-login.sh` authenticates `gh` using the
decrypted, repo-scoped `GITHUB_TOKEN`.
