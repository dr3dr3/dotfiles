#!/usr/bin/env bash
# =============================================================================
# setup-pi-ollama.sh — point Pi (in a dev container) at the host's Ollama.
#
# Generates Pi's `ollama` provider block FROM THE LIVE HOST and merges it into a
# container's ~/.pi/agent/models.json, leaving every other provider untouched.
#
# Usage:
#   ./scripts/setup-pi-ollama.sh --print               # show the JSON, write nothing
#   ./scripts/setup-pi-ollama.sh roe-devcontainer      # install into that container
#   ./scripts/setup-pi-ollama.sh roe-devcontainer --context 65536
#
# -----------------------------------------------------------------------------
# WHY GENERATE INSTEAD OF TRACKING A models.json
#
# A hand-written model list goes stale silently, and had: on 2026-09-14 this
# host's Pi listed `qwen3.5:35b-a3b-coding-nvfp4`, a model that was no longer
# installed, while the model that WAS installed did not appear at all. Pi cannot
# tell — it just offers you a model that 404s.
#
# Ollama already knows the truth, so ask it. /api/tags gives the installed
# models and /api/show gives each one's capabilities and real context length.
# Re-run this after any `olu` / `olrm` and the list is correct by construction.
#
# -----------------------------------------------------------------------------
# WHY THERE IS NO 0.0.0.0 BIND HERE
#
# baseUrl is host.docker.internal:11434 against Ollama's DEFAULT 127.0.0.1 bind.
# OrbStack forwards host.docker.internal to the host loopback, so that works and
# keeps a no-auth inference server off the LAN. See .dotfiles/zsh/.config/zsh/
# env.zsh for the evidence. On Docker Desktop you would need `o-expose` first.
#
# -----------------------------------------------------------------------------
# THE compat FLAGS ARE MEASURED, NOT GUESSED
#
# Verified 2026-09-14 against Ollama 0.33.3 + qwen3.8:27b-mlx over /v1:
#   * reasoning_effort WORKS and is monotonic — "none" produced 0 reasoning
#     characters and a 3-token answer; low/medium/high/xhigh/max produced
#     progressively more. So supportsReasoningEffort: true, and "off" maps to
#     "none" rather than being marked unsupported.
#   * chat_template_kwargs.enable_thinking was IGNORED — identical output to no
#     control at all. So thinkingFormat "qwen-chat-template" would be wrong
#     here, even though this is a Qwen model; Ollama does not forward it.
#   * Ollama does not reject unknown reasoning_effort values, so a wrong level
#     fails silently rather than erroring. "minimal" behaved anomalously (MORE
#     thinking than the default) and is mapped to null for that reason.
# Re-measure these if you change the model or upgrade Ollama.
#
# -----------------------------------------------------------------------------
# WHERE THIS RUNS, AND WHERE THE FILE LANDS
#
# The SCRIPT runs on the HOST (it reads the host's Ollama on 127.0.0.1 and uses
# docker exec to install). The FILE lands INSIDE the container, because that is
# where Pi runs and reads it.
#
# And ~/.pi is NOT on a volume — verified 2026-09-14 on roe-devcontainer, whose
# volumes cover ~/.ai, ~/.config and ~/.aws but not ~/.pi. A plain write there
# lives in the container layer and is DESTROYED by `dcb`, exactly like the
# ~/.local/bin case in README › Tools.
#
# So this follows the pattern docs/PERSISTENCE.md already uses for Codex: keep
# the real file on the AI volume (~/.ai/pi/models.json) and symlink the path Pi
# reads at it. When ~/.ai is not a mount, it falls back to a direct write and
# says plainly that a rebuild will eat it.
#
# BOUNDARY: Pi itself is installed by dotai, not this repo, and the volumes come
# from local-dev-env. This script only writes the one file that points Pi at the
# host Ollama this repo declares — using a volume that already exists, so it
# needs no change to either of those repos.
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
PI_MODELS_PATH=".pi/agent/models.json"
# What the CONTAINER uses to reach the host. Not the same as OLLAMA_URL above,
# which is how THIS script (running on the host) reaches it.
CONTAINER_BASE_URL="http://host.docker.internal:11434/v1"

PRINT_ONLY=0
CONTAINER=""
CONTEXT_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print)     PRINT_ONLY=1; shift ;;
    --context)   CONTEXT_OVERRIDE="${2:-}"; shift 2 ;;
    -h|--help)   sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)          echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
    *)           CONTAINER="$1"; shift ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

