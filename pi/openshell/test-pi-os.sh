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

# 1. Default environment (openshell-pi-dev) dry-run
PROJ_DIR="$TMP_ROOT/my-project"
mkdir -p "$PROJ_DIR"
REAL_PROJ_DIR="$(cd "$PROJ_DIR" && pwd -P)"

OUT1="$(cd "$PROJ_DIR" && env -u PI_OP_ENV -u PI_OP_ENVS -u PI_OPENSHELL_PROVIDER -u PI_OPENSHELL_PROVIDERS "$PI_OS" --dry-run -- --model qwen)"
assert_contains "$OUT1" "openshell sandbox create" "standard dry-run invokes openshell sandbox create"
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
assert_contains "$MERGE_OUT" "--env GH_TOKEN=ghp_alt_org_token_456" "loads environment-specific GH_TOKEN from 1Password Environment"
assert_contains "$MERGE_OUT" "--env GITHUB_TOKEN=ghp_alt_org_token_456" "mirrors GITHUB_TOKEN from 1Password Environment"

# 9. pi-sandbox-init.sh exports PI_CODING_AGENT_DIR when unset and normalizes LITELLM_BASE_URL
CHILD_AGENT_DIR="$(env -u PI_CODING_AGENT_DIR "$DOTFILES_ROOT/pi/openshell/pi-sandbox-init.sh" sh -c 'printf "%s" "${PI_CODING_AGENT_DIR:-}"')"
assert_contains "$CHILD_AGENT_DIR" "/tmp/pi-agent" "pi-sandbox-init exports PI_CODING_AGENT_DIR=/tmp/pi-agent to child"

FAKE_AGENT="$TMP_ROOT/fake-agent"
PI_CODING_AGENT_DIR="$FAKE_AGENT" LITELLM_BASE_URL="https://litellm.example.com/v1/" \
  "$DOTFILES_ROOT/pi/openshell/pi-sandbox-init.sh" true
MCP_CONTENT="$(cat "$FAKE_AGENT/mcp.json")"
assert_contains "$MCP_CONTENT" "\"url\": \"https://litellm.example.com/mcp\"" "strips trailing /v1/ before appending /mcp"
assert_contains "$MCP_CONTENT" 'Bearer ${LITELLM_API_KEY}' "keeps literal LITELLM_API_KEY placeholder expression in mcp.json"

# 10. Forward Git identity into sandbox
OUT_GIT="$(cd "$REPO_DIR" && git config user.name "Test Author" && git config user.email "author@example.com" && "$PI_OS" --dry-run)"
assert_contains "$OUT_GIT" "--env GIT_AUTHOR_NAME=Test Author" "forwards GIT_AUTHOR_NAME into sandbox"
assert_contains "$OUT_GIT" "--env GIT_AUTHOR_EMAIL=author@example.com" "forwards GIT_AUTHOR_EMAIL into sandbox"

# 11. Forward GH_TOKEN / GITHUB_TOKEN into sandbox when present
OUT_GH="$(cd "$PROJ_DIR" && GH_TOKEN="gho_test_token_123" "$PI_OS" --dry-run)"
assert_contains "$OUT_GH" "--env GH_TOKEN=gho_test_token_123" "forwards GH_TOKEN into sandbox"
assert_contains "$OUT_GH" "--env GITHUB_TOKEN=gho_test_token_123" "forwards GITHUB_TOKEN into sandbox"

# 12. Ensure no hardcoded *.1password.com account domains exist in pi/ or bin/pi-os
if git -C "$DOTFILES_ROOT" grep -En "[A-Za-z0-9-]+\.1password\.com" -- pi/ bin/pi-os ':!pi/openshell/test-pi-os.sh'; then
  echo "FAIL: found hardcoded 1Password account domain in repository files" >&2
  exit 1
fi

echo "PASS: all pi-os tests passed"
