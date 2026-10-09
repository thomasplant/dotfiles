# dotfiles

Shell and tool configuration for macOS, Windows, WSL, Fedora and Arch.
Mac/Linux use [GNU Stow](https://www.gnu.org/software/stow/); Windows uses `install.ps1`.

## Layout

The repo mirrors `$HOME`, so on Mac/Linux the path *is* the configuration:

```
.config/ripgrep/ripgreprc       shared
.config/lazygit/config.yml      shared
.config/git/config              shared
.config/nvim/                   shared Neovim config (including lazy-lock.json)
.pi/agent/                      shared Pi config (whole-folder link)
.pi/.gitignore                  Pi-specific tracked-file allowlist
windows/                        Windows only (PowerShell profile, oh-my-posh theme)

bootstrap.sh          install packages (brew / pacman / dnf / apt)
bootstrap.ps1         install Windows tools, build tools, modules and npm dependencies
install.sh            symlinks via stow (Mac / Linux)
install.ps1           symlinks via PowerShell (Windows)
.stow-local-ignore    what stow must not link
```

Shell (`.zshrc`, `.zshenv`) and tmux config are still to be imported from the Mac.

## Install

**Mac / Linux**

```sh
git clone <this-repo> ~/dotfiles && cd ~/dotfiles
./bootstrap.sh
./install.sh --dry   # preview
./install.sh         # link   (--undo to remove)
```

**Windows** (needs Developer Mode or an elevated shell for symlinks)

```powershell
git clone <this-repo> $HOME\dotfiles; cd $HOME\dotfiles
./bootstrap.ps1 -WhatIf # preview missing tools
./bootstrap.ps1         # install missing tools, not upgrades
# Open a new terminal if needed to pick up installed tools.
./install.ps1 -WhatIf   # preview
./install.ps1           # link   (-Undo to remove)
```

Run the scripts in PowerShell 7. WinGet (App Installer) must be available for
missing tools.

On Windows, `install.ps1` moves existing files/directories to
`<name>.bak-<timestamp>`, including an existing `~\.pi\agent` directory;
it does not delete them or merge their contents into the repo.

| Repo file | Windows destination |
|---|---|
| `.config/git/config` | `~\.config\git\config` |
| `.config/ripgrep/ripgreprc` | `~\.ripgreprc` (where `RIPGREP_CONFIG_PATH` points) |
| `.config/lazygit/config.yml` | `%LOCALAPPDATA%\lazygit\config.yml` |
| `.config/nvim/` | `%LOCALAPPDATA%\nvim` (directory symlink) |
| `.pi/agent/` | `~\.pi\agent` (directory symlink) |
| `windows/gruvbox-lean.omp.json` | `~\.config\oh-my-posh\gruvbox-lean.omp.json` |
| `windows/Microsoft.PowerShell_profile.ps1` | `$PROFILE` |

## NVIM

This Neovim config started from [Kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)
and has been customized for my workflow. Thanks to the Kickstart contributors
for the foundation. Its MIT license is retained in [.config/nvim/LICENSE.md](.config/nvim/LICENSE.md).

Use `:checkhealth dotfiles` to check core prerequisites.

## PI

Pi 1.0 still uses `~/.pi/agent`. Both installers symlink that entire folder to
`.pi/agent/` here. Stow skips `.pi`; `install.sh` creates this link directly.

This assumes a fresh install: **close Pi and manually move/back up the existing
agent folder before linking**. No credentials, sessions or package cache are
copied or merged.

The `pi-patty-bg-tasks` Windows workaround is retained at version **1.1.6**.
After reinstalling packages on Windows, review
[the patch instructions](.pi/agent/patches/README.md), apply the patch if needed,
and restart Pi. It is not applied automatically or required on Mac/Linux.

## Deliberate decisions

- **One repo, a `windows/` folder** rather than a second repo, so shared configs
  can't drift. Delete the folder once Windows is gone.
- **oh-my-posh is Windows-only.** It only drives the PowerShell prompt; the zsh
  side will use whatever comes over from the Mac.
- **Machine-specific git settings stay out of the repo.** Windows'
  `core.sshCommand` lives in `~/.gitconfig`, which git reads after
  `~/.config/git/config`.
- **`.stow-local-ignore`** stops stow linking repo files (`install.sh`,
  `windows/`, ...) into `$HOME`. It replaces stow's defaults, so they are repeated.
- **`install.sh` uses `--no-folding`** so stow links files, not whole
  directories, and can't swallow all of `~/.config`. Pi is an explicit
  whole-folder exception linked directly by the installer.
- **`.gitattributes` forces LF.** CRLF breaks shebangs; PowerShell reads LF fine.
  This is the opposite of the delivra repo's CRLF convention.

## macOS notes

- lazygit ignores `~/.config` on macOS unless `XDG_CONFIG_HOME="$HOME/.config"`
  is set (put it in `.zshenv`).
- An existing `~/.gitconfig` overrides `~/.config/git/config` for shared keys.
- ripgrep only reads its config through `RIPGREP_CONFIG_PATH`.

## Still outstanding
- Import `.zshrc` / `.zshenv` / tmux config from the Mac.

## Not tested
- bootstrap.ps1
- bootstrap.sh
- install.sh
