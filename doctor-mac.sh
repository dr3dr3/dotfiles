#!/usr/bin/env bash
# =============================================================================
# doctor-mac.sh — assert the LIVE host matches what this repo declares.
#
# Read-only: this script never changes anything. It answers one question —
# "is the machine actually in the state these dotfiles describe?" — because the
# expensive failures in this repo have all been silent ones, where the files
# were correct and the running system quietly disagreed:
#
#   * the nushell config had NEVER loaded on macOS (wrong config dir), with no
#     error to hint at it
#   * `brew autoupdate` could not run at all (tap untrusted), while the launchd
#     job kept working, so nothing looked wrong
#   * Ollama sat on 127.0.0.1 despite an exported OLLAMA_HOST, making it
#     unreachable from containers — the exact thing the export existed to fix
#   * an app installer wrote a hardcoded /Users/<name>/ path into a tracked file
#
# None of those are catchable by linting the repo. They need assertions against
# the machine, which is what this is.
#
# Usage:
#   ./doctor-mac.sh          # run all checks
#   ./doctor-mac.sh -q       # only warnings and failures
#
# Exit status: 1 if any check FAILED, 0 otherwise (warnings do not fail).
# Run automatically as the last step of ./update-mac.sh (aliased `upd`).
# =============================================================================
set -uo pipefail   # deliberately NOT -e: every check must run, even after one fails

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$REPO_DIR/.dotfiles"
QUIET=0
[[ "${1:-}" == "-q" ]] && QUIET=1

PASSED=0; WARNED=0; FAILED=0

# --- output ------------------------------------------------------------------
section() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
pass() { PASSED=$((PASSED+1)); [[ $QUIET -eq 1 ]] || printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { WARNED=$((WARNED+1)); printf '  \033[1;33m!\033[0m %s\n' "$*"; }
fail() { FAILED=$((FAILED+1)); printf '  \033[1;31m✗\033[0m %s\n' "$*"; }
hint() { printf '      \033[2m%s\033[0m\n' "$*"; }

[[ "$(uname -s)" == "Darwin" ]] || { echo "doctor-mac.sh targets macOS."; exit 1; }
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
export HOMEBREW_NO_AUTO_UPDATE=1

# A deliberately sanitised environment for the shell checks. Inheriting this
# script's env would mask exactly the bugs we care about: a var set here could
# make a shell look configured when its own config never ran.
CLEAN_PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
clean() { env -i HOME="$HOME" TERM=xterm-256color PATH="$CLEAN_PATH" "$@" 2>/dev/null; }

# =============================================================================
section "Shells load their own config"
# The nushell bug: config.nu was valid and stowed, but nushell reads a different
# directory on macOS, so none of it ran. Each shell is asked for a definition
# that exists ONLY in this repo's config — proof the file was sourced, rather
# than proof the shell starts.

if [[ "$(clean zsh -ic 'alias brewdump >/dev/null 2>&1 && echo y')" == *y* ]]; then
  pass "zsh    — aliases.zsh sourced (brewdump defined)"
else
  fail "zsh    — aliases.zsh did NOT load"
  hint "check the *.zsh drop-in loop in ~/.zshrc"
fi

if [[ "$(clean zsh -ic 'echo "${HOMEBREW_BUNDLE_FILE:-}"')" == *"$REPO_DIR/Brewfile"* ]]; then
  pass "zsh    — env.zsh sourced (HOMEBREW_BUNDLE_FILE points at this repo)"
else
  fail "zsh    — env.zsh did NOT load, or HOMEBREW_BUNDLE_FILE is wrong"
fi

if [[ "$(clean fish -ic 'functions -q cdc && echo y')" == *y* ]]; then
  pass "fish   — config.fish sourced (cdc defined)"
else
  fail "fish   — config.fish did NOT load"
fi

# NOTE: `nu -c` skips config files entirely and would report 0 even on a
# correctly wired host. `-e` runs after config load. This trap cost real time.
if [[ "$(clean nu -e 'scope commands | where name == "brewdump" | length | print; exit')" == *1* ]]; then
  pass "nu     — config.nu sourced (brewdump defined)"
else
  fail "nu     — config.nu did NOT load"
  hint "nushell reads \$nu.config-path, which on macOS is NOT ~/.config/nushell"
  hint "re-run ./bootstrap-mac.sh (step 3a bridges it); see README › Repo Structure"
fi

# =============================================================================
section "Stow links resolve into this repo"
check_link() {  # $1 = path under $HOME, $2 = expected substring
  local target="$HOME/$1"
  if [[ ! -e "$target" ]]; then fail "$1 — missing"; return; fi
  local real; real="$(cd "$(dirname "$target")" 2>/dev/null && realpath "$target" 2>/dev/null)"
  if [[ "$real" == *"$2"* ]]; then pass "$1"; else
    fail "$1 — resolves outside the repo ($real)"
    hint "a real file may be shadowing the stow link; see bootstrap-mac.sh step 3"
  fi
}
check_link ".zshrc"                 "$STOW_DIR/zsh"
check_link ".config/zsh"            "$STOW_DIR/zsh"
check_link ".config/fish"           "$STOW_DIR/fish"
check_link ".config/nushell"        "$STOW_DIR/nushell"
check_link ".config/starship.toml"  "$STOW_DIR/starship"
check_link ".config/ghostty"        "$STOW_DIR/ghostty"
check_link ".config/zellij"         "$STOW_DIR/zellij"
check_link ".config/mise"           "$STOW_DIR/mise"
# macOS-only bridge — nushell does not read ~/.config/nushell here.
check_link "Library/Application Support/nushell/config.nu" "$STOW_DIR/nushell"
check_link "Library/Application Support/nushell/env.nu"    "$STOW_DIR/nushell"

# =============================================================================
section "Packages match the Brewfile"
if brew bundle check --file="$REPO_DIR/Brewfile" >/dev/null 2>&1; then
  pass "brew bundle check satisfied"
else
  fail "brew bundle check failed — something declared is missing or outdated"
  hint "brew bundle --file=$REPO_DIR/Brewfile"
fi

# `cleanup` is the other direction: installed but NOT declared. Undeclared
# packages are what `update-mac.sh --prune` would silently delete.
cleanup_out="$(brew bundle cleanup --file="$REPO_DIR/Brewfile" 2>/dev/null)"
if grep -qE 'Would (uninstall|untap)' <<<"$cleanup_out"; then
  warn "undeclared packages installed — \`upd --prune\` would REMOVE these:"
  grep -A20 -E 'Would (uninstall|untap)' <<<"$cleanup_out" | grep -vE 'Would `brew cleanup`|^--$' | sed 's/^/        /'
  hint "declare them in the Brewfile, or accept that --prune removes them"
else
  pass "nothing installed-but-undeclared"
fi

# =============================================================================
section "Repo hygiene"
# Stow folds directories, so an installer writing to a stowed config dir writes
# into this repo. Three separate tools have done it. Uncommitted state here is
# usually that, not your own work in progress.
dirty="$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)"
if [[ -z "$dirty" ]]; then
  pass "working tree clean"
else
  warn "uncommitted changes — an installer may have written into the repo:"
  sed 's/^/        /' <<<"$dirty"
  hint "see README › Folded symlinks for the triage rule"
fi

crlf=0
while IFS= read -r f; do
  [[ -f "$REPO_DIR/$f" ]] && grep -qU $'\r' "$REPO_DIR/$f" 2>/dev/null && { crlf=$((crlf+1)); warn "CRLF line endings: $f"; }
done < <(git -C "$REPO_DIR" ls-files)
[[ $crlf -eq 0 ]] && pass "all tracked files are LF (.gitattributes holding)"

# =============================================================================
section "Runtime wiring"
node_path="$(clean zsh -ic 'command -v node')"
if [[ "$node_path" == *"/mise/"* ]]; then
  pass "node from mise — $(clean zsh -ic 'node --version')"
elif [[ -n "$node_path" ]]; then
  warn "node resolves OUTSIDE mise: $node_path"
  hint "expected ~/.local/share/mise/installs/... — a stray brew/nvm node may be shadowing it"
else
  fail "node not found on PATH"
fi

if [[ -n "$(clean zsh -ic 'command -v devcontainer')" ]]; then
  pass "devcontainer CLI present ($(clean zsh -ic 'devcontainer --version'))"
else
  fail "devcontainer CLI missing — the one host tool needed to boot the containers"
  hint "brew install devcontainer   (declared in the Brewfile; NOT the npm global — mise's node bin dir shadows brew)"
fi

case ":$(clean zsh -ic 'echo $PATH'):" in
  *":$HOME/.local/bin:"*) pass "~/.local/bin on PATH" ;;
  *) warn "~/.local/bin NOT on PATH — the unsloth CLI and pipx/uv shims live there" ;;
