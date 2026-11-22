# Configuration

Please Behave reads everything it enforces from the `.please/` directory at the
root of your Git working tree. This guide describes the files in it and how to
write them. It covers CLI 0.20.0. The binding definitions are the
[configuration contracts](https://github.com/please-behave/cli/tree/main/why/contracts/configuration)
in the CLI repository; if this guide and a contract differ, the contract is right.

Three concepts structure the configuration:

- A **Rule** states one expectation. It is either a **check**, a command whose
  exit status is the verdict, or a **review**, a prompt that an AI adapter
  evaluates.
- A **Rule Set** groups Rules and assigns them to **execution points**.
- An **execution point** is a moment at which Rules run: the Git hooks
  `pre-commit`, `commit-msg` and `pre-push`, the point `check` and any custom
  point you declare. `check` and custom points run only when you ask for them, for
  example in CI. They need no Git hook.

The commands you use are `please init` to create `.please/`, `please sync` to
validate it, `please run` to execute Rules and `please status` to inspect saved
results. `please help` lists all commands and options.

## Files and validation

Configuration has a fixed layout:

```text
.please/
  config.toml                 project settings and imports (required)
  adapter.toml                default adapter profile
  adapters/quality.toml       named adapter profile
  checks/readme/
    rule.toml                 one check per directory
    index.sh                  supporting files sit beside the Rule
  reviews/architecture/
    rule.toml                 one review per directory
    prompt.md
  rule-sets/repository.toml   one Rule Set per file
  reports/1.json              saved results, written by `please run`
```

Start with `config.toml` and add the other documents as you need them.
`please init` creates a starter setup: one passing check, one disabled failing
check, one disabled review and a `reports/.gitignore`. It requires that `.please/`
does not exist yet and installs no hooks.

Run `please sync` after every edit. It validates all documents, including disabled
Rules, and executes no check or adapter. It also installs or removes the Git hooks
that your Rule assignments require, after asking for confirmation; pass `--yes`
to skip the question. The
[discovery contract](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/discovery.md)
defines the recognized locations, size limits and safe paths. Documents are UTF-8
TOML, unknown fields are rejected and symlinks inside `.please/` are not followed.
The files have no version field.

## Project settings

`.please/config.toml` is the only required file. `please init` writes all
settings with their defaults; every table and field except `project` is optional.

```toml
project = "My_App"
max_display_files = 5

[execution]
max_parallel = 4
fail_fast_terminate_running_instances = false
fail_fast_termination_grace_seconds = 5

[context]
retain_runs = 10
max_section_bytes = 10485760

[report]
retain_runs = 10

[execution_points]
custom = ["release"]
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `project` | Required | Display label shown in plans and reports. |
| `max_display_files` | `5` | Changed paths that `please status` lists, 1 to 5. |
| `execution.max_parallel` | `4` | Checks that run at the same time. Use `1` for serial execution. `--max-parallel` overrides it for one run. |
| `execution.fail_fast_terminate_running_instances` | `false` | With `run --fail-fast`, stop checks that are still running instead of letting them finish. |
| `execution.fail_fast_termination_grace_seconds` | `5` | Seconds a stopped check gets to exit before it is killed, 1 to 3600. |
| `context.retain_runs` | `10` | Earlier [run contexts](#run-context) kept, 1 to 10000. |
| `context.max_section_bytes` | `10485760` | Size limit for each part of a run context, 1024 to 1073741824. |
| `report.retain_runs` | `10` | Saved [reports](#reports) kept, 1 to 10000. |
| `execution_points.custom` | `[]` | Names of additional execution points. Built-in names are reserved. |

Enable `fail_fast_terminate_running_instances` only if your checks can be
interrupted without leaving their work in a bad state. It has an effect only with
`--fail-fast`; fail-fast itself has no setting. Interrupted checks end as
`CANCELLED` with their partial output. After a cancellation, clean up
interrupted builds before you run again. Termination needs process-group support,
so the CLI rejects the setting on platforms without it. The
[project configuration contract](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/project.md)
explains each setting in detail, and its
[schema](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/project.schema.json)
holds the exact defaults and bounds.

A run without `--at` selects `pre-push`. Custom names such as `release` have no
special behavior; you run them with `please run --at release`.

## Rules

Each Rule lives in its own directory below `checks/` or `reviews/` and is defined
by a `rule.toml`. The directory kind must match the implementation: a `[check]` table
in `checks/`, a `[review]` table in `reviews/`.

| Field | Required / default | Meaning |
| --- | --- | --- |
| `id` | Required | Unique technical identity, independent of the directory name. Checks and reviews share one ID space. |
| `version` | Optional | Owner-assigned [rule version](#rule-version). Required for registration. |
| `name` | Optional | Display label. Defaults to the ID. |
| `description` | Required | What the Rule expects. |
| `enabled` | Optional; `true` | Disabled Rules are validated and shown in plans but never run. |
| `run_at` | Optional | Execution points at which the Rule runs. Ignored when a Rule Set references the Rule. |
| `blocking` | Reviews only; `true` | Whether a failing review blocks success. Checks always block and must not declare it. |
| `depends_on` | Checks only; none | Exact IDs of checks that must pass first. |
| `parameters` | Optional | Declared [inputs](#rule-parameters). |

An enabled Rule needs an execution point, either its own `run_at` or one from a
Rule Set. The [Rule definition contract](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/rule.md)
and its [schema](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/rule.schema.json)
define these fields in full.

### Rule version

Set `version = "1.0"` in `rule.toml` to record the rule owner's version.
Use a quoted TOML string of at most 64 characters in the form `A.B`. Each
component is a non-negative integer written with ASCII digits and no leading
zeros, except for zero itself. Versions compare numerically by A, then by B,
so `"1.10"` follows `"1.2"`.

Change A for a fundamental change to the rule and B for any other change.
A version communicates the owner's judgment about the change. Execution can
still vary with the rule's inputs, environment and tools.

You can leave checks and reviews unversioned, including imported rules. To
[register a rule version](registering-rules.md), declare a version and put a
`rule.yaml` knowledge document beside its `rule.toml`.

### Add a check

Create `.please/checks/readme/rule.toml`:

```toml
id = "repository-readme"
description = "Require a nonempty README"
run_at = ["pre-push", "check"]

[check]
command = "sh @rule/index.sh"
```

Create `.please/checks/readme/index.sh`:

```sh
#!/bin/sh
test -s README.md
```

| Field | Required / default | Meaning |
| --- | --- | --- |
| `check.command` | Required | One string with the executable and its arguments. |
| `check.timeout_seconds` | Optional; `30` | Deadline in seconds, 1 to 3600, including output capture. |
| `check.resource` | Optional | Name of a resource the check uses exclusively; see [shared resources](#shared-resources). |

The first word is an executable found through `PATH`, or a path. Relative paths
start at the project root. A script that you run directly needs execute permission,
while `sh script.sh` does not. Please Behave does not install tools or runtimes:

```toml
[check]
command = "cargo +stable test --locked"
timeout_seconds = 600
```

Checks receive no standard input and run in the project root with the permissions
of the user who runs `please`. Resource names are the only confinement; there is no
sandbox, so import checks only from [repositories you trust](external-rule-sets.md#trust-repositories).

#### Command syntax

A command is split into arguments by Please Behave. **No shell is involved**, so
pipelines, redirection, variable expansion, command chaining, comments and
globbing do not exist, and `*` and `~` are literal.

- Spaces and tabs separate arguments. Single or double quotes group text and
  are removed; adjacent segments join, so `pre"two words"post` is one argument.
  `''` or `""` gives an empty argument.
- A backslash escapes the next character, except inside single quotes.
- Unquoted `|`, `&`, `;`, `<`, `>`, `(`, `)` and `#`, and an unescaped `$` or
  backtick outside single quotes, are rejected. Quote or escape them when they are
  data. Unclosed quotes and a trailing backslash are rejected too.

To run shell syntax, call a shell explicitly, for example `command = "sh script.sh"`.
The grammar applies after TOML decoding. TOML literal strings avoid a second
layer of escaping:

```toml
[check]
command = '"tools/my checker" "path with spaces" "" path\ with\ spaces'
```

This starts `tools/my checker` with three arguments: `path with spaces`, an empty
string and `path with spaces`.

#### Rule inputs

A command can refer to files and values through references. They are resolved after
the command is split, in any position, and only when they make up a whole word:

| Reference | Resolves to |
| --- | --- |
| `@rule/<path>` | A path inside the directory of this Rule's `rule.toml`. |
| `@repo/<path>` | A path inside your repository. |
| `@source/<path>` | A path inside the source root: your repository for local Rules, or the checkout of the imported repository for imported ones. |
| `@param/<name>` | The value of a declared [parameter](#rule-parameters). A `file` parameter becomes an absolute path. |
| `@context` | The absolute path of the [run context](#run-context) file. |

```toml
[check]
command = "python3 @rule/check.py @context @param/scopes_file @repo/pyproject.toml"
```

`--file=@repo/data` stays literal because the reference is not the whole word.
Quote a word that contains spaces, such as `"@rule/my script.py"`; its resolved path
stays one argument. A leading `@` is reserved: write `@@` for a literal one.
Suffixes must be relative paths without `.`, `..`, backslashes or colons. When
the Rule runs, the referenced path must exist and must not be or contain a symlink;
otherwise the Rule ends as `ERROR`. Offline plans only check the syntax.

Please Behave removes every `PLEASE_*` variable from the environment before it
starts a check or adapter and sets none for them. If your script needs a value for a
subprocess, pass it explicitly.

#### Exit status

Exit status **0** is `PASS`, **1** is `FAIL` and every other status is `ERROR`.
`FAIL` is a verdict about the checked subject. A technical problem of the script
itself should exit with another status, conventionally 2. Interpreters exit with 1
on an uncaught exception, which reads as `FAIL`, so catch errors in your entry
point and exit with 2. Wrap external tools in the same way: map their
violation exit code to 1 and their own failures to 2.

Signals, a command that cannot start, output capture failures and timeouts are
`ERROR` as well. A failing or erroring check blocks success and prevents reviews.

### Shared resources

Checks that share mutable state, such as a build directory, declare the same
`resource`:

```toml
[check]
command = "cargo test --locked"
resource = "cargo"
```

Resource names are case-sensitive and have no meaning to Please Behave. Checks with
the same resource never run at the same time within one run, local and imported
checks alike. A check that waits for a resource occupies no execution slot.
Resources do not coordinate separate `please` invocations. Checks that depend on
serial execution need a resource or `max_parallel = 1`.

### Dependencies

A check can require other checks to pass first:

```toml
id = "smoke"
description = "Smoke test after a successful build"
run_at = ["check"]
depends_on = ["build"]

[check]
command = "./scripts/smoke.sh"
```

Dependencies never select extra Rules: the `build` check must be enabled and
selected at the same execution point, otherwise validation fails with an error. Use
exact IDs. Missing, self-referencing and cyclic dependencies fail before anything
runs. Reviews cannot declare `depends_on` or act as prerequisites.

Only `PASS` satisfies a prerequisite. If it fails, errors or does not run, the
dependent check ends as `NOT_RUN`, and so does anything that depends on that one.
Other checks continue. Checks that wait for a prerequisite occupy no execution slot.

Checks finish before reviews start. If any check fails, errors or is
incomplete, reviews end as `NOT_RUN`.

### Result statuses

| Status | Meaning | Effect on success |
| --- | --- | --- |
| `PASS` | The Rule ran and its expectation holds. | None. |
| `FAIL` | The Rule ran and found a violation. | Blocks for a check; for a review only if it is blocking. |
| `ERROR` | The Rule could not produce a trustworthy result: crash, missing tool, timeout, invalid adapter response. | Blocks for a check; for a review only if it is blocking. |
| `NOT_RUN` | The Rule was selected but not executed because of a failed prerequisite, fail-fast or a failed check phase. | Follows the failure that caused it. |
| `CANCELLED` | A running check was stopped by fail-fast termination. | Blocks. |

### Rule parameters

Checks and reviews can declare named inputs in their `rule.toml`:

```toml
id = "commit-message"
description = "Validate Conventional Commits"
run_at = ["commit-msg"]

[check]
command = "sh @rule/index.sh @param/scopes_file"

[parameters.scopes_file]
type = "file"
required = true
description = "Allowed commit scopes"
value = ".commit-scopes"
```

A `string` parameter is passed unchanged. A `file` parameter names an existing regular
file relative to the repository root and becomes its absolute path. A parameter
without a `value` stays absent; there is no default. A Rule that is imported must
leave `value` out, and the consuming project
[supplies it per import](external-rule-sets.md#supply-parameter-values). Values are resolved just
before the Rule runs. A missing required value, or a value that does not
fit, makes that Rule end as `ERROR`; for a review it is a configuration error that
blocks even when the review is not blocking. The
[Rule Parameters contract](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/parameters.md)
defines the details. Parameters are not the adapter `parameters` described below.

## Reviews

A review asks an AI adapter to assess your project against a prompt. Reviews run
after all checks, one adapter call per review.

### Configure an adapter profile

Please Behave talks to AI providers only through adapters, which are external
programs that speak a versioned JSON protocol. It ships no adapter and chooses none.
Install or write one, then describe how to start it in
`.please/adapter.toml`, the project default, or in a named profile such as
`.please/adapters/quality.toml`:

```toml
command = "python3"
args = ["tools/review-adapter.py"]
timeout_seconds = 180

[requirements]
executables = ["python3"]
env = ["QUALITY_API_KEY"]

[parameters]
model = "example-model"
```

| Field | Required / default | Meaning |
| --- | --- | --- |
| `command` | Required | Executable name or path. |
| `args` | Optional; `[]` | Arguments, passed literally. |
| `timeout_seconds` | Required | Seconds per call, 1 to 3600; `0` disables the deadline. |
| `requirements.env` | Optional; `[]` | Names of environment variables that must be set and nonempty. Never put values here. |
| `requirements.executables` | Optional; `[]` | Executables that must be available. |
| `parameters` | Optional; `{}` | Settings for the adapter. Please Behave passes them on without interpreting them. |

There is no shell, interpolation or argument expansion. The adapter runs in the
project root and inherits your environment except `PLEASE_*` variables. It receives
the execution point, the Rule parameters and the run-context path in its request.
Authentication and tool permissions are configured in the adapter. Treat adapters
like checks: they run with your permissions, and Please Behave neither installs
their dependencies nor sandboxes them. Protecting your project from what an adapter
does is the job of the adapter and its AI provider.

A named profile uses its filename stem as its ID: 1 to 80 ASCII letters, digits,
hyphens or underscores, not starting with `please-`. A review selects it with
`adapter = "quality"` in its `[review]` table; without that it uses
`.please/adapter.toml`. A selected, enabled review that finds neither is blocked.
Unknown profile names fail even for disabled reviews.

A review can override profile settings in `[review.parameters]`. Matching keys win,
and nested tables and arrays are replaced as a whole. Requirements are checked
only for selected reviews, right before the call. A missing requirement, nonzero
exit, timeout or invalid response makes the review `ERROR`.

The [adapter guide](adapters.md) explains the protocol, links its contracts and
provides a dummy adapter. The dummy performs no assessment and always ends as
`ERROR`, so do not use it as a working adapter.

### Add a review

Create `.please/reviews/architecture/rule.toml`:

```toml
id = "architecture-review"
description = "Review architectural consistency"
blocking = false
run_at = ["pre-push"]

[review]
prompt = "prompt.md"
```

Create `.please/reviews/architecture/prompt.md`:

```markdown
Compare the implementation with the project's documented architectural boundaries.
Report concrete contradictions and missing essential evidence as FAIL,
and PASS only with supporting file paths and line numbers.
```

The prompt contains instructions only, with no frontmatter. It must be a Markdown
file directly inside the review directory.

| Field | Required / default | Meaning |
| --- | --- | --- |
| `review.prompt` | Required | Name of a nonblank UTF-8 `.md` file in the review directory. |
| `review.adapter` | Optional | Named adapter profile; see above. |
| `review.parameters` | Optional; `{}` | Adapter settings that override the profile's. |
| `review.trigger.changed_files` | Optional | 1 to 64 patterns. The review runs only if a changed file matches, and those files are its scope. |
| `review.include_content` | Optional; `true` | Send the current content of the files in scope. Content above 256 KiB ends the review as `ERROR` before the call. |
| `review.include_change_set` | Optional; `false` | Send the change set of the files in scope. Above 32 KiB it ends as `ERROR` before the call. |
| `review.context` | Optional; `[]` | Up to 32 documents, as `[[review.context]]` tables with `path` and optional `headings`. |

The adapter's exit status is the verdict: 0 is `PASS` and 1 is `FAIL`, each only
with a valid response. Any other status, malformed output or evidence that does
not exist is `ERROR`. Findings must cite existing files and positive line numbers.
`FAIL` and `ERROR` of a review that is not blocking stay visible but do not stop success;
configuration errors and damaged imports always do.

### Run a review only for relevant changes

```toml
[review.trigger]
changed_files = ["src/**", "why/decisions/**", ".please/reviews/architecture/prompt.md"]
```

Patterns match repository-relative paths, case-sensitively with `/` as separator.
`*` matches within one path component, `?` one character and a whole component
`**` any number of directories. Absolute paths, `.` and `..` components,
backslashes, brackets, braces and embedded `**` such as `src/**.rs` are invalid.
Exact paths need not exist, so deleted files can trigger a review. A trigger selects
the review and limits its scope; it does not add context documents. A review can
cover at most 200 files. Without a trigger, any change selects the review and all
changed files are in scope. A review that is not selected appears in plans as omitted,
with the reason `trigger_not_matched` or `no_changes`, and needs no adapter.

What counts as changed depends on the execution point:

| Execution point | Changed files and change set |
| --- | --- |
| `pre-commit`, `commit-msg` | The staged changes. |
| `pre-push` | The pushed commits. Without Git's reference list, as in a direct run, the commits of `HEAD` that no remote-tracking reference of the upstream remote, else `origin`, else any remote contains. |
| `check` and custom points | The net changes from the commit in `PLEASE_CHANGE_BASE` to the working tree. |

A rename counts as a deletion and an addition. Content is read from the working
files, so a partly staged file shows its working state. An unmerged path blocks the plan.

At `check` and custom points, reviews need `PLEASE_CHANGE_BASE`, set to a
locally available commit or reference. Without it the plan is blocked:

```sh
PLEASE_CHANGE_BASE=main please run --at check --plan --json
PLEASE_CHANGE_BASE=main please run --at check
```

Please Behave resolves the reference once and compares that commit with your working
files, including staged, unstaged and untracked files; changes that you reverted to
the baseline select nothing. Locally, choose the commit to start from, or `HEAD` if
only uncommitted changes matter. In CI, fetch the baseline you want and pass its
commit; for a multi-commit pull request, compute the merge base yourself.
Please Behave never assumes `HEAD^` and does not fetch. Shallow clones work if the
commit and its tree are available. Missing or invalid baselines, sparse
checkouts and skip-worktree flags block the run with an error instead of
skipping the review silently.

### Review commit messages

At `commit-msg`, the whole commit message is part of each review's input, with line
numbers, and your prompt decides which part counts. To review only the summary line:

```toml
id = "commit-wording"
description = "Require a specific English imperative commit summary"
run_at = ["commit-msg"]

[review]
adapter = "commit-quality"
prompt = "prompt.md"
include_content = false
```

A review at `commit-msg` cannot run through `please run --at commit-msg` directly, because
no message file is supplied. `please sync` installs the hook, and Git supplies the
message when you commit or amend. A finding with `path = null` and a `line` cites a
line of the message. Changing the message during the run invalidates the result.

### Add context documents

```toml
[[review.context]]
path = "why/architecture.md"
headings = ["Boundaries"]
```

`headings` lists the exact text of ATX headings without the leading `#` marks.
A selection includes the subsections of a heading and keeps the original lines.
Headings inside code blocks are ignored; missing or ambiguous headings are errors.
Overlapping selections merge. Context is limited to 32 distinct files, 1 MiB per
file and 64 KiB of selected text. Paths must stay inside the repository.

## Rule Sets

A Rule Set assigns Rules to execution points. Create `.please/rule-sets/repository.toml`:

```toml
id = "repository"
description = "General repository governance"
run_at = ["pre-push", "check"]
rules = [
  "repository-readme",
  { id = "architecture-review", run_at = ["check"] },
]
```

| Field | Required / default | Meaning |
| --- | --- | --- |
| `id` | Required | Unique set ID: 1 to 80 lowercase ASCII letters, digits, `-` or `_`, starting with a letter or digit. Independent of Rule IDs. |
| `description` | Required | What the set is for. |
| `run_at` | Required | Execution points of the set. |
| `rules` | Required | Rule references, empty allowed. Local sets use Rule IDs; sets of an [import](external-rule-sets.md#import-rule-sets) use Rule directories. |

A reference is a string or a table with `id` and an optional `run_at` that
replaces the set's list for this reference, as `architecture-review` does above.
Lists are never merged. Unknown or duplicate points and empty overrides are errors,
even for disabled Rules.

A present set always applies; to stop using it, remove it. Once a Rule is
referenced by a set, the set decides where it runs and the Rule's own `run_at` is
ignored, which `please sync` points out. A Rule in several sets runs at the union
of their points, and at most once per point. A set cannot enable, disable or
change the enforcement of a Rule. Standalone enabled Rules use their own `run_at`.

Run a point with `please run --at <point>`. Use `--plan --json` to see what would run
without running it:

```sh
please sync
please run --at pre-commit
please run --at commit-msg
please run --at pre-push
please run --at check
please run --at release --plan --json
```

An execution point without Rules succeeds. `--checks-only` runs only deterministic
checks and reports selected reviews as `NOT_RUN` without calling an adapter. A plan
needs no adapter and changes no hooks.

## Imports

A project can take over Rule Sets and adapter profiles from other Git repositories
with `[[imports]]` and `[[adapter_imports]]` in `.please/config.toml`. Imports are
allowed there only. [External Rule Sets](external-rule-sets.md) describes how to
declare them, trust their repositories and refresh them.

## Run context

Each run gives Git facts to checks through the `@context` argument and to adapters as
`context_file` in the request. Use the path that is supplied, and treat the file and
its patch files as read-only. Check the truncation indicators in it before relying
on complete evidence; otherwise get missing facts from Git or fail the Rule.

At the start of each run, `context.retain_runs` keeps that many earlier contexts
in addition to the current one, whether or not those runs finished. With
`retain_runs = 3`, three earlier contexts and the current one remain.

The [Run Context contract](https://github.com/please-behave/cli/tree/main/why/contracts/run-context)
defines the [document](https://github.com/please-behave/cli/blob/main/why/contracts/run-context/document.md)
and its [delivery and lifetime](https://github.com/please-behave/cli/blob/main/why/contracts/run-context/delivery.md).
At `pre-push`, Git passes the reference list on standard input. Commands you put
after the managed section of a composed hook do not receive it.

## Publish settings

To send attestations to a [gateway](gateway.md), add the optional `[publish]` table
to `.please/config.toml`:

```toml
[publish]
key_env = "PLEASE_GATEWAY_KEY"
# repository = "git.example.org/team/project"
```

`key_env` names the environment variable that holds the key; keep the value out of
the file. `repository` sets the repository identity explicitly. Without it, the
identity is derived from the `origin` remote, so `git@git.example.org:team/project.git`
becomes `git.example.org/team/project`. Set it if you have no network `origin`.
The gateway address is given with `--gateway-url` and has no setting. Run again after
you change these fields so that the report reflects the current files. The
[CLI chapter](cli.md#configure-publication) describes publishing.

## Reports

Each run saves a numbered report as `.please/reports/<number>.json` and prints its
number. `report.retain_runs` keeps the newest reports, counting the one just saved.
Older ones are removed and numbering continues, so after run 25 with
`retain_runs = 10` reports 16 to 25 remain. This is independent of
`context.retain_runs`.

- `please status` shows the newest report and whether your files still match what it
  evaluated.
- `please status --report 17` shows a retained earlier report. A number that is not
  saved exits with status 3.
- `please status --details` adds results, findings and captured output.

A report identifies the evaluated working files, including declared governance
inputs even when they are ignored by Git. Files that cannot be covered completely
prevent `PASS`. Please Behave does not infer what your scripts read: declare the
inputs your Rules rely on. Keep raw reports local, because captured output is not
redacted and can contain secrets. The `.gitignore` in `reports/` keeps them out of Git.

The [Report contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/document.md)
defines the document, and the
[Snapshot and Freshness contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/snapshot.md)
defines coverage and exclusions.
