#!/usr/bin/env bash
# =============================================================================
# update-mac.sh — keep the host current, lean, and audited for CVEs.
#
# Run weekly (manually `upd`, or scheduled — see docs/CHEATSHEET.md › Maintenance).
# Idempotent and read-mostly: nothing here removes packages without --prune.
#
# Usage:
#   ./update-mac.sh           # update everything + report drift/CVEs
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
if command -v fnm >/dev/null 2>&1; then
  info "Updating global npm CLI tools…"
  eval "$(fnm env)"
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
  SCAN_DIR="${WORKSPACE_DIR:-$HOME/workspace}"
  if [[ -d "$SCAN_DIR" ]]; then
    info "Scanning $SCAN_DIR for known vulnerabilities (osv-scanner)…"
    osv-scanner scan --recursive "$SCAN_DIR" || warn "osv-scanner found issues — review above."
  else
    warn "Set WORKSPACE_DIR to scan your repos (default $HOME/workspace not found)."
  fi
fi

# --- 7. macOS security updates ----------------------------------------------
info "Checking macOS software updates…"
softwareupdate --list 2>/dev/null || true
echo "  (install with: softwareupdate --install --all --restart)"

ok "Maintenance pass complete."
echo "Tip: also open 1Password ▸ Watchtower for breached/weak credentials."
