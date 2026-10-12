#!/usr/bin/env bash
# Install the toolchain these dotfiles assume, on macOS (Homebrew), Arch (pacman),
# Fedora (dnf) or Debian/Ubuntu (apt, i.e. WSL).
#
# Two layers:
#   1. System packages: git, zsh + plugins, stow, tmux, compilers, Ghostty.
#   2. mise (https://mise.jdx.dev): the shared CLI toolchain listed in
#      .config/mise/config.toml - neovim, ripgrep, fzf, lazygit, delta, fd, bat,
#      zoxide, oh-my-posh, node, markdownlint-cli2 and Pi. Same versions on every OS.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. System packages ------------------------------------------------------

if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Install Homebrew first: https://brew.sh" >&2
    exit 1
  fi
  # Apple's Command Line Tools provide make and the clang C compiler.
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Install Apple's Command Line Tools: xcode-select --install" >&2
    echo "Once installation finishes, rerun ./bootstrap.sh." >&2
    exit 1
  fi
  brew install git stow tmux mise zsh-autosuggestions zsh-syntax-highlighting
  brew install --cask ghostty

elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm \
    zsh git stow tmux curl unzip base-devel mise \
    zsh-autosuggestions zsh-syntax-highlighting

elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y \
    zsh git stow tmux curl unzip gcc make \
    zsh-autosuggestions zsh-syntax-highlighting

elif command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y zsh git stow tmux curl unzip build-essential \
    zsh-autosuggestions zsh-syntax-highlighting

else
  echo "Unsupported platform. Install manually: git zsh stow tmux zsh-autosuggestions zsh-syntax-highlighting make, a C compiler and mise" >&2
  exit 1
fi

# --- 2. mise toolchain -------------------------------------------------------

# Homebrew and pacman install mise above; elsewhere use the official installer,
# which puts a single binary in ~/.local/bin and does not edit shell rc files.
if ! command -v mise >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/mise" ]]; then
  echo
  echo "Installing mise into ~/.local/bin"
  (
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://mise.run -o "$installer"
    sh "$installer"
  )
fi
export PATH="$HOME/.local/bin:$PATH"

# install.sh links the config into ~/.config/mise later; read it from the repo
# now so this script can run first. Missing tools are installed, existing kept.
echo
echo "Installing the mise toolchain (.config/mise/config.toml)"
export MISE_GLOBAL_CONFIG_FILE="$DOTFILES/.config/mise/config.toml"
mise install

# Neovim's local npm dependencies (Tree-sitter CLI), using mise's node.
echo
echo "Installing Neovim npm dependencies (.config/nvim/package-lock.json)"
mise exec -- npm ci --prefix "$DOTFILES/.config/nvim"

# Hack Nerd Font, via the mise-installed oh-my-posh. WSL uses the Windows font.
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  echo
  echo "WSL: install Hack Nerd Font on Windows (bootstrap.ps1), not here."
else
  if [[ "$(uname -s)" == "Darwin" ]]; then
    have_font() { [[ -e "$HOME/Library/Fonts/HackNerdFontMono-Regular.ttf" || -e /Library/Fonts/HackNerdFontMono-Regular.ttf ]]; }
  else
    have_font() { fc-list 2>/dev/null | grep -q 'HackNerdFontMono-Regular'; }
  fi
  if ! have_font; then
    echo
    echo "Installing Hack Nerd Font"
    mise exec -- oh-my-posh font install Hack --plain
    if command -v fc-cache >/dev/null 2>&1; then fc-cache -f; fi
  fi
fi
unset MISE_GLOBAL_CONFIG_FILE

echo
echo "Next: ./install.sh, then open a new zsh (it runs 'mise activate')."
if [[ "$(basename "${SHELL:-}")" != "zsh" ]]; then
  echo "Then make zsh your login shell:  chsh -s \$(command -v zsh)"
fi
echo "Update tools later with: mise upgrade"
