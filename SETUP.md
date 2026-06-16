# 🆕 New Mac Setup — End-to-End Runbook

First-run guide for a fresh macOS (Apple Silicon) machine. The host is a
terminal-first **launcher**: it boots dev containers, holds secrets, and runs
the engine — **AI agents run inside the containers** (via
[dotai](https://github.com/dr3dr3/dotai)), never on the host.

- Daily commands once you're set up: **[docs/CHEATSHEET.md](docs/CHEATSHEET.md)**
- What gets installed: **[Brewfile](Brewfile)** · **[bootstrap-mac.sh](bootstrap-mac.sh)**

---

## 📁 Repo layout convention

All cloned repos live under `~/Code/<org-or-username>/<repo-name>`:

```
~/Code/
├── dr3dr3/
│   ├── dotfiles/        ← this repo (host setup)
│   └── dotai/           ← agent provisioning for containers
└── rock-of-eye/
    └── ai-context/      ← work repos under the org name
```

- Clone with the helper (enforces the layout, SSH + github.com by default):
  ```bash
  clone dr3dr3/dotai          # → ~/Code/dr3dr3/dotai, then cd's in
  clone rock-of-eye/ai-context
  ```
- Jump around with `cdc dr3dr3/dotfiles` (or `cdc` → `~/Code`).
- `bootstrap-mac.sh` creates `~/Code` (and `~/host-share`) for you.

> **Host vs container paths:** `~/Code/...` is the **host** layout. Inside a dev
> container the project is mounted at `/workspace`, so in-container clones (e.g.
> dotai) use `/workspace/.ai/dotai`. Don't confuse the two.

---

## Phase 1 — Host setup (dotfiles) · once per machine

```bash
# 1. Clone this repo to its canonical location
git clone https://github.com/dr3dr3/dotfiles.git ~/Code/dr3dr3/dotfiles
cd ~/Code/dr3dr3/dotfiles

# 2. Run the idempotent bootstrap:
#    Homebrew → Brewfile → stow zsh/ghostty/starship → fnm + @devcontainers/cli
#    → create ~/Code and ~/host-share
./bootstrap-mac.sh
#    └─ Homebrew will prompt to install Xcode Command Line Tools — accept.

# 3. Load the freshly-stowed shell
exec zsh
```

### Manual follow-ups (can't be scripted)

1. **1Password** — open, sign in, then **Settings ▸ Developer ▸** enable
   **"Use the SSH agent"** + **"Integrate with 1Password CLI"**.
   ⚠️ Do this **before booting any container** — the `agent.sock` must exist, or
   Docker bind-mounts a broken directory in its place.
2. **OrbStack** — launch once to grant privileges. `docker` / `docker compose`
   then work against any devcontainer stack.
3. **Ghostty** — set it as your default terminal (the config is already linked).
4. *(optional)* Background Homebrew updates:
   ```bash
   brew tap homebrew/autoupdate
   brew autoupdate start 86400 --upgrade --cleanup --enable-notification
   ```
5. *(optional)* **Shells** — zsh is the default and the most wired-up, but Fish
   and Nushell carry the same host wiring (fnm, 1Password agent, fzf/zoxide,
   the `dc*`/`cc`/`oll`/`clone` shortcuts). To make one the login shell:
   ```bash
   which fish | sudo tee -a /etc/shells   # register it once (fish/nu)
   chsh -s "$(which fish)"                 # or $(which nu)
   ```
   Or just run `fish` / `nu` ad-hoc from zsh. Two Nushell caveats: `fzf`
   key-bindings aren't native (call `fzf` directly, or use zoxide's `zi`), and
   `ls`/`cat` stay Nu built-ins (not aliased to eza/bat).

### Verify the host

```bash
brew bundle check --file=~/Code/dr3dr3/dotfiles/Brewfile   # all green
devcontainer --version && docker ps && fnm current         # tooling live
op whoami                                                  # biometric 1Password
ls -ld ~/Code ~/host-share                                 # folders exist
```

---

## Phase 2 — Per-project agents (dotai) · once per project

Agents are installed **inside** each project's dev container. Two cases:

### A. The container needs the host wiring

The project's `.devcontainer/devcontainer.json` must mount the 1Password
`agent.sock`, `~/host-share`, and set `OLLAMA_HOST`. dotai's **own** container
already includes this; for other projects, copy the `mounts` / `remoteEnv`
snippet from the [dotai README](https://github.com/dr3dr3/dotai#macos-host-integration-orbstack).

### B. Install + wire the agents

```bash
# from the host, in the project repo:
clone rock-of-eye/ai-context          # or cd into an existing ~/Code/... repo
dcu                                   # devcontainer up (boot the stack)
dcs                                   # shell into the container

# INSIDE the container (project is at /workspace):
git clone https://github.com/dr3dr3/dotai.git /workspace/.ai/dotai
bash /workspace/.ai/dotai/setup.sh          # Claude Code + Codex + varlock + Pi + gh
bash /workspace/.ai/dotai/scripts/setup.sh  # commands / skills / MCP wiring
claude auth login                           # or resolve creds via op/varlock
gh auth login
exit
```

### C. Drive agents from the host

In a Ghostty pane **in the project folder**:

```bash
cc        # Claude Code (personal subscription) in the container
cca       # Claude Code (corporate-API profile)
cx        # Codex
pi        # Pi Harness
```

These `devcontainer exec` into the project's container — nothing runs on the host.

---

## Before your first agent run — two adjustments

1. **Corporate Claude profile (`cca`)** — edit the `op://…/corporate-key`
   reference and the corporate `CLAUDE_CONFIG_DIR` in
   [agents.zsh](.dotfiles/zsh/.config/zsh/agents.zsh) to match your real vault item.
2. **Pi + local model (optional)** — Pi has no built-in permission system (the
   container is its sandbox) and reaches local models via a `models.json`, not
   env vars. On the host: `olu qwen2.5-coder:32b`. In the container, add
   `~/.config/pi/models.json` pointing Pi at the host Ollama,
   `http://host.docker.internal:11434/v1`.

---

## Keeping it current

```bash
upd            # weekly: update brew + casks, prune, drift-check, CVE-scan ~/Code
upd --prune    # also remove anything not in the Brewfile (strict clean host)
```

Full maintenance reference: [docs/CHEATSHEET.md › Maintenance](docs/CHEATSHEET.md#-maintenance--security).
