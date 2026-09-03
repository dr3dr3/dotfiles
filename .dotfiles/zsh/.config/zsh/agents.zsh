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
