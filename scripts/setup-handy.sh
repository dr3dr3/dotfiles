#!/usr/bin/env bash
# =============================================================================
# setup-handy.sh — apply this repo's Handy dictation profile to the live host.
#
# Handy (cask "handy") transcribes speech ON-DEVICE and pastes the result into
# whatever window has focus — for this host, a Ghostty pane running Herdr. This
# script pins the handful of settings that matter for that use, binds the
# MacBook's built-in Fn/Globe key as hold-to-talk, and merges
# config/handy/vocabulary.txt into Handy's custom-words corrector.
#
# Idempotent: safe to re-run. A run that would change nothing writes nothing and
# takes no backup.
#
# Usage:
#   ./scripts/setup-handy.sh                # apply, then relaunch Handy
#   ./scripts/setup-handy.sh --dry-run      # show the diff, change nothing
#   ./scripts/setup-handy.sh --no-autostart # leave launch-at-login alone
#   ./scripts/setup-handy.sh --no-launch    # don't relaunch Handy afterwards
#
# -----------------------------------------------------------------------------
# WHY THIS EDITS JSON RATHER THAN STOWING A CONFIG
#
# Handy keeps settings in ~/Library/Application Support/com.pais.handy/, which
# ALSO holds models/ (GB-scale GGUF weights), recordings/ (raw WAV audio) and
# history.db (transcripts). Stowing that directory would pull all of it into the
# repo — see README › "Folded symlinks: tools can write into this repo", which
# is the same trap fish, OrbStack and Unsloth each fell into here. So: the
# directory stays entirely outside Git, and this script merges only the keys
# listed in MANAGED below, leaving every other key untouched.
#
# -----------------------------------------------------------------------------
# WHY THE SCHEMA GATE IS NOT PARANOIA
#
# settings_store.json is Handy's own serde-serialised AppSettings struct, and it
# stamps settings_schema_version. This script refuses to write unless that
# equals EXPECTED_SCHEMA_VERSION, because the values below are enum variants
# from a specific build: RecordingRetentionPeriod, ClipboardHandling and
# PasteMethod are Rust enums, and a renamed variant would be silently dropped.
# (Handy salvages per-key — an unparseable value is discarded and its DEFAULT
# used, with only a log line. So a bad write here does not corrupt the file; it
# quietly gives you the opposite of what you asked for, which is worse.)
# When the gate trips, nothing is written and docs/HANDY.md's manual checklist
# is the fallback. Verified against Handy 0.9.6 / schema 2.
#
# -----------------------------------------------------------------------------
# THE ONE THAT WOULD HAVE BITTEN: recording_retention_period
#
# The variant named `never` does NOT mean "never keep recordings". Read the
# upstream match arm: Never => "Don't delete anything" — it disables cleanup and
# keeps every WAV forever. The combination that actually deletes recordings is
# `preserve_limit` + history_limit 0, which prunes every unsaved entry and its
# WAV after each transcription. That is what is set below.
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT_DIR="$HOME/Library/Application Support/com.pais.handy"
SETTINGS="$SUPPORT_DIR/settings_store.json"
VOCAB_FILE="$REPO_DIR/config/handy/vocabulary.txt"
EXPECTED_SCHEMA_VERSION=2

# Set `selected_microphone` to this device, but only if the host actually has
# it. The value is the CoreAudio device name exactly as Handy (via cpal) sees
# it. Pinning matters on this host: a Logitech headset and a webcam mic are
# often also connected, and Handy would otherwise follow the system default.
BUILTIN_MIC="MacBook Pro Microphone"

DRY_RUN=0
AUTOSTART=1
RELAUNCH=1
for arg in "$@"; do
  case "$arg" in
    --dry-run)      DRY_RUN=1 ;;
    --no-autostart) AUTOSTART=0 ;;
    --no-launch)    RELAUNCH=0 ;;
    -h|--help)      sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

# --- 0. sanity ---------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "setup-handy.sh targets macOS (Handy is a host-native app)."
[[ -f "$VOCAB_FILE" ]] || die "Vocabulary file missing: $VOCAB_FILE"

