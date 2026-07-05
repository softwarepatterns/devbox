#!/usr/bin/env bash
# devbox test/verify.sh
# Asserts every expected tool is installed and responds to --version.
# Sourced by test/run.sh after scripts run inside a test container.
# Exit non-zero if any tool is missing or fails.
set -euo pipefail

PASS=0
FAIL=0

check() {
  local tool="$1"
  local version_cmd="${2:---version}"
  if command -v "$tool" >/dev/null 2>&1; then
    local ver
    ver="$("$tool" "$version_cmd" 2>&1 | head -1)"
    echo "  ✓ $tool: $ver"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $tool: NOT FOUND"
    FAIL=$((FAIL + 1))
  fi
}

echo "Verifying installed tools..."

# Base packages
check git
check curl
check jq
check rg
check vim
check python3
check ssh
check file
check tmux
check htop

# TS toolchain
check bun
check node
check npm

# Python toolchain
check uv

# Secrets
check sops
check age

# CI/CD
check gh
check flyctl

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
