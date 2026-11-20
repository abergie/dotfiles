#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
PI_OS="$DOTFILES_ROOT/bin/pi-os"
OP_READ="$DOTFILES_ROOT/pi/openshell/op-read.sh"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pi-os-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $msg" >&2
    echo "  expected to contain: $needle" >&2
    echo "  actual output: $haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "FAIL: $msg" >&2
    echo "  expected NOT to contain: $needle" >&2
    echo "  actual output: $haystack" >&2
    exit 1
  fi
}

# 1. Default environment (openshell-pi-dev) dry-run
PROJ_DIR="$TMP_ROOT/my-project"
mkdir -p "$PROJ_DIR"
REAL_PROJ_DIR="$(cd "$PROJ_DIR" && pwd -P)"

OUT1="$(cd "$PROJ_DIR" && env -u PI_OP_ENV -u PI_OP_ENVS -u PI_OPENSHELL_PROVIDER -u PI_OPENSHELL_PROVIDERS -u PI_OPENSHELL_GATEWAY -u PI_OPENSHELL_GATEWAY_ENDPOINT "$PI_OS" --dry-run -- --model qwen)"
assert_contains "$OUT1" "openshell sandbox create -g openshell" "standard dry-run targets local openshell gateway by default"
assert_contains "$OUT1" "--no-keep" "standard dry-run uses --no-keep by default"
assert_contains "$OUT1" "--no-auto-providers" "standard dry-run disables auto-providers"
assert_contains "$OUT1" "--from pi-openshell:local" "standard dry-run selects pi-openshell:local"
assert_contains "$OUT1" "--provider openshell-pi-dev" "default environment maps to --provider openshell-pi-dev"
assert_contains "$OUT1" "\"source\":\"$REAL_PROJ_DIR\"" "standard dry-run mounts physical project dir"
assert_contains "$OUT1" "\"target\":\"/sandbox/work\"" "standard dry-run mounts at /sandbox/work"
assert_contains "$OUT1" "\"target\":\"/sandbox/sessions\"" "standard dry-run mounts /sandbox/sessions for persistent jsonl logs"
assert_contains "$OUT1" "--env PI_CODING_AGENT_SESSION_DIR=/sandbox/sessions" "sets PI_CODING_AGENT_SESSION_DIR=/sandbox/sessions"
assert_contains "$OUT1" "/usr/local/bin/pi-sandbox-init --workdir /sandbox/work pi --model qwen" "standard dry-run passes workdir and pi args"

# 2. Switchable environment via --op-env / PI_OP_ENV
OUT_SWITCH="$(cd "$PROJ_DIR" && "$PI_OS" --op-env openshell-pi-staging --dry-run)"
assert_contains "$OUT_SWITCH" "--provider openshell-pi-staging" "--op-env switches attached provider"

# 3. Multi-environment stacking (-e env1 -e env2) and repeatable --provider
OUT_STACK="$(cd "$PROJ_DIR" && "$PI_OS" -e openshell-pi-dev -e github-tools --dry-run)"
assert_contains "$OUT_STACK" "--provider openshell-pi-dev --provider github-tools" "multiple -e flags attach stacked providers in order"

OUT_PROV_STACK="$(cd "$PROJ_DIR" && "$PI_OS" --provider custom-a --provider custom-b --dry-run)"
assert_contains "$OUT_PROV_STACK" "--provider custom-a --provider custom-b" "repeatable --provider flags stack providers"

# 4. Linked git worktree mounts common repo root and enters relative worktree subdir
REPO_DIR="$TMP_ROOT/git-repo"
mkdir -p "$REPO_DIR"
git -C "$REPO_DIR" init -q -b main
git -C "$REPO_DIR" config user.email "test@example.com"
git -C "$REPO_DIR" config user.name "Test"
git -C "$REPO_DIR" config commit.gpgsign false
echo "hello" > "$REPO_DIR/README.md"
git -C "$REPO_DIR" add README.md
git -C "$REPO_DIR" commit -qm "init"
git -C "$REPO_DIR" worktree add -q -b feat/demo .worktrees/feat/demo main
REAL_REPO_DIR="$(cd "$REPO_DIR" && pwd -P)"

