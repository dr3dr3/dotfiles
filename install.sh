#!/bin/sh

# Devpod runs this script when using dotfiles

# Install dotfiles
cp -r ./.dotfiles ~/.dotfiles/
cd ~/.dotfiles
stow */

exit 0
