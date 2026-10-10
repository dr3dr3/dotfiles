// herdr-send — send a message to another Herdr pane only if its input box is empty.
//
//     herdr-send <pane_id> <message...>
//     herdr-send --file <pane_id> <message...>   # write it to a file, send a pointer
//     herdr-send --from init·claude <pane_id> <message...>
//
// Why: on 2026-10-07 a blind `pane send-text` landed in the middle of a command
// André had recalled but not yet run, and garbled it. This reads the target
// first (`pane read --format ansi`) and sends only when the agent's input box is
// empty. Dim (SGR 2) text is a placeholder or suggestion and counts as empty.
// Anything else — typed text, a multi-line draft, a permission dialog, a screen
// it does not recognise — is a refusal: exit 2, nothing typed, nothing appended.
//
// Into an agent it presses Enter. Into a shell (fish, bash, zsh, …) it only
// stages the text: Enter in a shell runs a command, and that is André's call.
//
// Exit codes: 0 sent, 1 usage or herdr error, 2 refused.
//
// Recognises Claude Code's input box (a `❯` line directly under a `───` rule)
// and, when the foreground process is a shell, a shell prompt on the last line
// (Starship `➜`/`❯`, plain `$`). Other harnesses are refused as "no input box"
// until a capture of theirs is added to the tests — failing closed is the point.
// A pane labelled `you·…` (André's, e.g. `term`) is only ever staged into.
//
// There is still a window between the read and the send in which someone could
// start typing. It is a few milliseconds, not the open-ended window of a blind
// send, but it is not zero.

import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const SHELLS = new Set(["bash", "fish", "zsh", "sh", "dash", "nu", "pwsh"]);
const RULE = /^─{3,}/;
const PROMPT = "❯";

export type InputState = { state: "empty" | "typed" | "none"; text: string };

