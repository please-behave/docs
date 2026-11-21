# Cockpit

The cockpit shows the reported attestations held by the [ledger](ledger.md).
See the [cockpit repository](https://github.com/please-behave/cockpit) for the
container image and how to start the service from source.

## Configure GitHub sign-in

Serve the cockpit through an HTTPS reverse proxy. Register a GitHub OAuth app
with a callback at your cockpit's HTTPS origin followed by
`/sign-in/callback`, for example
`https://cockpit.example.org/sign-in/callback`.

| Required setting | Value |
| --- | --- |
| `COCKPIT_LEDGER_URL` | HTTP or HTTPS origin of the ledger, such as `https://ledger.example.org`. |
| `COCKPIT_GITHUB_CLIENT_ID` | GitHub OAuth app client ID. |
| `COCKPIT_GITHUB_CLIENT_SECRET` | GitHub OAuth app client secret. |
| `COCKPIT_GITHUB_CALLBACK_URL` | The HTTPS callback URL registered with GitHub. |
| `COCKPIT_COOKIE_KEY` | 64 random bytes encoded as 128 hex digits. Generate it with `openssl rand -hex 64` and use the same key on every instance. |
| `COCKPIT_GITHUB_ALLOWED_IDS` | Comma-separated positive numeric GitHub user IDs, such as `12345,67890`. |

Set `COCKPIT_BIND_ADDR` if the reverse proxy needs the service to listen on
a different address than the default `127.0.0.1:8080`.

## View the reported evidence

Open `/sign-in` and sign in with an allowed GitHub account. The overview
shows the latest attestation for each repository and execution-point
combination, with errors and failures first. Select a repository link to
see the rule IDs, kinds, and outcomes in that attestation. Sessions expire
after eight hours. **Sign out** clears the session in your browser.

See the [cockpit sign-in requirements](https://github.com/please-behave/cockpit/tree/main/why/requirements)
and the [ledger read contracts](https://github.com/please-behave/ledger/tree/main/why/contracts/read).