# --- 0. host Ollama must be up ----------------------------------------------
curl -fsS --max-time 5 "$OLLAMA_URL/api/version" >/dev/null 2>&1 \
  || die "No Ollama at $OLLAMA_URL. Start it with \`o-up\` (brew services), then re-run."

# --- 1. generate the provider block from live state --------------------------
PROVIDER_JSON="$(
  OLLAMA_URL="$OLLAMA_URL" \
  CONTAINER_BASE_URL="$CONTAINER_BASE_URL" \
  CONTEXT_OVERRIDE="$CONTEXT_OVERRIDE" \
  /usr/bin/python3 <<'PY'
import json, os, sys, urllib.request

base   = os.environ["OLLAMA_URL"]
cap    = os.environ.get("CONTEXT_OVERRIDE") or ""
cap    = int(cap) if cap else None

def api(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req  = urllib.request.Request(base + path, data=data,
                                  headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=30))

tags = api("/api/tags").get("models", [])
if not tags:
    print("NO_MODELS", file=sys.stderr); raise SystemExit(3)

models = []
for t in sorted(tags, key=lambda m: m["name"]):
    name = t["name"]
    try:
        show = api("/api/show", {"model": name})
    except Exception as e:
        print("SKIP %s (%s)" % (name, e), file=sys.stderr)
        continue

    caps = show.get("capabilities") or []
    if "completion" not in caps:
        continue                      # embedding-only models are not chat models

    # Real context length, whatever the architecture calls it.
    ctx = next((v for k, v in (show.get("model_info") or {}).items()
                if k.endswith("context_length")), 32768)
    if cap:
        ctx = min(ctx, cap)

    det   = show.get("details") or {}
    label = " ".join(x for x in (det.get("parameter_size"),
                                 det.get("quantization_level")) if x)

    entry = {
        "id":   name,
        "name": "%s (local Ollama%s)" % (name.split(":")[0], ", " + label if label else ""),
        # `thinking` in Ollama's capabilities == extended reasoning in Pi.
        "reasoning": "thinking" in caps,
        "input": ["text", "image"] if "vision" in caps else ["text"],
        # It runs on your own hardware; there is no per-token price to track.
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": ctx,
        # Ollama reports no max-output; this matches Pi's own default for the
        # provider and is a cap on the reply, not on the context.
        "maxTokens": 16384,
    }

    compat = {
        # Ollama's /v1 shim does not implement the "developer" role.
        "supportsDeveloperRole": False,
    }
    if "thinking" in caps:
        compat["supportsReasoningEffort"] = True
        # NB: thinkingLevelMap is a MODEL-level field in Pi's ProviderModelConfig,
        # a sibling of compat — not a compat flag. Nesting it inside compat makes
        # it silently inert.
        entry["thinkingLevelMap"] = {
            "off":     "none",     # measured: 0 reasoning characters
            "minimal": None,       # measured: MORE thinking than default — unusable
            "low":     "low",
            "medium":  "medium",
            "high":    "high",
            "xhigh":   "xhigh",
            "max":     "max",
        }
    entry["compat"] = compat
    models.append(entry)

