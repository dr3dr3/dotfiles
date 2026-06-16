# 🧾 macOS Dev Environment — Cheat Sheet

Terminal-first, container-centric workflow. The **host stays clean** (terminal,
shell, container engine, secrets, AI agents, single-binary CLI tools); **app
runtimes** (PHP, Node apps, MySQL, Redis…) live inside dev containers.

- Setup: [`bootstrap-mac.sh`](../bootstrap-mac.sh) · Packages: [`Brewfile`](../Brewfile)
- Aliases: [`aliases.zsh`](../.dotfiles/zsh/.config/zsh/aliases.zsh) · [`agents.zsh`](../.dotfiles/zsh/.config/zsh/agents.zsh)
- Maintenance: [`update-mac.sh`](../update-mac.sh)

---

## ⌨️ Daily aliases

| Alias | Command | Notes |
| --- | --- | --- |
| `dcu` | `devcontainer up --workspace-folder .` | boot the stack (headless) |
| `dcb` | `… up --remove-existing-container` | rebuild from scratch |
| `dce <cmd>` | `devcontainer exec --workspace-folder . <cmd>` | run a command in-container |
| `dcs` | exec `bash` (TERM-safe) | **shell into the devcontainer** |
| `csh <name>` | `docker exec -it … bash` | shell into any container by name fragment |
| `dps` / `dpsa` | `docker ps` / `-a` | running / all containers |
| `dcl` | `docker compose logs -f` | tail stack logs |
| `lzd` | `lazydocker` | container/logs TUI |
| `cc` / `cca` | Claude Code personal / corporate-API | **runs in-container** (devcontainer exec) |
| `cx` / `pi` | Codex / Pi Harness | **runs in-container** |
| `oll` / `olp` | `ollama list` / `ollama ps` | installed / resident models |
| `olr` / `olu` / `olrm` | `ollama run` / `pull` / `rm` | run / fetch / free memory |
| `roe` | `code roe-local-dev.code-workspace` | **JIT editor — never bare `code .`** |
| `ll` / `lt` | `eza -lah --git` / tree | listings |
| `lg` | `lazygit` | git TUI |
| `upd` | `update-mac.sh` | update + audit the host |

---

## 🐳 Dev container workflow

```bash
cd ~/Code/rock-of-eye/<repo>   # repos live under ~/Code/<org-or-user>/<repo>
dcu                       # boot: 3 Laravel + 3 Vue + MySQL + Redis + Mailpit + RustFS
dcs                       # drop into the container shell
dce php artisan migrate   # or run one-off commands from the host
dcb                       # rebuild fresh if the image/config changed
```

- **CLI booting ignores `customizations.vscode`** — no Intelephense, Volar,
  i18n-ally, or Linear MCP. Agents use the prebuilt **graphify codegraph** for
  repo context instead. Accepted trade for orchestration-first.
- **Min resources:** 16GB / 4 CPU. Set OrbStack's memory ceiling in its
  settings so a 32b Ollama model can't starve the stack (see *Memory budget*).
- **OrbStack = Docker Desktop drop-in:** same socket/CLI/compose. No compose
  changes vs. the team standard, but you lose Docker Desktop's repro parity —
  keep that in mind when reproducing a teammate's issue.

---

## 🖥️ Ghostty ⇄ containers

Ghostty runs on the **host**; you "work inside" a container by running a shell
**in a Ghostty pane**. Typical layout — one window, four splits:

```
┌────────────────────┬────────────────────┐
│ host: git, dcu/dcb │ container: dcs      │   Cmd+D      split right
├────────────────────┼────────────────────┤   Cmd+Shift+D split down
│ agent: cc / cx     │ logs: dcl / olp     │   Cmd+[ / ]  move between splits
└────────────────────┴────────────────────┘   Cmd+Enter  zoom focused split
```

### Ghostty keybindings

| Keys | Action |
| --- | --- |
| `Cmd+D` / `Cmd+Shift+D` | split right / down |
| `Cmd+[` / `Cmd+]` | focus previous / next split |
| `Cmd+Enter` | zoom (maximise) the focused split |
| `Cmd+T` / `Cmd+W` | new tab / close pane |
| `Cmd+K` | clear scrollback |
| `Cmd+Shift+P` | command palette (fuzzy action search) |
| `Ctrl+` `` ` `` (global) | drop-down **quick terminal** from anywhere |
| `Cmd+Shift+,` | reload config after editing |

- **New splits inherit the cwd** (and the container shell, via shell
  integration) — split off `dcs` and you're still inside the container.
- **Quick terminal** (`Ctrl+``) is a global scratch shell — fire off `olp`,
  `gh pr list`, or an `op` lookup without leaving your editor, then dismiss.

### The `TERM` gotcha (important)

Ghostty advertises `TERM=xterm-ghostty`. Bare container images don't ship that
terminfo, so `clear`, `tput`, and TUIs error inside them. Two fixes:

