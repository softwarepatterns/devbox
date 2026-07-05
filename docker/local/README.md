# devbox-local

A Docker container with a full development toolchain. Start it, exec in, work.

## Features

Pre-installed: git, bun, uv, sops, age, gh, flyctl, ripgrep, jq, vim, tmux,
htop, python3, ssh, build-essential.

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
