// Tests for scripts/herdr/herdr-send.ts — run with `node --test tests/*.test.ts`.
//
// The fixtures are real `herdr pane read --format ansi` captures of a Claude
// Code 2.1.296 pane, trimmed to the last 14 lines. The refusal cases matter
// most: on 2026-10-07 a blind send landed in the middle of André's recalled
// command and garbled it, so "typed", "multiline" and "blocked" must refuse and
// the CLI must not call send-text at all when they do.

import { test } from "node:test";
import assert from "node:assert/strict";
import { chmodSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { inputState } from "../scripts/herdr/herdr-send.ts";

const here = dirname(fileURLToPath(import.meta.url));
const fixture = (name: string) => readFileSync(join(here, "fixtures/herdr-send", `claude-${name}.ansi`), "utf8");
const CLI = join(here, "../scripts/herdr/herdr-send");

test("an empty input box with a dim placeholder is empty", () => {
  assert.equal(inputState(fixture("empty")).state, "empty");
});

test("an empty input box after a finished turn is empty, despite a history prompt above it", () => {
  assert.equal(inputState(fixture("after-turn")).state, "empty");
});

test("typed text is not empty", () => {
  const s = inputState(fixture("typed"));
  assert.equal(s.state, "typed");
  assert.equal(s.text, "half-typed command");
});

test("a multi-line draft is not empty, even if its first line were cleared", () => {
  const s = inputState(fixture("multiline"));
  assert.equal(s.state, "typed");
  assert.match(s.text, /line two/);
  const firstLineGone = fixture("multiline").replace("line one", "");
  assert.equal(inputState(firstLineGone).state, "typed");
});

test("a permission dialog has no input box", () => {
  assert.equal(inputState(fixture("blocked")).state, "none");
});

test("no recognisable input box is 'none', never 'empty'", () => {
  assert.equal(inputState("").state, "none");
  assert.equal(inputState("$ ls\r\nfoo bar\r\n$ ").state, "none");
});

// A fake herdr that serves a fixture for `pane read`, describes the target pane,
// and logs every other call so the test can see whether anything was sent.
function fakeHerdr(screen: string, opts: { fg?: string; status?: string; label?: string } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "herdr-send-"));
  writeFileSync(join(dir, "screen.ansi"), screen);
  const pane = { pane_id: "w1:p9", agent_status: opts.status ?? "idle", label: opts.label ?? "init·claude" };
  const proc = { foreground_processes: [{ name: opts.fg ?? "claude" }] };
  writeFileSync(
    join(dir, "herdr"),
    `#!/usr/bin/env bash
echo "$*" >> "${dir}/calls.log"
case "$1 $2" in
  "pane read") cat "${dir}/screen.ansi" ;;
  "pane get") echo '${JSON.stringify({ result: { pane } })}' ;;
  "pane process-info") echo '${JSON.stringify({ result: { process_info: proc } })}' ;;
  *) ;;  # the real send-text / send-keys print nothing on success
esac
`,
  );
  chmodSync(join(dir, "herdr"), 0o755);
  const run = (...args: string[]) =>
    spawnSync(CLI, args, {
      encoding: "utf8",
      env: { ...process.env, HERDR_BIN: join(dir, "herdr"), HERDR_SEND_DIR: dir, HERDR_PANE_ID: "" },
    });
  const sends = () =>
    readFileSync(join(dir, "calls.log"), "utf8")
      .split("\n")
      .filter((l) => l.startsWith("pane send-"));
  return { dir, run, sends };
}

test("CLI refuses with exit 2 and sends nothing when the input box has text", () => {
  const h = fakeHerdr(fixture("typed"));
  const r = h.run("w1:p9", "hello");
  assert.equal(r.status, 2);
  assert.match(r.stderr, /not empty/);
  assert.deepEqual(h.sends(), []);
});

test("CLI refuses with exit 2 and sends nothing at a permission dialog", () => {
  const h = fakeHerdr(fixture("blocked"), { status: "blocked" });
  assert.equal(h.run("w1:p9", "hello").status, 2);
  assert.deepEqual(h.sends(), []);
});

test("CLI sends text then Enter into an empty agent input", () => {
  const h = fakeHerdr(fixture("empty"));
  const r = h.run("w1:p9", "hello");
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(h.sends(), ["pane send-text w1:p9 hello", "pane send-keys w1:p9 enter"]);
});

// Shell fixtures are real captures, trimmed to 4 lines: André's own `term` pane
// (read only, fish + Starship `➜`), a probe pane's fish in the same states, and
// a plain bash `$ ` prompt. The first version of this file tested shells with a
// Claude screen and a fake `fish` process, which hid that a real shell prompt
// was refused as "no input box" — so herdr-send could never stage into `term`.
const shell = (name: string) => readFileSync(join(here, "fixtures/herdr-send", `shell-${name}.ansi`), "utf8");

