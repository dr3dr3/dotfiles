# Personal Firstmate coordination

This integration is **explicitly opt-in**, not part of `setup-herdr.sh`, dotai's
shared setup, or local-dev-env bootstrap. Other developers need neither
Firstmate nor this tool. Install only on a dedicated local-dev-env stack.

```bash
python3 /workspace/dotfiles/tools/roe-coordination/setup.py enable \
  --root /workspace --firstmate-home /workspace/.firstmate-home
roe-coordination status
roe-agent codex
# Resume with a fresh reminder; argv is forwarded unchanged:
roe-agent codex resume
```

The personal policy is a managed block in user Codex/Claude instructions and
Firstmate's `data/captain-shared.md`. Existing instructions remain intact.
Native Herdr session restoration can bypass this wrapper: the instruction block
requires rechecking status after resume. We do not claim a native Codex startup
hook or change Herdr's configuration. Plain agent binaries and existing aliases
retain their launch behavior. Add additional trusted homes by repeating
`--firstmate-home` on enable while no reservation exists.

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