OUT2="$(cd "$REPO_DIR/.worktrees/feat/demo" && "$PI_OS" --dry-run)"
assert_contains "$OUT2" "\"source\":\"$REAL_REPO_DIR\"" "linked worktree mounts common repo root"
assert_contains "$OUT2" "/usr/local/bin/pi-sandbox-init --workdir /sandbox/work/.worktrees/feat/demo pi" "linked worktree launches pi inside relative worktree path"

# 5. Symlinked directory resolves to physical target path
LINK_DIR="$TMP_ROOT/project-symlink"
ln -s "$PROJ_DIR" "$LINK_DIR"
OUT3="$(cd -P "$TMP_ROOT" && cd "$LINK_DIR" && "$PI_OS" --dry-run)"
assert_contains "$OUT3" "\"source\":\"$REAL_PROJ_DIR\"" "symlinked cwd canonicalizes to physical target"

# 6. Refuses mounting $HOME, /, or ~/.ssh
set +e
HOME_OUT="$(cd "$HOME" && "$PI_OS" --dry-run 2>&1)"
HOME_RC=$?
ROOT_OUT="$(cd / && "$PI_OS" --dry-run 2>&1)"
ROOT_RC=$?
set -e
[ "$HOME_RC" -ne 0 ] || { echo "FAIL: expected $PI_OS to refuse mounting $HOME" >&2; exit 1; }
[ "$ROOT_RC" -ne 0 ] || { echo "FAIL: expected $PI_OS to refuse mounting /" >&2; exit 1; }
assert_contains "$HOME_OUT" "refusing to mount" "home guard explains refusal"

FAKE_HOME="$TMP_ROOT/fake-home"
mkdir -p "$FAKE_HOME/.ssh"
set +e
SSH_OUT="$(cd "$FAKE_HOME/.ssh" && HOME="$FAKE_HOME" "$PI_OS" --dry-run 2>&1)"
SSH_RC=$?
set -e
[ "$SSH_RC" -ne 0 ] || { echo "FAIL: expected $PI_OS to refuse mounting ~/.ssh" >&2; exit 1; }

# 7. op-read.sh reads 1Password Environments by name (unconcealed config + reveal fallback)
SHIM_DIR="$TMP_ROOT/shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/op" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "environment" ] && [ "${2:-}" = "secret" ] && [ "${3:-}" = "list" ]; then
  ENV_NAME="${4:-}"
  REVEAL=0
  for a in "$@"; do
    [ "$a" = "--reveal" ] && REVEAL=1
  done
  if [ "$ENV_NAME" = "openshell-pi-dev" ]; then
    if [ "$REVEAL" -eq 1 ]; then
      printf '[{"name":"LITELLM_BASE_URL","value":"https://dev-llm.example.com","is_concealed":false},{"name":"LITELLM_API_KEY","value":"sk-dev-secret","is_concealed":true}]\n'
    else
      printf '[{"name":"LITELLM_BASE_URL","value":"https://dev-llm.example.com","is_concealed":false},{"name":"LITELLM_API_KEY","value":"","is_concealed":true}]\n'
    fi
    exit 0
  elif [ "$ENV_NAME" = "openshell-pi-alt" ]; then
    if [ "$REVEAL" -eq 1 ]; then
      printf '[{"name":"LITELLM_BASE_URL","value":"alt-llm.example.com/v1","is_concealed":false},{"name":"EXTRA_CFG","value":"enabled","is_concealed":false},{"name":"GH_TOKEN","value":"ghp_alt_org_token_456","is_concealed":true}]\n'
    else
      printf '[{"name":"LITELLM_BASE_URL","value":"alt-llm.example.com/v1","is_concealed":false},{"name":"EXTRA_CFG","value":"enabled","is_concealed":false},{"name":"GH_TOKEN","value":"","is_concealed":true}]\n'
    fi
    exit 0
  fi
fi
exit 1
EOF
chmod +x "$SHIM_DIR/op"

VAL_URL="$(PATH="$SHIM_DIR:$PATH" "$OP_READ" LITELLM_BASE_URL)"
assert_contains "$VAL_URL" "https://dev-llm.example.com" "op-read defaults to openshell-pi-dev Environment"

VAL_KEY="$(PATH="$SHIM_DIR:$PATH" "$OP_READ" --env openshell-pi-dev LITELLM_API_KEY)"
assert_contains "$VAL_KEY" "sk-dev-secret" "op-read retries with --reveal when field is concealed"

