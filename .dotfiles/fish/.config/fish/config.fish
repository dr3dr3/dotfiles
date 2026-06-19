# Disable new user greeting.
set -U fish_greeting

# Set default text editor
set -gx EDITOR vim

# ── Host wiring (all guarded → no-ops inside containers / non-mac) ────────────
# Homebrew (Apple Silicon)
if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv | source
end

# fnm — host Node for CLI tooling; switches version on cd
if type -q fnm
    fnm env --use-on-cd --shell fish | source
end

# 1Password biometric SSH agent (socket exists only on the macOS host)
set -l op_sock "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if test -S "$op_sock"
    set -gx SSH_AUTH_SOCK "$op_sock"
end
set -gx OP_ACCOUNT rockofeyesoftware

# fzf (Ctrl-R / Ctrl-T / Alt-C) + zoxide (z)
if type -q fzf
    fzf --fish | source
end
if type -q zoxide
    zoxide init fish | source
end

# Canonical repo layout: ~/Code/<org-or-user>/<repo>
set -gx CODE_DIR "$HOME/Code"

# date/time
abbr -a -- ds 'date +%Y-%m-%d'
abbr -a -- ts 'date +%Y-%m-%dT%H:%M:%SZ'
abbr -a -- yyyymmdd 'date +%Y%m%d'

# git
abbr -a -- ga 'git add . '
abbr -a -- gc 'git commit -am '
abbr -a -- gco 'git checkout'
abbr -a -- gcob 'git checkout -b '
abbr -a -- gcod 'git checkout develop'
abbr -a -- gcom 'git checkout master'
abbr -a -- glog git\ log\ --Uraph\ --pretty=\'\%Cred\%h\%Creset\ -\%C\(auto\)\%d\%Creset\ \%s\ \%Cgreen\(\%ad\)\ \%C\(bold\ blue\)\<\%an\>\%Creset\'\ --date=short
abbr -a -- gpll 'git pull'
abbr -a -- gp 'git push'
abbr -a -- gclone 'git clone git@github.com:dr3dr3/'
abbr -a -- gwhoami 'echo "user.name:" (git config user.name) && echo "user.email:" (git config user.email)'

# kubernetes
# https://github.com/ahmetb/kubectl-aliases/blob/master/.kubectl_aliases
abbr -a -- k 'kubectl'
abbr -a -- kn 'kubectl config set-context --current --namespace'
abbr -a -- kge 'kubectl get events --sort-by=.lastTimestamp'
abbr -a -- kdesc 'kubectl describe'
abbr -a -- kgn 'kubectl get nodes'
abbr -a -- kgp 'kubectl get pods'
abbr -a -- kgpa 'kubectl get pods -- all-namespaces'
abbr -a -- kgs 'kubectl get services'
abbr -a -- kgd 'kubectl get deployments'

# talos
abbr -a -- t 'talosctl'
abbr -a -- tgc 'talosctl gen config'
abbr -a -- ta 'talosctl apply-config -n $TALOSIP -e $TALOSIP --talosconfig=$TALOSCONF'
abbr -a -- tl 'talosctl logs -f'
abbr -a -- tm 'talosctl dmesg -f -e $TALOSIP -n $TALOSIP'

# ── dev containers (@devcontainers/cli, booted headlessly) ───────────────────
abbr -a -- dcu 'devcontainer up --workspace-folder .'
abbr -a -- dcb 'devcontainer up --workspace-folder . --remove-existing-container'
abbr -a -- dce 'devcontainer exec --workspace-folder .'
abbr -a -- dcl 'docker compose logs -f'
abbr -a -- dps 'docker ps'
abbr -a -- lzd 'lazydocker'

# zellij (persistent sessions + layouts)
abbr -a -- zj 'zellij attach --create main'
abbr -a -- zjd 'zellij --layout dev'
abbr -a -- zjl 'zellij list-sessions'

function dcs --description 'shell into the devcontainer (TERM-safe)'
    devcontainer exec --workspace-folder . env TERM=xterm-256color bash
end
function csh --description 'shell into a running container by name fragment'
    set -l c (docker ps --format '{{.Names}}' | string match -r -- "$argv[1]" | head -n1)
    if test -z "$c"
        echo "no running container matches: $argv[1]"; return 1
    end
    docker exec -it -e TERM=xterm-256color $c bash 2>/dev/null
    or docker exec -it -e TERM=xterm-256color $c sh
end

# ── AI agents (run inside the project container; nothing on the host) ─────────
function _dcx
    devcontainer exec --workspace-folder . env TERM=xterm-256color $argv
end
function ccp --description 'Claude Code (personal) in the container'; _dcx claude $argv; end
function cca --description 'Claude Code (corporate-API) in the container'; _dcx env CLAUDE_CONFIG_DIR="$HOME/.claude-corp" claude $argv; end
function cc  --description 'Claude Code (defaults to personal)'; ccp $argv; end
function cx  --description 'Codex in the container'; _dcx codex $argv; end
function pi  --description 'Pi Harness in the container'; _dcx pi $argv; end

# ── Ollama (host-native; fallback only) ──────────────────────────────────────
abbr -a -- oll 'ollama list'
abbr -a -- olp 'ollama ps'
abbr -a -- olr 'ollama run'
abbr -a -- olu 'ollama pull'
abbr -a -- olrm 'ollama rm'

# ── JIT editor — always the multi-root workspace, never `code .` ─────────────
abbr -a -- roe 'code roe-local-dev.code-workspace'
abbr -a -- zoe 'zed roe-local-dev.code-workspace'

# ── modern CLI (interactive) ─────────────────────────────────────────────────
alias ls 'eza --group-directories-first'
alias ll 'eza -lah --group-directories-first --git'
alias lt 'eza --tree --level=2 --group-directories-first'
alias lg 'lazygit'

# ── repos: ~/Code/<org>/<repo> helpers ───────────────────────────────────────
function clone --description 'clone <org>/<repo> into ~/Code and cd in'
    if test -z "$argv[1]"
        echo "usage: clone <org>/<repo> [git-host]"; return 1
    end
    set -l host github.com
    test -n "$argv[2]"; and set host $argv[2]
    set -l dest "$CODE_DIR/$argv[1]"
    if test -d "$dest/.git"
        echo "exists → $dest"; cd "$dest"; return
    end
    git clone "git@$host:$argv[1].git" "$dest"; and cd "$dest"
end
function cdc --description 'cd into ~/Code[/<org>/<repo>]'
    cd "$CODE_DIR/$argv[1]"
end

# ── host maintenance ─────────────────────────────────────────────────────────
abbr -a -- upd '~/Code/dr3dr3/dotfiles/update-mac.sh'
abbr -a -- brewdump 'brew bundle dump --file=~/Code/dr3dr3/dotfiles/Brewfile --force'

starship init fish | source