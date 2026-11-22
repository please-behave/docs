# External Rule Sets

A shared governance repository lets many projects enforce the same Rules.
A project **imports** a Rule Set, or an adapter profile, from a Git repository at a
pinned revision and runs it like its own. This guide describes how to publish and
import them, how Please Behave refreshes and stores them, and how trust protects
you. It covers CLI 0.20.0. Local Rules, Rule Sets and adapter profiles are
described in the [configuration guide](configuration.md); the binding definitions are the
[configuration contracts](https://github.com/please-behave/cli/tree/main/why/contracts/configuration)
in the CLI repository. If this guide and a contract differ, the contract is right.

## A shared repository

An import selects one directory of the repository, which defines exactly one Rule
Set in `ruleset.toml`. The set references Rule directories anywhere inside the
repository, so several sets can share Rules:

```text
governance-rules/
  repository/ruleset.toml
  releasable-software/ruleset.toml
  rules/checks/readme/rule.toml
  rules/checks/readme/index.sh
  rules/checks/changelog/rule.toml
  rules/checks/changelog/index.sh
```

`repository/ruleset.toml`:

```toml
id = "repository"
description = "General repository governance"
run_at = ["pre-push", "check"]
rules = ["rules/checks/readme"]
```

`releasable-software/ruleset.toml`:

```toml
id = "releasable-software"
description = "Release documentation"
run_at = ["pre-push", "release"]
rules = ["rules/checks/readme", "rules/checks/changelog"]
```

`rules/checks/readme/rule.toml`:

```toml
id = "repository-readme"
description = "Require the consumer README"

[check]
command = "sh @rule/index.sh"
```

`rules/checks/readme/index.sh`:

```sh
test -s README.md
```

`rules/checks/changelog/rule.toml`:

```toml
id = "release-changelog"
description = "Require the consumer changelog"

[check]
command = "sh @rule/index.sh"
```

`rules/checks/changelog/index.sh`:

```sh
test -s CHANGELOG.md
```

A Rule Set has the same four fields as a [local one](configuration.md#rule-sets),
with these differences:

- `rules` entries are Rule directories relative to the **repository root**, not
  Rule IDs and not paths relative to the set. Each directory must sit directly
  below a `checks/` or `reviews/` directory and contain a `rule.toml` with its
  resources.
- Only referenced Rules load. Unreferenced Rules and other sets do not affect an
  import, but every referenced definition is validated, disabled Rules included.
- A Rule ID must be unique within one import. Two directories with the same ID
  fail validation.
- Sets cannot reference other sets or your local definitions, and they accept no
  project settings or imports.

A reference can also be a table that replaces the set's `run_at` for one Rule. Its
`id` is the same directory path:

```toml
rules = [
  "rules/checks/readme",
  { id = "rules/checks/changelog", run_at = ["check"] },
]
```

Overrides use the point names of the repository, before any
[mapping](#map-execution-points). They work for checks and reviews alike. A Rule
referenced twice runs once, at the union of the points.

## Import Rule Sets

Declare imports in `.please/config.toml`; no other file may contain them. This
consumer imports both sets above and declares the custom point they use:

```toml
project = "My_App"

[execution_points]
custom = ["release"]

[[imports]]
git = "https://git.example.org/team/governance-rules.git"
path = "repository"
ref = "v1.2.0"

[[imports]]
git = "https://git.example.org/team/governance-rules.git"
path = "releasable-software"
ref = "v1.2.0"
```

| Field | Required / default | Meaning |
| --- | --- | --- |
| `git` | Required | Repository to use: HTTP(S), SSH, SCP-style, Git protocol, file URL or a repository path relative to your project. Git's own authentication applies. |
| `path` | Required | Directory with the set, or `"."` for the repository root. No parent components or symlinks. |
| `ref` | Required | Branch, tag or full commit hash, 1 to 1024 bytes. |
| `execution_points` | Optional; `{}` | Maps custom point names of the imported set to custom points you declared. |
| `rule_parameters` | Optional; `{}` | Parameter values for imported Rules, per Rule ID. |

Before the first `please sync` for a repository, [trust it](#trust-repositories).
Then `please sync` retrieves and validates every import, and `please run` uses the
result offline. Each import executes independently, even when two sets share a
Rule. Remove an import to stop using it.

Keep `ref` pinned to a tag or a full commit hash that works with your CLI version.
A moving branch can bring in Rules that your CLI cannot load. Hosted repositories
use Git's authentication: Please Behave asks for no credentials, rejects credentials
and queries inside URLs, and hides Git's error output. Configure a credential
helper or SSH access in Git instead.

### Map execution points

A set may use custom point names that you do not use. An `[imports.execution_points]`
table belongs to the `[[imports]]` entry directly above it. Its keys are custom
names of the imported set and its values are custom points from your own
`execution_points.custom`:

```toml
[execution_points]
custom = ["verify", "audit"]

[[imports]]
git = "https://git.example.org/team/governance-rules.git"
path = "security"
ref = "v2.1.0"

[imports.execution_points]
scan = "audit"
report = "verify"
```

Built-in points cannot appear on either side. Names that you do not map keep their
name, and you must declare them yourself; otherwise validation fails with
`unknown resulting execution point`. Imports may map the same name differently,
and several source points may map to one target, where a Rule still runs once.
Mapping needs no network and changes neither the files nor the revision.

### Supply parameter values

An imported Rule declares [parameters](configuration.md#rule-parameters) without a
`value`. You supply the values per import, keyed by the Rule's ID:

```toml
[[imports]]
git = "https://git.example.org/team/governance-rules.git"
path = "repository"
ref = "v1.2.0"

[imports.rule_parameters.commit-message]
scopes_file = "frontend/scopes.txt"

[[imports]]
git = "https://git.example.org/team/governance-rules.git"
path = "repository"
ref = "v1.2.0"

[imports.rule_parameters.commit-message]
scopes_file = "backend/scopes.txt"
```

Both imports execute as separate bindings, each with its own values, and plans and
reports keep their Rules apart. There is no global parameter table, and nothing else
about an imported Rule can be overridden. A `file` parameter names an existing file
in your repository.

## Resources of imported Rules

Imported checks follow the [same command syntax](configuration.md#command-syntax) as
local ones, run in your project root and receive the same
[references](configuration.md#rule-inputs). They resolve against the imported
repository like this:

| Reference | Resolves to |
| --- | --- |
| `@rule/<path>` | The directory of the Rule that declares it, even for a script that several Rules share. |
| `@source/<path>` | The root of the imported repository, independent of the selected set directory. |
| `@repo/<path>` | Your repository. |

A shared script can therefore be used as
`command = "python3 @source/scripts/check-files.py"`. Review prompts load from
their own Rule directory, while context paths and evidence refer to your repository.

The imported repository is the boundary for Rule references and shared scripts.
Set directories, Rule references, definitions and prompts may not contain
symlinks, parent traversal or unexpected file types. Resolution never searches
other places and works offline from the cache. Git retrieval disables hooks and
initialization scripts that the repository ships and never initializes submodules.

This confinement concerns **where Rules are read from**, not what they do. Imported
checks run with your permissions, can reach other paths, credentials and the
network, and are not sandboxed. The same holds for imported adapter commands, which
run from your project root with your environment. Review them before you trust a
repository.

## Trust repositories

Every repository that a project imports from, for Rule Sets and adapter profiles
alike, must be trusted by you first. Without trust, `sync`, `run` and `run --plan`
fail before anything is retrieved, loaded or executed. The error names the
repository and the command to run:

```sh
please trust https://git.example.org/team/governance-rules.git
please trust --list
please trust --remove https://git.example.org/team/governance-rules.git
```

Trust covers the whole repository, so another directory, reference or revision of a
trusted repository needs no new decision. It is neither a pin nor a sandbox: keep
pinning the revisions you import and remember that trusted checks run with your
permissions. Trust is checked again offline before every run, so removing it takes
effect immediately.

The decisions live in `please/trust.toml` below `XDG_CONFIG_HOME`, or
`$HOME/.config`, outside every project. No project file, imported content or Git
directory can grant trust, and neither `sync` nor `sync --yes` establishes it. In
CI, run `please trust` in a workflow step before `please sync`; the workflow is then
as strongly protected as the repository that contains it.

A repository is identified by its normalized location only: the scheme and host are
lowercased, default ports, trailing slashes and a `.git` suffix are dropped, and a
local repository is identified by its absolute path. Other aliases, such as an SSH
and an HTTPS location of one repository, are separate and need their own trust.

## Adapter profiles

A review needs an [adapter profile](configuration.md#configure-an-adapter-profile).
You can take profiles over from Git in two ways. In both, profile IDs are global
across your local files and everything you import. A duplicate is an error and
nothing is overridden, with one exception: Rule Sets that ship identical
definitions of one ID, also from different commits, share that profile.

### Profiles shipped with a Rule Set

A set directory may carry complete named profiles in `adapters/<id>.toml` beside its
`ruleset.toml`. They use the fields, defaults and limits of local profiles, and all of
them are validated, including unused ones. A review selects one with
`adapter = "quality"` in its `[review]` table. The profile must sit in the directory
of the set that the review comes from; otherwise `please sync` fails with
`unknown adapter profile`. Reviews without `adapter` keep your default
`.please/adapter.toml`. An adapter-profile-only set may use `rules = []`, but it
still needs `id`, `description` and a nonempty `run_at`.

### Independent profile packages

`[[adapter_imports]]` imports a profile without any Rule Set, so you need neither an
empty set nor an execution point. Rule Sets and profiles may come from different
repositories.

```toml
[[adapter_imports]]
id = "quality"
git = "https://git.example.org/team/governance-adapters.git"
path = "adapters/quality"
ref = "v1.2.0"
```

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | Yes | Profile name that reviews select with `adapter`. |
| `git` | Yes | Repository, with the same forms and trust rules as for Rule Set imports. |
| `path` | Yes | Directory with `adapter.toml` and the adapter's files. |
| `ref` | Yes | Branch, tag or full commit hash. |

The directory contains a normal `adapter.toml`:

```toml
command = "python3"
args = ["@adapter/adapter.py"]
timeout_seconds = 70

[requirements]
executables = ["python3"]
env = ["QUALITY_API_KEY"]
```

No file is copied into your project, so you need no `.please/adapters/quality.toml`.
Only packages imported this way may use references in `command`, `args` and
`requirements.executables`: `@adapter/` is the package directory, `@source/` the root of
its repository and `@repo/` your project root. `@@` writes a literal leading `@`.
Referenced paths must exist and may not contain parent traversal or symlinks, and a
resolved path stays one argument. Arguments of local profiles and profiles shipped
with a set stay literal.

Repeating an ID in two independent imports fails even when the content is identical.
Put no credential values into profile files; `requirements.env` names variables only.
An unavailable or damaged imported profile blocks the run, even for an advisory
review. Authentication and tools of the adapter are checked only when a selected
review reaches its adapter call. Please Behave ships no adapter.

## Refresh, storage and provenance

`please sync` fetches the exact `ref` of each import, resolves it to a commit and
validates all local and imported Rules, profiles and references before it records
anything. Tags resolve to their commit, a full hash must name that exact commit and a
failing `ref` never falls back to another one. A revision that is already available
is reused, and a cached full commit needs no network. A failed refresh keeps the last
valid state. Afterwards runs, hooks and plans use the cache offline.

Two places hold the result:

- The **cache** is shared by all projects and keeps one checkout per repository and
  commit, so imports of the same commit share it, whichever ref selected it. Its
  default is `$HOME/Library/Caches/please` on macOS and `$HOME/.cache/please` on Linux;
  an absolute `XDG_CACHE_HOME` replaces the base directory. Cached revisions are never
  evicted automatically.
- The **resolution state** is `please/external-rule-sets.json` inside the project's
  Git directory, so each worktree has its own. It records, per import, the
  configured ref, the selected directory and the resolved commit, stays out of
  tracked files and snapshots, and drops removed imports on the next sync.

Imported Rules carry their origin in plans and reports: the configured ref and the full
resolved commit, without cache paths. Repeated imports keep distinguishable IDs, and
your own Rules keep theirs. A report is local, unsigned evidence. Its freshness
compares your working tree, so inspect the origin to see which revision of an import
it evaluated. Receipts in the cache detect accidental corruption, not an attacker
who can rewrite the cache and its receipts.

## Recovery and limits

If the resolution state is missing or changed, a cached revision is missing or an
integrity check fails, `please run` stops and asks for `please sync`. For a corrupt
cache entry, remove the cache directory of the affected repository and sync again.
Please Behave never replaces a validated revision silently.

Fetches time out after 60 seconds; local Git operations and waiting for a cache lock
after 30 seconds. Locks serialize writers across projects and end with the process.
Cached repositories may hold up to 8 MiB per file, 128 MiB in total, 100,000
entries and 128 directory levels. The combined configuration allows 256 Rules, 256
Rule Sets and 256 named adapter profiles, and a `ref` is at most 1024 bytes. External
imports are not supported on Windows.
