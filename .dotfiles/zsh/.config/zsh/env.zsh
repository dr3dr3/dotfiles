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

# --- Homebrew Bundle ---------------------------------------------------------
# Make the dotfiles Brewfile the default target for every `brew bundle`
# subcommand, from any directory — so `brew bundle`, `brew bundle check` and
# `brew bundle cleanup` all act on the repo's declared package set without
# needing --file. Lookup order is: --file flag > this var > ./Brewfile.
# NOTE: because this wins over a ./Brewfile in the current directory, a
# per-project Brewfile elsewhere would be ignored — pass --file explicitly for
# those. bootstrap-mac.sh / update-mac.sh are unaffected (they pass --file).
export HOMEBREW_BUNDLE_FILE="$HOME/Code/dr3dr3/dotfiles/Brewfile"
