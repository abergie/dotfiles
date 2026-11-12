# dotfiles

## topical

Everything's built around topic areas. If you're adding a new area to your
forked dotfiles — say, "Java" — you can simply add a `java` directory and put
files in there. Anything with an extension of `.zsh` will get automatically
included into your shell. Anything with an extension of `.symlink` will get
symlinked without extension into `$HOME` when you run `script/bootstrap`.

## components

There's a few special files in the hierarchy.

- **Brewfile**: Managed via `brew bundle`. Defines Homebrew taps, formulae,
  casks, VS Code extensions, and Go/`uv` tools.
- **bin/**: Anything in `bin/` will get added to your `$PATH` and be made
  available everywhere.
- **functions/**: Autoloaded Zsh functions and completion scripts (`_brew`,
  `c`, `extract`, `gf`, etc.).
- **pi/**: Configuration (`AGENTS.md`), OpenShell MicroVM sandbox assets (`pi/openshell/`, launched via `bin/pi-os`), `nono` session hooks, and custom extensions (`litellm`, `worktree-status`) managed by `pi/install.sh`.
- **topic/\*.zsh**: Any files ending in `.zsh` get loaded into your
  environment.
- **topic/path.zsh**: Any file named `path.zsh` is loaded first and is
  expected to setup `$PATH` or similar.
- **topic/completion.zsh**: Any file named `completion.zsh` is loaded
  last and is expected to setup autocomplete.
- **topic/install.sh**: Any file named `install.sh` is executed when you run `script/install` (for example `homebrew/install.sh`, `zsh/install.sh`, `pi/install.sh`). To avoid being loaded automatically, its extension is `.sh`, not `.zsh`.
- **topic/\*.symlink**: Any file ending in `*.symlink` gets symlinked into
  your `$HOME`. This is so you can keep all of those versioned in your dotfiles
  but still keep those autoloaded files in your home directory. These get
  symlinked in when you run `script/bootstrap`.

## install

Run this:

```sh
git clone https://github.com/abergie/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
script/bootstrap
```

This will symlink the appropriate files in `.dotfiles` to your home directory,
configure your `~/.pi/agent` setup (if `pi` is installed), and run `dot` on
macOS to install Homebrew dependencies and run topic installers. Everything is
configured and tweaked within `~/.dotfiles`.

The main file you'll want to change right off the bat is `zsh/zshrc.symlink`,
which sets up a few paths that'll be different on your particular machine. You
can also place machine-local secrets or environment variables in `~/.localrc`,
which `zshrc` sources automatically if present.

`dot` is a simple script in `bin/` that installs/upgrades Homebrew packages,
dumps the current system state back into `Brewfile` (`brew bundle dump`), and
runs `script/install` (`brew bundle` and all topic `install.sh` scripts). Run
`dot` from time to time to keep your environment fresh and up-to-date. To
apply macOS defaults (`macos/set-defaults.sh`), run `set-defaults`.

## thanks

forked from [Zach Holman](https://github.com/holman)
