# Herdr

Herdr is managed here with the rest of the terminal environment. The same
portable keymap is used on macOS, Linux/Omarchy, Windows, and inside
devcontainers:

- Config source: `.dotfiles/herdr/.config/herdr/config.toml`
- Prefix: `Ctrl+Space`, matching Omarchy
- One-key prefix: Caps Lock sends `Ctrl+Space`
- Live help: prefix, then `?`
- Reload: prefix, then `q`
- Detach: prefix, then `d`

Herdr accepts one prefix value, not a list. Caps Lock is therefore translated
to `Ctrl+Space` by the host keyboard layer. The normal `Ctrl+Space` chord always
remains available.

## Keymap

The action keys mirror Omarchy's tmux/Herdr layout:

- Panes: `prefix+v` splits beside, `prefix+h` splits below, `prefix+x` closes,
  and `prefix+z` zooms.
- Tabs: `prefix+c` creates, `prefix+r` renames, and `prefix+k` closes.
- Workspaces: `prefix+Shift+C` creates, `prefix+Shift+R` renames,
  `prefix+Shift+K` closes, and `prefix+s` opens the picker.
- `Alt+Arrow` changes tabs/workspaces. `Ctrl+Alt+Arrow` changes panes.
- `Ctrl+Alt+Shift+Arrow` resizes panes.
- Copy mode remains `prefix+[`.

## macOS

`bootstrap-mac.sh` installs Herdr through Homebrew and stows its config.
Karabiner-Elements is installed for the one-key prefix.

After bootstrap, open Karabiner-Elements:

1. Open **Complex Modifications**.
2. Choose **Add predefined rule**.
3. Enable **Ghostty: Caps Lock sends Ctrl+Space; Shift+Caps Lock toggles Caps
   Lock**.

The rule is scoped to Ghostty, so Caps Lock behaves normally in other apps.
Inside Ghostty, use `Shift+Caps Lock` when you need actual Caps Lock.

Run `herdr` for host work. From a project directory, run `devherd` to attach to
Herdr inside that project's devcontainer.

## Windows 11

