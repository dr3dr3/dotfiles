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
#   * a check here asserted Ollama had to bind 0.0.0.0 to serve containers. It
#     does not under OrbStack, so the check failed on a healthy host for weeks
#     (corrected 2026-09-14) — a reminder that an assertion is only as good as
#     the belief behind it, and that both directions need testing
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
check_link ".local/bin/devrebuild"  "$STOW_DIR/bin"
check_link ".local/bin/devherd"     "$STOW_DIR/bin"
check_link ".config/herdr/config.toml" "$STOW_DIR/herdr"
check_link ".config/karabiner/assets/complex_modifications/herdr-caps-lock.json" "$STOW_DIR/karabiner"
check_link ".config/karabiner/assets/complex_modifications/handy-vibe-key.json" "$STOW_DIR/karabiner"
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
# memory).
#
# THIS CHECK USED TO BE BACKWARDS. It failed whenever Ollama was on 127.0.0.1,
# asserting that containers could not reach it — so every `upd` reported a
# broken host that was working fine. Verified 2026-09-14 with the server bound
# to loopback ONLY: a fresh `docker run alpine` on the default bridge and the
# roe-devcontainer both reached it through host.docker.internal, while this
# host's LAN address refused. OrbStack forwards host.docker.internal to the host
# loopback deliberately (docs.orbstack.dev/docker/network); Docker Desktop's
# sandbox blocks that, which is the case the wide bind actually exists for.
#
# So loopback is now the expected, and safer, state: a wildcard bind puts a
# no-auth inference server on the LAN. The check warns in both directions rather
# than failing, because which one is right depends on the container engine.
listen="$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep 11434)"
engine="$(docker context show 2>/dev/null || echo unknown)"
if [[ -z "$listen" ]]; then
  pass "ollama not listening (idle — fine; \`o-up\` starts it)"
elif grep -qE '\*:11434|0\.0\.0\.0:11434' <<<"$listen"; then
  if [[ "$engine" == "orbstack" ]]; then
    warn "ollama is bound to ALL interfaces — unnecessary under OrbStack"
    hint "containers reach a loopback-bound server via host.docker.internal already"
    hint "this exposes a no-auth inference server to the LAN; \`o-up\` rebinds to loopback"
  else
    pass "ollama bound to all interfaces (docker context: $engine — wide bind needed)"
  fi
elif [[ "$engine" == "orbstack" ]]; then
  pass "ollama on loopback — OrbStack containers reach it via host.docker.internal"
else
  warn "ollama on loopback, but docker context is '$engine', not orbstack"
  hint "only OrbStack forwards host.docker.internal to the host loopback"
  hint "if containers cannot reach it, run \`o-expose\` (binds 0.0.0.0 — LAN-visible)"
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
    "keyboard_implementation": "tauri",
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
print("%s %s %s %s" % ("OK" if binding == "control+option+command+r" else "DRIFT",
                       "bindings.transcribe.current_binding",
                       json.dumps(binding), json.dumps("control+option+command+r")))

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

# Symbolic hotkey 164 is macOS Dictation's double-Fn/Globe trigger. The managed
# Karabiner bridge owns that physical key, so leaving 164 enabled produces
# competing behaviour on a quick double press.
dictation_hotkey_enabled="$(
  /usr/bin/defaults export com.apple.symbolichotkeys - 2>/dev/null |
    /usr/bin/plutil -extract 'AppleSymbolicHotKeys.164.enabled' raw -o - - 2>/dev/null
)"
case "$dictation_hotkey_enabled" in
  false) pass "macOS double-Fn Dictation shortcut is disabled" ;;
  true)
    fail "macOS double-Fn Dictation shortcut competes with Handy's Globe bridge"
    hint "System Settings ▸ Keyboard ▸ Dictation — change the Dictation shortcut"
    ;;
  *) warn "could not determine the macOS double-Fn Dictation shortcut state" ;;
esac

