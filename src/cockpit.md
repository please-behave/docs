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

## Read the repository dashboard

Open `/sign-in` and sign in with an allowed GitHub account. The dashboard
shows one tile per repository in the ledger's overview. The verdict pill shows
**PASS**, **FAIL**, or **ERROR** from the newest attestation containing `check`,
with its reported commit and receipt time below. **No evidence** means no
attestation containing `check` has been reported for the repository.

The top stripe shows repository health. Each tile also names its state.

| State | Meaning | Health stripe |
| --- | --- | --- |
| **Unknown** | No covering sync has completed, the last one is stale, or there is check evidence but no observed head. | Unknown |
| **Never integrated** | A fresh sync covers the repository, and there is no check evidence. | Failed |
| **Current** | The observed head has check evidence for that exact commit. | Passed |
| **Pending** | Check evidence for the observed head is missing within the grace period. | Passed |
| **Overdue** | The grace period has elapsed. The tile shows the current step and the total number of steps. | Warning until the final step, then failed |

A **FAIL** or **ERROR** verdict makes the stripe failed whenever the state is
known. For example, a **PASS** pill can appear with a warning stripe when the
passing check was reported for an earlier commit and the observed head is
overdue. A pending or overdue tile shows the observed head, how long it has
been waiting for evidence, and how many heads were observed since evidence.
The ledger configures the grace period, overdue steps, and sync staleness.
See the [ledger repository overview contract](https://github.com/please-behave/ledger/blob/main/why/contracts/read/repository-overview.md#heartbeat-and-status).

**Not managed** identifies a repository with attestations and no collector
inventory entry. It has no covering sync. Archived repositories are hidden.
Heads are periodic observations, so the count can miss changes between syncs.
Attestations carry reported evidence. A verdict records what a sender reported
for a run and carries no proof that a requirement is satisfied.

The dashboard sorts by health severity by default. Its banner counts tiles by
health and shows the oldest covering sync completion. Select a repository name
to see its latest attestation for every execution-point combination, recent
attestations, releases and deployments. Select an attestation's reported time
to see its rules and outcomes.

When available, a tile includes the newest recorded release version and the
latest deployment target and receipt time. The completed Rule Set chip shows
the count, lists the names on hover or focus, and links to the repository page.
See the [cockpit repository overview contract](https://github.com/please-behave/cockpit/blob/main/why/contracts/browser/repository-overview.md).

## View the reported evidence

The dashboard and **Attestations** tab refresh every five minutes while the
browser tab is visible. Use **Refresh** to read again immediately. The
**Attestations** tab loads older reports as you scroll, and the **Releases**
tab shows [recorded releases](recording-releases.md#view-releases-in-the-cockpit)
with their reported evidence. The
[Deployments tab](recording-deployments.md#view-deployments-in-the-cockpit)
shows what was reported on each target and what evidence is available.
Sessions expire after eight hours.
**Sign out** clears the session in your browser.

See the [cockpit sign-in requirements](https://github.com/please-behave/cockpit/tree/main/why/requirements)
and the [ledger read contracts](https://github.com/please-behave/ledger/tree/main/why/contracts/read).
