# André Dreyer's Dotfiles

A collection of personal configuration files for development tools and shells.
Two target environments share one Stow-managed `.dotfiles/` tree:

- **macOS host** (Apple Silicon) — terminal-first, orchestration-oriented dev
  machine. See [macOS Setup](#-macos-setup).
- **Ubuntu 24.04 dev containers** — the original target. See [Dev Container Usage](#-dev-container-usage).

## 🍎 macOS Setup

A fresh M-series Mac is provisioned by `bootstrap-mac.sh`, which installs
Homebrew, applies the `Brewfile`, and stows the macOS dotfiles:

```bash
git clone https://github.com/dr3dr3/dotfiles.git ~/.dotfiles-repo
cd ~/.dotfiles-repo && ./bootstrap-mac.sh
```

It is idempotent (safe to re-run) and will:

1. Install **Homebrew** (if missing) and everything in [`Brewfile`](Brewfile)
2. Stow the macOS packages (`zsh`, `ghostty`, `starship`) into `~`
3. Set up host **Node via fnm** + install `@devcontainers/cli` (npm-only)
4. Install the **Claude Code CLI** via its self-updating native installer
5. Print the one-time manual steps (1Password SSH agent, default shell, …)

**Stack:** Ghostty terminal · OrbStack engine · `@devcontainers/cli` to boot
stacks headlessly · Claude Code + Codex CLIs (varlock-wrapped) · Ollama (local
LLM, fallback only) · 1Password + varlock for secrets. The `op://`-referencing
secret wiring lives in [`zsh/agents.zsh`](.dotfiles/zsh/.config/zsh/agents.zsh) —
no hand-rolled key injection.

📖 **Full command + maintenance reference:** [`docs/CHEATSHEET.md`](docs/CHEATSHEET.md)
— daily aliases, devcontainer workflow, Ghostty⇄container usage, secrets, and
the keep-it-current/CVE-scan routine ([`update-mac.sh`](update-mac.sh)).

Handy aliases (see [`aliases.zsh`](.dotfiles/zsh/.config/zsh/aliases.zsh) /
[`agents.zsh`](.dotfiles/zsh/.config/zsh/agents.zsh)):

| Alias | Expands to |
| --- | --- |
| `dcu` / `dcb` / `dce` | `devcontainer up` / rebuild / `exec` (current folder) |
| `cc` / `cca` / `cx` | Claude Code (personal / corporate-API) · Codex — varlock-wrapped |
| `oll` / `olp` / `olr` | `ollama list` / `ps` / `run` |
| `roe` | `code roe-local-dev.code-workspace` (never bare `code .`) |

## 🐳 Dev Container Usage

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

- **Zsh** - macOS host shell (fnm, 1Password agent, agent/devcontainer aliases)
- **Ghostty** - native macOS terminal configuration
- **Fish Shell** - Modern shell with intelligent autocompletions (containers)
- **Nushell** - Data-driven shell with structured output (containers)
- **Starship** - Fast, customizable prompt for any shell (shared)
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
