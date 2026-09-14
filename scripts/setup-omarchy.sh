#!/usr/bin/env bash
# Personal Omarchy host setup. Preserve Omarchy-owned desktop configuration.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
stow_dir="$repo_dir/.dotfiles"
backup_root="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles-backups/omarchy-$(date +%Y%m%d%H%M%S)-$$"
stow_packages=(bin fish nushell starship)

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot verify this is an Omarchy host: /etc/os-release is missing." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != omarchy ]]; then
  echo "Run this setup on Omarchy. Detected: ${PRETTY_NAME:-unknown Linux}." >&2
  exit 1
fi

if ! command -v omarchy >/dev/null 2>&1; then
  echo "The omarchy command is missing; cannot install host packages safely." >&2
  exit 1
fi

backup_target() {
  local target="$1"
  local relative="${target#"$HOME"/}"
  local backup="$backup_root/$relative"

  mkdir -p "$(dirname "$backup")"
  mv "$target" "$backup"
  printf '→ Backed up %s to %s\n' "$target" "$backup"
}

prepare_stow_package() {
  local package="$1"
  local package_dir="$stow_dir/$package"
  local source relative target expected_link

  [[ -d "$package_dir" ]] || {
    echo "Missing Stow package: $package_dir" >&2
    return 1
  }

  while IFS= read -r -d '' source; do
    relative="${source#"$package_dir"/}"
    target="$HOME/$relative"

    if [[ -L "$target" ]]; then
      expected_link="$(realpath --relative-to="$(dirname "$target")" "$source")"
      [[ "$(readlink "$target")" == "$expected_link" ]] && continue
    fi

    if [[ -d "$target" && ! -L "$target" ]]; then
      echo "Cannot replace directory with managed file: $target" >&2
      return 1
    fi

    if [[ -e "$target" || -L "$target" ]]; then
      backup_target "$target"
    fi
  done < <(find "$package_dir" -mindepth 1 \( -type f -o -type l \) -print0)
}

retire_generated_atuin_fish_hook() {
  local hook="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/atuin.fish"

  # setup-atuin.sh used this hook before the managed Fish config was linked.
  # The tracked config initializes Atuin itself, so retaining it would run
  # Atuin twice in every Fish session. Preserve unfamiliar custom hooks.
  if [[ -f "$hook" ]] && grep -qF 'atuin init fish --disable-up-arrow | source' "$hook"; then
    backup_target "$hook"
  elif [[ -e "$hook" || -L "$hook" ]]; then
    echo "NOTE: Preserving custom Fish Atuin hook: $hook"
  fi
}

echo "→ Installing Omarchy packages"
omarchy pkg add stow fish nushell starship atuin

for package in "${stow_packages[@]}"; do
  prepare_stow_package "$package"
done
retire_generated_atuin_fish_hook

stow --dir "$stow_dir" --target "$HOME" --no-folding --restow "${stow_packages[@]}"

bash "$script_dir/setup-nushell.sh"
bash "$script_dir/setup-herdr.sh"
bash "$script_dir/setup-atuin.sh"
bash "$repo_dir/tools/diagram/install.sh"

echo "✓ Omarchy dotfiles setup complete"
if [[ -d "$backup_root" ]]; then
  echo "  Replaced files were backed up under: $backup_root"
fi
echo "  Open a new terminal and run fish to use Fish; the login shell was not changed."