UNCONCEALED="$(PATH="$SHIM_DIR:$PATH" "$OP_READ" --list-unconcealed --env openshell-pi-alt)"
assert_contains "$UNCONCEALED" "EXTRA_CFG=enabled" "--list-unconcealed emits non-concealed config"
if [[ "$UNCONCEALED" == *"ghp_alt_org_token_456"* ]]; then
  echo "FAIL: --list-unconcealed must never emit concealed secrets" >&2
  exit 1
fi

# 8. Missing provider preflight error & live multi-env config merge (with fake openshell + op shims)
cat > "$SHIM_DIR/openshell" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "gateway" ] && [ "${2:-}" = "info" ]; then
  exit 0
fi
if [ "${1:-}" = "provider" ] && [ "${2:-}" = "get" ]; then
  for a in "$@"; do
    if [ "$a" = "-o" ] || [ "$a" = "--output" ]; then
      echo "error: unexpected argument '$a' found" >&2
      exit 2
    fi
  done
  exit 1
fi
if [ "${1:-}" = "provider" ] && [ "${2:-}" = "list" ]; then
  cat <<'JSON'
{
  "next_page_token": "",
  "providers": [
    {"name":"op-openshell-pi-dev","type":"openshell-pi-dev","credential_keys":["LITELLM_API_KEY"]},
    {"name":"op-openshell-pi-alt","type":"openshell-pi-alt","credential_keys":["LITELLM_API_KEY"]},
    {"name":"op-expired-env","type":"expired-env","credential_keys":["LITELLM_API_KEY"],"credential_expires_at_ms":{"LITELLM_API_KEY":1000}}
  ]
}
JSON
  exit 0
fi
if [ "${1:-}" = "provider" ] && ([ "${2:-}" = "create" ] || [ "${2:-}" = "update" ]); then
  printf 'PROVIDER_SYNC:%s\n' "$*" >&2
  exit 0
fi
if [ "${1:-}" = "sandbox" ] && [ "${2:-}" = "create" ]; then
  printf 'EXEC_SANDBOX:%s\n' "$*"
  exit 0
fi
exit 0
EOF
chmod +x "$SHIM_DIR/openshell"

set +e
MISS_OUT="$(cd "$PROJ_DIR" && PATH="$SHIM_DIR:$PATH" "$PI_OS" --op-env missing-env 2>&1)"
MISS_RC=$?
set -e
[ "$MISS_RC" -ne 0 ] || { echo "FAIL: expected missing provider check to exit non-zero" >&2; exit 1; }
assert_contains "$MISS_OUT" "1Password" "missing provider error references 1Password Environment setup"

MERGE_OUT="$(cd "$PROJ_DIR" && env -u LITELLM_BASE_URL -u GH_TOKEN -u GITHUB_TOKEN PATH="$SHIM_DIR:$PATH" "$PI_OS" -e openshell-pi-dev -e openshell-pi-alt)"
assert_contains "$MERGE_OUT" "--provider op-openshell-pi-dev --provider op-openshell-pi-alt" "live stack resolves 1Password op-<env> provider names"

set +e
EXP_OUT="$(cd "$PROJ_DIR" && PATH="$SHIM_DIR:$PATH" "$PI_OS" -e expired-env 2>&1)"
EXP_RC=$?
set -e
[ "$EXP_RC" -ne 0 ] || { echo "FAIL: expected expired credential TTL check to exit non-zero" >&2; exit 1; }
assert_contains "$EXP_OUT" "Send again" "expired TTL error tells user to Send again in 1Password"
assert_contains "$MERGE_OUT" "--env LITELLM_BASE_URL=https://alt-llm.example.com" "later stacked env overrides and normalizes LITELLM_BASE_URL"
assert_contains "$MERGE_OUT" "--env EXTRA_CFG=enabled" "unconcealed config from stacked env forwards to sandbox"
assert_contains "$MERGE_OUT" "--provider github-openshell-pi-alt" "attaches per-env github provider instead of plain --env GH_TOKEN"
if [[ "$MERGE_OUT" == *"--env GH_TOKEN="* ]] || [[ "$MERGE_OUT" == *"--env GITHUB_TOKEN="* ]]; then
  echo "FAIL: must never pass raw GH_TOKEN or GITHUB_TOKEN as plain --env" >&2
  exit 1
