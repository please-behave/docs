# Running rules

`please run` executes the Rules that are assigned to an execution point and
saves the outcome as a report. This page covers selecting and previewing Rules,
reading results and the exit codes of all commands. Checks and reviews are
together called **Rules**; the [configuration guide](configuration.md) explains
how to write them.

## Execution points

The default execution point is `pre-push`. Select another one with `--at`. The
built-in points are `pre-commit`, `commit-msg`, `pre-push` and `check`; you can
declare custom points in the project settings. The first three are run by Git
hooks, see [Git hooks](git-hooks.md). `check` and custom points have no hook:
invoke them directly, for example in CI, where they work on a fresh checkout.
Please Behave generates no CI workflow.

Every selected Rule is required, with one exception: a review with
`blocking = false` stays visible when it fails but does not prevent success.
Checks run concurrently, up to `[execution] max_parallel` at a time. Override
the limit with `--max-parallel`, and give checks that share mutable state the
same [shared resource](configuration.md#shared-resources). `--fail-fast` stops
scheduling after a blocking failure or error.

## Preview a run

A plan preview shows which Rules would run and what input they would receive,
before any check runs or any review spends tokens.

```sh
please run --at pre-push --plan
please run --at pre-push --plan --json
```

The preview works offline against previously synchronized imports, runs no
Rule, saves no report and leaves the newest report untouched. Read the status
and the blocking reasons first. A `PLANNED` preview describes what can be
executed and does not say that the Rules pass. A blocked preview exits with
code 2 and explains what prevents preparation. Disabled Rules are listed
separately. The preview also shows context sizes and the number of planned
adapter calls; every review is one call, even when reviews share an adapter
profile.

Reviews at `check` and custom points compare against a commit that you supply.
In CI, use the merge base of the pull request:

```sh
PLEASE_CHANGE_BASE=BASE_COMMIT please run --at check --plan --json
```

The commit must exist locally; the preview does not fetch it. A `commit-msg`
review needs the message that the managed hook supplies, so a direct preview of
it is blocked. The [JSON output](https://github.com/please-behave/cli/blob/main/why/contracts/plan/preview.md)
and the [plan identity](https://github.com/please-behave/cli/blob/main/why/contracts/plan/prepared.md)
are defined in the CLI repository.

## Run only the checks

```sh
please run --checks-only
```

`--checks-only` runs the checks of the execution point and calls no adapter.
Selected reviews are reported `NOT_RUN` and do not count towards the result, so
a `PASS` means that the checks passed, not the reviews. The report, the plan
and `please status` say that the run was limited. It is useful for fast local
feedback and for pipelines that cannot reach an adapter.

## Run results

Each valid run saves a new numbered report, `.please/reports/<number>.json`,
also when the verdict is `FAIL` or `ERROR`, and names its number in the summary
line. `report.retain_runs` (default 10) keeps the newest reports; numbering
continues after older ones are removed. A run with an invalid configuration
saves no report and leaves the saved ones untouched. Reports are git-ignored and
stay on your machine. Each review result names the adapter profile that produced
it, or none if it used the default profile or made no call. The
[report contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/document.md)
defines the format.

Progress appears on stderr: each Rule shows its display name (the optional
`name` in `rule.toml`, otherwise its ID), then its result and duration.
`--progress` selects the style. `auto` redraws in an interactive terminal and
appends plain lines in CI, with `TERM=dumb` or when stderr is redirected;
`plain` and `tty` force one style. Colors follow `NO_COLOR`, `--no-color` and
whether the stream is a terminal.

The last line summarizes the run, for example
`FAIL · 3 rules · 1 failed · 1 not executed · 2.0 s`. If the run does not
pass, a short failure summary follows: the number of Rules that prevented
success, up to three lines of cause for the first one, and a pointer to
`please status --details`. If a check fails or errors, reviews are not started
and are reported `NOT_RUN`, so no tokens are spent on them. Disabled Rules never
appear in results.

## Read the status

`please status` shows the newest saved report without running anything. It
compares the report's snapshot with your working tree and reports one of:

- `CURRENT`: nothing relevant changed since the run.
- `STALE`: files changed since the run.
- `UNKNOWN`: the snapshot is incomplete, so the comparison is not possible.

Only hashes are stored, so line counts of changes are unavailable. Use
`--report NUMBER` to show an older report. `--details` adds the full findings,
the captured output, the selection, the required Rule IDs, external sources and
token usage. Captured output is limited per stream and is not redacted, so do
not let your checks print secrets. See
[snapshot freshness](https://github.com/please-behave/cli/blob/main/why/contracts/report/snapshot.md)
for the exact rules.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Initialization, validation or help succeeded, a plan preview is executable, or all required results are `PASS` and the status is `CURRENT` |
| 1 | Verification `FAIL`, or status `STALE` |
| 2 | Configuration, reconciliation, execution, adapter or report `ERROR`; a plan preview blocked by a configuration or selection error; declined or unavailable confirmation; status `UNKNOWN`; or invalid command-line arguments |
| 3 | Status requested for a report that does not exist |

`please status` of a `CURRENT` report returns the exit code of the saved run:
0 for `PASS`, 1 for `FAIL`, 2 for `ERROR`. `UNKNOWN` takes precedence when the
snapshot is incomplete. `please publish` exits with 0 when the gateway accepted
the attestation and with 2 when delivery did not succeed, including a failed
local prerequisite.