# Handy has only one transcribe binding. It listens to the Ulanzi chord
# directly; Karabiner converts the physical Globe key to that chord. Check both
# physical routes, including the active AU05 profile.
VIBE_RULE_DESCRIPTION="Handy: Fn/Globe sends Ctrl+Option+Command+R (Ulanzi Vibe Key)"
KARABINER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/karabiner/karabiner.json"
ULANZI_ROOT="$HOME/Library/Application Support/Ulanzi/UlanziDeck"
vibe_report="$(/usr/bin/python3 - "$KARABINER_CONFIG" "$ULANZI_ROOT" "$VIBE_RULE_DESCRIPTION" <<'PY' 2>/dev/null
import glob, json, os, sys

karabiner_path, root, description = sys.argv[1:]
try:
    karabiner = json.load(open(karabiner_path, encoding="utf-8"))
    selected = [p for p in karabiner.get("profiles", []) if p.get("selected")]
    rules = selected[0].get("complex_modifications", {}).get("rules", []) if len(selected) == 1 else []
    print("RULE %s" % ("OK" if any(r.get("description") == description for r in rules) else "MISSING"))
except Exception:
    print("RULE UNREADABLE")

try:
    live = json.load(open(os.path.join(root, "config", "setting_source.json"), encoding="utf-8"))
    uuid = live.get("CurrentDeviceType")
    device = next(d for d in live.get("Devices", []) if d.get("CurrentDevice") == uuid)
    if device.get("DeviceType") != "AU05":
        print("HOTKEY NO_DEVICE")
        raise SystemExit(0)
    profile_name = device.get("CurrentProfile")
    match = None
    for path in glob.glob(os.path.join(root, "ProfilesV2", "*.ulanziProfile", "manifest.json")):
        manifest = json.load(open(path, encoding="utf-8"))
        if manifest.get("Device", {}).get("UUID") == uuid and manifest.get("Name") == profile_name:
            match = (path, manifest)
            break
    page_path = os.path.join(os.path.dirname(match[0]), "Profiles", match[1]["Pages"]["Current"], "manifest.json")
    page = json.load(open(page_path, encoding="utf-8"))
    keypad = next(c for c in page["Controllers"] if c.get("Type") == "Keypad")
    hotkey = keypad["Actions"]["0_0"]["ActionParam"]["Hotkey"]
    print("HOTKEY %s" % ("OK" if hotkey == "⌃ ⌥ ⌘  R" else hotkey))
except SystemExit:
    pass
except Exception:
    print("HOTKEY UNREADABLE")
PY
)"
case "$(sed -n 's/^RULE //p' <<<"$vibe_report")" in
  OK) pass "Karabiner routes Fn/Globe to Handy's modifier binding" ;;
  *)  warn "Handy's Fn/Globe Karabiner route is not active"; hint "./scripts/setup-handy-vibe-key.sh" ;;
esac
case "$(sed -n 's/^HOTKEY //p' <<<"$vibe_report")" in
  OK)        pass "local Vibe Key profile declares Ctrl+Option+Command+R" ;;
  NO_DEVICE) warn "no active Ulanzi AU05 Vibe Key profile found" ;;
  *)         warn "Vibe Key Voice Input hotkey is not managed"; hint "./scripts/setup-handy-vibe-key.sh" ;;
esac


