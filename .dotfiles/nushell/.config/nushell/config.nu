# =============================================================================
# config.nu — Nushell config (stow package: nushell)
# Host wiring mirrors zsh/fish, all guarded so it's a no-op inside containers.
# =============================================================================

$env.config.buffer_editor = "vim"
$env.config.show_banner = false

# ── Homebrew (Apple Silicon) ─────────────────────────────────────────────────
# brew shellenv emits POSIX syntax, so set the paths directly. PATH is a list
# in config.nu (env conversions already applied), hence prepend.
if ("/opt/homebrew/bin/brew" | path exists) {
    $env.PATH = ($env.PATH | prepend ["/opt/homebrew/bin" "/opt/homebrew/sbin"])
}

# ── fnm — host Node for CLI tooling ──────────────────────────────────────────
# Loads fnm's env + puts the default Node on PATH. Auto-switch-on-cd is wired as
# a defensive PWD hook below (fnm ships no first-class Nushell hook).
if (which fnm | is-not-empty) {
    ^fnm env --json | from json | load-env
    $env.PATH = ($env.PATH | prepend ($env.FNM_MULTISHELL_PATH | path join "bin"))
    $env.config.hooks.env_change.PWD = (
        $env.config.hooks.env_change.PWD? | default []
        | append {|| if ([.nvmrc .node-version] | any {|f| $f | path exists }) {
            try { ^fnm use --silent-if-unchanged }
        } }
    )
}

# ── 1Password biometric SSH agent (macOS host only) ──────────────────────────
let op_sock = ($env.HOME | path join "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock")
if ($op_sock | path exists) { $env.SSH_AUTH_SOCK = $op_sock }
$env.OP_ACCOUNT = "rockofeyesoftware"

# ── Canonical repo layout: ~/Code/<org-or-user>/<repo> ───────────────────────
$env.CODE_DIR = ($env.HOME | path join "Code")

# ── Prompt + zoxide (saved to the autoload dir, like starship) ───────────────
# NOTE: fzf ships no native Nushell key-bindings; the `fzf` binary still works
# when called explicitly, and zoxide's `zi` covers interactive dir-jumping.
mkdir ($nu.data-dir | path join "vendor/autoload")
^starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
if (which zoxide | is-not-empty) {
    ^zoxide init nushell | save -f ($nu.data-dir | path join "vendor/autoload/zoxide.nu")
}

# ── Aliases / commands ───────────────────────────────────────────────────────
# kubernetes
alias k = kubectl

# dev containers
alias dcu = devcontainer up --workspace-folder .
alias dcb = devcontainer up --workspace-folder . --remove-existing-container
def --wrapped dce [...rest] { devcontainer exec --workspace-folder . ...$rest }
def dcs [] { devcontainer exec --workspace-folder . env TERM=xterm-256color bash }
alias dcl = docker compose logs -f
alias dps = docker ps
alias lzd = lazydocker

# zellij (persistent sessions + layouts)
alias zj = zellij attach --create main
alias zjd = zellij --layout dev
alias zjl = zellij list-sessions

# AI agents — run inside the project container (nothing on the host)
def --wrapped ccp [...rest] { devcontainer exec --workspace-folder . env TERM=xterm-256color claude ...$rest }
def --wrapped cca [...rest] { devcontainer exec --workspace-folder . env TERM=xterm-256color $"CLAUDE_CONFIG_DIR=($env.HOME)/.claude-corp" claude ...$rest }
alias cc = ccp
def --wrapped cx [...rest] { devcontainer exec --workspace-folder . env TERM=xterm-256color codex ...$rest }
def --wrapped pi [...rest] { devcontainer exec --workspace-folder . env TERM=xterm-256color pi ...$rest }

# Ollama (host-native; fallback only)
alias oll = ollama list
alias olp = ollama ps
def --wrapped olr [...rest] { ollama run ...$rest }
def --wrapped olu [...rest] { ollama pull ...$rest }
def --wrapped olrm [...rest] { ollama rm ...$rest }
# Server lifecycle (brew formula): o-up binds 0.0.0.0:11434 so in-container
# agents reach it via host.docker.internal; o-down stops it and frees memory.
def o-up [] { with-env {OLLAMA_HOST: "0.0.0.0:11434"} { brew services restart ollama } }
alias o-down = brew services stop ollama

# JIT editor — always the multi-root workspace, never `code .`
alias roe = code roe-local-dev.code-workspace

# repos: ~/Code/<org>/<repo> helpers
def --env clone [slug: string, host: string = "github.com"] {
    let dest = ($env.CODE_DIR | path join $slug)
    if ($dest | path join ".git" | path exists) {
        print $"exists → ($dest)"; cd $dest; return
    }
    git clone $"git@($host):($slug).git" $dest
    cd $dest
}
def --env cdc [repo?: string] { cd ($env.CODE_DIR | path join ($repo | default "")) }

# host maintenance
def upd [...rest] { ^($env.HOME | path join "Code/dr3dr3/dotfiles/update-mac.sh") ...$rest }
def brewdump [] { brew bundle dump --file=($env.HOME | path join "Code/dr3dr3/dotfiles/Brewfile") --force }
