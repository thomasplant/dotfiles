#!/usr/bin/env bash
# Symlink this repo into $HOME with GNU Stow.
#   ./install.sh          link everything
#   ./install.sh --dry    show what would happen, change nothing
#   ./install.sh --undo   remove the symlinks
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

if ! command -v stow >/dev/null 2>&1; then
  echo "stow is not installed. Run ./bootstrap.sh first." >&2
  exit 1
fi

# --no-folding links individual FILES and creates real directories, instead of
# symlinking a whole directory when the target does not exist yet. This keeps
# ~/.config a real directory so other applications can safely write there.
STOW_ARGS=(--target="$HOME" --no-folding --verbose)

case "${1:-}" in
  --dry)  STOW_ARGS+=(--simulate); ACTION=(--stow) ;;
  --undo) ACTION=(--delete) ;;
  "")     ACTION=(--stow) ;;
  *)      echo "usage: $0 [--dry|--undo]" >&2; exit 2 ;;
esac

# Pi needs a whole-folder link; Stow deliberately excludes .pi.
PI_SOURCE="$DOTFILES/.pi/agent"
PI_DEST="$HOME/.pi/agent"
PI_LINKED=0
if [[ -L "$PI_DEST" && "$(readlink "$PI_DEST")" == "$PI_SOURCE" ]]; then PI_LINKED=1; fi
if [[ "${1:-}" != "--undo" && "$PI_LINKED" == 0 && ( -e "$PI_DEST" || -L "$PI_DEST" ) ]]; then
  echo "Move or back up $PI_DEST before installing the Pi link." >&2
  exit 1
fi

stow "${STOW_ARGS[@]}" "${ACTION[@]}" .
case "${1:-}" in
  --dry) echo "Pi: $PI_DEST -> $PI_SOURCE (preview only)" ;;
  --undo) if [[ "$PI_LINKED" == 1 ]]; then rm "$PI_DEST"; fi ;;
  "")
    if [[ "$PI_LINKED" == 0 ]]; then
      mkdir -p "$HOME/.pi"
      ln -s "$PI_SOURCE" "$PI_DEST"
    fi
    ;;
esac

echo
echo "Done. Reminders:"
echo "  - nvim config is included in this repo at .config/nvim"
echo "  - pi config is included at .pi/agent (whole-folder link)"
echo "  - restart Pi after installation; close Pi before migrating its folder"
echo "  - set zsh as your login shell:  chsh -s \$(which zsh)"
