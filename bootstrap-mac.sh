#!/usr/bin/env bash
# =============================================================================
# bootstrap-mac.sh — set up a fresh macOS (Apple Silicon) dev machine.
#
# Idempotent: safe to re-run. It will
#   1. install Homebrew (if missing)
#   2. install everything in ./Brewfile
#   3. stow the macOS dotfiles (zsh, ghostty, starship) into ~
#   4. set up host Node via mise + install @devcontainers/cli (npm-only)
#   5. print the manual follow-up steps that can't be automated
#
# It deliberately does NOT install AI agent CLIs on the host — those run inside
# the dev containers (provisioned by dotai). This box only boots them.
#
# Usage:
#   git clone https://github.com/dr3dr3/dotfiles.git ~/Code/dr3dr3/dotfiles
#   cd ~/Code/dr3dr3/dotfiles && ./bootstrap-mac.sh
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$REPO_DIR/.dotfiles"
# macOS host packages. zsh is the wired-up default; fish + nushell are alt
# drivers with the same host wiring. (vim stays container-only.)
STOW_PACKAGES=(zsh ghostty starship fish nushell zellij)

# --- pretty logging ----------------------------------------------------------
info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m  !\033[0m %s\n' "$*"; }

# --- 0. sanity ---------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  warn "This script targets macOS. Use install.sh for Linux dev containers."
  exit 1
fi

# --- 1. Homebrew -------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  ok "Homebrew already installed."
fi
# Load brew into THIS shell (Apple Silicon prefix) so the rest of the script works.
eval "$(/opt/homebrew/bin/brew shellenv)"

# --- 2. Brewfile -------------------------------------------------------------
info "Installing Brewfile packages (brew bundle)…"
brew bundle --file="$REPO_DIR/Brewfile"
ok "Brewfile applied."

# --- 3. Dotfiles via GNU Stow ------------------------------------------------
info "Stowing dotfiles: ${STOW_PACKAGES[*]}"
cd "$STOW_DIR"
# Re-link idempotently. Plain --restow is a no-op on re-runs (targets are already
# our own symlinks). If a NON-stow file pre-exists at a target — e.g. an app wrote
# a default config before bootstrap ran — stow refuses rather than overwriting it.
# We deliberately do NOT use --adopt: adopt would move that stray file INTO the repo,
# silently clobbering the tracked version. Surface the conflict and let the user decide.
if ! stow --restow --target "$HOME" "${STOW_PACKAGES[@]}"; then
  warn "Stow conflict: real (non-symlink) files already exist at one or more targets above."
  warn "Back them up and remove them, then re-run ./bootstrap-mac.sh."
  warn "(To intentionally absorb a stray file into the repo: stow --adopt --target \"$HOME\" <pkg>, then review 'git status'.)"
  exit 1
fi
cd "$REPO_DIR"
ok "Dotfiles linked into ~."

# --- 3b. Host folders --------------------------------------------------------
# ~/Code/<org-or-user>/<repo> — canonical layout for all cloned repos
#   (e.g. ~/Code/dr3dr3/dotfiles, ~/Code/rock-of-eye/ai-context).
# ~/host-share — bind-mounted read-write into the dev containers at /host.
#   Create it so the bind mount has a real source (otherwise Docker would
#   create a root-owned dir in its place).
mkdir -p "$HOME/Code" "$HOME/host-share"
ok "~/Code and ~/host-share ready."

# --- 4. Host Node (mise) + @devcontainers/cli (npm-only) ---------------------
info "Setting up host Node via mise (CLI tooling only)…"
# Pin the global Node to the current LTS line. Idempotent: re-running re-resolves
# `lts` and rewrites ~/.config/mise/config.toml. Replaced fnm on 2026-09-03.
mise use --global node@lts
# `mise activate` hooks an interactive prompt, which does nothing in a script —
# so put mise's shims on PATH to make node/npm resolvable for the steps below.
export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"

if ! command -v devcontainer >/dev/null 2>&1; then
  info "Installing @devcontainers/cli (npm global)…"
  npm install -g @devcontainers/cli
else
  ok "@devcontainers/cli already installed."
fi

# --- 5. Manual follow-ups (can't / shouldn't be automated) -------------------
cat <<'EOF'

────────────────────────────────────────────────────────────────────────────
✅ Bootstrap complete. A few one-time manual steps remain:

  1Password
    • Open the 1Password app and sign in.
    • Settings ▸ Developer ▸ enable "Use the SSH agent" and
      "Integrate with 1Password CLI" (biometric unlock for `op`).
    • New shells then pick up SSH_AUTH_SOCK automatically (see ~/.zshrc).

  AI agents (run inside the containers, not here)
    • Provision them per project with dotai:
        git clone https://github.com/dr3dr3/dotai.git /workspace/.ai/dotai
        bash /workspace/.ai/dotai/setup.sh      # inside the devcontainer
    • Then launch from the host with `cc` / `cx` / `pi` (devcontainer exec).

  Ghostty
    • Set Ghostty as your default terminal; the config is already linked.
    • Install a Nerd Font if missing:  brew install --cask font-jetbrains-mono-nerd-font

  Default shell
    • If not already zsh:  chsh -s /bin/zsh

  OrbStack
    • Launch once to grant privileges; `docker`/`docker compose` then just work
      against the Rock of Eye devcontainer stack (no compose changes needed).

  Stay current (optional, recommended)
    • Run `./update-mac.sh` weekly (aliased to `upd`), or automate background
      Homebrew upgrades:
        brew trust domt4/autoupdate   # tap comes from the Brewfile; brew
                                      # refuses to load the command untrusted
        brew autoupdate start 86400 --upgrade --cleanup --enable-notification
    • Full command + maintenance reference: docs/CHEATSHEET.md
────────────────────────────────────────────────────────────────────────────
EOF
