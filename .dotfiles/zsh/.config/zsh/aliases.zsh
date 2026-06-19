# =============================================================================
# ~/.config/zsh/aliases.zsh — short shortcuts for the daily loop
# (sourced by ~/.zshrc). Agent-launch lives in agents.zsh.
# =============================================================================

# --- Dev containers (@devcontainers/cli, booted headlessly) ------------------
# Always operate on the current folder as the workspace. These boot the
# docker-compose devcontainer stack without VS Code (customizations.vscode is
# ignored by the CLI — agents lean on the prebuilt graphify codegraph instead).
alias dcu='devcontainer up --workspace-folder .'                          # bring stack up
alias dcb='devcontainer up --workspace-folder . --remove-existing-container'  # rebuild fresh
alias dce='devcontainer exec --workspace-folder .'                        # exec: dce <cmd>
# Drop into a container shell. TERM is forced to a value every container's
# terminfo knows — Ghostty advertises xterm-ghostty, which bare images lack and
# which makes clear/tput/TUIs error. (Proper fix: install the terminfo — see the
# cheat-sheet.)
alias dcs='devcontainer exec --workspace-folder . env TERM=xterm-256color bash'

# Shell into an arbitrary running container by name fragment (via OrbStack):
#   csh mysql   →  exec bash in the first container matching "mysql"
csh() {
  local c
  c="$(docker ps --format '{{.Names}}' | grep -m1 "${1:?usage: csh <name-fragment>}")" \
    || { echo "no running container matches: $1"; return 1; }
  docker exec -it -e TERM=xterm-256color "$c" bash 2>/dev/null \
    || docker exec -it -e TERM=xterm-256color "$c" sh
}

# --- OrbStack / containers ---------------------------------------------------
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dco='docker compose'
alias dcl='docker compose logs -f'                                       # tail stack logs
alias lzd='lazydocker'                                                    # container TUI
alias orb='orbstack'                                                      # `orb start|stop|status`

# --- zellij (persistent sessions + layouts) ----------------------------------
alias zj='zellij attach --create main'   # everyday persistent session
alias zjd='zellij --layout dev'          # 2x2 host/container/agent/logs workspace
alias zjl='zellij list-sessions'

# --- JIT editor — ALWAYS the multi-root workspace, never `code .` ------------
# Bare `code .` breaks per-repo Laravel Extra Intellisense routing in the
# Rock of Eye /workspace umbrella. Open the workspace file from /workspace.
alias roe='code roe-local-dev.code-workspace'
alias zoe='zed roe-local-dev.code-workspace'

# --- Ollama (fallback/transient local LLM — see memory budget caveat) --------
alias oll='ollama list'      # installed models
alias olp='ollama ps'        # what's resident in memory right now
alias olr='ollama run'       # olr qwen2.5-coder:32b
alias olu='ollama pull'      # olu qwen2.5-coder:32b
alias olrm='ollama rm'       # free unified memory: olrm <model>

# --- git (carried over from the fish config, zsh-flavoured) ------------------
alias ga='git add .'
alias gc='git commit -am'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gp='git push'
alias gpll='git pull'
alias gs='git status -sb'
alias glog="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' --date=short"
# (to clone, prefer the `clone` function above — it enforces ~/Code/<org>/<repo>)
alias gwhoami='echo "user.name: $(git config user.name)"; echo "user.email: $(git config user.email)"'

# --- modern CLI replacements (interactive only) ------------------------------
alias ls='eza --group-directories-first'
alias ll='eza -lah --group-directories-first --git'
alias lt='eza --tree --level=2 --group-directories-first'
alias cat='bat --paging=never'
alias lg='lazygit'

# --- repos: canonical ~/Code/<org-or-user>/<repo> layout ---------------------
export CODE_DIR="$HOME/Code"
# Clone into ~/Code/<org>/<repo> and cd in.  Usage: clone dr3dr3/dotfiles
#   (defaults to github.com + SSH; pass a host as 2nd arg for other forges)
clone() {
  local slug="${1:?usage: clone <org>/<repo> [git-host]}"
  local host="${2:-github.com}"
  local dest="$CODE_DIR/$slug"
  if [[ -d "$dest/.git" ]]; then echo "exists → $dest"; cd "$dest"; return; fi
  git clone "git@${host}:${slug}.git" "$dest" && cd "$dest"
}
# Jump to a repo dir: cdc dr3dr3/dotfiles  (or `cdc` for ~/Code)
cdc() { cd "$CODE_DIR/${1:-}"; }

# --- host maintenance (see update-mac.sh + docs/CHEATSHEET.md) ----------------
alias upd='~/Code/dr3dr3/dotfiles/update-mac.sh'    # update + audit the host
alias brewdump="brew bundle dump --file=~/Code/dr3dr3/dotfiles/Brewfile --force"  # snapshot installs

# --- date/time ---------------------------------------------------------------
alias ds='date +%Y-%m-%d'
alias ts='date +%Y-%m-%dT%H:%M:%SZ'
