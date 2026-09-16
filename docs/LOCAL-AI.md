# Local AI — Ollama, Pi, and overnight batches

Everything about running a model on this Mac and pointing the Pi harness at it.
Read this one when you come back to it in three months.

- **Model runtime:** Ollama, host-native (`brew "ollama"`)
- **Agent:** Pi, in the dev container (installed by dotai, not this repo)
- **Config generator:** [`scripts/setup-pi-ollama.sh`](../scripts/setup-pi-ollama.sh)
- **Overnight runner:** [`pi-batch`](../.dotfiles/bin/.local/bin/pi-batch) ·
  [`pi-batch-review`](../.dotfiles/bin/.local/bin/pi-batch-review)
- Daily commands: [CHEATSHEET](CHEATSHEET.md) · first-time setup: [SETUP.md](../SETUP.md)

**The shape.** Ollama serves models on the host. Pi runs inside the project's dev
container and reaches Ollama over `host.docker.internal`. Claude or Codex plans a
batch of work and writes a brief; Pi executes it overnight on the local model;
you review a branch in the morning.

---

## Which model, and why

```bash
oll                                  # what is installed
echo $PI_LOCAL_MODEL                 # what the wrappers use
```

`PI_LOCAL_MODEL` (set in `env.zsh`, `config.fish`, `config.nu` — one value, three
shells) is the single source of truth. Change it there, not in the wrappers.

**Current default: `qwen3-coder:30b-a3b-q4_K_M`.**

Benchmarked on this host (M5 Pro, 64GB), 12.6k-token prompt:

| Tag | Prefill | Generation | Cold load | Size |
| --- | --- | --- | --- | --- |
| **`qwen3-coder:30b-a3b-q4_K_M`** | **766 t/s** | **62.7 t/s** | 5.6s | 18GB |
| `qwen3.8:27b-mtp-q4_K_M` | 314 t/s | 26.7 t/s | 13.9s | 17GB |
| `qwen3.8:27b-mlx` *(removed)* | 129 t/s | 24.5 t/s | — | 18GB |

**Prefill is the number that matters** in an agentic loop — it is what you wait
through before the first token, and a tool-use turn re-sends a large context every
time. The coder model wins because it is **Mixture-of-Experts**: 30B total but only
~3.3B *active* per token. It was also RL-trained for agentic SWE.

Two counter-intuitive results worth keeping:

- **`-mlx` is not automatically the fast one.** Ollama runs on Apple's MLX on
  Apple Silicon (0.19+), so `-mlx` tags use the MLX engine and plain GGUF tags
  fall back to Metal — which makes `-mlx` look like the obvious pick. It was the
  *slowest* thing here. `mtp` tags (built-in multi-token prediction, i.e.
  self-speculative decoding) beat it 2.4x on the Metal path, and the MoE coder
  model beat *that* by another 2.4x.
- **Architecture beat quantisation.** Chasing a bigger quant would have cost
  memory for less gain than switching to MoE.

**Keep `qwen3.8:27b-mtp-q4_K_M`** as the generalist — the coder model has **no
thinking and no vision**; Qwen3.8 has both. Different jobs.

### Memory budget — why q4 and not q8

64GB total, but that is not the number that matters:

```
devcontainer ~19GB  +  model  +  macOS ~8GB
```

OrbStack's VM is capped around 39GB and the ROE stack alone holds ~19GB of it. So
a 19GB q4 model lands near 46GB with real headroom, while a 32GB q8 lands near
59GB and you swap by 3am. If you idle the app containers overnight, q8 becomes
viable — but that is a change to your stack, not a model choice.

> A 27B model resident is ~19GB of unified memory that the containers do not get.
> Local LLM memory is not free.

---

## Day-to-day

| Command | Does |
| --- | --- |
| `pil` | Pi on the local model, `--thinking off` |
| `piw` | preload the model so the first turn is not cold |
| `olp` | what is resident right now (with an `UNTIL` column) |
| `o-stop <model>` | **unload** from memory, model stays on disk |
| `olrm <model>` | **DELETE** from disk — not an unload |
| `o-up` / `o-down` | start / stop the server |
| `o-night` / `o-day` | pin / release the model between agent turns |

⚠️ **`olrm` is `ollama rm`.** It deletes an 18GB model. To free memory use
`o-stop`, or just wait — Ollama unloads after `OLLAMA_KEEP_ALIVE` (5 min default).
This page used to recommend `olrm` for reclaiming memory, which was wrong.

`pil` exists as a safety rail, not a shortcut: `pi --list-models` shows your local
models and ~250 **billed** gateway models in one flat list with nothing marking
which is which. `pil` is the local path your fingers learn.

---

## Wiring Pi to the host model

```bash
./scripts/setup-pi-ollama.sh --print              # inspect, change nothing
./scripts/setup-pi-ollama.sh roe-devcontainer     # install into a container
```

**Re-run it after every `olu` / `olrm`.** The provider block is *generated* from
the host's live `/api/tags` + `/api/show`, which is the whole point — a
hand-written list goes stale silently. It had: Pi was offering a model that was no
longer installed while omitting the one that was, with wrong capabilities and
context length.

What it writes: only the `ollama` provider key. Every other provider — including
Pi's built-in `vercel-ai-gateway` — is preserved.

The `compat` flags are measured, not guessed:

- `reasoning_effort` **works**, and `"none"` yields zero reasoning tokens. That is
  what `--thinking off` maps to.
