# Herdr conventions

How workspaces, tabs and panes are named and laid out, for people and agents
alike. Agreed 2026-10-10. Keybindings and setup are in [`HERDR.md`](HERDR.md);
the session pattern behind this is ai-context
`reference/diagrams/14-herdr-session-topology.md`.

## Names

| Level | Rule | Examples |
|---|---|---|
| Workspace | One area of work. 2–6 lowercase characters. Host-side workspaces start with `h-`. | `ai`, `daily`, `ops`, `think`, `h-ai` |
| Tab | One thread. At most 8 characters: a short topic or a ticket. | `init`, `rev`, `tls`, `e3790` |
| Pane | One actor, labelled `<role>·<harness>`. | `init·claude`, `rev·claude`, `review·codex`, `you·shell` |

The long description of a thread belongs on the pane label, never on the tab.
Label every pane you create: `herdr pane rename <pane_id> <role>·<harness>`.

## Layout

- **Side by side.** Split `right`, never `down`.
- **One pane per tab** by default. A second pane only for a defined pair: an
  agent and its shell, an agent and its reviewer, or an agent and André's
  operator pane.
- **At most 2 panes per tab by setup, 4 at any time.** More than 2 is a
  warning; more than 4 is an error. Need more? Open a tab.
- **At most 9 tabs per workspace**, so `Alt+1..9` reaches every one.

## Checking

`herdr-lint` (linked onto `PATH` by `scripts/setup-herdr.sh`) reports every
breach of the rules above in the live session. It is read-only. Exit 0 means
clean, 1 means findings, 2 means it could not check. `--json` gives machine
output; `--dump` saves a snapshot that `--fixture` can lint later.

## Operating rules

- **`term` is André's.** Each workspace has one `term` tab with a `you·shell`
  pane. Agents may stage a command there with `herdr pane send-text` and never
  press Enter.
- **Never type into another agent's input blindly.** Read its pane first and
  send only if the input box is empty (a dim suggestion counts as empty), or
  write the message to a file and send a one-line pointer. `herdr-send <pane>
  <message>` does the read for you and refuses (exit 2) if the box is not empty; add
  `--file` for anything longer than a line. A blind send on
  2026-10-07 landed mid-way through a recalled command and garbled it.
- **Close what you open** when finished. Never close a pane, tab or workspace
  you did not create without André's approval.
- **Rotate long sessions.** A session that has grown very large hands off
  through a checkpoint rather than living forever.
