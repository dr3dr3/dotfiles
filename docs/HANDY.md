# Handy — local voice dictation

[Handy](https://handy.computer/) is push-to-talk dictation that transcribes
**on-device** and pastes the result into whatever window has focus. On this host
that means: hold the hotkey, speak a prompt, release, and the text lands in the
Ghostty pane where Herdr is waiting.

- Installed by: `cask "handy"` in the [Brewfile](../Brewfile)
- Configured by: [`scripts/setup-handy.sh`](../scripts/setup-handy.sh)
- Vibe Key bridge: [`scripts/setup-handy-vibe-key.sh`](../scripts/setup-handy-vibe-key.sh)
- Vocabulary source: [`config/handy/vocabulary.txt`](../config/handy/vocabulary.txt)
- Settings live in `~/Library/Application Support/com.pais.handy/` — **not** in
  this repo, and not stowed. See [Why nothing here is stowed](#why-nothing-here-is-stowed).

**Nothing leaves the Mac.** Transcription is whisper.cpp running locally against
Metal. There is no account, no API key, no subscription, and no per-minute cost.
The only network traffic Handy makes is the one-off model download and its
update check. The single feature that *would* send text off-box is
post-processing (it POSTs the transcript to OpenAI/Anthropic/Groq/…), and it is
pinned off — see the settings table below.

> **Host-native on purpose.** Dictation needs the microphone and the macOS
> paste path, neither of which a dev container has. Handy types into the focused
> window, so the container side needs no awareness of it at all — the same shape
> as Karabiner-Elements. There is nothing to install in the devcontainer.

---

## First run

```bash
brew bundle                  # installs the cask (HOMEBREW_BUNDLE_FILE is set)
open -a Handy                # once, so it writes its default settings store
./scripts/setup-handy.sh     # apply this repo's profile
```

Then three things remain, in this order:

### 1. Grant the two macOS permissions

These are TCC permissions. **Nothing in this repo touches TCC**, and you should
be suspicious of anything that offers to: the whole point of that database is
that an app cannot grant itself access. Handy prompts on first use; if you
dismissed a prompt, grant them by hand:

| Pane | Why Handy needs it | What it looks like when missing |
| --- | --- | --- |
| **Privacy & Security ▸ Microphone** | capture audio | loud, obvious — no audio, an error in the overlay |
| **Privacy & Security ▸ Accessibility** | send the paste keystroke to the focused app | **silent** — recording and transcription work, the text just never appears |

Accessibility is the one that wastes an afternoon. If dictation "does nothing",
check that pane before anything else.

> Ghostty may *also* need Accessibility for the paste to land in a terminal
> pane. If text appears in TextEdit but not in Ghostty, add Ghostty to the same
> list.

### 2. Download the transcription model

`scripts/setup-handy.sh` deliberately does **not** set `selected_model` — that
key names a model file that must already be on disk, and pointing it at an
absent model leaves Handy unable to transcribe at all. Pick it in the app:

**Handy ▸ Settings ▸ Models ▸ Whisper Medium** (~1.5GB download, Q8_0 quant).

Models land in `~/Library/Application Support/com.pais.handy/models/`. They are
not brew-owned and not in Git.

> **Consider "Whisper Medium (English)" instead.** Same size and speed, trained
> English-only, and measurably better on English technical speech. Since the
> profile below pins the language to English anyway, the multilingual capacity
> of plain Whisper Medium buys nothing here. Plain Medium is what this profile
> documents because it is what was asked for; the `.en` variant is a free
> accuracy upgrade if you want it.

### 3. Globe and Ulanzi Vibe Key triggers

Handy's single Transcribe binding is **Ctrl+Option+Command+R**. The Ulanzi Vibe
Key emits that ordinary shortcut directly. Karabiner translates the physical
MacBook Fn/Globe key to the same chord, preserving the existing Globe workflow
(including its double-tap behaviour).

The direction matters: Ulanzi Studio posts synthetic macOS keyboard events,
which are downstream of Karabiner's physical HID remapping. Consequently a
Ulanzi-chord-to-Fn Karabiner rule cannot see the event; the Globe-to-chord rule
can. Handy uses its `tauri` global-shortcut backend here because its lower-level
`handy_keys` backend does not receive Ulanzi's synthetic chord.

Apply the bridge after Ulanzi Studio has discovered the AU05 and loaded its
default preset:

```bash
./scripts/setup-handy-vibe-key.sh --dry-run
./scripts/setup-handy-vibe-key.sh
```

The script changes only the selected AU05 profile's `Voice Input` action at
keypad slot `0_0`, installs the tracked Karabiner rule, and backs up both live
JSON files before writing. It refuses unexpected devices, profiles, actions or
hotkeys. Ulanzi Studio is relaunched to load the local profile.

**Finish the device sync in Ulanzi Studio.** A JSON edit plus relaunch does not
invoke Studio's profile-to-device update path. Select **Voice Input**, enter
**Ctrl+Option+Command+T**, click away, then enter
**Ctrl+Option+Command+R** and click away again. That committed editor change
pushes the preset to the Vibe Key. After a successful sync, Ulanzi's documented
offline mode can use the saved shortcut. `doctor-mac.sh` can verify the local
profile but cannot read the shortcut stored on the device.

macOS Dictation's own symbolic double-Fn hotkey remains disabled on this Mac so
it does not compete with Handy. `doctor-mac.sh` checks that OS setting, Handy's
binding, the Karabiner route, and the active Vibe Key profile.

---

## The managed profile

`scripts/setup-handy.sh` merges exactly these keys and leaves every other
setting alone. Re-run it any time — it is idempotent, and a run that would
change nothing writes nothing.

| Setting | Value | Why |
| --- | --- | --- |
| `push_to_talk` | `true` | hold to talk, release to transcribe — no toggle state to lose track of |
| `bindings.transcribe.current_binding` | `"control+option+command+r"` | receives Ulanzi directly and physical Globe through Karabiner |
| `auto_submit` | **`false`** | **safety-critical, see below** |
| `post_process_enabled` | `false` | the only feature that would send text off this Mac |
| `selected_language` | `"en"` | `auto` runs language ID per utterance and mis-detects short technical phrases |
| `translate_to_english` | `false` | nothing to translate when the source is English |
| `paste_method` | `"ctrl_v"` | the clipboard path — and the one that restores your clipboard |
| `clipboard_handling` | `"dont_modify"` | leave the restored clipboard alone |
| `keyboard_implementation` | `"tauri"` | receives Ulanzi Studio's synthetic global shortcut |
| `recording_retention_period` | `"preserve_limit"` | pairs with the limit below to delete recordings |
| `history_limit` | `0` | keep no transcript history |
| `selected_microphone` | `"MacBook Pro Microphone"` | pin the built-in mic |
| `autostart_enabled` | `true` | launch at login |
| `custom_words` | from `config/handy/vocabulary.txt` | developer terms, merged as a union |

### ⚠️ Auto Submit must stay off

`auto_submit` appends the `auto_submit_key` (default Return) to every
transcript. With it on, dictating into a terminal **runs whatever Whisper
heard** — no pause, no chance to read it first. Against a shell, or an agent
prompt that can execute tools, a misheard phrase becomes an executed command.

It is off by default, this script pins it off, and `doctor-mac.sh` fails if it
is ever on. If you turn it on in the UI, the next `upd` will tell you.

### Recordings and history: the trap in the naming

Handy's retention enum has a variant literally called `never`, and it does
**not** mean "never keep recordings" — reading upstream, `Never => don't delete
anything`, i.e. keep every WAV forever. It disables cleanup.

The combination that actually deletes is `preserve_limit` + `history_limit: 0`:
after each transcription Handy prunes every unsaved entry, deleting both the
database row and the WAV file on disk. That is what this profile sets.

Two honest caveats:

- A recording exists on disk **between** the transcription finishing and the
  cleanup running. It is deleted within the same operation, but there is a
  window — this is "delete immediately after", not "never write to disk".
- Entries you explicitly **star/save** in Handy's history are exempt
  (`WHERE saved = 0`). If you save one, it stays until you delete it.

### Clipboard preserve/restore

Handy has no "restore clipboard" toggle, because restore is unconditional in the
clipboard paste path: it snapshots the current clipboard (text, or an image when
there is no text), writes the transcript, sends ⌘V, then puts the original back.
Two settings keep you on that path — `paste_method: ctrl_v` (a `direct`
keystroke method bypasses the clipboard entirely, and the restore with it) and
`clipboard_handling: dont_modify` (the alternative, `copy_to_clipboard`,
deliberately overwrites the clipboard with the transcript afterwards).

### Launch at login — a deliberate exception

This repo is otherwise strict that the host runs **no** background services:
Ollama and Herdr are both "start on demand, stop to reclaim memory". Handy gets
an exception because a dictation hotkey that needs launching first is a
dictation hotkey you stop using.

The cost is small and bounded: Handy idles as a ~40MB tray app, and the model
(the expensive part) is unloaded after 5 minutes idle — `model_unload_timeout`
is `min5` — so the GB-scale weights are not resident between dictations.

If you would rather keep the no-login-items rule intact:

```bash
./scripts/setup-handy.sh --no-autostart
```

…then turn the login item off in **System Settings ▸ General ▸ Login Items**.
The script leaves the setting alone with that flag but will not un-register an
item macOS has already registered.

---

## Developer vocabulary

[`config/handy/vocabulary.txt`](../config/handy/vocabulary.txt) is the tracked
source. One term per line, `#` comments, blank lines ignored.

```bash
$EDITOR config/handy/vocabulary.txt
./scripts/setup-handy.sh          # merge into Handy
```

`custom_words` is a **post-transcription corrector**, not a hint to the model.
Handy walks 1-, 2- and 3-word n-grams of the finished transcript and replaces
any that fuzzily match a listed term (soundex + Levenshtein, gated on
`word_correction_threshold`, default `0.18`). Punctuation and case are stripped
before matching, which is why "dev container" → `devcontainer` and "charge bee"
→ `ChargeBee` work. The casing in the file is the casing you get.

The merge is a **union**: terms you add in Handy's own Settings ▸ Words pane are
preserved, and this file only ever adds (matching case-insensitively, so
re-casing a term here updates it rather than duplicating it).

> Keep the list tight. Every term is a chance to fuzzily rewrite a correctly
> transcribed word into something else — the matcher has no notion of context,
> and short or common-sounding terms will collide with ordinary speech. Add a
> term once you have actually watched Handy get it wrong.

---

## Why nothing here is stowed

`~/Library/Application Support/com.pais.handy/` holds, alongside the settings:

| Path | What it is |
| --- | --- |
| `models/` | GGUF model weights — GB-scale |
| `recordings/` | raw WAV audio of everything you dictate |
| `history.db` | transcript text |
| `settings_store.json` | settings — **and** any post-processing API keys |

Stowing that directory would pull all of it into this repo, which is precisely
the failure mode README › [Folded symlinks](../README.md#️-folded-symlinks-tools-can-write-into-this-repo)
documents fish, OrbStack and Unsloth each causing here. So the directory stays
outside Git entirely, and `scripts/setup-handy.sh` merges individual keys into
the live file instead.

Backups the script takes (`settings_store.json.bak.<timestamp>`) are written
**beside the store**, not into the repo, for the same reason — the file can
contain API keys.

---

## How the automation fails safely

`settings_store.json` is Handy's own serde-serialised `AppSettings` struct, and
it stamps `settings_schema_version`. Several managed values are Rust enum
variants from a specific build.

- The script **refuses to write** unless the stamp equals the version it was
  verified against (currently `2`, Handy 0.9.6). On a mismatch it changes
  nothing and points here.
- Every value is checked against a whitelist of legal variants before the write.
- It **quits Handy first** — Handy holds settings in memory and rewrites the
  whole store on change, so an edit made while it runs is silently clobbered.
- It takes a **timestamped backup**, but only when something will actually
  change, so re-runs do not litter.
- It writes to a temp file, **re-reads and verifies** it, and only then does an
  atomic `os.replace`. A failed verification leaves the original untouched.

Handy itself adds a backstop: it salvages per key, so a value it cannot parse is
dropped in favour of that key's default with a log line, rather than the whole
store being reset. That is a good safety net and a bad thing to rely on — a
silently defaulted key gives you the *opposite* of what you asked for.

### When the schema gate trips

Don't guess at the new format. Re-verify against the installed build, then
update `EXPECTED_SCHEMA_VERSION` and the `MANAGED` table in the script:

```bash
python3 -m json.tool ~/Library/Application\ Support/com.pais.handy/settings_store.json | less
```

Until then, configure by hand with the checklist below.

---

## Manual configuration checklist

Everything the script does, as UI steps — for a machine where the schema gate
trips, or when you just want to confirm what you're running.

**Handy ▸ Settings**

- **General**
  - Launch at login — **on**
  - Push to talk — **on**
- **Bindings**
  - Transcribe — **Ctrl+Option+Command+R**
- **Audio**
  - Microphone — **MacBook Pro Microphone**
- **Models**
  - **Whisper Medium** (downloaded and selected)
  - Language — **English** (not Auto)
  - Translate to English — **off**
- **Output**
  - **Auto Submit — OFF** ← confirm this one every time
  - Paste method — **Cmd+V / clipboard**
  - Clipboard handling — **Don't modify**
- **Post-processing**
  - Enabled — **off** (and no API keys entered)
- **History**
  - History limit — **0**
  - Recording retention — **Preserve limit**
- **Words**
  - the terms from `config/handy/vocabulary.txt`

---

## Verifying

`doctor-mac.sh` asserts the live settings match this profile, and runs as the
last step of `upd`:

```bash
./doctor-mac.sh            # full read-only host audit
./scripts/setup-handy.sh --dry-run   # what would change, changes nothing
```

---

## Using it with Herdr

The Vibe Key and the MacBook's built-in **Fn/Globe** key are two physical routes
to Handy's managed `Ctrl+Option+Command+R` binding. Hold either to talk and
release it to transcribe. That reserved chord does not
collide with the Herdr prefix — Caps Lock / `Ctrl+Alt+Space`, see
[HERDR.md](HERDR.md).

This applies to the key on Apple's built-in keyboard. Logitech's Fn key is
handled inside the keyboard and does not reach macOS as a normal bindable key,
so use the MacBook key when the external keyboard is connected.

Typical loop: focus the Ghostty pane running Herdr, then use Globe as before or
hold the Vibe Key's Voice Input key, speak, and release. The text appears at the
cursor. **Read it, then press Return yourself** — that pause is what Auto Submit
would take away.

Dictation quality drops on strings speech is bad at: long file paths, version
numbers, flags. Expect to fix those by hand, and prefer dictating intent
("rerun the failing test in the devcontainer") over syntax.
