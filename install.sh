#!/bin/sh

# Devpod runs this script when using dotfiles

# Set git user and email 
git config --global user.name "Andre Dreyer"
git config --global user.email "git@andredreyer.com"

# Install dotfiles
mv ~/dotfiles/.dotfiles ~
cd ~/.dotfiles
stow */

exit 0