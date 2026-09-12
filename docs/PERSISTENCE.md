# Personal tooling across devcontainer rebuilds

The workspace is a host bind mount: `/workspace/dotfiles` and
`/workspace/.ai/dotai` survive container replacement. Keep these clones at the
same paths because configuration links refer to them.

local-dev-env supplies volumes and calls the optional
`dotfiles/scripts/setup-devcontainer.sh` hook. This personal repo owns shell configuration, Starship, Herdr and
Atuin installation and shell setup. After cloning, run `roe setup-dotfiles`
(or `make setup-dotfiles`) inside the devcontainer to apply them immediately.
Existing shell configs are backed up under `~/.config/dotfiles-backups/`;
config directories remain real directories to keep runtime files out of git. dotai owns AI CLI installation, Codex
persistence, and Herdr's agent integrations. No new Docker volume is needed.

| Data | Backing location |
| --- | --- |
| Claude Code sessions (`~/.claude`) | `~/.ai/claude`, existing AI volume |
| Codex (`~/.codex`, after one-time migration) | `~/.ai/codex`, existing AI volume |
| Herdr config, session snapshots, named sessions, pane history | `~/.config/herdr`, existing config volume |
| Atuin history, keys, local identity and record data | `~/.config/atuin/data`, existing config volume, linked from the standard data directory |
| Atuin configuration | `~/.config/atuin/config.toml`, copied on first setup |

## First rebuild after adopting Codex persistence

Exit all Codex clients and app servers. In an ordinary devcontainer shell, run:

```bash
python3 /workspace/.ai/dotai/scripts/persist-codex.py
```

This copies the complete directory, verifies SQLite backups, keeps the original
at `~/.codex.pre-persistence`, and links `~/.codex` into the AI volume. It refuses
migration with open Codex files or conflicting source/destination histories.
Do this **before** deleting the current container. Post-create can wire future
containers but cannot recover an old container's unpersisted state.

A live backup without migration is available with `--snapshot`; backups go to
`~/.ai/backups/codex-*`. SQLite backups include committed WAL changes. Other
files can still change during a live snapshot, so this is not a replacement for
the stopped migration. Retain backups until a successful rebuild is verified.

Claude sessions already persist. The separate `~/.claude.json` global settings
file is outside the existing volume mapping; this setup does not promise full
Claude login/onboarding preservation. Project configuration in the workspace
survives through the host bind mount.

## Rebuild and resume

Save work and finish or interrupt active commands. Recreate the devcontainer
using the same workspace and Compose project name; let post-create finish.
From the host, run `devherd` (or `devherd --session NAME` for a named session).

Herdr restores layout, saved directories and recent screen history. Current
Claude/Codex integrations allow eligible panes to resume native conversations;
existing agents may need restarting once to load newly installed integrations.
For manual recovery use `claude --resume` or `codex resume`.

A container replacement ends all its processes. Shell variables, running tests,
servers and in-flight commands do not survive. Herdr live handoff cannot carry
processes across container deletion. Screen history is saved terminal output,
not a full process checkpoint, and may contain sensitive output.

Volumes survive ordinary rebuilds, not deliberate volume deletion (`down -v`,
volume removal, or a Docker storage reset). A different Compose project name
selects different volumes. This is local persistence, not an off-machine backup.

## Atuin

```bash
bash /workspace/dotfiles/scripts/setup-atuin.sh
atuin import auto        # import an existing shell history when desired
atuin info               # display paths, without printing history
```

Open a new Bash, Zsh or Fish shell and use Ctrl-R. The up arrow retains normal
shell behavior. The Linux installer is pinned to 18.21.0; macOS uses Homebrew.
The Brewfile and managed Fish/Zsh configs support host installation too. The
setup script uses the vendor binary installer without modifying shell profiles;
this repo installs the shell initialization explicitly.

Sync is opt-in (`auto_sync = false` initially); no account is registered and no
history is uploaded by setup. Existing configuration is preserved. Data is
redirected only where the config directory is an actual Linux mount. Existing
unlinked Atuin data is left untouched with an actionable error to avoid moving
an active database. Runtime data is never a Stow package or committed to git.

Sources: [Herdr restore](https://herdr.dev/docs/session-state/),
[Atuin configuration](https://docs.atuin.sh/main/configuration/config/),
[Codex state locations](https://learn.chatgpt.com/docs/config-file/config-advanced#config-and-state-locations).
