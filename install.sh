#!/bin/bash

# Update package lists
apt-get update

# Install tools
apt-get install -y stow git vim fish nushell

# Install Starship
curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Apply dotfiles via stow from this repo's directory
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"
stow --delete */
stow --adopt */

exit 0