# Resolve the app rather than assuming /Applications — a cask can be installed
# into ~/Applications when Homebrew is not the admin-owned install.
HANDY_APP=""
for candidate in "/Applications/Handy.app" "$HOME/Applications/Handy.app"; do
  [[ -d "$candidate" ]] && { HANDY_APP="$candidate"; break; }
done
if [[ -z "$HANDY_APP" ]]; then
  die "Handy.app not found. Install it with: brew bundle --file=$REPO_DIR/Brewfile"
fi
ok "Handy.app at $HANDY_APP ($(/usr/bin/defaults read "$HANDY_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo '?'))"

if [[ ! -f "$SETTINGS" ]]; then
  die "No settings store yet at:
      $SETTINGS
      Launch Handy once so it writes its defaults, then re-run this script:
        open -a Handy"
fi

# --- 1. schema gate ----------------------------------------------------------
# Read BEFORE quitting the app, so a mismatched build costs nothing.
actual_schema="$(/usr/bin/python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("unreadable:%s" % e); raise SystemExit(0)
print(d.get("settings", {}).get("settings_schema_version", "absent"))
' "$SETTINGS")"

if [[ "$actual_schema" == unreadable:* ]]; then
  die "Handy's settings store will not parse: ${actual_schema#unreadable:}
      Nothing was changed. Restore the most recent backup beside it —
        ls -t '$SETTINGS'.bak.* | head -1
      or delete the store and let Handy write a fresh one on next launch."
fi

if [[ "$actual_schema" != "$EXPECTED_SCHEMA_VERSION" ]]; then
  die "Handy's settings schema is '$actual_schema', expected $EXPECTED_SCHEMA_VERSION.
      Refusing to write — the managed values are enum variants from a specific
      build and this one may have renamed them. Nothing was changed.
      Configure Handy by hand instead: docs/HANDY.md › Manual checklist,
      then re-verify this script against the new schema before trusting it."
fi
ok "settings schema version $actual_schema (as expected)"

# --- 2. quit Handy -----------------------------------------------------------
# Handy holds settings in memory and rewrites the whole store on change, so an
# edit made while it runs is silently clobbered on its next write. Quit first.
handy_running() { /usr/bin/pgrep -x handy >/dev/null 2>&1; }
WAS_RUNNING=0
if handy_running; then
  WAS_RUNNING=1
  if [[ "$DRY_RUN" == "1" ]]; then
    warn "Handy is running — a real run would quit it first (dry run: leaving it alone)."
  else
    info "Quitting Handy…"
    /usr/bin/osascript -e 'tell application "Handy" to quit' >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
      handy_running || break
      sleep 0.5
    done
    if handy_running; then
      warn "Handy ignored the quit request; sending TERM."
      /usr/bin/pkill -x handy || true
      for _ in $(seq 1 10); do handy_running || break; sleep 0.5; done
    fi
    handy_running && die "Handy is still running. Quit it from the menu bar and re-run."
    ok "Handy stopped."
  fi
else
  ok "Handy not running."
fi

# --- 3. does this host have the built-in mic? --------------------------------
# Only pin the microphone if it is actually present; otherwise leave whatever
# Handy has, rather than pointing it at a device that does not exist.
MIC_TO_SET=""
if /usr/sbin/system_profiler SPAudioDataType 2>/dev/null | grep -qF "$BUILTIN_MIC"; then
  MIC_TO_SET="$BUILTIN_MIC"
else
  warn "'$BUILTIN_MIC' not found in this host's audio devices — leaving selected_microphone as-is."
fi

# --- 4. merge ----------------------------------------------------------------
# Everything below runs in python3 (macOS system python, already relied on by
# scripts/link-container-config.py and tests/). It merges ONLY the managed keys,
# validates every value against the enums this script was verified against, and
# writes atomically.
export HANDY_SETTINGS="$SETTINGS"
export HANDY_VOCAB="$VOCAB_FILE"
export HANDY_MIC="$MIC_TO_SET"
export HANDY_AUTOSTART="$AUTOSTART"
export HANDY_DRY_RUN="$DRY_RUN"
export HANDY_SUPPORT_DIR="$SUPPORT_DIR"

