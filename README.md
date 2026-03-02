# André Dreyer's Dotfiles

A collection of personal configuration files for various development tools and shells, intended for use inside Ubuntu 24.04-based dev containers.

## 🚀 Usage

This repo is designed to be cloned into other repositories as a `.dotfiles` subfolder. The `install.sh` script is then run from there to set up the shell environment inside the dev container. It only modifies the container's home directory (`~`) and does not touch the host repo's workspace.

### Setup in a Project

In your project's devcontainer setup (e.g. `postCreateCommand` or `postStartCommand`), clone this repo and run the install script:

```bash
git clone https://github.com/dr3dr3/dotfiles.git .dotfiles
bash .dotfiles/install.sh
```

This will:

1. Install required tools (`fish`, `nushell`, `starship`, `stow`, `git`, `vim`) via `apt-get`
2. Apply dotfile configurations to `~` using GNU Stow

## 📁 What's Included

This dotfiles repository includes configurations for:

- **Fish Shell** - Modern shell with intelligent autocompletions
- **Nushell** - Data-driven shell with structured output
- **Starship** - Fast, customizable prompt for any shell
- **Vim** - Lightweight text editor configuration

All configurations are managed using [GNU Stow](https://www.gnu.org/software/stow/) for easy symlink management.

## 🐳 Target Environment

- **Base Image**: Ubuntu 24.04
- **Default Shell**: Bash

## 🐟 Fish Shell Tips

- `cdh` - Select from previous directories
- `dirh` - Show directory history  
- `prevd` - Go to previous directory
- `nextd` - Go forward in directory history
- `fish -P` - Start incognito mode (no history)

## ⚡ Starship Prompt

The repository includes a custom Starship configuration for a beautiful, informative command prompt that works across all shells.

## 📝 License

Personal dotfiles for André Dreyer. Feel free to use as inspiration for your own configurations!
