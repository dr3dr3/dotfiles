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
check_link ".local/bin/devsh"       "$STOW_DIR/bin"
check_link ".local/bin/devherd"     "$STOW_DIR/bin"
check_link ".config/herdr/config.toml" "$STOW_DIR/herdr"
check_link ".config/karabiner/assets/complex_modifications/herdr-caps-lock.json" "$STOW_DIR/karabiner"
check_link ".config/cliamp/radios.toml" "$STOW_DIR/cliamp"
# macOS-only bridge — nushell does not read ~/.config/nushell here.
check_link "Library/Application Support/nushell/config.nu" "$STOW_DIR/nushell"
check_link "Library/Application Support/nushell/env.nu"    "$STOW_DIR/nushell"

# ~/.config/cliamp must be a REAL directory, never a stow-folded symlink.
# This needs its own check because check_link above CANNOT catch it: if the
# directory were folded into the repo, radios.toml would still resolve into the
# repo and that check would happily pass. Meanwhile cliamp would be writing
# cliamp.sock, cliamp.log, favorites.toml and history.toml into the tracked
# tree. bootstrap-mac.sh guards this by mkdir-ing the directory before stowing;
# nothing verified it until now.
if [[ -L "$HOME/.config/cliamp" ]]; then
  fail ".config/cliamp is a FOLDED symlink — cliamp writes runtime state into the repo"
  hint "rm ~/.config/cliamp && mkdir -p ~/.config/cliamp && (cd $STOW_DIR && stow --restow -t \"$HOME\" cliamp)"
  hint "then check 'git status' for cliamp.sock / favorites.toml / history.toml that landed in the repo"
elif [[ -d "$HOME/.config/cliamp" ]]; then
  pass ".config/cliamp is a real dir (stow did not fold it)"
else
  fail ".config/cliamp missing — run ./bootstrap-mac.sh"
fi

# Herdr parses the active config without starting or attaching to a session.
if clean herdr config check | grep -q "config: ok"; then
  pass "Herdr config parses (Omarchy keymap, Ctrl+Alt+Space prefix)"
else
  fail "Herdr config is invalid"
  hint "run: herdr config check"
fi

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
section "Handy dictation profile"
# Handy's settings are NOT stowed (its Application Support dir also holds model
# weights, WAV recordings and transcript history — see docs/HANDY.md), so no
# stow-link check can cover them. They are merged into the live JSON by
# scripts/setup-handy.sh, which means the UI can drift away from the repo
# silently: every one of these is a toggle a stray click can flip.
#
# The one that matters most is auto_submit. It appends Return to every
# transcript, so with it on, dictating into a terminal RUNS what Whisper heard.
# That is a failure you want caught here, not discovered.
HANDY_SETTINGS="$HOME/Library/Application Support/com.pais.handy/settings_store.json"
if [[ ! -e "/Applications/Handy.app" && ! -e "$HOME/Applications/Handy.app" ]]; then
  fail "Handy.app missing — declared as cask \"handy\" in the Brewfile"
  hint "brew bundle --file=$REPO_DIR/Brewfile"
elif [[ ! -f "$HANDY_SETTINGS" ]]; then
  warn "Handy installed but never launched (no settings store yet)"
  hint "open -a Handy, then: ./scripts/setup-handy.sh"
else
  # One python pass reports every managed key; the shell just grades it. Keys are
  # compared against the same values scripts/setup-handy.sh writes.
  handy_report="$(/usr/bin/python3 - "$HANDY_SETTINGS" "$REPO_DIR/config/handy/vocabulary.txt" <<'PY' 2>/dev/null
import json, sys

EXPECTED_SCHEMA = 2
WANT = {
    "auto_submit": False,            # safety-critical: appends Return
    "post_process_enabled": False,   # the only off-box network path
    "push_to_talk": True,
    "selected_language": "en",
    "translate_to_english": False,
    "paste_method": "ctrl_v",        # the path that restores the clipboard
    "clipboard_handling": "dont_modify",
    "recording_retention_period": "preserve_limit",
    "history_limit": 0,              # with the line above: prune every recording
}

try:
    settings = json.load(open(sys.argv[1], encoding="utf-8"))["settings"]
except Exception as exc:
    print("UNREADABLE %s" % exc)
    raise SystemExit(0)

schema = settings.get("settings_schema_version")
print("SCHEMA %s %s" % (schema, EXPECTED_SCHEMA))
if schema != EXPECTED_SCHEMA:
    raise SystemExit(0)   # every assertion below is schema-specific

for key, want in WANT.items():
    got = settings.get(key, "<absent>")
    print("%s %s %s %s" % ("OK" if got == want else "DRIFT", key,
                           json.dumps(got), json.dumps(want)))

