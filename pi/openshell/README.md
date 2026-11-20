# Pi on NVIDIA OpenShell (Local MicroVM + Remote Gateways + 1Password Environments)

Runs Pi inside either a local per-session Linux MicroVM on Apple `Hypervisor.framework` (`libkrun`) or a remote/cloud OpenShell gateway with default-deny network egress. Only `/usr/local/bin/node` inside the sandbox can reach the LiteLLM endpoint configured by `LITELLM_BASE_URL` (`/v1/*` inference and `/mcp` Streamable HTTP), while `git` and `gh` inside the sandbox can interact with `github.com` and `api.github.com` to push branches and create pull requests. `LITELLM_API_KEY` is injected as an opaque placeholder resolved by OpenShell's supervisor.

Host `pi` (`~/.pi/agent`, managed by `pi/install.sh`) and existing `nono` profiles remain untouched so `pi`, `nono`, and `pi-os` can all run side by side.

## One-Time Setup

### 1. Create 1Password Environment(s)

1. In **1Password for Mac**, go to **Settings → Developer** and enable **Provision OpenShell providers**.
2. Go to **Developer → View Environments → New environment**, name the default environment `openshell-pi-dev`, and add:
   - `LITELLM_API_KEY` (secret)
   - `LITELLM_BASE_URL` (e.g. `https://your-litellm-host.example.com`, set **Show value by default** so non-secret config reads require no secret reveal)
   - `GH_TOKEN` or `GITHUB_TOKEN` (secret; optional org-specific personal access token with repo/PR permissions)
3. Create additional Environments as needed (for example `openshell-pi-staging`, `openshell-pi-client-a`, `openshell-pi-personal`). Each environment can store its own organization `GH_TOKEN`, `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, and `LITELLM_BASE_URL`.

### 2. Sync gateway config and OpenShell provider profiles

`pi/openshell/install.sh` stages `gateway.toml` and `gateway.env` into `~/.config/openshell/`, ensures the local `openshell` gateway (`https://localhost:17670`) is registered without overwriting any active remote gateway selection, reads `LITELLM_BASE_URL` from each 1Password Environment, and imports/updates matching OpenShell provider profiles (`github`, `openshell-pi-dev`, etc., plus a `litellm` alias for the primary environment):

```sh
# Default local gateway (openshell) and default environment (openshell-pi-dev)
~/.dotfiles/pi/openshell/install.sh

# Sync multiple LiteLLM Environments at once
~/.dotfiles/pi/openshell/install.sh --env openshell-pi-dev --env openshell-pi-staging
# (or set PI_OP_ENVS="openshell-pi-dev,openshell-pi-staging" in ~/.localrc)

# Sync provider profiles to a remote/cloud OpenShell gateway (leaves local gateway config untouched)
~/.dotfiles/pi/openshell/install.sh -g platform-tools
~/.dotfiles/pi/openshell/install.sh --gateway-endpoint https://gateway.example.com
```

### 3. Connect Environment(s) in 1Password Desktop

For each Environment in **1Password Desktop → Developer → View Environments**:

1. Click **Connect** next to **OpenShell provider**:
   - **Provider name:** match the Environment name (for example `openshell-pi-dev`; 1Password prefixes it as `op-openshell-pi-dev`, which `pi-os` resolves automatically)
   - **Profile:** **Existing profile** → select `openshell-pi-dev` (or create a custom profile for non-LiteLLM services like GitHub)
   - **Secrets expire:** choose your desired TTL window
2. Authorize the prompt and verify on the host:

```sh
openshell provider list
```

When a TTL expires, open the Environment in 1Password Desktop and choose **⋯ → Send again**.

### 4. Build the guest image

Colima/Docker is used only at build time to compile `Dockerfile.pi` into `pi-openshell:local`, pre-seeding `pi-subagents`, `pi-ask-user`, and copying your local host `~/.pi/agent/git/github.com/EveryInc/compound-engineering-plugin` checkout into `/opt/pi-seed/git`; runtime execution uses OpenShell's Apple Hypervisor VM driver:

```sh
~/.dotfiles/pi/openshell/build-image.sh
# Optional: override the local host Compound Engineering checkout path
PI_COMPOUND_ENGINEERING_DIR=/path/to/compound-engineering-plugin ~/.dotfiles/pi/openshell/build-image.sh
```

## Daily Usage

```sh
# Launch on the local 'openshell' MicroVM gateway with default Environment (openshell-pi-dev)
# (works even when 'openshell gateway select' points at a remote gateway)
pi-os

# Target a remote/cloud OpenShell gateway (automatically omits local macOS VM bind mounts)
pi-os -g platform-tools
pi-os -g platform-tools --template pi-cloud
pi-os -g platform-tools --image ghcr.io/your-org/pi-openshell:latest
pi-os --gateway-endpoint https://gateway.example.com --no-policy

# Or configure remote defaults via environment variables:
#   PI_OPENSHELL_GATEWAY=platform-tools
#   PI_OPENSHELL_REMOTE_IMAGE=ghcr.io/your-org/pi-openshell:latest
#   PI_OPENSHELL_REMOTE_TEMPLATE=pi-cloud
# Override back to the local VM gateway at any time with:
pi-os --local

# Switch to another Environment for this session
pi-os -e openshell-pi-staging
PI_OP_ENV=openshell-pi-staging pi-os

# Stack multiple Environments / providers into one MicroVM session
# (later -e flags take precedence for non-secret config vars)
pi-os -e openshell-pi-dev -e github-work

# Or attach explicit OpenShell providers directly
pi-os -p openshell-pi-dev -p custom-service

# GitHub operations inside the sandbox:
# - git commit (attributing GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL)
# - git push (via https://github.com/...)
# - gh pr create / gh pr list / gh api (via api.github.com)
#
# Identity & Token resolution order:
# - Git author/committer: 1Password Environment (GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL) -> host git config (user.name / user.email)
# - GitHub token: 1Password Environment (GH_TOKEN / GITHUB_TOKEN) -> host env -> host 'gh auth token'
#   (automatically synced into a per-environment OpenShell 'github-<env>' provider so
#   only opaque placeholders enter the VM)

# Session persistence:
# Sandbox .jsonl session files persist on the host under ~/.pi/agent/sessions/sandbox
# (mounted at /sandbox/sessions via PI_CODING_AGENT_SESSION_DIR):
pi-os -- -c                  # Continue the most recent sandbox session
pi-os -- -r                  # Pick a past sandbox session to resume

# Inspect command, open a shell, or view logs
pi-os --dry-run
pi-os --shell
openshell logs <name> --tail
openshell term
```

Host `pi` outside OpenShell honors the same `PI_OP_ENV` / `PI_OP_ENVS` variables (defaulting to `openshell-pi-dev`).
