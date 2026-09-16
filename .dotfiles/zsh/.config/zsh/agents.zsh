# =============================================================================
# ~/.config/zsh/agents.zsh — host-side launchers for the in-container AI agents
# (sourced by ~/.zshrc)
#
# These wrappers run the agents INSIDE the project's dev container, which is the
# default for any real project work: dotai (github.com/dr3dr3/dotai) installs
# them there, and `devcontainer exec` starts them in the current project's
# container. Secrets resolve in-container via the mounted 1Password agent.sock +
# varlock (also provisioned by dotai) — nothing touches the host.
#
# Host copies of claude/codex/herdr are also installed (see Brewfile) for the
# times there is no container to work in. The names don't collide: bare `claude`
# / `codex` are the host binaries; the wrappers below are the container ones.
#
# TERM is forced to a value the container's terminfo knows (Ghostty advertises
# xterm-ghostty, which bare images lack) so the agents' TUIs render correctly.
# =============================================================================

_dcx() { devcontainer exec --workspace-folder . env TERM=xterm-256color "$@"; }

# --- Claude Code (primary) ---------------------------------------------------
# Two profiles, swapped via CLAUDE_CONFIG_DIR inside the container so personal-sub
# and corporate-API auth/state never collide:
#   ccp → personal (Claude subscription, container's default ~/.claude)
#   cca → corporate (Anthropic API; key resolved in-container from 1Password)
#   cc  → defaults to personal
ccp() { _dcx claude "$@"; }
cca() { _dcx env CLAUDE_CONFIG_DIR="$HOME/.claude-corp" claude "$@"; }
alias cc='ccp'

# --- Codex CLI (secondary) ---------------------------------------------------
cx() { _dcx codex "$@"; }

# --- Pi Harness (lightweight; hooks local Ollama on the host) ----------------
# Ollama runs natively on the host; from inside the container Pi reaches it at
# host.docker.internal:11434 (OrbStack maps it). dotai sets OLLAMA_HOST for this.
pi() { _dcx pi "$@"; }

# --- Pi on the LOCAL model (host Ollama) -------------------------------------
# `pi --list-models` shows the local Ollama models and the hosted gateway models
# in ONE flat list, with nothing marking which is which. `pil` is the local path
# your fingers learn, so a billed gateway model is never one tab-complete away.
# --thinking off maps to reasoning_effort=none (verified: zero reasoning tokens)
# and is the right default for tool-heavy turns.
pil() { _dcx pi --provider ollama --model "$PI_LOCAL_MODEL" --thinking off "$@"; }

# Preload the model so the first real turn does not pay the cold load. Worth it
# before a batch; pointless otherwise (it unloads again after OLLAMA_KEEP_ALIVE).
piw() {
  printf 'warming %s… ' "$PI_LOCAL_MODEL"
  curl -fsS http://127.0.0.1:11434/api/generate \
    -d "{\"model\":\"$PI_LOCAL_MODEL\",\"prompt\":\"hi\",\"stream\":false}" \
    >/dev/null && echo "resident (olp to confirm)" || echo "FAILED — is ollama up?"
}
# Unattended batches run through `pi-batch` (.dotfiles/bin), not an alias here:
# it needs caffeinate, an isolated branch, a refuse-to-push hook and a test gate.
