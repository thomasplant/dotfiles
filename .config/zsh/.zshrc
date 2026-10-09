# Interactive zsh config, shared by macOS and Linux/WSL2.
# Plugins come from the system package manager (see bootstrap.sh); no framework.
# Machine-specific additions go in $ZDOTDIR/.zshrc.local (not tracked).

# --- Environment -------------------------------------------------------------

# Homebrew (macOS). Sets PATH, MANPATH and HOMEBREW_PREFIX.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

typeset -U path fpath  # no duplicate entries
path=("$HOME/bin" "$HOME/.local/bin" $path)

export EDITOR=nvim VISUAL=nvim
export MANPAGER='nvim +Man!'

# --- History -----------------------------------------------------------------

HISTFILE="$XDG_STATE_HOME/zsh/history"
[[ -d ${HISTFILE:h} ]] || mkdir -p "${HISTFILE:h}"
HISTSIZE=1000000
SAVEHIST=1000000
setopt extended_history       # save timestamps
setopt share_history          # share between open shells
setopt hist_ignore_dups hist_ignore_space hist_reduce_blanks hist_verify

# --- Options -----------------------------------------------------------------

setopt autocd                 # type a directory name to cd into it
setopt interactive_comments   # allow # comments on the command line
setopt extended_glob
unsetopt beep
stty stop undef 2>/dev/null   # Ctrl+S doesn't freeze the terminal
zle_highlight=('paste:none')  # don't highlight pasted text

# --- Completion --------------------------------------------------------------

[[ -n $HOMEBREW_PREFIX ]] && fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
autoload -Uz compinit
[[ -d $XDG_CACHE_HOME/zsh ]] || mkdir -p "$XDG_CACHE_HOME/zsh"
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
zmodload zsh/complist
_comp_options+=(globdots)                              # include dotfiles
zstyle ':completion:*' menu select                     # arrow/vim-key menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive, like PowerShell
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"

# --- Vi mode (mirrors the PowerShell PSReadLine setup) -----------------------

bindkey -v
KEYTIMEOUT=20   # 200ms: long enough for `kj`, short enough that Esc feels instant
bindkey -M viins 'kj' vi-cmd-mode
bindkey -M viins '^?' backward-delete-char   # backspace past where insert started
bindkey -M viins '^H' backward-delete-char

# Cursor shape: block in command mode, beam in insert mode.
_cursor_block() { print -n '\e[1 q' }
_cursor_beam()  { print -n '\e[5 q' }
zle-keymap-select() { [[ $KEYMAP == vicmd ]] && _cursor_block || _cursor_beam }
zle-line-init() { _cursor_beam }
zle -N zle-keymap-select
zle -N zle-line-init
autoload -Uz add-zsh-hook
add-zsh-hook preexec _cursor_beam   # programs start with a beam cursor

# History search by prefix: Up/Down in insert mode, k/j in command mode, Ctrl+P/N anywhere.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
for km in viins vicmd; do
  for key in '^[[A' '^[OA' ${terminfo[kcuu1]}; do bindkey -M $km "$key" up-line-or-beginning-search; done
  for key in '^[[B' '^[OB' ${terminfo[kcud1]}; do bindkey -M $km "$key" down-line-or-beginning-search; done
  bindkey -M $km '^P' up-line-or-beginning-search
  bindkey -M $km '^N' down-line-or-beginning-search
done
bindkey -M vicmd 'k' up-line-or-beginning-search
bindkey -M vicmd 'j' down-line-or-beginning-search

# `v` in command mode edits the line in $EDITOR; save and quit to run it.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# Vim keys in the completion menu.
bindkey -M menuselect '^h' vi-backward-char
bindkey -M menuselect '^j' vi-down-line-or-history
bindkey -M menuselect '^k' vi-up-line-or-history
bindkey -M menuselect '^l' vi-forward-char
bindkey -M menuselect '^[[Z' vi-up-line-or-history   # Shift+Tab

