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

From the host, run `devherd` in the local-dev-env checkout. Inside a Herdr pane,
start Claude normally with `claude`.
