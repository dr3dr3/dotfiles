# =============================================================================
# Brewfile — André Dreyer's macOS dev environment (Apple Silicon, M5)
# -----------------------------------------------------------------------------
# Terminal-first, orchestration-oriented setup. AI CLI agents do most editing
# inside isolated dev containers; a UI editor is launched Just-In-Time only for
# inspection/diffing.
#
# Apply with:   brew bundle              (HOMEBREW_BUNDLE_FILE points here, so no
#                                         --file and any working directory is fine)
# Remove drift: brew bundle cleanup      (dry run) then --force to uninstall
#               NOTE: `brew bundle` is additive — deleting a line here does NOT
#               uninstall it. The cleanup pass is what applies removals.
# Or via:       ./bootstrap-mac.sh   (installs Homebrew + this + dotfiles)
#
# PEER MANIFEST: .dotfiles/mise/.config/mise/config.toml declares tool VERSIONS
#               (runtimes, per-project pins). This file is machine-wide and
#               single-version; mise is per-project and multi-version. Rule of
#               thumb: exists once and always → here. Version depends on what
#               you're working on → mise. See docs/CHEATSHEET.md › mise.
#
# Validated against formulae.brew.sh / official repos (June 2026).
# The host is a LAUNCHER, not a workstation: it boots containers, holds secrets,
# and runs the engine. AI coding agents run *inside* the dev containers by
# default (provisioned by dotai, github.com/dr3dr3/dotai) so agent activity on
# project code stays sandboxed — with a deliberate exception for host copies of
# Claude Code / Codex / herdr, for the times there is no container to work in.
# See the "AI coding agents" section below.
#
# NOTE: the devcontainer CLI IS declared here (see "Container engine" below).
#       It used to be an npm global installed by bootstrap-mac.sh; moved to brew
#       on 2026-09-04 so it lives in the declarative set like everything else.
# =============================================================================

# --- Taps --------------------------------------------------------------------
tap "dmno-dev/tap"          # varlock (secrets/env loader)
tap "domt4/autoupdate"      # `brew autoupdate` launchd job (background upgrades).
                            # Declared so `brew bundle cleanup --force` /
                            # `update-mac.sh --prune` don't untap it and silently
                            # kill the job. Needs `brew trust domt4/autoupdate`
                            # before the command will load — see bootstrap-mac.sh.

# --- Core CLI ----------------------------------------------------------------
brew "git"                  # newer than the macOS system git
brew "gh"                   # GitHub CLI (auth, PRs, gh api)
brew "stow"                 # GNU Stow — symlinks the dotfiles in this repo
brew "starship"             # cross-shell prompt (config shared with containers)

# --- Shells (zsh is the wired-up default; fish + nu are alt drivers) ----------
# Single self-contained binaries, no daemons. fish pulls pcre2, nushell pulls
# openssl@3 — both tiny / already present. Host wiring (mise, 1Password agent,
# fzf/zoxide, devcontainer + agent aliases) is mirrored into all three shells.
brew "fish"                 # config: .dotfiles/fish
brew "nushell"              # config: .dotfiles/nushell  (binary: `nu`)

# --- Modern CLI productivity (single binaries, no daemons — host stays clean) -
brew "ripgrep"              # rg — fast code search (agents/editors lean on it)
brew "fd"                   # fast, ergonomic `find`
brew "fzf"                  # fuzzy finder — powers Ctrl-R/Ctrl-T in zsh
brew "bat"                  # `cat` with syntax highlight + git gutter
brew "eza"                  # modern `ls` (icons, git status)
brew "zoxide"               # `z` — jump to frequent dirs (terminal-first nav)
brew "git-delta"            # gorgeous git/diff pager — the JIT diffing surface
brew "jq"                   # JSON wrangling (devcontainer.json, gh api)
brew "yq"                   # YAML wrangling (docker-compose, configs)
brew "lazygit"             # TUI git client for quick host-side history/staging
brew "wget"                 # the one curl can't always replace

