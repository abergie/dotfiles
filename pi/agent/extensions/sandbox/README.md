# pi Sandbox Extension

OS-level sandboxing for bash commands in [pi](https://github.com/earendil-works/pi).

Uses `@anthropic-ai/sandbox-runtime` to enforce filesystem and network restrictions via `sandbox-exec` on macOS and `bubblewrap` on Linux.

## What it does

This extension overrides the built-in `bash` tool so that every command runs inside an OS-level sandbox with restricted:

- **Network access** — only allowed domains can be reached.
- **Filesystem access** — reads/writes are limited by allow/deny lists.

## Setup

1. Make sure this repository is checked out at `~/.dotfiles/pi` and that `~/.pi/agent/extensions/sandbox` symlinks to `~/.dotfiles/pi/agent/extensions/sandbox`.
2. Install dependencies:

   ```bash
   cd ~/.pi/agent/extensions/sandbox
   npm install
   ```

3. (macOS only) No extra system packages are required — `sandbox-exec` is built in.
4. (Linux only) Install the required system packages:

   ```bash
   # Debian/Ubuntu
   sudo apt-get install bubblewrap socat ripgrep

   # macOS
   # already provided by sandbox-exec
   ```

## Usage

```bash
# enable sandbox with default/config settings
pi -e ./sandbox

# disable sandboxing
pi -e ./sandbox --no-sandbox

# show current sandbox configuration
/sandbox
```

## Configuration

Config files are merged in this order (project config wins):

- `~/.pi/agent/extensions/sandbox.json` — global
- `<cwd>/.pi/sandbox.json` — project-local

Example `sandbox.json`:

```json
{
  "enabled": true,
  "network": {
    "allowedDomains": ["github.com", "*.github.com"],
    "deniedDomains": []
  },
  "filesystem": {
    "denyRead": ["~/.ssh", "~/.aws"],
    "allowWrite": [".", "/tmp"],
    "denyWrite": [".env"]
  }
}
```

## Default policy

- **Allowed network domains**: `npmjs.org`, `registry.npmjs.org`, `pypi.org`, `github.com`, `api.github.com`, `raw.githubusercontent.com`, etc.
- **Denied reads**: `~/.ssh`, `~/.aws`, `~/.gnupg`
- **Allowed writes**: current working directory and `/tmp`
- **Denied writes**: `.env`, `.env.*`, `*.pem`, `*.key`

## Source

Copied from the official pi examples:
https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions/sandbox