fi

# 9. pi-sandbox-init.sh exports PI_CODING_AGENT_DIR when unset and normalizes LITELLM_BASE_URL
# Use an isolated HOME so git config --global inside pi-sandbox-init never mutates host ~/.gitconfig.
SANDBOX_INIT_HOME="$TMP_ROOT/sandbox-init-home"
mkdir -p "$SANDBOX_INIT_HOME"
CHILD_AGENT_DIR="$(env -u PI_CODING_AGENT_DIR HOME="$SANDBOX_INIT_HOME" "$DOTFILES_ROOT/pi/openshell/pi-sandbox-init.sh" sh -c 'printf "%s" "${PI_CODING_AGENT_DIR:-}"')"
assert_contains "$CHILD_AGENT_DIR" "/tmp/pi-agent" "pi-sandbox-init exports PI_CODING_AGENT_DIR=/tmp/pi-agent to child"

FAKE_AGENT="$TMP_ROOT/fake-agent"
HOME="$SANDBOX_INIT_HOME" PI_CODING_AGENT_DIR="$FAKE_AGENT" LITELLM_BASE_URL="https://litellm.example.com/v1/" \
  "$DOTFILES_ROOT/pi/openshell/pi-sandbox-init.sh" true
MCP_CONTENT="$(cat "$FAKE_AGENT/mcp.json")"
assert_contains "$MCP_CONTENT" "\"url\": \"https://litellm.example.com/mcp\"" "strips trailing /v1/ before appending /mcp"
assert_contains "$MCP_CONTENT" 'Bearer ${LITELLM_API_KEY}' "keeps literal LITELLM_API_KEY placeholder expression in mcp.json"
SANDBOX_GPGSIGN="$(HOME="$SANDBOX_INIT_HOME" git config --global --get commit.gpgsign || true)"
assert_contains "$SANDBOX_GPGSIGN" "false" "pi-sandbox-init disables commit.gpgsign in isolated sandbox HOME"

# 10. Forward Git identity into sandbox
OUT_GIT="$(cd "$REPO_DIR" && git config user.name "Test Author" && git config user.email "author@example.com" && "$PI_OS" --dry-run)"
assert_contains "$OUT_GIT" "--env GIT_AUTHOR_NAME=Test Author" "forwards GIT_AUTHOR_NAME into sandbox"
assert_contains "$OUT_GIT" "--env GIT_AUTHOR_EMAIL=author@example.com" "forwards GIT_AUTHOR_EMAIL into sandbox"

# 11. Never pass raw GH_TOKEN / GITHUB_TOKEN as plain --env even in dry-run
OUT_GH="$(cd "$PROJ_DIR" && GH_TOKEN="gho_test_token_123" "$PI_OS" --dry-run)"
if [[ "$OUT_GH" == *"--env GH_TOKEN="* ]] || [[ "$OUT_GH" == *"--env GITHUB_TOKEN="* ]]; then
  echo "FAIL: dry-run must not emit raw GH_TOKEN as plain --env" >&2
  exit 1
fi

# 12. gateway.env resolves Colima DOCKER_HOST even before docker.sock exists (boot race)
FAKE_COLIMA_HOME="$TMP_ROOT/fake-colima-home"
mkdir -p "$FAKE_COLIMA_HOME/.colima/default"
GATEWAY_ENV_OUT="$(env -u DOCKER_HOST HOME="$FAKE_COLIMA_HOME" sh -c '. "$1"; printf "%s" "${DOCKER_HOST:-}"' _ "$DOTFILES_ROOT/pi/openshell/gateway.env")"
if [ ! -S /var/run/docker.sock ]; then
  assert_contains "$GATEWAY_ENV_OUT" "unix://$FAKE_COLIMA_HOME/.colima/default/docker.sock" "gateway.env sets DOCKER_HOST when ~/.colima/default exists before docker.sock"
fi
GATEWAY_ENV_KEEP="$(DOCKER_HOST="unix:///custom/docker.sock" HOME="$FAKE_COLIMA_HOME" sh -c '. "$1"; printf "%s" "${DOCKER_HOST:-}"' _ "$DOTFILES_ROOT/pi/openshell/gateway.env")"
assert_contains "$GATEWAY_ENV_KEEP" "unix:///custom/docker.sock" "gateway.env preserves explicit DOCKER_HOST"