esac

# =============================================================================
section "Services"
# Ollama only matters if it is running; not running is a valid state (it frees
# memory). But running while bound to loopback is a silent trap: containers
# cannot reach it, and an exported OLLAMA_HOST does NOT fix the launchd service.
listen="$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep 11434)"
if [[ -z "$listen" ]]; then
  pass "ollama not listening (idle — fine; \`o-up\` starts it)"
elif grep -qE '\*:11434|0\.0\.0\.0:11434' <<<"$listen"; then
  pass "ollama bound to all interfaces — reachable from containers"
else
  fail "ollama bound to loopback only — containers CANNOT reach it"
  hint "$(awk '{print $1, $9}' <<<"$listen" | head -1)"
  hint "run \`o-up\` (exported OLLAMA_HOST does not reach the launchd service)"
fi

if brew autoupdate status >/dev/null 2>&1; then
  pass "brew autoupdate reachable ($(brew autoupdate status 2>/dev/null | head -1))"
else
  fail "brew autoupdate command will not run"
  hint "brew trust domt4/autoupdate   # required before the command loads"
fi

# =============================================================================
printf '\n\033[1m%s\033[0m\n' "───────────────────────────────────────────────"
printf '  \033[1;32m%d passed\033[0m · \033[1;33m%d warning(s)\033[0m · \033[1;31m%d failure(s)\033[0m\n' \
  "$PASSED" "$WARNED" "$FAILED"
if [[ $FAILED -gt 0 ]]; then
  printf '  Failures are things the repo claims but the machine does not do.\n'
  exit 1
fi
exit 0
