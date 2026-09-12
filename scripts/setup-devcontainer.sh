#!/usr/bin/env bash
# Personal Linux devcontainer setup. Keep runtime directories out of the repo.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
if [[ ! -e /.dockerenv && ! -e /run/.containerenv ]]; then
  echo "Run this setup inside the devcontainer." >&2
  exit 1
fi
missing=()
for tool in fish zsh vim python3; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if (( ${#missing[@]} )); then
  sudo apt-get update
  sudo apt-get install -y "${missing[@]}"
fi
if ! command -v starship >/dev/null 2>&1; then
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl -fsSL --retry 3 https://starship.rs/install.sh -o "$installer"
  mkdir -p "$HOME/.local/bin"
  sh "$installer" --yes --bin-dir "$HOME/.local/bin"
fi
bash "$script_dir/setup-nushell.sh"
python3 "$script_dir/link-container-config.py"
HERDR_CONTAINER_FISH=1 bash "$script_dir/setup-herdr.sh"
bash "$script_dir/setup-atuin.sh"
echo "Personal setup complete. Open a new terminal; run fish, zsh or nu to use that shell."