binding = settings.get("bindings", {}).get("transcribe", {}).get(
    "current_binding", "<absent>")
print("%s %s %s %s" % ("OK" if binding == "fn" else "DRIFT",
                       "bindings.transcribe.current_binding",
                       json.dumps(binding), json.dumps("fn")))

print("MODEL %s" % (settings.get("selected_model") or "<none>"))

# Compare case-insensitively, the way Handy matches, but report the canonical
# casing from the vocabulary file — that is what you have to look for.
# NOTE: no apostrophes anywhere in this heredoc. It sits inside a double-quoted
# $( ... ), and bash mis-parses a lone quote character in that position even
# though the heredoc delimiter is quoted. Cost 10 minutes once.
vocab = {}
for line in open(sys.argv[2], encoding="utf-8"):
    term = line.split("#", 1)[0].strip()
    if term:
        vocab[term.lower()] = term
live = {w.strip().lower() for w in settings.get("custom_words", []) if isinstance(w, str)}
missing = sorted((vocab[k] for k in vocab if k not in live), key=str.lower)
print("VOCAB %d %d %s" % (len(vocab), len(live), ",".join(missing)))
PY
)"

  if [[ -z "$handy_report" ]]; then
    fail "could not read Handy's settings store"
    hint "$HANDY_SETTINGS"
  elif [[ "$handy_report" == UNREADABLE* ]]; then
    fail "Handy's settings store is unparseable — ${handy_report#UNREADABLE }"
    hint "restore one of: $HANDY_SETTINGS.bak.*"
  else
    schema_line="$(grep '^SCHEMA ' <<<"$handy_report")"
    read -r _ have_schema want_schema <<<"$schema_line"
    if [[ "$have_schema" != "$want_schema" ]]; then
      warn "Handy settings schema is $have_schema, this repo verified $want_schema"
      hint "settings assertions skipped; re-verify scripts/setup-handy.sh — docs/HANDY.md"
    else
      while read -r status key got want; do
        case "$status" in
          OK)    pass "$key = $got" ;;
          DRIFT)
            if [[ "$key" == "auto_submit" ]]; then
              fail "Auto Submit is ON ($got) — dictation would RUN what it hears in a terminal"
              hint "turn it off in Handy ▸ Settings, or run ./scripts/setup-handy.sh"
            else
              fail "$key = $got, repo declares $want"
              hint "./scripts/setup-handy.sh"
            fi
            ;;
        esac
      done < <(grep -E '^(OK|DRIFT) ' <<<"$handy_report")

      model="$(sed -n 's/^MODEL //p' <<<"$handy_report")"
      if [[ "$model" == "<none>" ]]; then
        warn "no transcription model selected — Handy cannot transcribe yet"
        hint "Handy ▸ Settings ▸ Models ▸ Whisper Medium (docs/HANDY.md)"
      else
        pass "model selected ($model)"
      fi

      read -r _ vocab_count live_count vocab_missing < <(grep '^VOCAB ' <<<"$handy_report")
      if [[ -n "${vocab_missing:-}" ]]; then
        warn "vocabulary drift — ${vocab_missing//,/, } not in Handy's word list"
        hint "./scripts/setup-handy.sh   (merges config/handy/vocabulary.txt)"
      else
        pass "all $vocab_count vocabulary term(s) present (Handy has $live_count)"
      fi
    fi
  fi
fi

# Symbolic hotkey 164 is macOS Dictation's double-Fn/Globe trigger. Handy owns
# that physical key for hold-to-talk, so leaving 164 enabled produces competing
# behaviour on a quick double press.
dictation_hotkey_enabled="$(
  /usr/bin/defaults export com.apple.symbolichotkeys - 2>/dev/null |
    /usr/bin/plutil -extract 'AppleSymbolicHotKeys.164.enabled' raw -o - - 2>/dev/null
)"
case "$dictation_hotkey_enabled" in
  false) pass "macOS double-Fn Dictation shortcut is disabled" ;;
  true)
    fail "macOS double-Fn Dictation shortcut competes with Handy's Fn binding"
    hint "System Settings ▸ Keyboard ▸ Dictation — change the Dictation shortcut"
    ;;
  *) warn "could not determine the macOS double-Fn Dictation shortcut state" ;;
esac

# =============================================================================
printf '\n\033[1m%s\033[0m\n' "───────────────────────────────────────────────"
printf '  \033[1;32m%d passed\033[0m · \033[1;33m%d warning(s)\033[0m · \033[1;31m%d failure(s)\033[0m\n' \
  "$PASSED" "$WARNED" "$FAILED"
if [[ $FAILED -gt 0 ]]; then
  printf '  Failures are things the repo claims but the machine does not do.\n'
  exit 1
fi
exit 0