# 13. Remote/cloud gateway dry-run skips local VM bind mounts & local image default
OUT_REMOTE="$(cd "$HOME" && env -u PI_OPENSHELL_IMAGE -u PI_OPENSHELL_REMOTE_IMAGE -u PI_OPENSHELL_TEMPLATE -u PI_OPENSHELL_REMOTE_TEMPLATE "$PI_OS" -g platform-tools --dry-run -- --model qwen)"
assert_contains "$OUT_REMOTE" "openshell sandbox create -g platform-tools" "remote dry-run forwards -g platform-tools"
assert_not_contains "$OUT_REMOTE" "--driver-config-json" "remote dry-run omits local VM --driver-config-json bind mounts"
assert_not_contains "$OUT_REMOTE" "PI_CODING_AGENT_SESSION_DIR=/sandbox/sessions" "remote dry-run omits local host session mount env"
assert_not_contains "$OUT_REMOTE" "--from pi-openshell:local" "remote dry-run omits local-only pi-openshell:local image"
assert_contains "$OUT_REMOTE" "pi-sandbox-init" "remote dry-run uses resilient init wrapper"

OUT_REMOTE_TPL="$(cd "$PROJ_DIR" && PI_OPENSHELL_REMOTE_TEMPLATE=pi-cloud "$PI_OS" -g platform-tools --no-policy --dry-run)"
assert_contains "$OUT_REMOTE_TPL" "--template pi-cloud" "remote dry-run applies PI_OPENSHELL_REMOTE_TEMPLATE"
assert_not_contains "$OUT_REMOTE_TPL" "--from " "remote template omits --from unless --image is explicit"
assert_not_contains "$OUT_REMOTE_TPL" "--policy " "--no-policy omits --policy"

OUT_REMOTE_IMG="$(cd "$PROJ_DIR" && PI_OPENSHELL_REMOTE_IMAGE=ghcr.io/example/pi:latest "$PI_OS" --gateway-endpoint https://gw.example.com --gateway-insecure --dry-run)"
assert_contains "$OUT_REMOTE_IMG" "--gateway-endpoint https://gw.example.com --gateway-insecure" "forwards direct gateway endpoint and insecure flag"
assert_contains "$OUT_REMOTE_IMG" "--from ghcr.io/example/pi:latest" "remote dry-run uses PI_OPENSHELL_REMOTE_IMAGE"

OUT_LOCAL_OVERRIDE="$(cd "$PROJ_DIR" && PI_OPENSHELL_GATEWAY=platform-tools PI_OPENSHELL_GATEWAY_ENDPOINT=https://gw.example.com "$PI_OS" --local --dry-run)"
assert_contains "$OUT_LOCAL_OVERRIDE" "openshell sandbox create -g openshell" "--local overrides remote gateway env vars back to local openshell"
assert_contains "$OUT_LOCAL_OVERRIDE" "--driver-config-json" "--local re-enables VM bind mounts"

