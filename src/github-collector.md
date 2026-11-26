# GitHub collector

The collector periodically inventories the GitHub repositories you configure
and samples their default-branch heads. The ledger uses the inventory to show
repositories that have never sent an attestation and the sampled heads to tell
whether check evidence has arrived for the observed commit. Archived
repositories stay in the inventory with their archive flag. The collector
skips their heads, and the [dashboard](cockpit.md#read-the-repository-dashboard)
hides them.

Run the [collector image](https://github.com/please-behave/github-collector/releases)
with outbound access to `api.github.com` and access to the ledger on the internal
network. It sends completed syncs directly to the ledger on that network.
The gateway never handles collector traffic. See the
[ledger platform-sync contract](https://github.com/please-behave/ledger/blob/main/why/contracts/ingest/platform-sync.md).

## Configure the collector

| Environment variable | Value |
| --- | --- |
| `GITHUB_COLLECTOR_SCOPES` | Comma-separated repository scopes. Use `owner/*` for all visible repositories of an owner and `owner/name` for an individual repository. You can mix scopes, such as `example-team/*,example-user/sample-app`. Names are case-insensitive. |
| `GITHUB_COLLECTOR_INTERVAL_SECONDS` | Positive polling interval in whole seconds. Defaults to `300` (five minutes). |
| `GITHUB_COLLECTOR_LEDGER_URL` | Internal HTTP or HTTPS origin, such as `http://ledger:8080`. An optional trailing slash is allowed. Omit credentials, paths, queries, and fragments. |
| `GITHUB_COLLECTOR_TOKEN_<OWNER>` | Read-only GitHub credential for every scope of one owner. Uppercase the owner and replace hyphens with underscores. For example, `example-team` uses `GITHUB_COLLECTOR_TOKEN_EXAMPLE_TEAM`. |

Use a fine-grained personal access token with read-only repository permissions
**Metadata** for listing repositories and **Contents** for reading refs and
commits. Select all repositories for an owner-wide inventory or the specific
repositories you plan to cover. The collector only sees repositories visible
to the credential.

- For a personal account, create the token while signed in as that account and
  select the account as resource owner. The collector checks that the credential
  belongs to the configured owner and reads its owned repositories.
- For an organization, select the organization as resource owner. Use an account
  with access to the repositories in scope, and obtain approval if the
  organization requires it for fine-grained tokens.

See [GitHub's token setup guide](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)
and the [collector configuration requirements](https://github.com/please-behave/github-collector/blob/main/why/requirements/REQ-0001.yaml).
To run the service locally, follow the [Docker Compose example](example-setup.md#optional-github-collector).