set +e
/usr/bin/python3 <<'PY'
import json, os, shutil, sys, time
from datetime import datetime

settings_path = os.environ["HANDY_SETTINGS"]
vocab_path    = os.environ["HANDY_VOCAB"]
mic           = os.environ["HANDY_MIC"] or None
autostart     = os.environ["HANDY_AUTOSTART"] == "1"
dry_run       = os.environ["HANDY_DRY_RUN"] == "1"

GREEN, YELLOW, RESET = "\033[1;32m", "\033[1;33m", "\033[0m"

# Every managed key, with the legal values this script was verified against
# (Handy 0.9.6, settings schema 2). `None` means "any value of that type".
# Anything not listed here is NEVER touched.
MANAGED = {
    # --- local-only transcription -------------------------------------------
    # post_process_* is the ONLY path that would send text off this Mac: it
    # POSTs the transcript to OpenAI/Anthropic/Groq/etc. Off means Handy makes
    # no network call at all beyond model downloads and update checks.
    "post_process_enabled":       (False,           [True, False]),

    # --- push to talk --------------------------------------------------------
    "push_to_talk":               (True,            [True, False]),

    # --- language ------------------------------------------------------------
    # "auto" runs language ID on every utterance and mis-detects short technical
    # phrases. Pinning to English removes that failure mode.
    "selected_language":          ("en",            None),
    "translate_to_english":       (False,           [True, False]),

    # --- SAFETY-CRITICAL -----------------------------------------------------
    # auto_submit appends the auto_submit_key (default Return) to every
    # transcript. Dictating into a terminal with this on runs whatever Whisper
    # heard, with no chance to read it first. It must stay False.
    "auto_submit":                (False,           [True, False]),

    # --- clipboard preserve/restore -----------------------------------------
    # Handy has no "restore clipboard" toggle; restore is built into the
    # clipboard paste path (it snapshots text, or an image when there is no
    # text, and puts it back after pasting). Two keys keep that behaviour:
    #   paste_method ctrl_v      -> use the clipboard path that does the restore
    #                               (a `direct` / keystroke method bypasses it)
    #   clipboard_handling
    #     dont_modify            -> leave the restored clipboard alone
    #     copy_to_clipboard      -> deliberately OVERWRITE it with the transcript
    "paste_method":               ("ctrl_v",        ["ctrl_v", "direct", "shift_insert",
                                                     "ctrl_shift_v", "external_script"]),
    "clipboard_handling":         ("dont_modify",   ["dont_modify", "copy_to_clipboard"]),

    # --- no retained recordings or transcript history ------------------------
    # See the header note: `preserve_limit` + limit 0 is what DELETES; the
    # variant literally named `never` means "never delete".
    "recording_retention_period": ("preserve_limit", ["never", "preserve_limit",
                                                      "days3", "weeks2", "months3"]),
    "history_limit":              (0,               None),
}

# Handy stores shortcuts under a nested bindings object. Keep this explicit so
# changing the hotkey in the UI cannot silently restore the old shortcut. Handy
# sees the Fn/Globe key on Apple's built-in keyboard as `fn`; third-party Fn keys
# (including Logitech's) generally never reach macOS as a bindable key event.
MANAGED_BINDINGS = {
    "transcribe": "fn",
}

if mic:
    MANAGED["selected_microphone"] = (mic, None)
if autostart:
    MANAGED["autostart_enabled"] = (True, [True, False])

# --- read ---------------------------------------------------------------------
with open(settings_path, encoding="utf-8") as fh:
    store = json.load(fh)

if not isinstance(store, dict) or not isinstance(store.get("settings"), dict):
    print("  \033[1;31m✗\033[0m settings_store.json is not the expected "
          "{'settings': {...}} shape — refusing to write.", file=sys.stderr)
    raise SystemExit(1)

settings = store["settings"]

