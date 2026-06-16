# =============================================================================
# ~/.zshrc — managed by dotfiles (stow package: zsh)
# Terminal-first macOS dev shell (Apple Silicon).
# =============================================================================

# --- Homebrew (Apple Silicon prefix) -----------------------------------------
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- Editor ------------------------------------------------------------------
export EDITOR="vim"
export VISUAL="$EDITOR"

# --- fnm (host Node for CLI tooling only; app runtimes live in containers) ----
# --use-on-cd switches Node version when entering a dir with .node-version/.nvmrc
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# --- 1Password SSH agent ------------------------------------------------------
# The desktop app exposes a biometric SSH agent socket. Point SSH at it instead
# of hand-managing keys. Enable in 1Password ▸ Settings ▸ Developer ▸ "Use the
# SSH agent". No custom key-injection functions — that's the whole point.
_OP_SSH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$_OP_SSH_SOCK" ]]; then
  export SSH_AUTH_SOCK="$_OP_SSH_SOCK"
fi

# --- 1Password CLI / varlock context -----------------------------------------
# varlock resolves op:// references at run time (see agents.zsh). Telling op
# which account to use avoids interactive account prompts.
export OP_ACCOUNT="rockofeyesoftware"

# --- History -----------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS INC_APPEND_HISTORY

# --- Completion --------------------------------------------------------------
autoload -Uz compinit && compinit -d "$HOME/.zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # case-insensitive

# --- Sourced config (kept out of this file for clarity) ----------------------
for _f in "$HOME"/.config/zsh/*.zsh; do
  [[ -r "$_f" ]] && source "$_f"
done
unset _f

# --- fzf (fuzzy finder: Ctrl-R history, Ctrl-T files, Alt-C cd) ---------------
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# --- zoxide (smarter cd: `z <partial>` jumps to frequent dirs) ---------------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# --- Prompt (shared starship config with the dev containers) -----------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
