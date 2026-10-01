"""herdr-session-guard: when it restores session.json, and when it refuses.

Runs the script as a subprocess against a temporary XDG_CONFIG_HOME, with a
stub `herdr` on PATH so no server is needed. The two refusal paths matter as
much as the restore: this tool overwrites Herdr's own state file, and the
interlocks are the only thing standing between "recovered my workspace" and
"wrote over a live session".
"""
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/herdr/herdr-session-guard'


def session(*pane_counts):
    """A session.json with one tab per argument, holding that many panes."""
    tabs = [{"custom_name": f"t{i}", "panes": {str(n): {"cwd": "/workspace"} for n in range(c)}}
            for i, c in enumerate(pane_counts)]
    return {"version": 3, "workspaces": [{"id": "w4", "tabs": tabs}]}


class GuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.cfg = root / 'cfg'
        self.snaps = self.cfg / 'herdr' / 'snapshots'
        self.snaps.mkdir(parents=True)
        self.live = self.cfg / 'herdr' / 'session.json'
        self.bin = root / 'bin'
        self.bin.mkdir()
        self.set_server(running=False)

    def tearDown(self):
        self.tmp.cleanup()

    def set_server(self, running):
        state = 'running' if running else 'stopped'
        stub = self.bin / 'herdr'
        stub.write_text(f'#!/bin/sh\nprintf "server:\\n  status: {state}\\n"\n')
        stub.chmod(0o755)

    def write_live(self, *pane_counts):
        self.live.write_text(json.dumps(session(*pane_counts)))

    def write_sidecar(self, *pane_counts, age_hours=0.0):
        f = self.snaps / '20260923T235900Z.session.json'
        f.write_text(json.dumps(session(*pane_counts)))
        if age_hours:
            old = time.time() - age_hours * 3600
            os.utime(f, (old, old))
        return f

    def run_guard(self, *args):
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.cfg), PATH=f"{self.bin}:/usr/bin:/bin")
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env=env)

    def panes_live(self):
        d = json.loads(self.live.read_text())
        return sum(len(t['panes']) for w in d['workspaces'] for t in w['tabs'])

    # -- the case it exists for ---------------------------------------------

    def test_restores_a_gutted_session_from_the_sidecar(self):
        self.write_live(1)
        self.write_sidecar(2, 3)
        out = self.run_guard()
        self.assertIn('restored', out.stdout)
        self.assertEqual(self.panes_live(), 5)

    def test_dry_run_changes_nothing(self):
        self.write_live(1)
        self.write_sidecar(2, 3)
        self.run_guard('--dry-run')
        self.assertEqual(self.panes_live(), 1)

    def test_keeps_the_emptied_file_for_forensics(self):
        self.write_live(1)
        self.write_sidecar(2, 3)
        self.run_guard()
        kept = list((self.cfg / 'herdr').glob('session.gutted.*.json'))
        self.assertEqual(len(kept), 1)
        self.assertEqual(sum(len(t['panes']) for w in json.loads(kept[0].read_text())['workspaces']
                             for t in w['tabs']), 1)

    # -- the refusals, which are the load-bearing half ----------------------

    def test_refuses_while_a_server_is_running(self):
        # Regression: server_running() looked up "herdr" by name, so under
        # postStartCommand's PATH it raised OSError and was swallowed as "no
        # server" — the interlock was inert at its primary call site.
        self.set_server(running=True)
        self.write_live(1)
        self.write_sidecar(2, 3)
        out = self.run_guard()
        self.assertIn('already running', out.stdout)
        self.assertEqual(self.panes_live(), 1)

    def test_finds_herdr_even_when_it_is_not_on_path(self):
        self.set_server(running=True)
        self.write_live(1)
        self.write_sidecar(2, 3)
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.cfg), PATH='/usr/bin:/bin',
                   HOME=str(self.bin.parent))
        (self.bin.parent / '.local' / 'bin').mkdir(parents=True)
        (self.bin.parent / '.local' / 'bin' / 'herdr').write_text(
            (self.bin / 'herdr').read_text())
        (self.bin.parent / '.local' / 'bin' / 'herdr').chmod(0o755)
        out = subprocess.run([str(SCRIPT)], capture_output=True, text=True, env=env)
        self.assertIn('already running', out.stdout)

    def test_declines_when_herdr_cannot_be_executed_at_all(self):
        # 🔑 The ONLY branch that fails CLOSED, and so the only one whose absence
        # is destructive. server_running() returns three states on purpose: None
        # means "could not answer", which is NOT False — a live server may own
        # session.json, so the guard must decline rather than write over it.
        #
        # Every other test drives an ANSWERABLE server (`running` or `stopped`),
        # which is why this path had no cover. It is reached via the fallback
        # lookup, which checks .exists() and not executability: `which` skips a
        # non-executable file, the fallback returns it, and running it raises
        # PermissionError — an OSError, hence None.
        #
        # What this protects against is the obvious future tidy-up:
        # `return "status: running" in out.stdout` looks total, and collapsing
        # the three states to a bool turns "cannot tell" into "no server" and
        # overwrites a live session. Without this test that change stays green.
        # The live session must look GUTTED and the sidecar restorable, so that
        # the ambiguity check is the ONLY thing standing between the guard and a
        # write. With a healthy live session the `live_n > 1` interlock would
        # decline too, and this test would pass even with the None handling gone.
        self.write_live(1)
        self.write_sidecar(2, 3)
        fallback = self.bin.parent / '.local' / 'bin'
        fallback.mkdir(parents=True)
        herdr = fallback / 'herdr'
        herdr.write_text('#!/bin/sh\nprintf "server:\\n  status: stopped\\n"\n')
        herdr.chmod(0o000)             # present, and impossible to execute
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.cfg), PATH='/usr/bin:/bin',
                   HOME=str(self.bin.parent))
        out = subprocess.run([str(SCRIPT)], capture_output=True, text=True, env=env)
        self.assertIn('did not answer', out.stdout)
        self.assertEqual(out.returncode, 0)   # never fails the container start
        self.assertEqual(self.panes_live(), 1)  # NOT restored from the sidecar
        self.assertEqual(list(self.cfg.glob('herdr/*.gutted.*')), [],
                         'declining must not move the live file aside')

    def test_leaves_an_intact_session_alone(self):
        self.write_live(4, 4)
        self.write_sidecar(2, 3)
        out = self.run_guard()
        self.assertIn('looks intact', out.stdout)
        self.assertEqual(self.panes_live(), 8)

    def test_refuses_a_stale_sidecar(self):
        self.write_live(1)
        self.write_sidecar(2, 3, age_hours=72)
        out = self.run_guard()
        self.assertIn('too stale', out.stdout)
        self.assertEqual(self.panes_live(), 1)

    def test_refuses_a_sidecar_not_worth_restoring(self):
        self.write_live(1)
        self.write_sidecar(1)
        out = self.run_guard()
        self.assertIn('not worth restoring', out.stdout)

    def test_says_so_when_there_is_no_sidecar_at_all(self):
        self.write_live(1)
        out = self.run_guard()
        self.assertIn('no session sidecar', out.stdout)
        self.assertEqual(out.returncode, 0)


if __name__ == '__main__':
    unittest.main()
