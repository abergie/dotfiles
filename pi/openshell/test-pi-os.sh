#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
PI_OS="$DOTFILES_ROOT/bin/pi-os"

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

if [ ! -x "$PI_OS" ]; then
  echo "FAIL: $PI_OS does not exist or is not executable" >&2
  exit 1
fi

# 1. Standard directory dry-run
PROJ_DIR="$TMP_ROOT/my-project"
mkdir -p "$PROJ_DIR"
REAL_PROJ_DIR="$(cd "$PROJ_DIR" && pwd -P)"

OUT1="$(cd "$PROJ_DIR" && "$PI_OS" --dry-run -- --model qwen)"
assert_contains "$OUT1" "openshell sandbox create" "standard dry-run invokes openshell sandbox create"
assert_contains "$OUT1" "--no-keep" "standard dry-run uses --no-keep by default"
assert_contains "$OUT1" "--no-auto-providers" "standard dry-run disables auto-providers"
assert_contains "$OUT1" "--from pi-openshell:local" "standard dry-run selects pi-openshell:local"
assert_contains "$OUT1" "--provider litellm" "standard dry-run attaches litellm provider"
assert_contains "$OUT1" "\"source\":\"$REAL_PROJ_DIR\"" "standard dry-run mounts physical project dir"
assert_contains "$OUT1" "\"target\":\"/sandbox/work\"" "standard dry-run mounts at /sandbox/work"
assert_contains "$OUT1" "/usr/local/bin/pi-sandbox-init --workdir /sandbox/work pi --model qwen" "standard dry-run passes workdir and pi args"

# 2. Linked git worktree mounts common repo root and enters relative worktree subdir
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

# 3. Symlinked directory resolves to physical target path
LINK_DIR="$TMP_ROOT/project-symlink"
ln -s "$PROJ_DIR" "$LINK_DIR"
OUT3="$(cd -P "$TMP_ROOT" && cd "$LINK_DIR" && "$PI_OS" --dry-run)"
assert_contains "$OUT3" "\"source\":\"$REAL_PROJ_DIR\"" "symlinked cwd canonicalizes to physical target"

# 4. Refuses mounting $HOME or /
set +e
HOME_OUT="$(cd "$HOME" && "$PI_OS" --dry-run 2>&1)"
HOME_RC=$?
ROOT_OUT="$(cd / && "$PI_OS" --dry-run 2>&1)"
ROOT_RC=$?
set -e
if [ "$HOME_RC" -eq 0 ]; then
  echo "FAIL: expected $PI_OS to refuse mounting $HOME" >&2
  exit 1
fi
if [ "$ROOT_RC" -eq 0 ]; then
  echo "FAIL: expected $PI_OS to refuse mounting /" >&2
  exit 1
fi
assert_contains "$HOME_OUT" "refusing to mount" "home guard explains refusal"

FAKE_HOME="$TMP_ROOT/fake-home"
mkdir -p "$FAKE_HOME/.ssh"
set +e
SSH_OUT="$(cd "$FAKE_HOME/.ssh" && HOME="$FAKE_HOME" "$PI_OS" --dry-run 2>&1)"
SSH_RC=$?
set -e
if [ "$SSH_RC" -eq 0 ]; then
  echo "FAIL: expected $PI_OS to refuse mounting ~/.ssh" >&2
  exit 1
fi

# 5. Missing provider preflight error (non-dry-run with fake openshell shim)
SHIM_DIR="$TMP_ROOT/shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/openshell" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "gateway" ] && [ "${2:-}" = "info" ]; then
  exit 0
fi
if [ "${1:-}" = "provider" ] && [ "${2:-}" = "get" ]; then
  echo "Error: provider not found" >&2
  exit 1
fi
exit 0
EOF
chmod +x "$SHIM_DIR/openshell"

set +e
MISS_OUT="$(cd "$PROJ_DIR" && PATH="$SHIM_DIR:$PATH" "$PI_OS" 2>&1)"
MISS_RC=$?
set -e
if [ "$MISS_RC" -eq 0 ]; then
  echo "FAIL: expected missing provider check to exit non-zero" >&2
  exit 1
fi
assert_contains "$MISS_OUT" "1Password" "missing provider error references 1Password Environment setup"

# 6. LITELLM_BASE_URL env var forwards into openshell sandbox create
OUT_URL="$(cd "$PROJ_DIR" && LITELLM_BASE_URL="https://litellm.example.com" "$PI_OS" --dry-run)"
assert_contains "$OUT_URL" "--env LITELLM_BASE_URL=https://litellm.example.com" "forwards LITELLM_BASE_URL env into sandbox"

# 7. pi-sandbox-init.sh renders mcp.json dynamically from LITELLM_BASE_URL
FAKE_AGENT="$TMP_ROOT/fake-agent"
PI_CODING_AGENT_DIR="$FAKE_AGENT" LITELLM_BASE_URL="https://litellm.example.com/" \
  "$DOTFILES_ROOT/pi/openshell/pi-sandbox-init.sh" true
MCP_CONTENT="$(cat "$FAKE_AGENT/mcp.json")"
assert_contains "$MCP_CONTENT" "\"url\": \"https://litellm.example.com/mcp\"" "renders /mcp URL from LITELLM_BASE_URL without trailing slash"
assert_contains "$MCP_CONTENT" 'Bearer ${LITELLM_API_KEY}' "keeps literal LITELLM_API_KEY placeholder expression in mcp.json"

# 8. Ensure no hardcoded *.1password.com account domains exist in pi/ or bin/pi-os
if git -C "$DOTFILES_ROOT" grep -En "[A-Za-z0-9-]+\.1password\.com" -- pi/ bin/pi-os ':!pi/openshell/test-pi-os.sh'; then
  echo "FAIL: found hardcoded 1Password account domain in repository files" >&2
  exit 1
fi

echo "PASS: all pi-os tests passed"
