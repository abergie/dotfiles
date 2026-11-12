#!/usr/bin/env bash
set -euo pipefail

AGENT_DIR="${PI_CODING_AGENT_DIR:-/tmp/pi-agent}"
SEED_DIR="/opt/pi-seed"

mkdir -p "$AGENT_DIR/extensions"

for f in AGENTS.md settings.json; do
  if [ -f "$SEED_DIR/$f" ] && [ ! -e "$AGENT_DIR/$f" ]; then
    cp "$SEED_DIR/$f" "$AGENT_DIR/$f"
  fi
done

if [ ! -e "$AGENT_DIR/mcp.json" ] && [ -n "${LITELLM_BASE_URL:-}" ]; then
  node -e '
    const fs = require("node:fs");
    let base = process.argv[1].trim();
    if (base && !/^https?:\/\//i.test(base)) base = "https://" + base;
    base = base.replace(/\/+$/, "").replace(/\/v1$/i, "");
    const cfg = {
      mcpServers: {
        litellm: {
          url: base + "/mcp",
          headers: {
            Authorization: "Bearer ${LITELLM_API_KEY}",
          },
        },
      },
    };
    fs.writeFileSync(process.argv[2], JSON.stringify(cfg, null, 2) + "\n");
  ' "$LITELLM_BASE_URL" "$AGENT_DIR/mcp.json"
fi

if [ -d "$SEED_DIR/extensions" ]; then
  for ext in "$SEED_DIR"/extensions/*; do
    [ -e "$ext" ] || continue
    ext_name="$(basename "$ext")"
    if [ ! -e "$AGENT_DIR/extensions/$ext_name" ]; then
      cp -R "$ext" "$AGENT_DIR/extensions/$ext_name"
    fi
  done
fi

if [ -d "$SEED_DIR/npm" ] && [ ! -e "$AGENT_DIR/npm" ]; then
  ln -s "$SEED_DIR/npm" "$AGENT_DIR/npm"
fi

if [ "${1:-}" = "--workdir" ]; then
  if [ "$#" -lt 2 ]; then
    echo "pi-sandbox-init: --workdir requires a directory argument" >&2
    exit 2
  fi
  TARGET_WORKDIR="$2"
  shift 2
  cd "$TARGET_WORKDIR"
fi

if [ "$#" -eq 0 ]; then
  exec pi
fi

exec "$@"