bindings = settings.get("bindings")
if not isinstance(bindings, dict):
    print("  \033[1;31m✗\033[0m settings.bindings is not an object — refusing "
          "to write.", file=sys.stderr)
    raise SystemExit(1)
for binding_id in MANAGED_BINDINGS:
    if not isinstance(bindings.get(binding_id), dict):
        print("  \033[1;31m✗\033[0m settings.bindings.%s is not an object — "
              "refusing to write." % binding_id, file=sys.stderr)
        raise SystemExit(1)

# --- vocabulary ---------------------------------------------------------------
vocab = []
with open(vocab_path, encoding="utf-8") as fh:
    for line in fh:
        term = line.split("#", 1)[0].strip()
        if term:
            vocab.append(term)

# Union, not replace: terms added in Handy's own Words pane must survive. Match
# case-insensitively so re-casing a term here updates it rather than duplicating.
existing = settings.get("custom_words")
if not isinstance(existing, list):
    existing = []
by_key = {}
for term in existing:
    if isinstance(term, str) and term.strip():
        by_key[term.strip().lower()] = term.strip()
for term in vocab:                       # this file wins on casing
    by_key[term.lower()] = term
merged_words = sorted(by_key.values(), key=str.lower)

# --- plan ---------------------------------------------------------------------
changes = []
for key, (want, allowed) in MANAGED.items():
    if allowed is not None and want not in allowed:
        print("  \033[1;31m✗\033[0m internal error: %r is not a legal value for %s"
              % (want, key), file=sys.stderr)
        raise SystemExit(1)
    if key not in settings:
        changes.append((key, "(absent)", json.dumps(want)))
    elif settings[key] != want:
        changes.append((key, json.dumps(settings[key]), json.dumps(want)))

for binding_id, want in MANAGED_BINDINGS.items():
    got = bindings[binding_id].get("current_binding", "<absent>")
    if got != want:
        changes.append(("bindings.%s.current_binding" % binding_id,
                        json.dumps(got), json.dumps(want)))

if merged_words != existing:
    had = {e.strip().lower() for e in existing if isinstance(e, str)}
    added = [w for w in merged_words if w.lower() not in had]
    changes.append(("custom_words",
                    "%d term(s)" % len(existing),
                    "%d term(s)%s" % (len(merged_words),
                                      (" — adding %s" % ", ".join(added)) if added else "")))

if not changes:
    print("  %s✓%s Handy profile already applied — nothing to change "
          "(%d vocabulary term(s))." % (GREEN, RESET, len(merged_words)))
    raise SystemExit(0)

print("\033[1;34m==>\033[0m Settings to change:")
for key, have, want in changes:
    print("      %-28s %s  ->  %s" % (key, have, want))

if dry_run:
    print("  %s!%s Dry run — nothing written." % (YELLOW, RESET))
    raise SystemExit(0)

# --- backup -------------------------------------------------------------------
# Taken only when something will actually change, so re-runs don't litter.
# Lives beside the store, OUTSIDE the repo — it can contain post-processing API
# keys, which must never reach Git.
stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = "%s.bak.%s" % (settings_path, stamp)
shutil.copy2(settings_path, backup)
print("  %s✓%s Backup: %s" % (GREEN, RESET, backup))

# --- write --------------------------------------------------------------------
for key, (want, _allowed) in MANAGED.items():
    settings[key] = want
for binding_id, want in MANAGED_BINDINGS.items():
    settings["bindings"][binding_id]["current_binding"] = want
settings["custom_words"] = merged_words

tmp = settings_path + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(store, fh, indent=2, ensure_ascii=False)
    fh.write("\n")

# Re-read the temp file before it replaces anything: a store we cannot parse is
# a store Handy would fall back to defaults on.
with open(tmp, encoding="utf-8") as fh:
    check = json.load(fh)
for key, (want, _allowed) in MANAGED.items():
    if check["settings"].get(key) != want:
        os.unlink(tmp)
        print("  \033[1;31m✗\033[0m verification failed for %s — original left "
              "untouched." % key, file=sys.stderr)
        raise SystemExit(1)
