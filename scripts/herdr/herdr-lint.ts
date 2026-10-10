// herdr-lint — check the live Herdr layout against docs/herdr-conventions.md.
//
// Read-only: it lists workspaces, tabs, panes and per-tab layouts through the
// herdr CLI and never changes anything.
//
//     herdr-lint                      # lint the live session
//     herdr-lint --json               # findings as JSON
//     herdr-lint --fixture FILE       # lint a saved snapshot instead
//     herdr-lint --dump               # print the live snapshot (to save as a fixture)
//
// Exit codes: 0 clean, 1 findings, 2 could not check. "Could not check" is
// never reported as clean: an unreachable server or an unreadable snapshot
// exits 2, because a linter that exits 0 having looked at nothing is worse
// than no linter.
//
// Not yet checked: panes whose agent has been idle or finished for a long time.
// Herdr exposes the current agent_status but no time-in-state, so there is
// nothing to measure "long" against yet.

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

// André confirmed 2026-10-10 that panes go side by side. Flip this one constant
// if stacked splits ever become acceptable again.
export const FLAG_DOWN_SPLITS = true;

export const WORKSPACE_LABEL = /^[a-z0-9-]{2,6}$/;
export const TAB_LABEL_MAX = 8;
export const PANE_LABEL = /^[a-z0-9-]+·[a-z0-9-]+$/;
export const PANES_WARN_ABOVE = 2;
export const PANES_ERROR_ABOVE = 4;
export const TABS_MAX = 9;

export type Snapshot = {
  workspaces: { workspace_id: string; label: string }[];
  tabs: { tab_id: string; workspace_id: string; label: string }[];
  panes: { pane_id: string; tab_id: string; workspace_id: string; label?: string | null }[];
  layouts: Record<string, { splits: { direction: "right" | "down" }[] }>;
};

export type Finding = {
  severity: "error" | "warn";
  rule: string;
  target: string;
  message: string;
};

export function lint(snap: Snapshot): Finding[] {
  const findings: Finding[] = [];
  const add = (severity: Finding["severity"], rule: string, target: string, message: string) =>
    findings.push({ severity, rule, target, message });

  for (const ws of snap.workspaces) {
    if (!WORKSPACE_LABEL.test(ws.label)) {
      add("error", "workspace-label", ws.workspace_id, `workspace "${ws.label}" is not 2-6 lowercase characters`);
    }
    const tabs = snap.tabs.filter((t) => t.workspace_id === ws.workspace_id);
    if (tabs.length > TABS_MAX) {
      add("error", "workspace-tabs", ws.workspace_id, `workspace "${ws.label}" has ${tabs.length} tabs (max ${TABS_MAX})`);
    }
  }

  for (const tab of snap.tabs) {
    if ([...tab.label].length > TAB_LABEL_MAX) {
      add("error", "tab-label", tab.tab_id, `tab "${tab.label}" is over ${TAB_LABEL_MAX} characters`);
    }
    const panes = snap.panes.filter((p) => p.tab_id === tab.tab_id);
    if (panes.length > PANES_ERROR_ABOVE) {
      add("error", "tab-panes", tab.tab_id, `tab "${tab.label}" has ${panes.length} panes (max ${PANES_ERROR_ABOVE})`);
    } else if (panes.length > PANES_WARN_ABOVE) {
      add("warn", "tab-panes", tab.tab_id, `tab "${tab.label}" has ${panes.length} panes (setup max ${PANES_WARN_ABOVE})`);
    }
    const downs = (snap.layouts[tab.tab_id]?.splits ?? []).filter((s) => s.direction === "down").length;
    if (FLAG_DOWN_SPLITS && downs > 0) {
      add("error", "split-down", tab.tab_id, `tab "${tab.label}" has ${downs} stacked split(s); split right instead`);
    }
  }

  const tabLabel = new Map(snap.tabs.map((t) => [t.tab_id, t.label]));
  for (const pane of snap.panes) {
    if (!pane.label) {
      const where = `pane ${pane.pane_id} in tab "${tabLabel.get(pane.tab_id) ?? pane.tab_id}"`;
      add("error", "pane-unlabelled", pane.pane_id, `${where} has no label (want <role>·<harness>)`);
    } else if (!PANE_LABEL.test(pane.label)) {
      add("warn", "pane-label", pane.pane_id, `pane "${pane.label}" is not shaped <role>·<harness>`);
    }
  }

  return findings;
}

