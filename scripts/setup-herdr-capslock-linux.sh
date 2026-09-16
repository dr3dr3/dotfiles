#!/usr/bin/env bash
# Opt-in Linux host remap: Caps Lock emits Ctrl+Alt+Space for Herdr.
# Do not run this inside a devcontainer; keyboard remapping belongs on the host.

set -euo pipefail

if [[ -f /.dockerenv || -n "${container:-}" ]]; then
  echo "✗ Run this on the Linux host, not inside a container." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/../config/keyd/herdr-prefix.conf"
TARGET="/etc/keyd/herdr-prefix.conf"

if ! command -v keyd >/dev/null 2>&1; then
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed keyd
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y keyd
  else
    echo "✗ keyd is required; install it with your system package manager." >&2
    exit 1
  fi
fi

sudo install -D -m 0644 "$SOURCE" "$TARGET"
# restart rather than enable --now + reload: on a first install the daemon has
# not created /var/run/keyd.socket yet when `keyd reload` runs, so the reload
# fails and the script exits non-zero even though the remap is active. A
# restart both starts a fresh service and re-reads the config on a running one.
sudo systemctl enable keyd
sudo systemctl restart keyd

echo "✓ Caps Lock now sends Ctrl+Alt+Space on this Linux host."
echo "  This replaces Omarchy's Caps Lock compose/emoji sequences."