for binding_id, want in MANAGED_BINDINGS.items():
    got = check["settings"]["bindings"][binding_id].get("current_binding")
    if got != want:
        os.unlink(tmp)
        print("  \033[1;31m✗\033[0m verification failed for binding %s — "
              "original left untouched." % binding_id, file=sys.stderr)
        raise SystemExit(1)

os.replace(tmp, settings_path)
print("  %s✓%s Wrote %d managed setting(s) + %d vocabulary term(s)."
      % (GREEN, RESET, len(MANAGED) + len(MANAGED_BINDINGS), len(merged_words)))
PY
merge_status=$?
set -e
[[ "$merge_status" -eq 0 ]] || die "Settings merge failed (see above). Handy was not modified."

# --- 5. what is still manual -------------------------------------------------
# selected_model is deliberately NOT managed. It names a model file that must
# already be DOWNLOADED — pointing it at an absent model leaves Handy unable to
# transcribe, and this script cannot fetch a ~1.5GB GGUF. Report, don't set.
current_model="$(/usr/bin/python3 -c '
import json, os
d = json.load(open(os.environ["HANDY_SETTINGS"]))
print(d["settings"].get("selected_model") or "")
')"
if [[ -z "$current_model" ]]; then
  warn "No transcription model selected yet."
  warn "  Pick one in Handy ▸ Settings ▸ Models — 'Whisper Medium' per docs/HANDY.md."
  warn "  (This script never sets it: the model has to be downloaded first.)"
else
  ok "Model in use: $current_model"
fi

# The default macOS Dictation shortcut is a double press of Fn/Globe. It can
# coexist badly with Handy owning the same physical key for hold-to-talk. This
# script does not rewrite the user's system shortcut table, but it does make the
# conflict visible; doctor-mac.sh enforces the same expectation.
dictation_hotkey_enabled="$(
  /usr/bin/defaults export com.apple.symbolichotkeys - 2>/dev/null |
    /usr/bin/plutil -extract 'AppleSymbolicHotKeys.164.enabled' raw -o - - 2>/dev/null
)"
case "$dictation_hotkey_enabled" in
  false) ok "macOS double-Fn Dictation shortcut is disabled." ;;
  true)
    warn "macOS double-Fn Dictation is still enabled and may compete with Handy."
    warn "  In System Settings ▸ Keyboard ▸ Dictation, change its shortcut."
    ;;
  *) warn "Could not determine whether macOS double-Fn Dictation is enabled." ;;
esac

if [[ "$DRY_RUN" == "0" && "$AUTOSTART" == "1" ]]; then
  # Handy re-applies autostart_enabled on every launch, registering itself as an
  # SMAppService login item. So the JSON edit above only takes effect once Handy
  # has been started again — which is what the relaunch below is for.
  info "Launch-at-login is enabled in settings; Handy registers it on next start."
fi

# --- 6. relaunch -------------------------------------------------------------
if [[ "$DRY_RUN" == "0" && "$RELAUNCH" == "1" ]]; then
  if [[ "$WAS_RUNNING" == "1" || ! -t 0 ]]; then
    info "Relaunching Handy…"
  else
    info "Starting Handy…"
  fi
  open -a "$HANDY_APP"
  ok "Handy running; settings reloaded from disk."
elif [[ "$DRY_RUN" == "0" ]]; then
  warn "Handy not relaunched (--no-launch). Start it before dictating: open -a Handy"
fi

cat <<'EOF'

────────────────────────────────────────────────────────────────────────────
Still yours to grant — macOS permissions cannot be scripted, and nothing in
this repo tries to. Handy prompts on first use; if you missed a prompt:

  System Settings ▸ Privacy & Security ▸ Microphone      → enable Handy
  System Settings ▸ Privacy & Security ▸ Accessibility   → enable Handy

Accessibility is the one that fails silently: without it Handy records and
transcribes fine, then the paste keystroke goes nowhere and the text never
appears. If dictation "does nothing", check that pane first.

Full runbook, including the settings this script does NOT manage:
  docs/HANDY.md
────────────────────────────────────────────────────────────────────────────
EOF
