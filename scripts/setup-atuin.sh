#!/usr/bin/env bash
# Personal shell history. Runtime data never lives in the Stow repository.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/atuin"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
export PATH="$HOME/.local/bin:$PATH"

# Only redirect data when ~/.config is actually a persistent mount.
if [[ "$(uname -s)" == Linux ]] && mountpoint -q "${XDG_CONFIG_HOME:-$HOME/.config}"; then
  backing="$config_dir/data"
  mkdir -p "$config_dir" "$(dirname "$data_dir")"
  if [[ -L "$data_dir" ]]; then
    [[ "$(readlink "$data_dir")" == "$backing" ]] || {
      echo "Custom Atuin data symlink preserved; check its persistence: $data_dir" >&2
      exit 1
    }
  elif [[ -e "$data_dir" ]]; then
    echo "Existing Atuin data at $data_dir; stop Atuin and migrate it to $backing before setup." >&2
    exit 1
  else
    mkdir -p "$backing"
    chmod 700 "$backing"
    ln -s "$backing" "$data_dir"
  fi
fi

if ! command -v atuin >/dev/null 2>&1; then
  if [[ "$(uname -s)" == Darwin ]] && command -v brew >/dev/null 2>&1; then
    brew install atuin
  else
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    # Pin the release; use the vendor's architecture-aware binary installer.
    curl -fsSL --retry 3 --max-time 120 \
      https://github.com/atuinsh/atuin/releases/download/v18.21.0/atuin-installer.sh -o "$installer"
    ATUIN_INSTALL_DIR="$HOME/.local/bin" ATUIN_NO_MODIFY_PATH=1 sh "$installer"
  fi
fi

mkdir -p "$config_dir"
if [[ ! -e "$config_dir/config.toml" ]]; then
  cp "$script_dir/../config/atuin/config.toml" "$config_dir/config.toml"
fi

# These files are regenerated after rebuild; shell rc files only source them.
for shell in bash zsh; do
  atuin init "$shell" --disable-up-arrow > "$config_dir/init.$shell"
  rc="$HOME/.${shell}rc"
  [[ "$shell" != zsh ]] || rc="${ZDOTDIR:-$HOME}/.zshrc"
  line='export PATH="$HOME/.local/bin:$PATH"; [ ! -r "${XDG_CONFIG_HOME:-$HOME/.config}/atuin/init.'"$shell"'" ] || . "${XDG_CONFIG_HOME:-$HOME/.config}/atuin/init.'"$shell"'"'
  # Managed host rc files already initialize Atuin after fzf.
  if grep -q "atuin init $shell" "$rc" 2>/dev/null; then
    continue
  fi
  grep -qxF "$line" "$rc" 2>/dev/null || printf '\n%s\n' "$line" >> "$rc"
done
if ! grep -q "atuin init fish" "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" 2>/dev/null; then
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d"
cat > "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/atuin.fish" <<'FISH'
if status is-interactive
    fish_add_path "$HOME/.local/bin"
    if type -q atuin
        atuin init fish --disable-up-arrow | source
    end
end
FISH
fi
atuin --version
echo "Atuin ready. Open a new shell; Ctrl-R searches history. Sync remains opt-in."