# Ctrl+Z on an empty line resumes the last suspended job (e.g. nvim).
_ctrl_z_fg() {
  if [[ -z $BUFFER ]]; then
    BUFFER=fg
    zle accept-line
  else
    zle push-input
    zle clear-screen
  fi
}
zle -N _ctrl_z_fg
bindkey -M viins '^Z' _ctrl_z_fg
bindkey -M vicmd '^Z' _ctrl_z_fg

# --- Aliases & functions -----------------------------------------------------

if [[ $OSTYPE == darwin* ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi
alias ll='ls -lah'
alias la='ls -A'
alias lt='ls -latr'          # newest last, like `lt` in PowerShell
alias grep='grep --color=auto'
alias g='lazygit' lg='lazygit'
alias gst='git status'
alias oc='opencode'

# nnn: `n` changes to nnn's directory on quit.
if (( $+commands[nnn] )); then
  export NNN_TRASH=1
  n() {
    [[ ${NNNLVL:-0} -eq 0 ]] || { echo "nnn is already running"; return }
    export NNN_TMPFILE="$XDG_CONFIG_HOME/nnn/.lastd"
    command nnn "$@"
    [[ -f $NNN_TMPFILE ]] && { . "$NNN_TMPFILE"; rm -f "$NNN_TMPFILE" }
  }
fi

# --- Tools -------------------------------------------------------------------

# fzf: Ctrl+T files, Ctrl+R history, Alt+C cd. `fzf --zsh` needs fzf >= 0.48;
# older distro packages ship the scripts as files instead.
if (( $+commands[fzf] )); then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    for f in /usr/share/fzf/{key-bindings,completion}.zsh \
             /usr/share/doc/fzf/examples/{key-bindings,completion}.zsh; do
      [[ -f $f ]] && source "$f"
    done
  fi
  (( $+commands[fd] )) && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git' \
                                 FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git' \
                                 FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi

(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"   # z <dir>, zi for a picker

# --- Prompt & colour mode ----------------------------------------------------

# gruvbox light/dark for the prompt (OMP_MODE) and delta (DELTA_FEATURES; under
# lazygit delta can't detect the background itself). Follows the OS setting.
set-color-mode() {
  export OMP_MODE=$1 DELTA_FEATURES="+$1-mode"
}
omp-light() { set-color-mode light }
omp-dark()  { set-color-mode dark }
sync-color-mode() {
  local mode=dark
  if [[ $OSTYPE == darwin* ]]; then
    [[ $(defaults read -g AppleInterfaceStyle 2>/dev/null) == Dark ]] || mode=light
  elif (( $+commands[reg.exe] )); then   # WSL: read the Windows app theme
    [[ $(reg.exe query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' \
         /v AppsUseLightTheme 2>/dev/null) == *0x1* ]] && mode=light
  fi
  set-color-mode $mode
}
sync-color-mode

if (( $+commands[oh-my-posh] )); then
  eval "$(oh-my-posh init zsh --config "$XDG_CONFIG_HOME/oh-my-posh/gruvbox-lean.omp.json")"
fi

# --- Plugins (order matters: syntax highlighting must be last) ---------------

_zsh_plugin() {
  local name=$1 dir
  for dir in ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share} /usr/share/zsh/plugins /usr/share; do
    [[ -f $dir/$name/$name.zsh ]] && { source "$dir/$name/$name.zsh"; return }
  done
}

_zsh_plugin zsh-autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey -M viins '^F' autosuggest-accept   # accept the whole suggestion
bindkey -M viins '^[f' forward-word        # Alt+F: accept one word
bindkey -M viins '^[[C' forward-word       # Right arrow: accept one word, like PowerShell

[[ -f $ZDOTDIR/.zshrc.local ]] && source "$ZDOTDIR/.zshrc.local"

_zsh_plugin zsh-syntax-highlighting
unfunction _zsh_plugin