1. **Quick (already wired):** `dcs` / `csh` force `TERM=xterm-256color`. Done.
2. **Proper (full Ghostty features in-container):** install the terminfo once
   per image —
   ```bash
   infocmp -x xterm-ghostty | dce tic -x -
   ```
   Add that to the project's `postCreateCommand` to make it permanent.

---

## 🤖 AI agents — in containers, launched from the host

Agents do **not** run on the host (isolation/safety). They're installed inside
each project's dev container by [dotai](https://github.com/dr3dr3/dotai); the
host wrappers just `devcontainer exec` into the container.

```bash
# one-time per project, from inside the container (dcs):
git clone https://github.com/dr3dr3/dotai.git /workspace/.ai/dotai
bash /workspace/.ai/dotai/setup.sh          # installs Claude/Codex/Pi + skills

# then, from the host, in the project folder:
cc           # Claude Code (personal) in the container
cca          # Claude Code (corporate-API profile)
cx           # Codex
pi           # Pi Harness (reaches host Ollama via host.docker.internal:11434)
```

## 🔐 Secrets — 1Password (host) → op/varlock (container)

No hand-rolled key injection. The **host** runs the 1Password app; its biometric
**agent.sock is mounted into the containers** (configured in dotai), where
`op`/`varlock` resolve `op://` refs at agent launch.

```bash
# host:
op item get "GitHub Token"      # ad-hoc lookup (1password-cli on host)
# in-container (provisioned by dotai):
vr <cmd>                         # = varlock run -- <cmd>  (inject resolved env)
```

- Enable in the **1Password app** ▸ Settings ▸ Developer: *Use the SSH agent*
  and *Integrate with 1Password CLI*. `SSH_AUTH_SOCK` is then auto-wired in
  `~/.zshrc`; `git push` over SSH "just works" with a biometric tap — and the
  same socket, mounted in, gives the in-container agents biometric `op`.
- `OP_ACCOUNT=rockofeyesoftware` is exported so `op` never prompts for account.
- Corporate Claude profile (`cca`) swaps `CLAUDE_CONFIG_DIR` inside the container
  and resolves its API key there from 1Password — adjust in `agents.zsh`/dotai.

---

## 🤖 Local LLM — Ollama (fallback / transient only)

```bash
olu qwen2.5-coder:32b     # pull a model
olr qwen2.5-coder:32b     # run it
olp                       # what's resident in unified memory RIGHT NOW
olrm qwen2.5-coder:32b    # evict it to reclaim memory
```

> **Memory budget (64GB unified):** dev stack ≈16GB + a 32b model ≈20GB resident
> + Claude Code. It fits, but the model and the containers share the same pool —
> **`olrm` the model when you're done** so it doesn't starve the stack. Local
> LLM memory is not free.

---

## 🧹 Maintenance & security

Goal: stay current (90% of "vuln-free" is just being up to date) and keep the
host == `Brewfile`.

### Weekly (run `upd`, or [`update-mac.sh`](../update-mac.sh))

```bash
upd                 # update brew + casks, prune cruft, check drift, scan CVEs
upd --prune         # also remove anything NOT in the Brewfile (strict clean host)
```

What it does: `brew update && brew upgrade --greedy` → `brew bundle check`
(drift) → `brew autoremove` + `cleanup` → `npm update -g` → report agent
versions → **`osv-scanner`** over your repos → list macOS updates.

### Automate background Homebrew upgrades (set once)

```bash
brew tap homebrew/autoupdate
brew autoupdate start 86400 --upgrade --cleanup --enable-notification
brew autoupdate status      # verify the launchd job
```

### Vulnerability scanning

Real CVEs live in **project lockfiles** (`composer.lock`, `package-lock.json`),
not the host. Point the scanner at your workspace:

```bash
osv-scanner scan --recursive ~/Code           # or set WORKSPACE_DIR for `upd`
```

- **1Password Watchtower** flags breached/weak/reused credentials — check it.
- **macOS patches:** `softwareupdate --install --all --restart`.
- Self-updating (no action needed): Claude Code (native installer), OrbStack,
  1Password, Ghostty's binary via `brew upgrade --cask`.

### Drift & snapshots

```bash
brew bundle check --file=Brewfile     # is everything in the Brewfile installed?
brew bundle cleanup --file=Brewfile   # show what's installed but NOT declared
brewdump                              # snapshot current installs back to Brewfile
brew leaves                           # top-level formulae (no other pkg needs them)
```

---

## 🔄 Re-applying / editing dotfiles

```bash
cd ~/Code/dr3dr3/dotfiles
git pull
./bootstrap-mac.sh            # idempotent: re-stows, installs anything new
# After editing a config, re-link just the dotfiles:
cd .dotfiles && stow --restow --target "$HOME" zsh ghostty starship
```

Reload without restarting: `exec zsh` (shell) · `Cmd+Shift+,` (Ghostty).

> First time on a new Mac? See **[SETUP.md](../SETUP.md)** for the full
> end-to-end runbook (host + per-project agents).
