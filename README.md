# devbox

Turn any Linux machine into a fully-equipped development and compute
environment. Idempotent, OS-specific install scripts that provision
toolchains, CLIs, and runtimes. Consumed by Docker images, Ansible
playbooks, or run directly on bare metal.

## Design

**Scripts are the source of truth.** Every consumer (Docker, Ansible,
Terraform) calls the same scripts. The scripts don't know about consumers.

**OS-specific, not conditional.** Each OS has its own script directory.
No runtime OS detection inside scripts — the consumer picks the right
script for the target OS. This keeps each script simple and testable.

**Pinned versions with checksums.** Every downloaded binary has a
pinned version and SHA256 checksum. Reproducible across machines and time.

**No agent framework.** devbox installs tools, not AI agents. The
machine is a compute target — whatever drives it (Hermes, Claude Code,
a human, a CI runner) connects separately.

## Structure

```
devbox/
├── scripts/
│   ├── debian/              Debian/Ubuntu (apt-based)
│   │   ├── 00-base.sh       git, curl, jq, ripgrep, vim, build-essential, etc.
│   │   ├── 10-ts.sh         bun, prettier, oxlint
│   │   ├── 20-python.sh     uv, python3
│   │   ├── 30-secrets.sh    sops, age
│   │   └── 40-cicd.sh       gh, flyctl
│   └── darwin/              macOS (homebrew-based) — future
│       └── ...
├── docker/
│   ├── remote/              SSH-accessible compute target (Fly.io, cloud VMs)
│   │   ├── Dockerfile
│   │   └── entrypoint.sh
│   └── local/               Local container (no sshd, direct access)
│       └── Dockerfile
├── test/
│   ├── run.sh               Builds Docker images per OS, verifies tools
│   └── verify.sh            Asserts every expected tool exists and works
├── .github/
│   └── workflows/
│       └── ci.yml           GitHub Actions: shellcheck + Docker matrix tests
├── .gitignore
├── LICENSE
└── README.md
```

## Usage

### Docker (remote SSH variant)

```bash
cd docker/remote
docker build -t devbox-remote .
# Run with SSH key injected at runtime
```

### Direct (bare metal or VM)

```bash
# On a fresh Debian/Ubuntu machine:
curl -fsSL https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian/00-base.sh | bash
curl -fsSL https://raw.githubusercontent.com/softwarepatterns/devbox/main/scripts/debian/10-ts.sh | bash
# ... or run specific scripts as needed
```

## Testing

```bash
./test/run.sh
```

Builds Docker images for each target OS, runs the install scripts,
then verifies every tool is installed and working.

## License

MIT
