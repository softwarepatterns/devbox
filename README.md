# devbox

Turn any machine into a fully-equipped development environment. Idempotent,
OS-specific install scripts that provision a full toolchain — consumed by
Docker images or run directly on bare metal, VMs, or CI.

## Features

Pre-installed: git, bun, node, uv, python3, sops, age, gh, flyctl, ripgrep,
jq, vim, tmux, htop, build-essential, ssh.

**Scripts are the product.** The install scripts are standalone. They work
on bare metal, in Docker, or in CI. Docker images are thin wrappers that
call the scripts. Change a tool once; every consumer benefits.

**OS-specific, not conditional.** Each OS has its own script directory with
native package manager calls. No fragile runtime OS detection. The consumer
picks the right OS; the script does the rest.

**Idempotent.** Every script checks whether a tool is already installed
before installing it. Run once on a fresh machine or twenty times on an
existing one — the result is the same.

**No agent frameworks.** devbox installs tools only. The machine is a
compute target, not an agent runtime.

## Usage

### Docker

Two variants, both built from the same scripts:

- **local** — direct-access container, no sshd. `docker exec` in.
  See [docker/local/README.md](docker/local/README.md).
- **remote** — SSH-accessible compute target with sshd on :2222, key-only
  auth. For Fly.io machines, cloud VMs, or rented servers.
  See [docker/remote/README.md](docker/remote/README.md).

```bash
docker build -f docker/local/Dockerfile -t devbox-local .
docker build -f docker/remote/Dockerfile -t devbox-remote .
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
| `10-ts.sh`      | bun, node (LTS)                                            |
| `20-python.sh`  | uv                                                         |
| `30-secrets.sh` | sops, age                                                  |
| `40-cicd.sh`    | gh (GitHub CLI), flyctl                                    |

## Development

### Add a tool

Edit the appropriate script in `scripts/debian/` (e.g. add a package to
`00-base.sh` or create a new `50-rust.sh`), add it to `test/verify.sh`,
then run the suite:

```bash
./test/run.sh                          # full matrix
./test/run.sh debian:bookworm-slim     # one target
```

### Add a new OS

Create `scripts/<os>/` ported to the native package manager (brew for macOS,
pacman for Arch). Keep the numeric ordering. Add the OS to `test/run.sh`.

### Structure

```
devbox/
├── scripts/debian/   install scripts (the product)
├── docker/
│   ├── local/        no sshd, direct access
│   └── remote/       sshd on :2222, key auth
├── test/             run.sh + verify.sh
├── .sops.yaml        SOPS age recipients
└── .env.enc          SOPS-encrypted secrets (committed)
```

### Conventions

- **Numbering:** `00-base.sh` → `90-*.sh`, lowest runs first.
- **Root required:** run via sudo or as root in Docker.
- **No OS detection:** scripts are OS-specific by directory.

### Secrets

SOPS-encrypted with age and committed as `.env.enc`. The repo is public; the
secrets are not. CI decrypts via `SOPS_AGE_KEY`.

### GitHub identity (optional)

A devbox that pushes to GitHub as an agent needs two things the image does not
ship: a way to decrypt each repo's `.env.enc` (which holds a repo-scoped
`GITHUB_TOKEN`), and a key to sign commits. Both are per-box secrets, generated
once, injected at runtime. The box is treated as a named engineer — its own
identity, attributable commits, revocable access.

This is additive and never required to start: build the image and you have a
working toolchain with no secrets, no signing, no GitHub involvement. Climb the
ladder only when your use case demands it:

- nothing — local exec, no GitHub.
- SOPS/age — the box can decrypt a repo's `GITHUB_TOKEN` and authenticate via
  `scripts/github-login.sh`.
- + SSH signing — the box's commits are signed and show Verified on GitHub.

devbox provides the tooling (sops, age, git with SSH signing, openssh); the
deployer provides the keys. The local and remote variants take different paths
to the same end, by design — see the individual READMEs.

### CI

GitHub Actions runs ShellCheck and per-OS contract tests on every push and
PR, using the same `test/run.sh` / `test/verify.sh` you run locally.

## License

MIT — see [LICENSE](LICENSE).
