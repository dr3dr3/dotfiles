# Personal Firstmate coordination

This is a terminal tool for Firstmate's validation workflow, not an agent launcher
or another coordinator. Python uses only the standard library.

| Location | Contents |
| --- | --- |
| dotfiles: `tools/roe-coordination/roe-coordination` | Reservation runner, ownership checks, status and recovery |
| dotfiles: `tools/roe-coordination/setup.py` | Explicit personal install/uninstall and instruction blocks |
| dotfiles: `tools/roe-coordination/policy.md` | Personal platform/tooling routing and authority boundaries |
| local-dev-env: `scripts/runtime-guard.sh` + entry points | Generic, disabled-by-default provider integration |
| Git common directory: `roe-runtime.json`, `roe-runtime-state/` | Local activation, reservation and audit state; never committed |

This integration is **explicitly opt-in**, not part of `setup-herdr.sh`, dotai's
shared setup, or local-dev-env bootstrap. Other developers need neither
Firstmate nor this tool. Install only on a dedicated local-dev-env stack.

```bash
python3 /workspace/dotfiles/tools/roe-coordination/setup.py enable \
  --root /workspace --firstmate-home /workspace/.firstmate-home
roe-coordination status
```

The personal policy is a managed block in user Codex/Claude instructions and
Firstmate's `data/captain-shared.md`. Existing instructions remain intact.
Continue launching Codex or Claude normally in Herdr. There is no agent-launch
wrapper. Agents re-read the personal routing instructions and check coordination
when a task needs the shared runtime. The tool does not depend on a native
Codex startup hook or alter Herdr configuration. Add additional trusted homes
by repeating `--firstmate-home` on enable while no reservation exists.

For a Firstmate-registered task (metadata plus brief and existing worktree), run
a validation script containing stage, tests and unstage under one reservation:

```bash
roe-coordination run --home /workspace/.firstmate-home --task TASK_ID \
  -- bash /path/to/reviewed-validation-script.sh
```

Task IDs and paths above are placeholders. The script must restore the staged
checkouts even when tests fail (for example with an EXIT trap). Existing pilot
restrictions still govern who executes it; a reservation grants no additional
authority. No worker sandbox is widened and no task is dispatched automatically.
Firstmate handles scheduling; a competing run refuses rather than stealing.

The guard is cooperative: Make preflight blocks unrecognized goals conservatively,
and direct staging, exec, stack switching, seeding and selected dependency/reload
scripts also check ownership. Direct Docker/database access, arbitrary scripts,
live-checkout edits and modified guards remain bypasses. Do not use them to
avoid coordination. Strict enforcement requires a separately designed capability
broker; this feature does not claim to provide one.

Config and state live in local-dev-env's **Git common directory**, shared by its
linked worktrees. Firstmate homes using this stack must register with the same
config. Separate clones controlling the same Docker stack must not use separate
reservation stores: this installer supports one canonical checkout and its linked
worktrees, not arbitrary aliases to a Docker daemon. Run runtime commands from
the canonical `/workspace`, not an alternative checkout's Compose configuration.

`run` exports an opaque token only to its child. It stores a hash, task identity,
runner PID and heartbeat, and atomically acquires a whole-stack reservation.
Successful completion releases only after all staging records are gone. Failures,
interruptions and crashes retain ownership. A stale heartbeat never causes
automatic reassignment. Journal entries exclude commands and credentials.

After inspecting processes and stack state, the human can recover an abandoned
reservation. First stop any surviving validation processes, then either clear
an already-restored reservation, or run a restoration command under renewed
ownership for the same task:

```bash
roe-coordination recover --confirm-id RESERVATION_ID --reason 'Reviewed and restored' \
  --processes-stopped-and-state-reviewed
roe-coordination run --home /workspace/.firstmate-home --task TASK_ID \
  --recover-id RESERVATION_ID --processes-stopped-and-state-reviewed \
  -- bash /path/to/reviewed-restoration-script.sh
```

Recovery refuses while the recorded runner is alive. PID reuse can conservatively
block recovery; investigate rather than deleting state blindly. Existing legacy
staging records must be restored before enabling this integration.

Disable after releasing/recovering reservations:

```bash
python3 /workspace/dotfiles/tools/roe-coordination/setup.py disable --root /workspace
```

Disabling removes only the owned blocks, links and activation. Audit state stays
local. Enabled-but-broken providers fail closed; absent activation has no Python
or Firstmate dependency. Test with `python3 dotfiles/tests/test_roe_coordination.py`
from `/workspace`; all fixtures are isolated and use no real Docker stack.

The integration test exercises a registered-task fixture through the real staging
script: reserve, stage committed code, validate, restore, and release. It does not
launch Firstmate or alter a live application. The pilot still requires the captain
to execute runtime commands; this tool does not relax that authority boundary.
