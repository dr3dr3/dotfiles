// Tests for scripts/herdr/herdr-lint.ts — run with `node --test tests/`.
//
// The load-bearing case is the fixture captured from the live layout on
// 2026-10-10, before the conventions were applied. It MUST produce findings:
// a linter that passes the layout the conventions were written to fix is
// checking nothing. The clean snapshot is the positive control the other way —
// it proves "no findings" is reachable, so a zero is a result, not a crash.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { lint, FLAG_DOWN_SPLITS, type Snapshot } from "../scripts/herdr/herdr-lint.ts";

const here = dirname(fileURLToPath(import.meta.url));
const FIXTURE = join(here, "fixtures/herdr-lint/current-layout.json");
const CLI = join(here, "../scripts/herdr/herdr-lint");

function clean(): Snapshot {
  return {
    workspaces: [{ workspace_id: "w1", label: "ai" }],
    tabs: [
      { tab_id: "w1:t1", workspace_id: "w1", label: "init" },
      { tab_id: "w1:t2", workspace_id: "w1", label: "term" },
    ],
    panes: [
      { pane_id: "w1:p1", tab_id: "w1:t1", workspace_id: "w1", label: "init·claude" },
      { pane_id: "w1:p2", tab_id: "w1:t1", workspace_id: "w1", label: "init·shell" },
      { pane_id: "w1:p3", tab_id: "w1:t2", workspace_id: "w1", label: "you·shell" },
    ],
    layouts: { "w1:t1": { splits: [{ direction: "right" }] }, "w1:t2": { splits: [] } },
  };
}

const rules = (s: Snapshot) => lint(s).map((f) => f.rule);

test("a layout that follows the conventions has no findings", () => {
  assert.deepEqual(lint(clean()), []);
});

test("the captured 2026-10-10 layout produces findings", () => {
  const snap = JSON.parse(readFileSync(FIXTURE, "utf8")) as Snapshot;
  const found = rules(snap);
  assert.ok(found.includes("workspace-label"), "infrastructure is over 6 chars");
  assert.ok(found.includes("tab-label"), "ai-setup-thinking is over 8 chars");
  assert.ok(found.includes("pane-unlabelled"));
  assert.equal(found.filter((r) => r === "pane-unlabelled").length, 12);
});

test("workspace labels: 2-6 lowercase characters", () => {
  for (const label of ["infrastructure", "a", "Daily", "has space"]) {
    const s = clean();
    s.workspaces[0].label = label;
    assert.deepEqual(rules(s), ["workspace-label"], label);
  }
  for (const label of ["ai", "daily", "h-ai", "ops2"]) {
    const s = clean();
    s.workspaces[0].label = label;
    assert.deepEqual(rules(s), [], label);
  }
});

test("tab labels: at most 8 characters", () => {
  const s = clean();
  s.tabs[0].label = "ENG-3790 RDS TLS";
  assert.deepEqual(rules(s), ["tab-label"]);
  s.tabs[0].label = "e3790";
  assert.deepEqual(rules(s), []);
});

test("panes: unlabelled is an error, a label not shaped role·harness is a warning", () => {
  const s = clean();
  s.panes[0].label = null;
  delete s.panes[1].label;
  s.panes[2].label = "my shell";
  const found = lint(s);
  assert.deepEqual(
    found.map((f) => [f.rule, f.severity]),
    [
      ["pane-unlabelled", "error"],
      ["pane-unlabelled", "error"],
      ["pane-label", "warn"],
    ],
  );
});

test("panes per tab: more than 2 warns, more than 4 errors", () => {
  const withPanes = (n: number) => {
    const s = clean();
    s.panes = s.panes.filter((p) => p.tab_id !== "w1:t1");
    for (let i = 0; i < n; i++) {
      s.panes.push({ pane_id: `w1:x${i}`, tab_id: "w1:t1", workspace_id: "w1", label: `a${i}·shell` });
    }
    s.layouts["w1:t1"] = { splits: Array.from({ length: n - 1 }, () => ({ direction: "right" as const })) };
    return lint(s).filter((f) => f.rule === "tab-panes");
  };
  assert.deepEqual(withPanes(2), []);
  assert.deepEqual(withPanes(3).map((f) => f.severity), ["warn"]);
  assert.deepEqual(withPanes(4).map((f) => f.severity), ["warn"]);
  assert.deepEqual(withPanes(5).map((f) => f.severity), ["error"]);
});

test("stacked (down) splits are flagged while FLAG_DOWN_SPLITS is on", () => {
  assert.equal(FLAG_DOWN_SPLITS, true, "André confirmed 2026-10-10: side by side only");
  const s = clean();
  s.layouts["w1:t1"] = { splits: [{ direction: "down" }] };
  assert.deepEqual(rules(s), ["split-down"]);
});

test("more than 9 tabs in a workspace is flagged", () => {
  const s = clean();
  for (let i = 0; i < 8; i++) {
    s.tabs.push({ tab_id: `w1:e${i}`, workspace_id: "w1", label: `t${i}` });
    s.panes.push({ pane_id: `w1:e${i}p`, tab_id: `w1:e${i}`, workspace_id: "w1", label: "x·shell" });
  }
  assert.deepEqual(rules(s), ["workspace-tabs"]);
  s.tabs.pop();
  assert.deepEqual(rules(s), []);
});

test("CLI exit codes: 0 clean, 1 findings, 2 could not check", () => {
  const run = (...args: string[]) => spawnSync(CLI, args, { encoding: "utf8" });
  const tmp = join(here, "fixtures/herdr-lint/.clean.tmp.json");
  // Written to disk rather than piped so the CLI exercises its real read path.
  writeFileSync(tmp, JSON.stringify(clean()));
  try {
    assert.equal(run("--fixture", tmp).status, 0);
  } finally {
    unlinkSync(tmp);
  }
  const findings = run("--fixture", FIXTURE);
  assert.equal(findings.status, 1);
  assert.match(findings.stdout, /tab-label/);
  assert.equal(run("--fixture", "/nonexistent/snapshot.json").status, 2);
  // No Herdr to talk to: an unreachable server is "could not check", never "clean".
  const noHerdr = spawnSync(CLI, [], { encoding: "utf8", env: { ...process.env, HERDR_BIN: "/nonexistent/herdr" } });
  assert.equal(noHerdr.status, 2);
});
