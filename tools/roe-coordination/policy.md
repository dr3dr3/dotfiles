# Personal RoE work routing

Applies only to the explicitly configured local-dev-env instance. It does not change other developers' workflows.

Firstmate coordinates app/platform implementation: app repos, infrastructure and helper containers. Independent internal tooling (including product-discovery and roe-explainers) may run directly in Herdr. local-dev-env editing is independent until an action affects the shared runtime. Read-only exploration does not require a new Firstmate task.

Before implementation, state the lane and check `roe-coordination status`. A session opened for platform implementation outside Firstmate should prepare a bounded task brief and route it through Firstmate; do not silently become another coordinator or transmit messages without authorization. Re-check after resume and whenever scope changes.

Before staging/unstaging, service lifecycle changes, shared dependency changes or stateful validation, obtain the runtime through Firstmate. Use `roe-coordination run --home <registered-home> --task <existing-task-id> -- <command>`. Group stage, test and unstage in one script passed to run. Commit first. Restore the stack even when tests fail. The wrapper keeps ownership on failure or while staging records remain; never bypass a refusal. `status` explains ownership and `recover` is an explicit human reconciliation path.

A reservation coordinates access only. It grants no permission to deploy, migrate, destroy, access credentials, broaden worker sandboxes or override the pilot's captain-only runtime restrictions. Firstmate may arrange a reservation-backed command for the captain where those restrictions apply. All existing project and permission rules remain in force.

Do not use direct Docker, database access, or edits to a live mounted checkout to bypass reservations. This is cooperative enforcement at supported entry points, not a security sandbox. Independent coding and static checks can continue while the stack is reserved.
