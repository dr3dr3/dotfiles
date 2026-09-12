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
        existing=json.loads(destination.read_text()) if destination.exists() else None
        if existing and existing.get('provider') != str(HERE/'roe-coordination'):
            raise RuntimeError('Existing provider belongs to another installation; refusing to overwrite')
        if settings.exists() and json.loads(settings.read_text()).get('config') != str(destination):
            raise RuntimeError('This personal launcher already targets a different stack')
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
            for target in [executable, install/'roe-agent']:
                if target.exists() or target.is_symlink():
                    expected=HERE/('roe-coordination' if target.name=='roe-coordination' else 'roe-agent')
                    if not target.is_symlink() or target.resolve()!=expected:
                        raise RuntimeError('Refusing to overwrite unmanaged executable: '+str(target))
            # Validate managed blocks before changing any destination.
            for doc in docs:
                old=doc.read_text() if doc.exists() else ''
                if (BEGIN in old)!=(END in old):
                    raise RuntimeError('Incomplete managed instruction block: '+str(doc))
            config=dict(version=1,root=str(root),provider=str(HERE/'roe-coordination'),state=str(common/'roe-runtime-state'),homes=homes)
            install.mkdir(parents=True,exist_ok=True)
            for name in ['roe-coordination','roe-agent']:
                dest=install/name
                if not dest.is_symlink(): dest.symlink_to(HERE/name)
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
                if dest.is_symlink() and dest.resolve()==HERE/name: dest.unlink()
            print('Disabled personal coordination; unrelated configuration preserved')



if __name__=='__main__':
    try: main()
    except (RuntimeError,OSError,ValueError,subprocess.CalledProcessError) as error: raise SystemExit(str(error))