# --- Runtime versions (host stays clean; Node only for local CLI tooling) ----
brew "mise"                 # polyglot runtime version manager — replaced fnm
                            # (2026-09-03). Owns host Node, pinned to LTS with
                            # `mise use -g node@lts` (recorded in
                            # ~/.config/mise/config.toml). Host Node is for CLI
                            # tools only (@devcontainers/cli, etc.), NOT app
                            # runtimes — those live in the dev containers.
                            # Activated in all three shells; auto-switches on cd
                            # for .node-version/.nvmrc/.tool-versions/mise.toml.
                            # Extend to python/go/etc. when a need shows up.

# --- Container engine + dev containers --------------------------------------
brew "devcontainer"        # @devcontainers/cli — the reference implementation
                           # (containers.dev). The one host tool needed to boot
                           # a devcontainer without VS Code, and what `devsh`
                           # (.dotfiles/bin) shells through. Was an npm global
                           # under mise's node until 2026-09-04; that install
                           # dies whenever `mise upgrade` re-resolves node@lts
                           # to a new major, and sat outside brew bundle check.
                           # Pulls brew's `node` as a dependency — harmless,
                           # mise still wins on PATH (.zshrc runs brew shellenv
                           # before `mise activate`, so its shims land first).
                           # Do NOT also install the npm global: mise's node bin
                           # dir precedes /opt/homebrew/bin, so it would shadow
                           # this one and you'd be running the wrong copy.
cask "orbstack"            # Docker/Compose-compatible engine, faster on macOS.
                            # Drop-in for the team's Docker Desktop standard —
                            # same socket/CLI/compose, no devcontainer changes.
                            # (@devcontainers/cli itself is npm — see bootstrap.)
brew "lazydocker"          # TUI dashboard for containers/logs/compose (OrbStack)
brew "dive"                # inspect image layers when debugging a Dockerfile

# --- Terminal ----------------------------------------------------------------
cask "ghostty"             # native GPU terminal; config in dotfiles/ghostty
brew "zellij"              # terminal multiplexer — persistent sessions that
                            # survive Ghostty restarts/detach + reproducible
                            # layouts. Config + dev layout in dotfiles/zellij.
                            # (Reattach with `zj`; 2x2 workspace with `zjd`.)

# --- AI coding agents (host copies — deliberate exception) -------------------
# The default is still container-first: agents are installed *inside* the dev
# containers by dotai (github.com/dr3dr3/dotai), so agent activity on project
# code stays sandboxed. Launch those with `cc` / `cx` / `pi` (devcontainer
# exec) — see zsh/agents.zsh.
# The host copies below are an exception (2026-09-03) for the occasions when
# there is no container to work in: this dotfiles repo itself, host triage, a
# quick one-off. No command collision — the bare names are the host binaries,
# the `cc`/`cx` wrappers still reach into the container.
cask "claude-code"         # Claude Code CLI — installs the `claude` binary.
                           # Heads-up: Claude Code also self-updates in place
                           # and this cask declares no `auto_updates`, so the
                           # brew-pinned version drifts from what's actually
                           # installed and shows up in `brew outdated`.
                           # Cosmetic — don't chase it. (`claude-code@latest`
                           # tracks releases faster with far less install
                           # volume; stable chosen deliberately.)
cask "codex"               # OpenAI Codex CLI — `codex` binary plus bash/zsh/
                           # fish completions (github.com/openai/codex).
                           # NOT `codex-app`: discontinued upstream, brew
                           # disables it 2027-07-12.
brew "herdr"               # agent multiplexer for the two above (herdr.dev).
                           # The one daemon declared in this file: start on
                           # demand with `herdr server`, or as a service via
                           # `brew services start herdr`. Stop the service to
                           # reclaim memory when idle.

# --- Local LLM — inference (ollama) + fine-tuning (unsloth) ------------------
# Both are on-demand / transient, NOT primary drivers. Unified memory is the
# binding constraint on this host, not disk — see the heads-up on each.
brew "ollama"              # CLI + server (headless; no menu-bar app). Cleaner for
                            # a terminal-first, fallback-only tool: start on demand
                            # with `ollama serve` or `brew services start ollama`,
                            # and stop the service to reclaim memory when idle.
                            # `oll`/`olp`/`olr` aliases drive it. (Swap to
                            # cask "ollama-app" if you want the native menu-bar app.)
                            # For in-container agents to reach it via
                            # host.docker.internal it must bind 0.0.0.0 — use
                            # the `o-up` alias. The exported OLLAMA_HOST covers
                            # only a shell-started `ollama serve`; the launchd
                            # service does NOT inherit it (see zsh/env.zsh).
                            # o-up is not persistent across reboot.
                            # Heads-up: a 32b model is ~20GB resident in unified
                            # memory and competes with the ~16GB dev stack —
                            # local LLM memory is NOT free.
