# 🧾 macOS Dev Environment — Cheat Sheet

Terminal-first, container-centric workflow. The **host stays clean** (terminal,
shell, container engine, secrets, AI agents, single-binary CLI tools); **app
runtimes** (PHP, Node apps, MySQL, Redis…) live inside dev containers.

- Setup: [`bootstrap-mac.sh`](../bootstrap-mac.sh) · Packages: [`Brewfile`](../Brewfile) · Tool versions: [`mise config`](../.dotfiles/mise/.config/mise/config.toml)
- Aliases: [`aliases.zsh`](../.dotfiles/zsh/.config/zsh/aliases.zsh) · [`agents.zsh`](../.dotfiles/zsh/.config/zsh/agents.zsh)
- Maintenance: [`update-mac.sh`](../update-mac.sh)

---

## ⌨️ Daily aliases

| Alias | Command | Notes |
| --- | --- | --- |
| `devsh` | exec `bash -l` in this repo's devcontainer | **shell in — prefer this** (finds the repo from any subdir, starts it if down) |
| `devsh <cmd>` | `devcontainer exec … <cmd>` | run one command in-container |
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
devsh                     # shell in — boots the container first if it's down
devsh make doctor         # or run one command and come straight back
dcb                       # rebuild fresh if the image/config changed
```

### `devsh` — host terminal into any devcontainer

Ghostty (or any host shell) attached to the *same* container VS Code uses. It is
a script, not a shell function — `.dotfiles/bin/.local/bin/devsh`, stowed to
`~/.local/bin` — so zsh, fish and nushell all get one copy with no duplicated
logic.

- **cwd-based, no registry.** Walks up from `$PWD` to the nearest
  `.devcontainer/devcontainer.json`, so it works in *any* repo with a
  devcontainer, from any subdirectory. `dcu`/`dcs` only work at the repo root —
  from a subdir the CLI dies with a JS stack trace, because it does not search
  parents. Not in the project? `cdc rock-of-eye/local-dev-env && devsh`.
- **Starts a stopped container** via `devcontainer up`, then attaches. It never
  passes `--remove-existing-container` — that recreates the container and
  replays `postCreateCommand` (1115 lines for Rock of Eye). Use `dcb` when you
  genuinely want a rebuild. Verified 2026-09-04: restarting reuses the same
  container id and re-runs only `postStartCommand`.
- **Finds the container by label**, `devcontainer.local_folder`, not by name.
  Compose templates the name (`roe${ROE_INSTANCE}-devcontainer`) and
  `ROE_INSTANCE` lives in the *project's* `.env`, not your host shell — so
  guessing the name attaches to the wrong container on a multi-instance clone.

> **Why `devcontainer exec` and not `docker exec`.** `remoteEnv` from
> `devcontainer.json` is applied by the CLI at exec time, not baked into the
> image. Bare `docker exec` silently drops it. Rock of Eye's `Makefile` gates on
> `DEVCONTAINER` to export `COMPOSE_PROJECT_NAME` from the container's own
> compose labels; without it compose falls back to the *directory name* and
> `make up` addresses a different project — the "`roe-mysql` already in use"
> collision its comments warn about, or a silent second stack. Measured
> 2026-09-04 with `make -pn help` inside the container:
>
> | | `devcontainer exec` | bare `docker exec` |
> | --- | --- | --- |
> | `DEVCONTAINER` | `1` | unset |
> | `COMPOSE_PROJECT_NAME` | `roe-local-dev-env` | **unset** |
> | `OP_ACCOUNT` | `rockofeyesoftware` | unset |
>
> Costs ~0.5s of CLI startup. Worth it. `csh` remains the escape hatch for
> containers that have no devcontainer.json at all.

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

## 🤖 AI agents — containers by default, host copies as an exception

Project work runs the agents **inside** the project's dev container, installed
by [dotai](https://github.com/dr3dr3/dotai); the `cc`/`cca`/`cx`/`pi` wrappers
just `devcontainer exec` into it. That keeps agent activity on project code
sandboxed.

Host copies of `claude`, `codex` and `herdr` are also installed (declared in
the [`Brewfile`](../Brewfile)) for the times there is no container to work in —
this dotfiles repo itself, host triage, a quick one-off. **The names don't
collide:** bare `claude`/`codex` are the host binaries, the wrappers are the
container ones.

```bash
# one-time per project, from inside the container (dcs):
git clone https://github.com/dr3dr3/dotai.git /workspace/.ai/dotai
bash /workspace/.ai/dotai/setup.sh          # installs Claude/Codex/Pi + skills

# then, from the host, in the project folder — CONTAINER agents:
cc           # Claude Code (personal) in the container
cca          # Claude Code (corporate-API profile)
cx           # Codex
pi           # Pi Harness (reaches host Ollama via host.docker.internal:11434)

