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

# ── ~/.local/bin ─────────────────────────────────────────────────────────────
# Unsloth Studio CLI, pipx / uv / pip --user shims. Owned here rather than left
# to installers — Unsloth's install.sh writes shell snippets with a hardcoded
# /Users/<name>/ path, and these packages are folded stow symlinks, so such
# edits land in the tracked repo.
$env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local/bin"))

# ── mise — host Node for CLI tooling (replaced fnm 2026-09-03) ───────────────
# Deliberately NOT the `mise activate nu` + vendor/autoload pattern that
# starship/zoxide use below. `mise activate nu` bakes a *literal PATH snapshot*
# into its generated script; since autoload is sourced before config.nu, each
# startup would source the previous snapshot and then regenerate from it — a
# feedback loop that can freeze a stale PATH (verified 2026-09-03).
# Prepending the shims dir is static and deterministic instead, and still honours
# per-directory pins because each shim asks mise at exec time.
# Trade-off: no mise-managed env vars / on-cd env changes — unused on this host.
if (which mise | is-not-empty) {
    $env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local/share/mise/shims"))
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
# NB: brew generates the LaunchAgent plist from the formula and ignores a
# shell-exported OLLAMA_HOST, so we set it via launchctl (the launchd-spawned
# server inherits it). Not persistent across reboot — rerun o-up after a boot.
def o-up [] { launchctl setenv OLLAMA_HOST "0.0.0.0:11434"; brew services restart ollama }
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
# Default Brewfile for every `brew bundle` subcommand, from any directory.
# Lookup order: --file flag > this var > ./Brewfile (so a per-project Brewfile
# elsewhere needs an explicit --file). The *-mac.sh scripts pass --file already.
$env.HOMEBREW_BUNDLE_FILE = ($env.HOME | path join "Code/dr3dr3/dotfiles/Brewfile")
def upd [...rest] { ^($env.HOME | path join "Code/dr3dr3/dotfiles/update-mac.sh") ...$rest }
# Scratch-file snapshot only — never dump over the tracked Brewfile (--force
# would strip its comments + optional-groups block). Prefer `brew bundle check`
# / `brew bundle cleanup` for straight drift answers.
def brewdump [] { brew bundle dump --file=/tmp/Brewfile.now --force; print "→ wrote /tmp/Brewfile.now" }
