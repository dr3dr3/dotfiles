# =============================================================================
# ~/.config/zsh/env.zsh — host environment variables (stow package: zsh)
# Auto-sourced by ~/.zshrc for every interactive zsh (see the *.zsh drop-in loop).
# Non-secret, durable vars only — keep secrets in 1Password (op:// refs / varlock),
# not here.
# =============================================================================

# --- Ollama ------------------------------------------------------------------
# Bind the host Ollama server to all interfaces so in-container agents can reach
# it via host.docker.internal:11434 (OrbStack maps it). This export applies ONLY
# when you start the server from a shell — e.g. `ollama serve` in a pane.
#
# For the launchd-managed (`brew services`) server this export does nothing, and
# neither does prefixing the var to `brew services restart` — brew services does
# not propagate arbitrary shell env into the plist it generates. Verified
# 2026-09-03: the plist carried only the formula's own OLLAMA_FLASH_ATTENTION /
# OLLAMA_KV_CACHE_TYPE, and the running server was bound to 127.0.0.1 (i.e.
# unreachable from containers). Use the `o-up` alias in aliases.zsh instead — it
# sets the var on the launchd session before restarting the service.
# That is NOT persistent across reboot: rerun `o-up` after a boot, and confirm
# the bind address with:  lsof -nP -iTCP -sTCP:LISTEN | grep 11434
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

# --- ~/.local/bin on PATH ----------------------------------------------------
# Standard user-binary dir. Things that install here: the Unsloth Studio CLI
# (dropped by Unsloth Desktop's installer), plus pipx / uv / pip --user shims.
# Declared here deliberately: Unsloth's install.sh appends its own
# `export PATH=...` line to ~/.zshrc, and because the zsh package is a folded
# stow symlink that edit lands in the tracked repo file. Its fish equivalent
# hardcoded an absolute /Users/<name>/ path. Owning it here keeps the three
# shells in parity and keeps machine-specific paths out of git — if an
# installer re-adds its own line, revert it; this covers it.
# Guarded so nested interactive shells don't duplicate the entry.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
