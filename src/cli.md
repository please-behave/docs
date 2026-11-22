# CLI

Use `please publish` to share an attestation from a local verification run
with the [gateway](gateway.md). For installation and project setup, see the
[CLI repository](https://github.com/please-behave/cli).

## Configure publication

Set the name of the credential environment variable in your project's
`.please/config.toml`.

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

## Publish a report

From the Git working-tree root, run your rules and pass the gateway origin
with `--gateway-url`. Use an HTTP or HTTPS origin without credentials, a
query, a fragment, or a path other than `/`. Remove any existing
`gateway_url` entry from `[publish]` when upgrading to CLI 0.20.0.

```sh
please run --at pre-push
please publish --gateway-url https://gateway.example.org
```

The newest saved report must have a saved Git commit and still be
`CURRENT` according to `please status`. A change to the configured
publishing settings requires a fresh run. A current report with a `FAIL` or
`ERROR` verdict is also eligible for delivery.

A successful `please publish` exit confirms gateway acceptance. The saved
verification verdict stays as recorded by the run. On failure, read the CLI's
diagnostic for credential, rate limit, document, gateway, or connection errors.

See the [publish configuration contract](https://github.com/please-behave/cli/blob/main/why/contracts/configuration/project.md#publish-settings)
and [report contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/document.md#publishing-evidence).

## Publish from GitHub Actions

Create GitHub Actions secrets named `PLEASE_GATEWAY_URL` for the gateway
origin and `PLEASE_GATEWAY_KEY` for the bearer key. Pass the URL secret to
the action's `gateway-url` input and expose the key secret as the environment
variable named by `key_env`. Add this step after checkout in your workflow.

```yaml
- uses: please-behave/action@10dc79d3d884b81aae9baaf0a94242606419646e # publishing support
  with:
    version: v0.20.0
    checks-only: 'true'
    gateway-url: ${{ secrets.PLEASE_GATEWAY_URL }}
  env:
    PLEASE_GATEWAY_KEY: ${{ secrets.PLEASE_GATEWAY_KEY }}
```

The action attempts delivery after a run saves a report, including runs with
a `FAIL` or `ERROR` verdict. Delivery failures generate a warning and a job
summary entry. Set `publish-required: 'true'` to make a delivery failure fail
an otherwise successful action step.