print(json.dumps({
    "baseUrl": os.environ["CONTAINER_BASE_URL"],
    "api":     "openai-completions",
    # Ollama ignores the value but the OpenAI client requires one to be present.
    "apiKey":  "ollama",
    "models":  models,
}, indent=2))
PY
)" || die "Could not read models from $OLLAMA_URL (is anything pulled? try \`oll\`)"

model_count="$(/usr/bin/python3 -c 'import json,sys; print(len(json.loads(sys.stdin.read())["models"]))' <<<"$PROVIDER_JSON")"
ok "Generated provider block for $model_count model(s) from the live host."

if [[ "$PRINT_ONLY" == "1" ]]; then
  /usr/bin/python3 -c '
import json,sys
print(json.dumps({"providers":{"ollama":json.loads(sys.stdin.read())}}, indent=2))' <<<"$PROVIDER_JSON"
  exit 0
fi

# --- 2. target container -----------------------------------------------------
if [[ -z "$CONTAINER" ]]; then
  die "No container given.
      Usage: ./scripts/setup-pi-ollama.sh <container> [--context N]
             ./scripts/setup-pi-ollama.sh --print
      Running containers:
$(docker ps --format '        {{.Names}}' 2>/dev/null || echo '        (docker unavailable)')"
fi
docker inspect "$CONTAINER" >/dev/null 2>&1 || die "No such container: $CONTAINER"
docker exec "$CONTAINER" sh -lc 'command -v pi' >/dev/null 2>&1 \
  || warn "pi is not on PATH in $CONTAINER — writing the config anyway (dotai installs pi)."

# --- 3. can the container actually reach the host? ---------------------------
# Check before writing, so a config that cannot work is never installed.
if docker exec "$CONTAINER" sh -lc \
     "curl -fsS --max-time 5 ${CONTAINER_BASE_URL%/v1}/api/version" >/dev/null 2>&1; then
  ok "$CONTAINER reaches the host Ollama at $CONTAINER_BASE_URL"
else
  die "$CONTAINER cannot reach $CONTAINER_BASE_URL.
      Under OrbStack this should work against Ollama's default loopback bind.
      On Docker Desktop, run \`o-expose\` on the host first (LAN-visible — see
      docs/CHEATSHEET.md), or check that the host Ollama is running (\`olp\`)."
fi

# --- 4. merge, preserving every other provider -------------------------------
HOME_IN_C="$(docker exec "$CONTAINER" sh -lc 'echo $HOME' | tr -d '\r')"
PI_PATH="$HOME_IN_C/$PI_MODELS_PATH"          # where Pi actually reads
PERSIST_DIR="$HOME_IN_C/.ai/pi"               # on the AI volume, survives rebuilds

# Is ~/.ai a real mount in this container, or just a directory in the layer?
if docker exec "$CONTAINER" sh -lc "mountpoint -q '$HOME_IN_C/.ai' 2>/dev/null" \
   || docker exec "$CONTAINER" sh -lc "grep -q ' $HOME_IN_C/.ai ' /proc/self/mountinfo 2>/dev/null"; then
  TARGET="$PERSIST_DIR/models.json"
  PERSISTENT=1
  ok "~/.ai is a volume — storing on it so a rebuild cannot eat this"
else
  TARGET="$PI_PATH"
  PERSISTENT=0
  warn "~/.ai is not a volume in $CONTAINER — writing directly to ~/$PI_MODELS_PATH"
  warn "  a container rebuild (\`dcb\`) WILL destroy it; re-run this script after one"
fi

# Read whichever copy already has content. On the FIRST persistent run the
# volume path does not exist yet and the real config is still at the Pi path —
# reading only $TARGET there would silently drop every other provider.
existing="$(docker exec "$CONTAINER" sh -lc \
  "cat '$TARGET' 2>/dev/null || cat '$PI_PATH' 2>/dev/null || echo ''" || true)"

MERGE_ERR="$(mktemp)"; trap 'rm -f "$MERGE_ERR"' EXIT
MERGED="$(PROVIDER_JSON="$PROVIDER_JSON" EXISTING="$existing" /usr/bin/python3 2>"$MERGE_ERR" <<'PY'
import json, os, sys

provider = json.loads(os.environ["PROVIDER_JSON"])
raw      = os.environ.get("EXISTING", "").strip()

if raw:
    try:
        doc = json.loads(raw)
    except Exception as e:
        print("UNPARSEABLE:%s" % e, file=sys.stderr)
        raise SystemExit(4)
    if not isinstance(doc, dict):
        print("UNPARSEABLE:top level is not an object", file=sys.stderr)
        raise SystemExit(4)
else:
    doc = {}

doc.setdefault("providers", {})
if not isinstance(doc["providers"], dict):
    print("UNPARSEABLE:providers is not an object", file=sys.stderr)
    raise SystemExit(4)

before = json.dumps(doc.get("providers", {}).get("ollama"), sort_keys=True)
doc["providers"]["ollama"] = provider          # only this key is replaced
after  = json.dumps(provider, sort_keys=True)

print("CHANGED" if before != after else "UNCHANGED", file=sys.stderr)
others = [k for k in doc["providers"] if k != "ollama"]
print("OTHERS:%s" % ",".join(others), file=sys.stderr)
print(json.dumps(doc, indent=2))
PY
)" || { merge_err="$(cat "$MERGE_ERR")"
        if grep -q '^UNPARSEABLE' <<<"$merge_err"; then
          die "$TARGET is not valid JSON — ${merge_err#UNPARSEABLE:}
      Refusing to overwrite it. Inspect or move it, then re-run."
        fi
        die "Merge failed — $merge_err"; }

merge_err="$(cat "$MERGE_ERR")"
if grep -q '^UNPARSEABLE' <<<"$merge_err"; then
  die "$TARGET is not valid JSON — ${merge_err#UNPARSEABLE:}
      Refusing to overwrite it. Inspect or move it, then re-run."
fi

others="$(sed -n 's/^OTHERS://p' <<<"$merge_err")"
[[ -n "$others" ]] && ok "Preserving other provider(s): ${others//,/, }"

# "Unchanged" is about CONTENT. It is not a reason to skip the write when the
# file is still sitting in the ephemeral location — same bytes, wrong place,
# gone on the next rebuild.
NEEDS_MIGRATION=0
if [[ "$PERSISTENT" == "1" ]]; then
  docker exec "$CONTAINER" sh -lc \
    "[ -f '$TARGET' ] && [ -L '$PI_PATH' ] && [ \"\$(readlink '$PI_PATH')\" = '$TARGET' ]" \
    >/dev/null 2>&1 || NEEDS_MIGRATION=1
fi

if grep -q '^UNCHANGED' <<<"$merge_err" && [[ "$NEEDS_MIGRATION" == "0" ]]; then
  ok "Pi already points at these exact models — nothing to write."
  exit 0
fi
[[ "$NEEDS_MIGRATION" == "1" ]] && info "Moving the config onto the AI volume so it survives a rebuild…"

# --- 5. write (backup first) -------------------------------------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
docker exec "$CONTAINER" sh -lc "
  set -e
  mkdir -p '$(dirname "$TARGET")'
  [ -f '$TARGET' ] && cp '$TARGET' '$TARGET.bak.$STAMP' && echo '  backup: $TARGET.bak.$STAMP' || true
"
# The payload is valid by construction (json.dumps above), but re-parse it here
# so a truncated heredoc or a stray log line can never reach the container.
/usr/bin/python3 -c 'import json,sys; json.loads(sys.stdin.read())' <<<"$MERGED" \
  || die "Refusing to write: generated JSON did not re-parse."

printf '%s\n' "$MERGED" \
  | docker exec -i "$CONTAINER" sh -lc "cat > '$TARGET.tmp' && mv '$TARGET.tmp' '$TARGET'" \
  || die "Write failed; $TARGET left untouched."
ok "Wrote $TARGET in $CONTAINER"

# Point the path Pi reads at the persisted copy. Any pre-existing real file
# there is moved aside rather than deleted — it may be hand-written config.
if [[ "$PERSISTENT" == "1" ]]; then
  docker exec "$CONTAINER" sh -lc "
    set -e
    mkdir -p '$(dirname "$PI_PATH")'
    if [ -L '$PI_PATH' ]; then
      :                                    # already a link; repoint below
    elif [ -e '$PI_PATH' ]; then
      mv '$PI_PATH' '$PI_PATH.pre-persistence.$STAMP'
      echo '  moved aside: $PI_PATH.pre-persistence.$STAMP'
    fi
    ln -sfn '$TARGET' '$PI_PATH'
  " || die "Wrote the file but could not link $PI_PATH to it."
  ok "Linked ~/$PI_MODELS_PATH -> ~/.ai/pi/models.json (survives \`dcb\`)"
fi

# --- 6. prove it -------------------------------------------------------------
info "Asking pi what it can see:"
docker exec "$CONTAINER" sh -lc 'pi --list-models 2>/dev/null | head -20' \
  || warn "pi --list-models did not run (pi may not be installed yet)."

cat <<'EOF'

────────────────────────────────────────────────────────────────────────────
Use it:   pi --provider ollama --model <id>
          pi --provider ollama --model <id> --thinking off    # fastest

Re-run this script after any \`olu\` / \`olrm\` — the list is generated from the
host, so it only stays correct if you regenerate it.

Measured on this host (M5 Pro, 2026-09-14), 12.6k-token prompt:

  qwen3.8:27b-mtp-q4_K_M   prefill 314 tok/s   gen 26.2 tok/s   <- prefer this
  qwen3.8:27b-mlx          prefill 129 tok/s   gen 24.5 tok/s

PREFILL is what you feel in an agentic loop, and MTP (built-in speculative
decoding) is 2.4x faster at it despite running on the Metal path rather than
MLX. End to end, one `pi -p` turn: 134s cold vs 277s on -mlx.

The SECOND call is ~0s — Ollama caches the prompt prefix, and Pi resends the
same system prompt and tool definitions every turn. So you pay the prefill once
per session, not once per turn. `--thinking off` maps to reasoning_effort=none
and skips reasoning entirely; use it for tool-heavy turns.
────────────────────────────────────────────────────────────────────────────
EOF
