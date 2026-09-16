"""herdr-replay: the plan it builds from a snapshot against a live session.

Runs the script as a subprocess with `--live <file>` so no Herdr server is
needed. The fixture mirrors the real snapshot shape (protocol 22): a workspace
with a two-pane split tab holding a Claude session, a Firstmate captain pane,
and a workspace that already exists live.
"""
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/herdr/herdr-replay'


def rect(x, y, w, h):
    return {"x": x, "y": y, "width": w, "height": h}


SNAPSHOT = {
    "protocol": 22, "version": "0.9.0",
    "workspaces": [
        {"workspace_id": "w1", "number": 1, "label": "daily", "tab_count": 2, "pane_count": 3},
        {"workspace_id": "w2", "number": 2, "label": "firstmate", "tab_count": 1, "pane_count": 1},
        {"workspace_id": "w3", "number": 3, "label": "already-live", "tab_count": 1, "pane_count": 1},
    ],
    "tabs": [
        {"tab_id": "w1:t1", "workspace_id": "w1", "number": 1, "label": "scrum", "pane_count": 2},
        {"tab_id": "w1:t2", "workspace_id": "w1", "number": 2, "label": "ports", "pane_count": 1},
        {"tab_id": "w2:t1", "workspace_id": "w2", "number": 1, "label": "captain", "pane_count": 1},
        {"tab_id": "w3:t1", "workspace_id": "w3", "number": 1, "label": "keep", "pane_count": 1},
    ],
    "panes": [
        {"pane_id": "w1:p1", "tab_id": "w1:t1", "workspace_id": "w1", "cwd": "/workspace", "agent": "codex"},
        {"pane_id": "w1:p2", "tab_id": "w1:t1", "workspace_id": "w1", "cwd": "/workspace/repos/rock-of-eye-api", "agent": "claude"},
        {"pane_id": "w1:p3", "tab_id": "w1:t2", "workspace_id": "w1", "cwd": "/workspace"},
        {"pane_id": "w2:p1", "tab_id": "w2:t1", "workspace_id": "w2", "cwd": "/workspace/firstmate", "agent": "claude"},
        {"pane_id": "w3:p1", "tab_id": "w3:t1", "workspace_id": "w3", "cwd": "/workspace", "agent": "claude"},
    ],
    "agents": [
        {"pane_id": "w1:p1", "agent": "codex", "cwd": "/workspace", "agent_session": {"kind": "id", "value": "codex-session-1"}},
        {"pane_id": "w1:p2", "agent": "claude", "cwd": "/workspace/repos/rock-of-eye-api", "agent_session": {"kind": "id", "value": "claude-session-2"}},
        {"pane_id": "w2:p1", "agent": "claude", "cwd": "/workspace/firstmate", "agent_session": {"kind": "id", "value": "captain-session"}},
        {"pane_id": "w3:p1", "agent": "claude", "cwd": "/workspace", "agent_session": {"kind": "id", "value": "live-session"}},
    ],
    "layouts": [
        {"tab_id": "w1:t1", "workspace_id": "w1", "panes": [
            {"pane_id": "w1:p1", "rect": rect(0, 0, 100, 50)}, {"pane_id": "w1:p2", "rect": rect(100, 0, 100, 50)}]},
        {"tab_id": "w1:t2", "workspace_id": "w1", "panes": [{"pane_id": "w1:p3", "rect": rect(0, 0, 200, 50)}]},
        {"tab_id": "w2:t1", "workspace_id": "w2", "panes": [{"pane_id": "w2:p1", "rect": rect(0, 0, 200, 50)}]},
        {"tab_id": "w3:t1", "workspace_id": "w3", "panes": [{"pane_id": "w3:p1", "rect": rect(0, 0, 200, 50)}]},
    ],
}

LIVE = {
    "workspaces": [{"workspace_id": "wX", "number": 1, "label": "already-live"}],
    "tabs": [{"tab_id": "wX:t1", "workspace_id": "wX", "number": 1, "label": "keep"}],
    "panes": [], "agents": [], "layouts": [],
}


class HerdrReplayPlanTests(unittest.TestCase):
    def plan(self, *extra):
        with tempfile.TemporaryDirectory() as d:
            snap = Path(d) / 'snap.json'; live = Path(d) / 'live.json'
            snap.write_text(json.dumps({"result": {"snapshot": SNAPSHOT}}))
            live.write_text(json.dumps(LIVE))
            out = subprocess.run([str(SCRIPT), '--snapshot', str(snap), '--live', str(live), *extra],
                                 capture_output=True, text=True, check=False)
            self.assertEqual(out.returncode, 0, out.stderr)
            return out.stdout

    def test_missing_workspace_is_recreated_with_its_tabs_splits_and_agents(self):
        out = self.plan()
        self.assertIn("workspace  create 'daily'", out)
        self.assertIn("tab      create 'scrum' in 'daily'", out)
        self.assertIn("(workspace root tab)", out)
        self.assertIn("split  right 0.5 from w1:p1 → w1:p2 cwd=/workspace/repos/rock-of-eye-api", out)
        self.assertIn("tab      create 'ports' in 'daily'", out)
        self.assertIn("agent  codex resume codex-se… in pane w1:p1", out)
        self.assertIn("agent  claude resume claude-s… in pane w1:p2", out)

    def test_firstmate_captain_pane_is_never_resumed(self):
        out = self.plan()
        self.assertIn("SKIP   claude pane w2:p1 cwd=/workspace/firstmate", out)
        self.assertIn("relaunch via `fm`", out)
        self.assertNotIn("resume captain-", out)

    def test_live_workspace_and_tab_are_kept_not_duplicated(self):
        out = self.plan()
        self.assertIn("tab      keep   'keep' in 'already-live' (exists live)", out)
        self.assertNotIn("workspace  create 'already-live'", out)
        self.assertNotIn("live-session", out)

    def test_workspace_filter(self):
        out = self.plan('--workspace', 'daily')
        self.assertIn("create 'daily'", out)
        self.assertNotIn("firstmate", out)

    def test_dry_run_is_the_default_and_counts_steps(self):
        out = self.plan()
        self.assertIn("would run. Re-run with --apply", out)
        self.assertIn("8 step(s) would run", out)  # daily: ws + 2 tabs + split + 2 agents; firstmate: ws + tab (captain agent skipped)


if __name__ == '__main__':
    unittest.main()