- Ollama **ignores** `chat_template_kwargs`, so `thinkingFormat:
  "qwen-chat-template"` would be wrong here despite these being Qwen models.

### Where the config lives

`~/.pi/agent/models.json` **inside the container** — not `~/.config/pi/`. dotai
symlinks the whole `~/.pi/agent` directory onto the AI volume, so it already
survives a `dcb` rebuild. See [PERSISTENCE.md](PERSISTENCE.md).

> If it is ever *not* on the volume, the script puts the file on `~/.ai/pi/` and
> links it. It refuses to link a path onto itself — doing that once produced a
> self-referential symlink, Pi failed with `ELOOP`, and **every** provider
> disappeared, including the hosted ones the script does not manage.
> `doctor-mac.sh` now asserts the config actually loads.

---

## Overnight batches

```bash
pi-batch --brief work.md --test "make test"    # run
pi-batch --brief work.md --dry-run             # preflight only
pi-batch-review                                # morning read-out
pi-batch-review <stamp>                        # one run, with its diff
pi-batch-review --failed                       # only what needs attention
pi-batch-review --prune                        # drop records past 30 days
```

### The guardrails, and why each exists

| Guard | Because |
| --- | --- |
| `caffeinate -is` wraps the run | this Mac is `sleep 1` on AC — it suspends a minute after you walk away and takes OrbStack's VM with it. Scoped to the command, not your global `pmset`. |
| isolated `pi-batch/<stamp>` branch | your branch never receives an unattended commit |
| a pre-push hook that refuses | belt and braces; `git push` exits 1 |
| refuses a dirty tree | agent commits on top of your uncommitted work cannot be separated afterwards |
| tests before **and** after | records what was already broken, then gates the result |

Without `--test` there is no gate and the run says so. Pi has no permission
system — the container is the sandbox — so scope the brief to the work you want.

### Reviewing

**"Outstanding" means the branch still exists.** There is no reviewed flag: the
branch *is* what you must act on, so merging or deleting it is the review, and a
branch cannot drift out of sync the way a flag can. Parking something? Rename it
off the prefix (`git branch -m pi-batch/x parked/x`). `doctor-mac.sh` warns while
runs are unreviewed; `--prune` refuses to delete a record whose branch survives.

Records and logs live in `~/.local/state/pi-batch` — **host-only on purpose**.
`~/host-share` is mounted *into* the containers, and an agent able to read its own
past runs turns one night's mistakes into the next night's context.

---

## What the local model is and is not good at

**Good at:** directed work against a closed-world brief — writing tests, a named
refactor, mechanical changes across known files.

**Bad at research.** Pi's built-in tools are `read`, `bash`, `edit`, `write`. There
is **no web search and no fetch tool**. "Research" would mean a 3.3B-active model
driving `curl` and parsing HTML, badly and confidently. Have Claude/Codex do the
research at planning time and bake the findings into the brief as concrete facts,
paths and signatures. The local model then executes; that plays to both models'
strengths instead of asking the weak one to do the hard part.

### ⚠️ A passing test gate is necessary, not sufficient

From a real supervised run: the model wrote a correct parser and five readable
tests, the suite went 21 → 26, everything passed — and it **had not done what was
asked**. The brief said to assert against the real `config/handy/vocabulary.txt`;
it invented a hardcoded fixture instead and never opened the file. A dead
`from pathlib import Path` import was the only fingerprint.

The gate passed because it tested its own code against its own fixture. It also
**never committed**, despite an explicit instruction to.

So: **read the diff.** The gate catches broken code. Only you catch code that
answers a different question than the one you asked. Write briefs whose
requirements are checkable *from the diff*, and expect to commit the work
yourself — make the model's job writing code, not managing process.

---

## Containers reach Ollama on loopback — do not "fix" this

Ollama binds `127.0.0.1` and that is correct. **OrbStack forwards
`host.docker.internal` to the host loopback**, so containers reach it as-is while
your LAN cannot.

Verified with the server bound to loopback only: a fresh `docker run alpine` on
the default bridge and the project devcontainer both ran inference through it,
while this host's own LAN address refused the connection.

This repo previously asserted in six places that a `0.0.0.0` bind was *required*.
It is not, and setting one puts a **no-auth inference server on your network**.

- `o-up` starts the server on the loopback bind
- `o-expose` is the escape hatch — Docker Desktop (its sandbox blocks
  host-loopback access), another machine, a VM. LAN-visible; `o-up` undoes it.
- `doctor-mac.sh` keys off `docker context` and warns in *both* directions

---

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `Unknown provider "ollama"` | Pi's config is stale or broken — `./scripts/setup-pi-ollama.sh <container>` |
| `pi --list-models` warns about `models.json` | the config does not parse; check for a self-referential symlink, restore a `.bak.*` beside it |
| `pi-batch` refuses: dirty tree | commit or stash first — this is the guard working |
| `pi-batch` refuses: model not pulled | `olu $PI_LOCAL_MODEL` |
| Overnight run stopped early | the Mac slept — use `pi-batch`, which holds `caffeinate`, not bare `pi` |
| First call slow, rest instant | expected: model load + system-prompt prefill, then Ollama caches the prefix |
| A model is "gone" after freeing memory | you ran `olrm` (delete), not `o-stop` (unload) |
| `ollama pull` fails repeatedly with `Error: EOF` | corrupted partial blob — `rm ~/.ollama/models/blobs/*-partial*` and retry |
