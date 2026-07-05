# devbox-local

A ready-to-run Docker container with a full development toolchain. No sshd,
no network hardening — just tools and a shell. Start it, exec in, and work.

Built on the same scripts as devbox-remote. Same tools, same versions, same
checksums. The difference is access: local gives you `docker exec`, remote
gives you SSH.

## Features

*For the developer who wants a working environment in 30 seconds.*

**Everything pre-installed.** git, bun, uv, sops, age, gh, flyctl, ripgrep,
jq, vim, tmux, htop, python3, build-essential, openssh-client. No apt-get
marathons, no version conflicts, no "works on my machine."

**Clean lifecycle.** tini as PID 1 means `docker stop` works instantly.
No hard-locks, no 10-second timeouts, no orphaned zombies.

**Reproducible.** The image is built from pinned, checksum-verified scripts.
Build it today or in six months — same toolchain.

**Lightweight.** ~200MB. debian:bookworm-slim base, only what's needed.

## Usage

*For the developer running the container on their machine.*

### Quick start

```bash
# From the devbox repo root:
docker build -f docker/local/Dockerfile -t devbox-local .

# Run in the background
docker run -d --name devbox devbox-local

# Get a shell
docker exec -it devbox bash

# Stop when done (instant — tini handles SIGTERM)
docker stop devbox
docker rm devbox
```

### Mount your project

```bash
docker run -d --name devbox -v $(pwd):/workspace devbox-local
docker exec -it devbox bash
# Inside: cd /workspace && bun install && bun run test
```

### Persist caches between restarts

```bash
docker run -d --name devbox \
  -v $(pwd):/workspace \
  -v devbox-bun-cache:/root/.bun/cache \
  -v devbox-uv-cache:/root/.cache/uv \
  devbox-local
```

### Use as a base image

```dockerfile
FROM ghcr.io/softwarepatterns/devbox:local
# Your project-specific tools on top of the devbox toolchain
RUN bun install -g prettier oxlint
```

## Install

*For the operator setting up the devbox project locally.*

### Prerequisites

- Docker (Docker Desktop, Colima, OrbStack, or raw dockerd)

### Build

```bash
# From the devbox repo root:
docker build -f docker/local/Dockerfile -t devbox-local .
```

### What's inside

| Tool        | Purpose                          |
|-------------|----------------------------------|
| git         | Version control                  |
| bun         | JavaScript/TypeScript runtime    |
| uv          | Python package manager           |
| sops + age  | Secrets encryption               |
| gh          | GitHub CLI                       |
| flyctl      | Fly.io CLI                       |
| ripgrep     | Fast file search                 |
| jq          | JSON processing                  |
| vim         | Text editor                      |
| tmux        | Terminal multiplexer             |
| htop        | Process monitoring               |
| python3     | Python 3 runtime                 |
| ssh         | SSH client                       |
| build-essential | C/C++ compiler toolchain     |

## Development

*For the contributor modifying the local image.*

### Iterating on the Dockerfile

```bash
# Build and run in one step
docker build -f docker/local/Dockerfile -t devbox-local . && \
docker run -d --name devbox devbox-local && \
docker exec -it devbox bash
```

### Testing changes

The local image uses the same scripts as the remote variant. Verify your
changes against the test suite from the repo root:

```bash
./test/run.sh debian:bookworm-slim
```

This builds a throwaway image, runs all install scripts, and asserts every
tool exists and responds to `--version`.

### Architecture

The local Dockerfile is intentionally thin:

1. `FROM debian:bookworm-slim`
2. Install tini (PID 1 init)
3. Run the install scripts (shared with all other variants)
4. `CMD ["tail", "-f", "/dev/null"]` (keep-alive that responds to signals)

All tooling logic lives in `scripts/debian/`, not in the Dockerfile. Adding
a tool means editing a script, not the Dockerfile.

### Adding tools

See the repo-root [Development](../../README.md#development) section for
conventions on adding tools and OS support.
