#!/usr/bin/env python3
"""Link curated configs, preserving existing files and real runtime directories."""
import os
from pathlib import Path
import shutil
import time
from urllib.parse import quote

repo = Path(__file__).resolve().parent.parent
home = Path.home()
config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
backup_root = config / "dotfiles-backups" / str(time.time_ns())


def backup(path):
    destination = backup_root / quote(str(path), safe="")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), str(destination))
    print(f"Backed up {path} to {destination}")


def directory(path):
    if path == home:
        return
    directory(path.parent)
    if path.is_symlink():
        # Preserve contents of folded Stow directories without leaving a writable
        # directory link into the checkout. Never move the symlink's target.
        contents = path.resolve()
        backup(path)
        if contents.is_dir():
            shutil.copytree(contents, path, symlinks=False)
        else:
            path.mkdir()
    elif path.exists() and not path.is_dir():
        backup(path)
        path.mkdir()
    else:
        path.mkdir(exist_ok=True)


def link(source, target):
    directory(target.parent)
    if target.is_symlink() and target.readlink() == source:
        return
    if target.exists() or target.is_symlink():
        backup(target)
    target.symlink_to(source)


files = {
    "nushell": (".config/nushell/config.nu", ".config/nushell/env.nu"),
    "fish": (".config/fish/config.fish",),
    "zsh": (".zshrc", ".config/zsh/agents.zsh", ".config/zsh/aliases.zsh", ".config/zsh/env.zsh"),
    "starship": (".config/starship.toml",),
    "vim": (".vimrc",),
}
for package, names in files.items():
    for name in names:
        relative = Path(name)
        source = repo / ".dotfiles" / package / relative
        target = config / relative.relative_to(".config") if relative.parts[0] == ".config" else home / relative
        link(source, target)

# Bash keeps the devcontainer's existing initialization (NVM, roe, etc.).
bashrc = home / ".bashrc"
line = 'export PATH="$HOME/.local/bin:$PATH"; eval "$(starship init bash)"'
text = bashrc.read_text() if bashrc.exists() else ""
if "starship init bash" not in text:
    if bashrc.exists() or bashrc.is_symlink():
        backup(bashrc)
    bashrc.write_text(text + "\n" + line + "\n")