cask "unsloth"             # Unsloth Desktop — GUI for Unsloth Studio: local
                           # fine-tuning plus MLX/GGUF inference, Metal-
                           # accelerated on Apple Silicon (arm64 + macOS only).
                           # Self-updating (auto_updates), so brew neither
                           # fights it nor nags in `brew outdated` — unlike the
                           # claude-code cask above.
                           #
                           # NOT self-contained. The .app is a 59MB THIN
                           # INSTALLER (Resources = icon.icns + install.sh); on
                           # first launch it provisions its OWN Python 3.13
                           # venv via uv under ~/.unsloth, plus llama.cpp and
                           # whisper.cpp. So it needs no Python from us and is
                           # unaffected by this host's python3 being 3.14.x
                           # (Unsloth requires >=3.11,<3.14) — it simply brings
                           # a compliant interpreter of its own. Do NOT add
                           # python to the mise config on its account.
                           # It also drops a CLI at ~/.local/bin/unsloth, which
                           # is on PATH.
                           #
                           # UNINSTALL SURFACE — ~2.9GB, none of it brew-owned.
                           # `brew uninstall --cask unsloth` removes the .app
                           # and leaves ALL of the following behind:
                           #   ~/.unsloth                          2.5G
                           #   ~/.cache/huggingface                322M (models)
                           #   ~/Library/WebKit/ai.unsloth.studio  1.2M
                           #   ~/Library/Application Support/ai.unsloth.studio
                           #   ~/.local/bin/unsloth
                           # (~/.cache/huggingface is shared with any other HF
                           # tooling — check before deleting that one.)
                           #
                           # Memory: fine-tuning is heavier than the ollama note
                           # above. This host has 64GB unified, so there is real
                           # headroom, but stop containers for large runs.
                           # Beta (0.1.x); cask was days old when added.

# --- Secrets (1Password — do NOT hand-roll key injection) --------------------
# The host runs the 1Password app, which exposes the SSH agent + biometric CLI.
# Its agent.sock is *mounted into* the containers (configured in dotai), so the
# agents resolve op:// references in-container. varlock therefore lives in the
# container too (installed by dotai), NOT on the host.
cask "1password"           # desktop app: unlocks SSH agent + CLI biometrics
cask "1password-cli"       # the `op` command on the host (handy for lookups)
# brew "dmno-dev/tap/varlock"  # optional on host — only if you wrap host-side
                               # commands (e.g. `varlock run -- devcontainer up`).
                               # Primary install is in-container via dotai.

# --- Maintenance & security --------------------------------------------------
brew "mas"                  # Mac App Store CLI — declarative App Store installs
brew "osv-scanner"          # scan composer.lock / package-lock.json for CVEs.
                            # Run against the project repos (where real vulns
                            # live), not just the host. See update-mac.sh + docs.

# --- Fonts -------------------------------------------------------------------
cask "font-jetbrains-mono-nerd-font"  # required by the Ghostty config

# =============================================================================
# Optional groups — uncomment what you need. Kept off by default to honour the
# "clean host" goal; most of this can also live inside a dev container.
# =============================================================================

# --- Kubernetes / Talos (you have aliases for these in the fish config) ------
# brew "kubectl"            # k8s CLI
# brew "k9s"                # k8s TUI
# brew "helm"               # charts
# brew "siderolabs/talos/talosctl"  # Talos Linux

# --- API / HTTP poking against the Laravel backends --------------------------
# brew "httpie"           # friendly HTTP client
# brew "curlie"           # curl + httpie ergonomics

# --- All-in-one updater (alternative to update-mac.sh; see docs) -------------
# brew "topgrade"         # updates brew + npm globals + mise + more in one shot
