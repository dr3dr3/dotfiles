#!/usr/bin/env bash
# Configure an Ulanzi AU05 Vibe Key as a second trigger for Handy.
#
# Handy supports one transcribe binding. Ulanzi Studio synthesizes shortcuts
# above Karabiner's physical-input layer, so Handy listens to a normal chord
# directly. Karabiner maps the physical Fn/Globe key to that same chord, keeping
# the existing built-in-keyboard trigger.
#
# Usage:
#   ./scripts/setup-handy-vibe-key.sh
#   ./scripts/setup-handy-vibe-key.sh --dry-run
#   ./scripts/setup-handy-vibe-key.sh --no-launch

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULE_FILE="$REPO_DIR/.dotfiles/karabiner/.config/karabiner/assets/complex_modifications/handy-vibe-key.json"
KARABINER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/karabiner/karabiner.json"
HANDY_SETTINGS="$HOME/Library/Application Support/com.pais.handy/settings_store.json"
ULANZI_ROOT="$HOME/Library/Application Support/Ulanzi/UlanziDeck"
ULANZI_SETTINGS="$ULANZI_ROOT/config/setting_source.json"

# This is the exact value serialized by Ulanzi Studio's macOS hotkey editor:
# one space between modifier glyphs and two before the ordinary key. The UI may
# display plus signs, but writing that display form to the profile does not
# produce the editor's canonical value. This is Ctrl+Option+Command+R, not Fn.
ULANZI_HOTKEY='⌃ ⌥ ⌘  R'
ULANZI_BAD_COMPACT_HOTKEY='⌃⌥⌘R'
ULANZI_BAD_PLUS_HOTKEY='⌃ + ⌥ + ⌘ + R'
LEGACY_RULE_DESCRIPTION='Handy: Ctrl+Option+Command+R sends Fn/Globe (Ulanzi Vibe Key)'
RULE_DESCRIPTION='Handy: Fn/Globe sends Ctrl+Option+Command+R (Ulanzi Vibe Key)'
HANDY_BINDING='control+option+command+r'

DRY_RUN=0
RELAUNCH=1
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --no-launch) RELAUNCH=0 ;;
    -h|--help)   sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This setup targets macOS."
[[ -f "$RULE_FILE" ]] || die "Missing managed Karabiner rule: $RULE_FILE"
[[ -f "$KARABINER_CONFIG" ]] || die "Karabiner config not found: $KARABINER_CONFIG"
[[ -f "$HANDY_SETTINGS" ]] || die "Handy settings not found; run scripts/setup-handy.sh first."
[[ -f "$ULANZI_SETTINGS" ]] || die "Ulanzi Studio has not created its device settings yet."

# Refuse to build a dead chain: both physical inputs must feed the shortcut to
# which Handy is actually bound.
handy_binding="$(/usr/bin/python3 - "$HANDY_SETTINGS" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    print(data["settings"]["bindings"]["transcribe"]["current_binding"])
except Exception as exc:
    print("unreadable:%s" % exc)
PY
)"
[[ "$handy_binding" == "$HANDY_BINDING" ]] || die "Handy's transcribe binding is '$handy_binding', expected '$HANDY_BINDING'. Run scripts/setup-handy.sh first."
ok "Handy listens directly for Ctrl+Option+Command+R."

handy_backend="$(/usr/bin/python3 - "$HANDY_SETTINGS" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    print(data["settings"].get("keyboard_implementation", "<absent>"))
except Exception as exc:
    print("unreadable:%s" % exc)
PY
)"
[[ "$handy_backend" == "tauri" ]] || die "Handy's keyboard backend is '$handy_backend', expected 'tauri' for Ulanzi's synthetic shortcut. Run scripts/setup-handy.sh first."
ok "Handy's Tauri backend accepts Ulanzi's synthetic shortcut."

export VIBE_RULE_FILE="$RULE_FILE"
export VIBE_KARABINER_CONFIG="$KARABINER_CONFIG"
export VIBE_ULANZI_ROOT="$ULANZI_ROOT"
export VIBE_ULANZI_SETTINGS="$ULANZI_SETTINGS"
export VIBE_ULANZI_HOTKEY="$ULANZI_HOTKEY"
export VIBE_ULANZI_BAD_COMPACT_HOTKEY="$ULANZI_BAD_COMPACT_HOTKEY"
export VIBE_ULANZI_BAD_PLUS_HOTKEY="$ULANZI_BAD_PLUS_HOTKEY"
export VIBE_RULE_DESCRIPTION="$RULE_DESCRIPTION"
export VIBE_LEGACY_RULE_DESCRIPTION="$LEGACY_RULE_DESCRIPTION"
export VIBE_DRY_RUN="$DRY_RUN"

