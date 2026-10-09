# Read by every zsh (login, interactive, scripts). Keep it tiny: only locations.
# PATH lives in .zshrc, because macOS's /etc/zprofile reorders PATH after this file.
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Everything else zsh reads lives in ~/.config/zsh.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# ripgrep only reads a config file named by this variable.
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/ripgreprc"
