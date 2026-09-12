# André Dreyer's Dotfiles

A collection of personal configuration files for development tools and shells.
The same tracked terminal configuration supports four environments:

- **macOS host** (Apple Silicon) — terminal-first, orchestration-oriented dev
  machine. See [macOS Setup](#-macos-setup).
- **Ubuntu 24.04 dev containers** — the original target. See [Dev Container Usage](#-dev-container-usage).
- **Omarchy Linux** — the same Herdr keymap, plus an opt-in keyd Caps Lock remap.
- **Windows 11** — native Herdr setup through PowerShell.

Herdr setup and its Omarchy-compatible keymap are documented in
[`docs/HERDR.md`](docs/HERDR.md).

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
2. Stow the macOS packages (`zsh ghostty starship fish nushell zellij mise`) into `~`
3. Set up host **Node via mise** (pinned to LTS) + install `@devcontainers/cli` (npm-only)
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
— daily aliases, devcontainer workflow, Ghostty⇄container usage, secrets, the
keep-it-current/CVE-scan routine ([`update-mac.sh`](update-mac.sh)), and
[`doctor-mac.sh`](doctor-mac.sh) — read-only assertions that the live host
actually matches what this repo declares.

Handy aliases (see [`aliases.zsh`](.dotfiles/zsh/.config/zsh/aliases.zsh) /
[`agents.zsh`](.dotfiles/zsh/.config/zsh/agents.zsh)) plus
[`devsh`](.dotfiles/bin/.local/bin/devsh):

| Alias | Expands to |
| --- | --- |
| `devsh` / `devsh <cmd>` | host terminal into this repo's devcontainer — works from any subdir, starts it if down |
| `devherd` | start or attach to Herdr inside the current repo's devcontainer |
| `dcu` / `dcb` / `dce` | `devcontainer up` / rebuild / `exec` (current folder) |
| `cc` / `cca` / `cx` | Claude Code (personal / corporate-API) · Codex — in-container |
| `oll` / `olp` / `olr` | `ollama list` / `ps` / `run` |
| `clone` / `cdc` | clone into / cd to `~/Code/<org>/<repo>` |
| `roe` | `code roe-local-dev.code-workspace` (never bare `code .`) |

## 🐳 Dev Container Usage

This repo is designed to be cloned into a project's devcontainer setup. The `install.sh` script sets up the shell environment inside the container — it only modifies the container's home directory (`~`) and does not touch the host workspace.

### Setup in the Rock of Eye devcontainer

Clone this repo at `/workspace/dotfiles`, then run `roe setup-dotfiles`
(or `make setup-dotfiles` from `/workspace`). The command requires an existing
clone and runs `bash /workspace/dotfiles/scripts/setup-devcontainer.sh`.
Future container creation runs the same hook automatically when the clone exists.

The personal hook installs Fish, Zsh, Nushell, Vim and Starship when missing, applies
managed Fish/Zsh/Nushell/Vim/Starship configuration, and sets up Herdr and Atuin.
Bash retains its existing initialization and gains Starship and Atuin.
Open a new terminal afterward; run `fish` or `zsh` to choose that shell.
Herdr uses Fish for new panes; the account default shell is unchanged. Nushell uses the pinned official 0.115.1 Linux release for ARM64 or x86_64.
Host-only tooling is not installed by this hook. Prompt icons use the font configured in your host terminal.

Existing config files are backed up under `~/.config/dotfiles-backups/`.
Config directories remain real directories: only selected files are linked,
so shell runtime state does not land in this checkout. Repeated setup preserves
already-correct links. The legacy `install.sh` is a separate, broad Stow installer;
use the new hook for this devcontainer.

## 📁 Repo Structure

Dotfile configs live in `.dotfiles/` and are organised as [GNU Stow](https://www.gnu.org/software/stow/) packages — each subfolder mirrors the target home directory structure:

```
.dotfiles/
  bin/         → ~/.local/bin/               (host scripts: `devsh`)
               ↳ one script serves zsh + fish + nushell, so shell-agnostic
                 helpers go here rather than being written three times.
  cliamp/      → ~/.config/cliamp/radios.toml  (curated radio shortlist)
               ↳ ONLY radios.toml is stowed. config.toml is not: cliamp
                 rewrites it on every visualiser/EQ change, and `cliamp setup`
                 would write OAuth secrets into it. bootstrap-mac.sh mkdirs
                 ~/.config/cliamp first so stow cannot fold the directory —
                 see "Folded symlinks" below.
  zsh/         → ~/.zshrc + ~/.config/zsh/   (macOS host default shell)
  ghostty/     → ~/.config/ghostty/config    (macOS terminal)
  herdr/       → ~/.config/herdr/config.toml (portable Omarchy-style keymap)
  karabiner/   → ~/.config/karabiner/assets/ (macOS Caps Lock → Herdr prefix rule)
  fish/        → ~/.config/fish/             (Fish shell — host + containers)
  nushell/     → ~/.config/nushell/          (Nushell — host + containers)
               ↳ macOS ONLY: nushell reads ~/Library/Application Support/
                 nushell/, so bootstrap-mac.sh symlinks config.nu + env.nu
                 from there. Without that bridge the config silently never
                 loads on macOS. Linux/containers use ~/.config/nushell.
  starship/    → ~/.config/starship.toml     (Starship prompt — shared)
  zellij/      → ~/.config/zellij/            (multiplexer config + dev layout)
  mise/        → ~/.config/mise/config.toml   (host tool versions — Brewfile peer)
  vim/         → ~/.vimrc                     (Vim config)
```

On the **macOS host**, `bootstrap-mac.sh` stows `zsh ghostty herdr karabiner starship fish nushell zellij mise`,
and Fish + Nushell carry the same host wiring as zsh (mise, 1Password agent,
fzf/zoxide, the devcontainer/agent aliases). In **containers**, use `scripts/setup-devcontainer.sh` as described above.

To apply a single package manually: `cd .dotfiles && stow --target "$HOME" fish`

### ⚠️ Folded symlinks: tools can write into this repo

Stow **folds** directories wherever it can — `~/.config/fish` is a single
symlink to `.dotfiles/fish/.config/fish/`, not a real directory containing
per-file symlinks. That keeps `~` tidy, but it means **anything writing into a
stowed config directory is writing into this repo**, where it surfaces as an
uncommitted change or an untracked file.

That has caught us three times so far:

| What wrote it | What landed in the repo |
|---|---|
| fish, on every run | `fish_variables` — machine-local universal variables |
| OrbStack, on install | `fish/completions/*.fish` — symlinks to absolute `/Applications/OrbStack.app/…` paths |
| Unsloth's `install.sh` | a `.zshrc` PATH append, plus `fish/conf.d/unsloth.fish` containing a hardcoded `/Users/<name>/…` path |

The Unsloth case is the instructive one: committing it would have pushed a
hardcoded username into a repo whose whole point is being portable to a fresh
machine.

**Habit: run `git status` here after installing anything that offers shell
integration.** When something appears, decide which of two things it is:

- **Host state** — history, caches, machine-local variables, generated
  completions. Add it to `.gitignore` with a comment explaining why, alongside
  the existing entries.
- **Config you actually want** — a PATH entry, an env var. Don't keep the
  installer's version: re-declare it properly in the owning package, using
  `$HOME` rather than an absolute path, and mirror it across zsh/fish/nushell so
  the three stay in parity. The `~/.local/bin` block in
  `zsh/.config/zsh/env.zsh` is the worked example.

A related trap, same root cause: a tool that *regenerates* its config on every
start can feed on its own output. See the `mise activate nu` note in
`nushell/config.nu` for why nushell deliberately avoids that pattern.

## 🛠 Tools

`tools/` holds personal command-line tools that are **not** dotfiles. They are not stow
packages — each installs a launcher into `~/.local/bin` instead — and `install.sh` runs
each tool's own installer at the end of setup.

| Tool | What it does |
| ---- | ------------ |
| [`diagram`](tools/diagram) | Turns a small YAML spec into a laid-out, editable Excalidraw file. ELK does the layout and a geometry check fails the build on overlaps, adrift arrows or clipped labels. |

⚠️ The launcher lands in `~/.local/bin`, which **does not survive a dev container
rebuild** — nothing re-runs `install.sh`, so re-run `tools/diagram/install.sh` after one.
A `diagram: command not found` in a fresh container means exactly this.

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

### Devcontainer persistence and Atuin

Run `bash scripts/setup-devcontainer.sh` for the personal shell, Starship, Herdr +
Atuin setup. See [persistence and rebuild recovery](docs/PERSISTENCE.md), including
the one-time Codex migration to run **before** rebuilding an existing container.
