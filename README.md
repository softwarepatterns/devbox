# devbox

Turn any machine into a fully-equipped development environment for agents.
Idempotent, OS-specific install scripts that provision a full toolchain —
consumed by Docker images or run directly on bare metal, VMs, or CI.

## Features

Pre-installed: git, bun, node, npm, uv, python3, sops, age, gh, flyctl,
ripgrep, jq, vim, tmux, htop, build-essential, ssh.

**Scripts are the product.** The install scripts are standalone. They work
on bare metal, in Docker, or in CI. Docker images are thin wrappers that
call the scripts. Change a tool once; every consumer benefits.

**OS-specific, not conditional.** Each OS has its own script directory with
native package manager calls. No fragile runtime OS detection. The consumer
picks the right OS; the script does the rest.

**Idempotent.** Every script checks whether a tool is already installed
before installing it. Run once on a fresh machine or twenty times on an
existing one — the result is the same.

**Sealed containers.** The container owns its state under `/data` (named
volume): caches, repos, and its own generated SSH identity. Host mounts are
allowed but unsupported — the container is a self-contained Linux box, not a
mirror of the host.

## Usage

### Docker

One image, started via `docker exec` (local) or `sshd` (remote). See
[docker/README.md](docker/README.md) for the full guide.

```bash
docker build -f docker/Dockerfile -t devbox .

# local (docker exec)
docker run -d --name devbox --user "$(id -u):$(id -g)" -v devbox-data:/data devbox

# remote (sshd)
docker run -d --name devbox -e DEVBOX_SSH=true -v devbox-data:/data devbox
```

### Bare metal or VM (Debian/Ubuntu)

Run the scripts you need, in numeric order. Each is independent and idempotent:

```bash
base=https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian
curl -fsSL "$base/00-base.sh" | sudo bash
curl -fsSL "$base/40-cicd.sh" | sudo bash   # ...etc
```

### What gets installed

| Script          | Tools                                                      |
|-----------------|------------------------------------------------------------|
| `00-base.sh`    | git, curl, jq, ripgrep, vim, python3, build-essential, tmux, htop, ssh |
| `10-ts.sh`      | bun, node (LTS), npm                                       |
| `20-python.sh`  | uv                                                         |
| `30-secrets.sh` | sops, age                                                  |
| `40-cicd.sh`    | gh (GitHub CLI), flyctl                                    |

## Development

### Add a tool

Edit the appropriate script in `scripts/debian/`, add it to `test/verify.sh`,
then run the suite:

```bash
./test/run.sh                          # full matrix
./test/run.sh debian:bookworm-slim     # one target
```

### Add a new OS

Create `scripts/<os>/` ported to the native package manager. Keep the numeric
ordering. Add the OS to `test/run.sh`.

### Structure

```
devbox/
├── scripts/debian/   install scripts (the product)
├── docker/
│   ├── Dockerfile    sealed container (local + remote modes)
│   ├── entrypoint.sh init, git config, signing, optional sshd
│   ├── fly.toml      reference Fly.io deployment
│   └── README.md     Docker usage guide
├── test/             run.sh + verify.sh
├── .sops.yaml        SOPS age recipients
└── .env.enc          SOPS-encrypted secrets (committed)
```

### Conventions

- **Numbering:** `00-base.sh` → `90-*.sh`, lowest runs first.
- **No OS detection:** scripts are OS-specific by directory.
- **`/data`:** sealed container territory (named volume). Caches, repos, SSH
  identity. Host mounts to `/data` are the user's responsibility.
- **`/data/repos`:** convention for container-native repository clones.

### Secrets

SOPS-encrypted with age and committed as `.env.enc`. The repo is public; the
secrets are not. CI decrypts via `SOPS_AGE_KEY`.

### CI

GitHub Actions runs ShellCheck and per-OS contract tests on every push and
PR, using the same `test/run.sh` / `test/verify.sh` you run locally.

## License

MIT — see [LICENSE](LICENSE).