# 14. Live gateway compute driver detection (port-forwarded non-VM remote gateway vs local VM gateway)
GW_SHIM_DIR="$TMP_ROOT/gw-shim"
mkdir -p "$GW_SHIM_DIR"
cat > "$GW_SHIM_DIR/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$GW_SHIM_DIR/gh"
cat > "$GW_SHIM_DIR/openshell" <<'EOF'
#!/usr/bin/env bash
SUB="${1:-}"
ACT="${2:-}"
TARGET_GW=""
ARGS=("$@")
for (( i=0; i<${#ARGS[@]}; i++ )); do
  if [ "${ARGS[i]}" = "-g" ] || [ "${ARGS[i]}" = "--gateway" ]; then
    TARGET_GW="${ARGS[i+1]:-}"
  fi
done
if [ "$SUB" = "gateway" ] && [ "$ACT" = "info" ]; then
  if [ "$TARGET_GW" = "platform-tools" ]; then
    printf '{"gateway":"platform-tools","server":"https://127.0.0.1:8080","status":"healthy","compute_drivers":[{"name":"kubernetes"}]}\n'
  else
    printf '{"gateway":"openshell","server":"https://localhost:17670","status":"healthy","compute_drivers":[{"name":"vm"}]}\n'
  fi
  exit 0
fi
if [ "$SUB" = "gateway" ] && [ "$ACT" = "list" ]; then
  printf '[{"name":"openshell","is_remote":false,"active":false},{"name":"platform-tools","is_remote":false,"active":true}]\n'
  exit 0
fi
if [ "$SUB" = "provider" ] && [ "$ACT" = "list" ]; then
  printf '{"next_page_token":"","providers":[{"name":"op-openshell-pi-dev","type":"openshell-pi-dev","credential_keys":["LITELLM_API_KEY"]}]}\n'
  exit 0
fi
if [ "$SUB" = "sandbox" ] && [ "$ACT" = "create" ]; then
  printf 'LIVE_SANDBOX:%s\n' "$*"
  exit 0
fi
exit 0
EOF
chmod +x "$GW_SHIM_DIR/openshell"

LIVE_LOCAL_OUT="$(cd "$PROJ_DIR" && env -u PI_OPENSHELL_GATEWAY -u PI_OPENSHELL_GATEWAY_ENDPOINT OPENSHELL_GATEWAY_ENDPOINT=https://127.0.0.1:8080 PATH="$GW_SHIM_DIR:$SHIM_DIR:$PATH" "$PI_OS")"
assert_contains "$LIVE_LOCAL_OUT" "sandbox create -g openshell" "live default targets local openshell even when active gateway is remote"
assert_contains "$LIVE_LOCAL_OUT" "--driver-config-json" "live local VM gateway attaches VM bind mounts"
assert_contains "$LIVE_LOCAL_OUT" "--from pi-openshell:local" "live local VM gateway uses pi-openshell:local"

LIVE_REMOTE_OUT="$(cd "$PROJ_DIR" && env -u PI_OPENSHELL_IMAGE -u PI_OPENSHELL_REMOTE_IMAGE -u PI_OPENSHELL_TEMPLATE -u PI_OPENSHELL_REMOTE_TEMPLATE PATH="$GW_SHIM_DIR:$SHIM_DIR:$PATH" "$PI_OS" -g platform-tools)"
assert_contains "$LIVE_REMOTE_OUT" "sandbox create -g platform-tools" "live -g platform-tools targets remote gateway"
assert_not_contains "$LIVE_REMOTE_OUT" "--driver-config-json" "live non-VM kubernetes driver (even on 127.0.0.1) skips VM bind mounts"
assert_not_contains "$LIVE_REMOTE_OUT" "--from pi-openshell:local" "live non-VM gateway omits local-only image"

# 15. Compound Engineering extension is copied from local host ~/.pi/agent/git into Dockerfile build context, settings.json, and pi-sandbox-init.sh
SETTINGS_CONTENT="$(cat "$DOTFILES_ROOT/pi/openshell/settings.json")"
assert_contains "$SETTINGS_CONTENT" "git:github.com/EveryInc/compound-engineering-plugin" "settings.json declares compound-engineering-plugin git package"
DOCKERFILE_CONTENT="$(cat "$DOTFILES_ROOT/pi/openshell/Dockerfile.pi")"
assert_contains "$DOCKERFILE_CONTENT" "COPY pi-seed/git/github.com/EveryInc/compound-engineering-plugin /opt/pi-seed/git/github.com/EveryInc/compound-engineering-plugin" "Dockerfile.pi copies host-staged compound-engineering-plugin into /opt/pi-seed/git"
assert_not_contains "$DOCKERFILE_CONTENT" "git clone" "Dockerfile.pi does not clone compound-engineering-plugin directly from GitHub"
assert_not_contains "$DOCKERFILE_CONTENT" "chmod 0644" "Dockerfile.pi preserves executable bits inside /opt/pi-seed"

BUILD_TEST_DIR="$TMP_ROOT/build-test"
BUILD_SHIM="$BUILD_TEST_DIR/shim"
BUILD_HOME="$BUILD_TEST_DIR/home"
BUILD_CAPTURED="$BUILD_TEST_DIR/captured.txt"
mkdir -p "$BUILD_SHIM" "$BUILD_HOME"
cat > "$BUILD_SHIM/docker" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "info" ] || ([ "\${1:-}" = "buildx" ] && [ "\${2:-}" = "version" ]); then
  exit 0
fi
CTX="\${@: -1}"
if [ -f "\$CTX/pi-seed/git/github.com/EveryInc/compound-engineering-plugin/skills/ce-work/SKILL.md" ]; then
  echo "HAS_CE_SKILL=1" > "$BUILD_CAPTURED"
fi
if [ -e "\$CTX/pi-seed/git/github.com/EveryInc/compound-engineering-plugin/node_modules" ]; then
  echo "HAS_HOST_NODE_MODULES=1" >> "$BUILD_CAPTURED"
fi
printf 'CTX=%s\n' "\$CTX" >> "$BUILD_CAPTURED"
exit 0
EOF
chmod +x "$BUILD_SHIM/docker"

# Fails cleanly when local host checkout is missing
set +e
BUILD_MISS_OUT="$(HOME="$BUILD_HOME" env -u PI_CODING_AGENT_DIR -u PI_HOST_AGENT_DIR -u PI_COMPOUND_ENGINEERING_DIR PATH="$BUILD_SHIM:$PATH" "$DOTFILES_ROOT/pi/openshell/build-image.sh" 2>&1)"
BUILD_MISS_RC=$?
set -e
[ "$BUILD_MISS_RC" -ne 0 ] || { echo "FAIL: build-image.sh should fail when host compound-engineering-plugin checkout is missing" >&2; exit 1; }
assert_contains "$BUILD_MISS_OUT" "compound-engineering-plugin not found" "build-image.sh explains missing host checkout"

# Copies host checkout into temp build context, strips host node_modules, and cleans up temp context
mkdir -p "$BUILD_HOME/.pi/agent/git/github.com/EveryInc/compound-engineering-plugin/skills/ce-work" \
         "$BUILD_HOME/.pi/agent/git/github.com/EveryInc/compound-engineering-plugin/node_modules/fake"
echo "skill" > "$BUILD_HOME/.pi/agent/git/github.com/EveryInc/compound-engineering-plugin/skills/ce-work/SKILL.md"
HOME="$BUILD_HOME" env -u PI_CODING_AGENT_DIR -u PI_HOST_AGENT_DIR -u PI_COMPOUND_ENGINEERING_DIR PATH="$BUILD_SHIM:$PATH" "$DOTFILES_ROOT/pi/openshell/build-image.sh"
BUILD_CAP_CONTENT="$(cat "$BUILD_CAPTURED")"
assert_contains "$BUILD_CAP_CONTENT" "HAS_CE_SKILL=1" "build-image.sh stages host ~/.pi/agent/git compound-engineering-plugin into Docker context"
assert_not_contains "$BUILD_CAP_CONTENT" "HAS_HOST_NODE_MODULES=1" "build-image.sh excludes host node_modules from staged build context"
STAGED_CTX_PATH="$(sed -n 's/^CTX=//p' "$BUILD_CAPTURED")"
[ ! -e "$STAGED_CTX_PATH" ] || { echo "FAIL: build-image.sh should clean up temporary build context on exit" >&2; exit 1; }

FAKE_SEED="$TMP_ROOT/fake-seed"
mkdir -p "$FAKE_SEED/git/github.com/EveryInc/compound-engineering-plugin" "$FAKE_SEED/npm"
FAKE_AGENT_CE="$TMP_ROOT/fake-agent-ce"
HOME="$SANDBOX_INIT_HOME" PI_SEED_DIR="$FAKE_SEED" PI_CODING_AGENT_DIR="$FAKE_AGENT_CE" \
  "$DOTFILES_ROOT/pi/openshell/pi-sandbox-init.sh" true
[ -L "$FAKE_AGENT_CE/git" ] || { echo "FAIL: expected pi-sandbox-init to symlink \$AGENT_DIR/git to \$SEED_DIR/git" >&2; exit 1; }
[ -d "$FAKE_AGENT_CE/git/github.com/EveryInc/compound-engineering-plugin" ] || { echo "FAIL: expected compound-engineering-plugin accessible via \$AGENT_DIR/git" >&2; exit 1; }

# 16. install.sh preserves active remote gateway when re-registering local gateway & supports -g remote profile sync
INSTALL_TEST_DIR="$TMP_ROOT/install-test"
INSTALL_SHIM="$INSTALL_TEST_DIR/shim"
INSTALL_LOG="$INSTALL_TEST_DIR/openshell.log"
INSTALL_CFG="$INSTALL_TEST_DIR/xdg-config"
mkdir -p "$INSTALL_SHIM" "$INSTALL_CFG"
mkdir -p "$INSTALL_TEST_DIR/fake-tap/Formula"
touch "$INSTALL_TEST_DIR/fake-tap/Formula/openshell.rb"
cat > "$INSTALL_SHIM/brew" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "--repository" ]; then
  printf '%s\n' "$INSTALL_TEST_DIR/fake-tap"
  exit 0
fi
exit 0
EOF
chmod +x "$INSTALL_SHIM/brew"
cat > "$INSTALL_SHIM/openshell" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$INSTALL_LOG"
case "\${1:-} \${2:-}" in
  "gateway list")
    printf '[{"name":"platform-tools","is_remote":false,"active":true}]\n'
    exit 0
    ;;
  "gateway add"|"gateway select"|"gateway info")
    exit 0
    ;;
  "profile describe")
    exit 1
    ;;
  "profile import"|"profile update")
    exit 0
    ;;
