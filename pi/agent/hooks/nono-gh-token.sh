#!/bin/bash
# Runs OUTSIDE the nono sandbox with host privileges before the child starts.
# Captures the current gh CLI token and exports it into the sandboxed child's
# environment via NONO_ENV_FILE, so gh/git operations inside the sandbox work
# over HTTPS without needing raw port-22 SSH egress (which nono's proxy model
# cannot support) and without needing a TLS-intercepted credential route
# (which gh's cert-pinned HTTP client rejects).
set -euo pipefail

if command -v gh >/dev/null 2>&1; then
  TOKEN="$(gh auth token 2>/dev/null || true)"
  if [ -n "${TOKEN:-}" ] && [ -n "${NONO_ENV_FILE:-}" ]; then
    echo "GH_TOKEN=${TOKEN}" >> "$NONO_ENV_FILE"
  fi
fi
