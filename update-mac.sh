#!/usr/bin/env bash
# =============================================================================
# update-mac.sh — keep the host current, lean, audited, and CORRECT.
#
# Run weekly (manually `upd`, or scheduled — see docs/CHEATSHEET.md › Maintenance).
# Idempotent and read-mostly: nothing here removes packages without --prune.
#
# Steps 1-7 update and report. Step 8 runs ./doctor-mac.sh, which asserts the
# live host actually matches what this repo declares — a different question from
# "is everything up to date", and the one that has caught the real problems here
# (a shell config that never loaded, a service on the wrong interface, an app
# installer editing a tracked file). Exits non-zero if doctor reports failures.
#
# Usage:
#   ./update-mac.sh           # update everything + report drift/CVEs + assert
#   ./update-mac.sh --prune    # also remove anything not in the Brewfile
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRUNE=0
[[ "${1:-}" == "--prune" ]] && PRUNE=1

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }

eval "$(/opt/homebrew/bin/brew shellenv)"

# --- 1. Homebrew: update formulae/casks, including self-updating apps ---------
info "Updating Homebrew…"
brew update
info "Upgrading packages (--greedy also bumps auto-updating casks)…"
brew upgrade --greedy
ok "Homebrew up to date."

# --- 2. Drift check: is the host still == Brewfile? --------------------------
info "Checking host against Brewfile…"
if brew bundle check --file="$REPO_DIR/Brewfile"; then
  ok "Host matches Brewfile."
else
  warn "Drift detected. Install missing: brew bundle --file=$REPO_DIR/Brewfile"
fi

# --- 3. Prune cruft ----------------------------------------------------------
info "Removing orphaned dependencies and old downloads…"
brew autoremove
brew cleanup --prune=all
if [[ "$PRUNE" == "1" ]]; then
  warn "Pruning anything NOT in the Brewfile…"
  brew bundle cleanup --file="$REPO_DIR/Brewfile" --force
else
  # Report-only: show what a --prune run would remove.
  brew bundle cleanup --file="$REPO_DIR/Brewfile" || true
fi

# --- 4. Node toolchain (host CLI tooling only) -------------------------------
if command -v mise >/dev/null 2>&1; then
  info "Updating mise-managed runtimes + global npm CLI tools…"
  # Re-resolves node@lts to the newest LTS patch and installs it.
  mise upgrade || warn "mise upgrade hit an issue (non-fatal)."
  # Shims, not `activate` — this script is non-interactive (see bootstrap-mac.sh).
  export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"
  npm update -g || warn "npm global update hit an issue (non-fatal)."
  npm outdated -g || true
fi

# --- 5. Self-updating agents (report; they update themselves) ----------------
command -v claude  >/dev/null 2>&1 && { info "Claude Code:"; claude --version || true; }
command -v codex   >/dev/null 2>&1 && { info "Codex:"; codex --version || true; }

# --- 6. Vulnerability scan ---------------------------------------------------
# Real CVEs live in the PROJECT lockfiles (composer.lock, package-lock.json),
# not the host. Point osv-scanner at your workspace. Adjust the path as needed.
if command -v osv-scanner >/dev/null 2>&1; then
  SCAN_DIR="${WORKSPACE_DIR:-$HOME/Code}"
  if [[ -d "$SCAN_DIR" ]]; then
    info "Scanning $SCAN_DIR for known vulnerabilities (osv-scanner)…"
    osv-scanner scan --recursive "$SCAN_DIR" || warn "osv-scanner found issues — review above."
  else
    warn "Set WORKSPACE_DIR to scan your repos (default $HOME/Code not found)."
  fi
fi

# --- 7. macOS security updates ----------------------------------------------
info "Checking macOS software updates…"
softwareupdate --list 2>/dev/null || true
echo "  (install with: softwareupdate --install --all --restart)"

# --- 8. Doctor: does the machine actually match the repo? --------------------
# Everything above updates and reports. This asserts. The failures that have
# actually cost time here were silent — a config that never loaded, a service
# on the wrong interface, an installer editing a tracked file — and none of them
# surface in the steps above. Run last so its output is what you're left looking
# at. Captured rather than allowed to abort (set -e is on) so the summary and
# tip below still print.
DOCTOR_STATUS=0
if [[ -x "$REPO_DIR/doctor-mac.sh" ]]; then
  "$REPO_DIR/doctor-mac.sh" || DOCTOR_STATUS=$?
else
  warn "doctor-mac.sh missing or not executable — skipping host assertions."
fi

ok "Maintenance pass complete."
echo "Tip: also open 1Password ▸ Watchtower for breached/weak credentials."
if [[ "$DOCTOR_STATUS" -ne 0 ]]; then
  warn "doctor-mac.sh reported failures above: the host does not match this repo."
  exit "$DOCTOR_STATUS"
fi
