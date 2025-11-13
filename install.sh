#!/bin/sh

# Devpod runs this script when using dotfiles

# Install tools
apk add --no-cache stow git vim fish starship font-fira-code-nerd

# Install dotfiles
cp -rf ./.dotfiles ~/.dotfiles/
cd ~/.dotfiles
stow --delete */
stow --adopt */

exit 0