class CannotCheck extends Error {}

function herdr(args: string[]): any {
  const bin = process.env.HERDR_BIN || "herdr";
  let out: string;
  try {
    out = execFileSync(bin, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  } catch (err) {
    throw new CannotCheck(`herdr ${args.join(" ")} failed: ${(err as Error).message.split("\n")[0]}`);
  }
  const parsed = JSON.parse(out);
  if (parsed.error) throw new CannotCheck(`herdr ${args.join(" ")}: ${parsed.error.message}`);
  return parsed.result;
}

export function collect(): Snapshot {
  const workspaces = herdr(["workspace", "list"]).workspaces.map((w: any) => ({
    workspace_id: w.workspace_id,
    label: w.label,
  }));
  const tabs = workspaces.flatMap((w: any) =>
    herdr(["tab", "list", "--workspace", w.workspace_id]).tabs.map((t: any) => ({
      tab_id: t.tab_id,
      workspace_id: t.workspace_id,
      label: t.label,
    })),
  );
  const panes = herdr(["pane", "list"]).panes.map((p: any) => ({
    pane_id: p.pane_id,
    tab_id: p.tab_id,
    workspace_id: p.workspace_id,
    label: p.label ?? null,
  }));
  const layouts: Snapshot["layouts"] = {};
  for (const tab of tabs) {
    const first = panes.find((p: any) => p.tab_id === tab.tab_id);
    if (!first) continue;
    const layout = herdr(["pane", "layout", "--pane", first.pane_id]).layout;
    layouts[tab.tab_id] = { splits: layout.splits.map((s: any) => ({ direction: s.direction })) };
  }
  return { workspaces, tabs, panes, layouts };
}

function load(path: string): Snapshot {
  let snap: Snapshot;
  try {
    snap = JSON.parse(readFileSync(path, "utf8"));
  } catch (err) {
    throw new CannotCheck(`cannot read snapshot ${path}: ${(err as Error).message}`);
  }
  for (const key of ["workspaces", "tabs", "panes", "layouts"] as const) {
    if (!snap[key]) throw new CannotCheck(`snapshot ${path} has no "${key}"`);
  }
  return snap;
}

function main(argv: string[]): number {
  const fixture = argv.includes("--fixture") ? argv[argv.indexOf("--fixture") + 1] : undefined;
  try {
    const snap = fixture ? load(fixture) : collect();
    if (argv.includes("--dump")) {
      process.stdout.write(JSON.stringify(snap, null, 2) + "\n");
      return 0;
    }
    const findings = lint(snap);
    if (argv.includes("--json")) {
      process.stdout.write(JSON.stringify(findings, null, 2) + "\n");
    } else {
      for (const f of findings) process.stdout.write(`${f.severity.padEnd(5)} ${f.rule.padEnd(16)} ${f.message}\n`);
      const errors = findings.filter((f) => f.severity === "error").length;
      process.stdout.write(
        `${snap.workspaces.length} workspaces, ${snap.tabs.length} tabs, ${snap.panes.length} panes: ` +
          `${errors} errors, ${findings.length - errors} warnings\n`,
      );
    }
    return findings.length ? 1 : 0;
  } catch (err) {
    if (!(err instanceof CannotCheck) && !(err instanceof SyntaxError)) throw err;
    process.stderr.write(`herdr-lint: could not check: ${(err as Error).message}\n`);
    return 2;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = main(process.argv.slice(2));
}
