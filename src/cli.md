# CLI

The CLI checks your repository against the rules in `.please/`. Start with
[Getting started](getting-started.md), write rules in the
[configuration guide](configuration.md), run and read them in
[Running rules](running-rules.md) and let Git run them with
[Git hooks](git-hooks.md). Use `please publish` to share an attestation from a
local verification run with the [gateway](gateway.md). For installation, see
the [CLI releases](https://github.com/please-behave/cli/releases).

## Configure publication

For API-key authentication, set the name of the credential environment
variable in your project's `.please/config.toml`.

```toml
[publish]
key_env = "PLEASE_GATEWAY_KEY"
```

Supply the bearer key issued by the gateway operator in that environment
variable when you publish. Keep the key out of the TOML file and version
control. The CLI derives the repository identity from the host and path of
the network Git remote named `origin`. If you use a local remote or want to
set the identity explicitly, add `repository = "git.example.org/team/project"`
to the same table.

### Authenticate with GitHub OIDC

With a CLI release that supports GitHub OIDC, set the following in
`.please/config.toml`.

```toml
[publish]
auth = "github-oidc"
```

Grant the GitHub Actions job or workflow `id-token: write`. With this
permission, `please publish` and `please register` obtain a token from GitHub
Actions without a stored API key. The gateway operator must allow the
workflow's repository and configure the exact audience. For
`--gateway-url https://gateway.example.org:8443/`, the audience is
`https://gateway.example.org:8443`. The gateway rejects a
`publish.repository` override that differs from the workflow's repository.

## Publish a report

From the Git working-tree root, run your rules and pass the gateway origin
with `--gateway-url`, which is required on every call. Use an HTTP or HTTPS
origin, and HTTPS for a remote gateway. It may have a port and a trailing
slash, but no credentials, query, fragment, or other path. Remove any existing
`gateway_url` entry from `[publish]` when upgrading to CLI 0.20.0.

```sh
please run --at pre-push
please publish --gateway-url https://gateway.example.org
```

The newest saved report must have a saved Git commit and still be
`CURRENT` according to `please status`. A change to the configured
publishing settings requires a fresh run. A current report with a `FAIL` or
`ERROR` verdict is also eligible for delivery.

The gateway receives only the summary described in
[Evidence and its limits](overview.md#evidence-and-its-limits); captured
output, findings and explanations stay local. A successful `please publish`
exit confirms gateway acceptance. The saved
verification verdict stays as recorded by the run. On failure, read the CLI's
diagnostic for credential, rate limit, document, gateway, or connection errors.
The command exits with code 2 and leaves the report untouched. In CI, publish
explicitly after you capture the exit status of the run, also when the run
fails, and decide in your workflow how to treat a delivery failure.

See the [publish configuration contract](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/project.md#publish-settings)
and [report contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/document.md#publishing-evidence).

## How the cockpit verifies rule results

The cockpit shows a result as **verified** when the ledger finds a registration
with the same rule identity, version and digest. The rule identity consists of
the source repository, the directory path within that repository and the rule
ID. The digest identifies the registered rule details. Verification describes
the match independently of the reported outcome, so a failed check can be
verified.

- **Unregistered** means the result carries no version or the ledger has no
  registration for that identity and version. An unversioned rule carries no
  version by definition. Rules defined in your own project need a registration
  from your project's CI. A rule sourced only from a local path or file URL
  lacks a publishable identity.
- **Mismatch** means a registration exists for the identity and version, but
  the reported digest differs.

The ledger retains unverified results and checks them again when read. A later
matching registration can make an earlier result verified without republishing
the report. See [Register rule versions](registering-rules.md).

## Publish from GitHub Actions

For API-key authentication, create GitHub Actions secrets named
`PLEASE_GATEWAY_URL` for the gateway origin and `PLEASE_GATEWAY_KEY` for the
bearer key. Pass the URL secret to
the action's `gateway-url` input and expose the key secret as the environment
variable named by `key_env`. Add this step after checkout in your workflow.

```yaml
- uses: please-behave/action@1032b7de037313d2bf54dc5d2a4a9483107e6f3f # v1.8.0
  with:
    version: v0.21.0
    checks-only: 'true'
    gateway-url: ${{ secrets.PLEASE_GATEWAY_URL }}
  env:
    PLEASE_GATEWAY_KEY: ${{ secrets.PLEASE_GATEWAY_KEY }}
```

The action attempts delivery after a run saves a report, including runs with
a `FAIL` or `ERROR` verdict. Delivery failures generate a warning and a job
summary entry. Set `publish-required: 'true'` to make a delivery failure fail
an otherwise successful action step.

For [GitHub OIDC](#authenticate-with-github-oidc), grant `id-token: write`
and use a CLI version that supports it. After a verification run saves a
current report, run `please publish --gateway-url https://gateway.example.org`
from the checkout root.
