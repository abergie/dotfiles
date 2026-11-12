# Pi on NVIDIA OpenShell (macOS MicroVM + 1Password)

Runs Pi inside a per-session Linux MicroVM on Apple `Hypervisor.framework` (`libkrun`) with default-deny network egress. Only `/usr/local/bin/node` inside the VM can reach the LiteLLM endpoint configured by `LITELLM_BASE_URL` (`/v1/*` inference and `/mcp` Streamable HTTP), and `LITELLM_API_KEY` is injected as an opaque placeholder resolved on the host by OpenShell's supervisor.

Host `pi` (`~/.pi/agent`, managed by `pi/install.sh`) and existing `nono` profiles remain untouched so `pi`, `nono`, and `pi-os` can all run side by side.

## One-Time Setup

### 1. Gateway and `litellm` profile

`pi/openshell/install-tap.sh` pre-stages NVIDIA's macOS release tap, and `pi/openshell/install.sh` copies `gateway.toml` and `gateway.env` to `~/.config/openshell/`, reads `LITELLM_BASE_URL` from your environment or 1Password, and renders/imports the `litellm` provider profile into your local OpenShell gateway:

```sh
~/.dotfiles/pi/openshell/install.sh
openshell gateway info
openshell profile describe litellm
```

To pin a specific 1Password account, vault, or item on machines with multiple accounts, set `OP_ACCOUNT`, `OP_VAULT`, or `OP_ITEM` in `~/.localrc`.

### 2. Build the guest image

Colima/Docker is used only at build time to compile `Dockerfile.pi` into `pi-openshell:local`; runtime execution uses OpenShell's Apple Hypervisor VM driver:

```sh
~/.dotfiles/pi/openshell/build-image.sh
```

Re-run `build-image.sh` whenever `AGENTS.md`, extensions, or `PI_VERSION` change.

### 3. Connect 1Password Environments (beta)

1. In **1Password for Mac**, go to **Settings → Developer** and enable **Provision OpenShell providers**.
2. Go to **Developer → View Environments → New environment**, name it (for example `pi-litellm`), and add `LITELLM_API_KEY` (secret) and `LITELLM_BASE_URL` (configuration).
3. Inside that Environment, click **Connect** next to **OpenShell provider**:
   - **Provider name:** `litellm`
   - **Profile:** **Existing profile** → select `litellm`
   - **Secrets expire:** choose your desired TTL window
4. Authorize the prompt. Confirm OpenShell registered the provider:

```sh
openshell provider list
```

When the TTL expires, open the Environment in 1Password Desktop and choose **⋯ → Send again**.

## Daily Usage

From any project directory or linked git worktree (`.worktrees/<branch>`):

```sh
pi-os
```

`pi-os` mounts the physical repository root at `/sandbox/work` over `virtiofs` (entering the matching worktree subdirectory automatically when run inside `.worktrees/`), populates `/tmp/pi-agent/mcp.json` from `LITELLM_BASE_URL`, and deletes the ephemeral MicroVM when Pi exits.

Useful flags and inspection commands:

```sh
pi-os --dry-run              # Inspect the openshell sandbox create command
pi-os --shell                # Open bash inside the MicroVM instead of pi
pi-os --keep --name pi-dev   # Retain the sandbox after exit
openshell logs <name> --tail # Stream allowed and blocked network events
openshell term               # Interactive OpenShell TUI monitor
```
