# Pi on NVIDIA OpenShell (macOS MicroVM + 1Password Environments)

Runs Pi inside a per-session Linux MicroVM on Apple `Hypervisor.framework` (`libkrun`) with default-deny network egress. Only `/usr/local/bin/node` inside the VM can reach the LiteLLM endpoint configured by `LITELLM_BASE_URL` (`/v1/*` inference and `/mcp` Streamable HTTP), and `LITELLM_API_KEY` is injected as an opaque placeholder resolved on the host by OpenShell's supervisor.

Host `pi` (`~/.pi/agent`, managed by `pi/install.sh`) and existing `nono` profiles remain untouched so `pi`, `nono`, and `pi-os` can all run side by side.

## One-Time Setup

### 1. Create 1Password Environment(s)

1. In **1Password for Mac**, go to **Settings → Developer** and enable **Provision OpenShell providers**.
2. Go to **Developer → View Environments → New environment**, name the default environment `openshell-pi-dev`, and add:
   - `LITELLM_API_KEY` (secret)
   - `LITELLM_BASE_URL` (e.g. `https://your-litellm-host.example.com`, set **Show value by default** so non-secret config reads require no secret reveal)
3. Create additional Environments as needed (for example `openshell-pi-staging`, `openshell-pi-personal`, or service-specific Environments such as `github-work`).

### 2. Sync gateway config and OpenShell provider profiles

`pi/openshell/install.sh` stages `gateway.toml` and `gateway.env` into `~/.config/openshell/`, reads `LITELLM_BASE_URL` from each 1Password Environment, and imports/updates a matching OpenShell provider profile (`openshell-pi-dev`, etc., plus a `litellm` alias for the primary environment):

```sh
# Default environment (openshell-pi-dev)
~/.dotfiles/pi/openshell/install.sh

# Sync multiple LiteLLM Environments at once
~/.dotfiles/pi/openshell/install.sh --env openshell-pi-dev --env openshell-pi-staging
# (or set PI_OP_ENVS="openshell-pi-dev,openshell-pi-staging" in ~/.localrc)
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

Colima/Docker is used only at build time to compile `Dockerfile.pi` into `pi-openshell:local`; runtime execution uses OpenShell's Apple Hypervisor VM driver:

```sh
~/.dotfiles/pi/openshell/build-image.sh
```

## Daily Usage

```sh
# Launch with default Environment (openshell-pi-dev)
pi-os

# Switch to another Environment for this session
pi-os -e openshell-pi-staging
PI_OP_ENV=openshell-pi-staging pi-os

# Stack multiple Environments / providers into one MicroVM session
# (later -e flags take precedence for non-secret config vars)
pi-os -e openshell-pi-dev -e github-work

# Or attach explicit OpenShell providers directly
pi-os -p openshell-pi-dev -p custom-service

# Inspect command, open a shell, or view logs
pi-os --dry-run
pi-os --shell
openshell logs <name> --tail
openshell term
```

Host `pi` outside OpenShell honors the same `PI_OP_ENV` / `PI_OP_ENVS` variables (defaulting to `openshell-pi-dev`).
