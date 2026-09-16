#!/usr/bin/env python3
"""Explicit personal opt-in. Never called by shared local-dev-env setup."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
BEGIN = '<!-- roe-personal-coordination:start -->'
END = '<!-- roe-personal-coordination:end -->'


def managed(path, block, remove=False):
    old = path.read_text() if path.exists() else ''
    if (BEGIN in old) != (END in old):
        raise RuntimeError(f'Incomplete managed block: {path}')
    if BEGIN in old:
        start = old.index(BEGIN); end = old.index(END, start) + len(END)
        text = old[:start] + ('' if remove else BEGIN+'\n'+block+'\n'+END) + old[end:]
    elif remove:
        return
    else:
        text = old + '\n\n' + BEGIN+'\n'+block+'\n'+END+'\n'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['enable', 'disable'])
    p.add_argument('--root', type=Path, required=True)
    p.add_argument('--firstmate-home', type=Path, action='append', default=[])
    p.add_argument('--user-home', type=Path, default=Path.home())
    args=p.parse_args()
    root=args.root.resolve()
    common=Path(subprocess.check_output(['git','-C',str(root),'rev-parse','--path-format=absolute','--git-common-dir'],text=True).strip())
    if root != common.parent or common.name != '.git':
        raise RuntimeError('Enable/disable from the canonical checkout, not a linked worktree')
    destination=common/'roe-runtime.json'
    state=common/'roe-runtime-state'
    state.mkdir(mode=0o700, exist_ok=True)
    with (state/'mutex').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        settings=Path(os.environ.get('XDG_CONFIG_HOME', str(args.user_home/'.config')))/'roe-coordination/config.json'
        install=args.user_home/'.local/bin'
        executable=install/'roe-coordination'
        # The guard runs from an INSTALLED COPY, not from this checkout.
        #
        # dotfiles is a stow repo: 17 symlinks point into its working tree so an
        # edit takes effect immediately, which is exactly what you want for a
        # prompt or an alias. It is exactly what you do NOT want for the guard
        # that every `make` executes — it made the guard follow whatever branch
        # happened to be checked out, and run half-saved files mid-edit. Copying
        # it here means the guard changes only when you deliberately re-run
        # `setup.py enable`, while the rest of dotfiles stays live.
        libdir=args.user_home/'.local/lib/roe-coordination'
        installed=libdir/'roe-coordination'
        source=HERE/'roe-coordination'
        # The pre-copy layout pointed provider straight at the checkout. Accept
        # it as ours so an upgrade rewrites it instead of refusing.
        ours={str(installed),str(source)}
        existing=json.loads(destination.read_text()) if destination.exists() else None
        if existing and existing.get('provider') not in ours:
            raise RuntimeError('Existing provider belongs to another installation; refusing to overwrite')
        if settings.exists() and json.loads(settings.read_text()).get('config') != str(destination):
            raise RuntimeError('This personal installation already targets a different stack')
        homes=[str(x.resolve()) for x in args.firstmate_home] or (existing or {}).get('homes',[])
        docs=[args.user_home/'.codex/AGENTS.md',args.user_home/'.claude/CLAUDE.md']
        docs += [Path(home)/'data/captain-shared.md' for home in homes]
        if args.action=='enable':
            if list((root/'.staged-worktrees').glob('*.lock')):
                raise RuntimeError('Restore existing staged checkouts before enabling coordination')
            if not homes:
                raise RuntimeError('Specify at least one --firstmate-home')
            for home in homes:
                if not (Path(home)/'state').is_dir() or not (Path(home)/'data').is_dir():
                    raise RuntimeError('Firstmate home must already have state/ and data/: '+home)
            if existing and (Path(existing['state'])/'lease.json').exists():
                raise RuntimeError('Cannot reconfigure while the runtime is reserved')
            for target in [executable]:
                if target.exists() or target.is_symlink():
                    if not target.is_symlink() or target.resolve() not in {installed,source}:
                        raise RuntimeError('Refusing to overwrite unmanaged executable: '+str(target))
            if installed.exists() and not installed.is_file():
                raise RuntimeError('Refusing to overwrite a non-file at '+str(installed))
            # Validate managed blocks before changing any destination.
            for doc in docs:
                old=doc.read_text() if doc.exists() else ''
                if (BEGIN in old)!=(END in old):
                    raise RuntimeError('Incomplete managed instruction block: '+str(doc))
                # ...and that we can actually write them. A retired Firstmate home
                # leaves data/captain-shared.md mode 444, which used to fail LATE:
                # the copy was installed and the bin symlink repointed, then the
                # write raised and the activation was never published. Nothing was
                # corrupted (publishing is deliberately last) but the install was
                # left half-applied. Fail here instead, before anything moves.
                target=doc if doc.exists() else doc.parent
                while not target.exists() and target != target.parent: target=target.parent
                if not os.access(target, os.W_OK):
                    raise RuntimeError('Not writable, refusing a partial install: '+str(doc))
            config=dict(version=1,root=str(root),provider=str(installed),state=str(common/'roe-runtime-state'),homes=homes)
            # Copy atomically: a guard read mid-write must never see a partial
            # file, since runtime-guard.sh execs it on every make invocation.
            libdir.mkdir(parents=True,exist_ok=True)
            staged=installed.with_suffix('.tmp')
            staged.write_bytes(source.read_bytes());os.chmod(staged,0o755);os.replace(staged,installed)
            install.mkdir(parents=True,exist_ok=True)
            # Repoint an older checkout-symlink at the installed copy.
            if executable.is_symlink() or executable.exists(): executable.unlink()
            executable.symlink_to(installed)
            # Migrate the earlier optional reminder wrapper; never remove an unmanaged command.
            legacy=install/'roe-agent'
            if legacy.is_symlink() and legacy.resolve()==HERE/'roe-agent':
                legacy.unlink()
            policy=(HERE/'policy.md').read_text()
            policy='Configured stack: '+str(root)+'\n\n'+policy
            policy+='\n\nThis scoped routing supersedes an older personal preference saying all software work must go through Firstmate. Other pilot restrictions remain unchanged.'
            for doc in docs: managed(doc,policy)
            settings.parent.mkdir(parents=True,exist_ok=True)
            settings.write_text(json.dumps(dict(config=str(destination)))+'\n')
            # Publish the activation last. No environment variable activates the guard.
            temp=destination.with_suffix('.tmp')
            temp.write_text(json.dumps(config,indent=2)+'\n');os.chmod(temp,0o600);os.replace(temp,destination)
            print('Enabled personal coordination for '+str(root))
        else:
            if existing and (Path(existing['state'])/'lease.json').exists():
                raise RuntimeError('Reservation exists: finish or explicitly recover it before disabling')
            for doc in docs: managed(doc,'',remove=True)
            destination.unlink(missing_ok=True)
            settings.unlink(missing_ok=True)
            for name in ['roe-coordination','roe-agent']:
                dest=install/name
                if dest.is_symlink() and dest.resolve() in {installed,HERE/name}: dest.unlink()
            # Remove the installed copy, and the directory when it owns nothing else.
            installed.unlink(missing_ok=True)
            if libdir.is_dir() and not any(libdir.iterdir()): libdir.rmdir()
            print('Disabled personal coordination; unrelated configuration preserved')



if __name__=='__main__':
    try: main()
    except (RuntimeError,OSError,ValueError,subprocess.CalledProcessError) as error: raise SystemExit(str(error))
