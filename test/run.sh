#!/usr/bin/env bash
# devbox test/run.sh
# Builds Docker images for each target OS, runs the install scripts,
# then verifies every tool is installed and working.
#
# Usage:
#   ./test/run.sh                    # test all OS targets
#   ./test/run.sh debian:bookworm    # test a specific target
#
# Requires: Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Target OS images to test against. Each must be apt-based (debian/ubuntu).
TARGETS=(
  "debian:bookworm-slim"
  "debian:trixie-slim"
  "ubuntu:24.04"
)

if [ -n "${1:-}" ]; then
  TARGETS=("$1")
fi

echo "=== devbox test suite ==="
echo "Targets: ${TARGETS[*]}"
echo ""

FAILED_TARGETS=()

for target in "${TARGETS[@]}"; do
  echo "--- Testing: $target ---"

  # Build a test image: FROM <target>, copy scripts, run them, copy verify script.
  # The verify.sh runs at build time (RUN) so a failure stops the build.
  docker build -t "devbox-test:${target//[:\/]/-}" -f - "$PROJECT_ROOT" <<EOF
FROM $target
COPY scripts/debian/ /tmp/devbox-scripts/
RUN bash /tmp/devbox-scripts/00-base.sh \
    && bash /tmp/devbox-scripts/10-ts.sh \
    && bash /tmp/devbox-scripts/20-python.sh \
    && bash /tmp/devbox-scripts/30-secrets.sh \
    && bash /tmp/devbox-scripts/40-cicd.sh \
    && rm -rf /tmp/devbox-scripts
COPY test/verify.sh /tmp/verify.sh
RUN chmod +x /tmp/verify.sh && bash /tmp/verify.sh
EOF

  if [ $? -eq 0 ]; then
    echo "✓ $target: PASS"
  else
    echo "✗ $target: FAIL"
    FAILED_TARGETS+=("$target")
  fi
  echo ""
done

echo "=== Summary ==="
if [ ${#FAILED_TARGETS[@]} -eq 0 ]; then
  echo "All targets passed."
  exit 0
else
  echo "Failed targets: ${FAILED_TARGETS[*]}"
  exit 1
fi
