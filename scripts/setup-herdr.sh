#!/usr/bin/env bash
# Install Herdr and link the portable config owned by this dotfiles repo.
# Safe to run repeatedly on macOS, Linux hosts, and Linux devcontainers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_SRC="$REPO_DIR/.dotfiles/herdr/.config/herdr/config.toml"
CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml"
INSTALL_DIR="${HERDR_INSTALL_DIR:-$HOME/.local/bin}"

export PATH="$INSTALL_DIR:$PATH"

install_herdr() {
  if command -v herdr >/dev/null 2>&1; then
    printf '✓ Herdr already installed: %s\n' "$(herdr --version 2>/dev/null | head -1)"
    return
  fi

  if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    echo "→ Installing Herdr with Homebrew"
    brew install herdr
  else
    echo "→ Installing Herdr from herdr.dev"
    curl -fsSL https://herdr.dev/install.sh | sh
  fi

  if ! command -v herdr >/dev/null 2>&1; then
    echo "✗ Herdr installed but is not on PATH (expected under $INSTALL_DIR)" >&2
    return 1
  fi
  printf '✓ Herdr installed: %s\n' "$(herdr --version 2>/dev/null | head -1)"
}

link_config() {
  local backup

  [[ -f "$CONFIG_SRC" ]] || {
    echo "✗ Missing managed Herdr config: $CONFIG_SRC" >&2
    return 1
  }

  mkdir -p "$(dirname "$CONFIG_DST")"

  if [[ -L "$CONFIG_DST" ]] && [[ "$(readlink "$CONFIG_DST")" == "$CONFIG_SRC" ]]; then
    echo "✓ Herdr config already linked to dotfiles"
    return
  fi

  if [[ -e "$CONFIG_DST" || -L "$CONFIG_DST" ]]; then
    backup="${CONFIG_DST}.pre-dotfiles.$(date +%Y%m%d%H%M%S)"
    mv "$CONFIG_DST" "$backup"
    echo "→ Backed up existing Herdr config to $backup"
  fi

  ln -s "$CONFIG_SRC" "$CONFIG_DST"
  echo "✓ Herdr config linked: $CONFIG_DST → $CONFIG_SRC"
}

install_herdr
link_config

echo "✓ Herdr setup complete (prefix: Ctrl+Space; one-key host trigger: Caps Lock)"
