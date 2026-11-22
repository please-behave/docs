# Git hooks

Git hooks are optional. Please Behave supports three: `pre-commit`,
`commit-msg` and `pre-push`. Each runs the execution point of the same name.
The `check` point and custom points have no hook; run them directly, for example
in CI.

## Install and update hooks

You never write hooks yourself. `please sync` derives the hooks you need from
your enabled Rule assignments, including those inherited from Rule Sets and
imports, and installs, updates or removes them. Run it after every change to
`.please/`. All hook failures block Git, including a `please` that is missing
from `PATH`.

Synchronization follows these steps: validate the configuration, inspect the
current state, plan the changes, ask for confirmation, apply and verify. A
synchronized state needs no prompt and no write. Changes are displayed and need
confirmation in a terminal. If you decline, no terminal is available, a conflict
exists or a step fails, the command exits with code 2 and keeps the previous
report. `please run` for a Git hook point performs the same reconciliation
before it runs any Rule, and inside a hook it is read-only: drift fails with
the instruction to run `please sync`. `--plan` never synchronizes.

For unattended setup, `--yes` approves the displayed plan without a terminal.
It manages declared integration state only and does nothing when everything is
synchronized.

```sh
please sync --yes
```

Importing Rule Sets from a Git repository additionally requires
`please trust REPOSITORY`; `--yes` never grants trust.

## Hook input

A hook does not pass its arguments to your checks, and standard input is
empty. Staged files, the commit message and the pushed references are in the
[run context](configuration.md#rule-inputs). Checks of `commit-msg` find the
message file there; see
[Review commit messages](configuration.md#review-commit-messages) for a
complete example.

A check must not run Please Behave again in the same repository. A guard blocks
nested runs and synchronization before anything is written. Checks may run
Please Behave in other repositories.

## Ownership and conflicts

Managed hooks are delimited by `# BEGIN PLEASE MANAGED` and
`# END PLEASE MANAGED` markers, and an ownership line ties them to the common
Git repository. An existing executable `#!/bin/sh` hook receives a managed
section after its shebang and keeps the rest of its content. Everything else is
a conflict and `please sync` stops before writing anything: other shebangs,
hooks that are not executable, malformed or duplicate markers, symlinks and
hooks owned by another repository. Resolve the conflict by hand and run
`please sync` again. Do not copy managed hooks between repositories; each clone
generates its own.

Git decides the effective hooks directory, including `core.hooksPath` and
worktrees. A custom directory must lie inside the working tree. Linked
worktrees share the common hooks directory and must agree on the mappings.
Changing or removing a mapping only touches the managed sections.

Updating several hook files is not one atomic transaction. After an
interruption, inspect the reported paths and run `please sync` again. Remove
leftover `.please-hook-*` files once no other synchronization is running.

## Limits

Local hooks can be skipped with `--no-verify`, and they verify the working tree,
not the exact staged index or the commit being pushed. Run the same execution
points on a clean checkout in CI to close that gap.
