#!/usr/bin/env bash
# Personal Linux devcontainer setup. Keep runtime directories out of the repo.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
if [[ ! -e /.dockerenv && ! -e /run/.containerenv ]]; then
  echo "Run this setup inside the devcontainer." >&2
  exit 1
fi

install_release_binary() {
  local name="$1" version="$2" asset="$3" checksum="$4" url="$5"
  local archive_binary="${6:-$name}"
  local installed="" temporary archive actual

  if command -v "$name" >/dev/null 2>&1; then
    installed="$("$name" --version 2>/dev/null || true)"
    if [[ "$installed" == *"$version"* ]]; then
      echo "$name $version already installed"
      return
    fi
  fi

  temporary="$(mktemp -d)"
  archive="$temporary/$asset"
  curl -fsSL --retry 3 --max-time 180 "$url/$asset" -o "$archive"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$archive" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
  fi
  if [[ "$actual" != "$checksum" ]]; then
    rm -rf "$temporary"
    echo "$name $version checksum mismatch" >&2
    return 1
  fi

  tar -xzf "$archive" -C "$temporary"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$temporary/$archive_binary" "$HOME/.local/bin/$name"
  rm -rf "$temporary"
  echo "Installed $name $version"
}

install_tui_tools() {
  local arch
  local lazygit_asset lazygit_checksum glow_asset glow_checksum
  local fd_asset fd_checksum eza_asset eza_checksum zoxide_asset zoxide_checksum
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)
      lazygit_asset="lazygit_0.65.0_linux_x86_64.tar.gz"
      lazygit_checksum="44d8e7dd1484b4a66e191bd4ab25a71e8b4b3a65ab122f838e65677ef58c5506"
      glow_asset="glow_3.0.0_Linux_x86_64.tar.gz"
      glow_checksum="13e05e4b2acc18d2aee44291aefe6325b077ec321b631a0cfa780e8e3bc33f78"
      fd_asset="fd-v10.5.0-x86_64-unknown-linux-gnu.tar.gz"
      fd_checksum="a1259cd129636efbc3fef123525c1b49e88fe5088c012630983c310e52fdfa95"
      eza_asset="eza_x86_64-unknown-linux-gnu.tar.gz"
      eza_checksum="35c70c5c43c29108075e58b893234c67ef585f0b53a7eaf8e9e7d4eec9f339b4"
      zoxide_asset="zoxide-0.10.0-x86_64-unknown-linux-musl.tar.gz"
      zoxide_checksum="2d93385b99f3e82cf2701609a1bffcad863fbeb75aa3fe7eb6be4d29be68b1ae"
      ;;
    aarch64|arm64)
      lazygit_asset="lazygit_0.65.0_linux_arm64.tar.gz"
      lazygit_checksum="d954a09c128bd37b2bd0d254308474e87de3729cfe0e37f5b46a49357a4fe257"
      glow_asset="glow_3.0.0_Linux_arm64.tar.gz"
      glow_checksum="810c39f4691feb75e675a5f5f54b9fa091354e7599d9cf9c9fc9b97e47a99759"
      fd_asset="fd-v10.5.0-aarch64-unknown-linux-gnu.tar.gz"
      fd_checksum="c0ee43802e3313a317c5af2f4eabd6ba13eeedd595af9775f05e18a13ac4f52c"
      eza_asset="eza_aarch64-unknown-linux-gnu.tar.gz"
      eza_checksum="40b87ae8628aa2ff0f0d2dc24ab52f689631366385c3da630bae745671fd71ec"
      zoxide_asset="zoxide-0.10.0-aarch64-unknown-linux-musl.tar.gz"
      zoxide_checksum="f1f16c5d6298d63dee467eedea1cdcd8490e43e493bea43acd416dc9033ef641"
      ;;
    *)
      echo "Unsupported architecture for TUI tools: $arch" >&2
      return 1
      ;;
  esac

  install_release_binary lazygit 0.65.0 "$lazygit_asset" "$lazygit_checksum" \
    "https://github.com/jesseduffield/lazygit/releases/download/v0.65.0"
  install_release_binary glow 3.0.0 "$glow_asset" "$glow_checksum" \
    "https://github.com/charmbracelet/glow/releases/download/v3.0.0" \
    "${glow_asset%.tar.gz}/glow"
  install_release_binary fd 10.5.0 "$fd_asset" "$fd_checksum" \
    "https://github.com/sharkdp/fd/releases/download/v10.5.0" \
    "${fd_asset%.tar.gz}/fd"
  install_release_binary eza 0.23.5 "$eza_asset" "$eza_checksum" \
    "https://github.com/eza-community/eza/releases/download/v0.23.5"
  install_release_binary zoxide 0.10.0 "$zoxide_asset" "$zoxide_checksum" \
    "https://github.com/ajeetdsouza/zoxide/releases/download/v0.10.0"
}

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
install_tui_tools
echo "Personal setup complete. Open a new terminal; run fish, zsh or nu to use that shell."
