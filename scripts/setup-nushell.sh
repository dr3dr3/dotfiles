#!/usr/bin/env bash
# Pinned official Linux binary; supports both devcontainer architectures.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
if ! command -v nu >/dev/null 2>&1; then
  case "$(uname -m)" in
    aarch64|arm64) arch=aarch64 ;;
    x86_64|amd64) arch=x86_64 ;;
    *) echo "Unsupported Nushell architecture: $(uname -m)" >&2; exit 1 ;;
  esac
  version=0.115.1
  bundle="nu-${version}-${arch}-unknown-linux-gnu"
  temporary="$(mktemp -d)"
  trap 'rm -rf "$temporary"' EXIT
  curl -fsSL --retry 3 --max-time 180 "https://github.com/nushell/nushell/releases/download/${version}/${bundle}.tar.gz" -o "$temporary/nu.tar.gz"
  tar -xzf "$temporary/nu.tar.gz" -C "$temporary" "$bundle/nu"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$temporary/$bundle/nu" "$HOME/.local/bin/nu"
fi
# Generate before the first interactive launch so the prompt works immediately.
nu --no-config-file -c 'mkdir ($nu.data-dir | path join "vendor/autoload"); ^starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")'
nu --version
