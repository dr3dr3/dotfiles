# =============================================================================
# ~/.config/zsh/env.zsh — host environment variables (stow package: zsh)
# Auto-sourced by ~/.zshrc for every interactive zsh (see the *.zsh drop-in loop).
# Non-secret, durable vars only — keep secrets in 1Password (op:// refs / varlock),
# not here.
# =============================================================================

# --- Ollama ------------------------------------------------------------------
# Bind the host Ollama server to all interfaces so in-container agents can reach
# it via host.docker.internal:11434 (OrbStack maps it). This applies when you
# start the server from a shell — e.g. `ollama serve` in a pane.
# NOTE: the launchd-managed `brew services` server does NOT inherit this shell
# env; for that route set it on the service instead:
#   OLLAMA_HOST=0.0.0.0:11434 brew services restart ollama
# See SETUP.md ("Local LLM — Ollama").
export OLLAMA_HOST=0.0.0.0:11434
