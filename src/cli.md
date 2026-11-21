# CLI

Use `please publish` to share an attestation from a local verification run
with the [gateway](gateway.md). For installation and project setup, see the
[CLI repository](https://github.com/please-behave/cli).

## Configure publication

Add the gateway origin and the name of the credential environment variable
to your project's `.please/config.toml`.

```toml
[publish]
gateway_url = "https://gateway.example.org"
key_env = "PLEASE_GATEWAY_KEY"
```

Supply the bearer key issued by the gateway operator in that environment
variable when you publish. Keep the key out of the TOML file and version
control. The CLI derives the repository identity from the host and path of
the network Git remote named `origin`. If you use a local remote or want to
set the identity explicitly, add `repository = "git.example.org/team/project"`
to the same table.

## Publish a report

From the Git working-tree root, run your rules and then publish.

```sh
please run --at pre-push
please publish
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
