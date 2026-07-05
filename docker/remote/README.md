# devbox-remote

An SSH-accessible compute target with a full development toolchain. Start it,
SSH in, work. For Fly.io machines, cloud VMs, or rented servers.

## Features

Pre-installed: git, bun, node, npm, uv, sops, age, gh, flyctl, ripgrep, jq,
vim, tmux, htop, python3, ssh, build-essential.

sshd on port 2222 with key-only auth. `authorized_keys` injected at runtime
via the `SSH_AUTHORIZED_KEY` env var. Clean lifecycle with tini as PID 1.

All tool caches are under `/data` for simple persistence.

## Usage

### Build

```bash
docker build -f docker/remote/Dockerfile -t devbox-remote .
```

Requires Docker (Docker Desktop, Colima, OrbStack, or dockerd).

### Run locally (for testing)

```bash
docker run -d --name devbox-remote \
  -p 2222:2222 \
  -e SSH_AUTHORIZED_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  devbox-remote

ssh -p 2222 root@localhost
```

### Run on Fly.io

```bash
fly deploy          # uses fly.toml in your project
fly ssh console     # SSH in via Fly's proxy
```

On Fly, `/data` is a mounted volume — caches persist across restarts.

### Cache locations

| Container path | Tool | Host default             |
|----------------|------|--------------------------|
| /data/bun      | bun  | ~/.bun/install/cache     |
| /data/uv       | uv   | ~/.cache/uv              |
| /data/npm      | npm  | ~/.npm                   |
| /data/pip      | pip  | ~/.cache/pip             |

## Development

The remote Dockerfile runs the same install scripts as all other devbox
variants. Tooling logic lives in `scripts/debian/`, not the Dockerfile.
Adding a tool means editing a script, not the Dockerfile.

Test:

```bash
./test/run.sh debian:bookworm-slim
```

## GitHub identity (optional)

A remote box is a new named engineer — it gets its own keys, distinct from
any human developer. Unlike the local variant (which reuses your whole
`~/.ssh`), the remote box gets a narrow keypair injected via secrets. The
asymmetry is deliberate: local acts as you and inherits your identity
wholesale; remote is its own identity and should only have its own keys.

### 1. Generate the keys

```bash
# SOPS/age keypair (for decrypting .env.enc)
age-keygen -o devbox-age-key.txt
# Public key printed to stdout — add it to each repo's .sops.yaml

# SSH signing keypair (one key for both git auth and commit signing)
ssh-keygen -t ed25519 -f devbox-signing-key -N "" -C "devbox@fly"
# Public key in devbox-signing-key.pub
```

### 2. Register with each repo

For every repo this box should access:

- Add the age public key to `.sops.yaml`, then re-encrypt:
  `sops updatekeys .env.enc` (picks up new recipients from `.sops.yaml`).
- Upload the SSH public key to the relevant GitHub account under
  **Settings → SSH and GPG keys**, in both the *Authentication* and *Signing*
  sections (same key, both categories — it authenticates pushes and signs
  commits).

### 3. Inject as Fly secrets

```bash
fly secrets set \
  SOPS_AGE_KEY="$(cat devbox-age-key.txt)" \
  GIT_SIGNING_KEY="$(cat devbox-signing-key)" \
  GIT_USER_NAME="devbox-lax" \
  GIT_USER_EMAIL="devbox@softwarepatterns.com"
```

One identity (`GIT_USER_NAME` + `GIT_USER_EMAIL`) sets both author and
committer. Fly can only inject secrets as env vars, so the signing key
content arrives via `GIT_SIGNING_KEY` — the entrypoint writes it to
`/root/.ssh/id_ed25519`, derives the public key, and enables SSH signing
with local verification.

Then in any repo with a `.env.enc`: `./scripts/github-login.sh`
authenticates `gh` using the decrypted, repo-scoped `GITHUB_TOKEN`. The
same SSH key handles both `git push` (GitHub auth) and commit signing.
