# Record releases

`please record release` reports a release to the [gateway](gateway.md) as a
fact: a version and the Git commit it was built from. The command runs no
rules, reads no report and creates no release. It also triggers nothing: the
[ledger](ledger.md) stores the fact and the [cockpit](cockpit.md) shows it.
Record a release after your workflow has published it.

Recording needs CLI `v0.24.0` or later.

## Record a release from the CLI

From the Git working-tree root, pass the gateway origin and the version.

```sh
please record release --gateway-url https://gateway.example.org --version 1.4.0
```

- `--version` is an opaque string. It does not have to be a Git tag. The CLI
  sends it exactly as given, including case and whitespace.
- `--commit` names the released commit as a full 40- or 64-digit hexadecimal
  Git object ID. Without it the command uses the commit of `HEAD`. A given
  value need not exist in the local clone.
- `--gateway-url`, the gateway authentication and the repository identity work
  as for `please publish` and `please register`. See
  [Configure publication](cli.md#configure-publication) and
  [Authenticate with GitHub OIDC](cli.md#authenticate-with-github-oidc).

### Outcomes

| Outcome | Message | Exit code |
| --- | --- | --- |
| Recorded | The release was recorded. | 0 |
| Unchanged | The release is already known with the same commit. | 0 |
| Conflict | The version is already recorded with a different commit. | 2 |

A conflict leaves the recorded release as it is. Recording the same version
with another commit does not replace it, so choose a new version for a new
commit. Invalid arguments, an unresolvable `HEAD`, missing configuration or
credentials, a rejection by the gateway and an unreachable gateway also exit
with code 2. The diagnostics distinguish a gateway rejection from a transport
failure and never contain credentials.

See the [release fact contract](https://github.com/please-behave/cli/blob/main/why/contracts/release-facts/record.md)
and the [gateway ingest contract](https://github.com/please-behave/gateway/blob/main/why/contracts/ingest/release-fact.md).

## Record a release from GitHub Actions

Set the `release-version` input of the [action](https://github.com/please-behave/action)
in the workflow that publishes the release. The step runs after the
publication, uses the `gateway-url` input and the authentication of
attestation delivery, and needs no governance run.

```yaml
- uses: please-behave/action@<action-tag>
  with:
    version: v0.24.0
    run: 'false'
    gateway-url: ${{ secrets.PLEASE_GATEWAY_URL }}
    release-version: ${{ github.ref_name }}
```

Replace `<action-tag>` with an action release that has the input. Set
`release-commit` to a full Git object ID to record a commit other than `HEAD`.

The job summary shows whether the release was recorded, unchanged or in
conflict. Without a gateway URL the step does nothing and says so. Any other
failure, including a conflict, is a warning unless `publish-required` is
`'true'`, which fails the step. See the
[action publishing guide](https://github.com/please-behave/action/blob/main/docs/publishing.md#recording-a-release).

## View releases in the cockpit

The **Releases** tab lists every repository with at least one recorded
release: its newest version, when it was recorded and its evidence. Entries
without evidence or with a `FAIL` or `ERROR` outcome come first, then the
rest by repository. Repositories without a release do not appear. A repository
opens the page of its releases, newest first, and a version opens the release
detail page. The detail page shows the version, the full commit, the time the
ledger received the fact and the sender with its authentication method. A
sender that authenticated with an API key is marked as self-asserted, because
the key is not bound to the repository.

### What the evidence of a release means

Evidence for a release is reported evidence. The release fact claims nothing
about verification. The ledger looks for the newest attestation with the
`check` execution point for the same repository and commit, and the cockpit
shows what that attestation reports:

- The overall outcome, with a link to the attestation.
- Each Rule Set bound at `check` as **Complete** or **Incomplete**. An
  incomplete Rule Set names its non-passing rules.
- **No evidence** when no such attestation exists. A release is not wrong
  because of that, but nothing was reported for its commit.

A later attestation for the commit changes the evidence on the next read. The
stored release stays as recorded. Like all evidence, it consists of claims by
the sender; see [Evidence and its limits](overview.md#evidence-and-its-limits).

See the cockpit contracts for the
[releases](https://github.com/please-behave/cockpit/blob/main/why/contracts/browser/latest-releases.md)
and the
[release detail](https://github.com/please-behave/cockpit/blob/main/why/contracts/browser/release-detail.md),
and the ledger's
[commit evidence contract](https://github.com/please-behave/ledger/blob/main/why/contracts/read/commit-evidence.md).