From PowerShell in this repository:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-herdr.ps1
```

The script installs native Herdr and persists `HERDR_CONFIG_PATH` so Herdr reads
the config directly from this checkout.

For Caps Lock:

1. Install PowerToys: `winget install --id Microsoft.PowerToys --source winget`.
2. Open **PowerToys → Keyboard Manager → Remap a key**.
3. Map `Caps Lock` to the shortcut `Ctrl+Space`.

PowerToys' key-to-shortcut remap is global. If preserving Caps Lock matters,
add a second shortcut for it or skip the remap and use `Ctrl+Space` directly.

## Omarchy Linux

Omarchy already uses `Ctrl+Space` as its Herdr prefix. To make Caps Lock emit
that chord:

```bash
bash scripts/setup-herdr-capslock-linux.sh
```

This installs the tracked keyd fragment and reloads keyd. It deliberately
replaces Omarchy's Caps Lock compose/emoji sequences; Omarchy's two-Shift-keys
shortcut still toggles Caps Lock. Skip this script if those compose sequences
matter more than the one-key prefix.

Run `bash scripts/setup-herdr.sh` if Herdr or the managed config is missing.

## Devcontainers

Do not install a keyboard remapper inside a container. The macOS, Windows, or
Linux host sends `Ctrl+Space` through the terminal. In local-dev-env:

```bash
git clone https://github.com/dr3dr3/dotfiles.git /workspace/dotfiles
git clone https://github.com/dr3dr3/dotai.git /workspace/.ai/dotai
```

On the next post-create/re-attach, local-dev-env detects each personal clone:
dotfiles installs Herdr first, then dotai installs Claude Code and registers
Herdr's Claude integration. Other developers who do not clone these repos get
neither personal layer.

From a plain host terminal, run `devherd` in the local-dev-env checkout. Inside
a container Herdr pane, start Claude normally with `claude`. See the workflow
comparison below before launching `devherd` from inside host Herdr.

## Choosing where Herdr runs

For container development and agent workflows, use a **plain Ghostty tab**
and run `devherd` from the project's host checkout. Keep host Herdr in another
terminal tab when needed. This gives each environment one Herdr UI without
nested keymaps.

`devherd` wraps `devsh bash -lc 'cd /workspace && exec herdr "$@"'`,
forwarding its arguments. It starts or attaches to container Herdr; it is not
Herdr's SSH remote-attach mode. The simpler `devsh herdr` follows the same
architecture, but does not explicitly change the working directory or start
a login shell.

| Trade-off | Ghostty → devsh herdr | Host Herdr → devsh | Host Herdr → devsh herdr |
| --- | --- | --- | --- |
| Herdr servers | Container | Mac | Both |
| New panes start in | Container | Mac; enter the container with devsh | The environment of the Herdr creating them |
| Container agents managing panes | Can use container Herdr directly | Need an explicit bridge to host Herdr | Can manage inner Herdr; outer remains separate |
| Mixing host and container tools | Separate terminal tabs/windows | One Herdr workspace | One terminal, two workspace hierarchies |
| Input and UI | One keymap and UI | One keymap and UI | Separate keymaps required; two UIs |
| Container stop/rebuild | Container server and live processes stop | Host panes remain; container connections end | Outer remains; inner server and processes stop |
| Complexity | Low | Low to moderate | Highest |

### 1. Container Herdr: default for container work

From a plain Ghostty shell in the project's host checkout:

```bash
devherd
# Or:
devsh herdr
```

New Herdr panes run inside the container with its tools, paths, dependencies,
and credentials. Container agents can reach the same Herdr server to create
and manage panes. Detaching leaves the server and its processes running while
the container remains running.

Host work belongs in a separate terminal tab/window. Stopping or rebuilding
the container ends its live processes: persisted configuration or a restored
session layout does not preserve running processes through a restart.

### 2. Host Herdr: convenient for mixed host/container work

Launch `herdr` on the Mac, then run `devsh` in each pane that needs a
container shell. Do not launch another Herdr in those shells.

The host server owns the outer pane terminals, but commands entered through
`devsh` execute inside the container. One workspace can mix Mac tools and
container tooling with one keymap. Host panes remain when the container stops;
run `devsh` again after it is available.

New panes start on the host, so entering the container is an extra step unless
you configure pane launch commands. Container agents do not automatically
have access to the host Herdr socket. Choose this option when mixed host work
matters more than container-side Herdr pane orchestration.

### 3. Nested Herdr: both environments in one terminal

Launch host Herdr, then run `devherd` (or `devsh herdr`) in an outer pane.
The two servers remain independent. Each has its own workspaces, panes, focus,
and detach operation. Detaching the outer client leaves both layers running
provided the host and container remain running.

This is useful when both environments need their own pane orchestration in
one terminal, but adds navigation and input complexity. Zooming the outer pane
can reduce visual clutter without removing the two layers.

Herdr normally sets `HERDR_ENV=1` in its panes and refuses nested launches
unless the inner config enables:

```toml
[experimental]
allow_nested = true
```

In the checked local-dev-env setup, `devsh` does not forward that marker, so
the container launch does not detect nesting. Explicitly forwarding the marker
and enabling the setting would make nesting intentional. It would **not**
connect the servers, share workspaces, bridge sockets, or solve input conflicts.
That change is not required for the current nested launch to work.

If maintaining nesting, separate both the prefix and direct shortcuts. This
repo's shared config uses `Ctrl+Space` plus bindings such as `Alt+Left/Right`
and `Ctrl+Alt+Arrow`. Installing it unchanged in both environments lets outer
Herdr intercept inner shortcuts. A different host prefix alone is insufficient.
Mouse interaction can also be intercepted by the outer UI.

### SSH thin client: a separate alternative

`herdr --remote <ssh-target>` runs a local thin client against a remote Herdr
server. Launch it from a plain terminal for one UI, with panes on the remote
side. Local keybindings are used by default; `--remote-keybindings server`
selects the server's bindings. It can bridge local desktop features such as
image clipboard paste.

This requires working SSH access to the container and adds SSH setup and
maintenance. Forwarding the nesting marker through `devsh` does not provide
this mode. See [Herdr remote access](https://herdr.dev/docs/persistence-remote/).

### Verified setup snapshot — 2026-09-07

These observations describe the checked Mac/local-dev-env installation, not
requirements for every machine:

- Both host and container ran Herdr 0.8.2.
- The host had no `~/.config/herdr/config.toml`, so its prefix was the default
  `Ctrl+B`.
- Container config linked to
  `/workspace/dotfiles/.dotfiles/herdr/.config/herdr/config.toml`, using
  `Ctrl+Space`.
- A `HERDR_ENV=1` launch on the host was refused. Through `devsh`, both that
  marker and a separate test variable arrived unset; configured
  `DEVCONTAINER=1` was present. This is specific to the current configuration,
  not a claim that devcontainer CLI can never forward host variables.
- The container had no `sshd` on PATH and no TCP port 22 listener.
- `bootstrap-mac.sh` includes the `herdr` Stow package. Applying that bootstrap
  installs the shared keymap on the host too. A Git commit or merge alone does
  not activate it.

Recheck configuration before relying on the currently different prefixes.
