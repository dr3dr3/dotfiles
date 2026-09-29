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
import time
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


class AutosnapFreshnessTest(unittest.TestCase):
    """An UNCHANGED layout must still keep its sidecar looking fresh.

    herdr-session-guard refuses a sidecar older than HERDR_GUARD_MAX_AGE_HOURS
    (48h), and mtime is the only freshness signal it has. Skipping the write on an
    unchanged digest is the right call — but skipping the TOUCH too meant a layout
    that simply did not change for two days aged its own snapshot out, and the
    guard then declined on the next reboot: in the one scenario this exists for,
    and for the most stable layout there is.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.cfg = root / 'cfg'
        self.snaps = self.cfg / 'herdr' / 'snapshots'
        self.snaps.mkdir(parents=True)
        self.bin = root / 'bin'
        self.bin.mkdir()

        # A herdr reporting a live server and one fixed pane, so the digest is
        # stable across calls and the second tick sees "unchanged".
        herdr = self.bin / 'herdr'
        herdr.write_text(
            '#!/bin/sh\n'
            'case "$*" in\n'
            '  "status server") exit 0 ;;\n'
            '  "status") printf "server:\\n  status: running\\n" ;;\n'
            '  "api snapshot") printf \'{"result":{"snapshot":'
            '{"panes":[{"pane_id":"w1:p1","tab_id":"w1:t1"}],"agents":[]}}}\' ;;\n'
            'esac\n')
        herdr.chmod(0o755)

        # Only reached when the tick decides to WRITE. It deliberately creates no
        # file, so any new sidecar in the assertions could only come from elsewhere.
        snap = self.bin / 'herdr-snapshot'
        snap.write_text('#!/bin/sh\necho "stub: wrote a snapshot"\n')
        snap.chmod(0o755)

    def tearDown(self):
        self.tmp.cleanup()

    def once(self):
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.cfg),
                   PATH=f"{self.bin}:{os.environ.get('PATH', '/usr/bin:/bin')}")
        return subprocess.run([str(SCRIPT), 'once'], capture_output=True, text=True, env=env)

    def sidecars(self):
        return sorted(self.snaps.glob('*.session.json'))

    def test_an_unchanged_layout_still_refreshes_the_newest_sidecar(self):
        sidecar = self.snaps / '20260920T000000Z.session.json'
        sidecar.write_text('{}')
        stale = time.time() - 40 * 3600          # 40h: inside the 48h limit, but only just
        os.utime(sidecar, (stale, stale))

        self.once()                              # first tick: digest differs, records it
        self.assertEqual(self.once().returncode, 0)   # second tick: unchanged

        self.assertAlmostEqual(sidecar.stat().st_mtime, time.time(), delta=60,
                               msg='an unchanged tick must still touch the newest sidecar')
        self.assertEqual(len(self.sidecars()), 1,
                         'touching must not add a sidecar — skipping the write is still the point')

    def test_only_the_newest_sidecar_is_touched(self):
        old = self.snaps / '20260918T000000Z.session.json'
        new = self.snaps / '20260920T000000Z.session.json'
        for f, hours in ((old, 80), (new, 40)):
            f.write_text('{}')
            t = time.time() - hours * 3600
            os.utime(f, (t, t))

        self.once()
        self.once()

        self.assertAlmostEqual(new.stat().st_mtime, time.time(), delta=60)
        self.assertLess(old.stat().st_mtime, time.time() - 70 * 3600,
                        'the older sidecar must be left alone — the ring still ages out')

    def test_a_tick_with_no_sidecars_at_all_still_succeeds(self):
        # `set -euo pipefail` is on: with no sidecars the glob does not expand, ls
        # exits non-zero, and without the guards the assignment would abort the
        # tick — on a fresh install, where there is nothing to touch.
        self.once()
        r = self.once()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.sidecars(), [])


if __name__ == '__main__':
    unittest.main()