# Resolve and validate every target before quitting Ulanzi Studio. The helper
# emits the selected page manifest path after it has proved that it is an AU05
# profile and that keypad slot 0_0 is the Voice Input system-hotkey action.
ULANZI_PAGE="$(/usr/bin/python3 <<'PY'
import glob, json, os, sys

root = os.environ["VIBE_ULANZI_ROOT"]
setting_path = os.environ["VIBE_ULANZI_SETTINGS"]
try:
    live = json.load(open(setting_path, encoding="utf-8"))
except Exception as exc:
    print("Ulanzi settings are unreadable: %s" % exc, file=sys.stderr)
    raise SystemExit(1)

uuid = live.get("CurrentDeviceType")
device = next((d for d in live.get("Devices", []) if d.get("CurrentDevice") == uuid), None)
if not device or device.get("DeviceType") != "AU05":
    print("The selected Ulanzi device is not an AU05 Vibe Key.", file=sys.stderr)
    raise SystemExit(1)
profile_name = device.get("CurrentProfile")

matches = []
for manifest_path in glob.glob(os.path.join(root, "ProfilesV2", "*.ulanziProfile", "manifest.json")):
    try:
        manifest = json.load(open(manifest_path, encoding="utf-8"))
    except Exception:
        continue
    if (manifest.get("Device", {}).get("UUID") == uuid and
            manifest.get("Device", {}).get("Model") == "AU05" and
            manifest.get("Name") == profile_name):
        matches.append((manifest_path, manifest))
if len(matches) != 1:
    print("Expected one active AU05 profile, found %d." % len(matches), file=sys.stderr)
    raise SystemExit(1)

manifest_path, manifest = matches[0]
page_id = manifest.get("Pages", {}).get("Current")
page_path = os.path.join(os.path.dirname(manifest_path), "Profiles", str(page_id), "manifest.json")
try:
    page = json.load(open(page_path, encoding="utf-8"))
except Exception as exc:
    print("Active Ulanzi page is unreadable: %s" % exc, file=sys.stderr)
    raise SystemExit(1)

keypads = [c for c in page.get("Controllers", []) if c.get("Type") == "Keypad"]
action = keypads[0].get("Actions", {}).get("0_0") if len(keypads) == 1 else None
if not action or action.get("Action") != "com.ulanzi.ulanzideck.system.hotkey":
    print("AU05 keypad 0_0 is not the expected Voice Input hotkey action.", file=sys.stderr)
    raise SystemExit(1)
titles = [v.get("Text") for v in action.get("ViewParam", []) if isinstance(v, dict)]
if "Voice Input" not in titles:
    print("AU05 keypad 0_0 is not titled Voice Input; refusing to change it.", file=sys.stderr)
    raise SystemExit(1)
hotkey = action.get("ActionParam", {}).get("Hotkey")
if hotkey not in ("Fn", os.environ["VIBE_ULANZI_HOTKEY"],
                  os.environ["VIBE_ULANZI_BAD_COMPACT_HOTKEY"],
                  os.environ["VIBE_ULANZI_BAD_PLUS_HOTKEY"]):
    print("Voice Input has an unexpected hotkey %r; refusing to overwrite it." % hotkey, file=sys.stderr)
    raise SystemExit(1)
print(page_path)
PY
)" || die "Could not resolve the active Vibe Key profile."
export VIBE_ULANZI_PAGE="$ULANZI_PAGE"
ok "Active Vibe Key Voice Input action: $ULANZI_PAGE"

ulanzi_running() { /usr/bin/pgrep -x UlanziDeck >/dev/null 2>&1; }
WAS_RUNNING=0
if ulanzi_running; then
  WAS_RUNNING=1
  if [[ "$DRY_RUN" == "1" ]]; then
    warn "Ulanzi Studio is running; a real run would quit it before editing its profile."
  else
    info "Quitting Ulanzi Studio so it cannot overwrite the profile…"
    /usr/bin/osascript -e 'tell application "Ulanzi Studio" to quit' >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do ulanzi_running || break; sleep 0.5; done
    ulanzi_running && die "Ulanzi Studio is still running. Quit it and re-run."
  fi
fi

