# =============================================================================
# ~/.config/zsh/env.zsh — host environment variables (stow package: zsh)
# Auto-sourced by ~/.zshrc for every interactive zsh (see the *.zsh drop-in loop).
# Non-secret, durable vars only — keep secrets in 1Password (op:// refs / varlock),
# not here.
# =============================================================================

# --- Ollama ------------------------------------------------------------------
# Deliberately NOT setting OLLAMA_HOST here. Ollama's default bind — 127.0.0.1
# — is both sufficient and the safer choice on this host.
#
# This file used to `export OLLAMA_HOST=0.0.0.0:11434` on the belief that
# containers could not otherwise reach the server. That belief was wrong under
# OrbStack. Verified 2026-09-14 with the server bound to 127.0.0.1 ONLY (nothing
# wildcard-bound, confirmed via lsof):
#   * a fresh `docker run alpine` on the default bridge, with no ExtraHosts,
#     reached http://host.docker.internal:11434/api/version
#   * roe-devcontainer ran a full /v1/chat/completions inference through it
#   * this host's own LAN address refused the connection
#     (re-check with: curl "http://$(ipconfig getifaddr en0):11434/api/version")
# OrbStack forwards host.docker.internal to the host's loopback on purpose —
# docs.orbstack.dev/docker/network. So binding 0.0.0.0 bought nothing except
# exposing a no-auth inference server to every device on the network.
#
# Note OLLAMA_HOST is dual-purpose: it is the server's bind address AND the
# CLI's connect address. Leaving it unset points the CLI at 127.0.0.1:11434,
# which is exactly where the server is.
#
# Need the wide bind anyway — Docker Desktop (its sandbox blocks host-loopback
# access), a second machine, a VM? `o-expose` in aliases.zsh does it explicitly.
# See SETUP.md ("Local LLM — Ollama").

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