# =============================================================================
section "Overnight agent runs (pi-batch)"
# Two different silent failures live here.
#
# The first is work you never look at: an unattended run leaves a branch, and a
# branch nobody reviews is indistinguishable from one that was never created.
# "Outstanding" is defined as "the branch still exists" — deleting or merging it
# IS the review, so there is no separate flag to drift out of sync.
#
# The second cost a real outage on 2026-09-16. dotai symlinks the whole
# ~/.pi/agent directory onto the AI volume, so scripts/setup-pi-ollama.sh
# resolved the file and its "persistent" target to the SAME path and linked it
# to itself. Pi then failed with ELOOP and lost every provider — including the
# hosted ones it did not manage. The script now refuses to do that; this asserts
# the live result, because a config Pi cannot parse is invisible until you run
# an agent and it says "Unknown provider".
PI_STATE_DIR="${PI_BATCH_LOG_DIR:-$HOME/.local/state/pi-batch}"
if [[ -d "$PI_STATE_DIR" ]] && ls "$PI_STATE_DIR"/*.json >/dev/null 2>&1; then
  pi_out=0; pi_fail=0; pi_old=0; pi_total=0
  cutoff=$(( $(date +%s) - ${PI_BATCH_RETENTION_DAYS:-30}*86400 ))
  for rec in "$PI_STATE_DIR"/*.json; do
    pi_total=$((pi_total+1))
    read -r st cont wd br vd < <(/usr/bin/python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
print(d["stamp"], d["container"], d["workdir"], d["batch_branch"], d["verdict"].split()[0])' "$rec" 2>/dev/null) || continue
    [[ "$vd" == "FAIL" ]] && pi_fail=$((pi_fail+1))
    ts=$(date -j -f "%Y%m%d-%H%M%S" "$st" +%s 2>/dev/null || echo 0)
    [[ "$ts" -ne 0 && "$ts" -lt "$cutoff" ]] && pi_old=$((pi_old+1))
    if docker inspect "$cont" >/dev/null 2>&1 &&
       docker exec -w "$wd" "$cont" git rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1; then
      pi_out=$((pi_out+1))
    fi
  done
  if [[ $pi_out -gt 0 ]]; then
    warn "$pi_out of $pi_total agent run(s) unreviewed — their branches still exist"
    hint "pi-batch-review        # what they did"
  else
    pass "no unreviewed agent runs ($pi_total recorded)"
  fi
  [[ $pi_fail -gt 0 ]] && { warn "$pi_fail run(s) ended with failing tests"; hint "pi-batch-review --failed"; }
  [[ $pi_old  -gt 0 ]] && { warn "$pi_old record(s) past the retention window"; hint "pi-batch-review --prune"; }
else
  pass "no pi-batch runs recorded yet"
fi

# Pi's provider config must actually load. Check every running container that
# has one, since a broken link is silent until an agent run fails.
for c in $(docker ps --format '{{.Names}}' 2>/dev/null); do
  cfg="$(docker exec "$c" sh -lc 'echo $HOME/.pi/agent/models.json' 2>/dev/null | tr -d '\r')"
  [[ -n "$cfg" ]] || continue
  # -e FOLLOWS the link and is FALSE on a loop, which would skip the very state
  # this check exists for — the first version of this check did exactly that and
  # stayed silent through a broken config. -L catches a link that cannot resolve.
  docker exec "$c" sh -lc "[ -e '$cfg' ] || [ -L '$cfg' ]" 2>/dev/null || continue
  if docker exec "$c" sh -lc "python3 -c 'import json,sys; json.load(open(sys.argv[1]))' '$cfg'" >/dev/null 2>&1; then
    n="$(docker exec "$c" sh -lc "python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get(\"providers\",{})))' '$cfg'" 2>/dev/null | tr -d '\r')"
    pass "$c — Pi config loads (${n:-?} provider(s))"
  else
    fail "$c — Pi's models.json does NOT parse (a self-referential symlink does this)"
    hint "ls -l \$HOME/.pi/agent/models.json inside the container; restore a .bak.* beside it"
    hint "then re-run: ./scripts/setup-pi-ollama.sh $c"
  fi
done
# =============================================================================
printf '\n\033[1m%s\033[0m\n' "───────────────────────────────────────────────"
printf '  \033[1;32m%d passed\033[0m · \033[1;33m%d warning(s)\033[0m · \033[1;31m%d failure(s)\033[0m\n' \
  "$PASSED" "$WARNED" "$FAILED"
if [[ $FAILED -gt 0 ]]; then
  printf '  Failures are things the repo claims but the machine does not do.\n'
  exit 1
fi
exit 0
