# devbox local — local container for direct-access compute.
#
# Used by: local development, CI runners, any scenario where the container
# is accessed directly (docker exec, attached TTY) rather than over SSH.
#
# No sshd, no network hardening. The consumer has direct shell access.

FROM debian:bookworm-slim AS base

LABEL org.opencontainers.image.title="devbox-local"
LABEL org.opencontainers.image.description="Local dev container with full toolchain — no sshd, direct access"
LABEL org.opencontainers.image.source="https://github.com/softwarepatterns/devbox"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Software Patterns LLC"

# tini: proper PID 1 init process. Handles SIGTERM forwarding and zombie
# reaping. Without it, tail/bash as PID 1 ignore docker stop on some kernels.
RUN apt-get update -qq && apt-get install -y -qq tini && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/tini", "--"]

# --- Install all devbox tooling -----------------------------------------------
COPY scripts/debian/ /tmp/devbox-scripts/
RUN bash /tmp/devbox-scripts/00-base.sh \
    && bash /tmp/devbox-scripts/10-ts.sh \
    && bash /tmp/devbox-scripts/20-python.sh \
    && bash /tmp/devbox-scripts/30-secrets.sh \
    && bash /tmp/devbox-scripts/40-cicd.sh \
    && rm -rf /tmp/devbox-scripts

# CMD process: tail -f /dev/null is more signal-responsive than sleep
# infinity on some kernels (notably Colima's QEMU VM). The container stays
# alive but cleanly stops on SIGTERM. Get a shell via: docker exec -it <name> bash
CMD ["tail", "-f", "/dev/null"]
