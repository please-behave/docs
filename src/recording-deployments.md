# Record deployments

After your workflow deploys software, use `please record deployment` to report
which version or commit went to a target. A repository such as
`github.com/example/infra` can own the target and report the deployment of
software from `github.com/example/app`. The command only sends a fact.

Declaring targets and recording deployments require CLI v0.25.0 or later.

## Declare and register a target

In the repository that manages the target, add a top-level entry to
`.please/config.toml`. If the file already has `targets = []`, remove that line
when adding your first entry.

```toml
[[targets]]
name = "production"
description = "Production environment"
```

The description is optional. Target names are case-sensitive and unique within
an owner. Start the name with an ASCII letter or digit. You can use letters,
digits, dots, underscores and hyphens after that.

From the owner's checkout root in CI, run the following command with
[publication credentials](cli.md#configure-publication).

```sh
please register --gateway-url https://gateway.example.org
```

The CLI validates target declarations before sending any batches. It sends
targets after any rule and Rule Set batches and reports `created` or
`unchanged` for each target. Both are successful outcomes. Re-registering
the same target keeps its original description. You can register targets on
their own. With GitHub Actions, use the same
[`register: 'true'` input](registering-rules.md#register-from-github-actions)
with CLI v0.25.0 or later.

The gateway assigns ownership using the authenticated sender. With GitHub OIDC,
the owner is the normalized lowercase repository identity. With an API key, it
is the key label. Use the same owner when reporting deployments to the target.
See the CLI's [project configuration contract](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/project.md#deployment-targets),
its [registration contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/registration.md#deployment-targets)
and the [ledger registration contract](https://github.com/please-behave/ledger/blob/main/why/contracts/ingest/target-registration.md).

## Report a deployment from the CLI

From the reporting repository's checkout root, pass the name of a registered
target owned by the authenticated sender and explicitly name the deployed
repository. Use the same [gateway and authentication settings](cli.md#configure-publication)
as for registration.

```sh
please record deployment --gateway-url https://gateway.example.org \
  --target production --repository github.com/example/app --version 1.4.0
```

You can pass a normalized repository identity or a network Git URL. Pass
exactly one of `--version` and `--commit`. A version is sent as supplied and can
be reported before a matching [release](recording-releases.md) is recorded.
Use `--commit` with a full 40- or 64-digit hexadecimal Git object ID to report
a commit directly.

| Outcome | Meaning | Exit code |
| --- | --- | --- |
| Recorded | The ledger accepted a new current deployment for this target and repository. | 0 |
| Unchanged | The current deployment already reports the same version or the same explicit commit. | 0 |
| Unknown target | The target name is unregistered for this authenticated sender. | 2 |

Reporting an earlier version or commit again after a different deployment
records a new event. Invalid arguments, missing credentials or configuration,
gateway rejection and delivery failures also exit with code 2. See the
[CLI deployment command contract](https://github.com/please-behave/cli/blob/main/why/contracts/release-facts/deployment.md)
and the [gateway deployment ingest contract](https://github.com/please-behave/gateway/blob/main/why/contracts/ingest/deployment-fact.md).

## Report a deployment from GitHub Actions

Add a step after the job deploys the software. The deployment inputs are
available in Please Behave Action v1.10.0 and use the same
[authentication as attestation delivery](cli.md#publish-from-github-actions).
A step with `run: 'false'` can report a deployment on its own.

```yaml
- uses: please-behave/action@<action-commit-sha>
  with:
    version: v0.25.0
    run: 'false'
    gateway-url: ${{ secrets.PLEASE_GATEWAY_URL }}
    deployment-target: production
    deployment-repository: github.com/example/app
    deployment-version: '1.4.0'
```

Replace the Action reference with the full commit SHA of the release you use.
Supply the version your workflow deployed, or replace `deployment-version`
with `deployment-commit` and pass the full Git object ID.

With valid inputs, a missing gateway URL skips delivery and adds a notice to
the job summary. The summary reports recorded, unchanged or unknown target
even with `summary: 'false'`. Delivery failures, including unknown targets,
produce a warning by default. Set `publish-required: 'true'` to fail the step
on a delivery failure. Missing required deployment inputs or supplying both a
version and a commit fails the step regardless of that setting. See the
[Action publishing guide](https://github.com/please-behave/action/blob/main/docs/publishing.md#recording-a-deployment).

## View deployments in the cockpit

The **Deployments** tab shows the latest deployment the ledger received for
each target owner, target name and deployed repository. Each row shows when
the ledger received the report and what version or commit it names. Recorded
versions link to the release detail. Commit-only reports show the short commit
ID with the full ID available in a tooltip.

The tab groups by target by default. Switch to grouping by repository or
combine filters for target, repository and evidence status. Group headings
show the worst visible status and its count. Entries that need attention
appear first.

Select a repository name to open its repository page. Its **Deployments**
section shows current deployments of that repository across targets alongside
its **Releases** and **Attestations** sections. See the
[cockpit deployments contract](https://github.com/please-behave/cockpit/blob/main/why/contracts/browser/deployments.md)
and the [repository page requirement](https://github.com/please-behave/cockpit/blob/main/why/requirements/REQ-0033.yaml).

### What the evidence states mean

| State | Meaning |
| --- | --- |
| Reported outcome | The ledger found an attestation for the deployed repository and commit that includes the `check` execution point. The view shows the newest qualifying attestation's overall result and links to completed Rule Sets. |
| No evidence | The commit is known, but there is no attestation for it that includes the `check` execution point in that repository. |
| Release not recorded | The reported version has no matching release fact yet, so the ledger cannot resolve it to a commit. |

An attestation or matching release recorded later can change the evidence on
the next read. A deployment is reported evidence from the sender. Its receipt
time tells you when the ledger received the report. See
[Evidence and its limits](overview.md#evidence-and-its-limits) and the
[ledger deployments contract](https://github.com/please-behave/ledger/blob/main/why/contracts/read/deployments.md).
