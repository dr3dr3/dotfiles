# André Dreyer's Dotfiles

A collection of personal configuration files for development tools and shells.
Two target environments share one Stow-managed `.dotfiles/` tree:

- **macOS host** (Apple Silicon) — terminal-first, orchestration-oriented dev
  machine. See [macOS Setup](#-macos-setup).
- **Ubuntu 24.04 dev containers** — the original target. See [Dev Container Usage](#-dev-container-usage).

## 🍎 macOS Setup

> 🆕 **Setting up a new Mac?** Follow the full end-to-end runbook in
> **[SETUP.md](SETUP.md)** (host + per-project agents + repo layout). The quick
> version is below.

A fresh M-series Mac is provisioned by `bootstrap-mac.sh`, which installs
Homebrew, applies the `Brewfile`, and stows the macOS dotfiles. Repos live under
`~/Code/<org-or-username>/<repo>`:

```bash
git clone https://github.com/dr3dr3/dotfiles.git ~/Code/dr3dr3/dotfiles
cd ~/Code/dr3dr3/dotfiles && ./bootstrap-mac.sh
```

It is idempotent (safe to re-run) and will:

1. Install **Homebrew** (if missing) and everything in [`Brewfile`](Brewfile)
2. Stow the macOS packages (`zsh ghostty starship fish nushell zellij`) into `~`
3. Set up host **Node via fnm** + install `@devcontainers/cli` (npm-only)
4. Create `~/Code` (repo layout) and `~/host-share` (mounted into containers)
5. Print the one-time manual steps (1Password SSH agent, default shell, …)

**Stack:** Ghostty terminal · OrbStack engine · `@devcontainers/cli` to boot
stacks headlessly · Ollama (local LLM, fallback only) · 1Password for secrets.
The host is a **launcher** — AI agents (Claude Code, Codex, Pi) run *inside* the
dev containers, provisioned by [dotai](https://github.com/dr3dr3/dotai); the
`cc`/`cca`/`cx`/`pi` aliases just `devcontainer exec` into them. Secret wiring
([`zsh/agents.zsh`](.dotfiles/zsh/.config/zsh/agents.zsh)) resolves `op://` refs
via the mounted 1Password agent — no hand-rolled key injection.

📖 **Full command + maintenance reference:** [`docs/CHEATSHEET.md`](docs/CHEATSHEET.md)
— daily aliases, devcontainer workflow, Ghostty⇄container usage, secrets, and
the keep-it-current/CVE-scan routine ([`update-mac.sh`](update-mac.sh)).

Handy aliases (see [`aliases.zsh`](.dotfiles/zsh/.config/zsh/aliases.zsh) /
[`agents.zsh`](.dotfiles/zsh/.config/zsh/agents.zsh)):

| Alias | Expands to |
| --- | --- |
| `dcu` / `dcb` / `dce` | `devcontainer up` / rebuild / `exec` (current folder) |
| `cc` / `cca` / `cx` | Claude Code (personal / corporate-API) · Codex — in-container |
| `oll` / `olp` / `olr` | `ollama list` / `ps` / `run` |
| `clone` / `cdc` | clone into / cd to `~/Code/<org>/<repo>` |
| `roe` | `code roe-local-dev.code-workspace` (never bare `code .`) |

## 🐳 Dev Container Usage

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
  zsh/         → ~/.zshrc + ~/.config/zsh/   (macOS host default shell)
  ghostty/     → ~/.config/ghostty/config    (macOS terminal)
  fish/        → ~/.config/fish/             (Fish shell — host + containers)
  nushell/     → ~/.config/nushell/          (Nushell — host + containers)
  starship/    → ~/.config/starship.toml     (Starship prompt — shared)
  zellij/      → ~/.config/zellij/            (multiplexer config + dev layout)
  vim/         → ~/.vimrc                     (Vim config)
```

On the **macOS host**, `bootstrap-mac.sh` stows `zsh ghostty starship fish nushell zellij`,
and Fish + Nushell carry the same host wiring as zsh (fnm, 1Password agent,
fzf/zoxide, the devcontainer/agent aliases). In **containers**, `install.sh`
stows `fish nushell starship vim`.

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
