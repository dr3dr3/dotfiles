#!/usr/bin/env bash
# Opt-in Linux host remap: the Forward button on the MX Ergo S and MX Vertical
# emits Enter. Do not run this inside a devcontainer; input remapping belongs
# on the host. See docs/LOGITECH-MICE.md for why this is keyd and not Solaar.

set -euo pipefail

if [[ -f /.dockerenv || -n "${container:-}" ]]; then
  echo "✗ Run this on the Linux host, not inside a container." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAGMENTS=(mx-ergo-s.conf mx-vertical.conf)

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

for f in "${FRAGMENTS[@]}"; do
  sudo install -D -m 0644 "$SCRIPT_DIR/../config/keyd/$f" "/etc/keyd/$f"
done
# restart, not `keyd reload`: reload was observed to leave the running daemon on
# the old bindings (see setup-herdr-capslock-linux.sh for the first-install
# reason). Confirm with `journalctl -u keyd -n 40` that each fragment was
# parsed and its mouse matched.
sudo systemctl enable keyd
sudo systemctl restart keyd

echo "✓ MX Ergo S front button and MX Vertical upper thumb button now send Enter."
echo "  Only those two mice (by USB id) are touched; the Back button is unchanged."
