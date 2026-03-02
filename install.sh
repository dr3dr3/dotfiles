#!/bin/bash

# Update package lists
sudo apt-get update

# Install tools
sudo apt-get install -y stow git vim fish

# Install Nushell from GitHub releases
NU_VERSION=$(curl -s https://api.github.com/repos/nushell/nushell/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
NU_ARCHIVE="nu-${NU_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
curl -sL "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/${NU_ARCHIVE}" \
  | tar -xz -C /tmp
sudo mv "/tmp/nu-${NU_VERSION}-x86_64-unknown-linux-gnu/nu" /usr/local/bin/nu
sudo chmod +x /usr/local/bin/nu

# Install Starship
curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes

# Apply dotfiles via stow from the packages directory
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR/.dotfiles"
stow --delete --target "$HOME" */
stow --adopt --target "$HOME" */

exit 0