# André Dreyer's Dotfiles

A collection of personal configuration files for various development tools and shells, designed for use with DevPod.sh and development containers.

## 🚀 Quick Start

### DevPod Integration

This repository is designed to work seamlessly with [DevPod.sh](https://devpod.sh/). When you set this as your dotfiles repository in DevPod, it will automatically run the `install.sh` script to set up your development environment.

### Manual Installation

```bash
git clone https://github.com/dr3dr3/dotfiles.git
cd dotfiles
./install.sh
```

## 📁 What's Included

This dotfiles repository includes configurations for:

- **Fish Shell** - Modern shell with intelligent autocompletions
- **Nushell** - Data-driven shell with structured output  
- **Starship** - Fast, customizable prompt for any shell
- **Vim** - Lightweight text editor configuration

All configurations are managed using [GNU Stow](https://www.gnu.org/software/stow/) for easy symlink management.

## 🐳 Development Container

The repository includes a complete development container setup:

- **Base Image**: Alpine Linux (latest)
- **Pre-installed Tools**: Fish, Nushell, Starship, Stow, Git, Gum, FiraCode Nerd Font
- **VS Code Extensions**: GitHub Copilot, GitHub Pull Requests, Docker
- **Default Shell**: Fish

To use with VS Code Dev Containers, simply open this repository in VS Code and select "Reopen in Container" when prompted.

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
