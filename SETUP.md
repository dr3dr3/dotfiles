# 🆕 New Mac Setup — End-to-End Runbook

First-run guide for a fresh macOS (Apple Silicon) machine. The host is a
terminal-first **launcher**: it boots dev containers, holds secrets, and runs
the engine — **AI agents run inside the containers** (via
[dotai](https://github.com/dr3dr3/dotai)) for project work. Host copies of
Claude Code / Codex / herdr are installed as well, for the times there is no
container to work in (this dotfiles repo, host triage, a quick one-off).

- Daily commands once you're set up: **[docs/CHEATSHEET.md](docs/CHEATSHEET.md)**
- Local model + overnight agent batches: **[docs/LOCAL-AI.md](docs/LOCAL-AI.md)**
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
#    Homebrew → Brewfile → stow zsh/ghostty/starship → mise + @devcontainers/cli
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
4. **Handy** (voice dictation) — launch once, then `./scripts/setup-handy.sh`.
   Grant **Microphone** *and* **Accessibility** in Privacy & Security (the second
   fails silently), and download **Whisper Medium** in Handy ▸ Settings ▸ Models.
   Leave **Auto Submit off** — it would press Return on every dictation.
   Full runbook: [docs/HANDY.md](docs/HANDY.md).
5. *(optional)* Background Homebrew updates:
   ```bash
   brew trust domt4/autoupdate   # tap is declared in the Brewfile; brew
                                 # won't load the command until it is trusted
   brew autoupdate start 86400 --upgrade --cleanup --enable-notification
   ```
6. *(optional)* **Shells** — zsh is the default and the most wired-up, but Fish
   and Nushell carry the same host wiring (mise, 1Password agent, fzf/zoxide,
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
devcontainer --version && docker ps && mise current       # tooling live
op whoami                                                  # biometric 1Password
ls -ld ~/Code ~/host-share                                 # folders exist
```

---

## Phase 2 — Per-project terminal + agents · once per project

Herdr comes from **dotfiles**; agents come from **dotai**. Both are installed
inside each project's dev container. Two cases:

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
git clone https://github.com/dr3dr3/dotfiles.git /workspace/dotfiles
git clone https://github.com/dr3dr3/dotai.git /workspace/.ai/dotai
bash /workspace/dotfiles/scripts/setup-herdr.sh
bash /workspace/.ai/dotai/setup.sh          # Claude Code + Codex + varlock + Pi + gh
bash /workspace/.ai/dotai/scripts/setup.sh  # commands / skills / MCP wiring
claude auth login                           # or resolve creds via op/varlock
gh auth login
exit
```

### C. Drive agents from the host

In a Ghostty pane **in the project folder**:

```bash
devherd   # Herdr in the container; start `claude` in one of its panes
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
   env vars. The file is `~/.pi/agent/models.json` **inside the container** (this
   page previously said `~/.config/pi/models.json`, which is not where Pi looks).

   Don't hand-write it — generate it from the live host, so the model list cannot
   drift out of sync with what is actually pulled:
   ```bash
   ./scripts/setup-pi-ollama.sh --print            # inspect first
   ./scripts/setup-pi-ollama.sh roe-devcontainer   # install into a container
   ```
   The **script runs on the host**; the **file lands in the container**, on the
   AI volume at `~/.ai/pi/models.json` with `~/.pi/agent/models.json` symlinked
   at it, so a `dcb` rebuild does not eat it (see
   [docs/PERSISTENCE.md](docs/PERSISTENCE.md)).

   Re-run it after any `olu` / `olrm`. Then:
   ```bash
   pi --provider ollama --model qwen3.8:27b-mtp-q4_K_M --thinking off
   ```
   See [docs/CHEATSHEET.md › Local LLM](docs/CHEATSHEET.md) for which tag to pick
   and why the first call is slow and the rest are not.

   For unattended overnight work use **`pi-batch`**, not bare `pi`: it holds the
   Mac awake (this host sleeps after a minute idle), works on a throwaway branch
   it cannot push, and gates on your test suite. `pi-batch-review` is the morning
   read-out. See [docs/CHEATSHEET.md › Overnight agent runs](docs/CHEATSHEET.md).

---

## Local LLM — Ollama (fallback / transient only)

Installed as the **`brew "ollama"` formula** (headless CLI + server, no menu-bar
app) — the cleanest fit for a terminal-first, fallback-only tool. You control the
server lifecycle and reclaim memory when idle:

```bash
brew services start ollama     # background server (or: `ollama serve` in a pane)
olu qwen2.5-coder:32b          # pull a model   (olr = run, olp = ps, oll = list)
brew services stop ollama      # fully free memory when done
```

- **In-container agents already reach it — nothing to configure.** Ollama binds
  `127.0.0.1`, and OrbStack forwards `host.docker.internal` to the host loopback,
  so containers hit `http://host.docker.internal:11434` as-is. Verified
  2026-09-14 from both a throwaway `docker run alpine` and the roe-devcontainer,
  with the host's own LAN address refusing the connection.
  This page previously said a `0.0.0.0` bind was required. It is not, and setting
  one puts a **no-auth inference server on your LAN**. If you ever switch to
  Docker Desktop (its sandbox blocks host-loopback access) or need another
  machine to reach it, `o-expose` does that deliberately and `o-up` undoes it.
- **Which model:** `$PI_LOCAL_MODEL`, set in the shell configs. Do not assume the
  `-mlx` tags are fastest — they were the slowest thing measured here. See
  [docs/LOCAL-AI.md](docs/LOCAL-AI.md#which-model-and-why) for the numbers.
- **Memory budget:** a 27B model is ~19GB resident in unified memory and competes
  with the ~16GB dev stack. Models auto-unload after ~5 min idle
  (`OLLAMA_KEEP_ALIVE`); `o-stop <model>` frees it immediately, and
  `brew services stop ollama` (`o-down`) stops the server entirely.
  ⚠️ `olrm` is `ollama rm` — that **deletes** the model from disk, it is not an
  unload. Local LLM memory is not free.
- Prefer the native menu-bar app instead? Swap `brew "ollama"` →
  `cask "ollama-app"` in the [Brewfile](Brewfile).

---

## Terminal sessions — Zellij (optional)

Ghostty restores window/tab *layout* but not running processes. Zellij keeps
panes + processes alive across detach / Ghostty quit:

```bash
zjd                     # 2x2 host/container/agent/logs workspace (zellij --layout dev)
zj                      # attach/create the persistent "main" session
# ...run dcs / cc / dcl in panes, detach with Ctrl-o d, quit Ghostty...
zellij attach main      # everything's still running   (zjl = list sessions)
```

---

## Keeping it current

```bash
upd            # weekly: update brew + casks, prune, drift-check, CVE-scan ~/Code
upd --prune    # also remove anything not in the Brewfile (strict clean host)
```

Full maintenance reference: [docs/CHEATSHEET.md › Maintenance](docs/CHEATSHEET.md#-maintenance--security).
