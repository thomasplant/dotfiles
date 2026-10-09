#!/usr/bin/env bash
# Install the toolchain these dotfiles assume, on macOS (Homebrew), Arch (pacman),
# Fedora (dnf) or Debian/Ubuntu (apt, i.e. WSL). Shell plugins are deliberately NOT installed
# here - that depends on the oh-my-zsh decision and belongs with the zsh config.
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
  brew install git stow neovim ripgrep fzf lazygit git-delta fd bat tmux

elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm \
    zsh git stow neovim ripgrep fzf lazygit git-delta fd bat tmux curl unzip base-devel

elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y \
    zsh git stow neovim ripgrep fzf git-delta fd-find bat tmux curl unzip gcc make

  # lazygit needs a third-party repository; don't enable one automatically.
  echo
  echo "NOTE: install lazygit separately, using its release tarball or COPR:"
  echo "  sudo dnf copr enable dejan/lazygit"
  echo "  sudo dnf install lazygit"

elif command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y zsh git stow ripgrep fzf tmux curl unzip bat fd-find build-essential

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
  echo "Unsupported platform. Install manually: git stow neovim ripgrep fzf lazygit delta tmux make and a C compiler" >&2
  exit 1
fi

# Install Pi on Linux only; leave existing installations alone.
if [[ "$(uname -s)" == "Linux" ]] && ! command -v pi >/dev/null 2>&1; then
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
