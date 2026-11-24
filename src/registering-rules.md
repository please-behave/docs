# Register rule versions

Register rule versions in CI from the Git repository that owns the rules.
Registration records the commit as provenance and gives the cockpit a reference
for [verifying published results](cli.md#how-the-cockpit-verifies-rule-results).
Keeping registration in the owner's CI ties the record to a traceable checkout
of the committed definitions. Make it a deliberate workflow step. Neither
`please run` nor Git hooks trigger registration.

## Prepare the repository

Use CLI v0.21.0 or later and set up the [publication credentials](cli.md#configure-publication).
Set an [owner-assigned version](configuration.md#rule-version) in every
`rule.toml` and commit a [rule knowledge document](https://github.com/please-behave/cli/tree/main/why/contracts/rule-knowledge)
named `rule.yaml` beside it. Commit the review prompts as well.

Registration covers every rule directory in the repository, including
disabled rules and directories outside `.please/`. Imported rules are
registered by the repositories that own their definitions. A missing version,
missing knowledge file or changes within a rule directory cause the command
to fail before sending the batch.

## Run registration in CI

From the checkout root, pass the gateway origin on each invocation. For
API-key authentication, have CI inject the bearer key into the environment
variable named by `[publish].key_env`. For
[GitHub OIDC](cli.md#authenticate-with-github-oidc), set `publish.auth` to
`"github-oidc"` and grant the workflow or job `id-token: write`.
Registration uses the repository identity derived from the network Git
`origin`, or the override in `[publish].repository`. With GitHub OIDC, that
identity is lowercased in full and must match the workflow's repository.

```sh
please register --gateway-url https://gateway.example.org
```

The command reports an outcome for each rule. `created` records a new
version and `unchanged` confirms the same details were already registered.
A `conflict` means the rule identity and version already exist with different
registered details. The original registration stays in place. Assign a new
version for the change, commit it and rerun CI. A conflict fails the command.

The digest covers the rule identity, version, kind, declared name, description
and full parsed knowledge document. For reviews it also covers the effective
`blocking` value and the prompt. See the
[CLI registration contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/registration.md)
for the complete input and failure behavior.

## Register from GitHub Actions

For API-key authentication, use [Please Behave Action](https://github.com/please-behave/action/blob/main/docs/publishing.md#registering-rule-versions) v1.8.0 or
later. Replace `main` with your default branch and the Action reference
placeholder with your chosen release's full commit SHA. Set the gateway origin
and bearer key as repository secrets. This example assumes
`key_env = "PLEASE_GATEWAY_KEY"`.

```yaml
name: Verify and register rules
on:
  push:
    branches: [main]
permissions:
  contents: read

jobs:
  register:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          persist-credentials: false
      - uses: please-behave/action@<action-commit-sha>
        with:
          version: v0.21.0
          checks-only: 'true'
          gateway-url: ${{ secrets.PLEASE_GATEWAY_URL }}
          register: 'true'
        env:
          PLEASE_GATEWAY_KEY: ${{ secrets.PLEASE_GATEWAY_KEY }}
```

The Action registers only after the governance run succeeds and shows per-rule
outcomes in the Job Summary. Any registration failure fails the step.
[Attestation delivery](cli.md#publish-from-github-actions) follows its own
failure policy.