esac
exit 0
EOF
chmod +x "$INSTALL_SHIM/openshell"

# Local install re-registers missing 'openshell' gateway and restores active 'platform-tools'
INSTALL_LOCAL_OUT="$(HOME="$INSTALL_TEST_DIR" XDG_CONFIG_HOME="$INSTALL_CFG" LITELLM_BASE_URL="https://litellm.example.com" PATH="$INSTALL_SHIM:$SHIM_DIR:$PATH" \
  "$DOTFILES_ROOT/pi/openshell/install.sh" --local)"
INSTALL_LOG_CONTENT="$(cat "$INSTALL_LOG")"
assert_contains "$INSTALL_LOG_CONTENT" "gateway add https://localhost:17670 --local --name openshell" "install.sh re-registers missing local openshell gateway"
assert_contains "$INSTALL_LOG_CONTENT" "gateway select platform-tools" "install.sh preserves previously active remote gateway"
assert_contains "$INSTALL_LOG_CONTENT" "profile import -g openshell" "install.sh imports profiles explicitly against -g openshell"
[ -f "$INSTALL_CFG/openshell/gateway.toml" ] || { echo "FAIL: local install.sh should stage gateway.toml" >&2; exit 1; }
[ -f "$INSTALL_CFG/openshell/.profile-openshell-github.sha256" ] || { echo "FAIL: local install.sh should write gateway-scoped profile stamp" >&2; exit 1; }

