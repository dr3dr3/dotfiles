"""herdr-autosnap: whether it believes its own pidfile.

The pidfile lives on the persisted ~/.config volume, so it outlives the
container; the EXIT trap that removes it never runs, because PID 1 in the
devcontainer is `sleep infinity` and Docker SIGKILLs the daemon. The next boot
then hands out low PIDs — including the one in the stale file.

Trusting `kill -0` alone therefore made a rebooted container report "already
running (pid 412)" forever while taking no snapshots: silent, permanent, and
in exactly the scenario the tool exists for. These tests pin the identity
check that fixes it.

`start` is deliberately not exercised — it would spawn a real daemon.
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/herdr/herdr-autosnap'


class AutosnapPidfileTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cfg = Path(self.tmp.name)
        (self.cfg / 'herdr' / 'snapshots').mkdir(parents=True)
        self.pidfile = self.cfg / 'herdr' / 'autosnap.pid'

    def tearDown(self):
        self.tmp.cleanup()

    def status(self):
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.cfg))
        return subprocess.run([str(SCRIPT), 'status'], capture_output=True, text=True, env=env).stdout

    def test_a_reused_pid_is_not_mistaken_for_the_daemon(self):
        # PID 1 always exists and is never herdr-autosnap — the shape of every
        # post-reboot collision.
        self.pidfile.write_text('1\n')
        out = self.status()
        self.assertIn('not running', out)
        self.assertIn('stale pidfile', out)

    def test_a_real_autosnap_process_is_recognised(self):
        proc = subprocess.Popen(['bash', '-c', 'exec -a herdr-autosnap-under-test sleep 30'])
        try:
            self.pidfile.write_text(f'{proc.pid}\n')
            self.assertIn(f'running (pid {proc.pid}', self.status())
        finally:
            proc.kill()
            proc.wait()

    def test_no_pidfile_means_not_running(self):
        self.assertIn('herdr-autosnap: not running', self.status())

    def test_a_dead_pid_is_not_running(self):
        proc = subprocess.Popen(['sleep', '30'])
        proc.kill()
        proc.wait()
        self.pidfile.write_text(f'{proc.pid}\n')
        self.assertIn('not running', self.status())

    def test_snapshot_count_is_a_single_number_when_empty(self):
        # `grep -c` exits 1 on no matches, so `|| echo 0` used to fire IN
        # ADDITION to grep's own 0, printing the count twice.
        line = [l for l in self.status().splitlines() if l.startswith('snapshots:')][0]
        self.assertRegex(line, r'^snapshots: 0 in /')

    def test_snapshot_count_ignores_sidecars(self):
        snaps = self.cfg / 'herdr' / 'snapshots'
        (snaps / '20260923T100000Z.json').write_text('{}')
        (snaps / '20260923T100000Z.session.json').write_text('{}')
        line = [l for l in self.status().splitlines() if l.startswith('snapshots:')][0]
        self.assertRegex(line, r'^snapshots: 1 in /')


if __name__ == '__main__':
    unittest.main()