/usr/bin/python3 <<'PY'
import json, os, shutil, tempfile
from datetime import datetime

karabiner_path = os.environ["VIBE_KARABINER_CONFIG"]
rule_path = os.environ["VIBE_RULE_FILE"]
ulanzi_path = os.environ["VIBE_ULANZI_PAGE"]
hotkey = os.environ["VIBE_ULANZI_HOTKEY"]
description = os.environ["VIBE_RULE_DESCRIPTION"]
legacy_description = os.environ["VIBE_LEGACY_RULE_DESCRIPTION"]
dry_run = os.environ["VIBE_DRY_RUN"] == "1"

with open(rule_path, encoding="utf-8") as fh:
    managed_rule = json.load(fh)["rules"][0]
with open(karabiner_path, encoding="utf-8") as fh:
    karabiner = json.load(fh)
selected = [p for p in karabiner.get("profiles", []) if p.get("selected")]
if len(selected) != 1:
    raise SystemExit("Expected exactly one selected Karabiner profile.")
rules = selected[0].setdefault("complex_modifications", {}).setdefault("rules", [])
rule_indexes = [i for i, rule in enumerate(rules)
                if rule.get("description") in (description, legacy_description)]
if len(rule_indexes) > 1:
    raise SystemExit("Duplicate managed Handy/Vibe Key rules in Karabiner config.")
karabiner_changed = not rule_indexes or rules[rule_indexes[0]] != managed_rule
if karabiner_changed:
    if rule_indexes:
        rules[rule_indexes[0]] = managed_rule
    else:
        rules.append(managed_rule)

with open(ulanzi_path, encoding="utf-8") as fh:
    ulanzi = json.load(fh)
keypad = next(c for c in ulanzi["Controllers"] if c.get("Type") == "Keypad")
action = keypad["Actions"]["0_0"]
old_hotkey = action["ActionParam"]["Hotkey"]
ulanzi_changed = old_hotkey != hotkey
if ulanzi_changed:
    action["ActionParam"]["Hotkey"] = hotkey

print("==> Planned changes:")
print("    Karabiner rule: %s" % ("install/update" if karabiner_changed else "already installed"))
print("    Vibe Key Voice Input: %r -> %r" % (old_hotkey, hotkey) if ulanzi_changed
      else "    Vibe Key Voice Input: already %r" % hotkey)
if dry_run:
    print("  ! Dry run — nothing written.")
    raise SystemExit(0)
if not karabiner_changed and not ulanzi_changed:
    print("  ✓ Vibe Key support already configured — nothing to change.")
    raise SystemExit(0)

stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
def atomic_write(path, data):
    directory = os.path.dirname(path)
    fd, temp_path = tempfile.mkstemp(prefix=os.path.basename(path) + ".tmp.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        with open(temp_path, encoding="utf-8") as fh:
            json.load(fh)
        os.replace(temp_path, path)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)

if karabiner_changed:
    backup = karabiner_path + ".bak." + stamp
    shutil.copy2(karabiner_path, backup)
    atomic_write(karabiner_path, karabiner)
    print("  ✓ Karabiner rule installed (backup: %s)" % backup)
if ulanzi_changed:
    backup = ulanzi_path + ".bak." + stamp
    shutil.copy2(ulanzi_path, backup)
    atomic_write(ulanzi_path, ulanzi)
    print("  ✓ Vibe Key hotkey updated (backup: %s)" % backup)
PY

if [[ "$DRY_RUN" == "0" && "$RELAUNCH" == "1" && "$WAS_RUNNING" == "1" ]]; then
  info "Relaunching Ulanzi Studio to load the edited local preset…"
  open -a "Ulanzi Studio"
elif [[ "$DRY_RUN" == "0" && "$RELAUNCH" == "0" && "$WAS_RUNNING" == "1" ]]; then
  warn "Ulanzi Studio was left stopped (--no-launch). Start it to load the preset."
fi

if [[ "$DRY_RUN" == "1" ]]; then
  ok "Dry run complete; the built-in Globe shortcut and live files were unchanged."
else
  ok "The local Vibe Key profile declares Handy's Ctrl+Option+Command+R binding."
  ok "Karabiner maps the built-in Globe key to the same binding."
  warn "Ulanzi only pushes a shortcut to the device after an in-app hotkey edit."
  warn "  In Studio ▸ Voice Input, enter Ctrl+Option+Command+T and click away,"
  warn "  then enter Ctrl+Option+Command+R and click away to commit and sync."
fi
