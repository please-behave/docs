# Illustrative My_App setup

From a macOS application's Git root, run `please init`, then copy the
`checks/build/` and `reviews/product/` directories into the corresponding
`.please/` directories. Set `project = "My_App"` in `.please/config.toml`.
Customize the Xcode project, scheme, destination and prompt before enabling.
Run `please sync` after editing and `please run` to execute enabled rules.
Both example rules start disabled and remain validated. They run on your machine
with your permissions. The build check requires macOS and Xcode. A review needs an
[adapter profile](../../src/adapters.md).

## Optional attestation delivery

To send evidence for a current report with a commit, add this table to
`.please/config.toml`.

```toml
[publish]
key_env = "PLEASE_GATEWAY_KEY"
```

Set the key through your secret store, then run `please run` and
`please publish --gateway-url https://gateway.example.invalid` as separate
commands. Replace the placeholder with your gateway origin. The command uses
the Git `origin` for repository identity unless you provide an override.
See [Configure publication](../../src/cli.md#configure-publication).
