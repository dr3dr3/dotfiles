# =============================================================================
# Brewfile — André Dreyer's macOS dev environment (Apple Silicon, M5)
# -----------------------------------------------------------------------------
# Terminal-first, orchestration-oriented setup. AI CLI agents do most editing
# inside isolated dev containers; a UI editor is launched Just-In-Time only for
# inspection/diffing.
#
# Apply with:   brew bundle --file=Brewfile
# Or via:       ./bootstrap-mac.sh   (installs Homebrew + this + dotfiles)
#
# Validated against formulae.brew.sh / official repos (June 2026).
# The host is a LAUNCHER, not a workstation: it boots containers, holds secrets,
# and runs the engine. AI coding agents (Claude Code, Codex, Pi Harness) are
# deliberately NOT installed here — they run *inside* the dev containers for
# isolation/safety, provisioned by the dotai repo (github.com/dr3dr3/dotai).
#
# NOTE: @devcontainers/cli is intentionally not here either — it's npm-only and
#       installed in bootstrap-mac.sh (it's the one host tool needed to boot the
#       containers the agents live in).
# =============================================================================

# --- Taps --------------------------------------------------------------------
tap "dmno-dev/tap"          # varlock (secrets/env loader)

# --- Core CLI ----------------------------------------------------------------
brew "git"                  # newer than the macOS system git
brew "gh"                   # GitHub CLI (auth, PRs, gh api)
brew "stow"                 # GNU Stow — symlinks the dotfiles in this repo
brew "starship"             # cross-shell prompt (config shared with containers)

# --- Shells (zsh is the wired-up default; fish + nu are alt drivers) ----------
# Single self-contained binaries, no daemons. fish pulls pcre2, nushell pulls
# openssl@3 — both tiny / already present. Host wiring (fnm, 1Password agent,
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

# --- Node toolchain (host stays clean; Node only for local CLI tooling) ------
brew "fnm"                  # Fast Node Manager. Host Node is for CLI tools only
                            # (@devcontainers/cli, etc.), NOT app runtimes —
                            # those live inside the dev containers.

# --- Container engine + dev containers --------------------------------------
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

# --- AI coding agents --------------------------------------------------------
# NONE on the host — by design. Claude Code, Codex, and Pi Harness are installed
# *inside* the dev containers via dotai (github.com/dr3dr3/dotai) so untrusted
# agent activity is sandboxed away from the host. Launch them with the host-side
# `cc` / `cx` / `pi` wrappers (devcontainer exec) — see zsh/agents.zsh.

# --- Local LLM (fallback / transient only — NOT the primary driver) ----------
brew "ollama"              # CLI + server (headless; no menu-bar app). Cleaner for
                            # a terminal-first, fallback-only tool: start on demand
                            # with `ollama serve` or `brew services start ollama`,
                            # and stop the service to reclaim memory when idle.
                            # `oll`/`olp`/`olr` aliases drive it. (Swap to
                            # cask "ollama-app" if you want the native menu-bar app.)
                            # To let in-container agents reach it via
                            # host.docker.internal, run the server with
                            # OLLAMA_HOST=0.0.0.0:11434.
                            # Heads-up: a 32b model is ~20GB resident in unified
                            # memory and competes with the ~16GB dev stack —
                            # local LLM memory is NOT free.

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
# brew "topgrade"         # updates brew + npm globals + fnm + more in one shot
