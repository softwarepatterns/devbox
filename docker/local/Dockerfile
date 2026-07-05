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

# --- Install all devbox tooling -----------------------------------------------
COPY scripts/debian/ /tmp/devbox-scripts/
RUN bash /tmp/devbox-scripts/00-base.sh \
    && bash /tmp/devbox-scripts/10-ts.sh \
    && bash /tmp/devbox-scripts/20-python.sh \
    && bash /tmp/devbox-scripts/30-secrets.sh \
    && bash /tmp/devbox-scripts/40-cicd.sh \
    && rm -rf /tmp/devbox-scripts

# Keep the container running with a sleep so it can be exec'd into.
CMD ["sleep", "infinity"]
