# devbox

Turn any machine into a fully-equipped development and compute environment.
Idempotent, OS-specific install scripts that provision toolchains, CLIs, and
runtimes. Consumed by Docker images, Ansible playbooks, or run directly.

## Features

*For the engineer deciding whether to adopt devbox.*

**One command, every tool.** No more maintaining per-project Dockerfiles
with 40 apt-get lines. devbox installs the full stack — git, bun, Python,
sops, gh, flyctl, ripgrep, and more — from a single set of version-pinned,
checksum-verified scripts.

**Scripts are the product.** The install scripts are standalone. They work
on bare metal, in Docker, in CI, or over SSH. Docker images, Ansible
playbooks, and Terraform modules are thin wrappers that call the scripts.
Change a tool version once; every consumer benefits.

**OS-specific, not conditional.** Each OS has its own script directory with
native package manager calls. No fragile runtime OS detection inside
scripts. The consumer picks the right OS; the script does the rest.

**Idempotent and safe.** Every script checks whether a tool is already
installed before installing it. Run them once on a fresh machine or twenty
times on an existing one — the result is the same.

**Reproducible builds.** Every binary download is pinned to a version and
verified against a SHA256 checksum. Two machines provisioned six months
apart get the same toolchain.

**Secrets-safe public repo.** SOPS-encrypted `.env.enc` committed to the
repo. CI decrypts at runtime with an age key stored in GitHub Actions
secrets. The repo is fully public; the secrets are not.

**Two Docker variants:**
- **Remote** — SSH-accessible compute target with sshd, key-only auth, and
  volume support. For Fly.io machines, cloud VMs, or rented servers.
- **Local** — direct-access container with no sshd. For local development,
  CI runners, or GPU compute boxes.

## Usage

*For the operator standing up a machine or writing a Dockerfile.*

### Docker: remote SSH variant

```dockerfile
# Fly.io machine, cloud VM, or rented server
FROM ghcr.io/softwarepatterns/devbox:remote
# sshd on :2222, authorized_keys from CONTROL_PLANE_PUBKEY env var
```

```bash
# Build locally
cd docker/remote
docker build -t devbox-remote .
```

### Docker: local variant

```dockerfile
# CI runner, local dev container, GPU box
FROM ghcr.io/softwarepatterns/devbox:local
# No sshd — access via docker exec or attached TTY
```

```bash
cd docker/local
docker build -t devbox-local .
```

### Bare metal or VM (Debian/Ubuntu)

```bash
# On a fresh machine, run the scripts you need:
curl -fsSL https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian/00-base.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian/10-ts.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian/20-python.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian/30-secrets.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian/40-cicd.sh | sudo bash
```

Each script is independent and idempotent. Install only what you need.

### What gets installed

| Script         | Tools                                                |
|----------------|------------------------------------------------------|
| `00-base.sh`   | git, curl, jq, ripgrep, vim, python3, build-essential, tmux, htop, ssh |
| `10-ts.sh`     | bun                                                  |
| `20-python.sh` | uv                                                   |
| `30-secrets.sh`| sops, age                                            |
| `40-cicd.sh`   | gh (GitHub CLI), flyctl                              |

## Install

*For the maintainer or contributor setting up the devbox project locally.*

### Prerequisites

- Docker (for building images and running the test suite)
- ShellCheck (for linting: `apt install shellcheck` or `brew install shellcheck`)

### Clone and test

```bash
git clone https://github.com/softwarepatterns/devbox.git
cd devbox

# Run the full test suite (builds per-OS Docker images, verifies tools)
./test/run.sh

# Test a specific OS target
./test/run.sh debian:bookworm-slim
```

### Secrets setup (for CI and builds)

devbox uses SOPS with age encryption to store secrets in the public repo:

1. Generate an age key pair:
   ```bash
   age-keygen -o key.txt
   # Public key: age1... (add to .sops.yaml)
   # Private key: stored in key.txt (keep secret)
   ```

2. Add the public key to `.sops.yaml`.

3. Create encrypted secrets:
   ```bash
   echo "MY_SECRET=value" > .env
   sops -e .env > .env.enc
   rm .env  # plaintext is gitignored
   ```

4. For CI: add the private key as a GitHub Actions secret named `SOPS_AGE_KEY`.

### Structure

```
devbox/
├── scripts/
│   ├── debian/              Debian/Ubuntu (apt-based)
│   │   ├── 00-base.sh
│   │   ├── 10-ts.sh
│   │   ├── 20-python.sh
│   │   ├── 30-secrets.sh
│   │   └── 40-cicd.sh
│   └── darwin/              macOS (future)
├── docker/
│   ├── remote/              SSH variant (sshd, key auth, volume support)
│   └── local/               Local variant (no sshd, direct access)
├── test/
│   ├── run.sh               Docker matrix test runner
│   └── verify.sh            Tool existence + version assertions
├── .sops.yaml               SOPS age recipients
├── .env.enc                 SOPS-encrypted secrets (committed)
└── .github/workflows/ci.yml ShellCheck + per-OS contract tests
```

## Development

*For the contributor adding a tool, a new OS, or fixing a bug.*

### Adding a tool to an existing OS

1. Edit the appropriate script in `scripts/debian/` (e.g., add a package
   to `00-base.sh` or create a new `50-rust.sh`).

2. Add the tool to `test/verify.sh` so the test suite checks for it.

3. Run the tests:
   ```bash
   ./test/run.sh
   ```

4. Commit and push. CI runs ShellCheck and the Docker matrix automatically.

### Adding a new OS

1. Create `scripts/<os>/` (e.g., `scripts/darwin/`).

2. Port the scripts using the OS-native package manager (brew for macOS,
   pacman for Arch, etc.). Keep the same numbering convention so consumers
   can reference them consistently.

3. Add the OS to the test matrix in `test/run.sh` and `.github/workflows/ci.yml`.

### Conventions

- **Script numbering:** `00-base.sh` through `90-*.sh`. Lower numbers run first.
  Consumers run scripts in numeric order.
- **Idempotency:** every script checks `command -v <tool>` before installing.
- **Checksums:** every downloaded binary has a pinned SHA256. No exceptions.
- **Root required:** all scripts assume root (run via sudo or as root in Docker).
- **No OS detection:** scripts are OS-specific by directory. The consumer
  chooses the right one.
- **No agent frameworks:** devbox installs tools only. The machine is a
  compute target, not an agent runtime.

### CI

GitHub Actions runs two jobs on every push and PR:

1. **ShellCheck** — lints every shell script at warning severity.
2. **Contract tests** — builds a Docker image per target OS, runs all scripts,
   and asserts every expected tool exists and responds to `--version`.

Both jobs use the same `test/run.sh` and `test/verify.sh` that you can run
locally, so CI failures are reproducible on your machine.

## License

MIT — see [LICENSE](LICENSE).
