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

# A link this script wrote: the portable source, or the generated container
# variant next to the destination.
is_managed_link() {
  [[ "$1" == "$REPO_DIR/.dotfiles/herdr/.config/herdr/config.toml" ]] && return 0
  [[ "$1" == "$(dirname "$CONFIG_DST")/container.toml" ]] && return 0
  return 1
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

  # Replacing one of OUR OWN links is not a backup-worthy event. This script
  # links config.toml at either the portable source or the generated
  # container.toml, and it used to treat the other variant as a stranger's
  # file — so a host-style run and a container-style run each "backed up" the
  # other, leaving a new timestamped symlink on every pass. Ten had piled up
  # here, alternating targets. Only a genuinely foreign config gets preserved.
  if [[ -L "$CONFIG_DST" ]] && is_managed_link "$(readlink "$CONFIG_DST")"; then
    rm -f "$CONFIG_DST"
  elif [[ -e "$CONFIG_DST" || -L "$CONFIG_DST" ]]; then
    backup="${CONFIG_DST}.pre-dotfiles.$(date +%Y%m%d%H%M%S)"
    mv "$CONFIG_DST" "$backup"
    echo "→ Backed up existing Herdr config to $backup"
  fi

  ln -s "$CONFIG_SRC" "$CONFIG_DST"
  echo "✓ Herdr config linked: $CONFIG_DST → $CONFIG_SRC"
}

# Rebuild-restore helpers (docs/HERDR.md "Surviving a devcontainer rebuild"):
# launch.toml declares service commands to relaunch per pane; the three scripts
# snapshot the live session, replay a snapshot, and rerun those commands.
link_restore_tooling() {
  local launch_src="$REPO_DIR/.dotfiles/herdr/.config/herdr/launch.toml"
  local launch_dst="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/launch.toml"
  # This runs before link_config, so on a fresh devcontainer (~/.config is an
  # empty volume) the directory does not exist yet and the ln would abort the
  # whole script under set -e, leaving Herdr with no managed config at all.
  mkdir -p "$(dirname "$launch_dst")"
  if [[ ! -e "$launch_dst" && ! -L "$launch_dst" ]]; then
    ln -s "$launch_src" "$launch_dst"
    echo "✓ Herdr launch.toml linked: $launch_dst → $launch_src"
  fi
  mkdir -p "$HOME/.local/bin"
  local tool
  for tool in herdr-snapshot herdr-replay herdr-after-restore; do
    ln -sfn "$REPO_DIR/scripts/herdr/$tool" "$HOME/.local/bin/$tool"
  done
  echo "✓ Herdr restore tooling on PATH: herdr-snapshot, herdr-replay, herdr-after-restore"
}

install_herdr
link_restore_tooling
# The devcontainer opts into Fish without changing the portable host config.
#
# The opt-in is STICKY. local-dev-env's post-create runs this script directly,
# without HERDR_CONTAINER_FISH, while the personal setup-devcontainer.sh runs it
# with the flag — so on every rebuild the two took turns and the shell Herdr
# opened flipped between fish and bash depending on which ran last. An existing
# container.toml that config.toml already points at is this machine saying it
# opted in; honour that and just refresh it from the (possibly updated) source,
# rather than silently reverting the choice.
generated="$(dirname "$CONFIG_DST")/container.toml"
container_variant=0
if [[ "${HERDR_CONTAINER_FISH:-0}" == 1 ]]; then
  container_variant=1
elif [[ -e "$generated" ]] && [[ "$(readlink "$CONFIG_DST" 2>/dev/null)" == "$generated" ]]; then
  container_variant=1
  echo "→ Keeping the container shell opt-in already active here"
fi
if [[ "$container_variant" == 1 ]]; then
  if command -v fish >/dev/null 2>&1; then
    mkdir -p "$(dirname "$CONFIG_DST")"
    { cat "$CONFIG_SRC"; printf '\n[terminal]\ndefault_shell = "/usr/bin/fish"\n'; } > "$generated"
    CONFIG_SRC="$generated"
  else
    echo "→ fish is not installed; using the portable config" >&2
  fi
fi
link_config

echo "✓ Herdr setup complete (prefix: Ctrl+Alt+Space; one-key host trigger: Caps Lock)"
