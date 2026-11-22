# Getting started

This page takes you from an empty Git repository to a first saved report. You
need Git and the [Please Behave CLI](https://github.com/please-behave/cli/releases)
0.20.0 or later on your `PATH`. A repository without a commit, as created by
`git init`, is enough.

## First run

From the root of the repository, run:

```sh
please init
please sync --yes
please run
please status
```

- `please init` creates the `.please/` directory with a starter setup: one
  enabled check that passes, one disabled check that fails on purpose and one
  disabled review. It stops with exit code 2 and writes nothing if `.please/`
  already exists. It stages and commits nothing.
- `please sync` validates every file in `.please/`, including disabled Rules,
  and installs the Git hooks that your Rules require. The starter check runs at
  `pre-push`, so `sync` plans a `pre-push` hook. Without `--yes`, it shows the
  planned changes and asks for confirmation in a terminal. It runs no Rule.
- `please run` runs the enabled checks of the `pre-push` execution point and
  saves a numbered report in `.please/reports/`. The starter check passes
  without any adapter.
- `please status` reads the newest saved report without running anything and
  tells you whether it is still `CURRENT` for your working tree. Add `--details`
  for full findings and captured output.

## See a failure

Enable the failing check by setting `enabled = true` in
`.please/checks/deliberately-failing/rule.toml`, then run it again.

```sh
please run
```

The run ends with `FAIL`, names the Rule that prevented success and exits with
code 1. Set `enabled` back to `false` when you are done.

## Next steps

- Write your own checks and reviews, group them into Rule Sets and decide
  where they run in the [configuration guide](configuration.md).
- Learn how to preview, run and read results in [Running rules](running-rules.md).
- Let Git run your Rules for you with [Git hooks](git-hooks.md).
- Share results with your team by [publishing a report](cli.md#publish-a-report).