// Remove escape sequences, and with them any text drawn while SGR 2 (dim) is on.
function visibleText(line: string): string {
  let out = "";
  let dim = false;
  const re = /\x1b\[([0-9;]*)m|\x1b\[[0-9;?]*[A-Za-z]|([^\x1b]+)/g;
  for (const m of line.matchAll(re)) {
    if (m[2] !== undefined) {
      if (!dim) out += m[2];
    } else if (m[1] !== undefined) {
      // Walk the parameters properly: 38/48/58 introduce a colour whose own
      // arguments (5;n or 2;r;g;b) contain 2s that are NOT the dim attribute.
      // Treating them as dim once hid green and truecolour text entirely.
      const ps = (m[1] || "0").split(";");
      for (let k = 0; k < ps.length; k++) {
        const p = ps[k];
        if (p === "38" || p === "48" || p === "58") {
          k += ps[k + 1] === "5" ? 2 : ps[k + 1] === "2" ? 4 : 0;
        } else if (p === "2") dim = true;
        else if (p === "0" || p === "" || p === "22") dim = false;
      }
    }
  }
  return out;
}

const plain = (line: string) => line.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "");

// A shell prompt: the last non-blank line starts with a prompt symbol (Starship
// `➜`/`❯`, plain `$`/`#`/`%`/`>`), optionally after one host/path-like token
// with no spaces, such as `user@host:~$`. Whatever follows the symbol, minus dim text, is the
// command line. A fish autosuggestion only appears after a typed prefix, so it
// never makes a typed line look empty. Anything else is "none" — fail closed.
const SHELL_PROMPT = /^\s*(?:\S*[@:~/]\S*?)?[➜❯$#%>](?=\s|$)/u;

function shellInputState(screen: string): InputState {
  const lines = screen.split("\n").map((l) => l.replace(/\r$/, ""));
  let i = lines.length - 1;
  while (i >= 0 && !plain(lines[i]).trim()) i--;
  if (i < 0) return { state: "none", text: "" };
  const visible = visibleText(lines[i]);
  const match = visible.match(SHELL_PROMPT);
  if (!match) return { state: "none", text: "" };
  const text = visible.slice(match[0].length).trim();
  return { state: text ? "typed" : "empty", text };
}

export function inputState(screen: string, kind: "agent" | "shell" = "agent"): InputState {
  if (kind === "shell") return shellInputState(screen);
  const lines = screen.split("\n").map((l) => l.replace(/\r$/, ""));
  // The input box is the LAST column-0 prompt that sits directly under a rule.
  // History prompts are not under a rule; a permission dialog's `❯` is indented.
  let start = -1;
  for (let i = 1; i < lines.length; i++) {
    if (plain(lines[i]).startsWith(PROMPT) && RULE.test(plain(lines[i - 1]))) start = i;
  }
  if (start < 0) return { state: "none", text: "" };
  let end = start + 1;
  while (end < lines.length && !RULE.test(plain(lines[end]))) end++;
  if (end >= lines.length) return { state: "none", text: "" };

  const body = lines.slice(start, end).map((l, i) => {
    const text = visibleText(l);
    return i === 0 ? text.slice(text.indexOf(PROMPT) + PROMPT.length) : text;
  });
  const text = body.map((t) => t.trim()).filter(Boolean).join("\n");
  return { state: text ? "typed" : "empty", text };
}

class Refused extends Error {}
class Failed extends Error {}

function herdr(args: string[]): any {
  const bin = process.env.HERDR_BIN || "herdr";
  let out: string;
  try {
    out = execFileSync(bin, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  } catch (err) {
    throw new Failed(`herdr ${args.slice(0, 2).join(" ")} failed: ${(err as Error).message.split("\n")[0]}`);
  }
  if (args[1] === "read") return out;
  // send-text and send-keys print nothing at all on success.
  if (!out.trim()) return {};
  const parsed = JSON.parse(out);
  if (parsed.error) throw new Failed(`herdr ${args.slice(0, 2).join(" ")}: ${parsed.error.message}`);
  return parsed.result;
}

const sleep = (ms: number) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

function stamp(): string {
  const d = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
  return `${d}-${Math.random().toString(36).slice(2, 8)}`;
}

function main(argv: string[]): number {
  let file = false;
  let from: string | undefined;
  const rest: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--file") file = true;
    else if (argv[i] === "--from") from = argv[++i];
    else rest.push(argv[i]);
  }
  const [pane, ...words] = rest;
  const message = words.join(" ");
  if (!pane || !message) {
    process.stderr.write("usage: herdr-send [--file] [--from LABEL] <pane_id> <message...>\n");
    return 1;
  }

  try {
    const target = herdr(["pane", "get", pane]).pane;
    if (target.agent_status === "blocked") throw new Refused(`${pane} is blocked on a question or approval`);

    const fg = herdr(["pane", "process-info", "--pane", pane]).process_info.foreground_processes?.[0]?.name ?? "";
    const isShell = SHELLS.has(fg);
    // André's own panes (`you·…`, e.g. the `term` tab) never get an Enter from
    // an agent, whatever is running in them.
    const stageOnly = isShell || String(target.label ?? "").startsWith("you·");

    const screen = herdr(["pane", "read", pane, "--source", "visible", "--format", "ansi", "--lines", "60"]);
    const input = inputState(screen, isShell ? "shell" : "agent");
    if (input.state === "none") throw new Refused(`${pane} shows no input box herdr-send recognises`);
    if (input.state === "typed") throw new Refused(`${pane}'s input box is not empty: "${input.text.slice(0, 60)}"`);

    let text = message;
    if (file) {
      const dir = process.env.HERDR_SEND_DIR || "/workspace/tmp";
      mkdirSync(dir, { recursive: true });
      const path = join(dir, `msg-${stamp()}.md`);
      writeFileSync(path, message.endsWith("\n") ? message : message + "\n");
      const self = process.env.HERDR_PANE_ID;
      const sender = from ?? (self ? herdr(["pane", "get", self]).pane.label : undefined) ?? "herdr-send";
      text = `[from ${sender}] ${path}`;
    } else if (from) {
      text = `[from ${from}] ${message}`;
    }

    herdr(["pane", "send-text", pane, text]);
    if (stageOnly) {
      process.stdout.write(`staged in ${pane} (${fg}); Enter left to the owner\n`);
      return 0;
    }
    sleep(300);
    herdr(["pane", "send-keys", pane, "enter"]);
    process.stdout.write(`sent to ${pane}\n`);
    return 0;
  } catch (err) {
    if (err instanceof Refused) {
      process.stderr.write(`herdr-send: refused: ${err.message}\n`);
      return 2;
    }
    if (err instanceof Failed) {
      process.stderr.write(`herdr-send: ${err.message}\n`);
      return 1;
    }
    throw err;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = main(process.argv.slice(2));
}
