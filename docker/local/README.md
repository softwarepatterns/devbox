# devbox-local

A Docker container with a full development toolchain. Start it, exec in, work.

## Features

Pre-installed: git, bun, node, uv, sops, age, gh, flyctl, ripgrep, jq, vim,
tmux, htop, python3, ssh, build-essential.

All tool caches are under `/data` for simple persistence. Clean lifecycle
with tini as PID 1 — `docker stop` works instantly.

## Usage

### Run with a shell

```bash
docker build -f docker/local/Dockerfile -t devbox-local .

docker run -d --name devbox devbox-local
docker exec -it devbox bash
docker stop devbox
```

### Persist all caches

```bash
docker run -d --name devbox -v devbox-data:/data devbox-local
```

### Bind individual caches to your host

```bash
docker run -d --name devbox \
  -v ~/.bun/install/cache:/data/bun \
  -v ~/.cache/uv:/data/uv \
  devbox-local
```

### Mount your project

```bash
docker run -d --name devbox -v $(pwd):/workspace devbox-local
docker exec -w /workspace -it devbox bash
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
docker run -d --name devbox devbox-local && \
docker exec -it devbox bash
```

Test:

```bash
./test/run.sh debian:bookworm-slim
```

## GitHub identity (optional)

The local container acts as you — it reuses your existing SSH identity, your
age key, and your git identity. The simplest way to do this is to mount your
entire `~/.ssh` directory read-only into the container. This gives the box
your signing keypair, your `allowed_signers` file (so `git log` verifies
signatures locally without the confusing "allowedSignersFile needs to be
configured" error), and any other SSH identity you have. Since the box is
acting as you, that's appropriate.

The alternative — mounting only `id_ed25519` and `id_ed25519.pub` — leaves the
box without an `allowed_signers` file, which the entrypoint then has to
generate. Mounting the whole directory sidesteps that entirely: your existing,
maintained `allowed_signers` is already correct.

```bash
docker run -d --name devbox \
  -v ~/.ssh:/root/.ssh:ro \
  -v ~/.config/sops/age:/root/.config/sops/age:ro \
  -e GIT_USER_NAME="Dane Stuckel" \
  -e GIT_USER_EMAIL="dane.stuckel@gmail.com" \
  devbox-local
```

SOPS finds the age key via its default path or the `SOPS_AGE_KEY` env var.
Mounting the directory covers the default path; `SOPS_AGE_KEY` is the
equivalent for environments without a mount.

The entrypoint detects the signing public key, configures SSH signing, and
points git at the `allowed_signers` file — all automatically. In any repo
with a `.env.enc`, `./scripts/github-login.sh` authenticates `gh` using the
decrypted, repo-scoped `GITHUB_TOKEN`.
