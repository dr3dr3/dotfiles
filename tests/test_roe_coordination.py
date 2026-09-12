"""Integration tests: isolated Git/Firstmate fixtures, no Docker or real state."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

SOURCE = Path(__file__).resolve().parents[1]
TOOL = SOURCE / 'tools/roe-coordination/roe-coordination'
SETUP = SOURCE / 'tools/roe-coordination/setup.py'
UMBRELLA = Path(os.environ.get('ROE_LOCAL_DEV_ENV_ROOT', str(SOURCE.parent)))
HAS_GUARD = (UMBRELLA / 'scripts/runtime-guard.sh').exists()


class CoordinationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / 'stack'; self.root.mkdir()
        self.home = self.base / 'home'; self.home.mkdir()
        self.fm = self.base / 'firstmate'
        (self.fm / 'state').mkdir(parents=True)
        (self.fm / 'data/demo').mkdir(parents=True)
        (self.fm / 'data/demo/brief.md').write_text('A registered task')
        (self.fm / 'state/demo.meta').write_text(f'kind=ship\nworktree={self.root}\n')
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'))
        self.env.pop('ROE_RUNTIME_TOKEN', None)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        (self.root / 'scripts').mkdir()
        if HAS_GUARD:
            shutil.copy2(UMBRELLA / 'scripts/runtime-guard.sh', self.root / 'scripts/runtime-guard.sh')
            header = (UMBRELLA / 'Makefile').read_text().split('# Optional runtime coordination,',1)[1].split('# Load .env',1)[0]
        else:
            header = ''
        (self.root / 'Makefile').write_text('# Optional runtime coordination,' + header + '\nhelp:\n\t@echo help\nrestart:\n\t@touch MUTATED\n')
        self.cfg = self.root / '.git/roe-runtime.json'
        self.state = self.root / '.git/roe-runtime-state'

    def call(self, *args, ok=True, env=None):
        r = subprocess.run([str(x) for x in args], env=env or self.env, cwd=self.root, text=True, capture_output=True)
        if ok:
            self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        else:
            self.assertNotEqual(r.returncode, 0, r.stderr + r.stdout)
        return r

    def enable(self):
        return self.call('python3', SETUP, 'enable', '--root', self.root, '--firstmate-home', self.fm)

    def command(self, code, *extra):
        return [str(TOOL), 'run', '--home', str(self.fm), '--task', 'demo', *extra, '--', 'python3', '-c', code]

    @unittest.skipUnless(HAS_GUARD, 'Set ROE_LOCAL_DEV_ENV_ROOT for companion guard integration')
    def test_default_unchanged_and_no_python_dependency(self):
        fake = self.base/'bin'; fake.mkdir()
        p=fake/'python3'; p.write_text('#!/bin/sh\necho PROVIDER_CALLED >&2\nexit 77\n'); p.chmod(0o755)
        env=dict(self.env,PATH=str(fake)+':'+os.environ['PATH'],FM_HOME=str(self.fm))
        r=self.call('bash','scripts/runtime-guard.sh','exec',env=env)
        self.assertEqual(r.stdout+r.stderr,'')
        self.call('make','restart',env=env)
        self.assertTrue((self.root/'MUTATED').exists())

    @unittest.skipUnless(HAS_GUARD, 'Set ROE_LOCAL_DEV_ENV_ROOT for companion guard integration')
    def test_make_blocks_before_side_effects_and_allows_help(self):
        self.enable()
        self.call('make','help')
        self.call('make','restart',ok=False)
        self.assertFalse((self.root/'MUTATED').exists())
        self.call(*self.command("import subprocess; subprocess.run(['make','restart'],check=True)"))
        self.assertTrue((self.root/'MUTATED').exists())
        self.assertFalse((self.state/'lease.json').exists())

    @unittest.skipUnless(HAS_GUARD, 'Set ROE_LOCAL_DEV_ENV_ROOT for companion guard integration')
    def test_broken_provider_fails_closed(self):
        self.enable(); c=json.loads(self.cfg.read_text());c['provider']='/missing/provider';self.cfg.write_text(json.dumps(c))
        r=self.call('bash','scripts/runtime-guard.sh','exec',ok=False)
        self.assertIn('enabled but unavailable',r.stderr)

    def test_repeated_setup_preserves_instructions_and_uninstall(self):
        p=self.home/'.codex/AGENTS.md';p.parent.mkdir();p.write_text('Existing policy\n')
        self.enable(); first=p.read_text();self.enable();self.assertEqual(first,p.read_text())
        self.call('python3',SETUP,'disable','--root',self.root)
        self.assertIn('Existing policy',p.read_text());self.assertNotIn('roe-personal-coordination',p.read_text())
        self.assertFalse(self.cfg.exists())
        self.call('make','restart')

    def test_foreign_executable_refused_before_activation(self):
        p=self.home/'.local/bin/roe-agent';p.parent.mkdir(parents=True);p.write_text('mine')
        self.call('python3',SETUP,'enable','--root',self.root,'--firstmate-home',self.fm,ok=False)
        self.assertEqual(p.read_text(),'mine');self.assertFalse(self.cfg.exists())
        self.assertFalse((self.home/'.codex/AGENTS.md').exists())

    def test_unknown_task_refused(self):
        self.enable();(self.fm/'state/demo.meta').unlink()
        self.call(*self.command('pass'),ok=False)
        self.assertFalse((self.state/'lease.json').exists())

    def test_competing_run_cannot_acquire_or_disable_or_recover(self):
        self.enable()
        p=subprocess.Popen(self.command('import time;time.sleep(3)'),cwd=self.root,env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        self.addCleanup(lambda: p.poll() is None and p.kill())
        for _ in range(100):
            if (self.state/'lease.json').exists():break
            time.sleep(.02)
        item=json.loads((self.state/'lease.json').read_text())
        self.call(*self.command('pass'),ok=False)
        self.call(TOOL,'guard',self.cfg,'exec',ok=False)
        self.call(TOOL,'recover','--confirm-id',item['id'],'--reason','reviewed','--processes-stopped-and-state-reviewed',ok=False)
        self.call('python3',SETUP,'disable','--root',self.root,ok=False)
        out,err=p.communicate(timeout=8);self.assertEqual(p.returncode,0,out+err)
        self.assertFalse((self.state/'lease.json').exists())

    def test_failed_run_retained_then_explicit_recovery(self):
        self.enable();self.call(*self.command('raise SystemExit(9)'),ok=False)
        item=json.loads((self.state/'lease.json').read_text())
        self.call(TOOL,'recover','--confirm-id','wrong','--reason','reviewed','--processes-stopped-and-state-reviewed',ok=False)
        self.call(TOOL,'recover','--confirm-id',item['id'],'--reason','reviewed','--processes-stopped-and-state-reviewed')
        self.assertFalse((self.state/'lease.json').exists())

    def test_staged_code_retained_and_restored_under_same_task(self):
        self.enable()
        self.call(*self.command("from pathlib import Path;p=Path('.staged-worktrees');p.mkdir();(p/'api.lock').write_text('staged')"),ok=False)
        item=json.loads((self.state/'lease.json').read_text())
        self.call(*self.command("from pathlib import Path;Path('.staged-worktrees/api.lock').unlink()",'--recover-id',item['id'],'--processes-stopped-and-state-reviewed'))
        self.assertFalse((self.state/'lease.json').exists())

    @unittest.skipUnless(HAS_GUARD, 'Set ROE_LOCAL_DEV_ENV_ROOT for companion guard integration')
    def test_linked_worktree_uses_same_activation(self):
        self.call('git','add','Makefile','scripts')
        self.call('git','-c','user.name=Test','-c','user.email=test@example.com','commit','-qm','fixture')
        wt=self.base/'linked';self.call('git','worktree','add','--detach',wt)
        self.enable()
        self.call('bash',wt/'scripts/runtime-guard.sh','exec',ok=False)

    def test_enable_refuses_legacy_staging(self):
        stage=self.root/'.staged-worktrees';stage.mkdir();(stage/'api.lock').write_text('legacy')
        self.call('python3',SETUP,'enable','--root',self.root,'--firstmate-home',self.fm,ok=False)
        self.assertFalse(self.cfg.exists())

    def test_stale_token_is_refused(self):
        self.enable()
        token='test-only-token'
        import hashlib
        item=dict(id='stale',task='demo',home=str(self.fm),pid=99999999,
                  acquired=0,heartbeat=0,token_hash=hashlib.sha256(token.encode()).hexdigest())
        (self.state/'lease.json').write_text(json.dumps(item))
        self.call(TOOL,'guard',self.cfg,'exec',env=dict(self.env,ROE_RUNTIME_TOKEN=token),ok=False)
        self.assertTrue((self.state/'lease.json').exists())

    def test_guard_status_is_read_only(self):
        self.enable()
        self.call(TOOL,'guard',self.cfg,'stage-worktree','status')
        self.call(TOOL,'guard',self.cfg,'stage-worktree','stage',ok=False)

    def test_launch_reminder_and_argv(self):
        self.enable()
        r=self.call(TOOL,'launch','--','python3','-c','import sys;print(repr(sys.argv[1:]))','two words')
        self.assertIn('Personal routing:',r.stdout);self.assertIn("['two words']",r.stdout)


if __name__=='__main__':unittest.main()
