# =============================================================================
# ~/.config/zsh/agents.zsh — host-side launchers for the in-container AI agents
# (sourced by ~/.zshrc)
#
# The agents themselves do NOT run on this host. They are installed *inside* the
# dev containers by dotai (github.com/dr3dr3/dotai) for isolation/safety. These
# wrappers just `devcontainer exec` into the current project's container and
# start the agent there. Secrets resolve in-container via the mounted 1Password
# agent.sock + varlock (also provisioned by dotai) — nothing touches the host.
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
