# devbox (Docker)

A sealed compute container with a full development toolchain, for agents.

## Design

The container owns its state under `/data` (named volume):
- `/data/.ssh` — the box's own SSH keypair and allowed_signers (generated on
  first boot, persists across restarts)
- `/data/repos` — container-native repository clones
- `/data/{bun,uv,npm,pip}` — tool caches

Host directories can be bind-mounted at `/workspace` for file sharing, but
devbox makes no assumptions about their contents. Everything the container
needs to function lives under `/data`.

The container generates its own SSH identity on first boot. Register the
public key with GitHub (Settings → SSH and GPG keys → Signing keys) to
enable signed commits. The key persists with the named volume.

## Usage

One image. Start it with `docker exec` access (local) or `sshd` access
(remote via `DEVBOX_SSH=true`):

**docker exec (local):**
```bash
docker build -f docker/Dockerfile -t devbox .

docker run -d --name devbox \
  --user "$(id -u):$(id -g)" \
  -v devbox-data:/data \
  devbox

docker exec -it devbox bash
```

**sshd (remote):**
```bash
docker run -d --name devbox \
  -e DEVBOX_SSH=true \
  -e SSH_AUTHORIZED_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -v devbox-data:/data \
  devbox

ssh -p 2222 root@localhost
```

## Deploy on Fly.io

A reference `fly.toml` is included at `docker/fly.toml`. Copy it, rename the
app, and deploy with `DEVBOX_SSH=true`:

```bash
flyctl deploy . --dockerfile docker/Dockerfile
fly secrets set DEVBOX_SSH=true SSH_AUTHORIZED_KEY="$(cat ~/.ssh/id_ed25519.pub)"
fly ssh console
```

On Fly, `/data` is a mounted volume — caches and identity persist across
restarts.

## Cache locations

| Container path | Tool | Host default             |
|----------------|------|--------------------------|
| /data/bun      | bun  | ~/.bun/install/cache     |
| /data/uv       | uv   | ~/.cache/uv              |
| /data/npm      | npm  | ~/.npm                   |
| /data/pip      | pip  | ~/.cache/pip             |

## Cloning repos

Repos should be cloned into `/data/repos` — the container-native working
tree. Dependencies installed there match the container's platform.

```bash
docker exec -it devbox bash
cd /data/repos
git clone git@github.com:yourorg/yourrepo.git
```

## GitHub identity

The container's SSH keypair is generated on first boot and stored under
`/data/.ssh`. To enable signed commits:

1. Check the first-boot logs for the public key (or `cat /data/.ssh/id_ed25519.pub`)
2. Add it to GitHub under Settings → SSH and GPG keys → Signing keys
3. Commits are automatically signed via SSH (`commit.gpgsign=true`)

Alternatively, provide a pre-generated key via `GIT_SIGNING_KEY`:

```bash
docker run -d --name devbox \
  --user "$(id -u):$(id -g)" \
  -v devbox-data:/data \
  -e GIT_USER_NAME="Dane Stuckel" \
  -e GIT_USER_EMAIL="dane.stuckel@gmail.com" \
  -e GIT_SIGNING_KEY="$(cat ~/.ssh/devbox-signing-key)" \
  devbox
```

In any repo with a `.env.enc`, `./scripts/github-login.sh` authenticates `gh`
using the decrypted, repo-scoped `GITHUB_TOKEN`.

## Development

The Dockerfile runs the install scripts from `scripts/debian/`. Adding a tool
means editing a script, not the Dockerfile.

Test:

```bash
./test/run.sh debian:bookworm-slim
```