# HOST agents (no container needed):
claude       # host Claude Code
codex        # host Codex
herdr        # agent multiplexer — `herdr server` to start it
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
brew trust domt4/autoupdate   # the tap is declared in the Brewfile; brew
                              # refuses to load the command until it is trusted
brew autoupdate start 86400 --upgrade --cleanup --enable-notification
brew autoupdate status      # verify the launchd job
```

> The launchd job uses `StartInterval`, which does **not** fire while the Mac is
> asleep and does not aggressively catch up afterwards — so "daily" can silently
> stretch to a week or more. It is a drift-reducer, not a guarantee; keep running
> `upd` yourself. Check the last real run with:
> `ls -l ~/Library/Logs/com.github.domt4.homebrew-autoupdate/*.out`

### Vulnerability scanning

Real CVEs live in **project lockfiles** (`composer.lock`, `package-lock.json`),
not the host. Point the scanner at your workspace:

```bash
osv-scanner scan --recursive ~/Code           # or set WORKSPACE_DIR for `upd`
```

- **1Password Watchtower** flags breached/weak/reused credentials — check it.
- **macOS patches:** `softwareupdate --install --all --restart`.
- Self-updating (no action needed): OrbStack, 1Password, Ghostty's binary via
  `brew upgrade --cask`.
- **Claude Code is a special case:** now declared as the `claude-code` cask, but
  it *also* self-updates in place. The cask sets no `auto_updates`, so brew's
  pinned version drifts from what's installed and it lingers in `brew outdated`.
  Cosmetic — leave it. `brew upgrade --cask claude-code` just re-syncs the pin.

### Editing the package set (add / remove software)

There is exactly **one** Brewfile on this machine: `~/Code/dr3dr3/dotfiles/Brewfile`.
`HOMEBREW_BUNDLE_FILE` points at it (set in the zsh/fish/nushell configs), so
every `brew bundle` subcommand targets it **from any directory** — no `--file`
needed. Edit the file, then apply:

```bash
brew bundle                  # install everything declared (additive; never removes)
brew bundle cleanup          # DRY RUN: what's installed but no longer declared
brew bundle cleanup --force  # actually uninstall those
```

`brew bundle` alone will **not** remove a package you deleted from the Brewfile —
you need the `cleanup` pass. The full "make the host match the file" round trip:

```bash
brew bundle && ./update-mac.sh --prune
```

> **Caveat:** `HOMEBREW_BUNDLE_FILE` wins over a `./Brewfile` in the current
> directory. If you ever work in a project shipping its own Brewfile, pass
> `--file=./Brewfile` explicitly. `bootstrap-mac.sh` / `update-mac.sh` are
> unaffected — they always pass `--file`.

### Drift & snapshots

```bash
brew bundle check            # is everything in the Brewfile installed?
brew bundle cleanup          # show what's installed but NOT declared
brew leaves                  # top-level formulae (no other pkg needs them)
brew list --cask             # installed casks
```

> ⚠️ `brewdump` (`brew bundle dump --force`) **overwrites** the Brewfile with a
> bare generated list, destroying its comments and the optional-groups block.
> Use it only to *discover* drift, dumping somewhere scratch first:
> `brew bundle dump --file=/tmp/Brewfile.now && diff /tmp/Brewfile.now Brewfile`

---

## 📌 Tool versions with mise

[mise](https://mise.jdx.sh) owns runtimes and per-project tool versions. Its
host config is a stow package —
[`.dotfiles/mise/.config/mise/config.toml`](../.dotfiles/mise/.config/mise/config.toml)
— and is the declarative peer to the [`Brewfile`](../Brewfile).

### Which manifest does a tool belong in?

Keep this boundary sharp, or the two manifests fight:

| | `Brewfile` | `mise` |
|---|---|---|
| **Scope** | Machine-wide, ONE version | Per-project, many versions |
| **Owns** | System tools, GUI casks, daemons: `git`, `gh`, `ripgrep`, `ghostty`, `orbstack`, `1password`, `claude-code`, `codex` | Language runtimes, version-pinned CLIs, tools from npm/cargo/go/aqua |
| **Apply** | `brew bundle` | `mise install` |

**Rule of thumb:** if the tool should exist once and always → Homebrew. If its
version depends on what you're working on → mise.

Do **not** migrate working Brewfile entries over for its own sake. `jq` and
`yq` are both in the mise registry but are single-version machine-wide tools —
they stay in the Brewfile.

### Daily commands

```bash
mise ls              # installed / active versions and where each came from
mise current         # what's active in this directory
mise use -g node@lts # set a HOST default — edits the stowed config in place
mise use node@22     # pin for THIS project — writes ./mise.toml
mise install         # install everything the active configs declare
mise upgrade         # re-resolve `lts`-style pins to newer releases
mise doctor          # config resolution, dirs, backends — start debugging here
mise tasks           # list tasks declared in mise.toml
mise run <task>      # run one
```

> `mise use -g` rewrites the **stowed** config. Verified 2026-09-03 that mise
> writes *through* the stow symlink (it does not replace it) and preserves the
> file's comments — so global tool changes land in the repo and show up in
> `git status`. Commit them.

### Per-project pins live in the PROJECT repo

A `mise.toml` at a project root carries that project's tool pins plus an
`[env]` block. **Not in this repo** — those files hold real cluster IPs and
paths that shouldn't be committed here.

This is the intended home for the Kubernetes/Talos tooling left commented out
in the Brewfile, and it fixes `$TALOSIP` / `$TALOSCONF` — referenced by the
`ta` / `tm` fish abbreviations but never defined anywhere:

```toml
# <project>/mise.toml
[tools]
kubectl  = "1.31"     # aqua:kubernetes/kubernetes/kubectl
helm     = "latest"   # aqua:helm/helm
k9s      = "latest"   # aqua:derailed/k9s
talosctl = "latest"   # aqua:siderolabs/talos

[env]
TALOSIP   = "10.0.0.5"
TALOSCONF = "{{config_root}}/talosconfig"
```

Two reasons this beats uncommenting them in the Brewfile:

- **Scoped shadowing.** A project-local `kubectl` wins only inside that
  project. `brew "kubectl"` would shadow OrbStack's `/usr/local/bin/kubectl`
  *everywhere*, since `/opt/homebrew/bin` precedes it in `PATH`.
- **Per-cluster versions.** Pin `kubectl` to whatever each cluster runs.

New config files need a one-time `mise trust` before mise will load them.

### Backends — for tools outside the registry

`mise registry` lists ~1000 tools. For anything absent, install from source:

```bash
mise use -g npm:@devcontainers/cli   # an npm package as a global CLI
mise use -g cargo:ripgrep            # from crates.io
mise use -g ubi:owner/repo           # a GitHub release binary
```

Available: `aqua`, `asdf`, `cargo`, `conda`, `core`, `dotnet`, `forgejo`,
`gem`, `github`, `gitlab`, `go`, `npm`, `pipx`, `pkgx`, `spm`, `http`, `s3`,
`ubi`, `vfox`.

### Gotchas

- **Interactive shells use `activate`; scripts use shims.** `.zshrc` and
  `config.fish` call `mise activate` (a prompt hook). `bootstrap-mac.sh` and
  `update-mac.sh` instead put `~/.local/share/mise/shims` on `PATH`, because
  the `activate` hook does nothing in a non-interactive script.
- **Nushell deliberately differs.** It prepends the shims dir rather than using
  `mise activate nu`, which bakes a literal `PATH` snapshot into its generated
  script and can freeze a stale `PATH`. The reasoning is in `nushell/config.nu`.
- **Homebrew formulae ignore mise's Node.** A formula needing Node depends on
  Homebrew's own `node`, with its shebang rewritten to that absolute path.
  mise's Node only serves what you install through mise — currently just
  `@devcontainers/cli`.

---

## 🔄 Re-applying / editing dotfiles

```bash
cd ~/Code/dr3dr3/dotfiles
git pull
./bootstrap-mac.sh            # idempotent: re-stows, installs anything new
# After editing a config, re-link just the dotfiles:
cd .dotfiles && stow --restow --target "$HOME" zsh ghostty starship fish nushell zellij mise
```

> **After installing any app with shell integration, run `git status` here.**
> The stow packages are folded symlinks, so installers can write straight into
> this repo — it has happened three times (fish, OrbStack, Unsloth). See
> [README › Folded symlinks](../README.md#-folded-symlinks-tools-can-write-into-this-repo)
> for the triage rule.

> ⚠️ **Nushell on macOS needs more than `stow`.** Nushell reads its config from
> the platform-native dir — `~/Library/Application Support/nushell/` — not
> `~/.config/nushell/`, which is where the stow package puts it (correct for
> Linux/containers). `bootstrap-mac.sh` step 3a symlinks `config.nu` and
> `env.nu` from the native dir into the stowed package to bridge that.
> **Failure mode is silent:** `nu` starts with defaults, every alias/def/env in
> `config.nu` is inert, and there is no error. If nushell looks unconfigured:
>
> ```bash
> nu -c '$nu.config-path'   # where nushell actually looks
> nu -e 'scope commands | where name == "brewdump" | length | print; exit'
> ```
>
> That must print `1`. Use `-e`, **not** `-c` — `nu -c` skips config files
> entirely, so it will report `0` even when everything is wired correctly.

Reload without restarting: `exec zsh` (shell) · `Cmd+Shift+,` (Ghostty).

> First time on a new Mac? See **[SETUP.md](../SETUP.md)** for the full
> end-to-end runbook (host + per-project agents).
