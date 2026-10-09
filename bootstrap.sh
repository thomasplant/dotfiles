#!/usr/bin/env bash
# Install the toolchain these dotfiles assume, on macOS (Homebrew), Arch (pacman),
# Fedora (dnf) or Debian/Ubuntu (apt, i.e. WSL). zsh uses no framework: its plugins
# (autosuggestions, syntax highlighting, zoxide) come from the package manager.
set -euo pipefail

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
  brew install git stow neovim ripgrep fzf lazygit git-delta fd bat tmux \
    oh-my-posh zoxide zsh-autosuggestions zsh-syntax-highlighting markdownlint-cli2
  brew install --cask ghostty

elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm \
    zsh git stow neovim ripgrep fzf lazygit git-delta fd bat tmux curl unzip base-devel \
    zoxide zsh-autosuggestions zsh-syntax-highlighting

elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y \
    zsh git stow neovim ripgrep fzf git-delta fd-find bat tmux curl unzip gcc make \
    zoxide zsh-autosuggestions zsh-syntax-highlighting

  # lazygit needs a third-party repository; don't enable one automatically.
  echo
  echo "NOTE: install lazygit separately, using its release tarball or COPR:"
  echo "  sudo dnf copr enable dejan/lazygit"
  echo "  sudo dnf install lazygit"

elif command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y zsh git stow ripgrep fzf tmux curl unzip bat fd-find build-essential \
    zoxide zsh-autosuggestions zsh-syntax-highlighting

  # Debian/Ubuntu repos lag badly on these - install them properly instead.
  echo
  echo "NOTE: apt's neovim/lazygit/delta are usually too old."
  echo "  neovim    : official AppImage or the unstable PPA"
  echo "  lazygit   : release tarball from github.com/jesseduffield/lazygit"
  echo "  delta     : .deb from github.com/dandavison/delta/releases"
  # Ubuntu ships fd as fdfind and bat as batcat; give them their real names.
  mkdir -p "$HOME/.local/bin"
  if [[ -x /usr/bin/fdfind ]]; then ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"; fi
  if [[ -x /usr/bin/batcat ]]; then ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"; fi

else
  echo "Unsupported platform. Install manually: git stow neovim ripgrep fzf lazygit delta tmux zoxide oh-my-posh zsh-autosuggestions zsh-syntax-highlighting make and a C compiler" >&2
  exit 1
fi

# nvim lints Markdown with markdownlint-cli2 (lua/plugins/lint.lua). Linux repos don't
# package it, so use npm when available (macOS: brew above).
if [[ "$(uname -s)" == "Linux" ]] && ! command -v markdownlint-cli2 >/dev/null 2>&1; then
  echo
  if command -v npm >/dev/null 2>&1; then
    echo "Installing markdownlint-cli2 with npm"
    npm install --global markdownlint-cli2 \
      || echo "NOTE: npm install failed; try: sudo npm install --global markdownlint-cli2"
  else
    echo "NOTE: install Node.js, then: npm install --global markdownlint-cli2"
  fi
fi

# oh-my-posh isn't in the Linux distro repos; use its official installer (macOS: brew above).
if [[ "$(uname -s)" == "Linux" ]] && ! command -v oh-my-posh >/dev/null 2>&1; then
  echo
  echo "Installing oh-my-posh into ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  (
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://ohmyposh.dev/install.sh -o "$installer"
    bash "$installer" -d "$HOME/.local/bin"
  )
fi

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
    omp="$(command -v oh-my-posh || echo "$HOME/.local/bin/oh-my-posh")"
    "$omp" font install Hack --plain
    if command -v fc-cache >/dev/null 2>&1; then fc-cache -f; fi
  fi
fi

# Install Pi (macOS and Linux); leave existing installations alone.
if command -v pi >/dev/null 2>&1; then
  echo
  echo "Pi already installed: $(command -v pi)"
else
  echo
  echo "Installing Pi using the official installer (may offer to install Node.js/npm)."
  echo "Decline 'Start pi now' until you have run ./install.sh."
  (
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://pi.dev/install.sh -o "$installer"
    # Keep the managed install in the repo, ready for the later agent symlink.
    PI_CODING_AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.pi/agent" sh "$installer"
  )
fi

echo
echo "Next: ./install.sh"
if [[ "$(basename "${SHELL:-}")" != "zsh" ]]; then
  echo "Then make zsh your login shell:  chsh -s \$(command -v zsh)"
fi