# Remote install syncs profiles to -g platform-tools without writing local gateway.toml
REMOTE_CFG="$INSTALL_TEST_DIR/xdg-remote"
mkdir -p "$REMOTE_CFG"
: > "$INSTALL_LOG"
HOME="$INSTALL_TEST_DIR" XDG_CONFIG_HOME="$REMOTE_CFG" LITELLM_BASE_URL="https://litellm.example.com" PATH="$INSTALL_SHIM:$SHIM_DIR:$PATH" \
  "$DOTFILES_ROOT/pi/openshell/install.sh" -g platform-tools >/dev/null
REMOTE_LOG_CONTENT="$(cat "$INSTALL_LOG")"
assert_contains "$REMOTE_LOG_CONTENT" "profile import -g platform-tools" "remote install.sh imports profiles against -g platform-tools"
[ ! -f "$REMOTE_CFG/openshell/gateway.toml" ] || { echo "FAIL: remote install.sh must not stage local gateway.toml" >&2; exit 1; }
[ -f "$REMOTE_CFG/openshell/.profile-platform-tools-github.sha256" ] || { echo "FAIL: remote install.sh should write remote-scoped profile stamp" >&2; exit 1; }

# 17. Ensure no hardcoded *.1password.com account domains exist in pi/ or bin/pi-os
if git -C "$DOTFILES_ROOT" grep -En "[A-Za-z0-9-]+\.1password\.com" -- pi/ bin/pi-os ':!pi/openshell/test-pi-os.sh'; then
  echo "FAIL: found hardcoded 1Password account domain in repository files" >&2
  exit 1
fi

echo "PASS: all pi-os tests passed"
