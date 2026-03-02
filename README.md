# André Dreyer's Dotfiles

A collection of personal configuration files for various development tools and shells, intended for use inside Ubuntu 24.04-based dev containers.

## 🚀 Usage

This repo is designed to be cloned into a project's devcontainer setup. The `install.sh` script sets up the shell environment inside the container — it only modifies the container's home directory (`~`) and does not touch the host workspace.

### Setup in a Project

In your project's devcontainer config (e.g. `postCreateCommand` or `postStartCommand`), clone this repo and run the install script:

```bash
git clone https://github.com/dr3dr3/dotfiles.git .dotfiles
bash .dotfiles/install.sh
```

This will:

1. Install `fish`, `stow`, `git`, `vim` via `apt-get`
2. Install **Nushell** from the [latest GitHub release](https://github.com/nushell/nushell/releases) (not available in apt)
3. Install **Starship** from the official installer script
4. Auto-configure Starship for Bash, Fish, and Nushell
5. Apply all dotfile configs to `~` using [GNU Stow](https://www.gnu.org/software/stow/)

> **Note:** You may see `bash: __git_ps1: command not found` in the terminal after running the script. This is harmless — it comes from the default bash PS1 before Starship takes over, and disappears once you open a new terminal session.

## 📁 Repo Structure

Dotfile configs live in `.dotfiles/` and are organised as [GNU Stow](https://www.gnu.org/software/stow/) packages — each subfolder mirrors the target home directory structure:

```
.dotfiles/
  fish/        → ~/.config/fish/        (Fish shell config)
  nushell/     → ~/.config/nushell/     (Nushell config)
  starship/    → ~/.config/starship.toml (Starship prompt)
  vim/         → ~/.vimrc               (Vim config)
```

To apply a single package manually: `cd .dotfiles && stow --target "$HOME" fish`

## 🐳 Target Environment

- **Base Image**: Ubuntu 24.04
- **Default Shell**: Bash (Starship prompt active)
- **Available Shells**: Bash 🐚, Fish 🐠, Nushell 🐢

## ⚡ Starship Prompt

The custom Starship config shows context-relevant info in a single line, with the cursor on a clean second line:

```
🐠 ~/project main ? ~ +2 via ⬢ 22.0.0 via 🐘 8.3.0 🐳 14:32
➜
```

| Segment                   | Meaning                                                     |
| ------------------------- | ----------------------------------------------------------- |
| `🐚` / `🐠` / `🐢` / `🪟` | Current shell (Bash / Fish / Nushell / PowerShell)          |
| `~/project`               | Working directory (truncated to 8 segments)                 |
| `main`                    | Git branch                                                  |
| `?` `~` `+2` `✘`          | Git status: untracked / modified / staged count / conflicts |
| `✓`                       | Git status: clean                                           |
| `⇡2` / `⇣1`               | Commits ahead / behind remote                               |
| `via ⬢ x.x.x`             | Node.js version (shown when `package.json` is present)      |
| `via 🐘 x.x.x`            | PHP version (shown when `composer.json` is present)         |
| `🐳`                      | Running inside a container                                  |
| `14:32`                   | Current time                                                |

## 🐟 Fish Shell Tips

- `cdh` — Select from previous directories
- `dirh` — Show directory history
- `prevd` — Go to previous directory
- `nextd` — Go forward in directory history
- `fish -P` — Start incognito mode (no history)

## 📝 License

Personal dotfiles for André Dreyer. Feel free to use as inspiration for your own configurations!