test("real shell prompts with nothing typed are empty", () => {
  for (const name of ["fish-term-empty", "fish-empty", "fish-after-error", "bash-empty"]) {
    assert.equal(inputState(shell(name), "shell").state, "empty", name);
  }
});

test("real shell prompts with text are typed, including a fish autosuggestion", () => {
  assert.equal(inputState(shell("fish-typed"), "shell").text, "echo half typed");
  assert.equal(inputState(shell("bash-typed"), "shell").text, "ls -la");
  // Fish only suggests after a typed prefix, so a suggestion means "not empty".
  assert.equal(inputState(shell("fish-autosuggest"), "shell").state, "typed");
});

test("colour codes containing a 2 are not the dim attribute", () => {
  // 38;2;r;g;b truecolour (Claude Code's own styling) and 38;5;2 green both
  // carry a "2" parameter. Reading either as SGR 2 would make typed text vanish
  // and a non-empty input box look empty.
  const box = (styled: string) => `────\r\n❯ ${styled}\r\n────\r\n`;
  assert.equal(inputState(box("\x1b[38;2;255;255;255mhalf-typed\x1b[0m")).state, "typed");
  assert.equal(inputState(box("\x1b[38;5;2mhalf-typed\x1b[0m")).state, "typed");
  assert.equal(inputState(box("\x1b[48;2;55;55;55mhalf-typed\x1b[0m")).state, "typed");
  // ...while real dim text, even combined with a colour, is still a placeholder.
  assert.equal(inputState(box("\x1b[2;38;5;7mTry something\x1b[0m")).state, "empty");
});

test("a shell screen with no recognisable prompt is 'none'", () => {
  assert.equal(inputState("building...\r\n  42% done\r\n", "shell").state, "none");
});

test("CLI stages into a real fish term pane without pressing Enter", () => {
  const h = fakeHerdr(shell("fish-term-empty"), { fg: "fish", label: "you·shell" });
  const r = h.run("w1:p9", "make doctor");
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(h.sends(), ["pane send-text w1:p9 make doctor"]);
});

test("CLI refuses a shell with a half-typed command and sends nothing", () => {
  const h = fakeHerdr(shell("fish-typed"), { fg: "fish", label: "you·shell" });
  assert.equal(h.run("w1:p9", "make doctor").status, 2);
  assert.deepEqual(h.sends(), []);
});

test("CLI never presses Enter in André's pane, even when an agent is running there", () => {
  const h = fakeHerdr(fixture("empty"), { fg: "claude", label: "you·shell" });
  const r = h.run("w1:p9", "hello");
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(h.sends(), ["pane send-text w1:p9 hello"]);
});

test("importing the module without a script path does not throw (node -e)", () => {
  const mod = join(here, "../scripts/herdr/herdr-send.ts");
  const r = spawnSync(process.execPath, ["--input-type=module", "-e", `await import(${JSON.stringify(mod)})`], {
    encoding: "utf8",
  });
  assert.equal(r.status, 0, r.stderr);
});

test("--file writes the message to a file and sends a one-line pointer", () => {
  const h = fakeHerdr(fixture("empty"));
  const r = h.run("--file", "w1:p9", "a long\nmulti-line report");
  assert.equal(r.status, 0, r.stderr);
  const files = readdirSync(h.dir).filter((f) => /^msg-.*\.md$/.test(f));
  assert.equal(files.length, 1);
  assert.equal(readFileSync(join(h.dir, files[0]), "utf8"), "a long\nmulti-line report\n");
  const [text, enter] = h.sends();
  assert.ok(text.includes(join(h.dir, files[0])), text);
  assert.ok(!text.includes("multi-line report"), "the body must not be typed into the pane");
  assert.equal(enter, "pane send-keys w1:p9 enter");
});

test("--file still refuses when the input box has text, and writes no file", () => {
  const h = fakeHerdr(fixture("typed"));
  assert.equal(h.run("--file", "w1:p9", "report").status, 2);
  assert.deepEqual(h.sends(), []);
  assert.deepEqual(readdirSync(h.dir).filter((f) => f.startsWith("msg-")), []);
});

test("a column-0 prompt that is not directly under a rule is not an input box", () => {
  assert.equal(inputState("some output\r\n❯ \r\n────────────\r\n").state, "none");
});

test("CLI refuses an unrecognised screen even when Herdr says the agent is idle", () => {
  const h = fakeHerdr("$ ls\r\nfoo\r\n$ ", { status: "idle" });
  const r = h.run("w1:p9", "hello");
  assert.equal(r.status, 2);
  assert.match(r.stderr, /no input box/);
  assert.deepEqual(h.sends(), []);
});
